import AppKit
import AVFoundation
import Foundation
import SwiftData
import UserNotifications

enum PomodoroPreset: String, CaseIterable, Identifiable {
    case p25_5 = "25/5"
    case p35_7 = "35/7"
    case p50_10 = "50/10"

    var id: String { rawValue }

    var focusDuration: TimeInterval {
        switch self {
        case .p25_5: return 25 * 60
        case .p35_7: return 35 * 60
        case .p50_10: return 50 * 60
        }
    }
    var shortBreakDuration: TimeInterval {
        switch self {
        case .p25_5: return 5 * 60
        case .p35_7: return 7 * 60
        case .p50_10: return 10 * 60
        }
    }
    var longBreakDuration: TimeInterval { 30 * 60 }
    var focusBlocksBeforeLongBreak: Int {
        switch self {
        case .p25_5: return 4
        case .p35_7: return 3
        case .p50_10: return 2
        }
    }
}

@Observable
final class TimerEngine {
    enum State: Equatable {
        case idle
        case running
        case paused
    }

    private static let presetKey = "PomodoroPreset"

    var preset: PomodoroPreset {
        didSet {
            UserDefaults.standard.set(preset.rawValue, forKey: Self.presetKey)
            if state == .idle {
                remaining = duration(for: phase)
            }
        }
    }

    var focusDuration: TimeInterval { preset.focusDuration }
    var shortBreakDuration: TimeInterval { preset.shortBreakDuration }
    var longBreakDuration: TimeInterval { preset.longBreakDuration }
    var focusBlocksBeforeLongBreak: Int { preset.focusBlocksBeforeLongBreak }

    private(set) var state: State = .idle
    private(set) var phase: SessionType = .focus
    private(set) var remaining: TimeInterval = 25 * 60
    private(set) var completedFocusBlocks: Int = 0
    private var completedFocusBlocksDay: Date = Calendar.current.startOfDay(for: Date())

    private var ticker: Timer?
    private var phaseEndsAt: Date?
    private var currentSession: Session?
    private var blockerActive = false
    private var dripPlayers: [AVAudioPlayer] = []

    private let modelContext: ModelContext
    private let blocker: Blocker

    init(modelContext: ModelContext, blocker: Blocker) {
        self.modelContext = modelContext
        self.blocker = blocker
        let savedRaw = UserDefaults.standard.string(forKey: Self.presetKey)
        self.preset = PomodoroPreset(rawValue: savedRaw ?? "") ?? .p25_5
        self.remaining = self.preset.focusDuration
        // Clear any stale blocks left over from a prior crash / force-quit.
        blocker.stopBlocking()
        requestNotificationPermissionIfNeeded()
    }

    // MARK: - Public controls

    func start() {
        guard state == .idle else { return }
        rolloverCounterIfNeeded()
        beginPhase(phase)
    }

    func rolloverCounterIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != completedFocusBlocksDay else { return }
        completedFocusBlocks = 0
        completedFocusBlocksDay = today
    }

    func pause() {
        guard state == .running else { return }
        ticker?.invalidate()
        ticker = nil
        state = .paused
        syncBlocker()
    }

    func resume() {
        guard state == .paused else { return }
        phaseEndsAt = Date().addingTimeInterval(remaining)
        startTicker()
        state = .running
        syncBlocker()
    }

    func skip() {
        endCurrentSession(completed: false)
        advancePhase()
        remaining = duration(for: phase)
        syncBlocker()
    }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        endCurrentSession(completed: false)
        state = .idle
        phase = .focus
        completedFocusBlocks = 0
        remaining = focusDuration
        phaseEndsAt = nil
        syncBlocker()
    }

    // MARK: - Phase machinery

    private func beginPhase(_ next: SessionType) {
        phase = next
        let total = duration(for: next)
        remaining = total
        phaseEndsAt = Date().addingTimeInterval(total)

        let session = Session(type: next, plannedDuration: total)
        modelContext.insert(session)
        try? modelContext.save()
        currentSession = session

        state = .running
        startTicker()
        syncBlocker()
    }

    private func syncBlocker() {
        let shouldBeActive = state != .idle
        guard shouldBeActive != blockerActive else { return }
        if shouldBeActive {
            blocker.startBlocking()
        } else {
            blocker.stopBlocking()
        }
        blockerActive = shouldBeActive
    }

    private func advancePhase() {
        let prev = phase
        let nextPhase: SessionType

        if prev == .focus {
            completedFocusBlocks += 1
            nextPhase = (completedFocusBlocks % focusBlocksBeforeLongBreak == 0) ? .longBreak : .shortBreak
        } else {
            nextPhase = .focus
        }

        phase = nextPhase
        remaining = duration(for: nextPhase)
        phaseEndsAt = nil
        state = .idle
    }

    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let ticker {
            RunLoop.main.add(ticker, forMode: .common)
        }
    }

    private func tick() {
        guard let endsAt = phaseEndsAt else { return }
        let now = Date()
        remaining = max(0, endsAt.timeIntervalSince(now))
        rolloverCounterIfNeeded()
        if remaining <= 0 {
            ticker?.invalidate()
            ticker = nil
            phaseFinished()
        }
    }

    private func phaseFinished() {
        let finishedPhase = phase
        endCurrentSession(completed: true)
        notifyPhaseEnded(finishedPhase)
        advancePhase()
        if finishedPhase == .focus {
            // Focus → break auto-rolls; the user shouldn't have to babysit the transition.
            beginPhase(phase)
        } else {
            // Break → focus is manual so the user can extend their rest. Drop the blocker now.
            syncBlocker()
        }
    }

    private func endCurrentSession(completed: Bool) {
        guard let session = currentSession else { return }
        let now = Date()
        session.endedAt = now
        session.actualDuration = now.timeIntervalSince(session.startedAt)
        session.completed = completed
        try? modelContext.save()
        currentSession = nil
    }

    private func duration(for phase: SessionType) -> TimeInterval {
        switch phase {
        case .focus: return focusDuration
        case .shortBreak: return shortBreakDuration
        case .longBreak: return longBreakDuration
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyPhaseEnded(_ phase: SessionType) {
        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "Focus block complete"
            content.body = "Time for a break."
        case .shortBreak:
            content.title = "Break over"
            content.body = "Back to focus."
        case .longBreak:
            content.title = "Long break over"
            content.body = "Ready for another round?"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
        playDripSound()
    }

    func playDripSound() {
        // First third of "Purr", fired five times. Scheduled on the audio device clock so the spacing
        // survives main-thread stalls (e.g. the sudo call in syncBlocker right after a phase ends).
        let url = URL(fileURLWithPath: "/System/Library/Sounds/Purr.aiff")
        let offsets: [TimeInterval] = [0.0, 0.18, 0.36, 0.54, 0.72]
        let fraction = 1.0 / 3.0

        let players = offsets.compactMap { _ -> AVAudioPlayer? in
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
            p.prepareToPlay()
            return p
        }
        guard let first = players.first else { return }
        let startAt = first.deviceCurrentTime + 0.1

        for (player, offset) in zip(players, offsets) {
            dripPlayers.append(player)
            player.play(atTime: startAt + offset)
            let stopAfter = (startAt + offset + player.duration * fraction) - first.deviceCurrentTime
            DispatchQueue.main.asyncAfter(deadline: .now() + stopAfter) { [weak self] in
                player.stop()
                self?.dripPlayers.removeAll { $0 === player }
            }
        }
    }
}

import SwiftUI

@MainActor
final class CountdownController: ObservableObject {
    @Published var remaining = 0
    @Published var isActive = false
    private var timer: Timer?

    func start(minutes: Int) {
        remaining = max(1, minutes) * 60
        isActive = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        remaining = 0
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            stop()
            NSSound.beep()
        }
    }

    var display: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}

@MainActor
final class FocusController: ObservableObject {
    enum Phase {
        case work
        case rest
    }

    @Published var isActive = false
    @Published var phase: Phase = .work
    @Published var remaining = 0
    @Published var cycle = 1
    @Published var noiseColor: NoiseEngine.NoiseColor = .brown

    let noise = NoiseEngine()
    private var timer: Timer?
    private var workMinutes = 25
    private let restMinutes = 5

    func start(work: Int = 25) {
        workMinutes = max(1, work)
        cycle = 1
        phase = .work
        remaining = workMinutes * 60
        isActive = true
        noise.start(noiseColor)
        run()
    }

    func setNoise(_ color: NoiseEngine.NoiseColor) {
        noiseColor = color
        noise.set(color)
        if isActive && phase == .work && !noise.isRunning {
            noise.start(color)
        }
    }

    func muteNoise() {
        noise.pause()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isActive = false
        noise.stop()
    }

    private func run() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        remaining -= 1
        guard remaining <= 0 else { return }
        if phase == .work {
            phase = .rest
            remaining = restMinutes * 60
            noise.pause()
            NSSound.beep()
        } else {
            cycle += 1
            phase = .work
            remaining = workMinutes * 60
            noise.resume()
            NSSound.beep()
        }
    }

    var display: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}

import AVFoundation

/// Generates study noise in real time with a source node.
/// No audio files, no licensing, works offline, costs nothing.
final class NoiseEngine {
    enum NoiseColor: String {
        case brown
        case white
        case pink
    }

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var current: NoiseColor = .brown

    // Filter state
    private var brownLast: Float = 0
    private var pink0: Float = 0
    private var pink1: Float = 0
    private var pink2: Float = 0

    private(set) var isRunning = false

    func start(_ color: NoiseColor) {
        current = color
        if source == nil { setup() }
        engine.mainMixerNode.outputVolume = 0.35
        if !engine.isRunning {
            try? engine.start()
        }
        isRunning = true
    }

    func set(_ color: NoiseColor) {
        current = color
    }

    func pause() {
        engine.mainMixerNode.outputVolume = 0
    }

    func resume() {
        engine.mainMixerNode.outputVolume = 0.35
    }

    func stop() {
        engine.stop()
        isRunning = false
    }

    private func setup() {
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = self.nextSample()
                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    let pointer = data.assumingMemoryBound(to: Float.self)
                    pointer[frame] = sample
                }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
        source = node
    }

    private func nextSample() -> Float {
        let white = Float.random(in: -1...1)
        switch current {
        case .white:
            return white * 0.4
        case .pink:
            // Kellet economy pink filter
            pink0 = 0.99765 * pink0 + white * 0.0990460
            pink1 = 0.96300 * pink1 + white * 0.2965164
            pink2 = 0.57000 * pink2 + white * 1.0526913
            return (pink0 + pink1 + pink2 + white * 0.1848) * 0.12
        case .brown:
            brownLast = (brownLast + 0.02 * white) / 1.02
            return brownLast * 3.2
        }
    }
}

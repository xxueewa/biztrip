import AVFoundation
import SwiftUI
import Accelerate
import Combine

enum Constants {
    static let sampleAmount: Int = 200
    static let magnitudeLimit: Float = 100
}
struct ContentView: View {
    @StateObject private var monitor = AudioModel.shared
    private var activityLevel: CGFloat {
        let peak = monitor.fftMagnitudes.max() ?? 0
        return CGFloat(min(max(peak / Constants.magnitudeLimit, 0), 1))
    }

    private var responseLines: [String] {
        let parts = monitor.responseText
            .components(separatedBy: ". ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.enumerated().map { index, line in
            guard index < parts.count - 1, !line.hasSuffix(".") else { return line }
            return line + "."
        }
    }

    var body: some View {
        VStack(spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Voice Session")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.10))

                        Text(monitor.isMonitoring ? "Listening" : "Ready")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Circle()
                        .fill(monitor.isMonitoring ? Color(red: 0.88, green: 0.19, blue: 0.16) : Color(red: 0.12, green: 0.55, blue: 0.46))
                        .frame(width: 10, height: 10)
                }

                ResponsePanel(lines: responseLines)
                    .frame(maxHeight: .infinity)
                    .layoutPriority(1)

                VoiceControlButton(
                    isRecording: monitor.isMonitoring,
                    activityLevel: activityLevel
                ) {
                    if monitor.isMonitoring {
                        monitor.stopMonitoring()
                    } else {
                        Task { await monitor.startMonitoring() }
                    }
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.97, blue: 0.95))
    }
}

private struct ResponsePanel: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.46))

                Text("Mock response")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.12))
            }
            .padding(.bottom, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: 17, weight: .regular))
                            .lineSpacing(5)
                            .foregroundStyle(Color(red: 0.20, green: 0.22, blue: 0.24))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 11)

                        if index < lines.count - 1 {
                            Divider()
                                .overlay(Color.black.opacity(0.05))
                        }
                    }
                }
            }
            .scrollIndicators(.visible)
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 18, y: 8)
    }
}

private struct VoiceControlButton: View {
    let isRecording: Bool
    let activityLevel: CGFloat
    let action: () -> Void

    private var accentColor: Color {
        isRecording ? Color(red: 0.88, green: 0.19, blue: 0.16) : Color(red: 0.08, green: 0.12, blue: 0.16)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(isRecording ? 0.14 : 0.08))
                        .frame(
                            width: 112 + activityLevel * 44,
                            height: 112 + activityLevel * 44
                        )
                        .shadow(
                            color: accentColor.opacity(isRecording ? 0.18 : 0.08),
                            radius: 14 + activityLevel * 12
                        )
                        .animation(.easeOut(duration: 0.18), value: activityLevel)

                    Circle()
                        .fill(accentColor)
                        .frame(width: 96, height: 96)
                        .shadow(color: accentColor.opacity(isRecording ? 0.24 : 0.16), radius: 20, y: 10)

                    Image(systemName: isRecording ? "stop.fill" : "waveform")
                        .font(.system(size: isRecording ? 28 : 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 140, height: 140)

                HStack(spacing: 8) {
                    Circle()
                        .fill(isRecording ? Color(red: 0.88, green: 0.19, blue: 0.16) : Color(red: 0.12, green: 0.55, blue: 0.46))
                        .frame(width: 8, height: 8)

                    Text(isRecording ? "Tap to stop" : "Tap to speak")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.11, green: 0.12, blue: 0.13))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

private struct FlowPager: View {

    var body: some View {
        TabView {
            PhoneScreen {
                CenterRecordingScreen()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black)
        .ignoresSafeArea()
    }
}

private struct PhoneScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
    }
}

private struct CenterRecordingScreen: View {

    var body: some View {
    }
}

@MainActor
private final class AudioModel: ObservableObject {
    static let shared = AudioModel()
    @Published var isMonitoring = false
    private var audioEngine = AVAudioEngine()
    private let bufferSize = 8192
    private var fftSetup: OpaquePointer?
    private var audioContinuation: AsyncStream<[Float]>.Continuation?
    private var processingTask: Task<Void, Never>?
    private let mockAPI = MockAudioAPI()
    
    private init() {}
    
    
    @Published var fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    @Published var responseText = "Tap Start and speak. The mock API consumes the live audio stream, drives the FFT visualization, and returns a dummy paragraph when you stop."
    
    func startMonitoring() async {
        guard !isMonitoring else { return }

        let hasPermission = await requestRecordPermission()
        guard hasPermission else {
            responseText = "Microphone permission is required to capture audio."
            return
        }

        processingTask?.cancel()
        responseText = "Listening... the mock API is consuming audio frames."

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            responseText = "Error configuring audio session: \(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        // digital signal peocessing routines on large vectors
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(self.bufferSize), .FORWARD)
        
        let audioStream = AsyncStream<[Float]> { continuation in
            self.audioContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.audioEngine.inputNode.removeTap(onBus: 0)
                    self.audioContinuation = nil
                }
            }

            inputNode.installTap(onBus: 0, bufferSize: UInt32(self.bufferSize), format: inputFormat) {
                @Sendable buffer, _ in
                let channelData = buffer.floatChannelData?[0] // channel number [1, 2] idx zero always has value
                let frameCount = Int(buffer.frameLength)
                
                let floatData = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
                
                continuation.yield(floatData)
            }
        }
        
        do {
            try audioEngine.start()
            isMonitoring = true
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            responseText = "Error starting audio engine: \(error.localizedDescription)"
            return
        }

        processingTask = Task { [weak self] in
            guard let self else { return }

            let paragraph = await self.mockAPI.consume(audioStream: audioStream) { data in
                await self.performFFT(data: data)
            }

            await MainActor.run {
                self.responseText = paragraph
            }
        }
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }

        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioContinuation?.finish()
        audioContinuation = nil
        
        responseText = "Processing captured audio with mock API..."
        
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }
        
        isMonitoring = false;
        
    }

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    func performFFT(data: [Float]) async -> [Float] {
        // performs the FFT transformation, responsible for extracting the strength
        // of different frequencies from the raw waveform given by the microphone.
        guard let setup = fftSetup else {
            return [Float](repeating: 0, count: Constants.sampleAmount)
        }
            
        var realIn = Array(data.prefix(bufferSize))
        if realIn.count < bufferSize {
            realIn.append(contentsOf: repeatElement(0, count: bufferSize - realIn.count))
        }
        var imagIn = [Float](repeating: 0, count: bufferSize)
        var realOut = [Float](repeating: 0, count: bufferSize)
        var imagOut = [Float](repeating: 0, count: bufferSize)
        
        var magnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
        
        realIn.withUnsafeMutableBufferPointer { realInPtr in
            imagIn.withUnsafeMutableBufferPointer { imagInPtr in
                realOut.withUnsafeMutableBufferPointer { realOutPtr in
                    imagOut.withUnsafeMutableBufferPointer { imagOutPtr in
                        // Discrete Fourier Transform
                        vDSP_DFT_Execute(setup, realInPtr.baseAddress!, imagInPtr.baseAddress!, realOutPtr.baseAddress!, imagOutPtr.baseAddress!)
                        
                        var complex = DSPSplitComplex(realp: realOutPtr.baseAddress!, imagp: imagOutPtr.baseAddress!)
                        
                        // magnitude = sqrt(realOut^2 + imagOut^2)
                        vDSP_zvabs(&complex, 1, &magnitudes, 1, UInt(Constants.sampleAmount))
                        
                    }
                }
                
            }
        }
        let clampedMagnitudes = magnitudes.map {min($0, Constants.magnitudeLimit)}
        fftMagnitudes = clampedMagnitudes
        return clampedMagnitudes
    }
}

private final class MockAudioAPI {
    func consume(
        audioStream: AsyncStream<[Float]>,
        performFFT: @escaping ([Float]) async -> [Float]
    ) async -> String {
        var bufferCount = 0
        var sampleCount = 0
        var peak: Float = 0
        var energy: Float = 0
        var latestDominantBin = 0

        for await floatData in audioStream {
            guard !Task.isCancelled else { break }

            bufferCount += 1
            sampleCount += floatData.count
            peak = max(peak, floatData.map { abs($0) }.max() ?? 0)
            energy += floatData.reduce(Float(0)) { partial, sample in
                partial + sample * sample
            }

            let magnitudes = await performFFT(floatData)
            if let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) {
                latestDominantBin = maxIndex
            }
        }

        let rms = sampleCount > 0 ? sqrt(energy / Float(sampleCount)) : 0
        let seconds = sampleCount > 0 ? Float(sampleCount) / 44_100 : 0

        return """
        Mock response: I consumed \(bufferCount) audio buffers, roughly \(String(format: "%.1f", seconds)) seconds of microphone input. The waveform had a peak level of \(String(format: "%.2f", peak)) and an RMS level of \(String(format: "%.2f", rms)). The latest dominant FFT bin was \(latestDominantBin), so this is where the real backend would hand the captured utterance to VAD, transcription, and agent processing.
        """
    }
}

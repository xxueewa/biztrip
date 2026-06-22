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

                Text("Server response")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.12))
            }
            .padding(.bottom, 16)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 17, weight: .regular))
                                .lineSpacing(5)
                                .foregroundStyle(Color(red: 0.20, green: 0.22, blue: 0.24))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 11)
                                .id(index)

                            if index < lines.count - 1 {
                                Divider()
                                    .overlay(Color.black.opacity(0.05))
                            }
                        }
                    }
                }
                .scrollIndicators(.visible)
                .onChange(of: lines) { _, updatedLines in
                    guard let lastIndex = updatedLines.indices.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastIndex, anchor: .bottom)
                    }
                }
            }
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
    private let audioAPI = WebSocketAudioAPI(
        endpoint: URL(string: "ws://127.0.0.1:8000/chat/ws/audio/connect")!
    )
    
    private init() {}
    
    
    @Published var fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    @Published var responseText = "Tap Start and speak. Audio will stream to the local WebSocket server."

    func startMonitoring() async {
        guard !isMonitoring else { return }

        let hasPermission = await requestRecordPermission()
        guard hasPermission else {
            responseText = "Microphone permission is required to capture audio."
            return
        }

        processingTask?.cancel()
        responseText = "Connecting to the local audio server..."

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true)
        } catch {
            responseText = "Error configuring audio session: \(error.localizedDescription)"
            return
        }

        let inputNode = audioEngine.inputNode
        do {
            try inputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("Voice processing unavailable; using the adaptive dialogue gate: \(error.localizedDescription)")
        }
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

            let paragraph = await self.audioAPI.consume(
                audioStream: audioStream,
                performFFT: { data in
                    await self.performFFT(data: data)
                },
                onText: { text in
                    await MainActor.run {
                        self.responseText = text
                    }
                },
                onSilenceDetected: {
                    await MainActor.run {
                        if self.isMonitoring {
                            self.stopMonitoring()
                        }
                    }
                }
            )

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
        
        responseText = "Waiting for the server response..."
        
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

private final class WebSocketAudioAPI {
    private let endpoint: URL

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    func consume(
        audioStream: AsyncStream<[Float]>,
        performFFT: @escaping ([Float]) async -> [Float],
        onText: @escaping (String) async -> Void,
        onSilenceDetected: @escaping () async -> Void
    ) async -> String {
        let socket = URLSession.shared.webSocketTask(with: endpoint)
        socket.resume()
        var dialogueGate = DialogueGate()
        var sentEndOfStream = false

        let receiver = Task { [endpoint] in
            var latestText = "Connected to \(endpoint.absoluteString). Listening for dialogue..."
            var streamedText = ""
            await onText(latestText)

            while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    guard case let .string(text) = message else {
                        continue
                    }

                    let response = Self.parseResponse(text)
                    if let displayText = response.text, !displayText.isEmpty {
                        if response.isDelta {
                            streamedText += displayText
                        } else {
                            streamedText = displayText
                        }
                        latestText = streamedText
                        await onText(streamedText)
                    }
                    if response.isDone {
                        break
                    }
                } catch {
                    if !Task.isCancelled {
                        latestText = "WebSocket closed: \(error.localizedDescription)"
                    }
                    break
                }
            }

            return latestText
        }

        for await floatData in audioStream {
            guard !Task.isCancelled else { break }

            _ = await performFFT(floatData)
            let gateOutput = dialogueGate.process(samples: floatData)

            for frame in gateOutput.frames {
                do {
                    try await socket.send(.data(Self.pcm16Data(from: frame)))
                } catch {
                    receiver.cancel()
                    socket.cancel(with: .goingAway, reason: nil)
                    return "Audio upload failed: \(error.localizedDescription)"
                }
            }

            if gateOutput.didDetectEndOfSpeech {
                do {
                    try await socket.send(.data(Data()))
                    sentEndOfStream = true
                    await onSilenceDetected()
                    break
                } catch {
                    receiver.cancel()
                    socket.cancel(with: .goingAway, reason: nil)
                    return "Could not finish the audio stream: \(error.localizedDescription)"
                }
            }
        }

        do {
            // A zero-length binary frame marks the end of the utterance while
            // keeping the socket open for the server's text response.
            if !sentEndOfStream {
                try await socket.send(.data(Data()))
            }
        } catch {
            receiver.cancel()
            socket.cancel(with: .goingAway, reason: nil)
            return "Could not finish the audio stream: \(error.localizedDescription)"
        }

        let response = await receiver.value
        socket.cancel(with: .normalClosure, reason: nil)
        return response
    }

    private static func pcm16Data(from samples: [Float]) -> Data {
        let pcm = samples.map { sample -> Int16 in
            let clamped = min(max(sample, -1), 1)
            return Int16(clamped * Float(Int16.max)).littleEndian
        }

        return pcm.withUnsafeBytes { Data($0) }
    }

    private static func parseResponse(
        _ rawText: String
    ) -> (text: String?, isDelta: Bool, isDone: Bool) {
        guard
            let data = rawText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return (rawText, true, false)
        }

        let type = (json["type"] as? String)?.lowercased()
        let delta = json["delta"] as? String
        let text = delta
            ?? (json["text"] as? String)
            ?? (json["message"] as? String)
            ?? (json["content"] as? String)
        let isDelta = delta != nil || type?.contains("delta") == true
        let isDone = type == "done"
            || type == "audio_end"
            || type?.contains(".done") == true
        return (text, isDelta, isDone)
    }
}

private struct DialogueGate {
    struct Output {
        let frames: [[Float]]
        let didDetectEndOfSpeech: Bool
    }

    private var noiseFloor: Float = 0.006
    private var isOpen = false
    private var quietFrameCount = 0
    private var preRoll: [[Float]] = []

    private let minimumOpenRMS: Float = 0.015
    private let minimumCloseRMS: Float = 0.009
    private let minimumSpeechPeak: Float = 0.03
    private let openNoiseRatio: Float = 3.0
    private let closeNoiseRatio: Float = 1.5
    private let hangoverFrames = 2
    private let preRollFrames = 1

    mutating func process(samples: [Float]) -> Output {
        guard !samples.isEmpty else {
            return Output(frames: [], didDetectEndOfSpeech: false)
        }

        let meanSquare = samples.reduce(Float.zero) { partial, sample in
            partial + sample * sample
        } / Float(samples.count)
        let rms = sqrt(meanSquare)
        let peak = samples.reduce(Float.zero) { currentPeak, sample in
            max(currentPeak, abs(sample))
        }
        let threshold = isOpen
            ? max(minimumCloseRMS, noiseFloor * closeNoiseRatio)
            : max(minimumOpenRMS, noiseFloor * openNoiseRatio)
        let containsDialogue = rms >= threshold
            && (isOpen || peak >= minimumSpeechPeak)

        if !isOpen && !containsDialogue {
            noiseFloor = noiseFloor * 0.95 + rms * 0.05
        }

        preRoll.append(samples)
        if preRoll.count > preRollFrames {
            preRoll.removeFirst()
        }

        if containsDialogue {
            quietFrameCount = 0
            if !isOpen {
                isOpen = true
                let bufferedFrames = preRoll
                preRoll.removeAll(keepingCapacity: true)
                return Output(frames: bufferedFrames, didDetectEndOfSpeech: false)
            }
            preRoll.removeAll(keepingCapacity: true)
            return Output(frames: [samples], didDetectEndOfSpeech: false)
        }

        guard isOpen else {
            return Output(frames: [], didDetectEndOfSpeech: false)
        }

        quietFrameCount += 1
        if quietFrameCount <= hangoverFrames {
            preRoll.removeAll(keepingCapacity: true)
            return Output(frames: [samples], didDetectEndOfSpeech: false)
        }

        isOpen = false
        quietFrameCount = 0
        return Output(frames: [], didDetectEndOfSpeech: true)
    }
}

import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var model = ConversationModel()

    var body: some View {
        FlowPager(model: model)
            .preferredColorScheme(.light)
    }
}

private struct FlowPager: View {
    @ObservedObject var model: ConversationModel

    var body: some View {
        TabView {
            PhoneScreen {
                CenterRecordingScreen(model: model)
            }

            PhoneScreen {
                ResponseScreen(model: model)
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
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 440, proxy.size.height / 956)

            ZStack {
                RoundedRectangle(cornerRadius: 64, style: .continuous)
                    .fill(.white)
                    .frame(width: 440, height: 956)
                    .overlay(alignment: .top) {
                        StatusChrome()
                    }
                    .overlay {
                        content
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 64, style: .continuous))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .scaleEffect(scale)
        }
    }
}

private struct StatusChrome: View {
    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Text("9:41")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)

                Spacer()

                HStack(spacing: 7) {
                    CellularIcon()
                    WifiIcon()
                    BatteryIcon()
                }
            }
            .frame(width: 326, height: 13)
            .offset(y: 25)

            Capsule()
                .fill(.black)
                .frame(width: 124, height: 36)
                .offset(y: 15)
        }
        .frame(width: 440, height: 70, alignment: .top)
    }
}

private struct CenterRecordingScreen: View {
    @ObservedObject var model: ConversationModel

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                Text(model.centerStatusText)
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.72))
                    .frame(width: 320)

                Text(model.connectionText)
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.42))
                    .frame(width: 320)
            }
            .position(x: 220, y: 585)

            RecordingButton(size: 124, isRecording: model.isRecording) {
                model.toggleRecording()
            }
            .position(x: 220, y: 456)
        }
        .frame(width: 440, height: 956)
    }
}

private struct ResponseScreen: View {
    @ObservedObject var model: ConversationModel

    var body: some View {
        ZStack {
            Text(model.promptText)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .frame(width: 365, height: 114)
                .position(x: 220.5, y: 227)

            Text(model.responseText)
                .font(.system(size: 17, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.black)
                .frame(width: 303, height: 357)
                .position(x: 220.5, y: 363.5)

            RecordingButton(size: 65, isRecording: model.isRecording) {
                model.toggleRecording()
            }
            .position(x: 219.5, y: 880.5)
        }
        .frame(width: 440, height: 956)
    }
}

private struct RecordingButton: View {
    let size: CGFloat
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                Circle()
                    .fill(Color(red: 0.91, green: 0.85, blue: 0.98))

                Circle()
                    .stroke(Color(red: 0.404, green: 0.314, blue: 0.643), lineWidth: max(3, size * 0.055))
                    .padding(size * 0.07)

                RoundedRectangle(cornerRadius: isRecording ? size * 0.08 : size * 0.5, style: .continuous)
                    .fill(Color(red: 0.86, green: 0.12, blue: 0.16))
                    .frame(width: isRecording ? size * 0.28 : size * 0.42, height: isRecording ? size * 0.28 : size * 0.42)
                    .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isRecording)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop recording" : "Start recording")
    }
}

@MainActor
private final class ConversationModel: ObservableObject {
    private let threadID = "3cfbf39d-8502-4aa1-bff5-f647b788cf89"
    private let socketURL = URL(string: "ws://127.0.0.1:8000/chat/ws/audio/debug")!
    private var client: ConversationSocketClient?

    @Published var isRecording = false
    @Published var promptText = "Tap the mic and speak. Audio streams to the Python websocket backend as PCM16 frames."
    @Published var responseText = "The dummy backend will answer with generated audio and text after you stop recording."
    @Published var centerStatusText = "Ready"
    @Published var connectionText = "ws://127.0.0.1:8000/chat/ws/audio/debug"

    func toggleRecording() {
        Task {
            if isRecording {
                await stopRecording()
            } else {
                await startRecording()
            }
        }
    }

    private func startRecording() async {
        let client = ConversationSocketClient(url: socketURL, threadID: threadID)
        self.client = client
        centerStatusText = "Connecting..."
        responseText = "Listening..."

        do {
            try await client.start { [weak self] event in
                Task { @MainActor in
                    self?.handle(event)
                }
            }
            isRecording = true
            centerStatusText = "Recording..."
            connectionText = "Streaming microphone audio"
        } catch {
            isRecording = false
            centerStatusText = "Connection failed"
            connectionText = socketURL.absoluteString
            responseText = error.localizedDescription
            self.client = nil
        }
    }

    private func stopRecording() async {
        isRecording = false
        centerStatusText = "Processing..."
        connectionText = "Waiting for agent response"

        do {
            try await client?.stopRecording()
        } catch {
            centerStatusText = "Stop failed"
            responseText = error.localizedDescription
            await client?.close()
            client = nil
        }
    }

    private func handle(_ event: ConversationEvent) {
        switch event {
        case .connected:
            connectionText = "Connected"
        case .recordingStarted:
            centerStatusText = "Recording..."
        case .speechEnded:
            centerStatusText = "Sentence detected"
        case .transcript(let text):
            promptText = text
        case .agentStarted:
            centerStatusText = "Agent is thinking..."
        case .responseText(let text):
            responseText = text
        case .audioStarted:
            centerStatusText = "Playing response..."
        case .audioEnded:
            centerStatusText = "Response ready"
            connectionText = "Ready for another turn"
        case .recordingSaved(let path):
            connectionText = "Saved recording: \(path)"
        case .closed:
            isRecording = false
            client = nil
        case .error(let message):
            isRecording = false
            centerStatusText = "WebSocket error"
            responseText = message
            client = nil
        }
    }
}

private enum ConversationEvent {
    case connected
    case recordingStarted
    case speechEnded
    case transcript(String)
    case agentStarted
    case responseText(String)
    case audioStarted
    case audioEnded
    case recordingSaved(String)
    case closed
    case error(String)
}

private final class ConversationSocketClient {
    private let url: URL
    private let threadID: String
    private let session: URLSession
    private let recorder = PCMRecorder(sampleRate: 16_000)
    private let player = PCMPlayer()

    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var eventHandler: ((ConversationEvent) -> Void)?

    init(url: URL, threadID: String) {
        self.url = url
        self.threadID = threadID
        self.session = URLSession(configuration: .default)
    }

    func start(onEvent: @escaping (ConversationEvent) -> Void) async throws {
        eventHandler = onEvent

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        onEvent(.connected)

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        try await sendJSON(SocketControl(type: "start_audio", threadID: threadID, sampleRate: recorder.sampleRate, encoding: "pcm_s16le"))
        try await recorder.start { [weak self] data in
            guard let task = self?.task else { return }
            let eventHandler = self?.eventHandler
            task.send(.data(data)) { error in
                if let error {
                    eventHandler?(.error(error.localizedDescription))
                }
            }
        }
        onEvent(.recordingStarted)
    }

    func stopRecording() async throws {
        recorder.stop()
        try await sendJSON(SocketControl(type: "stop_audio", threadID: threadID, sampleRate: nil, encoding: nil))
    }

    func close() async {
        recorder.stop()
        receiveTask?.cancel()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        await player.stop()
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let task else { return }

            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleText(text)
                case .data(let data):
                    await player.enqueuePCM16(data)
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    eventHandler?(.error(error.localizedDescription))
                }
                return
            }
        }
    }

    private func handleText(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(SocketMessage.self, from: data) else {
            eventHandler?(.responseText(text))
            return
        }

        switch message.type {
        case "speech_end":
            eventHandler?(.speechEnded)
        case "transcript":
            eventHandler?(.transcript(message.text ?? ""))
        case "agent_started":
            eventHandler?(.agentStarted)
        case "response_text":
            eventHandler?(.responseText(message.text ?? ""))
        case "audio_start":
            let sampleRate = Double(message.sampleRate ?? 24_000)
            do {
                try await player.start(sampleRate: sampleRate)
                eventHandler?(.audioStarted)
            } catch {
                eventHandler?(.error(error.localizedDescription))
            }
        case "audio_end":
            eventHandler?(.audioEnded)
        case "done":
            eventHandler?(.closed)
            await close()
        case "error":
            eventHandler?(.error(message.message ?? "Server error"))
            await close()
        default:
            break
        }
    }

    private func sendJSON<T: Encodable>(_ value: T) async throws {
        let data = try JSONEncoder().encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SocketClientError.invalidJSON
        }
        try await task?.send(.string(text))
    }
}

private final class SimpleRecorder {
    let sampleRate: Double
    
    let engine = AVAudioEngine()
    private var fileHandle: FileHandle?
    private(set) var outputURL: URL?
    
    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }
    
    func start() async throws {
        let session = AVAudioSession.sharedInstance()

        let hasPermission = await AVAudioApplication.requestRecordPermission()
        guard hasPermission else {
            throw RecordingError.permissionDenied
        }
        
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)
        
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }
        let customFolderURL = cachesDir.appendingPathComponent("MyCustomCache")
        
        let url = customFolderURL.appendingPathComponent("recording_\(Date().timeIntervalSince1970).pcm")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: customFolderURL.path) {
            try fileManager.createDirectory(at: customFolderURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        fileHandle = try FileHandle(forWritingTo: url)
        outputURL = url
        
        // Force inputNode initialization before prepare
        // Accessing it is enough — just don't use the format yet
        _ = engine.inputNode
        engine.prepare()
        
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)  // float32, 48000Hz native
        print("format after prepare: \(format)")

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            guard let self,
                  let channelData = buffer.floatChannelData?[0] else { return }

            let frameCount = Int(buffer.frameLength)
            let int16Data = (0..<frameCount).map { i -> Int16 in
                let clamped = max(-1.0, min(1.0, channelData[i]))
                return Int16(clamped * 32767.0)
            }

            let data = int16Data.withUnsafeBytes { Data($0) }
            self.fileHandle?.write(data)
        }

        
        try engine.start()
    }
    
    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        fileHandle?.closeFile()
        fileHandle = nil
        return outputURL
    }
}

private final class PCMRecorder {
    let sampleRate: Double

    private let engine = AVAudioEngine()
    private let fileQueue = DispatchQueue(label: "com.codex.FigmaTemplateApp.debugRecording")
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var debugFileHandle: FileHandle?
    private var debugFileURL: URL?

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
    }

    func start(onPCM: @escaping (Data) -> Void) async throws {
        let session = AVAudioSession.sharedInstance()
        let hasPermission = await requestRecordPermission(session: session)

        guard hasPermission else {
            throw RecordingError.permissionDenied
        }

        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        
        // Force inputNode initialization before prepare
        // Accessing it is enough — just don't use the format yet
        _ = engine.inputNode
        engine.prepare()
        
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)  // float32, 48000Hz native
        print("format after prepare: \(inputFormat)")

        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw RecordingError.unsupportedFormat
        }

        self.converter = converter
        self.outputFormat = outputFormat
        try prepareDebugFile()

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self,
                  let converter = self.converter,
                  let outputFormat = self.outputFormat else { return }
            
            let ratio = outputFormat.sampleRate / buffer.format.sampleRate
            let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 8
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCapacity) else { return }
            
            var didProvideInput = false
            var conversionError: NSError?
            converter.convert(to: convertedBuffer, error: &conversionError) { _, status in
                if didProvideInput {
                    status.pointee = .noDataNow
                    return nil
                }
                
                didProvideInput = true
                status.pointee = .haveData
                return buffer
            }
            
            guard conversionError == nil, convertedBuffer.frameLength > 0 else { return }
            let pcmData = Self.floatBufferToPCM16(convertedBuffer)
            self.writeDebugPCM(pcmData)
            onPCM(pcmData)
        }

        try engine.start()
    }

    @discardableResult
    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        outputFormat = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let savedURL = debugFileURL
        fileQueue.sync {
            try? debugFileHandle?.close()
            debugFileHandle = nil
        }
        debugFileURL = nil

        if let savedURL {
            print("Saved debug recording to \(savedURL.path)")
        }

        return savedURL
    }

    private static func floatBufferToPCM16(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData?[0] else { return Data() }

        var data = Data(capacity: Int(buffer.frameLength) * MemoryLayout<Int16>.size)
        for index in 0..<Int(buffer.frameLength) {
            let sample = max(-1, min(1, channelData[index]))
            var intSample = Int16(sample * Float(Int16.max)).littleEndian
            withUnsafeBytes(of: &intSample) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func prepareDebugFile() throws {
        let fileName = "biztrip-recording-\(Int(Date().timeIntervalSince1970)).pcm"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        debugFileHandle = try FileHandle(forWritingTo: fileURL)
        debugFileURL = fileURL
        print("Saving debug recording to \(fileURL.path)")
    }

    private func writeDebugPCM(_ data: Data) {
        guard !data.isEmpty else { return }

        fileQueue.async { [weak self] in
            self?.debugFileHandle?.write(data)
        }
    }

    private func requestRecordPermission(session: AVAudioSession) async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}

private actor PCMPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var isPrepared = false
    private var nodeAttached = false

    func start(sampleRate: Double) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        if !nodeAttached {
            engine.attach(playerNode)
            nodeAttached = true
        }

        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
            throw PlaybackError.unsupportedFormat
        }

        if self.format?.sampleRate != format.sampleRate || !isPrepared {
            engine.disconnectNodeOutput(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: format)
            self.format = format
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }

        if !playerNode.isPlaying {
            playerNode.play()
        }

        isPrepared = true
    }

    func enqueuePCM16(_ data: Data) {
        guard let format, isPrepared, !data.isEmpty else { return }

        let sampleCount = data.count / MemoryLayout<Int16>.size
        guard sampleCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount)) else { return }

        buffer.frameLength = AVAudioFrameCount(sampleCount)
        guard let samples = buffer.floatChannelData?[0] else { return }

        data.withUnsafeBytes { rawBuffer in
            let intSamples = rawBuffer.bindMemory(to: Int16.self)
            for index in 0..<sampleCount {
                samples[index] = Float(Int16(littleEndian: intSamples[index])) / Float(Int16.max)
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    func stop() {
        playerNode.stop()
        engine.stop()
        isPrepared = false
    }
}

private struct SocketControl: Encodable {
    let type: String
    let threadID: String
    let sampleRate: Double?
    let encoding: String?

    enum CodingKeys: String, CodingKey {
        case type
        case threadID = "thread_id"
        case sampleRate = "sample_rate"
        case encoding
    }
}

private struct SocketMessage: Decodable {
    let type: String
    let text: String?
    let message: String?
    let sampleRate: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case message
        case sampleRate = "sample_rate"
    }
}

private enum RecordingError: LocalizedError {
    case permissionDenied
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record."
        case .unsupportedFormat:
            return "The microphone audio format is not supported."
        }
    }
}

private enum PlaybackError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? {
        "The response audio format is not supported."
    }
}

private enum SocketClientError: LocalizedError {
    case invalidJSON

    var errorDescription: String? {
        "Could not encode the websocket control message."
    }
}

private struct CellularIcon: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3, height: CGFloat(4 + index * 2))
            }
        }
        .foregroundStyle(.black)
        .frame(width: 18, height: 12, alignment: .bottom)
    }
}

private struct WifiIcon: View {
    var body: some View {
        Image(systemName: "wifi")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: 17, height: 13)
    }
}

private struct BatteryIcon: View {
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(.black.opacity(0.35), lineWidth: 1)
                .frame(width: 25, height: 13)

            RoundedRectangle(cornerRadius: 2)
                .fill(.black)
                .frame(width: 21, height: 9)
                .padding(.leading, 2)

            Capsule()
                .fill(.black.opacity(0.4))
                .frame(width: 2, height: 5)
                .offset(x: 26)
        }
        .frame(width: 29, height: 13)
    }
}

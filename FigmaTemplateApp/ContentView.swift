import AVFoundation
import SwiftUI
import Accelerate
import Combine
import EventKit
import OSLog

enum Constants {
    static let sampleAmount: Int = 200
    static let magnitudeLimit: Float = 100
}
let logger = Logger(subsystem: "bisTrip", category: "websocket response")

struct ContentView: View {
    @StateObject private var monitor = AudioModel.shared
    private var activityLevel: CGFloat {
        let peak = monitor.fftMagnitudes.max() ?? 0
        return CGFloat(min(max(peak / Constants.magnitudeLimit, 0), 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            ResponsePanel(
                blocks: monitor.responseBlocks,
                isThinking: monitor.sessionStatus == "Waiting",
                reminderStatus: monitor.reminderStatus,
                onAddReminder: { response in
                    Task { await monitor.addResponseBlockToReminder(response) }
                }
            )
            .frame(maxHeight: .infinity)
            .layoutPriority(1)

            VoiceControlButton(
                isActive: monitor.isConversationActive,
                activityLevel: activityLevel
            ) {
                if monitor.isConversationActive {
                    Task { await monitor.endConversation() }
                } else {
                    Task { await monitor.startConversation() }
                }
            }
            .padding(.bottom, 44)
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

private struct ResponseBlock: Identifiable, Equatable {
    let id: UUID
    var text: String
}

private struct ResponsePanel: View {
    let blocks: [ResponseBlock]
    let isThinking: Bool
    let reminderStatus: String
    let onAddReminder: (String) -> Void

    private var latestResponseText: String {
        blocks.last?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var canAddReminder: Bool {
        !isThinking && !latestResponseText.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 0.46))

                    Text("Liam")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.12))
                }
                .padding(.top, 78)

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    AddReminderButton(
                        canAddReminder: canAddReminder,
                        action: {
                            onAddReminder(latestResponseText)
                        }
                    )

                    if !reminderStatus.isEmpty {
                        Text(reminderStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(red: 0.42, green: 0.44, blue: 0.47))
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .padding(.bottom, 20)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if blocks.isEmpty && isThinking {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(Color(red: 0.12, green: 0.55, blue: 0.46))

                                Text("Thinking...")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(Color(red: 0.42, green: 0.44, blue: 0.47))
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .id("thinking")
                        } else {
                            ForEach(blocks) { block in
                                ResponseBlockView(
                                    text: block.text,
                                    onAddReminder: {
                                        onAddReminder(block.text)
                                    }
                                )
                                    .id(block.id)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.visible)
                .defaultScrollAnchor(.top)
                .onChange(of: blocks) { _, updatedBlocks in
                    scrollToLatest(using: proxy, blocks: updatedBlocks)
                }
                .onChange(of: isThinking) { _, _ in
                    scrollToLatest(using: proxy, blocks: blocks)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
        .background(Color.white)
    }

    private func scrollToLatest(
        using proxy: ScrollViewProxy,
        blocks: [ResponseBlock]
    ) {
        withAnimation(.easeOut(duration: 0.24)) {
            if let latestID = blocks.last?.id {
                proxy.scrollTo(latestID, anchor: .bottom)
            } else if isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            }
        }
    }
}

private struct ResponseBlockView: View {
    let text: String
    let onAddReminder: () -> Void

    private var formattedText: AttributedString {
        let normalized = text.replacingOccurrences(
            of: #"(?m)^(\d+)\.\s*\n\s*"#,
            with: "$1. ",
            options: .regularExpression
        )

        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: normalized, options: options))
            ?? AttributedString(normalized)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(formattedText)
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(6)
                .foregroundStyle(Color(red: 0.20, green: 0.22, blue: 0.24))
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .textSelection(.enabled)
            
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(16)
        .contentShape(Rectangle())
        .contextMenu {
            Button(action: onAddReminder) {
                Label("Add to Reminder", systemImage: "plus.circle")
            }
        }
    }
}

private struct AddReminderButton: View {
    let canAddReminder: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Add to\nReminder")
                .font(.system(size: 17, weight: .regular))
                .lineSpacing(0)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(canAddReminder ? Color.black : Color.black.opacity(0.35))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canAddReminder)
        .accessibilityLabel("Add to Reminder")
    }
}

private struct VoiceControlButton: View {
    let isActive: Bool
    let activityLevel: CGFloat
    let action: () -> Void

    private var accentColor: Color {
        isActive ? Color(red: 0.88, green: 0.19, blue: 0.16) : Color(red: 0.08, green: 0.12, blue: 0.16)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(isActive ? 0.14 : 0.08))
                        .frame(
                            width: 112 + (isActive ? activityLevel * 44 : 0),
                            height: 112 + (isActive ? activityLevel * 44 : 0)
                        )
                        .shadow(
                            color: accentColor.opacity(isActive ? 0.18 : 0.08),
                            radius: 14 + (isActive ? activityLevel * 12 : 0)
                        )
                        .animation(.easeOut(duration: 0.18), value: activityLevel)
                        .animation(.easeOut(duration: 0.18), value: isActive)

                    Circle()
                        .fill(accentColor)
                        .frame(width: 96, height: 96)
                        .shadow(color: accentColor.opacity(isActive ? 0.24 : 0.16), radius: 20, y: 10)

                    Image(systemName: isActive ? "stop.fill" : "waveform")
                        .font(.system(size: isActive ? 28 : 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 140, height: 140)
            }
            .frame(width: 164, height: 164)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isActive ? "End conversation" : "Start conversation")
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

private enum ReminderError: Error {
    case accessDenied
}

enum SummaryClientError: Error, Equatable {
    case emptySummary
    case invalidResponse
}

private enum AudioSessionCoordinator {
    static func activateVoicePipeline() throws {
        let session = AVAudioSession.sharedInstance()
#if targetEnvironment(simulator)
        let mode: AVAudioSession.Mode = .default
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker]
#else
        let mode: AVAudioSession.Mode = .voiceChat
        let options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
#endif
        try session.setCategory(
            .playAndRecord,
            mode: mode,
            options: options
        )
        try session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
    }

    static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }
}

@MainActor
private final class AudioModel: ObservableObject {
    static let shared = AudioModel()
    @Published var isConversationActive = false
    @Published var isMonitoring = false
    @Published var sessionStatus = "Ready"
    @Published var reminderStatus = ""
    @Published private(set) var currentThreadID = ""
    private var audioEngine = AVAudioEngine()
    private let bufferSize = 2048
    private var fftSetup: OpaquePointer?
    private var audioContinuation: AsyncStream<[Float]>.Continuation?
    private var processingTask: Task<Void, Never>?
    private let reminderStore = EKEventStore()
    private let summaryClient = SummaryClient(
        endpoint: URL(string: "http://127.0.0.1:8000/summarize")!
    )
    private let audioAPI = WebSocketAudioAPI(
        endpoint: URL(string: "ws://127.0.0.1:8000/ws/audio")!
    )
    
    private init() {}
    
    
    @Published var fftMagnitudes = [Float](repeating: 0, count: Constants.sampleAmount)
    @Published var responseText = ""
    @Published var responseBlocks: [ResponseBlock] = []

    func startConversation() async {
        guard !isConversationActive else { return }

        isConversationActive = true
        currentThreadID = UUID().uuidString.lowercased()
        responseText = ""
        responseBlocks = []
        reminderStatus = ""
        await startMonitoring()
    }

    func endConversation() async {
        isConversationActive = false
        processingTask?.cancel()
        processingTask = nil
        stopMonitoring(showThinking: false)
        audioAPI.closeConnection()
        AudioSessionCoordinator.deactivate()
        sessionStatus = "Ready"
    }

    private func startMonitoring() async {
        guard isConversationActive else { return }
        guard !isMonitoring else { return }

        let hasPermission = await requestRecordPermission()
        guard hasPermission else {
            isConversationActive = false
            setSingleResponseBlock("Microphone permission is required to capture audio.")
            return
        }

        processingTask?.cancel()
        sessionStatus = "Connecting"
        reminderStatus = ""

        do {
            try AudioSessionCoordinator.activateVoicePipeline()
        } catch {
            isConversationActive = false
            setSingleResponseBlock("Error configuring audio session: \(error.localizedDescription)")
            return
        }

        let inputNode = audioEngine.inputNode
#if targetEnvironment(simulator)
        logger.info("Skipping AVAudioEngine voice processing on Simulator.")
#else
        do {
            try inputNode.setVoiceProcessingEnabled(true)
        } catch {
            print("Voice processing unavailable; using the adaptive dialogue gate: \(error.localizedDescription)")
        }
#endif
        let inputFormat = inputNode.inputFormat(forBus: 0)
        // digital signal peocessing routines on large vectors
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, UInt(self.bufferSize), .FORWARD)
        
        let audioStream = AsyncStream<[Float]>(bufferingPolicy: .bufferingNewest(8)) { continuation in
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
            audioEngine.prepare()
            try audioEngine.start()
            isMonitoring = true
            sessionStatus = "Listening"
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
            isConversationActive = false
            setSingleResponseBlock("Error starting audio engine: \(error.localizedDescription)")
            return
        }

        processingTask = Task { [weak self] in
            guard let self else { return }
            var responseBlockID = UUID()
            var hasReceivedTextForResponseBlock = false

            let paragraph = await self.audioAPI.consume(
                threadID: self.currentThreadID,
                audioStream: audioStream,
                performFFT: { data in
                    await self.performFFT(data: data)
                },
                onText: { text, startsNewBlock in
                    await MainActor.run {
                        if startsNewBlock {
                            if hasReceivedTextForResponseBlock {
                                responseBlockID = UUID()
                            }
                            hasReceivedTextForResponseBlock = false
                        }

                        let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.updateResponseBlock(
                            id: responseBlockID,
                            text: displayText
                        )
                        if self.canDisplayResponseBlock(displayText) {
                            hasReceivedTextForResponseBlock = true
                            self.sessionStatus = "Receiving"
                        }
                    }
                },
                onSilenceDetected: {
                    await MainActor.run {
                        if self.isMonitoring {
                            self.stopMonitoring(
                                showThinking: true,
                                responseBlockID: responseBlockID
                            )
                        }
                    }
                }
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.updateResponseBlock(
                    id: responseBlockID,
                    text: paragraph
                )

                if self.isConversationActive && !Task.isCancelled {
                    self.sessionStatus = "Ready"
                    Task { await self.startMonitoring() }
                } else {
                    self.sessionStatus = "Ready"
                }
            }
        }
    }
    
    private func stopMonitoring(
        showThinking: Bool,
        responseBlockID: UUID? = nil
    ) {
        guard isMonitoring else { return }

        audioEngine.stop()
        
        audioEngine.inputNode.removeTap(onBus: 0)
        audioContinuation?.finish()
        audioContinuation = nil
        
        if showThinking, let responseBlockID {
            updateResponseBlock(
                id: responseBlockID,
                text: "Thinking..."
            )
        }
        sessionStatus = "Waiting"
        
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
            fftSetup = nil
        }
        
        isMonitoring = false

        if !isConversationActive {
            AudioSessionCoordinator.deactivate()
        }
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

    private func updateResponseBlock(id: UUID, text: String) {
        let current = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canDisplayResponseBlock(current) else { return }

        if let index = responseBlocks.firstIndex(where: { $0.id == id }) {
            responseBlocks[index].text = current
        } else {
            responseBlocks.append(ResponseBlock(id: id, text: current))
        }

        responseText = responseBlocks
            .map(\.text)
            .joined(separator: "\n\n")
    }

    private func setSingleResponseBlock(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        responseBlocks = [ResponseBlock(id: UUID(), text: trimmed)]
        responseText = trimmed
    }

    private func canDisplayResponseBlock(_ text: String) -> Bool {
        !text.isEmpty
            && text != "Listening..."
            && !text.hasPrefix("Connected to ")
    }

    func addResponseBlockToReminder(_ responseText: String) async {
        let response = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSaveReminder(from: response) else { return }

        reminderStatus = "Summarizing..."
        do {
            let summary = try await summaryClient.summarize(response)
            guard canSaveReminder(from: summary) else {
                throw SummaryClientError.emptySummary
            }

            reminderStatus = "Adding..."
            try await requestReminderPermission()
            let reminder = EKReminder(eventStore: reminderStore)
            reminder.title = reminderTitle(from: summary)
            reminder.notes = summary
            reminder.calendar = reminderStore.defaultCalendarForNewReminders()
            try reminderStore.save(reminder, commit: true)
            reminderStatus = "Added to Reminders"
        } catch {
            reminderStatus = "Could not add reminder"
            print("Reminder save failed: \(error.localizedDescription)")
        }
    }

    private func canSaveReminder(from text: String) -> Bool {
        !text.isEmpty
            && text != "Listening..."
            && text != "Thinking..."
            && !text.hasPrefix("Connecting to ")
            && !text.hasPrefix("Error ")
            && !text.hasPrefix("WebSocket closed:")
    }

    private func requestReminderPermission() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await reminderStore.requestFullAccessToReminders()
            if !granted {
                throw ReminderError.accessDenied
            }
        } else {
            let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                reminderStore.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
            if !granted {
                throw ReminderError.accessDenied
            }
        }
    }

    private func reminderTitle(from response: String) -> String {
        let firstLine = response
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .replacingOccurrences(of: #"[*_`#>-]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let title = firstLine?.isEmpty == false ? firstLine! : "BizTrip response"
        if title.count <= 80 {
            return title
        }

        return String(title.prefix(77)) + "..."
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

final class SummaryClient {
    private struct SummarizeRequest: Encodable {
        let message: String
    }

    private let endpoint: URL
    private let session: URLSession

    init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    func summarize(_ text: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(SummarizeRequest(message: text))

        let (data, response) = try await session.data(for: request)
        guard
            let httpResponse = response as? HTTPURLResponse,
            200..<300 ~= httpResponse.statusCode
        else {
            throw SummaryClientError.invalidResponse
        }

        let summary = try JSONDecoder().decode(String.self, from: data)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else {
            throw SummaryClientError.emptySummary
        }

        return summary
    }
}

private final class WebSocketAudioAPI {
    private let endpoint: URL
    private let audioPlayer = StreamingAudioPlayer()
    private var socket: URLSessionWebSocketTask?
    private var connectedThreadID: String?

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    func closeConnection() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        connectedThreadID = nil
        audioPlayer.reset()
    }

    func consume(
        threadID: String,
        audioStream: AsyncStream<[Float]>,
        performFFT: @escaping ([Float]) async -> [Float],
        onText: @escaping (String, Bool) async -> Void,
        onSilenceDetected: @escaping () async -> Void
    ) async -> String {
        let socket = socketForSession(threadID: threadID)
        audioPlayer.reset()
        var dialogueGate = DialogueGate()
        var sentEndOfStream = false

        let receiver = Task {
            var latestText = "Listening..."
            var assembler = TextStreamAssembler()
            var lastPublishedText = ""
            var lastPublishedAt = Date.distantPast
            var pendingNewBlock = false
            await onText(latestText, false)

            receiveLoop: while !Task.isCancelled {
                do {
                    let message = try await socket.receive()
                    switch message {
                    case .string(let text):
                        if let audioControl = Self.parseAudioControl(text) {
                            switch audioControl.event {
                            case .start:
                                audioPlayer.configure(
                                    sampleRate: audioControl.sampleRate,
                                    channels: audioControl.channels
                                )
                            case .end:
                                break
                            }
                        }
                        logger.info("received: \(text)")
                        let response = Self.parseResponse(text)
                        if response.startsNewBlock {
                            assembler.reset()
                            latestText = ""
                            lastPublishedText = ""
                            pendingNewBlock = true
                        }

                        if let displayText = response.text, !displayText.isEmpty {
                            assembler.ingest(
                                displayText,
                                isDelta: response.isDelta
                            )
                            latestText = assembler.text

                            let now = Date()
                            let shouldPublish = response.isDone
                                || now.timeIntervalSince(lastPublishedAt) >= 0.06
                            if shouldPublish, latestText != lastPublishedText {
                                await onText(latestText, pendingNewBlock)
                                lastPublishedText = latestText
                                lastPublishedAt = now
                                pendingNewBlock = false
                            }
                        }
                        if response.isDone {
                            break receiveLoop
                        }

                    case .data(let audioData):
                        audioPlayer.enqueue(audioData)

                    @unknown default:
                        continue
                    }
                } catch {
                    if !assembler.text.isEmpty {
                        latestText = assembler.text
                    } else if !Task.isCancelled {
                        latestText = "WebSocket closed: \(error.localizedDescription)"
                        resetSocket()
                    }
                    break
                }
            }

            if !assembler.text.isEmpty, assembler.text != lastPublishedText {
                latestText = assembler.text
                await onText(latestText, pendingNewBlock)
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
                    resetSocket()
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
                    resetSocket()
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
            resetSocket()
            return "Could not finish the audio stream: \(error.localizedDescription)"
        }

        let response = await receiver.value
        return response
    }

    private func socketForSession(threadID: String) -> URLSessionWebSocketTask {
        if
            let socket,
            socket.state == .running,
            connectedThreadID == threadID
        {
            return socket
        }

        resetSocket()
        let socket = URLSession.shared.webSocketTask(
            with: connectionURL(threadID: threadID)
        )
        self.socket = socket
        connectedThreadID = threadID
        socket.resume()
        return socket
    }

    private func resetSocket() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        connectedThreadID = nil
    }

    private func connectionURL(threadID: String) -> URL {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return endpoint
        }

        components.path = endpoint.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .reduce("") { partialPath, component in
                partialPath + "/" + component
            }
        components.path += "/" + threadID

        return components.url ?? endpoint
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
    ) -> (text: String?, isDelta: Bool, isDone: Bool, startsNewBlock: Bool) {
        guard
            let data = rawText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return (rawText, true, false, false)
        }

        let type = (json["type"] as? String)?.lowercased()
        let delta = json["delta"] as? String
        let text = delta
            ?? (json["text"] as? String)
            ?? (json["message"] as? String)
            ?? (json["content"] as? String)
            ?? (json["data"] as? String)
            ?? (json["token"] as? String)
        let isDelta = delta != nil || type?.contains("delta") == true
        let isDone = type == "done"
            || type == "audio_end"
            || type == "error"
            || (type == "response_text" && !isDelta)
            || type?.contains(".done") == true
        let startsNewBlock = type == "response_start"
            || type == "response.start"
            || type == "response.created"
        return (text, isDelta, isDone, startsNewBlock)
    }

    private static func parseAudioControl(_ rawText: String) -> AudioControl? {
        guard
            let data = rawText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawType = json["type"] as? String
        else {
            return nil
        }

        let type = rawType.lowercased()
        if type == "tts_start" || type == "audio_start" {
            let sampleRate = json["sample_rate"] as? Double
                ?? json["sampleRate"] as? Double
                ?? 24_000
            let channels = (json["channels"] as? NSNumber)?.uint32Value ?? 1
            return AudioControl(event: .start, sampleRate: sampleRate, channels: channels)
        }

        if type == "tts_end" {
            return AudioControl(event: .end, sampleRate: 24_000, channels: 1)
        }

        return nil
    }
}

private struct AudioControl {
    enum Event {
        case start
        case end
    }

    let event: Event
    let sampleRate: Double
    let channels: UInt32
}

private final class StreamingAudioPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var format: AVAudioFormat
    private var hasActivatedSession = false

    init() {
        self.format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 24_000,
            channels: 1,
            interleaved: false
        )!
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }

    func configure(sampleRate: Double, channels: UInt32) {
        let nextFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: false
        )
        guard let nextFormat else { return }

        playerNode.stop()
        engine.stop()
        engine.disconnectNodeOutput(playerNode)
        format = nextFormat
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        hasActivatedSession = false
    }

    func enqueue(_ data: Data) {
        guard !data.isEmpty, let buffer = makePCMBuffer(from: data) else { return }

        do {
            try preparePlaybackSession()
            if !engine.isRunning {
                try engine.start()
            }
            if !playerNode.isPlaying {
                playerNode.play()
            }
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
        } catch {
            print("Audio playback failed: \(error.localizedDescription)")
        }
    }

    func reset() {
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        hasActivatedSession = false
    }

    private func preparePlaybackSession() throws {
        guard !hasActivatedSession else { return }

        try AudioSessionCoordinator.activateVoicePipeline()
        engine.prepare()
        hasActivatedSession = true
    }

    private func makePCMBuffer(from data: Data) -> AVAudioPCMBuffer? {
        let bytesPerSample = MemoryLayout<Int16>.size
        let inputChannelCount = max(Int(format.channelCount), 1)
        let frameCount = data.count / bytesPerSample / inputChannelCount
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(frameCount)
        ) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)

        guard let channels = buffer.floatChannelData else { return nil }
        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }

            for frameIndex in 0..<frameCount {
                for channelIndex in 0..<inputChannelCount {
                    let byteIndex = (frameIndex * inputChannelCount + channelIndex) * bytesPerSample
                    let low = UInt16(baseAddress[byteIndex])
                    let high = UInt16(baseAddress[byteIndex + 1]) << 8
                    let intSample = Int16(bitPattern: high | low)
                    channels[channelIndex][frameIndex] = Float(intSample) / Float(Int16.max)
                }
            }
        }

        return buffer
    }
}

struct TextStreamAssembler {
    private(set) var text = ""

    mutating func reset() {
        text = ""
    }

    mutating func ingest(_ fragment: String, isDelta: Bool) {
        guard !fragment.isEmpty else { return }

        if !isDelta {
            text = fragment
            return
        }

        // Some servers label cumulative snapshots as deltas. Replacing the
        // current value avoids duplicated paragraphs in that protocol.
        if fragment.count > text.count, fragment.hasPrefix(text) {
            text = fragment
        } else if fragment != text {
            text += fragment
        }
    }
}

struct DialogueGate {
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

        if !isOpen {
            if containsDialogue {
                isOpen = true
                quietFrameCount = 0
                let bufferedFrames = preRoll + [samples]
                preRoll.removeAll(keepingCapacity: true)
                return Output(frames: bufferedFrames, didDetectEndOfSpeech: false)
            }

            noiseFloor = noiseFloor * 0.95 + rms * 0.05
            preRoll.append(samples)
            if preRoll.count > preRollFrames {
                preRoll.removeFirst()
            }
            return Output(frames: [], didDetectEndOfSpeech: false)
        }

        if containsDialogue {
            quietFrameCount = 0
            return Output(frames: [samples], didDetectEndOfSpeech: false)
        }

        quietFrameCount += 1
        if quietFrameCount <= hangoverFrames {
            return Output(frames: [samples], didDetectEndOfSpeech: false)
        }

        isOpen = false
        quietFrameCount = 0
        return Output(frames: [], didDetectEndOfSpeech: true)
    }
}

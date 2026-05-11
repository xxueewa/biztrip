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
//            PhoneScreen {
//                SignInScreen()
//            }

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

private struct SignInScreen: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(red: 0.851, green: 0.851, blue: 0.851))
                .frame(width: 289, height: 33)
                .position(x: 219.5, y: 238.5)

            Text("Sign In with SSO")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 136, height: 20)
                .position(x: 220, y: 289)
        }
        .frame(width: 440, height: 956)
    }
}

private struct CenterRecordingScreen: View {
    @ObservedObject var model: ConversationModel

    var body: some View {
        ZStack {
            if !model.centerStatusText.isEmpty {
                Text(model.centerStatusText)
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black.opacity(0.72))
                    .frame(width: 320)
                    .position(x: 220, y: 570)
            }

            RecordingButton(size: 124, isRecording: model.isRecordingTranscription) {
                model.toggleTranscriptionRecording()
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

            RecordingButton(size: 65, isRecording: model.isRecordingTextStream) {
                model.toggleTextStreamRecording()
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
    private let api = ChatAPI()
    private let recorder = AudioRecorder()

    @Published var isRecordingTranscription = false
    @Published var isRecordingTextStream = false
    @Published var promptText = "Hi Liam, can you search in our database and provide the brief that I could use in my next meeting?"
    @Published var responseText = "Sure, the following is the summarized company info...."
    @Published var centerStatusText = ""

    private let threadID = "3cfbf39d-8502-4aa1-bff5-f647b788cf89"

    func toggleTranscriptionRecording() {
        Task {
            if isRecordingTranscription {
                await stopTranscriptionRecording()
            } else {
                await startTranscriptionRecording()
            }
        }
    }

    func toggleTextStreamRecording() {
        Task {
            if isRecordingTextStream {
                await stopTextStreamRecording()
            } else {
                await startTextStreamRecording()
            }
        }
    }

    private func startTranscriptionRecording() async {
        do {
            try await recorder.startRecording()
            isRecordingTranscription = true
            centerStatusText = "Recording..."
        } catch {
            centerStatusText = "Microphone unavailable"
            responseText = error.localizedDescription
        }
    }

    private func stopTranscriptionRecording() async {
        recorder.stopRecording()
        isRecordingTranscription = false
        centerStatusText = "Sending..."

        do {
            let answer = try await api.transcribe(threadID: threadID)
            responseText = answer.isEmpty ? responseText : answer
            centerStatusText = "Response ready"
        } catch {
            centerStatusText = "Request failed"
            responseText = error.localizedDescription
        }
    }

    private func startTextStreamRecording() async {
        do {
            try await recorder.startRecording()
            isRecordingTextStream = true
            responseText = "Recording..."
        } catch {
            responseText = error.localizedDescription
        }
    }

    private func stopTextStreamRecording() async {
        recorder.stopRecording()
        isRecordingTextStream = false
        responseText = ""

        do {
            for try await chunk in api.streamText(threadID: threadID) {
                responseText += chunk
            }
        } catch {
            responseText = error.localizedDescription
        }
    }
}

private final class AudioRecorder: NSObject {
    private var recorder: AVAudioRecorder?

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()
        let hasPermission = await requestRecordPermission(session: session)

        guard hasPermission else {
            throw RecordingError.permissionDenied
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("latest-recording")
            .appendingPathExtension("m4a")

        try? FileManager.default.removeItem(at: outputURL)
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        self.recorder = recorder
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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

private enum RecordingError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        "Microphone permission is required to record."
    }
}

private struct ChatAPI {
    private let baseURL = URL(string: "http://127.0.0.1:8000")!

    func transcribe(threadID: String) async throws -> String {
        let data = try await sendJSON(path: "/chat/transcribe", threadID: threadID)
        return parseResponseText(from: data)
    }

    func streamText(threadID: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = makeRequest(path: "/chat/text", threadID: threadID)
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validate(response)

                    for try await line in bytes.lines {
                        let chunk = parseStreamLine(line)
                        if !chunk.isEmpty {
                            continuation.yield(chunk)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func sendJSON(path: String, threadID: String) async throws -> Data {
        let request = makeRequest(path: path, threadID: threadID)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return data
    }

    private func makeRequest(path: String, threadID: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(ChatRequest(threadID: threadID))
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpStatus(httpResponse.statusCode)
        }
    }

    private func parseResponseText(from data: Data) -> String {
        if let payload = try? JSONDecoder().decode(ChatResponse.self, from: data) {
            return payload.bestText
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseStreamLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, trimmed != "data: [DONE]", trimmed != "[DONE]" else {
            return ""
        }

        let payload = trimmed.hasPrefix("data:")
            ? String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            : trimmed

        if let data = payload.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data) {
            return decoded.bestText
        }

        return payload
    }
}

private struct ChatRequest: Encodable {
    let threadID: String

    enum CodingKeys: String, CodingKey {
        case threadID = "thread_id"
    }
}

private struct ChatResponse: Decodable {
    let answer: String?
    let response: String?
    let text: String?
    let content: String?
    let delta: String?
    let message: String?

    var bestText: String {
        answer ?? response ?? text ?? content ?? delta ?? message ?? ""
    }
}

private enum APIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an invalid response."
        case .httpStatus(let status):
            return "The server returned HTTP \(status)."
        }
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

# Figma Template App

SwiftUI iOS prototype generated from a Figma iPhone flow. The app streams microphone audio to a websocket backend and plays response audio streamed back from that connection.

## Features

- SwiftUI implementation of the Figma iPhone layout
- Native microphone recording button states
- WebSocket session at `ws://127.0.0.1:8000/chat/ws/audio/connect`
- Binary websocket frames for raw PCM audio:
  - app to backend: `pcm_s16le`, mono, at the microphone's native sample rate
- Debug copy of each microphone recording saved to the app temp directory as `.pcm`
- JSON websocket control frames for session state, transcript text, agent status, and audio boundaries
- Live response audio playback with `AVAudioEngine`

## Project Structure

```text
FigmaTemplateApp/
  ContentView.swift
  FigmaTemplateAppApp.swift
  Info.plist
FigmaTemplateApp.xcodeproj/
```

## Requirements

- Xcode 15 or newer
- iOS 17 deployment target
- A websocket backend that implements the app contract below

## Running The App

1. Open `FigmaTemplateApp.xcodeproj` in Xcode.
2. Select an iPhone simulator.
3. Start your websocket backend on `ws://127.0.0.1:8000/chat/ws/audio/connect`.
4. Run the app with `Cmd + R`.
5. Allow microphone access when prompted.
6. Tap the mic, speak, then tap again to stop and hear the streamed response.

For local backend access from the iOS Simulator, `127.0.0.1` points to your Mac.

Each recording is also written to the app sandbox temp directory as raw PCM16 mono 16 kHz audio. The app prints the full temp file path to the Xcode console and shows it in the status text after recording stops.

## WebSocket Contract

Every app-to-server frame is binary so the backend can read it with
`websocket.receive_bytes()`. Each frame contains raw, headerless signed 16-bit
little-endian mono PCM at the microphone's native sample rate.

The app sends a zero-length binary frame after dialogue has started and the
adaptive gate detects sustained silence. Recording then stops automatically.
Manual stop uses the same marker. The backend should accumulate non-empty
frames as one utterance and treat the empty frame as the end-of-stream marker
before running transcription.

The backend may respond with these JSON frame types:

```text
recording_started
speech_end
transcript
agent_started
response_text
audio_start
audio_end
done
error
```

Binary frames received after `audio_start` are treated as response PCM audio for playback. The app uses the `sample_rate` from the `audio_start` JSON frame, defaulting to 24 kHz when it is omitted.

## License

MIT

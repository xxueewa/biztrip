# Figma Template App

SwiftUI iOS prototype that streams microphone audio to a WebSocket backend and visualizes streamed text responses.

## Features

- SwiftUI implementation of the Figma iPhone layout
- Native microphone recording button states
- WebSocket session at `ws://127.0.0.1:8000/chat/ws/audio/connect`
- Binary websocket frames for raw PCM audio:
  - app to backend: `pcm_s16le`, mono, at the microphone's native sample rate
- Adaptive dialogue gate with automatic silence detection
- Streamed plain-text and JSON response visualization

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
6. Tap the mic and speak. Recording stops after sustained silence, or you can stop it manually.

For local backend access from the iOS Simulator, `127.0.0.1` points to your Mac.

## WebSocket Contract

Every app-to-server frame is binary so the backend can read it with
`websocket.receive_bytes()`. Each frame contains raw, headerless signed 16-bit
little-endian mono PCM at the microphone's native sample rate.

The app sends a zero-length binary frame after dialogue has started and the
adaptive gate detects sustained silence. Recording then stops automatically.
Manual stop uses the same marker. The backend should accumulate non-empty
frames as one utterance and treat the empty frame as the end-of-stream marker
before running transcription.

The backend can stream plain-text frames, or JSON delta frames:

```json
{"type":"response.delta","delta":"Hello "}
{"type":"response.delta","delta":"world."}
{"type":"response.done","text":"Hello world."}
```

The server may instead send one complete response:

```json
{"type":"response_text","text":"Hello world."}
```

For a plain-text stream, close the WebSocket normally after the final frame.

## License

MIT

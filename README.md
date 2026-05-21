# Figma Template App

SwiftUI iOS prototype generated from a Figma iPhone flow. The app streams microphone audio to a websocket backend and plays response audio streamed back from that connection.

## Features

- SwiftUI implementation of the Figma iPhone layout
- Native microphone recording button states
- WebSocket session at `ws://127.0.0.1:8000/ws/conversation`
- Binary websocket frames for raw PCM audio:
  - app to backend: `pcm_s16le`, mono, 16 kHz microphone chunks
  - backend to app: `pcm_s16le`, mono response chunks
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
3. Start your websocket backend on `ws://127.0.0.1:8000/ws/conversation`.
4. Run the app with `Cmd + R`.
5. Allow microphone access when prompted.
6. Tap the mic, speak, then tap again to stop and hear the streamed response.

For local backend access from the iOS Simulator, `127.0.0.1` points to your Mac.

Each recording is also written to the app sandbox temp directory as raw PCM16 mono 16 kHz audio. The app prints the full temp file path to the Xcode console and shows it in the status text after recording stops.

## WebSocket Contract

The app sends a JSON frame before audio:

```json
{
  "type": "start_audio",
  "thread_id": "3cfbf39d-8502-4aa1-bff5-f647b788cf89",
  "sample_rate": 16000,
  "encoding": "pcm_s16le"
}
```

It then sends binary PCM frames while recording. When the user stops, it sends:

```json
{
  "type": "stop_audio",
  "thread_id": "3cfbf39d-8502-4aa1-bff5-f647b788cf89"
}
```

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

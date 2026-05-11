# Figma Template App

SwiftUI iOS prototype generated from a Figma iPhone flow. The app presents a swipeable two-screen experience with native recording controls and FastAPI chat integration.

## Features

- SwiftUI implementation of the Figma iPhone layout
- Swipeable page flow using `TabView`
- Native microphone recording button states
- FastAPI request integration for:
  - `POST http://127.0.0.1:8000/chat/transcribe`
  - `POST http://127.0.0.1:8000/chat/text`
- Streaming text response support for the response screen
- Local development HTTP networking and microphone permission configured in `Info.plist`

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
- FastAPI backend running locally on port `8000`

## Running The App

1. Open `FigmaTemplateApp.xcodeproj` in Xcode.
2. Select an iPhone simulator.
3. Run with `Cmd + R`.
4. Allow microphone access when prompted.

For local backend access from the iOS Simulator, `http://127.0.0.1:8000` points to your Mac.

## Backend Contract

Both endpoints currently receive the same JSON body:

```json
{
  "thread_id": "3cfbf39d-8502-4aa1-bff5-f647b788cf89"
}
```

The `/chat/text` endpoint may return plain streamed text, Server-Sent Events lines such as `data: ...`, or JSON chunks with one of these fields:

```text
answer, response, text, content, delta, message
```

## Notes

The app records audio locally to drive the recording UI, but the current sample API payload only sends `thread_id`. If the backend later expects uploaded audio, update `ChatAPI` to send multipart form data.

## License

MIT

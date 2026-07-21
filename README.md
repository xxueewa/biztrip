# BizTrip Voice Assistant Mobile App

BizTripMobile is a SwiftUI iOS prototype for bizTrip voice assistance. It records a spoken request, streams microphone audio to a local WebSocket service, displays the assistant response as it arrives, and can turn an individual response into an Apple Reminder.

## How the application was developed with Codex

The application is a vibe-coding project, it built iteratively though the my conversation with the coding agent. At the beginning, I provide the agent  with a static SwiftUI implementation of the Figma iPhone layout, and the audio data flow design. The recording control and microphone permission flow were added next, followed by an `AVAudioEngine` capture pipeline and Accelerate/vDSP frequency analysis for the visual activity indicator.

The networking layer then evolved from a basic audio connection into a conversational WebSocket client. Audio is converted to signed 16-bit little-endian PCM, sent as binary frames, and terminated with an empty frame when silence is detected. The response pipeline supports incremental JSON deltas, cumulative snapshots, complete messages, and binary audio playback. A thread identifier keeps successive utterances in the same conversation.

Later iterations improved the response UI, added multiple response blocks, automatic scrolling, simulator-safe audio behavior, and bounded audio buffering. The reminder workflow was then introduced: users can select a response, send it to the summarization endpoint, request EventKit access, and save the returned summary as a reminder.

Finally, the core non-UI behavior was made testable. The summary client accepts an injected `URLSession`, and XCTest coverage was added for its HTTP contract, streamed-text assembly, and dialogue-gate transitions. During that work, token spacing and speech pre-roll defects were identified and corrected.

Codex performs well with a clear understanding of requirements even with ambiguous illustration. During the analyze of entire repo, it breaks down the context into managable blocks and reviews the code based on commits. This reveals its ability of handling long-horizon context, and conducting professioanl analysis of projects. The average code changes could be delivered within 1 minute, with the prompt up approval requests to control the risk. The entire process is smooth and productive, and its cost, latency, and token usage scores are much higher than other coding agents.   

## Requirements

- Xcode 15 or newe- iOS 17 or newer
- Microphone and Reminders permissions
- A compatible HTTP and WebSocket backend

The app currently uses local development endpoints:

- WebSocket: `ws://127.0.0.1:8000/ws/audio/{thread-id}`
- Summarization: `http://127.0.0.1:8000/summarize`

These loopback addresses work when the backend and iOS Simulator run on the same Mac. On a physical iPhone, replace them with a configurable hostname or an address reachable from the device.

## Backend contracts

### Audio WebSocket

The app connects to `/ws/audio/{thread-id}` and sends headerless, signed 16-bit little-endian PCM in binary WebSocket frames. A zero-length binary frame marks the end of an utterance while leaving the socket available for the response.

The response is a event stream with json objects:

Finish the audio stream with `{"type":"tts_end"}`.

### Summarization HTTP API

The app sends:

```http
POST /summarize
Content-Type: application/json
Accept: application/json
```

```json
{"message":"Assistant response to summarize"}
```

The successful response body is a JSON string:

```json
"Concise reminder text"
```

## Tests and static analysis

Run the unit tests from Xcode with **Command-U**, or from the command line when an iOS Simulator runtime is installed:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
  -project FigmaTemplateApp.xcodeproj \
  -scheme FigmaTemplateApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

The test suite covers the summarization HTTP request and errors, streamed-text assembly, and dialogue-gate behavior. PMD is a Java analyzer and is not applicable to this Swift project. Use Xcode compiler warnings/static analysis or add SwiftLint for additional Swift-specific rules.

## License

MIT

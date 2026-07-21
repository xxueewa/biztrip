import XCTest
@testable import FigmaTemplateApp

final class SummaryClientTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        URLProtocolStub.requestHandler = nil
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testSummarizeSendsExpectedRequestAndReturnsTrimmedSummary() async throws {
        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: String]
            )
            XCTAssertEqual(json, ["message": "Book the morning flight"])

            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data(#""  Book the morning flight  ""#.utf8))
        }

        let client = SummaryClient(
            endpoint: URL(string: "https://example.test/summarize")!,
            session: session
        )

        let summary = try await client.summarize("Book the morning flight")

        XCTAssertEqual(summary, "Book the morning flight")
    }

    func testSummarizeRejectsNonSuccessResponse() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data())
        }
        let client = SummaryClient(
            endpoint: URL(string: "https://example.test/summarize")!,
            session: session
        )

        do {
            _ = try await client.summarize("Travel plan")
            XCTFail("Expected an invalid-response error")
        } catch let error as SummaryClientError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }

    func testSummarizeRejectsWhitespaceOnlySummary() async throws {
        URLProtocolStub.requestHandler = { request in
            let response = try XCTUnwrap(
                HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            )
            return (response, Data(#""   ""#.utf8))
        }
        let client = SummaryClient(
            endpoint: URL(string: "https://example.test/summarize")!,
            session: session
        )

        do {
            _ = try await client.summarize("Travel plan")
            XCTFail("Expected an empty-summary error")
        } catch let error as SummaryClientError {
            XCTAssertEqual(error, .emptySummary)
        }
    }
}

final class TextStreamAssemblerTests: XCTestCase {
    func testDeltaFragmentsPreserveServerProvidedSpacing() {
        var assembler = TextStreamAssembler()

        assembler.ingest("Book", isDelta: true)
        assembler.ingest(" the flight", isDelta: true)

        XCTAssertEqual(assembler.text, "Book the flight")
    }

    func testCumulativeDeltaReplacesExistingText() {
        var assembler = TextStreamAssembler()
        assembler.ingest("Book", isDelta: true)

        assembler.ingest("Book the flight", isDelta: true)

        XCTAssertEqual(assembler.text, "Book the flight")
    }

    func testSnapshotReplacesExistingTextAndResetClearsIt() {
        var assembler = TextStreamAssembler()
        assembler.ingest("Old", isDelta: true)
        assembler.ingest("Final answer", isDelta: false)
        XCTAssertEqual(assembler.text, "Final answer")

        assembler.reset()

        XCTAssertEqual(assembler.text, "")
    }
}

final class DialogueGateTests: XCTestCase {
    func testQuietAudioDoesNotOpenGate() {
        var gate = DialogueGate()

        let output = gate.process(samples: samples(amplitude: 0.001))

        XCTAssertTrue(output.frames.isEmpty)
        XCTAssertFalse(output.didDetectEndOfSpeech)
    }

    func testSpeechOpensGateAndIncludesPreRollAndCurrentFrame() {
        var gate = DialogueGate()
        let preRoll = samples(amplitude: 0.001)
        _ = gate.process(samples: preRoll)

        let speech = samples(amplitude: 0.04)
        let output = gate.process(samples: speech)

        XCTAssertEqual(output.frames, [preRoll, speech])
        XCTAssertFalse(output.didDetectEndOfSpeech)
    }

    func testGateClosesAfterHangoverFrames() {
        var gate = DialogueGate()
        _ = gate.process(samples: samples(amplitude: 0.04))

        let firstQuiet = gate.process(samples: samples(amplitude: 0))
        let secondQuiet = gate.process(samples: samples(amplitude: 0))
        let closingQuiet = gate.process(samples: samples(amplitude: 0))

        XCTAssertEqual(firstQuiet.frames.count, 1)
        XCTAssertEqual(secondQuiet.frames.count, 1)
        XCTAssertTrue(closingQuiet.frames.isEmpty)
        XCTAssertTrue(closingQuiet.didDetectEndOfSpeech)
    }

    private func samples(amplitude: Float) -> [Float] {
        [Float](repeating: amplitude, count: 256)
    }
}

private final class URLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

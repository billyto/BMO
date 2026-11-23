import XCTest
@testable import BMOLib

/// The real Wiktionary lookup against canned HTTP responses: only a 404
/// means "no entry"; any other failure must throw so it isn't cached and
/// the export can stop.
final class WiktionaryLookupTests: XCTestCase {

    override func tearDown() {
        CannedResponseProtocol.statusCode = 200
        CannedResponseProtocol.body = Data()
        super.tearDown()
    }

    private func makeLookup(status: Int, body: String = "") -> WiktionaryWordClassLookup {
        CannedResponseProtocol.statusCode = status
        CannedResponseProtocol.body = Data(body.utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CannedResponseProtocol.self]
        return WiktionaryWordClassLookup(session: URLSession(configuration: config))
    }

    func testSuccessIsParsed() async throws {
        let lookup = makeLookup(status: 200, body: #"{"da": [{"partOfSpeech": "Noun"}]}"#)
        let classes = try await lookup.wordClasses(for: "hus")
        XCTAssertEqual(classes, [.noun])
    }

    func testNotFoundMeansNoEntry() async throws {
        let classes = try await makeLookup(status: 404).wordClasses(for: "xyzzy")
        XCTAssertEqual(classes, [])
    }

    func testRateLimitAndServerErrorsThrow() async {
        for status in [429, 500, 503] {
            do {
                _ = try await makeLookup(status: status).wordClasses(for: "hus")
                XCTFail("HTTP \(status) should throw, not read as 'no entry'")
            } catch {}
        }
    }

    func testServerErrorIsNotCachedAndCountsAsFailure() async {
        let service = DanishWordClassService(lookup: makeLookup(status: 503))
        let result = await service.lookup("hus")
        XCTAssertEqual(result, .failed)
    }
}

/// Answers every request with the configured status and body.
private final class CannedResponseProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: Self.statusCode, httpVersion: nil, headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

import XCTest
@testable import BMOLib

final class PhoneticsServiceTests: XCTestCase {

    var sut: PhoneticsService!
    var mockRunner: MockPhoneticsRunner!

    override func setUp() {
        super.setUp()
        mockRunner = MockPhoneticsRunner()
        sut = PhoneticsService(runner: mockRunner)
    }

    override func tearDown() {
        sut = nil
        mockRunner = nil
        super.tearDown()
    }

    func testIPAReturnsRunnerOutput() async throws {
        mockRunner.mockIPA = "/hɛjˀ/"

        let result = try await sut.ipa(for: "Hej", language: .danish)

        XCTAssertEqual(result, "/hɛjˀ/")
        XCTAssertEqual(mockRunner.lastText, "Hej")
        XCTAssertEqual(mockRunner.lastLanguage, .danish)
    }

    func testIPATrimsWhitespaceBeforeRunning() async throws {
        _ = try await sut.ipa(for: "  Hej verden  ", language: .danish)

        XCTAssertEqual(mockRunner.lastText, "Hej verden")
    }

    func testIPAWithEmptyTextThrowsWithoutCallingRunner() async {
        do {
            _ = try await sut.ipa(for: "   ", language: .danish)
            XCTFail("Expected error")
        } catch let error as PhoneticsError {
            XCTAssertEqual(error, .emptyText)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertNil(mockRunner.lastText, "Runner should not be invoked for empty input")
    }

    func testIPAPropagatesToolNotInstalledError() async {
        mockRunner.errorToThrow = .toolNotInstalled

        do {
            _ = try await sut.ipa(for: "Hej", language: .danish)
            XCTFail("Expected error")
        } catch let error as PhoneticsError {
            XCTAssertEqual(error, .toolNotInstalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testIPAPropagatesProcessFailedError() async {
        mockRunner.errorToThrow = .processFailed

        do {
            _ = try await sut.ipa(for: "Hej", language: .danish)
            XCTFail("Expected error")
        } catch let error as PhoneticsError {
            XCTAssertEqual(error, .processFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mock Phonetics Runner

final class MockPhoneticsRunner: PhoneticsRunner, @unchecked Sendable {
    var mockIPA: String = "/mɔk/"
    var errorToThrow: PhoneticsError?

    var lastText: String?
    var lastLanguage: Language?

    func run(text: String, language: Language) async throws -> String {
        lastText = text
        lastLanguage = language

        if let errorToThrow {
            throw errorToThrow
        }
        return mockIPA
    }
}

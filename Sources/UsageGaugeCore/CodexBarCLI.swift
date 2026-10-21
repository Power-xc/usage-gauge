import Foundation

public enum UsageFetchError: Error, Equatable {
    case cliNotFound
    case timedOut
    case cliFailed(status: Int32)
    case invalidOutput

    /// Short Korean message for the gauge header.
    public var message: String {
        switch self {
        case .cliNotFound: "codexbar를 찾을 수 없음"
        case .timedOut: "응답 시간 초과"
        case .cliFailed: "codexbar 실행 실패"
        case .invalidOutput: "응답 해석 실패"
        }
    }
}

/// Runs the CodexBar CLI, which owns provider sign-in, and returns decoded usage.
public struct CodexBarCLI: Sendable {
    public static let defaultSearchPaths = ["/opt/homebrew/bin/codexbar", "/usr/local/bin/codexbar"]
    public static let defaultTimeout: TimeInterval = 90

    public let executableURL: URL
    public let timeout: TimeInterval

    public init(executableURL: URL, timeout: TimeInterval = defaultTimeout) {
        self.executableURL = executableURL
        self.timeout = timeout
    }

    public static func locate(in paths: [String] = defaultSearchPaths) -> CodexBarCLI? {
        paths.first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { CodexBarCLI(executableURL: URL(fileURLWithPath: $0)) }
    }

    public func fetchUsage() throws -> [ProviderUsage] {
        let process = Process()
        process.executableURL = executableURL
        // No --provider flag: CodexBar reports every provider enabled in its settings.
        process.arguments = ["usage", "--format", "json"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        // Read before waiting so a large payload cannot fill the pipe and stall the child.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard finished.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            throw UsageFetchError.timedOut
        }
        // CodexBar exits non-zero when one provider fails but still prints the others.
        guard !data.isEmpty else { throw UsageFetchError.cliFailed(status: process.terminationStatus) }
        do {
            return try CodexBarDecoder.decode(data)
        } catch {
            throw UsageFetchError.invalidOutput
        }
    }
}

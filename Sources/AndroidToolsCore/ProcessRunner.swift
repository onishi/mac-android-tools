import Foundation

public struct ProcessResult: Equatable {
    public let output: String
    public let error: String
    public let status: Int32
}

public enum ProcessRunner {
    @discardableResult
    public static func run(_ executable: URL, _ arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        return ProcessResult(
            output: String(decoding: outputPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            error: String(decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            status: process.terminationStatus
        )
    }
}

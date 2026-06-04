import Foundation
import OSLog

public enum SagaLogLevel: String, CaseIterable, Sendable {
    case trace
    case debug
    case info
    case warning
    case error
    case critical

    public var emoji: String {
        switch self {
            case .trace: "🔍"
            case .debug: "🐛"
            case .info: "ℹ️"
            case .warning: "⚠️"
            case .error: "❌"
            case .critical: "🚨"
        }
    }

    var osLogType: OSLogType {
        switch self {
            case .trace, .debug:
                .debug
            case .info:
                .info
            case .warning:
                .default
            case .error:
                .error
            case .critical:
                .fault
        }
    }
}

public struct SagaLogMetadata: Sendable {
    public let file: String
    public let function: String
    public let line: Int

    public init(
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        self.file = file
        self.function = function
        self.line = line
    }
}

public protocol SagaLogging: Sendable {
    func log(
        _ level: SagaLogLevel,
        _ message: @autoclosure () -> String,
        metadata: SagaLogMetadata
    )

    func logError(
        _ error: Error,
        _ message: @autoclosure () -> String?,
        metadata: SagaLogMetadata
    )
}

public extension SagaLogging {
    func log(
        level: SagaLogLevel,
        message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level,
            message(),
            metadata: SagaLogMetadata(file: file, function: function, line: line)
        )
    }

    func log(
        _ level: SagaLogLevel,
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            level,
            message(),
            metadata: SagaLogMetadata(file: file, function: function, line: line)
        )
    }

    func trace(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.trace, message(), metadata: SagaLogMetadata(file: file, function: function, line: line))
    }

    func debug(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.debug, message(), metadata: SagaLogMetadata(file: file, function: function, line: line))
    }

    func info(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.info, message(), metadata: SagaLogMetadata(file: file, function: function, line: line))
    }

    func warn(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.warning, message(), metadata: SagaLogMetadata(file: file, function: function, line: line))
    }

    func warning(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        warn(message(), file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.error, message(), metadata: SagaLogMetadata(file: file, function: function, line: line))
    }

    func critical(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(.critical, message(), metadata: SagaLogMetadata(file: file, function: function, line: line))
    }

    func logError(
        _ error: Error,
        _ message: @autoclosure () -> String? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        logError(
            error,
            message(),
            metadata: SagaLogMetadata(file: file, function: function, line: line)
        )
    }
}

public protocol SagaLogWriting: Sendable {
    func write(
        level: SagaLogLevel,
        message: String,
        metadata: SagaLogMetadata
    )
}

public enum SagaLogDestination: Sendable {
    case osLog(subsystem: String, category: String)
    case print
    case custom(any SagaLogWriting)
    case composite([SagaLogDestination])
}

public final class SagaLogger: SagaLogging, @unchecked Sendable {
    public static let shared = SagaLogger()

    private let destination: SagaLogDestination

    public init(destination: SagaLogDestination = .osLog(
        subsystem: Bundle.main.bundleIdentifier ?? "Saga",
        category: "App"
    )) {
        self.destination = destination
    }

    public func log(
        _ level: SagaLogLevel,
        _ message: @autoclosure () -> String,
        metadata: SagaLogMetadata
    ) {
        write(
            level: level,
            message: message(),
            metadata: metadata
        )
    }

    public func logError(
        _ error: Error,
        _ message: @autoclosure () -> String?,
        metadata: SagaLogMetadata
    ) {
        let prefix = message().map { "\($0): " } ?? ""
        write(
            level: .error,
            message: "\(prefix)\(error.localizedDescription)",
            metadata: metadata
        )
    }

    private func write(
        level: SagaLogLevel,
        message: String,
        metadata: SagaLogMetadata
    ) {
        write(
            level: level,
            message: message,
            metadata: metadata,
            destination: destination
        )
    }

    private func write(
        level: SagaLogLevel,
        message: String,
        metadata: SagaLogMetadata,
        destination: SagaLogDestination
    ) {
        switch destination {
            case let .osLog(subsystem, category):
                let formattedMessage = format(level: level, message: message, metadata: metadata)
                Logger(subsystem: subsystem, category: category)
                    .log(level: level.osLogType, "\(formattedMessage, privacy: .public)")
            case .print:
                print(format(level: level, message: message, metadata: metadata))
            case let .custom(writer):
                writer.write(level: level, message: message, metadata: metadata)
            case let .composite(destinations):
                for destination in destinations {
                    write(level: level, message: message, metadata: metadata, destination: destination)
                }
        }
    }

    private func format(
        level: SagaLogLevel,
        message: String,
        metadata: SagaLogMetadata
    ) -> String {
        "\(level.emoji) [\(level.rawValue.uppercased())] \(message) - \(metadata.file):\(metadata.line) \(metadata.function)"
    }
}

public struct SagaNoopLogger: SagaLogging {
    public init() {}

    public func log(
        _ level: SagaLogLevel,
        _ message: @autoclosure () -> String,
        metadata: SagaLogMetadata
    ) {}

    public func logError(
        _ error: Error,
        _ message: @autoclosure () -> String?,
        metadata: SagaLogMetadata
    ) {}
}

public let log: any SagaLogging = SagaLogger.shared

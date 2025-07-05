#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Errors that can occur during YAML parsing and processing.
public enum YAMLError: Error, LocalizedError {
    case invalidYAML(String)
    case unexpectedToken(String, line: Int, column: Int)
    case indentationError(String, line: Int)
    case unclosedQuote(line: Int)
    case invalidEscape(String, line: Int)
    
    public var errorDescription: String? {
        switch self {
        case .invalidYAML(let message):
            return "Invalid YAML: \(message)"
        case .unexpectedToken(let token, let line, let column):
            return "Unexpected token '\(token)' at line \(line), column \(column)"
        case .indentationError(let message, let line):
            return "Indentation error at line \(line): \(message)"
        case .unclosedQuote(let line):
            return "Unclosed quote at line \(line)"
        case .invalidEscape(let sequence, let line):
            return "Invalid escape sequence '\(sequence)' at line \(line)"
        }
    }
}
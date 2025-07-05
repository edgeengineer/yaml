#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A token representing a YAML event in the stream.
public enum YAMLToken: Sendable, Equatable {
    /// Start of a YAML document
    case documentStart
    /// End of a YAML document
    case documentEnd
    /// Start of a mapping
    case mappingStart
    /// End of a mapping
    case mappingEnd
    /// Start of a sequence
    case sequenceStart
    /// End of a sequence
    case sequenceEnd
    /// A key in a mapping
    case key(String)
    /// A scalar value
    case scalar(YAMLNode.Scalar)
}

/// A streaming YAML parser that processes documents token by token.
/// This is useful for parsing large YAML files without loading the entire document into memory.
public final class YAMLStreamParser {
    private var scanner: Scanner
    private var currentIndentStack: [Int] = []
    private var containerStack: [ContainerType] = []
    
    private enum ContainerType {
        case mapping
        case sequence
        case document
    }
    
    /// Delegate for receiving parsing events
    public weak var delegate: YAMLStreamParserDelegate?
    
    /// Creates a new streaming parser.
    public init() {
        self.scanner = Scanner(text: "")
    }
    
    /// Parses a YAML string in streaming mode.
    /// - Parameter yaml: The YAML string to parse
    /// - Throws: YAMLError if the input is not valid YAML
    public func parse(_ yaml: String) throws {
        self.scanner = Scanner(text: yaml)
        
        var isFirstDocument = true
        
        while !scanner.isAtEnd {
            // Reset state for each document
            currentIndentStack = [0]
            containerStack = [.document]
            
            // Skip any leading whitespace and comments
            skipEmptyLinesAndComments()
            
            if scanner.isAtEnd {
                break
            }
            
            // Check for document separator
            if checkDocumentSeparator() {
                // Skip the separator
                _ = scanner.advance() // -
                _ = scanner.advance() // -
                _ = scanner.advance() // -
                scanner.skipToEndOfLine()
                if scanner.peek() == "\n" {
                    _ = scanner.advance()
                }
                skipEmptyLinesAndComments()
                
                // If at end after separator, that's an empty document
                if scanner.isAtEnd {
                    delegate?.parserDidStartDocument(self)
                    try emitToken(.documentStart)
                    try emitToken(.documentEnd)
                    delegate?.parserDidEndDocument(self)
                    break
                }
            } else if !isFirstDocument {
                // If not the first document and no separator, we're done
                break
            }
            
            // Start the document
            delegate?.parserDidStartDocument(self)
            try emitToken(.documentStart)
            
            // Parse document content
            while !scanner.isAtEnd {
                // Check if we've hit another document separator
                if checkDocumentSeparator() {
                    break
                }
                
                try parseNext()
            }
            
            // Close any open containers
            while containerStack.count > 1 {
                try closeCurrentContainer()
            }
            
            try emitToken(.documentEnd)
            delegate?.parserDidEndDocument(self)
            
            isFirstDocument = false
        }
    }
    
    /// Parses a YAML file from a URL in streaming mode.
    /// - Parameter url: The URL of the YAML file
    /// - Throws: YAMLError if the input is not valid YAML or if file cannot be read
    public func parse(contentsOf url: URL) throws {
        let yaml = try String(contentsOf: url, encoding: .utf8)
        try parse(yaml)
    }
    
    /// Parses YAML data from an input stream.
    /// - Parameter inputStream: The input stream to read from
    /// - Throws: YAMLError if the input is not valid YAML
    public func parse(from inputStream: InputStream) throws {
        inputStream.open()
        defer { inputStream.close() }
        
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        var yamlData = Data()
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                yamlData.append(buffer, count: bytesRead)
            } else if bytesRead < 0 {
                throw YAMLError.invalidYAML("Error reading from input stream")
            }
        }
        
        guard let yamlString = String(data: yamlData, encoding: .utf8) else {
            throw YAMLError.invalidYAML("Invalid UTF-8 data in stream")
        }
        
        try parse(yamlString)
    }
    
    private func parseNext() throws {
        skipEmptyLinesAndComments()
        
        guard !scanner.isAtEnd else { return }
        
        let currentIndent = scanner.currentIndentation()
        
        // Check if we need to close containers based on indentation
        while let lastIndent = currentIndentStack.last, currentIndent < lastIndent {
            try closeCurrentContainer()
        }
        
        scanner.skipWhitespace()
        
        guard let firstChar = scanner.peek() else { return }
        
        switch firstChar {
        case "-":
            try parseSequenceItem(indent: currentIndent)
        case "\"", "'":
            try parseQuotedValue(quote: firstChar)
        case "|":
            try parseLiteralScalar(indent: currentIndent)
        case ">":
            try parseFoldedScalar(indent: currentIndent)
        default:
            // Check if this is a mapping
            let line = scanner.currentLineContent().trimmingCharacters(in: .whitespaces)
            if line.contains(": ") || line.hasSuffix(":") {
                try parseMappingEntry(indent: currentIndent)
            } else {
                try parsePlainScalar()
            }
        }
    }
    
    private func parseSequenceItem(indent: Int) throws {
        // If we're not in a sequence, start one
        if containerStack.last != .sequence {
            try emitToken(.sequenceStart)
            containerStack.append(.sequence)
            currentIndentStack.append(indent)
        }
        
        _ = scanner.advance() // Skip '-'
        scanner.skipWhitespace()
        
        // Parse the value after the dash
        if scanner.peek() == "\n" || scanner.isAtEnd {
            try emitToken(.scalar(.init(value: "", tag: .null)))
            _ = scanner.advance()
        } else {
            try parseValue()
        }
    }
    
    private func parseMappingEntry(indent: Int) throws {
        // If we're not in a mapping, start one
        if containerStack.last != .mapping {
            try emitToken(.mappingStart)
            containerStack.append(.mapping)
            currentIndentStack.append(indent)
        }
        
        // Parse key
        let key = try parseKey()
        try emitToken(.key(key))
        
        scanner.skipWhitespace()
        
        guard scanner.peek() == ":" else {
            throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                          line: scanner.currentLine, 
                                          column: scanner.currentColumn)
        }
        
        _ = scanner.advance() // Skip ':'
        scanner.skipWhitespace()
        
        // Parse value
        if scanner.peek() == "\n" || scanner.isAtEnd {
            _ = scanner.advance()
            skipEmptyLinesAndComments()
            
            let nextIndent = scanner.currentIndentation()
            if nextIndent > indent {
                // Nested structure follows
                return // Will be parsed in next iteration
            } else {
                try emitToken(.scalar(.init(value: "", tag: .null)))
            }
        } else {
            try parseValue()
            if scanner.peek() == "\n" {
                _ = scanner.advance()
            }
        }
    }
    
    private func parseValue() throws {
        guard let firstChar = scanner.peek() else {
            try emitToken(.scalar(.init(value: "", tag: .null)))
            return
        }
        
        switch firstChar {
        case "\"", "'":
            try parseQuotedValue(quote: firstChar)
        case "|":
            try parseLiteralScalar(indent: scanner.currentIndentation())
        case ">":
            try parseFoldedScalar(indent: scanner.currentIndentation())
        case "-":
            // This is a nested sequence
            return // Will be handled in next iteration
        default:
            // Check if this is a nested mapping
            let savedPosition = (scanner.lineIndex, scanner.columnIndex)
            var tempValue = ""
            
            while let char = scanner.peek(), char != "\n" && char != "#" {
                tempValue.append(char)
                _ = scanner.advance()
            }
            
            if tempValue.contains(": ") {
                // Restore position, this is a nested mapping
                scanner.lineIndex = savedPosition.0
                scanner.columnIndex = savedPosition.1
                return // Will be handled in next iteration
            } else {
                // It's a plain scalar
                let value = tempValue.trimmingCharacters(in: .whitespaces)
                let tag = detectScalarType(value)
                try emitToken(.scalar(.init(value: value, tag: tag)))
            }
        }
    }
    
    private func parseKey() throws -> String {
        var key = ""
        
        if scanner.peek() == "\"" || scanner.peek() == "'" {
            let quote = scanner.peek()!
            _ = scanner.advance()
            
            while let char = scanner.peek(), char != quote {
                if char == "\\" && quote == "\"" {
                    _ = scanner.advance()
                    if let escaped = scanner.peek() {
                        key.append(try parseEscapeSequence(escaped))
                        _ = scanner.advance()
                    }
                } else {
                    key.append(char)
                    _ = scanner.advance()
                }
            }
            
            if scanner.peek() == quote {
                _ = scanner.advance()
            } else {
                throw YAMLError.unclosedQuote(line: scanner.currentLine)
            }
        } else {
            while let char = scanner.peek(), char != ":" && char != "\n" {
                key.append(char)
                _ = scanner.advance()
            }
            key = key.trimmingCharacters(in: .whitespaces)
        }
        
        return key
    }
    
    private func parsePlainScalar() throws {
        var value = ""
        var prevChar: Character? = nil
        
        while let char = scanner.peek(), char != "\n" {
            if char == "#" && (prevChar == nil || prevChar == " " || prevChar == "\t") {
                break
            }
            value.append(char)
            prevChar = char
            _ = scanner.advance()
        }
        
        value = value.trimmingCharacters(in: .whitespaces)
        
        let tag = detectScalarType(value)
        try emitToken(.scalar(.init(value: value, tag: tag)))
        
        if scanner.peek() == "\n" {
            _ = scanner.advance()
        }
    }
    
    private func parseQuotedValue(quote: Character) throws {
        _ = scanner.advance() // Skip opening quote
        
        var value = ""
        let style: YAMLNode.Scalar.Style = quote == "\"" ? .doubleQuoted : .singleQuoted
        
        while let char = scanner.peek(), char != quote {
            if char == "\\" && quote == "\"" {
                _ = scanner.advance()
                if let escaped = scanner.peek() {
                    value.append(try parseEscapeSequence(escaped))
                    _ = scanner.advance()
                } else {
                    throw YAMLError.invalidEscape("\\", line: scanner.currentLine)
                }
            } else if char == "\n" {
                throw YAMLError.unclosedQuote(line: scanner.currentLine)
            } else {
                value.append(char)
                _ = scanner.advance()
            }
        }
        
        if scanner.peek() == quote {
            _ = scanner.advance()
        } else {
            throw YAMLError.unclosedQuote(line: scanner.currentLine)
        }
        
        try emitToken(.scalar(.init(value: value, tag: .str, style: style)))
    }
    
    private func parseLiteralScalar(indent: Int) throws {
        _ = scanner.advance() // Skip |
        scanner.skipToEndOfLine()
        _ = scanner.advance()
        
        var lines: [String] = []
        let baseIndent = max(scanner.currentIndentation(), indent + 2)
        
        while !scanner.isAtEnd {
            let currentIndent = scanner.currentIndentation()
            let line = scanner.currentLineContent()
            
            if currentIndent < baseIndent && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            
            if currentIndent >= baseIndent {
                let startIndex = line.index(line.startIndex, offsetBy: min(baseIndent, line.count))
                lines.append(String(line[startIndex...]))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
            } else {
                break
            }
            
            scanner.skipToEndOfLine()
            _ = scanner.advance()
        }
        
        while !lines.isEmpty && lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }
        
        let value = lines.joined(separator: "\n")
        try emitToken(.scalar(.init(value: value, tag: .str, style: .literal)))
    }
    
    private func parseFoldedScalar(indent: Int) throws {
        _ = scanner.advance() // Skip >
        scanner.skipToEndOfLine()
        _ = scanner.advance()
        
        var lines: [String] = []
        let baseIndent = max(scanner.currentIndentation(), indent + 2)
        
        while !scanner.isAtEnd {
            let currentIndent = scanner.currentIndentation()
            let line = scanner.currentLineContent()
            
            if currentIndent < baseIndent && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            
            if currentIndent >= baseIndent {
                let startIndex = line.index(line.startIndex, offsetBy: min(baseIndent, line.count))
                lines.append(String(line[startIndex...]))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
            } else {
                break
            }
            
            scanner.skipToEndOfLine()
            _ = scanner.advance()
        }
        
        var result = ""
        for (index, line) in lines.enumerated() {
            if line.isEmpty {
                result += "\n"
            } else if index > 0 && !lines[index - 1].isEmpty {
                result += " " + line
            } else {
                result += line
            }
        }
        
        let value = result.trimmingCharacters(in: .newlines)
        try emitToken(.scalar(.init(value: value, tag: .str, style: .folded)))
    }
    
    private func closeCurrentContainer() throws {
        guard containerStack.count > 1,
              let containerType = containerStack.popLast() else { return }
        
        currentIndentStack.removeLast()
        
        switch containerType {
        case .mapping:
            try emitToken(.mappingEnd)
        case .sequence:
            try emitToken(.sequenceEnd)
        case .document:
            break // Document end is handled separately
        }
    }
    
    private func emitToken(_ token: YAMLToken) throws {
        delegate?.parser(self, didParse: token)
    }
    
    private func skipEmptyLinesAndComments() {
        while !scanner.isAtEnd {
            scanner.skipWhitespace()
            
            if scanner.peek() == "#" {
                scanner.skipToEndOfLine()
                _ = scanner.advance()
            } else if scanner.peek() == "\n" {
                _ = scanner.advance()
            } else {
                break
            }
        }
    }
    
    private func detectScalarType(_ value: String) -> YAMLNode.Scalar.Tag? {
        if value.isEmpty || value == "~" || value.lowercased() == "null" {
            return .null
        }
        
        if value.lowercased() == "true" || value.lowercased() == "false" ||
           value.lowercased() == "yes" || value.lowercased() == "no" ||
           value.lowercased() == "on" || value.lowercased() == "off" {
            return .bool
        }
        
        if Int(value) != nil {
            return .int
        }
        
        if Double(value) != nil {
            return .float
        }
        
        return .str
    }
    
    private func parseEscapeSequence(_ char: Character) throws -> Character {
        switch char {
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "\\": return "\\"
        case "\"": return "\""
        case "0": return "\0"
        case "a": return "\u{07}"
        case "b": return "\u{08}"
        case "v": return "\u{0B}"
        case "f": return "\u{0C}"
        case "e": return "\u{1B}"
        case " ": return " "
        case "N": return "\u{85}"
        case "_": return "\u{A0}"
        case "L": return "\u{2028}"
        case "P": return "\u{2029}"
        default:
            throw YAMLError.invalidEscape("\\\(char)", line: scanner.currentLine)
        }
    }
    
    private func checkDocumentSeparator() -> Bool {
        // Document separator must be at the beginning of a line
        if scanner.columnIndex != 0 {
            return false
        }
        
        guard scanner.peek() == "-" else { return false }
        guard scanner.peek(offset: 1) == "-" else { return false }
        guard scanner.peek(offset: 2) == "-" else { return false }
        
        // Check that it's followed by whitespace or end of line
        let next = scanner.peek(offset: 3)
        return next == nil || next == " " || next == "\t" || next == "\n"
    }
    
    // Scanner implementation
    private final class Scanner {
        private let lines: [String]
        fileprivate var lineIndex: Int = 0
        fileprivate var columnIndex: Int = 0
        
        var currentLine: Int { lineIndex + 1 }
        var currentColumn: Int { columnIndex + 1 }
        
        init(text: String) {
            self.lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }
        
        var isAtEnd: Bool {
            lineIndex >= lines.count
        }
        
        func peek() -> Character? {
            guard lineIndex < lines.count else { return nil }
            let line = lines[lineIndex]
            guard columnIndex < line.count else { return "\n" }
            return line[line.index(line.startIndex, offsetBy: columnIndex)]
        }
        
        func peek(offset: Int) -> Character? {
            guard lineIndex < lines.count else { return nil }
            let line = lines[lineIndex]
            let targetIndex = columnIndex + offset
            
            if targetIndex < line.count {
                return line[line.index(line.startIndex, offsetBy: targetIndex)]
            } else if targetIndex == line.count {
                return "\n"
            } else {
                // Would need to look at next line(s)
                return nil
            }
        }
        
        func advance() -> Character? {
            guard let char = peek() else { return nil }
            
            if char == "\n" {
                lineIndex += 1
                columnIndex = 0
            } else {
                columnIndex += 1
            }
            
            return char
        }
        
        func skipWhitespace() {
            while let char = peek(), char == " " || char == "\t" {
                _ = advance()
            }
        }
        
        func skipToEndOfLine() {
            while let char = peek(), char != "\n" {
                _ = advance()
            }
        }
        
        func currentLineContent() -> String {
            guard lineIndex < lines.count else { return "" }
            return lines[lineIndex]
        }
        
        func currentIndentation() -> Int {
            guard lineIndex < lines.count else { return 0 }
            let line = lines[lineIndex]
            var indent = 0
            for char in line {
                if char == " " {
                    indent += 1
                } else if char == "\t" {
                    indent += 4
                } else {
                    break
                }
            }
            return indent
        }
    }
}

/// Protocol for receiving YAML streaming parser events.
public protocol YAMLStreamParserDelegate: AnyObject {
    /// Called when the parser encounters a token.
    func parser(_ parser: YAMLStreamParser, didParse token: YAMLToken)
    
    /// Called when the parser starts parsing a document.
    func parserDidStartDocument(_ parser: YAMLStreamParser)
    
    /// Called when the parser finishes parsing a document.
    func parserDidEndDocument(_ parser: YAMLStreamParser)
    
    /// Called when the parser encounters an error.
    func parser(_ parser: YAMLStreamParser, didFailWithError error: Error)
}

// Default implementations
public extension YAMLStreamParserDelegate {
    func parserDidStartDocument(_ parser: YAMLStreamParser) {}
    func parserDidEndDocument(_ parser: YAMLStreamParser) {}
    func parser(_ parser: YAMLStreamParser, didFailWithError error: Error) {}
}
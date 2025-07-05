import Foundation

extension Character {
    var isHexDigit: Bool {
        return ("0"..."9").contains(self) || ("a"..."f").contains(self) || ("A"..."F").contains(self)
    }
}

public final class YAMLParser {
    private var scanner: Scanner
    private var anchors: [String: YAMLNode] = [:]
    private var tagDirectives: [String: String] = [:]
    private var yamlVersion: String? = nil
    
    private final class Scanner: @unchecked Sendable {
        private let lines: [String]
        private var lineIndex: Int = 0
        private var columnIndex: Int = 0
        
        var currentLine: Int { lineIndex + 1 }
        var currentColumn: Int { columnIndex + 1 }
        var columnIndex_: Int { columnIndex }
        
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
    
    public init() {
        self.scanner = Scanner(text: "")
    }
    
    public func parse(_ yaml: String) throws -> YAMLNode {
        let scanner = Scanner(text: yaml)
        self.scanner = scanner
        self.anchors = [:] // Reset anchors for each parse
        self.tagDirectives = [:] // Reset tag directives
        self.yamlVersion = nil // Reset YAML version
        
        skipEmptyLinesAndComments()
        
        // Parse any directives at the beginning
        _ = try parseDirectives()
        
        // Skip document separator if present
        if checkDocumentSeparator() {
            _ = scanner.advance() // -
            _ = scanner.advance() // -
            _ = scanner.advance() // -
            scanner.skipToEndOfLine()
            if scanner.peek() == "\n" {
                _ = scanner.advance()
            }
            skipEmptyLinesAndComments()
        }
        
        if scanner.isAtEnd {
            return .scalar(.init(value: "", tag: .null))
        }
        
        return try parseNode(indent: 0)
    }
    
    public func parseStream(_ yaml: String) throws -> [YAMLNode] {
        let scanner = Scanner(text: yaml)
        self.scanner = scanner
        
        var documents: [YAMLNode] = []
        var expectingDocument = false
        
        while !scanner.isAtEnd {
            self.anchors = [:] // Reset anchors for each document
            self.tagDirectives = [:] // Reset tag directives for each document
            self.yamlVersion = nil // Reset YAML version for each document
            
            skipEmptyLinesAndComments()
            
            // Parse any directives at the beginning of the document
            let parsedDirectives = try parseDirectives()
            
            // If we parsed directives after a separator, we're no longer expecting an empty document
            if parsedDirectives && expectingDocument {
                expectingDocument = false
            }
            
            skipEmptyLinesAndComments()
            
            if scanner.isAtEnd {
                // If we were expecting a document after a separator, add empty
                if expectingDocument {
                    documents.append(.scalar(.init(value: "", tag: .null)))
                }
                break
            }
            
            // Check for document separator
            if checkDocumentSeparator() {
                // If we were expecting a document, it means we have consecutive separators
                if expectingDocument {
                    documents.append(.scalar(.init(value: "", tag: .null)))
                }
                
                _ = scanner.advance() // -
                _ = scanner.advance() // -
                _ = scanner.advance() // -
                
                // Skip the rest of the line (including any content after the separator)
                scanner.skipToEndOfLine()
                
                // If we're at a newline, advance past it
                if scanner.peek() == "\n" {
                    _ = scanner.advance()
                }
                
                expectingDocument = true
                
                // After a document separator, we should reset state for next document
                self.anchors = [:]
                self.tagDirectives = [:]
                self.yamlVersion = nil
                
                continue
            }
            
            // Check for document end marker
            if checkDocumentEnd() {
                // If we were expecting a document, add empty before the end marker
                if expectingDocument {
                    documents.append(.scalar(.init(value: "", tag: .null)))
                    expectingDocument = false
                }
                
                _ = scanner.advance() // .
                _ = scanner.advance() // .
                _ = scanner.advance() // .
                scanner.skipToEndOfLine()
                if scanner.peek() == "\n" {
                    _ = scanner.advance() // newline
                }
                continue
            }
            
            // Check if we have directive markers at the start of content
            if checkDirective() {
                // We have directives after separator, don't add empty document
                // The directives will be parsed in the next iteration
                expectingDocument = false  // Reset since directives start a new document
                continue
            }
            
            // Parse actual content
            // If we reach here, we're not at a separator or end marker, so parse content
            let node = try parseNode(indent: 0)
            documents.append(node)
            expectingDocument = false
            
            // Skip any remaining content on the current line
            skipEmptyLinesAndComments()
        }
        
        // If we ended while expecting a document, add empty
        if expectingDocument {
            documents.append(.scalar(.init(value: "", tag: .null)))
        }
        
        return documents
    }
    
    private func checkDocumentSeparator() -> Bool {
        // Document separator must be at the beginning of a line
        if scanner.columnIndex_ != 0 {
            return false
        }
        
        guard scanner.peek() == "-" else { return false }
        guard scanner.peek(offset: 1) == "-" else { return false }
        guard scanner.peek(offset: 2) == "-" else { return false }
        
        // Check that it's followed by whitespace or end of line
        let next = scanner.peek(offset: 3)
        return next == nil || next == " " || next == "\t" || next == "\n"
    }
    
    private func checkDocumentEnd() -> Bool {
        // Document end marker must be at the beginning of a line
        if scanner.columnIndex_ != 0 {
            return false
        }
        
        guard scanner.peek() == "." else { return false }
        guard scanner.peek(offset: 1) == "." else { return false }
        guard scanner.peek(offset: 2) == "." else { return false }
        
        // Check that it's followed by whitespace or end of line
        let next = scanner.peek(offset: 3)
        return next == nil || next == " " || next == "\t" || next == "\n"
    }
    
    private func checkDirective() -> Bool {
        // Directives must be at the beginning of a line
        if scanner.columnIndex_ != 0 {
            return false
        }
        
        return scanner.peek() == "%"
    }
    
    private func parseDirectives() throws -> Bool {
        var parsedAny = false
        while checkDirective() {
            parsedAny = true
            _ = scanner.advance() // Skip %
            
            // Read directive name
            var directive = ""
            while let char = scanner.peek(), char.isLetter || char.isNumber {
                directive.append(char)
                _ = scanner.advance()
            }
            
            scanner.skipWhitespace()
            
            switch directive {
            case "TAG":
                try parseTagDirective()
            case "YAML":
                try parseYAMLDirective()
            default:
                // Unknown directive, skip it
                scanner.skipToEndOfLine()
            }
            
            // Move to next line
            if scanner.peek() == "\n" {
                _ = scanner.advance()
            }
            
            skipEmptyLinesAndComments()
        }
        return parsedAny
    }
    
    private func parseTagDirective() throws {
        // Parse tag handle (like !)
        guard scanner.peek() == "!" else {
            throw YAMLError.invalidYAML("Expected ! in TAG directive at line \(scanner.currentLine)")
        }
        _ = scanner.advance()
        
        var handle = "!"
        while let char = scanner.peek(), char != " " && char != "\t" && char != "\n" {
            handle.append(char)
            _ = scanner.advance()
        }
        
        scanner.skipWhitespace()
        
        // Parse tag prefix
        var prefix = ""
        while let char = scanner.peek(), char != "\n" && char != " " && char != "\t" {
            prefix.append(char)
            _ = scanner.advance()
        }
        
        // Store the tag directive
        tagDirectives[handle] = prefix
        
        // Skip any remaining content on the line
        scanner.skipToEndOfLine()
    }
    
    private func parseYAMLDirective() throws {
        // Parse version number (e.g., "1.2")
        var version = ""
        
        // Skip any whitespace after YAML
        scanner.skipWhitespace()
        
        // Read version number
        while let char = scanner.peek(), char.isNumber || char == "." {
            version.append(char)
            _ = scanner.advance()
        }
        
        // Validate version format
        guard !version.isEmpty else {
            throw YAMLError.invalidYAML("Missing version in %YAML directive at line \(scanner.currentLine)")
        }
        
        // Currently we support YAML 1.1 and 1.2
        let supportedVersions = ["1.0", "1.1", "1.2"]
        guard supportedVersions.contains(version) else {
            throw YAMLError.invalidYAML("Unsupported YAML version \(version) at line \(scanner.currentLine). Supported versions: \(supportedVersions.joined(separator: ", "))")
        }
        
        // Store the version
        yamlVersion = version
        
        // Skip any remaining content on the line
        scanner.skipToEndOfLine()
    }
    
    private func parseNode(indent: Int) throws -> YAMLNode {
        skipEmptyLinesAndComments()
        
        guard !scanner.isAtEnd else {
            return .scalar(.init(value: "", tag: .null))
        }
        
        scanner.skipWhitespace()
        
        // Check for anchor
        var anchorName: String?
        if scanner.peek() == "&" {
            anchorName = try parseAnchor()
            scanner.skipWhitespace()
        }
        
        // Check for tag
        var tag: String?
        if scanner.peek() == "!" {
            tag = try parseTag()
            scanner.skipWhitespace()
        }
        
        // Check for alias
        if scanner.peek() == "*" {
            return try parseAlias()
        }
        
        // If we have a tag and are at end of line, parse content on next line with tag
        if tag != nil && (scanner.peek() == "\n" || scanner.isAtEnd) {
            _ = scanner.advance() // consume newline
            skipEmptyLinesAndComments()
            
            // Parse the content on the next line(s) at the current indent or greater
            let nextIndent = scanner.currentIndentation()
            if nextIndent >= indent {
                let node = try parseNode(indent: indent)
                
                // Apply the tag to the parsed node (this is limited for now to scalars)
                let taggedNode = applyTag(tag, to: node)
                
                // Store anchor if present
                if let anchorName = anchorName {
                    anchors[anchorName] = taggedNode
                }
                
                return taggedNode
            } else {
                // Empty tagged node
                let node = YAMLNode.scalar(.init(value: "", tag: .null))
                let taggedNode = applyTag(tag, to: node)
                
                // Store anchor if present
                if let anchorName = anchorName {
                    anchors[anchorName] = taggedNode
                }
                
                return taggedNode
            }
        }
        
        guard let firstChar = scanner.peek() else {
            return .scalar(.init(value: "", tag: .null))
        }
        
        // Parse the actual node
        let node: YAMLNode
        
        // Check first character to determine node type
        switch firstChar {
        case "-":
            // Check if this is a document separator (---)
            if scanner.peek(offset: 1) == "-" && scanner.peek(offset: 2) == "-" {
                // Check if it's a proper separator (followed by space/newline/EOF)
                let next = scanner.peek(offset: 3)
                if next == nil || next == " " || next == "\t" || next == "\n" {
                    // This is a document separator in the wrong place
                    throw YAMLError.unexpectedToken("---", line: scanner.currentLine, column: scanner.currentColumn)
                }
            }
            node = try parseSequence(indent: indent)
        case "?":
            // Explicit key indicator - this is a mapping
            node = try parseMapping(indent: indent)
        case "|":
            node = try parseLiteralScalar(indent: indent)
        case ">":
            node = try parseFoldedScalar(indent: indent)
        case "\"":
            // Check if this is a quoted key in a mapping
            let line = scanner.currentLineContent().trimmingCharacters(in: .whitespaces)
            if line.contains("\": ") || line.contains("\":") {
                node = try parseMapping(indent: indent)
            } else {
                node = try parseQuotedScalar(quote: "\"")
            }
        case "'":
            // Check if this is a quoted key in a mapping
            let line = scanner.currentLineContent().trimmingCharacters(in: .whitespaces)
            if line.contains("': ") || line.contains("':") {
                node = try parseMapping(indent: indent)
            } else {
                node = try parseQuotedScalar(quote: "'")
            }
        case "[":
            node = try parseFlowSequence()
        case "{":
            node = try parseFlowMapping()
        case "\n":
            // If we encounter a newline, return an empty scalar
            // This can happen at the end of documents
            node = .scalar(.init(value: "", tag: .null))
        default:
            // Get the current line, handling case where we might be at column 0
            let line = scanner.currentLineContent()
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // If line is empty or we're past the content, it's an empty scalar
            if trimmedLine.isEmpty || scanner.columnIndex_ >= line.count {
                node = .scalar(.init(value: "", tag: .null))
            } else if trimmedLine.contains(": ") || trimmedLine.hasSuffix(":") {
                // Check for mapping patterns like "key: value", 'key': value, key:
                node = try parseMapping(indent: indent)
            } else {
                node = try parsePlainScalar()
            }
        }
        
        // Apply tag if present (only works for scalars currently)
        let finalNode = tag != nil ? applyTag(tag, to: node) : node
        
        // Store anchor if present
        if let anchorName = anchorName {
            anchors[anchorName] = finalNode
        }
        
        return finalNode
    }
    
    private func parseSequence(indent: Int, tag: String? = nil) throws -> YAMLNode {
        var items: [YAMLNode] = []
        var sequenceIndent: Int? = nil
        
        while !scanner.isAtEnd {
            skipEmptyLinesAndComments()
            
            let currentIndent = scanner.currentIndentation()
            
            // The minimum indent is what was passed in
            if currentIndent < indent {
                break
            }
            
            scanner.skipWhitespace()
            
            // Check for document separator or end marker before trying to parse a sequence item
            if checkDocumentSeparator() || checkDocumentEnd() {
                break
            }
            
            guard scanner.peek() == "-" else {
                break
            }
            
            // For sequences, we allow the first item to establish the actual indentation
            if sequenceIndent == nil {
                // First sequence item - this sets the indentation for all items
                sequenceIndent = currentIndent
            } else if currentIndent != sequenceIndent {
                // All sequence items must be at the same indentation
                throw YAMLError.indentationError("Unexpected indentation", line: scanner.currentLine)
            }
            
            _ = scanner.advance()
            scanner.skipWhitespace()
            
            // Check for anchor
            var anchorName: String?
            if scanner.peek() == "&" {
                anchorName = try parseAnchor()
                scanner.skipWhitespace()
            }
            
            // Check for alias
            if scanner.peek() == "*" {
                let item = try parseAlias()
                items.append(item)
                continue
            }
            
            // Check for tag
            var tagName: String?
            if scanner.peek() == "!" {
                tagName = try parseTag()
                scanner.skipWhitespace()
            }
            
            if scanner.peek() == "\n" || scanner.isAtEnd {
                // Empty item or anchor with value on next line
                _ = scanner.advance()
                skipEmptyLinesAndComments()
                
                let nextIndent = scanner.currentIndentation()
                if nextIndent > indent {
                    var item = try parseNode(indent: nextIndent)
                    if let tagName = tagName {
                        item = applyTag(tagName, to: item)
                    }
                    if let anchorName = anchorName {
                        anchors[anchorName] = item
                    }
                    items.append(item)
                } else {
                    items.append(.scalar(.init(value: "", tag: .null)))
                }
            } else {
                // Check if this is an inline mapping (has ": " on the same line)
                let line = scanner.currentLineContent()
                let currentPos = scanner.currentColumn - 1  // Convert 1-based to 0-based
                let remainingLine = String(line.dropFirst(currentPos))
                
                if remainingLine.contains(": ") || remainingLine.hasSuffix(":") {
                    // Inline mapping - subsequent lines should be at the same indent as the dash
                    // But we need to tell the mapping parser to expect keys at currentIndent (where dash is)
                    // not at the position after the dash and spaces
                    
                    // The mapping should accept keys at the same level as the dash
                    var item = try parseInlineSequenceMapping(sequenceIndent: currentIndent)
                    if let tagName = tagName {
                        item = applyTag(tagName, to: item)
                    }
                    if let anchorName = anchorName {
                        anchors[anchorName] = item
                    }
                    items.append(item)
                } else {
                    // Regular scalar or nested structure
                    var item = try parseNode(indent: currentIndent + 2)
                    if let tagName = tagName {
                        item = applyTag(tagName, to: item)
                    }
                    if let anchorName = anchorName {
                        anchors[anchorName] = item
                    }
                    items.append(item)
                }
            }
        }
        
        return .sequence(items)
    }
    
    private func parseFlowSequence(tag: String? = nil) throws -> YAMLNode {
        // Skip the opening '['
        _ = scanner.advance()
        scanner.skipWhitespace()
        
        var items: [YAMLNode] = []
        
        while !scanner.isAtEnd {
            // Skip whitespace and newlines in flow context
            skipFlowWhitespace()
            
            // Check for closing ']'
            if scanner.peek() == "]" {
                _ = scanner.advance()
                return .sequence(items)
            }
            
            // Parse item
            if !items.isEmpty {
                // Expect comma between items
                guard scanner.peek() == "," else {
                    throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                                  line: scanner.currentLine, 
                                                  column: scanner.currentColumn)
                }
                _ = scanner.advance()
                skipFlowWhitespace()
            }
            
            // Check for trailing comma with closing bracket
            if scanner.peek() == "]" {
                _ = scanner.advance()
                return .sequence(items)
            }
            
            // Parse the item - could be any node type including nested flow
            let item = try parseFlowNode()
            items.append(item)
        }
        
        // If we get here, we didn't find a closing bracket
        throw YAMLError.unexpectedToken("end of input", 
                                      line: scanner.currentLine, 
                                      column: scanner.currentColumn)
    }
    
    private func parseInlineSequenceMapping(sequenceIndent: Int) throws -> YAMLNode {
        // This handles mappings that start inline after a sequence dash
        // like: - key: value
        //         another: value
        // The "another" line should be at the same indent as the dash
        
        var dict: [String: YAMLNode] = [:]
        var mergeNodes: [YAMLNode] = []
        
        // Parse the first key-value pair on the current line
        let firstKey = try parseKey()
        scanner.skipWhitespace()
        
        guard scanner.peek() == ":" else {
            throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                          line: scanner.currentLine, 
                                          column: scanner.currentColumn)
        }
        
        _ = scanner.advance()
        scanner.skipWhitespace()
        
        // Check if value is on the same line or next line
        let firstValue: YAMLNode
        if scanner.peek() == "\n" || scanner.isAtEnd {
            _ = scanner.advance()
            skipEmptyLinesAndComments()
            
            let nextIndent = scanner.currentIndentation()
            if nextIndent > sequenceIndent {
                firstValue = try parseNode(indent: nextIndent)
            } else {
                firstValue = .scalar(.init(value: "", tag: .null))
            }
        } else {
            firstValue = try parseInlineValue(indent: sequenceIndent)
        }
        
        // Check for merge key
        if firstKey == "<<" {
            mergeNodes.append(firstValue)
        } else {
            dict[firstKey] = firstValue
        }
        
        // Now look for continuation lines at the sequence indent level
        while !scanner.isAtEnd {
            skipEmptyLinesAndComments()
            
            let currentIndent = scanner.currentIndentation()
            if currentIndent < sequenceIndent {
                break
            }
            
            scanner.skipWhitespace()
            
            // Check if this looks like another key
            let line = scanner.currentLineContent().trimmingCharacters(in: .whitespaces)
            
            // Stop if we hit another sequence item
            if line.starts(with: "-") {
                break
            }
            
            if !line.contains(": ") && !line.hasSuffix(":") {
                break
            }
            
            // Check for explicit key marker
            var isExplicitKey = false
            if scanner.peek() == "?" {
                _ = scanner.advance() // consume ?
                scanner.skipWhitespace()
                isExplicitKey = true
            }
            
            let key = try parseKey()
            if key.isEmpty {
                break
            }
            
            scanner.skipWhitespace()
            
            // For explicit keys, we might have a newline before the :
            if isExplicitKey {
                // Skip to the next line if we're at end of line
                if scanner.peek() == "\n" {
                    _ = scanner.advance()
                    skipEmptyLinesAndComments()
                    scanner.skipWhitespace()
                }
                
                // Now we should see the : marker
                if scanner.peek() != ":" {
                    throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                                  line: scanner.currentLine, 
                                                  column: scanner.currentColumn)
                }
                _ = scanner.advance()
                scanner.skipWhitespace()
            } else {
                // Normal key: value syntax
                guard scanner.peek() == ":" else {
                    throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                                  line: scanner.currentLine, 
                                                  column: scanner.currentColumn)
                }
                
                _ = scanner.advance()
                scanner.skipWhitespace()
            }
            
            let value: YAMLNode
            if scanner.peek() == "\n" || scanner.isAtEnd {
                _ = scanner.advance()
                skipEmptyLinesAndComments()
                
                let nextIndent = scanner.currentIndentation()
                if nextIndent > sequenceIndent {
                    value = try parseNode(indent: nextIndent)
                } else {
                    value = .scalar(.init(value: "", tag: .null))
                }
            } else {
                value = try parseInlineValue(indent: sequenceIndent)
            }
            
            // Check for merge key
            if key == "<<" {
                mergeNodes.append(value)
            } else {
                dict[key] = value
            }
        }
        
        // Process merge nodes first (in order)
        for mergeNode in mergeNodes {
            if let mapping = mergeNode.dictionary {
                // Merge the mapping into our dictionary
                for (mergeKey, mergeValue) in mapping {
                    // Only add if key doesn't already exist (local values override merged ones)
                    if dict[mergeKey] == nil {
                        dict[mergeKey] = mergeValue
                    }
                }
            }
        }
        
        return .mapping(dict)
    }
    
    private func parseMapping(indent: Int, tag: String? = nil) throws -> YAMLNode {
        var dict: [String: YAMLNode] = [:]
        var mergeNodes: [YAMLNode] = []
        var mappingIndent: Int? = nil
        
        while !scanner.isAtEnd {
            skipEmptyLinesAndComments()
            
            let currentIndent = scanner.currentIndentation()
            
            // The minimum indent is what was passed in
            if currentIndent < indent {
                break
            }
            
            scanner.skipWhitespace()
            
            // Check if we're looking at a valid key start
            let keyStart = scanner.peek()
            if keyStart == nil || keyStart == "-" {
                break
            }
            
            // Check for explicit key marker
            var isExplicitKey = false
            if keyStart == "?" {
                _ = scanner.advance() // consume ?
                scanner.skipWhitespace()
                isExplicitKey = true
            }
            
            // For mappings, allow the first key to establish the actual indentation
            if mappingIndent == nil {
                // First mapping key - this sets the indentation for all keys
                mappingIndent = currentIndent
            } else if currentIndent != mappingIndent {
                // All mapping keys must be at the same indentation
                throw YAMLError.indentationError("Unexpected indentation", line: scanner.currentLine)
            }
            
            // Check for document separator or end marker before trying to parse a key
            if checkDocumentSeparator() || checkDocumentEnd() {
                break
            }
            
            let key = try parseKey()
            if key.isEmpty {
                break
            }
            
            scanner.skipWhitespace()
            
            // For explicit keys, we might have a newline before the :
            if isExplicitKey {
                // Skip to the next line if we're at end of line
                if scanner.peek() == "\n" {
                    _ = scanner.advance()
                    skipEmptyLinesAndComments()
                    scanner.skipWhitespace()
                }
                
                // Now we should see the : marker
                if scanner.peek() != ":" {
                    throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                                  line: scanner.currentLine, 
                                                  column: scanner.currentColumn)
                }
                _ = scanner.advance()
                scanner.skipWhitespace()
            } else {
                // Normal key: value syntax
                guard scanner.peek() == ":" else {
                    throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                                  line: scanner.currentLine, 
                                                  column: scanner.currentColumn)
                }
                
                _ = scanner.advance()
                scanner.skipWhitespace()
            }
            
            // Check for tag first
            var tagName: String?
            if scanner.peek() == "!" {
                tagName = try parseTag()
                scanner.skipWhitespace()
            }
            
            // Check for anchor
            var anchorName: String?
            if scanner.peek() == "&" {
                anchorName = try parseAnchor()
                scanner.skipWhitespace()
                
                // Check for tag after anchor
                if scanner.peek() == "!" && tagName == nil {
                    tagName = try parseTag()
                    scanner.skipWhitespace()
                }
            }
            
            // Check for alias
            if scanner.peek() == "*" {
                let value = try parseAlias()
                if key == "<<" {
                    mergeNodes.append(value)
                } else {
                    dict[key] = value
                }
                continue
            }
            
            let value: YAMLNode
            if scanner.peek() == "\n" || scanner.isAtEnd {
                _ = scanner.advance()
                skipEmptyLinesAndComments()
                
                let nextIndent = scanner.currentIndentation()
                
                // Check what type of value follows
                if scanner.peek() == "-" && nextIndent == currentIndent {
                    // This is a sequence at the same indentation as the key
                    // This is allowed in YAML spec
                    value = try parseNode(indent: currentIndent)
                } else if nextIndent > currentIndent {
                    // Other content - must be indented more than the key
                    value = try parseNode(indent: currentIndent + 1)
                } else {
                    value = .scalar(.init(value: "", tag: .null))
                }
            } else {
                // Parse inline value
                value = try parseInlineValue(indent: currentIndent)
            }
            
            // Apply tag if present
            let finalValue = applyTag(tagName, to: value)
            
            // Store anchor if present
            if let anchorName = anchorName {
                anchors[anchorName] = finalValue
            }
            
            // Check for merge key
            if key == "<<" {
                mergeNodes.append(finalValue)
            } else {
                dict[key] = finalValue
            }
        }
        
        // Process merge nodes first (in order)
        for mergeNode in mergeNodes {
            if let mapping = mergeNode.dictionary {
                // Merge the mapping into our dictionary
                for (mergeKey, mergeValue) in mapping {
                    // Only add if key doesn't already exist (local values override merged ones)
                    if dict[mergeKey] == nil {
                        dict[mergeKey] = mergeValue
                    }
                }
            } else if case .sequence(let items) = mergeNode {
                // Can also merge multiple mappings
                for item in items {
                    if let mapping = item.dictionary {
                        for (mergeKey, mergeValue) in mapping {
                            if dict[mergeKey] == nil {
                                dict[mergeKey] = mergeValue
                            }
                        }
                    }
                }
            }
        }
        
        return .mapping(dict)
    }
    
    private func parseFlowMapping(tag: String? = nil) throws -> YAMLNode {
        // Skip the opening '{'
        _ = scanner.advance()
        scanner.skipWhitespace()
        
        var dict: [String: YAMLNode] = [:]
        var mergeNodes: [YAMLNode] = []
        
        while !scanner.isAtEnd {
            // Skip whitespace and newlines in flow context
            skipFlowWhitespace()
            
            // Check for closing '}'
            if scanner.peek() == "}" {
                _ = scanner.advance()
                break
            }
            
            // Parse key-value pair
            if !dict.isEmpty || !mergeNodes.isEmpty {
                // Expect comma between pairs
                guard scanner.peek() == "," else {
                    throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                                  line: scanner.currentLine, 
                                                  column: scanner.currentColumn)
                }
                _ = scanner.advance()
                skipFlowWhitespace()
            }
            
            // Check for trailing comma with closing brace
            if scanner.peek() == "}" {
                _ = scanner.advance()
                break
            }
            
            // Parse key
            let key = try parseFlowKey()
            skipFlowWhitespace()
            
            // Expect colon
            guard scanner.peek() == ":" else {
                throw YAMLError.unexpectedToken(String(scanner.peek() ?? " "), 
                                              line: scanner.currentLine, 
                                              column: scanner.currentColumn)
            }
            _ = scanner.advance()
            skipFlowWhitespace()
            
            // Parse value
            let value = try parseFlowNode()
            
            // Check for merge key
            if key == "<<" {
                mergeNodes.append(value)
            } else {
                dict[key] = value
            }
        }
        
        // If we exited the loop due to EOF, we have an unclosed mapping
        if scanner.isAtEnd {
            throw YAMLError.unexpectedToken("end of input", 
                                          line: scanner.currentLine, 
                                          column: scanner.currentColumn)
        }
        
        // Process merge nodes first (in order)
        for mergeNode in mergeNodes {
            if let mapping = mergeNode.dictionary {
                // Merge the mapping into our dictionary
                for (mergeKey, mergeValue) in mapping {
                    // Only add if key doesn't already exist (local values override merged ones)
                    if dict[mergeKey] == nil {
                        dict[mergeKey] = mergeValue
                    }
                }
            } else if case .sequence(let items) = mergeNode {
                // Can also merge multiple mappings
                for item in items {
                    if let mapping = item.dictionary {
                        for (mergeKey, mergeValue) in mapping {
                            if dict[mergeKey] == nil {
                                dict[mergeKey] = mergeValue
                            }
                        }
                    }
                }
            }
        }
        
        return .mapping(dict)
    }
    
    private func parseKey() throws -> String {
        var key = ""
        
        if scanner.peek() == "\"" || scanner.peek() == "'" {
            let quote = scanner.peek()!
            _ = scanner.advance()
            
            while let char = scanner.peek(), char != quote {
                if char == "\\" {
                    _ = scanner.advance()
                    if let escaped = scanner.peek() {
                        let escapedChar = try parseEscapeSequence(escaped)
                        key.append(escapedChar)
                        // Only advance for single-character escapes
                        if escaped != "u" && escaped != "U" {
                            _ = scanner.advance()
                        }
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
    
    private func parsePlainScalar(tag: String? = nil) throws -> YAMLNode {
        var value = ""
        var prevChar: Character? = nil
        
        while let char = scanner.peek(), char != "\n" {
            // Only treat # as comment if preceded by whitespace
            if char == "#" && (prevChar == nil || prevChar == " " || prevChar == "\t") {
                break
            }
            value.append(char)
            prevChar = char
            _ = scanner.advance()
        }
        
        value = value.trimmingCharacters(in: .whitespaces)
        
        let tag = detectScalarType(value)
        return .scalar(.init(value: value, tag: tag))
    }
    
    private func parseInlineValue(indent: Int) throws -> YAMLNode {
        scanner.skipWhitespace()
        
        guard let firstChar = scanner.peek() else {
            return .scalar(.init(value: "", tag: .null))
        }
        
        switch firstChar {
        case "\"":
            return try parseQuotedScalar(quote: "\"")
        case "'":
            return try parseQuotedScalar(quote: "'")
        case "|":
            return try parseLiteralScalar(indent: indent)
        case ">":
            return try parseFoldedScalar(indent: indent)
        case "[":
            return try parseFlowSequence()
        case "{":
            return try parseFlowMapping()
        case "*":
            return try parseAlias()
        case "&":
            let anchorName = try parseAnchor()
            scanner.skipWhitespace()
            let node = try parseInlineValue(indent: indent)
            anchors[anchorName] = node
            return node
        default:
            return try parsePlainScalar()
        }
    }
    
    private func parseQuotedScalar(quote: Character, tag: String? = nil) throws -> YAMLNode {
        _ = scanner.advance()
        
        var value = ""
        let style: YAMLNode.Scalar.Style = quote == "\"" ? .doubleQuoted : .singleQuoted
        
        while let char = scanner.peek(), char != quote {
            if char == "\\" && quote == "\"" {
                _ = scanner.advance()
                if let escaped = scanner.peek() {
                    let escapedChar = try parseEscapeSequence(escaped)
                    value.append(escapedChar)
                    // Only advance once more for single-character escapes
                    // Unicode escapes already consumed their hex digits
                    if escaped != "u" && escaped != "U" {
                        _ = scanner.advance()
                    }
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
        
        return .scalar(.init(value: value, tag: .str, style: style))
    }
    
    private func parseLiteralScalar(indent: Int, tag: String? = nil) throws -> YAMLNode {
        _ = scanner.advance()  // Skip the |
        
        // Check for optional indentation indicator
        if let char = scanner.peek(), char.isNumber {
            var indentStr = ""
            while let char = scanner.peek(), char.isNumber {
                indentStr.append(char)
                _ = scanner.advance()
            }
            
            guard let indentValue = Int(indentStr) else {
                throw YAMLError.invalidYAML("Invalid indentation indicator: \(indentStr)")
            }
            
            // Validate reasonable indentation (YAML spec says max is 9)
            guard indentValue >= 1 && indentValue <= 9 else {
                throw YAMLError.invalidYAML("Indentation indicator must be between 1 and 9, got: \(indentValue)")
            }
            
            // TODO: Use explicitIndent value for parsing
            _ = indentValue
        }
        
        scanner.skipToEndOfLine()
        _ = scanner.advance()  // Move to next line
        
        var lines: [String] = []
        // The base indent should be at least greater than the current mapping indent
        let baseIndent = max(scanner.currentIndentation(), indent + 2)
        var firstLine = true
        
        while !scanner.isAtEnd {
            let currentIndent = scanner.currentIndentation()
            let line = scanner.currentLineContent()
            
            // If we hit a line with less indentation than base and it's not empty, we're done
            if currentIndent < baseIndent && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            
            // For the first content line, establish the actual base indent
            if firstLine && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                firstLine = false
            }
            
            if currentIndent >= baseIndent {
                let startIndex = line.index(line.startIndex, offsetBy: min(baseIndent, line.count))
                lines.append(String(line[startIndex...]))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
            } else {
                // This handles lines that have some indent but less than base
                break
            }
            
            scanner.skipToEndOfLine()
            _ = scanner.advance()
        }
        
        // Remove trailing empty lines
        while !lines.isEmpty && lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            lines.removeLast()
        }
        
        let value = lines.joined(separator: "\n")
        return .scalar(.init(value: value, tag: .str, style: .literal))
    }
    
    private func parseFoldedScalar(indent: Int, tag: String? = nil) throws -> YAMLNode {
        _ = scanner.advance()  // Skip the >
        
        // Check for optional indentation indicator
        if let char = scanner.peek(), char.isNumber {
            var indentStr = ""
            while let char = scanner.peek(), char.isNumber {
                indentStr.append(char)
                _ = scanner.advance()
            }
            
            guard let indentValue = Int(indentStr) else {
                throw YAMLError.invalidYAML("Invalid indentation indicator: \(indentStr)")
            }
            
            // Validate reasonable indentation (YAML spec says max is 9)
            guard indentValue >= 1 && indentValue <= 9 else {
                throw YAMLError.invalidYAML("Indentation indicator must be between 1 and 9, got: \(indentValue)")
            }
            
            // TODO: Use explicitIndent value for parsing
            _ = indentValue
        }
        
        scanner.skipToEndOfLine()
        _ = scanner.advance()  // Move to next line
        
        var lines: [String] = []
        // The base indent should be at least greater than the current mapping indent
        let baseIndent = max(scanner.currentIndentation(), indent + 2)
        
        while !scanner.isAtEnd {
            let currentIndent = scanner.currentIndentation()
            let line = scanner.currentLineContent()
            
            // If we hit a line with less indentation than base and it's not empty, we're done
            if currentIndent < baseIndent && !line.trimmingCharacters(in: .whitespaces).isEmpty {
                break
            }
            
            if currentIndent >= baseIndent {
                let startIndex = line.index(line.startIndex, offsetBy: min(baseIndent, line.count))
                lines.append(String(line[startIndex...]))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("")
            } else {
                // This handles lines that have some indent but less than base
                break
            }
            
            scanner.skipToEndOfLine()
            _ = scanner.advance()
        }
        
        // Process folded scalar rules
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
        
        return .scalar(.init(value: result.trimmingCharacters(in: .newlines), tag: .str, style: .folded))
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
        case "u":
            // Unicode escape sequence \uXXXX (4 hex digits)
            _ = scanner.advance() // Move past the 'u'
            return try parseUnicodeEscape(length: 4)
        case "U":
            // Unicode escape sequence \UXXXXXXXX (8 hex digits)
            _ = scanner.advance() // Move past the 'U'
            return try parseUnicodeEscape(length: 8)
        default:
            throw YAMLError.invalidEscape("\\\(char)", line: scanner.currentLine)
        }
    }
    
    private func parseUnicodeEscape(length: Int) throws -> Character {
        var hexString = ""
        for i in 0..<length {
            guard let hexChar = scanner.peek() else {
                throw YAMLError.invalidEscape("\\u expected \(length) hex digits but got \(i)", line: scanner.currentLine)
            }
            guard hexChar.isHexDigit else {
                throw YAMLError.invalidEscape("\\u with invalid hex digit '\(hexChar)' at position \(i)", line: scanner.currentLine)
            }
            hexString.append(hexChar)
            _ = scanner.advance()
        }
        
        guard let codePoint = UInt32(hexString, radix: 16),
              let scalar = Unicode.Scalar(codePoint) else {
            throw YAMLError.invalidEscape("\\u\(hexString) is not a valid Unicode code point", line: scanner.currentLine)
        }
        
        return Character(scalar)
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
        
        // Check for special integer formats
        if value.hasPrefix("0x") || value.hasPrefix("0X") || value.hasPrefix("-0x") || value.hasPrefix("-0X") {
            // Hexadecimal
            let hexValue = value.hasPrefix("-") ? String(value.dropFirst(3)) : String(value.dropFirst(2))
            if Int(hexValue, radix: 16) != nil {
                return .int
            }
        } else if value.hasPrefix("0o") || value.hasPrefix("0O") || value.hasPrefix("-0o") || value.hasPrefix("-0O") {
            // Octal
            let octalValue = value.hasPrefix("-") ? String(value.dropFirst(3)) : String(value.dropFirst(2))
            if Int(octalValue, radix: 8) != nil {
                return .int
            }
        } else if value.hasPrefix("0b") || value.hasPrefix("0B") || value.hasPrefix("-0b") || value.hasPrefix("-0B") {
            // Binary
            let binaryValue = value.hasPrefix("-") ? String(value.dropFirst(3)) : String(value.dropFirst(2))
            if Int(binaryValue, radix: 2) != nil {
                return .int
            }
        } else if value.contains("_") {
            // Number with underscores
            let cleanedValue = value.replacingOccurrences(of: "_", with: "")
            if Int(cleanedValue) != nil {
                return .int
            } else if Double(cleanedValue) != nil {
                return .float
            }
        } else if Int(value) != nil {
            return .int
        } else if Double(value) != nil {
            return .float
        }
        
        // Check for special float values
        if value == ".inf" || value == "+.inf" {
            return .float
        } else if value == "-.inf" {
            return .float
        } else if value == ".nan" || value.lowercased() == ".nan" {
            return .float
        }
        
        return .str
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
    
    private func skipFlowWhitespace() {
        while !scanner.isAtEnd {
            let char = scanner.peek()
            if char == " " || char == "\t" || char == "\n" || char == "\r" {
                _ = scanner.advance()
            } else {
                break
            }
        }
    }
    
    private func parseFlowNode() throws -> YAMLNode {
        skipFlowWhitespace()
        
        guard let firstChar = scanner.peek() else {
            return .scalar(.init(value: "", tag: .null))
        }
        
        switch firstChar {
        case "[":
            return try parseFlowSequence()
        case "{":
            return try parseFlowMapping()
        case "\"", "'":
            return try parseQuotedScalar(quote: firstChar)
        case "*":
            return try parseAlias()
        default:
            return try parseFlowScalar()
        }
    }
    
    private func parseFlowKey() throws -> String {
        skipFlowWhitespace()
        
        if scanner.peek() == "\"" || scanner.peek() == "'" {
            let quote = scanner.peek()!
            _ = scanner.advance()
            
            var key = ""
            while let char = scanner.peek(), char != quote {
                if char == "\\" && quote == "\"" {
                    _ = scanner.advance()
                    if let escaped = scanner.peek() {
                        let escapedChar = try parseEscapeSequence(escaped)
                        key.append(escapedChar)
                        // Only advance for single-character escapes
                        if escaped != "u" && escaped != "U" {
                            _ = scanner.advance()
                        }
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
            
            return key
        } else {
            // Unquoted flow key
            var key = ""
            while let char = scanner.peek() {
                if char == ":" || char == "," || char == "}" || char == "]" || 
                   char == "\n" || char == "\r" || char == " " || char == "\t" {
                    break
                }
                key.append(char)
                _ = scanner.advance()
            }
            return key.trimmingCharacters(in: .whitespaces)
        }
    }
    
    private func parseFlowScalar() throws -> YAMLNode {
        var value = ""
        var inWhitespace = false
        
        while let char = scanner.peek() {
            // Stop at flow indicators
            if char == "," || char == "]" || char == "}" || 
               (char == ":" && (scanner.peek(offset: 1) == " " || scanner.peek(offset: 1) == nil)) {
                break
            }
            
            if char == " " || char == "\t" {
                if !inWhitespace && !value.isEmpty {
                    value.append(" ")
                    inWhitespace = true
                }
                _ = scanner.advance()
            } else if char == "\n" || char == "\r" {
                // In flow context, newlines become spaces
                if !inWhitespace && !value.isEmpty {
                    value.append(" ")
                    inWhitespace = true
                }
                _ = scanner.advance()
            } else {
                inWhitespace = false
                value.append(char)
                _ = scanner.advance()
            }
        }
        
        value = value.trimmingCharacters(in: .whitespaces)
        let tag = detectScalarType(value)
        return .scalar(.init(value: value, tag: tag))
    }
    
    private func parseAnchor() throws -> String {
        guard scanner.advance() == "&" else {
            throw YAMLError.invalidYAML("Expected & for anchor")
        }
        
        var name = ""
        
        // Anchor names must start with letter
        guard let firstChar = scanner.peek(), firstChar.isLetter else {
            throw YAMLError.invalidYAML("Invalid anchor name: must start with letter")
        }
        
        while let char = scanner.peek(), isAnchorChar(char) {
            name.append(char)
            _ = scanner.advance()
        }
        
        if name.isEmpty {
            throw YAMLError.invalidYAML("Empty anchor name")
        }
        
        return name
    }
    
    private func parseAlias() throws -> YAMLNode {
        guard scanner.advance() == "*" else {
            throw YAMLError.invalidYAML("Expected * for alias")
        }
        
        var name = ""
        while let char = scanner.peek(), isAnchorChar(char) {
            name.append(char)
            _ = scanner.advance()
        }
        
        if name.isEmpty {
            throw YAMLError.invalidYAML("Empty alias name")
        }
        
        // Look up the anchor
        guard let node = anchors[name] else {
            throw YAMLError.invalidYAML("Undefined alias: \(name)")
        }
        
        // Check for circular reference
        // For now, we just return the node - full circular detection would require tracking references
        return node
    }
    
    private func parseTag() throws -> String {
        guard scanner.advance() == "!" else {
            throw YAMLError.invalidYAML("Expected ! for tag")
        }
        
        var tag = "!"
        
        // Check for second ! (standard tag like !!str)
        if scanner.peek() == "!" {
            tag.append("!")
            _ = scanner.advance()
        }
        
        // Check for verbatim tag (e.g., !<tag:example.com,2014:foo>)
        if scanner.peek() == "<" {
            _ = scanner.advance()
            tag.append("<")
            
            var verbatimContent = ""
            while let char = scanner.peek(), char != ">" {
                // Verbatim tags should not contain spaces
                if char == " " || char == "\t" || char == "\n" {
                    throw YAMLError.invalidYAML("Invalid character in verbatim tag: '\(char)'")
                }
                verbatimContent.append(char)
                tag.append(char)
                _ = scanner.advance()
            }
            
            guard scanner.peek() == ">" else {
                throw YAMLError.invalidYAML("Unclosed verbatim tag")
            }
            
            // Validate verbatim tag content - should be a valid URI
            if verbatimContent.isEmpty || (!verbatimContent.contains(":") && !verbatimContent.contains("/")) {
                throw YAMLError.invalidYAML("Invalid verbatim tag format: '\(verbatimContent)'")
            }
            
            tag.append(">")
            _ = scanner.advance()
        } else {
            // Regular tag name
            while let char = scanner.peek(), isTagChar(char) {
                tag.append(char)
                _ = scanner.advance()
            }
        }
        
        // Check if we need to expand the tag using directives
        if let firstExclamation = tag.firstIndex(of: "!"),
           tag.count > 1,
           !tag.hasPrefix("!!"),
           !tag.hasPrefix("!<") {
            // Extract the handle and suffix
            let handleEndIndex = tag.index(after: firstExclamation)
            let handle = String(tag[..<handleEndIndex])
            let suffix = String(tag[handleEndIndex...])
            
            // Check if we have a directive for this handle
            if let prefix = tagDirectives[handle] {
                return prefix + suffix
            }
        }
        
        return tag
    }
    
    private func isAnchorChar(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber || char == "-" || char == "_"
    }
    
    private func isTagChar(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber || char == "-" || char == "_" || char == ":" || char == "/" || char == "."
    }
    
    private func applyTag(_ tagName: String?, to node: YAMLNode) -> YAMLNode {
        guard let tagName = tagName else { return node }
        
        // For scalars, we can apply the tag
        if case .scalar(let scalar) = node {
            let tag = YAMLNode.Scalar.Tag(shortForm: tagName) ?? YAMLNode.Scalar.Tag(rawValue: tagName)
            
            // For certain tags, we may need to convert the value
            switch tagName {
            case "!!str":
                return .scalar(.init(value: scalar.value, tag: tag, style: scalar.style))
            case "!!int":
                // Keep the string value, but mark it as an int
                return .scalar(.init(value: scalar.value, tag: tag, style: scalar.style))
            case "!!float":
                return .scalar(.init(value: scalar.value, tag: tag, style: scalar.style))
            case "!!bool":
                // Convert various boolean representations to canonical form
                let boolValue: String
                switch scalar.value.lowercased() {
                case "true", "yes", "on", "1":
                    boolValue = "true"
                case "false", "no", "off", "0":
                    boolValue = "false"
                default:
                    boolValue = scalar.value
                }
                return .scalar(.init(value: boolValue, tag: tag, style: scalar.style))
            case "!!null":
                return .scalar(.init(value: scalar.value, tag: tag, style: scalar.style))
            default:
                // Custom tag
                return .scalar(.init(value: scalar.value, tag: tag, style: scalar.style))
            }
        }
        
        // For sequences and mappings, tags are not currently supported in our structure
        // but we could extend YAMLNode to support them
        return node
    }
}
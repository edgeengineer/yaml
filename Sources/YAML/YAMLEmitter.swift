#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/// A YAML emitter that converts YAMLNode structures to YAML-formatted strings.
public final class YAMLEmitter {
    /// Options for controlling YAML output formatting.
    public struct Options: Sendable {
        /// The number of spaces to use for each indentation level.
        public var indentSize: Int
        
        /// Whether to use flow style for sequences and mappings when possible.
        public var useFlowStyle: Bool
        
        /// Whether to quote all string scalars.
        public var forceQuotes: Bool
        
        /// The line width for folded scalars.
        public var lineWidth: Int
        
        /// Whether to sort mapping keys alphabetically.
        public var sortKeys: Bool
        
        /// Whether to use anchors for repeated node references.
        public var useAnchorsForRepeatedNodes: Bool
        
        /// Whether to preserve the original scalar style when possible.
        public var preserveScalarStyle: Bool
        
        /// Whether to emit in canonical form (explicit tags, flow style, quoted strings).
        public var canonical: Bool
        
        /// Creates new emitter options with default values.
        public init(
            indentSize: Int = 2,
            useFlowStyle: Bool = false,
            forceQuotes: Bool = false,
            lineWidth: Int = 80,
            sortKeys: Bool = false,
            useAnchorsForRepeatedNodes: Bool = false,
            preserveScalarStyle: Bool = false,
            canonical: Bool = false
        ) {
            self.indentSize = indentSize
            self.useFlowStyle = useFlowStyle || canonical
            self.forceQuotes = forceQuotes || canonical
            self.lineWidth = lineWidth
            self.sortKeys = sortKeys || canonical
            self.useAnchorsForRepeatedNodes = useAnchorsForRepeatedNodes
            self.preserveScalarStyle = preserveScalarStyle && !canonical
            self.canonical = canonical
        }
    }
    
    private let options: Options
    private var seenNodes: [YAMLNode: String] = [:] // Maps nodes to their anchors
    private var anchorCounter = 0
    
    /// Creates a new YAML emitter with the specified options.
    /// - Parameter options: Options for controlling output formatting.
    public init(options: Options = Options()) {
        self.options = options
    }
    
    /// Converts a YAMLNode to a YAML-formatted string.
    /// - Parameter node: The YAML node to emit.
    /// - Returns: A YAML-formatted string representation of the node.
    public func emit(_ node: YAMLNode) -> String {
        // Reset state
        seenNodes = [:]
        anchorCounter = 0
        
        // First pass: find repeated nodes if anchors are enabled
        if options.useAnchorsForRepeatedNodes {
            var nodeOccurrences: [YAMLNode: Int] = [:]
            countOccurrences(node, in: &nodeOccurrences)
            
            // Prepare anchor names for nodes that appear more than once
            var anchorsToAssign: [YAMLNode: String] = [:]
            for (repeatedNode, count) in nodeOccurrences where count > 1 {
                // Only use anchors for non-scalar nodes
                switch repeatedNode {
                case .scalar:
                    continue
                case .mapping, .sequence:
                    anchorCounter += 1
                    anchorsToAssign[repeatedNode] = "id\(anchorCounter)"
                }
            }
            
            // Store which nodes need anchors (initially empty to indicate not yet emitted)
            for (node, _) in anchorsToAssign {
                seenNodes[node] = ""
            }
        }
        
        var output = ""
        emitNode(node, to: &output, indent: 0, isRoot: true)
        return output
    }
    
    private func countOccurrences(_ node: YAMLNode, in occurrences: inout [YAMLNode: Int]) {
        // Count this node
        occurrences[node, default: 0] += 1
        
        // Recurse into children
        switch node {
        case .scalar:
            break
        case .sequence(let items):
            for item in items {
                countOccurrences(item, in: &occurrences)
            }
        case .mapping(let dict):
            for (_, value) in dict {
                countOccurrences(value, in: &occurrences)
            }
        }
    }
    
    private func escapeKey(_ key: String) -> String {
        // Check if key needs quoting
        if needsQuoting(key) {
            return "\"\(key.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return key
    }
    
    private func canBeInline(_ dict: [String: YAMLNode]) -> Bool {
        // Check if all values are simple scalars
        for (_, value) in dict {
            if case .scalar = value {
                continue
            } else {
                return false
            }
        }
        return true
    }
    
    
    private func emitNode(_ node: YAMLNode, to output: inout String, indent: Int, isRoot: Bool) {
        // Check if this node should use an anchor or alias
        if options.useAnchorsForRepeatedNodes {
            switch node {
            case .scalar:
                // Don't use anchors for scalars
                break
            case .mapping, .sequence:
                if seenNodes.keys.contains(node) {
                    let currentAnchor = seenNodes[node]!
                    if currentAnchor.isEmpty {
                        // First occurrence - assign and emit anchor
                        anchorCounter += 1
                        let anchor = "id\(anchorCounter)"
                        seenNodes[node] = anchor
                        output += "&\(anchor) "
                    } else {
                        // Subsequent occurrence - emit alias
                        output += "*\(currentAnchor)"
                        return
                    }
                }
            }
        }
        
        switch node {
        case .scalar(let scalar):
            emitScalar(scalar, to: &output)
            
        case .sequence(let items):
            if options.canonical {
                output += "!!seq "
            }
            if items.isEmpty || options.canonical {
                // Always use flow style for empty sequences and canonical mode
                emitFlowSequence(items, to: &output)
            } else if options.useFlowStyle && canUseFlowStyle(for: .sequence(items)) {
                emitFlowSequence(items, to: &output)
            } else {
                emitBlockSequence(items, to: &output, indent: indent, isRoot: isRoot)
            }
            
        case .mapping(let dict):
            if options.canonical {
                output += "!!map "
            }
            if dict.isEmpty || options.canonical {
                // Always use flow style for empty mappings and canonical mode
                emitFlowMapping(dict, to: &output)
            } else if options.useFlowStyle && canUseFlowStyle(for: .mapping(dict)) {
                emitFlowMapping(dict, to: &output)
            } else {
                emitBlockMapping(dict, to: &output, indent: indent, isRoot: isRoot)
            }
        }
    }
    
    private func emitScalar(_ scalar: YAMLNode.Scalar, to output: inout String) {
        // In canonical mode, always emit tags
        if options.canonical {
            let tag = scalar.tag ?? detectDefaultTag(for: scalar.value) ?? .str
            output += shortForm(of: tag)
            output += " "
        } else if let tag = scalar.tag {
            // Emit tag if present and not the default
            // For quoted scalars, always check if we need to emit the tag
            let needsTag: Bool
            if scalar.style == .doubleQuoted || scalar.style == .singleQuoted {
                // Quoted strings are always parsed as strings, so emit tag if it's not a string
                needsTag = tag != .str
            } else {
                // For plain scalars, only emit tag if it's not the default for the value
                let detectedTag = detectDefaultTag(for: scalar.value)
                needsTag = tag != detectedTag
            }
            
            if needsTag {
                output += shortForm(of: tag)
                output += " "
            }
        }
        
        switch scalar.style {
        case .plain:
            // In canonical mode, always quote strings
            if options.canonical {
                let tag = scalar.tag ?? detectDefaultTag(for: scalar.value) ?? .str
                if tag == .str {
                    output += "\""
                    output += escapeString(scalar.value)
                    output += "\""
                } else {
                    output += scalar.value
                }
            } else if options.preserveScalarStyle && scalar.tag == nil {
                // When preserving style and no explicit tag, emit as-is if possible
                let shouldQuote = options.forceQuotes || needsQuotingForValidYAML(scalar.value)
                if shouldQuote {
                    output += "\""
                    output += escapeString(scalar.value)
                    output += "\""
                } else {
                    output += scalar.value
                }
            } else {
                // Don't quote if we have an explicit tag that matches the value type
                let detectedType = detectDefaultTag(for: scalar.value)
                let hasMatchingTag = scalar.tag != nil && scalar.tag == detectedType
                
                let shouldQuote = options.forceQuotes || 
                    (!hasMatchingTag && needsQuoting(scalar.value))
                    
                if shouldQuote {
                    output += "\""
                    output += escapeString(scalar.value)
                    output += "\""
                } else {
                    output += scalar.value
                }
            }
            
        case .singleQuoted:
            output += "'"
            output += scalar.value.replacingOccurrences(of: "'", with: "''")
            output += "'"
            
        case .doubleQuoted:
            output += "\""
            output += escapeString(scalar.value)
            output += "\""
            
        case .literal:
            output += "|\n"
            let lines = scalar.value.split(separator: "\n", omittingEmptySubsequences: false)
            for line in lines {
                output += String(repeating: " ", count: options.indentSize)
                output += line
                output += "\n"
            }
            
        case .folded:
            output += ">\n"
            // For folded scalars, newlines in the value represent paragraph breaks
            // Each paragraph needs to be separated by a blank line in the output
            let paragraphs = scalar.value.split(separator: "\n", omittingEmptySubsequences: false)
            
            for (index, paragraph) in paragraphs.enumerated() {
                if index > 0 {
                    // Add blank line between paragraphs
                    output += String(repeating: " ", count: options.indentSize)
                    output += "\n"
                }
                
                // Emit the paragraph (may be empty for consecutive newlines)
                if paragraph.isEmpty {
                    // Empty paragraph - just skip, we already added the blank line
                    continue
                }
                
                // Wrap paragraph text at line width
                emitFoldedParagraph(String(paragraph), 
                                  to: &output, 
                                  indent: options.indentSize, 
                                  lineWidth: options.lineWidth)
                output += "\n"
            }
            
            // Remove trailing newline if the last paragraph was empty
            if scalar.value.hasSuffix("\n") && output.hasSuffix("\n\n") {
                output.removeLast()
            }
        }
    }
    
    private func emitFoldedParagraph(_ paragraph: String, to output: inout String, indent: Int, lineWidth: Int) {
        let words = paragraph.split(separator: " ")
        var currentLine = String(repeating: " ", count: indent)
        var currentLength = indent
        
        for word in words {
            if currentLength + word.count + 1 > lineWidth && currentLength > indent {
                output += currentLine
                output += "\n"
                currentLine = String(repeating: " ", count: indent)
                currentLength = indent
            }
            
            if currentLength > indent {
                currentLine += " "
                currentLength += 1
            }
            
            currentLine += word
            currentLength += word.count
        }
        
        if currentLength > indent {
            output += currentLine
        }
    }
    
    private func emitBlockSequence(_ items: [YAMLNode], to output: inout String, indent: Int, isRoot: Bool) {
        if !isRoot && !output.isEmpty && !output.hasSuffix("\n") {
            output += "\n"
        }
        
        for item in items {
            output += String(repeating: " ", count: indent)
            output += "- "
            
            switch item {
            case .scalar:
                emitNode(item, to: &output, indent: indent + options.indentSize, isRoot: false)
                output += "\n"
                
            case .sequence:
                output += "\n"
                emitNode(item, to: &output, indent: indent + options.indentSize, isRoot: false)
                
            case .mapping(let dict):
                // For small mappings, consider inline format
                if dict.count <= 3 && canBeInline(dict) {
                    var first = true
                    let keysToEmit: [String]
                    if options.sortKeys {
                        keysToEmit = dict.keys.sorted()
                    } else {
                        // Put "name" first if it exists for better readability
                        var keys = Array(dict.keys)
                        if let nameIndex = keys.firstIndex(of: "name") {
                            keys.remove(at: nameIndex)
                            keys.insert("name", at: 0)
                        }
                        keysToEmit = keys
                    }
                    for key in keysToEmit {
                        guard let value = dict[key] else { continue }
                        if !first {
                            output += "\n"
                            output += String(repeating: " ", count: indent + 2)
                        }
                        first = false
                        output += escapeKey(key)
                        output += ": "
                        
                        if case .scalar(let scalar) = value {
                            emitScalar(scalar, to: &output)
                        } else {
                            output += "\n"
                            emitNode(value, to: &output, indent: indent + options.indentSize + 2, isRoot: false)
                        }
                    }
                    output += "\n"
                } else {
                    output += "\n"
                    emitNode(item, to: &output, indent: indent + options.indentSize, isRoot: false)
                }
            }
        }
    }
    
    private func emitBlockMapping(_ dict: [String: YAMLNode], to output: inout String, indent: Int, isRoot: Bool) {
        if !isRoot && !output.isEmpty && !output.hasSuffix("\n") {
            output += "\n"
        }
        
        let keys = options.sortKeys ? dict.keys.sorted() : Array(dict.keys)
        
        for key in keys {
            guard let value = dict[key] else { continue }
            
            output += String(repeating: " ", count: indent)
            
            if needsQuoting(key) {
                output += "\""
                output += escapeString(key)
                output += "\""
            } else {
                output += key
            }
            
            output += ": "
            
            switch value {
            case .scalar(let scalar):
                emitNode(value, to: &output, indent: indent + options.indentSize, isRoot: false)
                // Only add newline if not already present (literal/folded scalars add their own)
                if scalar.style != .literal && scalar.style != .folded {
                    output += "\n"
                }
                
            case .sequence(let items) where items.isEmpty:
                // Empty sequences go on the same line
                emitNode(value, to: &output, indent: indent + options.indentSize, isRoot: false)
                output += "\n"
                
            case .mapping(let dict) where dict.isEmpty:
                // Empty mappings go on the same line
                emitNode(value, to: &output, indent: indent + options.indentSize, isRoot: false)
                output += "\n"
                
            case .sequence, .mapping:
                output += "\n"
                emitNode(value, to: &output, indent: indent + options.indentSize, isRoot: false)
            }
        }
    }
    
    private func emitFlowSequence(_ items: [YAMLNode], to output: inout String) {
        output += "["
        
        for (index, item) in items.enumerated() {
            if index > 0 {
                output += ", "
            }
            emitNode(item, to: &output, indent: 0, isRoot: false)
        }
        
        output += "]"
    }
    
    private func emitFlowMapping(_ dict: [String: YAMLNode], to output: inout String) {
        output += "{"
        
        let keys = options.sortKeys ? dict.keys.sorted() : Array(dict.keys)
        
        for (index, key) in keys.enumerated() {
            guard let value = dict[key] else { continue }
            
            if index > 0 {
                output += ", "
            }
            
            if needsQuoting(key) {
                output += "\""
                output += escapeString(key)
                output += "\""
            } else {
                output += key
            }
            
            output += ": "
            emitNode(value, to: &output, indent: 0, isRoot: false)
        }
        
        output += "}"
    }
    
    private func canUseFlowStyle(for node: YAMLNode) -> Bool {
        switch node {
        case .scalar:
            return true
            
        case .sequence(let items):
            return items.count <= 5 && items.allSatisfy { child in
                if case .scalar = child {
                    return true
                }
                return false
            }
            
        case .mapping(let dict):
            return dict.count <= 3 && dict.values.allSatisfy { child in
                if case .scalar = child {
                    return true
                }
                return false
            }
        }
    }
    
    private func needsQuoting(_ string: String) -> Bool {
        if string.isEmpty {
            return true
        }
        
        // Special YAML values that need quoting to preserve as strings
        let specialStrings = ["true", "false", "yes", "no", "on", "off", "null", "~"]
        if specialStrings.contains(string.lowercased()) {
            return true
        }
        
        // Quote numeric strings to preserve them as strings
        if Int(string) != nil || Double(string) != nil {
            return true
        }
        
        // Check for characters that require quoting
        // Note: comma, exclamation, and @ are allowed in plain scalars  
        let needsQuoteCharacters = CharacterSet(charactersIn: ":{}[]&*#?|<>=%\\\n\t")
        if string.rangeOfCharacter(from: needsQuoteCharacters) != nil {
            return true
        }
        
        // Also check for - at the beginning (could be confused with list item)
        if string.hasPrefix("-") {
            return true
        }
        
        if string.hasPrefix(" ") || string.hasSuffix(" ") {
            return true
        }
        
        return false
    }
    
    private func escapeString(_ string: String) -> String {
        var escaped = ""
        
        for char in string {
            switch char {
            case "\\":
                escaped += "\\\\"
            case "\"":
                escaped += "\\\""
            case "\n":
                escaped += "\\n"
            case "\r":
                escaped += "\\r"
            case "\t":
                escaped += "\\t"
            case "\0":
                escaped += "\\0"
            case "\u{07}":
                escaped += "\\a"
            case "\u{08}":
                escaped += "\\b"
            case "\u{0B}":
                escaped += "\\v"
            case "\u{0C}":
                escaped += "\\f"
            case "\u{1B}":
                escaped += "\\e"
            case "\u{85}":
                escaped += "\\N"
            case "\u{A0}":
                escaped += "\\_"
            case "\u{2028}":
                escaped += "\\L"
            case "\u{2029}":
                escaped += "\\P"
            default:
                escaped.append(char)
            }
        }
        
        return escaped
    }
    
    private func needsQuotingForValidYAML(_ string: String) -> Bool {
        // Only quote if absolutely necessary for valid YAML syntax
        if string.isEmpty {
            return true
        }
        
        // Characters that would make the YAML invalid if not quoted
        let invalidChars = CharacterSet(charactersIn: ":[]{},#&*!|>%@\\`")
        if string.rangeOfCharacter(from: invalidChars) != nil {
            return true
        }
        
        // Leading/trailing whitespace
        if string.hasPrefix(" ") || string.hasSuffix(" ") ||
           string.hasPrefix("\t") || string.hasSuffix("\t") {
            return true
        }
        
        // Leading dash could be confused with list item
        if string.hasPrefix("-") && string.count > 1 && string[string.index(after: string.startIndex)] == " " {
            return true
        }
        
        // Leading question mark followed by space
        if string.hasPrefix("? ") {
            return true
        }
        
        // Contains newlines (should use block scalar instead)
        if string.contains("\n") {
            return true
        }
        
        return false
    }
    
    private func detectDefaultTag(for value: String) -> YAMLNode.Scalar.Tag? {
        // Detect the default tag based on YAML 1.2 core schema
        
        // Check for null
        if value.lowercased() == "null" || value == "~" || value.isEmpty {
            return .null
        }
        
        // Check for boolean
        let lowercased = value.lowercased()
        if lowercased == "true" || lowercased == "false" ||
           lowercased == "yes" || lowercased == "no" ||
           lowercased == "on" || lowercased == "off" {
            return .bool
        }
        
        // Check for integer (including special formats)
        if value.hasPrefix("0x") || value.hasPrefix("0X") ||
           value.hasPrefix("-0x") || value.hasPrefix("-0X") ||
           value.hasPrefix("0o") || value.hasPrefix("0O") ||
           value.hasPrefix("-0o") || value.hasPrefix("-0O") ||
           value.hasPrefix("0b") || value.hasPrefix("0B") ||
           value.hasPrefix("-0b") || value.hasPrefix("-0B") {
            return .int
        }
        
        // Check for float special values
        if value == ".inf" || value == "+.inf" || value == "-.inf" ||
           value == ".nan" || value.lowercased() == ".nan" {
            return .float
        }
        
        // Try parsing as number
        let cleanedValue = value.replacingOccurrences(of: "_", with: "")
        if Int(cleanedValue) != nil {
            return .int
        }
        if Double(cleanedValue) != nil {
            return .float
        }
        
        // Default to string
        return .str
    }
    
    private func shortForm(of tag: YAMLNode.Scalar.Tag) -> String {
        // Convert tag to short form for emission
        switch tag {
        case .str: return "!!str"
        case .int: return "!!int"
        case .float: return "!!float"
        case .bool: return "!!bool"
        case .null: return "!!null"
        case .timestamp: return "!!timestamp"
        case .binary: return "!!binary"
        default:
            // For custom tags, check if it's already in short form
            if tag.rawValue.hasPrefix("!") {
                return tag.rawValue
            } else {
                // Assume it's a full URI form, return as-is
                // In a full implementation, we'd handle tag shorthand properly
                return tag.rawValue
            }
        }
    }
}
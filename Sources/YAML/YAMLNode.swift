#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/// Represents a YAML node which can be a scalar, sequence, or mapping.
/// 
/// YAMLNode is the fundamental data structure in this library, representing
/// any valid YAML value. It supports three types:
/// - scalar: A single value (string, number, boolean, null)
/// - sequence: An ordered list of nodes
/// - mapping: A key-value dictionary of nodes
public enum YAMLNode: Sendable, Hashable {
    case scalar(Scalar)
    case sequence([YAMLNode])
    case mapping([String: YAMLNode])
    
    /// Represents a scalar value in YAML with optional tag and style information.
    ///
    /// Scalars are the leaf nodes in a YAML document and can represent
    /// strings, numbers, booleans, nulls, and other atomic values.
    public struct Scalar: Sendable, Hashable {
        public let value: String
        public let tag: Tag?
        public let style: Style
        
        /// YAML tag representing the type of scalar value.
        ///
        /// Tags provide type information for scalar values according to
        /// the YAML 1.2 specification.
        public struct Tag: RawRepresentable, Hashable, Sendable {
            public let rawValue: String
            
            public init(rawValue: String) {
                self.rawValue = rawValue
            }
            
            // Standard YAML tags
            public static let str = Tag(rawValue: "tag:yaml.org,2002:str")
            public static let int = Tag(rawValue: "tag:yaml.org,2002:int")
            public static let float = Tag(rawValue: "tag:yaml.org,2002:float")
            public static let bool = Tag(rawValue: "tag:yaml.org,2002:bool")
            public static let null = Tag(rawValue: "tag:yaml.org,2002:null")
            public static let timestamp = Tag(rawValue: "tag:yaml.org,2002:timestamp")
            public static let binary = Tag(rawValue: "tag:yaml.org,2002:binary")
            
            // Helper to create tags from short forms
            public init?(shortForm: String) {
                switch shortForm {
                case "!!str": self = .str
                case "!!int": self = .int
                case "!!float": self = .float
                case "!!bool": self = .bool
                case "!!null": self = .null
                case "!!timestamp": self = .timestamp
                case "!!binary": self = .binary
                default:
                    // Custom tag
                    self.rawValue = shortForm
                }
            }
        }
        
        /// The presentation style for scalar values.
        ///
        /// Style controls how scalar values are formatted when emitting YAML.
        public enum Style: Sendable, Hashable {
            case plain
            case singleQuoted
            case doubleQuoted
            case literal
            case folded
        }
        
        public init(value: String, tag: Tag? = nil, style: Style = .plain) {
            self.value = value
            self.tag = tag
            self.style = style
        }
    }
}

extension YAMLNode {
    /// Returns the string value if this node is a scalar.
    /// - Returns: The string value, or nil if not a scalar.
    public var string: String? {
        guard case .scalar(let scalar) = self else { return nil }
        return scalar.value
    }
    
    /// Returns the integer value if this node is a scalar that can be parsed as Int.
    /// - Returns: The integer value, or nil if not a scalar or cannot be parsed.
    public var int: Int? {
        guard case .scalar(let scalar) = self else { return nil }
        
        let value = scalar.value
        
        // Handle special integer formats
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            return Int(value.dropFirst(2), radix: 16)
        } else if value.hasPrefix("-0x") || value.hasPrefix("-0X") {
            if let positiveValue = Int(value.dropFirst(3), radix: 16) {
                return -positiveValue
            }
        } else if value.hasPrefix("0o") || value.hasPrefix("0O") {
            return Int(value.dropFirst(2), radix: 8)
        } else if value.hasPrefix("-0o") || value.hasPrefix("-0O") {
            if let positiveValue = Int(value.dropFirst(3), radix: 8) {
                return -positiveValue
            }
        } else if value.hasPrefix("0b") || value.hasPrefix("0B") {
            return Int(value.dropFirst(2), radix: 2)
        } else if value.hasPrefix("-0b") || value.hasPrefix("-0B") {
            if let positiveValue = Int(value.dropFirst(3), radix: 2) {
                return -positiveValue
            }
        } else if value.contains("_") {
            // Number with underscores
            let cleanedValue = value.replacingOccurrences(of: "_", with: "")
            return Int(cleanedValue)
        }
        
        return Int(value)
    }
    
    /// Returns the double value if this node is a scalar that can be parsed as Double.
    /// - Returns: The double value, or nil if not a scalar or cannot be parsed.
    public var double: Double? {
        guard case .scalar(let scalar) = self else { return nil }
        
        let value = scalar.value
        
        // Handle special float values
        if value == ".inf" || value == "+.inf" {
            return Double.infinity
        } else if value == "-.inf" {
            return -Double.infinity
        } else if value == ".nan" || value.lowercased() == ".nan" {
            return Double.nan
        } else if value.contains("_") {
            // Number with underscores
            let cleanedValue = value.replacingOccurrences(of: "_", with: "")
            return Double(cleanedValue)
        }
        
        return Double(value)
    }
    
    /// Returns the boolean value if this node is a scalar representing a boolean.
    /// 
    /// Recognizes the following boolean representations:
    /// - true: "true", "yes", "on", "y" (case-insensitive)
    /// - false: "false", "no", "off", "n" (case-insensitive)
    /// - Returns: The boolean value, or nil if not a valid boolean representation.
    public var bool: Bool? {
        guard case .scalar(let scalar) = self else { return nil }
        switch scalar.value.lowercased() {
        case "true", "yes", "on", "y":
            return true
        case "false", "no", "off", "n":
            return false
        default:
            return nil
        }
    }
    
    /// Checks if this node represents a null value.
    /// 
    /// Recognizes "null", "~", and empty strings as null values, but only
    /// when they are plain scalars or have a null tag.
    /// - Returns: true if the node represents null, false otherwise.
    public var isNull: Bool {
        guard case .scalar(let scalar) = self else { return false }
        
        // If it has an explicit null tag, it's null
        if scalar.tag == .null {
            return true
        }
        
        // If it has any other explicit tag (including .str), it's not null
        if scalar.tag != nil {
            return false
        }
        
        // For quoted scalars without explicit tags, they're strings not nulls
        if scalar.style == .singleQuoted || scalar.style == .doubleQuoted {
            return false
        }
        
        // For plain scalars, check the value
        return scalar.value.lowercased() == "null" || 
               scalar.value.lowercased() == "~" ||
               scalar.value.isEmpty
    }
    
    /// Returns the array of nodes if this is a sequence node.
    /// - Returns: Array of YAMLNode, or nil if not a sequence.
    public var array: [YAMLNode]? {
        guard case .sequence(let nodes) = self else { return nil }
        return nodes
    }
    
    /// Returns the dictionary if this is a mapping node.
    /// - Returns: Dictionary mapping strings to YAMLNode, or nil if not a mapping.
    public var dictionary: [String: YAMLNode]? {
        guard case .mapping(let dict) = self else { return nil }
        return dict
    }
    
    /// Accesses a node at the specified index if this is a sequence.
    /// - Parameter index: The index of the element to access.
    /// - Returns: The node at the index, or nil if not a sequence or index out of bounds.
    public subscript(index: Int) -> YAMLNode? {
        guard case .sequence(let nodes) = self,
              index >= 0 && index < nodes.count else { return nil }
        return nodes[index]
    }
    
    /// Accesses a node for the specified key if this is a mapping.
    /// - Parameter key: The key to look up.
    /// - Returns: The node for the key, or nil if not a mapping or key not found.
    public subscript(key: String) -> YAMLNode? {
        guard case .mapping(let dict) = self else { return nil }
        return dict[key]
    }
}

extension YAMLNode: Equatable {}
extension YAMLNode.Scalar: Equatable {}
extension YAMLNode.Scalar.Tag: Equatable {}
extension YAMLNode.Scalar.Style: Equatable {}
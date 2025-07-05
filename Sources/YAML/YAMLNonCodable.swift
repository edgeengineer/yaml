/// Non-Codable YAML support for Embedded Swift and platforms without Foundation
///
/// This module provides a lightweight YAML parsing and generation API that doesn't
/// depend on Codable or Foundation, making it suitable for embedded systems and
/// other constrained environments.

/// A lightweight YAML builder that doesn't require Codable support
public struct YAMLBuilder {
    /// Creates a YAML string from a YAMLNode
    /// - Parameter node: The YAML node to convert to string
    /// - Returns: A formatted YAML string
    public static func build(from node: YAMLNode) -> String {
        return buildNode(node, indent: 0)
    }
    
    private static func buildNode(_ node: YAMLNode, indent: Int) -> String {
        let indentString = String(repeating: " ", count: indent)
        
        switch node {
        case .scalar(let scalar):
            return formatScalar(scalar)
            
        case .sequence(let array):
            if array.isEmpty {
                return "[]"
            }
            if indent == 0 {
                return array.map { item in
                    "- \(buildNode(item, indent: indent + 2))"
                }.joined(separator: "\n")
            } else {
                return "\n" + array.map { item in
                    "\(indentString)- \(buildNode(item, indent: indent + 2))"
                }.joined(separator: "\n")
            }
            
        case .mapping(let dict):
            if dict.isEmpty {
                return "{}"
            }
            let entries = dict.sorted(by: { $0.key < $1.key }).map { key, value in
                let valueStr = buildNode(value, indent: indent + 2)
                if case .sequence = value {
                    return "\(key):\(valueStr)"
                } else if case .mapping = value {
                    return "\(key):\n\(indentString)  \(valueStr)"
                } else {
                    return "\(key): \(valueStr)"
                }
            }
            
            if indent == 0 {
                return entries.joined(separator: "\n")
            } else {
                return "\n" + entries.map { "\(indentString)\($0)" }.joined(separator: "\n")
            }
        }
    }
    
    private static func formatScalar(_ scalar: YAMLNode.Scalar) -> String {
        switch scalar.style {
        case .plain:
            return scalar.value
        case .singleQuoted:
            return "'\(scalar.value)'"
        case .doubleQuoted:
            return "\"\(scalar.value)\""
        case .literal:
            return "|\n  \(scalar.value.replacingOccurrences(of: "\n", with: "\n  "))"
        case .folded:
            return ">\n  \(scalar.value.replacingOccurrences(of: "\n", with: "\n  "))"
        }
    }
}

/// Lightweight YAML parsing without Codable
public extension YAMLNode {
    /// Creates a YAMLNode from a string value
    /// - Parameter string: The string value
    /// - Returns: A scalar YAMLNode
    static func string(_ value: String) -> YAMLNode {
        return .scalar(Scalar(value: value, tag: .str, style: .plain))
    }
    
    /// Creates a YAMLNode from an integer value
    /// - Parameter int: The integer value
    /// - Returns: A scalar YAMLNode
    static func int(_ value: Int) -> YAMLNode {
        return .scalar(Scalar(value: String(value), tag: .int, style: .plain))
    }
    
    /// Creates a YAMLNode from a double value
    /// - Parameter double: The double value
    /// - Returns: A scalar YAMLNode
    static func double(_ value: Double) -> YAMLNode {
        return .scalar(Scalar(value: String(value), tag: .float, style: .plain))
    }
    
    /// Creates a YAMLNode from a boolean value
    /// - Parameter bool: The boolean value
    /// - Returns: A scalar YAMLNode
    static func bool(_ value: Bool) -> YAMLNode {
        return .scalar(Scalar(value: value ? "true" : "false", tag: .bool, style: .plain))
    }
    
    /// Creates a null YAMLNode
    /// - Returns: A scalar YAMLNode representing null
    static var null: YAMLNode {
        return .scalar(Scalar(value: "null", tag: .null, style: .plain))
    }
    
    /// Creates a YAMLNode from an array of nodes
    /// - Parameter array: The array of YAMLNodes
    /// - Returns: A sequence YAMLNode
    static func array(_ nodes: [YAMLNode]) -> YAMLNode {
        return .sequence(nodes)
    }
    
    /// Creates a YAMLNode from a dictionary
    /// - Parameter dict: The dictionary mapping strings to YAMLNodes
    /// - Returns: A mapping YAMLNode
    static func dictionary(_ dict: [String: YAMLNode]) -> YAMLNode {
        return .mapping(dict)
    }
}

/// A simple YAML path accessor for non-Codable usage
public extension YAMLNode {
    /// Access nested values using a path notation
    /// - Parameter path: A dot-separated path (e.g., "user.name")
    /// - Returns: The YAMLNode at the path, or nil if not found
    func value(at path: String) -> YAMLNode? {
        let components = path.split(separator: ".").map(String.init)
        return value(at: components)
    }
    
    /// Access nested values using path components
    /// - Parameter components: An array of path components
    /// - Returns: The YAMLNode at the path, or nil if not found
    func value(at components: [String]) -> YAMLNode? {
        var current: YAMLNode = self
        
        for component in components {
            if let dict = current.dictionary {
                guard let next = dict[component] else { return nil }
                current = next
            } else if let array = current.array,
                      let index = Int(component),
                      index >= 0 && index < array.count {
                current = array[index]
            } else {
                return nil
            }
        }
        
        return current
    }
}

/// YAML document builder using result builders
@resultBuilder
public struct YAMLDocumentBuilder {
    public static func buildBlock(_ components: YAMLNode...) -> YAMLNode {
        if components.count == 1 {
            return components[0]
        }
        return .sequence(components)
    }
    
    public static func buildOptional(_ component: YAMLNode?) -> YAMLNode {
        return component ?? .null
    }
    
    public static func buildEither(first component: YAMLNode) -> YAMLNode {
        return component
    }
    
    public static func buildEither(second component: YAMLNode) -> YAMLNode {
        return component
    }
    
    public static func buildArray(_ components: [YAMLNode]) -> YAMLNode {
        return .sequence(components)
    }
}

/// Helper function to build YAML documents using result builders
/// - Parameter content: The content builder closure
/// - Returns: A YAMLNode representing the document
public func yaml(@YAMLDocumentBuilder content: () -> YAMLNode) -> YAMLNode {
    return content()
}
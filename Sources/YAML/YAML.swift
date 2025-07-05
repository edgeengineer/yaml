import Foundation

/// The main YAML namespace providing parsing and emitting functionality.
public enum YAML {
    /// Parses a YAML string into a YAMLNode structure.
    /// - Parameter yaml: The YAML string to parse.
    /// - Returns: A YAMLNode representing the parsed YAML structure.
    /// - Throws: YAMLError if the input is not valid YAML.
    public static func parse(_ yaml: String) throws -> YAMLNode {
        let parser = YAMLParser()
        return try parser.parse(yaml)
    }
    
    /// Converts a YAMLNode to a YAML-formatted string.
    /// - Parameters:
    ///   - node: The YAMLNode to convert.
    ///   - options: Options for controlling the output format.
    /// - Returns: A YAML-formatted string representation of the node.
    public static func emit(_ node: YAMLNode, options: YAMLEmitter.Options = .init()) -> String {
        let emitter = YAMLEmitter(options: options)
        return emitter.emit(node)
    }
    
    /// Parses a YAML string containing multiple documents separated by ---
    /// - Parameter yaml: The YAML string containing multiple documents.
    /// - Returns: An array of YAMLNode objects, one for each document.
    /// - Throws: YAMLError if any document contains invalid YAML.
    public static func parseStream(_ yaml: String) throws -> [YAMLNode] {
        let parser = YAMLParser()
        return try parser.parseStream(yaml)
    }
    
    /// Emits multiple YAML documents to a string, separated by ---
    /// - Parameters:
    ///   - nodes: The array of YAMLNode objects to emit.
    ///   - options: Options for controlling the output format.
    /// - Returns: A YAML-formatted string with documents separated by ---
    public static func emit(_ nodes: [YAMLNode], options: YAMLEmitter.Options = .init()) -> String {
        let emitter = YAMLEmitter(options: options)
        return nodes.enumerated().map { index, node in
            (index > 0 ? "---\n" : "") + emitter.emit(node)
        }.joined()
    }
}

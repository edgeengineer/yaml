import Foundation
/// A builder that constructs YAML nodes from streaming tokens.
/// This can be used with YAMLStreamParser to build partial or complete YAML structures.
public final class YAMLStreamBuilder: YAMLStreamParserDelegate {
    private var nodeStack: [BuilderNode] = []
    private var rootNode: YAMLNode?
    private var currentKey: String?
    
    /// Callback invoked when a complete top-level node is built
    public var onNodeComplete: ((YAMLNode) -> Void)?
    
    /// The maximum depth to build. Beyond this depth, nodes are skipped.
    /// This is useful for processing only top-level elements of large files.
    public var maxDepth: Int = Int.max
    
    private enum BuilderNode {
        case mapping([String: YAMLNode])
        case sequence([YAMLNode])
        case scalar(YAMLNode.Scalar)
    }
    
    public init() {}
    
    /// Resets the builder state
    public func reset() {
        nodeStack.removeAll()
        rootNode = nil
        currentKey = nil
    }
    
    // MARK: - YAMLStreamParserDelegate
    
    public func parser(_ parser: YAMLStreamParser, didParse token: YAMLToken) {
        // Skip if we're beyond max depth
        if nodeStack.count >= maxDepth {
            return
        }
        
        switch token {
        case .documentStart:
            reset()
            
        case .documentEnd:
            finalizeParsing()
            
        case .mappingStart:
            nodeStack.append(.mapping([:]))
            
        case .mappingEnd:
            if case .mapping(let dict) = nodeStack.popLast() {
                let node = YAMLNode.mapping(dict)
                addNode(node)
            }
            
        case .sequenceStart:
            nodeStack.append(.sequence([]))
            
        case .sequenceEnd:
            if case .sequence(let array) = nodeStack.popLast() {
                let node = YAMLNode.sequence(array)
                addNode(node)
            }
            
        case .key(let key):
            currentKey = key
            
        case .scalar(let scalar):
            let node = YAMLNode.scalar(scalar)
            addNode(node)
        }
    }
    
    public func parserDidEndDocument(_ parser: YAMLStreamParser) {
        finalizeParsing()
    }
    
    // MARK: - Private Methods
    
    private func addNode(_ node: YAMLNode) {
        if nodeStack.isEmpty {
            // Top-level node
            if rootNode == nil {
                rootNode = node
            }
            onNodeComplete?(node)
            return
        }
        
        guard let current = nodeStack.popLast() else { return }
        
        switch current {
        case .mapping(var dict):
            if let key = currentKey {
                dict[key] = node
                currentKey = nil
            }
            nodeStack.append(.mapping(dict))
            
        case .sequence(var array):
            array.append(node)
            nodeStack.append(.sequence(array))
            
        case .scalar:
            // This shouldn't happen
            break
        }
    }
    
    private func finalizeParsing() {
        if let root = rootNode {
            onNodeComplete?(root)
        }
        reset()
    }
}

/// A specialized stream builder that only processes top-level elements.
/// Useful for processing large files where you only need metadata or specific entries.
public final class YAMLTopLevelStreamBuilder: YAMLStreamParserDelegate {
    private var currentKey: String?
    private var depth: Int = 0
    private var isInTopLevelMapping = false
    
    /// Callback for each top-level key-value pair
    public var onTopLevelEntry: ((String, YAMLNode) -> Void)?
    
    /// Keys to filter. If set, only these keys will be processed.
    public var filterKeys: Set<String>?
    
    public init() {}
    
    public func parser(_ parser: YAMLStreamParser, didParse token: YAMLToken) {
        switch token {
        case .documentStart:
            depth = 0
            isInTopLevelMapping = false
            
        case .mappingStart:
            if depth == 0 {
                isInTopLevelMapping = true
            }
            depth += 1
            
        case .mappingEnd:
            depth -= 1
            if depth == 0 {
                isInTopLevelMapping = false
            }
            
        case .sequenceStart:
            depth += 1
            
        case .sequenceEnd:
            depth -= 1
            
        case .key(let key):
            if isInTopLevelMapping && depth == 1 {
                currentKey = key
            }
            
        case .scalar(let scalar):
            if let key = currentKey, isInTopLevelMapping && depth == 1 {
                if filterKeys == nil || filterKeys?.contains(key) == true {
                    onTopLevelEntry?(key, .scalar(scalar))
                }
                currentKey = nil
            }
            
        default:
            break
        }
    }
}

/// Example usage for processing large YAML files efficiently
public extension YAMLStreamParser {
    /// Processes a YAML file and calls the handler for each top-level entry.
    /// This is memory-efficient for large files.
    ///
    /// Example:
    /// ```swift
    /// try YAMLStreamParser.processTopLevel(of: fileURL) { key, value in
    ///     if key == "metadata" {
    ///         // Process metadata
    ///     }
    /// }
    /// ```
    static func processTopLevel(
        of url: URL,
        keys: Set<String>? = nil,
        handler: @escaping (String, YAMLNode) -> Void
    ) throws {
        let parser = YAMLStreamParser()
        let builder = YAMLTopLevelStreamBuilder()
        builder.filterKeys = keys
        builder.onTopLevelEntry = handler
        parser.delegate = builder
        
        try parser.parse(contentsOf: url)
    }
    
    /// Processes a YAML stream in chunks, calling the handler for each complete node.
    /// Useful for processing arrays of items without loading all items into memory.
    ///
    /// Example:
    /// ```swift
    /// try YAMLStreamParser.processChunked(yaml: hugeYamlString, maxDepth: 2) { node in
    ///     // Process each node as it's completed
    /// }
    /// ```
    static func processChunked(
        yaml: String,
        maxDepth: Int = Int.max,
        handler: @escaping (YAMLNode) -> Void
    ) throws {
        let parser = YAMLStreamParser()
        let builder = YAMLStreamBuilder()
        builder.maxDepth = maxDepth
        builder.onNodeComplete = handler
        parser.delegate = builder
        
        try parser.parse(yaml)
    }
}
import Testing
@testable import YAML

@Suite("YAML Comment Preservation Tests")
struct YAMLCommentPreservationTests {
    
    @Test("Preserve comments in simple document", .enabled(if: false))
    func preserveSimpleComments() throws {
        // This test is disabled because comment preservation is not yet implemented
        let yaml = """
        # This is a header comment
        key: value  # inline comment
        
        # Comment before nested
        nested:
          # Comment in nested
          child: value
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        
        // Should preserve comments
        #expect(emitted.contains("# This is a header comment"))
        #expect(emitted.contains("# inline comment"))
        #expect(emitted.contains("# Comment before nested"))
        #expect(emitted.contains("# Comment in nested"))
    }
    
    @Test("Comment preservation would require YAMLNode changes", .enabled(if: false))
    func commentStructureNeeded() throws {
        // To properly preserve comments, we would need to:
        // 1. Add comment fields to YAMLNode
        // 2. Parse and store comments during parsing
        // 3. Emit comments during emission
        
        // Example of what the API might look like:
        /*
        struct YAMLNode {
            case scalar(Scalar, leadingComment: String?, trailingComment: String?)
            case sequence([YAMLNode], leadingComment: String?)
            case mapping([String: YAMLNode], leadingComment: String?)
        }
        */
        
        // Or use a separate comment map:
        /*
        struct YAMLDocument {
            let root: YAMLNode
            let comments: [YAMLNode.ID: [Comment]]
        }
        */
        
        #expect(true) // Placeholder
    }
    
    @Test("Document current comment behavior")
    func currentCommentBehavior() throws {
        let yaml = """
        # Header comment
        key: value  # inline comment
        # Another comment
        key2: value2
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        
        
        // Currently, comments are stripped
        #expect(!emitted.contains("#"))
    }
}
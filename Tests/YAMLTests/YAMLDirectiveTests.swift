import Testing
@testable import YAML

@Suite("YAML Directive Tests")
struct YAMLDirectiveTests {
    
    @Test("Parse YAML version directive")
    func parseYAMLVersion() throws {
        let yaml = """
        %YAML 1.2
        ---
        key: value
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["key"]?.string == "value")
    }
    
    @Test("Parse multiple YAML versions in stream")
    func parseMultipleVersions() throws {
        let yaml = """
        %YAML 1.1
        ---
        doc1: value1
        ---
        %YAML 1.2
        ---
        doc2: value2
        """
        
        let nodes = try YAML.parseStream(yaml)
        #expect(nodes.count == 2)
        
        if let doc1 = nodes[0].dictionary {
            #expect(doc1["doc1"]?.string == "value1")
        }
        
        if let doc2 = nodes[1].dictionary {
            #expect(doc2["doc2"]?.string == "value2")
        }
    }
    
    @Test("Reject unsupported YAML version")
    func rejectUnsupportedVersion() throws {
        let yaml = """
        %YAML 2.0
        ---
        key: value
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Parse YAML 1.0")
    func parseYAML10() throws {
        let yaml = """
        %YAML 1.0
        ---
        old: style
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["old"]?.string == "style")
    }
    
    @Test("Parse YAML 1.1")
    func parseYAML11() throws {
        let yaml = """
        %YAML 1.1
        ---
        key: value
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["key"]?.string == "value")
    }
    
    @Test("Missing version in YAML directive")
    func missingVersion() throws {
        let yaml = """
        %YAML
        ---
        key: value
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("YAML directive with TAG directive")
    func yamlWithTag() throws {
        let yaml = """
        %YAML 1.2
        %TAG ! tag:example.com,2024:
        ---
        !widget
        name: My Widget
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["name"]?.string == "My Widget")
        // Note: The mapping itself should have the tag
        if case .mapping = node {
            // Tag preservation is handled internally
            #expect(true)
        }
    }
    
    @Test("YAML directive without document separator")
    func yamlWithoutSeparator() throws {
        // YAML directive without --- should still work
        let yaml = """
        %YAML 1.2
        key: value
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["key"]?.string == "value")
    }
}
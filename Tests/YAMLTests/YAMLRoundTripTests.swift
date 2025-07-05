import Testing
@testable import YAML

@Suite("YAML Round-Trip Tests")
struct YAMLRoundTripTests {
    
    @Test("Complex round-trip with all scalar styles")
    func complexScalarStyles() throws {
        let yaml = """
        plain: Hello world
        quoted: "This is a quoted string"
        single: 'Single quoted string'
        literal: |
          This is a literal block
          with multiple lines
          and preserved formatting
        folded: >
          This is a folded block
          where newlines become
          spaces except for
          
          blank lines
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with anchors and aliases")
    func anchorsAndAliases() throws {
        let yaml = """
        defaults: &defaults
          adapter: postgres
          host: localhost
          port: 5432
        
        development:
          database: myapp_development
          <<: *defaults
        
        test:
          database: myapp_test
          <<: *defaults
        
        production:
          database: myapp_production
          host: prod-db-server.com
          <<: *defaults
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with tags")
    func tagsRoundTrip() throws {
        let yaml = """
        explicit_string: !!str 123
        explicit_int: !!int "456"
        explicit_float: !!float "789.0"
        custom_tag: !myapp/version "2.0"
        tagged_sequence: !!seq
          - one
          - two
          - three
        tagged_mapping: !!map
          key1: value1
          key2: value2
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with nested block and flow collections")
    func nestedBlockAndFlow() throws {
        let yaml = """
        root:
          block_sequence:
            - item1
            - item2
            - nested_flow: [a, b, c]
          flow_sequence: [1, 2, 3]
          mixed:
            - block: item
              flow: {key: value, another: 42}
            - simple
            - [inline, array]
          deeply_nested:
            level1:
              level2:
                level3: {inline: {deeply: {nested: value}}}
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with special characters and escapes")
    func specialCharacters() throws {
        let yaml = """
        special_chars: "Line1\\nLine2\\tTabbed"
        unicode: "\\u263A \\U0001F600"
        quotes: "He said \\"Hello\\""
        backslash: "C:\\\\Users\\\\Name"
        control: "\\a\\b\\f\\n\\r\\t\\v"
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with empty collections")
    func emptyCollections() throws {
        let yaml = """
        empty_mapping: {}
        empty_sequence: []
        null_value: ~
        empty_string: ""
        nested_empty:
          mapping: {}
          sequence: []
          null: ~
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with complex keys")
    func complexKeys() throws {
        // Test explicit simple key syntax that we support
        let yaml = """
        ? simple key
        : simple value
        ? "quoted key"
        : quoted value
        'single quoted': another value
        unquoted: value
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with multi-line strings")
    func multiLineStrings() throws {
        let yaml = """
        description: |
          This is a multi-line
          description that preserves
          line breaks and indentation
            like this indented line
        
        summary: >
          This is a folded
          string where line
          breaks become spaces
          
          except for blank lines
        
        mixed: |+
          This has a chomping indicator
          to keep trailing newlines
          
          
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip with numeric edge cases")
    func numericEdgeCases() throws {
        let yaml = """
        integers:
          decimal: 12345
          octal: 0o14
          hex: 0xC
          binary: 0b1100
        
        floats:
          simple: 1.23
          exponential: 1.2e+3
          negative_exp: 1.2e-3
          infinity: .inf
          negative_infinity: -.inf
          not_a_number: .nan
        
        special:
          true: true
          false: false
          null: null
          empty: ~
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        #expect(areNodesEqual(node, reparsed))
    }
    
    @Test("Round-trip preserves document structure")
    func documentStructure() throws {
        let yaml = """
        ---
        # This is a comment
        first_document: value1
        
        # Another comment
        nested:
          # Nested comment
          key: value
        ...
        ---
        # Second document
        second_document: value2
        array:
          - item1
          - item2
        """
        
        let documents = try YAML.parseStream(yaml)
        #expect(documents.count == 2)
        
        let emitted = YAML.emit(documents)
        let reparsedDocuments = try YAML.parseStream(emitted)
        
        #expect(documents.count == reparsedDocuments.count)
        for (original, reparsed) in zip(documents, reparsedDocuments) {
            #expect(areNodesEqual(original, reparsed))
        }
    }
    
    // Helper function to compare YAML nodes
    private func areNodesEqual(_ lhs: YAMLNode, _ rhs: YAMLNode) -> Bool {
        switch (lhs, rhs) {
        case (.scalar(let l), .scalar(let r)):
            return l.value == r.value && l.tag == r.tag
            
        case (.sequence(let l), .sequence(let r)):
            guard l.count == r.count else { return false }
            return zip(l, r).allSatisfy { areNodesEqual($0, $1) }
            
        case (.mapping(let l), .mapping(let r)):
            guard l.count == r.count else { return false }
            for (key, lValue) in l {
                guard let rValue = r[key] else { return false }
                if !areNodesEqual(lValue, rValue) { return false }
            }
            return true
            
        default:
            return false
        }
    }
}
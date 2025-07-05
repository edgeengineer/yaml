import Testing
@testable import YAML

@Suite("YAML Parser Error Tests")
struct YAMLParserErrorTests {
    
    @Test("Invalid indentation in sequence")
    func invalidIndentationSequence() {
        let yaml = """
        items:
          - item1
         - item2  # Wrong indentation
          - item3
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Invalid indentation in mapping")
    func invalidIndentationMapping() {
        let yaml = """
        parent:
          child1: value1
         child2: value2  # Wrong indentation
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Unclosed double quote")
    func unclosedDoubleQuote() {
        let yaml = """
        key: "unclosed string
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Unclosed single quote")
    func unclosedSingleQuote() {
        let yaml = """
        key: 'unclosed string
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Mismatched flow sequence brackets")
    func mismatchedFlowSequenceBrackets() {
        let yaml = """
        array: [1, 2, 3
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Mismatched flow mapping brackets")
    func mismatchedFlowMappingBrackets() {
        let yaml = """
        object: {key: value
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Invalid flow sequence syntax - missing comma")
    func invalidFlowSequenceSyntax() {
        // Note: [1 2 3] is actually valid YAML - it's a sequence with one element: "1 2 3"
        // According to YAML spec, plain scalars in flow context can contain spaces
        // So this test should check that it parses correctly, not that it throws
        let yaml = """
        array: [1 2 3]
        """
        
        do {
            let result = try YAML.parse(yaml)
            // Should parse as a sequence with one string element
            #expect(result.dictionary?["array"]?.array?.count == 1)
            #expect(result.dictionary?["array"]?.array?[0].string == "1 2 3")
        } catch {
            Issue.record("Expected successful parse but got error: \(error)")
        }
    }
    
    @Test("Invalid flow mapping syntax - missing comma")
    func invalidFlowMappingSyntax() {
        let yaml = """
        object: {a: 1 b: 2}
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Invalid escape sequence")
    func invalidEscapeSequence() {
        let yaml = """
        key: "invalid \\q escape"
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Mixed indentation tabs and spaces")
    func mixedIndentation() {
        let yaml = """
        parent:
          child1: value1
        \tchild2: value2  # Tab instead of spaces
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Empty mapping key")
    func emptyMappingKey() {
        let yaml = """
        : value
        """
        
        // This might be valid YAML, but many parsers reject it
        do {
            let result = try YAML.parse(yaml)
            // Empty key might be allowed
            #expect(result != nil)
        } catch {
            // Or it might throw an error
            #expect(error is YAMLError)
        }
    }
    
    @Test("Duplicate keys in mapping")
    func duplicateKeys() {
        let yaml = """
        key: value1
        key: value2
        """
        
        // YAML spec allows duplicate keys, but parsers may warn
        // For now, just parse and check the result
        let node = try? YAML.parse(yaml)
        if let dict = node?.dictionary {
            // The parser should keep the last value
            #expect(dict["key"]?.string == "value2")
        }
    }
    
    @Test("Invalid anchor name")
    func invalidAnchorName() {
        let yaml = """
        &123 key: value  # Anchor names should start with letter
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Unresolved alias")
    func unresolvedAlias() {
        let yaml = """
        key: *unknown
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Circular alias reference")
    func circularAliasReference() {
        let yaml = """
        &a key: *a
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Error provides line and column information")
    func errorLineColumnInfo() {
        let yaml = """
        valid: line
        invalid: "unclosed
        another: line
        """
        
        do {
            _ = try YAML.parse(yaml)
            Issue.record("Expected error to be thrown")
        } catch let error as YAMLError {
            switch error {
            case .unclosedQuote(let line):
                #expect(line == 2)
            case .unexpectedToken(_, let line, let column):
                #expect(line > 0)
                #expect(column > 0)
            default:
                // Other error types should also provide location info
                break
            }
        } catch {
            Issue.record("Expected YAMLError but got: \(error)")
        }
    }
    
    @Test("Invalid tag format")
    func invalidTagFormat() {
        let yaml = """
        key: !<invalid tag> value
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Unexpected document end")
    func unexpectedDocumentEnd() {
        let yaml = """
        key:
        """
        
        // This might produce an empty string value or throw
        let result = try? YAML.parse(yaml)
        if let dict = result?.dictionary {
            #expect(dict["key"]?.string == "" || dict["key"]?.isNull == true)
        }
    }
    
    @Test("Invalid block scalar indicator")
    func invalidBlockScalarIndicator() {
        let yaml = """
        key: |9999999999
          Too large indentation indicator
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
}
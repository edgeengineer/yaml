import Testing
@testable import YAML

@Suite("YAML Complex Keys Tests")
struct YAMLComplexKeysTests {
    
    @Test("Document current complex key limitations")
    func documentCurrentLimitations() throws {
        // Currently, YAMLNode only supports String keys in mappings
        // This test documents what we can and cannot do
        
        let yaml1 = """
        ? key
        : value
        """
        
        // This should parse as a mapping with explicit key
        let node1 = try YAML.parse(yaml1)
        #expect(node1["key"]?.string == "value")
        
        // Complex keys are not supported - they would need API changes
        let yaml2 = """
        ? [a, b]
        : value1
        ? {x: 1}
        : value2
        """
        
        // Complex keys are not supported yet
        // The parser will interpret these differently
        do {
            let result = try YAML.parse(yaml2)
            // It likely parses but not as expected
            // Complex keys are parsed as regular mappings with string keys
            #expect(result.dictionary != nil)
        } catch {
            // Or it might throw an error
            throw error
        }
    }
    
    @Test("Explicit simple key syntax")
    func explicitSimpleKey() throws {
        let yaml = """
        ? simple key
        : simple value
        ? "quoted key"
        : quoted value
        """
        
        let node = try YAML.parse(yaml)
        #expect(node["simple key"]?.string == "simple value")
        #expect(node["quoted key"]?.string == "quoted value")
    }
    
    @Test("Complex key workaround using string representation")
    func complexKeyWorkaround() throws {
        // A potential workaround is to convert complex keys to strings
        // This preserves YAML validity while working within current constraints
        
        let yaml = """
        # Using anchors to simulate complex keys
        _keys:
          - &key1 [a, b]
          - &key2 {x: 1, y: 2}
        
        # Reference them as values
        data:
          "[a, b]": value1
          "{x: 1, y: 2}": value2
        """
        
        let node = try YAML.parse(yaml)
        
        // Access using string representation
        #expect(node["data"]?["[a, b]"]?.string == "value1")
        #expect(node["data"]?["{x: 1, y: 2}"]?.string == "value2")
    }
}
import Testing
@testable import YAML

@Suite("YAML Parser Sequence Tests")
struct YAMLParserSequenceTests {
    @Test("Parse two inline mappings in sequence")
    func parseTwoInlineMappings() throws {
        let yaml = """
        - name: Alice
          age: 25
        - name: Bob
          age: 30
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .sequence(let items) = node else {
            Issue.record("Expected sequence")
            return
        }
        
        #expect(items.count == 2)
        
        guard case .mapping(let alice) = items[0] else {
            Issue.record("Expected first item to be mapping")
            return
        }
        
        #expect(alice["name"]?.string == "Alice")
        #expect(alice["age"]?.int == 25)
        
        guard case .mapping(let bob) = items[1] else {
            Issue.record("Expected second item to be mapping")
            return
        }
        
        #expect(bob["name"]?.string == "Bob")
        #expect(bob["age"]?.int == 30)
    }
}
import Testing
@testable import YAML

@Suite("YAML Flow Style Tests")
struct YAMLFlowTests {
    @Test("Parse simple flow sequence")
    func parseSimpleFlowSequence() throws {
        let yaml = "[1, 2, 3]"
        let node = try YAML.parse(yaml)
        
        guard case .sequence(let items) = node else {
            Issue.record("Expected sequence")
            return
        }
        
        #expect(items.count == 3)
        #expect(items[0].int == 1)
        #expect(items[1].int == 2)
        #expect(items[2].int == 3)
    }
    
    @Test("Parse flow sequence with strings")
    func parseFlowSequenceWithStrings() throws {
        let yaml = "[apple, \"banana\", 'cherry']"
        let node = try YAML.parse(yaml)
        
        guard case .sequence(let items) = node else {
            Issue.record("Expected sequence")
            return
        }
        
        #expect(items.count == 3)
        #expect(items[0].string == "apple")
        #expect(items[1].string == "banana")
        #expect(items[2].string == "cherry")
    }
    
    @Test("Parse nested flow sequences")
    func parseNestedFlowSequences() throws {
        let yaml = "[[1, 2], [3, 4, 5], []]"
        let node = try YAML.parse(yaml)
        
        guard case .sequence(let outer) = node else {
            Issue.record("Expected outer sequence")
            return
        }
        
        #expect(outer.count == 3)
        
        guard case .sequence(let first) = outer[0] else {
            Issue.record("Expected first nested sequence")
            return
        }
        #expect(first.count == 2)
        #expect(first[0].int == 1)
        #expect(first[1].int == 2)
        
        guard case .sequence(let second) = outer[1] else {
            Issue.record("Expected second nested sequence")
            return
        }
        #expect(second.count == 3)
        
        guard case .sequence(let third) = outer[2] else {
            Issue.record("Expected third nested sequence")
            return
        }
        #expect(third.count == 0)
    }
    
    @Test("Parse simple flow mapping")
    func parseSimpleFlowMapping() throws {
        let yaml = "{name: John, age: 30}"
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            Issue.record("Expected mapping")
            return
        }
        
        #expect(dict.count == 2)
        #expect(dict["name"]?.string == "John")
        #expect(dict["age"]?.int == 30)
    }
    
    @Test("Parse flow mapping with quoted keys")
    func parseFlowMappingWithQuotedKeys() throws {
        let yaml = "{\"first name\": Alice, 'last name': Smith, age: 25}"
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            Issue.record("Expected mapping")
            return
        }
        
        #expect(dict.count == 3)
        #expect(dict["first name"]?.string == "Alice")
        #expect(dict["last name"]?.string == "Smith")
        #expect(dict["age"]?.int == 25)
    }
    
    @Test("Parse nested flow mappings")
    func parseNestedFlowMappings() throws {
        let yaml = "{person: {name: Bob, age: 40}, city: NYC}"
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let outer) = node else {
            Issue.record("Expected outer mapping")
            return
        }
        
        #expect(outer.count == 2)
        #expect(outer["city"]?.string == "NYC")
        
        guard case .mapping(let person) = outer["person"] else {
            Issue.record("Expected person mapping")
            return
        }
        
        #expect(person["name"]?.string == "Bob")
        #expect(person["age"]?.int == 40)
    }
    
    @Test("Parse mixed flow styles")
    func parseMixedFlowStyles() throws {
        let yaml = "{items: [1, 2, 3], metadata: {count: 3, type: numbers}}"
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            Issue.record("Expected mapping")
            return
        }
        
        guard case .sequence(let items) = dict["items"] else {
            Issue.record("Expected items sequence")
            return
        }
        #expect(items.count == 3)
        
        guard case .mapping(let metadata) = dict["metadata"] else {
            Issue.record("Expected metadata mapping")
            return
        }
        #expect(metadata["count"]?.int == 3)
        #expect(metadata["type"]?.string == "numbers")
    }
    
    @Test("Parse flow with multiline values")
    func parseFlowWithMultiline() throws {
        let yaml = """
        [first item,
         second item,
         third item]
        """
        let node = try YAML.parse(yaml)
        
        guard case .sequence(let items) = node else {
            Issue.record("Expected sequence")
            return
        }
        
        #expect(items.count == 3)
        #expect(items[0].string == "first item")
        #expect(items[1].string == "second item")
        #expect(items[2].string == "third item")
    }
    
    @Test("Parse empty flow collections")
    func parseEmptyFlowCollections() throws {
        let emptySeq = "[]"
        let node1 = try YAML.parse(emptySeq)
        guard case .sequence(let seq) = node1 else {
            Issue.record("Expected empty sequence")
            return
        }
        #expect(seq.isEmpty)
        
        let emptyMap = "{}"
        let node2 = try YAML.parse(emptyMap)
        guard case .mapping(let map) = node2 else {
            Issue.record("Expected empty mapping")
            return
        }
        #expect(map.isEmpty)
    }
    
    @Test("Parse flow with trailing commas")
    func parseFlowWithTrailingCommas() throws {
        let yaml1 = "[1, 2, 3,]"
        let node1 = try YAML.parse(yaml1)
        guard case .sequence(let seq) = node1 else {
            Issue.record("Expected sequence")
            return
        }
        #expect(seq.count == 3)
        
        let yaml2 = "{a: 1, b: 2,}"
        let node2 = try YAML.parse(yaml2)
        guard case .mapping(let map) = node2 else {
            Issue.record("Expected mapping")
            return
        }
        #expect(map.count == 2)
    }
}
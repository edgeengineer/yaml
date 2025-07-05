import Testing
@testable import YAML

@Suite("YAML Parser Tests")
struct YAMLParserTests {
    @Test("Parse simple scalar")
    func parseSimpleScalar() throws {
        let yaml = "Hello, World!"
        let node = try YAML.parse(yaml)
        
        #expect(node.string == "Hello, World!")
    }
    
    @Test("Parse integer scalar")
    func parseIntegerScalar() throws {
        let yaml = "42"
        let node = try YAML.parse(yaml)
        
        #expect(node.int == 42)
    }
    
    @Test("Parse float scalar")
    func parseFloatScalar() throws {
        let yaml = "3.14"
        let node = try YAML.parse(yaml)
        
        #expect(node.double == 3.14)
    }
    
    @Test("Parse boolean scalars")
    func parseBooleanScalars() throws {
        let trueValues = ["true", "True", "yes", "Yes", "on", "On"]
        let falseValues = ["false", "False", "no", "No", "off", "Off"]
        
        for value in trueValues {
            let node = try YAML.parse(value)
            #expect(node.bool == true)
        }
        
        for value in falseValues {
            let node = try YAML.parse(value)
            #expect(node.bool == false)
        }
    }
    
    @Test("Parse null values")
    func parseNullValues() throws {
        let nullValues = ["null", "Null", "~", ""]
        
        for value in nullValues {
            let node = try YAML.parse(value)
            #expect(node.isNull)
        }
    }
    
    @Test("Parse simple sequence")
    func parseSimpleSequence() throws {
        let yaml = """
        - apple
        - banana
        - cherry
        """
        
        let node = try YAML.parse(yaml)
        guard let array = node.array else {
            Issue.record("Expected sequence")
            return
        }
        
        #expect(array.count == 3)
        #expect(array[0].string == "apple")
        #expect(array[1].string == "banana")
        #expect(array[2].string == "cherry")
    }
    
    @Test("Parse simple mapping")
    func parseSimpleMapping() throws {
        let yaml = """
        name: John Doe
        age: 30
        city: New York
        """
        
        let node = try YAML.parse(yaml)
        guard let dict = node.dictionary else {
            Issue.record("Expected mapping")
            return
        }
        
        #expect(dict["name"]?.string == "John Doe")
        #expect(dict["age"]?.int == 30)
        #expect(dict["city"]?.string == "New York")
    }
    
    @Test("Parse nested structures")
    func parseNestedStructures() throws {
        let yaml = """
        person:
          name: Jane Smith
          age: 25
          hobbies:
            - reading
            - swimming
            - coding
          address:
            street: 123 Main St
            city: Boston
            zip: 02101
        """
        
        let node = try YAML.parse(yaml)
        let person = node["person"]
        
        #expect(person?["name"]?.string == "Jane Smith")
        #expect(person?["age"]?.int == 25)
        
        let hobbies = person?["hobbies"]?.array
        #expect(hobbies?.count == 3)
        #expect(hobbies?[0].string == "reading")
        
        let address = person?["address"]
        #expect(address?["street"]?.string == "123 Main St")
        #expect(address?["city"]?.string == "Boston")
        #expect(address?["zip"]?.int == 2101)
    }
    
    @Test("Parse quoted strings")
    func parseQuotedStrings() throws {
        let yaml = """
        single: 'single quoted string'
        double: "double quoted string"
        escaped: "line one\\nline two\\ttabbed"
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["single"]?.string == "single quoted string")
        #expect(node["double"]?.string == "double quoted string")
        #expect(node["escaped"]?.string == "line one\nline two\ttabbed")
    }
    
    @Test("Parse literal scalar")
    func parseLiteralScalar() throws {
        let yaml = """
        description: |
          This is a literal scalar.
          It preserves newlines.
          
          Even blank lines.
        """
        
        let node = try YAML.parse(yaml)
        let expected = """
        This is a literal scalar.
        It preserves newlines.
        
        Even blank lines.
        """
        
        #expect(node["description"]?.string == expected)
    }
    
    @Test("Parse folded scalar")
    func parseFoldedScalar() throws {
        let yaml = """
        description: >
          This is a folded scalar.
          It folds newlines into spaces.
          
          But preserves blank lines.
        """
        
        let node = try YAML.parse(yaml)
        let expected = "This is a folded scalar. It folds newlines into spaces.\nBut preserves blank lines."
        
        #expect(node["description"]?.string == expected)
    }
    
    @Test("Parse with comments")
    func parseWithComments() throws {
        let yaml = """
        # This is a comment
        name: Test # This is also a comment
        # Another comment
        value: 123
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["name"]?.string == "Test")
        #expect(node["value"]?.int == 123)
    }
    
    @Test("Parse empty sequence items")
    func parseEmptySequenceItems() throws {
        let yaml = """
        - first
        -
        - third
        """
        
        let node = try YAML.parse(yaml)
        guard let array = node.array else {
            Issue.record("Expected sequence")
            return
        }
        
        #expect(array.count == 3)
        #expect(array[0].string == "first")
        #expect(array[1].isNull)
        #expect(array[2].string == "third")
    }
    
    @Test("Parse complex mapping keys")
    func parseComplexMappingKeys() throws {
        let yaml = """
        "complex key": value1
        'another key': value2
        key with spaces: value3
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["complex key"]?.string == "value1")
        #expect(node["another key"]?.string == "value2")
        #expect(node["key with spaces"]?.string == "value3")
    }
}
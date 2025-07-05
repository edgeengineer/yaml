import Testing
@testable import YAML

@Suite("YAML Emitter Tests")
struct YAMLEmitterTests {
    @Test("Emit simple scalar")
    func emitSimpleScalar() {
        let node = YAMLNode.scalar(.init(value: "Hello, World!"))
        let yaml = YAML.emit(node)
        
        #expect(yaml == "Hello, World!")
    }
    
    @Test("Emit integer scalar")
    func emitIntegerScalar() {
        let node = YAMLNode.scalar(.init(value: "42", tag: .int))
        let yaml = YAML.emit(node)
        
        #expect(yaml == "42")
    }
    
    @Test("Emit boolean scalars")
    func emitBooleanScalars() {
        let trueNode = YAMLNode.scalar(.init(value: "true", tag: .bool))
        let falseNode = YAMLNode.scalar(.init(value: "false", tag: .bool))
        
        #expect(YAML.emit(trueNode) == "true")
        #expect(YAML.emit(falseNode) == "false")
    }
    
    @Test("Emit null scalar")
    func emitNullScalar() {
        let node = YAMLNode.scalar(.init(value: "", tag: .null))
        let yaml = YAML.emit(node)
        
        #expect(yaml == "")
    }
    
    @Test("Emit simple sequence")
    func emitSimpleSequence() {
        let node = YAMLNode.sequence([
            .scalar(.init(value: "apple")),
            .scalar(.init(value: "banana")),
            .scalar(.init(value: "cherry"))
        ])
        
        let yaml = YAML.emit(node)
        let expected = """
        - apple
        - banana
        - cherry
        
        """
        
        #expect(yaml == expected)
    }
    
    @Test("Emit simple mapping")
    func emitSimpleMapping() {
        let node = YAMLNode.mapping([
            "name": .scalar(.init(value: "John Doe")),
            "age": .scalar(.init(value: "30", tag: .int)),
            "city": .scalar(.init(value: "New York"))
        ])
        
        let yaml = YAML.emit(node)
        
        #expect(yaml.contains("name: John Doe"))
        #expect(yaml.contains("age: 30"))
        #expect(yaml.contains("city: New York"))
    }
    
    @Test("Emit nested structures")
    func emitNestedStructures() {
        let node = YAMLNode.mapping([
            "person": .mapping([
                "name": .scalar(.init(value: "Jane Smith")),
                "age": .scalar(.init(value: "25", tag: .int)),
                "hobbies": .sequence([
                    .scalar(.init(value: "reading")),
                    .scalar(.init(value: "swimming")),
                    .scalar(.init(value: "coding"))
                ])
            ])
        ])
        
        let yaml = YAML.emit(node)
        
        #expect(yaml.contains("person:"))
        #expect(yaml.contains("name: Jane Smith"))
        #expect(yaml.contains("age: 25"))
        #expect(yaml.contains("hobbies:"))
        #expect(yaml.contains("- reading"))
        #expect(yaml.contains("- swimming"))
        #expect(yaml.contains("- coding"))
    }
    
    @Test("Emit quoted strings")
    func emitQuotedStrings() {
        let node = YAMLNode.mapping([
            "simple": .scalar(.init(value: "simple string")),
            "colon": .scalar(.init(value: "string: with colon")),
            "special": .scalar(.init(value: "true")),
            "number": .scalar(.init(value: "123"))
        ])
        
        let yaml = YAML.emit(node)
        
        #expect(yaml.contains("simple: simple string"))
        #expect(yaml.contains("\"string: with colon\""))
        #expect(yaml.contains("\"true\""))
        #expect(yaml.contains("\"123\""))
    }
    
    @Test("Emit with flow style")
    func emitWithFlowStyle() {
        let options = YAMLEmitter.Options(useFlowStyle: true)
        
        let sequence = YAMLNode.sequence([
            .scalar(.init(value: "a")),
            .scalar(.init(value: "b")),
            .scalar(.init(value: "c"))
        ])
        
        let mapping = YAMLNode.mapping([
            "x": .scalar(.init(value: "1")),
            "y": .scalar(.init(value: "2"))
        ])
        
        #expect(YAML.emit(sequence, options: options) == "[a, b, c]")
        #expect(YAML.emit(mapping, options: options).contains("{") && YAML.emit(mapping, options: options).contains("}"))
    }
    
    @Test("Emit with sorted keys")
    func emitWithSortedKeys() {
        let options = YAMLEmitter.Options(sortKeys: true)
        
        let node = YAMLNode.mapping([
            "zebra": .scalar(.init(value: "1", tag: .int)),
            "apple": .scalar(.init(value: "2", tag: .int)),
            "mango": .scalar(.init(value: "3", tag: .int))
        ])
        
        let yaml = YAML.emit(node, options: options)
        let lines = yaml.split(separator: "\n").map(String.init)
        
        #expect(lines[0] == "apple: 2")
        #expect(lines[1] == "mango: 3")
        #expect(lines[2] == "zebra: 1")
    }
    
    @Test("Round trip simple data")
    func roundTripSimpleData() throws {
        let original = """
        name: Test User
        age: 42
        active: true
        tags:
          - swift
          - yaml
          - testing
        """
        
        let parsed = try YAML.parse(original)
        let emitted = YAML.emit(parsed)
        let reparsed = try YAML.parse(emitted)
        
        #expect(parsed == reparsed)
    }
}
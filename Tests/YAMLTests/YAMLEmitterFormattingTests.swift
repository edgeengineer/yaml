import Testing
@testable import YAML

@Suite("YAML Emitter Formatting Tests")
struct YAMLEmitterFormattingTests {
    
    @Test("Test indentation width option")
    func testIndentationWidth() throws {
        let node = YAMLNode.mapping([
            "parent": .mapping([
                "child": .scalar(.init(value: "value")),
                "nested": .mapping([
                    "deep": .scalar(.init(value: "nested value"))
                ])
            ]),
            "list": .sequence([
                .scalar(.init(value: "item1")),
                .scalar(.init(value: "item2"))
            ])
        ])
        
        // Test with 2 spaces (default)
        var options2 = YAMLEmitter.Options()
        options2.indentSize = 2
        let emitted2 = YAML.emit(node, options: options2)
        #expect(emitted2.contains("  child:"))
        #expect(emitted2.contains("    deep:"))
        
        // Test with 4 spaces
        var options4 = YAMLEmitter.Options()
        options4.indentSize = 4
        let emitted4 = YAML.emit(node, options: options4)
        #expect(emitted4.contains("    child:"))
        #expect(emitted4.contains("        deep:"))
    }
    
    @Test("Test line width for folded scalars")
    func testLineWidth() throws {
        let longText = "This is a very long line of text that should be wrapped when using folded scalar style because it exceeds the configured line width limit"
        
        let node = YAMLNode.mapping([
            "folded": .scalar(.init(value: longText, style: .folded))
        ])
        
        // Test with narrow width
        var options20 = YAMLEmitter.Options()
        options20.lineWidth = 20
        let emitted20 = YAML.emit(node, options: options20)
        
        // Count lines in the folded scalar (excluding the > line)
        let lines20 = emitted20.split(separator: "\n").filter { $0.trimmingCharacters(in: .whitespaces) != ">" }
        #expect(lines20.count > 3) // Should wrap into multiple lines
        
        // Test with wide width
        var options100 = YAMLEmitter.Options()
        options100.lineWidth = 100
        let emitted100 = YAML.emit(node, options: options100)
        
        let lines100 = emitted100.split(separator: "\n").filter { $0.trimmingCharacters(in: .whitespaces) != ">" }
        #expect(lines100.count < lines20.count) // Should have fewer lines
    }
    
    @Test("Test canonical output format")
    func testCanonicalOutput() throws {
        // Create a complex node with various types
        let node = YAMLNode.mapping([
            "string": .scalar(.init(value: "hello", tag: .str)),
            "int": .scalar(.init(value: "42", tag: .int)),
            "float": .scalar(.init(value: "3.14", tag: .float)),
            "bool": .scalar(.init(value: "true", tag: .bool)),
            "null": .scalar(.init(value: "", tag: .null)),
            "sequence": .sequence([
                .scalar(.init(value: "a")),
                .scalar(.init(value: "b"))
            ])
        ])
        
        // Test canonical output
        var canonicalOptions = YAMLEmitter.Options()
        canonicalOptions.canonical = true
        
        let canonical = YAML.emit(node, options: canonicalOptions)
        
        // Canonical format should:
        // 1. Always use explicit tags
        #expect(canonical.contains("!!str"))
        #expect(canonical.contains("!!int"))
        #expect(canonical.contains("!!float"))
        #expect(canonical.contains("!!bool"))
        #expect(canonical.contains("!!null"))
        
        // 2. Use flow style
        #expect(canonical.contains("[") || canonical.contains("]"))
        
        // 3. Quote all strings
        #expect(canonical.contains("\"hello\""))
    }
    
    @Test("Combined formatting options")
    func testCombinedOptions() throws {
        // Test with simple values that can use flow style
        let simpleNode = YAMLNode.mapping([
            "name": .scalar(.init(value: "test")),
            "count": .scalar(.init(value: "42")),
            "active": .scalar(.init(value: "true"))
        ])
        
        var options = YAMLEmitter.Options()
        options.indentSize = 3
        options.sortKeys = true
        options.useFlowStyle = true
        
        let emitted = YAML.emit(simpleNode, options: options)
        
        // Should use flow style for simple mapping
        #expect(emitted.contains("{") && emitted.contains("}"))
        
        // Test with nested structure (won't use flow style due to complexity)
        let complexNode = YAMLNode.mapping([
            "config": .mapping([
                "name": .scalar(.init(value: "test")),
                "values": .sequence([
                    .scalar(.init(value: "one")),
                    .scalar(.init(value: "two"))
                ])
            ])
        ])
        
        let complexEmitted = YAML.emit(complexNode, options: options)
        
        // Complex nested structures use block style even with useFlowStyle
        #expect(complexEmitted.contains("config:"))
    }
}
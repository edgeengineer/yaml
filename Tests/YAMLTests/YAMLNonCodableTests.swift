import Testing
@testable import YAML

@Suite("YAML Non-Codable Tests")
struct YAMLNonCodableTests {
    
    @Test("Build simple YAML document")
    func buildSimpleDocument() {
        let node = YAMLNode.dictionary([
            "name": .string("Test Device"),
            "version": .int(1),
            "active": .bool(true),
            "value": .double(3.14)
        ])
        
        let yaml = YAMLBuilder.build(from: node)
        
        #expect(yaml.contains("name: Test Device"))
        #expect(yaml.contains("version: 1"))
        #expect(yaml.contains("active: true"))
        #expect(yaml.contains("value: 3.14"))
    }
    
    @Test("Build nested structures")
    func buildNestedStructures() {
        let node = YAMLNode.dictionary([
            "device": .string("sensor-001"),
            "readings": .array([
                .dictionary([
                    "timestamp": .int(1000),
                    "value": .double(23.5)
                ]),
                .dictionary([
                    "timestamp": .int(2000),
                    "value": .double(24.1)
                ])
            ])
        ])
        
        let yaml = YAMLBuilder.build(from: node)
        
        #expect(yaml.contains("device: sensor-001"))
        #expect(yaml.contains("readings:"))
        #expect(yaml.contains("timestamp: 1000"))
        #expect(yaml.contains("value: 23.5"))
    }
    
    @Test("Access values using path notation")
    func accessUsingPath() {
        let node = YAMLNode.dictionary([
            "user": .dictionary([
                "name": .string("Alice"),
                "settings": .dictionary([
                    "theme": .string("dark"),
                    "notifications": .bool(true)
                ])
            ]),
            "scores": .array([.int(100), .int(95), .int(87)])
        ])
        
        #expect(node.value(at: "user.name")?.string == "Alice")
        #expect(node.value(at: "user.settings.theme")?.string == "dark")
        #expect(node.value(at: "user.settings.notifications")?.bool == true)
        #expect(node.value(at: "scores.0")?.int == 100)
        #expect(node.value(at: "scores.1")?.int == 95)
        #expect(node.value(at: "scores.2")?.int == 87)
        #expect(node.value(at: "nonexistent") == nil)
        #expect(node.value(at: "user.nonexistent") == nil)
    }
    
    @Test("Use document builder")
    func useDocumentBuilder() {
        let doc = yaml {
            YAMLNode.dictionary([
                "version": .string("1.0"),
                "config": .dictionary([
                    "debug": .bool(false),
                    "timeout": .int(30)
                ])
            ])
        }
        
        let yaml = YAMLBuilder.build(from: doc)
        
        #expect(yaml.contains("version: 1.0"))
        #expect(yaml.contains("debug: false"))
        #expect(yaml.contains("timeout: 30"))
    }
    
    @Test("Build empty collections")
    func buildEmptyCollections() {
        let node = YAMLNode.dictionary([
            "empty_array": .array([]),
            "empty_dict": .dictionary([:])
        ])
        
        let yaml = YAMLBuilder.build(from: node)
        
        // Check that empty array is formatted correctly
        #expect(yaml.contains("empty_array"))
        #expect(yaml.contains("[]"))
        
        // Check that empty dict is formatted correctly  
        #expect(yaml.contains("empty_dict"))
        #expect(yaml.contains("{}"))
    }
    
    @Test("Build with different scalar styles")
    func buildWithScalarStyles() {
        let node = YAMLNode.dictionary([
            "plain": .scalar(.init(value: "plain text", style: .plain)),
            "single": .scalar(.init(value: "single quoted", style: .singleQuoted)),
            "double": .scalar(.init(value: "double quoted", style: .doubleQuoted)),
            "literal": .scalar(.init(value: "literal\ntext", style: .literal)),
            "folded": .scalar(.init(value: "folded\ntext", style: .folded))
        ])
        
        let yaml = YAMLBuilder.build(from: node)
        
        #expect(yaml.contains("plain: plain text"))
        #expect(yaml.contains("single: 'single quoted'"))
        #expect(yaml.contains("double: \"double quoted\""))
        #expect(yaml.contains("literal: |"))
        #expect(yaml.contains("folded: >"))
    }
    
    @Test("Handle null values")
    func handleNullValues() {
        let node = YAMLNode.dictionary([
            "value": .null,
            "array": .array([.string("text"), .null, .int(42)])
        ])
        
        let yaml = YAMLBuilder.build(from: node)
        
        #expect(yaml.contains("value: null"))
        #expect(yaml.contains("- text"))
        #expect(yaml.contains("- null"))
        #expect(yaml.contains("- 42"))
    }
    
    @Test("Path access with arrays")
    func pathAccessWithArrays() {
        let node = YAMLNode.dictionary([
            "items": .array([
                .dictionary([
                    "id": .int(1),
                    "data": .dictionary([
                        "name": .string("First")
                    ])
                ]),
                .dictionary([
                    "id": .int(2),
                    "data": .dictionary([
                        "name": .string("Second")
                    ])
                ])
            ])
        ])
        
        #expect(node.value(at: "items.0.id")?.int == 1)
        #expect(node.value(at: "items.0.data.name")?.string == "First")
        #expect(node.value(at: "items.1.id")?.int == 2)
        #expect(node.value(at: "items.1.data.name")?.string == "Second")
    }
}
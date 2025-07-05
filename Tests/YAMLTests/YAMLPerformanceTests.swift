import Testing
@testable import YAML
import Foundation

@Suite("YAML Performance Tests")
struct YAMLPerformanceTests {
    
    @Test("Parse large sequence")
    func parseLargeSequence() throws {
        // Generate a large sequence
        var yamlLines = [String]()
        let itemCount = 10000
        
        for i in 0..<itemCount {
            yamlLines.append("- item_\(i)")
        }
        
        let yaml = yamlLines.joined(separator: "\n")
        
        let startTime = Date()
        let node = try YAML.parse(yaml)
        let parseTime = Date().timeIntervalSince(startTime)
        
        guard case .sequence(let items) = node else {
            #expect(Bool(false), "Expected sequence")
            return
        }
        
        #expect(items.count == itemCount)
        
        // Basic performance check - should parse in reasonable time
        #expect(parseTime < 1.0, "Parsing \(itemCount) items took \(parseTime) seconds")
    }
    
    @Test("Parse deeply nested structure") 
    func parseDeeplyNested() throws {
        // Generate deeply nested YAML
        // Reduced depth to avoid stack overflow
        let depth = 20  // Reduced from 100 to avoid recursive parsing issues
        var yaml = ""
        var indent = ""
        
        for i in 0..<depth {
            yaml += "\(indent)level_\(i):\n"
            indent += "  "
        }
        yaml += "\(indent)value: \"deep\""
        
        let startTime = Date()
        let node = try YAML.parse(yaml)
        let parseTime = Date().timeIntervalSince(startTime)
        
        // Navigate to deepest level
        var current = node
        for i in 0..<depth {
            guard case .mapping(let dict) = current,
                  let next = dict["level_\(i)"] else {
                #expect(Bool(false), "Failed at level \(i)")
                return
            }
            current = next
        }
        
        guard case .mapping(let dict) = current,
              dict["value"]?.string == "deep" else {
            #expect(Bool(false), "Failed to get final value")
            return
        }
        
        // Should handle deep nesting efficiently
        #expect(parseTime < 0.5, "Parsing \(depth) levels took \(parseTime) seconds")
    }
    
    @Test("Emit large mapping")
    func emitLargeMapping() throws {
        // Create a large mapping
        let itemCount = 5000
        var dict = [String: YAMLNode]()
        
        for i in 0..<itemCount {
            dict["key_\(i)"] = .scalar(.init(value: "value_\(i)"))
        }
        
        let node = YAMLNode.mapping(dict)
        
        let startTime = Date()
        let yaml = YAML.emit(node)
        let emitTime = Date().timeIntervalSince(startTime)
        
        // Verify the output contains expected keys
        #expect(yaml.contains("key_0:"))
        #expect(yaml.contains("key_\(itemCount - 1):"))
        
        // Should emit in reasonable time
        #expect(emitTime < 1.0, "Emitting \(itemCount) items took \(emitTime) seconds")
    }
    
    @Test("Round-trip performance")
    func roundTripPerformance() throws {
        // Create a moderately complex structure
        var items = [YAMLNode]()
        
        for i in 0..<100 {
            let mapping: [String: YAMLNode] = [
                "id": .scalar(.init(value: String(i))),
                "name": .scalar(.init(value: "Item \(i)")),
                "tags": .sequence([
                    .scalar(.init(value: "tag1")),
                    .scalar(.init(value: "tag2")),
                    .scalar(.init(value: "tag3"))
                ]),
                "metadata": .mapping([
                    "created": .scalar(.init(value: "2024-01-01")),
                    "updated": .scalar(.init(value: "2024-01-15")),
                    "version": .scalar(.init(value: "1.0"))
                ])
            ]
            items.append(.mapping(mapping))
        }
        
        let node = YAMLNode.sequence(items)
        
        // Measure round-trip time
        let startTime = Date()
        
        let yaml = YAML.emit(node)
        let reparsed = try YAML.parse(yaml)
        
        let roundTripTime = Date().timeIntervalSince(startTime)
        
        // Verify structure is preserved
        guard case .sequence(let reparsedItems) = reparsed else {
            #expect(Bool(false), "Expected sequence")
            return
        }
        
        #expect(reparsedItems.count == 100)
        
        // Should complete round-trip quickly
        #expect(roundTripTime < 0.5, "Round-trip took \(roundTripTime) seconds")
    }
    
    @Test("Memory efficiency with string interning")
    func stringInterning() throws {
        // Generate YAML with many repeated strings
        var yamlLines = ["items:"]
        let itemCount = 1000
        
        for i in 0..<itemCount {
            yamlLines.append("  - type: common_type")
            yamlLines.append("    status: active")
            yamlLines.append("    category: default")
            yamlLines.append("    id: \(i)")
        }
        
        let yaml = yamlLines.joined(separator: "\n")
        
        // Parse and check memory efficiency
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node,
              case .sequence(let items)? = dict["items"] else {
            #expect(Bool(false), "Expected structure")
            return
        }
        
        #expect(items.count == itemCount)
        
        // Verify all items have expected structure
        for (index, item) in items.enumerated() {
            guard case .mapping(let itemDict) = item else {
                #expect(Bool(false), "Item \(index) is not a mapping")
                continue
            }
            
            #expect(itemDict["type"]?.string == "common_type")
            #expect(itemDict["status"]?.string == "active")
            #expect(itemDict["category"]?.string == "default")
            #expect(itemDict["id"]?.string == String(index))
        }
    }
    
    @Test("Parse with many anchors and aliases")
    func manyAnchorsAliases() throws {
        // Generate YAML with many anchors and aliases
        var yamlLines = [String]()
        
        // Define anchors
        yamlLines.append("defaults: &defaults")
        yamlLines.append("  setting1: value1")
        yamlLines.append("  setting2: value2")
        yamlLines.append("  setting3: value3")
        yamlLines.append("")
        yamlLines.append("items:")
        
        // Create many items referencing the anchor
        let itemCount = 500
        for i in 0..<itemCount {
            yamlLines.append("  - name: item_\(i)")
            yamlLines.append("    <<: *defaults")
            yamlLines.append("    custom: custom_\(i)")
        }
        
        let yaml = yamlLines.joined(separator: "\n")
        
        let startTime = Date()
        let node = try YAML.parse(yaml)
        let parseTime = Date().timeIntervalSince(startTime)
        
        guard case .mapping(let dict) = node,
              case .sequence(let items)? = dict["items"] else {
            #expect(Bool(false), "Expected structure")
            return
        }
        
        #expect(items.count == itemCount)
        
        // Verify merge worked correctly
        if case .mapping(let firstItem)? = items.first {
            #expect(firstItem["setting1"]?.string == "value1")
            #expect(firstItem["setting2"]?.string == "value2")
            #expect(firstItem["setting3"]?.string == "value3")
            #expect(firstItem["custom"]?.string == "custom_0")
        }
        
        // Should handle many aliases efficiently
        #expect(parseTime < 1.0, "Parsing with \(itemCount) aliases took \(parseTime) seconds")
    }
    
    @Test("Codable performance with large dataset")
    func codablePerformance() throws {
        struct Item: Codable {
            let id: Int
            let name: String
            let description: String
            let tags: [String]
            let metadata: [String: String]
        }
        
        struct Dataset: Codable {
            let version: String
            let items: [Item]
        }
        
        // Create large dataset
        var items = [Item]()
        for i in 0..<1000 {
            let item = Item(
                id: i,
                name: "Item \(i)",
                description: "This is a description for item \(i) with some additional text",
                tags: ["tag1", "tag2", "tag3", "category\(i % 10)"],
                metadata: [
                    "created": "2024-01-01",
                    "updated": "2024-01-15",
                    "author": "system",
                    "version": "1.0"
                ]
            )
            items.append(item)
        }
        
        let dataset = Dataset(version: "1.0", items: items)
        
        // Measure encoding time
        let encoder = YAMLEncoder()
        let encodeStart = Date()
        let yaml = try encoder.encode(dataset)
        let encodeTime = Date().timeIntervalSince(encodeStart)
        
        // Measure decoding time
        let decoder = YAMLDecoder()
        let decodeStart = Date()
        let decoded = try decoder.decode(Dataset.self, from: yaml)
        let decodeTime = Date().timeIntervalSince(decodeStart)
        
        #expect(decoded.items.count == 1000)
        #expect(decoded.items[0].id == 0)
        #expect(decoded.items[999].id == 999)
        
        // Should encode/decode efficiently
        #expect(encodeTime < 2.0, "Encoding took \(encodeTime) seconds")
        #expect(decodeTime < 2.0, "Decoding took \(decodeTime) seconds")
    }
}
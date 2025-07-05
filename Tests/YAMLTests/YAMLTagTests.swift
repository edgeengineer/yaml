import Testing
import Foundation
@testable import YAML

@Suite("YAML Tag Tests")
struct YAMLTagTests {
    
    @Test("Parse standard tags")
    func parseStandardTags() throws {
        let yaml = """
        string: !!str "42"
        integer: !!int "42"
        float: !!float "3.14"
        boolean: !!bool "yes"
        null: !!null ""
        binary: !!binary "R0lGODlhAQABAIAAAP///wAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw=="
        """
        
        let node = try YAML.parse(yaml)
        
        // Values should be interpreted according to their tags
        #expect(node["string"]?.string == "42")
        #expect(node["integer"]?.int == 42)
        #expect(node["float"]?.double == 3.14)
        #expect(node["boolean"]?.bool == true)
        #expect(node["null"]?.isNull == true)
        
        // Binary data should be decoded
        if let binaryStr = node["binary"]?.string {
            #expect(Data(base64Encoded: binaryStr) != nil)
        }
    }
    
    @Test("Parse custom tags")
    func parseCustomTags() throws {
        let yaml = """
        custom: !myapp/user
          name: John Doe
          id: 12345
        
        point: !point [3.5, 4.2]
        
        color: !color "#FF0000"
        """
        
        let node = try YAML.parse(yaml)
        
        // Custom tags should be preserved in the node structure
        // This would require extending YAMLNode to store tag information
        #expect(node["custom"] != nil)
        #expect(node["point"] != nil)
        #expect(node["color"] != nil)
    }
    
    @Test("Tags on sequences and mappings")
    func tagsOnCollections() throws {
        let yaml = """
        sequence: !!seq
          - item1
          - item2
        
        mapping: !!map
          key1: value1
          key2: value2
        
        ordered: !omap
          - first: 1
          - second: 2
          - third: 3
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["sequence"]?.array?.count == 2)
        #expect(node["mapping"]?.dictionary?.count == 2)
        #expect(node["ordered"]?.array?.count == 3)
    }
    
    @Test("Local tags")
    func localTags() throws {
        let yaml = """
        local: !foo "bar"
        another: !bar/baz "value"
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["local"]?.string == "bar")
        #expect(node["another"]?.string == "value")
    }
    
    @Test("Tag shorthand directive")
    func tagShorthandDirective() throws {
        let yaml = """
        %TAG ! tag:example.com,2014:
        ---
        object: !foo
          property: value
        """
        
        // This would expand !foo to tag:example.com,2014:foo
        let node = try YAML.parse(yaml)
        
        #expect(node["object"]?["property"]?.string == "value")
    }
    
    @Test("Codable with custom tags for polymorphism")
    func codableWithCustomTags() throws {
        // Define a protocol and conforming types
        protocol Shape: Codable {
            var type: String { get }
        }
        
        struct Circle: Shape, Codable {
            var type: String { "circle" }
            let radius: Double
        }
        
        struct Rectangle: Shape, Codable {
            var type: String { "rectangle" }
            let width: Double
            let height: Double
        }
        
        let yaml = """
        shapes:
          - !circle
            radius: 5.0
          - !rectangle
            width: 10.0
            height: 20.0
          - !circle
            radius: 3.0
        """
        
        // This would require custom decoding logic based on tags
        // For now, just verify parsing doesn't fail
        let node = try YAML.parse(yaml)
        let shapes = node["shapes"]?.array ?? []
        
        #expect(shapes.count == 3)
        #expect(shapes[0]["radius"]?.double == 5.0)
        #expect(shapes[1]["width"]?.double == 10.0)
        #expect(shapes[1]["height"]?.double == 20.0)
    }
    
    @Test("Invalid tag syntax")
    func invalidTagSyntax() {
        let yaml = """
        invalid: !<tag> value
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Tag with anchor")
    func tagWithAnchor() throws {
        let yaml = """
        original: &anchor !custom {data: value}
        reference: *anchor
        """
        
        let node = try YAML.parse(yaml)
        
        // Both should have the same custom tagged data
        #expect(node["original"]?["data"]?.string == "value")
        #expect(node["reference"]?["data"]?.string == "value")
    }
    
    @Test("Explicit typing with tags")
    func explicitTypingWithTags() throws {
        let yaml = """
        # Force string interpretation
        port: !!str 8080
        
        # Force integer interpretation
        count: !!int "10"
        
        # Force float interpretation
        ratio: !!float "1"
        
        # Force boolean interpretation
        enabled: !!bool "1"
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["port"]?.string == "8080")
        #expect(node["count"]?.int == 10)
        #expect(node["ratio"]?.double == 1.0)
        #expect(node["enabled"]?.bool == true)
    }
    
    @Test("Sequence items with tags followed by mappings")
    func testSequenceItemTagsWithMappings() throws {
        let yaml = """
        shapes:
          - !circle
            center: {x: 73, y: 129}
            radius: 7
          - !rectangle
            width: 10
            height: 20
          - !square 15
        """
        
        let parser = YAMLParser()
        let result = try parser.parse(yaml)
        
        // Extract shapes array
        guard case .mapping(let root) = result,
              let shapes = root["shapes"],
              case .sequence(let items) = shapes else {
            Issue.record("Failed to parse shapes as sequence")
            return
        }
        
        #expect(items.count == 3)
        
        // First shape - circle with mapping
        if case .mapping(let circle) = items[0] {
            #expect(circle["radius"] != nil)
            #expect(circle["center"] != nil)
        } else {
            Issue.record("First item should be a mapping")
        }
        
        // Second shape - rectangle with mapping  
        if case .mapping(let rect) = items[1] {
            #expect(rect["width"] != nil)
            #expect(rect["height"] != nil)
        } else {
            Issue.record("Second item should be a mapping")
        }
        
        // Third shape - square with scalar value
        if case .scalar(let square) = items[2] {
            #expect(square.value == "15")
        } else {
            Issue.record("Third item should be a scalar")
        }
    }
    
    @Test("Tag on sequence item with properties on next line")
    func testTagWithPropertiesOnNextLine() throws {
        let yaml = """
        - !circle
          center: {x: 73, y: 129}
          radius: 7
        """
        
        let parser = YAMLParser()
        let result = try parser.parse(yaml)
        
        guard case .sequence(let items) = result else {
            Issue.record("Failed to parse as sequence")
            return
        }
        
        #expect(items.count == 1)
        
        // The item should be a mapping
        if case .mapping(let circle) = items[0] {
            #expect(circle["center"] != nil)
            #expect(circle["radius"] != nil)
        } else {
            Issue.record("Item should be a mapping")
        }
    }
    
    @Test("Multiple tags in sequence")
    func testMultipleTagsInSequence() throws {
        let yaml = """
        - !tag1 value1
        - !tag2
          key: value
        - !tag3 {inline: mapping}
        """
        
        let parser = YAMLParser()
        let result = try parser.parse(yaml)
        
        guard case .sequence(let items) = result else {
            Issue.record("Failed to parse as sequence")
            return
        }
        
        #expect(items.count == 3)
    }
}
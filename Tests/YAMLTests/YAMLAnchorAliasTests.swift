import Testing
@testable import YAML

@Suite("YAML Anchor and Alias Tests")
struct YAMLAnchorAliasTests {
    
    @Test("Parse simple anchor and alias")
    func parseSimpleAnchorAlias() throws {
        let yaml = """
        original: &anchor
          name: Original Object
          value: 42
        reference: *anchor
        """
        
        let node = try YAML.parse(yaml)
        
        // Both should reference the same data
        let original = node["original"]
        let reference = node["reference"]
        
        #expect(original?["name"]?.string == "Original Object")
        #expect(original?["value"]?.int == 42)
        
        #expect(reference?["name"]?.string == "Original Object")
        #expect(reference?["value"]?.int == 42)
    }
    
    @Test("Parse anchor in sequence")
    func parseAnchorInSequence() throws {
        let yaml = """
        items:
          - &first
            id: 1
            name: First Item
          - id: 2
            name: Second Item
          - *first  # Reference to first item
        """
        
        let node = try YAML.parse(yaml)
        let items = node["items"]?.array ?? []
        
        #expect(items.count == 3)
        #expect(items[0]["id"]?.int == 1)
        #expect(items[0]["name"]?.string == "First Item")
        #expect(items[2]["id"]?.int == 1)
        #expect(items[2]["name"]?.string == "First Item")
    }
    
    @Test("Parse multiple anchors and aliases")
    func parseMultipleAnchorsAliases() throws {
        let yaml = """
        defaults: &defaults
          timeout: 30
          retries: 3
        
        development: &dev
          <<: *defaults
          host: localhost
          port: 8080
        
        production:
          <<: *defaults
          host: api.example.com
          port: 443
        
        staging: *dev
        """
        
        let node = try YAML.parse(yaml)
        
        // Check defaults are applied
        #expect(node["development"]?["timeout"]?.int == 30)
        #expect(node["development"]?["retries"]?.int == 3)
        #expect(node["development"]?["host"]?.string == "localhost")
        
        #expect(node["production"]?["timeout"]?.int == 30)
        #expect(node["production"]?["retries"]?.int == 3)
        #expect(node["production"]?["host"]?.string == "api.example.com")
        
        // Staging should be identical to development
        #expect(node["staging"]?["host"]?.string == "localhost")
        #expect(node["staging"]?["port"]?.int == 8080)
    }
    
    @Test("Error on unresolved alias")
    func errorUnresolvedAlias() {
        let yaml = """
        reference: *nonexistent
        """
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parse(yaml)
        }
    }
    
    @Test("Anchor on scalar value")
    func anchorOnScalar() throws {
        let yaml = """
        name: &myname "John Doe"
        author: *myname
        contributor: *myname
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["name"]?.string == "John Doe")
        #expect(node["author"]?.string == "John Doe")
        #expect(node["contributor"]?.string == "John Doe")
    }
    
    @Test("Anchor in flow collections")
    func anchorInFlowCollections() throws {
        let yaml = """
        numbers: &nums [1, 2, 3]
        more_numbers: *nums
        config: &conf {key: value, count: 10}
        other_config: *conf
        """
        
        let node = try YAML.parse(yaml)
        
        let numbers = node["numbers"]?.array ?? []
        let moreNumbers = node["more_numbers"]?.array ?? []
        
        #expect(numbers.count == 3)
        #expect(moreNumbers.count == 3)
        #expect(numbers[0].int == 1)
        #expect(moreNumbers[0].int == 1)
        
        #expect(node["config"]?["key"]?.string == "value")
        #expect(node["other_config"]?["key"]?.string == "value")
        #expect(node["config"]?["count"]?.int == 10)
        #expect(node["other_config"]?["count"]?.int == 10)
    }
    
    @Test("Codable with anchors and aliases")
    func codableWithAnchors() throws {
        struct Config: Codable, Equatable {
            let defaults: Settings
            let development: Settings
            let production: Settings
        }
        
        struct Settings: Codable, Equatable {
            let timeout: Int
            let retries: Int
            let host: String?
            let port: Int?
        }
        
        let yaml = """
        defaults: &defaults
          timeout: 30
          retries: 3
        
        development:
          <<: *defaults
          host: localhost
          port: 8080
        
        production:
          <<: *defaults
          host: api.example.com
          port: 443
        """
        
        let decoder = YAMLDecoder()
        let config = try decoder.decode(Config.self, from: yaml)
        
        #expect(config.defaults.timeout == 30)
        #expect(config.defaults.retries == 3)
        
        #expect(config.development.timeout == 30)
        #expect(config.development.retries == 3)
        #expect(config.development.host == "localhost")
        #expect(config.development.port == 8080)
        
        #expect(config.production.timeout == 30)
        #expect(config.production.retries == 3)
        #expect(config.production.host == "api.example.com")
        #expect(config.production.port == 443)
    }
    
    @Test("Emitter with repeated objects uses anchors")
    func emitterWithRepeatedObjects() throws {
        // Create a structure with repeated references
        let sharedData = YAMLNode.mapping([
            "id": .scalar(.init(value: "shared")),
            "data": .scalar(.init(value: "important"))
        ])
        
        let root = YAMLNode.mapping([
            "first": sharedData,
            "second": sharedData,
            "third": .mapping([
                "nested": sharedData
            ])
        ])
        
        var options = YAMLEmitter.Options()
        options.useAnchorsForRepeatedNodes = true  // This would need to be added
        
        let yaml = YAML.emit(root, options: options)
        
        // The emitted YAML should use anchors
        #expect(yaml.contains("&"))
        #expect(yaml.contains("*"))
    }
}
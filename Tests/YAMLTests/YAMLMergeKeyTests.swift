import Testing
@testable import YAML

@Suite("YAML Merge Key Tests")
struct YAMLMergeKeyTests {
    
    @Test("Simple merge key")
    func simpleMergeKey() throws {
        let yaml = """
        defaults: &defaults
          timeout: 30
          retries: 3
        
        development:
          <<: *defaults
          host: localhost
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["development"]?["timeout"]?.int == 30)
        #expect(node["development"]?["retries"]?.int == 3)
        #expect(node["development"]?["host"]?.string == "localhost")
        #expect(node["development"]?["<<"] == nil)
    }
    
    @Test("Multiple merge keys with flow sequence")
    func multipleMergeKeysFlow() throws {
        let yaml = """
        base1: &base1
          a: 1
          b: 2
        
        base2: &base2
          c: 3
          d: 4
        
        merged:
          <<: [*base1, *base2]
          e: 5
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["merged"]?["a"]?.int == 1)
        #expect(node["merged"]?["b"]?.int == 2)
        #expect(node["merged"]?["c"]?.int == 3)
        #expect(node["merged"]?["d"]?.int == 4)
        #expect(node["merged"]?["e"]?.int == 5)
    }
    
    @Test("Override merge key values")
    func overrideMergeKeyValues() throws {
        let yaml = """
        defaults: &defaults
          x: 1
          y: 2
          z: 3
        
        custom:
          <<: *defaults
          y: 20  # Override y
          w: 4   # Add new key
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["custom"]?["x"]?.int == 1)
        #expect(node["custom"]?["y"]?.int == 20) // Local value overrides
        #expect(node["custom"]?["z"]?.int == 3)
        #expect(node["custom"]?["w"]?.int == 4)
    }
    
    @Test("Nested merge keys")
    func nestedMergeKeys() throws {
        let yaml = """
        base: &base
          database:
            host: localhost
            port: 5432
        
        dev: &dev
          <<: *base
          database:
            name: dev_db
        
        test:
          <<: *dev
          database:
            name: test_db
        """
        
        let node = try YAML.parse(yaml)
        
        // The database object is replaced entirely, not merged
        #expect(node["dev"]?["database"]?["name"]?.string == "dev_db")
        #expect(node["dev"]?["database"]?["host"] == nil) // Not merged
        
        #expect(node["test"]?["database"]?["name"]?.string == "test_db")
    }
    
    @Test("Merge key in sequence")
    func mergeKeyInSequence() throws {
        let yaml = """
        defaults: &defaults
          type: standard
          size: medium
        
        items:
          - <<: *defaults
            name: item1
          - <<: *defaults
            name: item2
            size: large
        """
        
        let node = try YAML.parse(yaml)
        
        let items = node["items"]?.array ?? []
        #expect(items.count == 2)
        
        #expect(items[0]["type"]?.string == "standard")
        #expect(items[0]["size"]?.string == "medium")
        #expect(items[0]["name"]?.string == "item1")
        
        #expect(items[1]["type"]?.string == "standard")
        #expect(items[1]["size"]?.string == "large") // Override
        #expect(items[1]["name"]?.string == "item2")
    }
    
    @Test("Merge key order precedence")
    func mergeKeyOrderPrecedence() throws {
        let yaml = """
        base1: &base1
          x: 1
          y: 2
        
        base2: &base2
          y: 20
          z: 30
        
        # First occurrence wins in merge
        merged:
          <<: [*base1, *base2]
          w: 40
        """
        
        let node = try YAML.parse(yaml)
        
        #expect(node["merged"]?["x"]?.int == 1) // From base1
        #expect(node["merged"]?["y"]?.int == 2) // From base1 (first occurrence wins)
        #expect(node["merged"]?["z"]?.int == 30) // From base2
        #expect(node["merged"]?["w"]?.int == 40) // Local
    }
}
import Testing
@testable import YAML

@Suite("YAML Indentation Test")
struct YAMLIndentationTest {
    
    @Test("Parse sequence items at same indentation as parent key")
    func sequenceAtParentIndentation() throws {
        // This is a common pattern in YAML where sequence items
        // start at the same indentation level as their parent key
        let yaml = """
        parent:
          items:
          - item1
          - item2
          other: value
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let root) = node,
              case .mapping(let parent) = root["parent"],
              case .sequence(let items) = parent["items"] else {
            #expect(Bool(false), "Expected structure")
            return
        }
        
        #expect(items.count == 2)
        #expect(items.first?.string == "item1")
        #expect(items.last?.string == "item2")
        #expect(parent["other"]?.string == "value")
    }
    
    @Test("Parse compact sequence notation")
    func compactSequenceNotation() throws {
        // Even more compact - no space after colon
        let yaml = """
        containers:
        - name: nginx
          image: nginx:latest
        - name: redis
          image: redis:alpine
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let root) = node,
              case .sequence(let containers) = root["containers"] else {
            #expect(Bool(false), "Expected containers sequence")
            return
        }
        
        #expect(containers.count == 2)
        
        guard case .mapping(let nginx) = containers.first else {
            #expect(Bool(false), "Expected nginx mapping")
            return
        }
        
        #expect(nginx["name"]?.string == "nginx")
        #expect(nginx["image"]?.string == "nginx:latest")
    }
}
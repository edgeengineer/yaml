import Testing
@testable import YAML

@Suite("YAML Multi-Document Tests")
struct YAMLMultiDocumentTests {
    
    @Test("Parse multiple documents")
    func parseMultipleDocuments() throws {
        let yaml = """
---
document: 1
content: First document
---
document: 2
content: Second document
---
document: 3
content: Third document
"""
        
        let documents = try YAML.parseStream(yaml)
        
        #expect(documents.count == 3)
        
        #expect(documents[0]["document"]?.int == 1)
        #expect(documents[0]["content"]?.string == "First document")
        
        #expect(documents[1]["document"]?.int == 2)
        #expect(documents[1]["content"]?.string == "Second document")
        
        #expect(documents[2]["document"]?.int == 3)
        #expect(documents[2]["content"]?.string == "Third document")
    }
    
    @Test("Parse documents with different types")
    func parseDocumentsWithDifferentTypes() throws {
        let yaml = """
---
# First document is a mapping
type: config
version: 1.0
---
# Second document is a sequence
- item1
- item2
- item3
---
# Third document is a scalar
Just a plain string
"""
        
        let documents = try YAML.parseStream(yaml)
        
        #expect(documents.count == 3)
        
        // First document should be a mapping
        #expect(documents[0]["type"]?.string == "config")
        #expect(documents[0]["version"]?.double == 1.0)
        
        // Second document should be a sequence
        #expect(documents[1].array?.count == 3)
        #expect(documents[1][0]?.string == "item1")
        
        // Third document should be a scalar
        #expect(documents[2].string == "Just a plain string")
    }
    
    @Test("Empty documents")
    func emptyDocuments() throws {
        let yaml = """
---
---
content: Not empty
---
---
"""
        
        let documents = try YAML.parseStream(yaml)
        
        #expect(documents.count == 4)
        #expect(documents[0].isNull || documents[0].string == "")
        #expect(documents[1]["content"]?.string == "Not empty")
        #expect(documents[2].isNull || documents[2].string == "")
        #expect(documents[3].isNull || documents[3].string == "")
    }
    
    @Test("Document with end marker")
    func documentWithEndMarker() throws {
        let yaml = """
---
document: with end marker
...
---
document: another one
...
"""
        
        let documents = try YAML.parseStream(yaml)
        
        #expect(documents.count == 2)
        #expect(documents[0]["document"]?.string == "with end marker")
        #expect(documents[1]["document"]?.string == "another one")
    }
    
    @Test("Emit multiple documents")
    func emitMultipleDocuments() throws {
        let doc1 = YAMLNode.mapping([
            "name": .scalar(.init(value: "Document 1")),
            "id": .scalar(.init(value: "1"))
        ])
        
        let doc2 = YAMLNode.sequence([
            .scalar(.init(value: "item1")),
            .scalar(.init(value: "item2"))
        ])
        
        let doc3 = YAMLNode.scalar(.init(value: "Just a scalar document"))
        
        let yaml = YAML.emit([doc1, doc2, doc3])
        
        // Should contain document separators
        let separatorCount = yaml.components(separatedBy: "---").count - 1
        #expect(separatorCount >= 2)
        
        // Parse it back
        let parsed = try YAML.parseStream(yaml)
        #expect(parsed.count == 3)
        #expect(parsed[0]["name"]?.string == "Document 1")
        #expect(parsed[1].array?.count == 2)
        #expect(parsed[2].string == "Just a scalar document")
    }
    
    @Test("Stream parser with document events")
    func streamParserDocumentEvents() throws {
        let yaml = """
---
first: document
---
second: document
"""
        
        class TestDelegate: YAMLStreamParserDelegate {
            var events: [YAMLToken] = []
            
            func parser(_ parser: YAMLStreamParser, didParse token: YAMLToken) {
                events.append(token)
            }
        }
        
        let delegate = TestDelegate()
        let parser = YAMLStreamParser()
        parser.delegate = delegate
        
        try parser.parse(yaml)
        
        // Should have document start events
        let documentStarts = delegate.events.filter { token in
            if case .documentStart = token { return true }
            return false
        }
        
        let documentEnds = delegate.events.filter { token in
            if case .documentEnd = token { return true }
            return false
        }
        
        #expect(documentStarts.count >= 2)
        #expect(documentEnds.count >= 2)
    }
    
    @Test("Anchors scoped to documents")
    func anchorsScoped() throws {
        let yaml = """
---
anchor: &first "Document 1"
reference: *first
---
# This should fail because anchors don't cross document boundaries
reference: *first
"""
        
        #expect(throws: YAMLError.self) {
            _ = try YAML.parseStream(yaml)
        }
    }
    
    @Test("Directives per document")
    func directivesPerDocument() throws {
        let yaml = """
%YAML 1.2
---
version: 1.2
...
%YAML 1.1
---
version: 1.1
"""
        
        // Parse and check that directives are handled
        let documents = try YAML.parseStream(yaml)
        
        #expect(documents.count == 2)
        #expect(documents[0]["version"]?.double == 1.2)
        #expect(documents[1]["version"]?.double == 1.1)
    }
    
    @Test("Single document without separator")
    func singleDocumentWithoutSeparator() throws {
        let yaml = """
key: value
list:
  - item1
  - item2
"""
        
        // parseStream should handle single documents too
        let documents = try YAML.parseStream(yaml)
        
        #expect(documents.count == 1)
        #expect(documents[0]["key"]?.string == "value")
        #expect(documents[0]["list"]?.array?.count == 2)
    }
}
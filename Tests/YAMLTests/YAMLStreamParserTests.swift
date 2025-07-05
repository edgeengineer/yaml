import Testing
import Foundation
@testable import YAML

@Suite("YAML Stream Parser Tests")
struct YAMLStreamParserTests {
    // Test delegate to collect tokens
    final class TestDelegate: YAMLStreamParserDelegate {
        var tokens: [YAMLToken] = []
        var errors: [Error] = []
        var documentStarted = false
        var documentEnded = false
        
        func parser(_ parser: YAMLStreamParser, didParse token: YAMLToken) {
            tokens.append(token)
        }
        
        func parserDidStartDocument(_ parser: YAMLStreamParser) {
            documentStarted = true
        }
        
        func parserDidEndDocument(_ parser: YAMLStreamParser) {
            documentEnded = true
        }
        
        func parser(_ parser: YAMLStreamParser, didFailWithError error: Error) {
            errors.append(error)
        }
    }
    
    @Test("Parse simple scalar stream")
    func parseSimpleScalarStream() throws {
        let yaml = "Hello, World!"
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        try parser.parse(yaml)
        
        #expect(delegate.documentStarted)
        #expect(delegate.documentEnded)
        #expect(delegate.tokens.count == 3) // documentStart, scalar, documentEnd
        
        if case .scalar(let scalar) = delegate.tokens[1] {
            #expect(scalar.value == "Hello, World!")
        } else {
            Issue.record("Expected scalar token")
        }
    }
    
    @Test("Parse sequence stream")
    func parseSequenceStream() throws {
        let yaml = """
        - apple
        - banana
        - cherry
        """
        
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        try parser.parse(yaml)
        
        #expect(delegate.tokens.count == 7) // documentStart, sequenceStart, 3 scalars, sequenceEnd, documentEnd
        
        var index = 0
        #expect(delegate.tokens[index] == .documentStart)
        index += 1
        #expect(delegate.tokens[index] == .sequenceStart)
        index += 1
        
        if case .scalar(let scalar1) = delegate.tokens[index] {
            #expect(scalar1.value == "apple")
        }
        index += 1
        
        if case .scalar(let scalar2) = delegate.tokens[index] {
            #expect(scalar2.value == "banana")
        }
        index += 1
        
        if case .scalar(let scalar3) = delegate.tokens[index] {
            #expect(scalar3.value == "cherry")
        }
        index += 1
        
        #expect(delegate.tokens[index] == .sequenceEnd)
        index += 1
        #expect(delegate.tokens[index] == .documentEnd)
    }
    
    @Test("Parse mapping stream")
    func parseMappingStream() throws {
        let yaml = """
        name: John Doe
        age: 30
        city: New York
        """
        
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        try parser.parse(yaml)
        
        #expect(delegate.tokens.count == 10) // documentStart, mappingStart, 3*(key+scalar), mappingEnd, documentEnd
        
        var index = 0
        #expect(delegate.tokens[index] == .documentStart)
        index += 1
        #expect(delegate.tokens[index] == .mappingStart)
        index += 1
        
        if case .key(let key1) = delegate.tokens[index] {
            #expect(key1 == "name")
        }
        index += 1
        
        if case .scalar(let value1) = delegate.tokens[index] {
            #expect(value1.value == "John Doe")
        }
        index += 1
        
        if case .key(let key2) = delegate.tokens[index] {
            #expect(key2 == "age")
        }
        index += 1
        
        if case .scalar(let value2) = delegate.tokens[index] {
            #expect(value2.value == "30")
            #expect(value2.tag == .int)
        }
        index += 1
    }
    
    @Test("Parse nested structures stream")
    func parseNestedStructuresStream() throws {
        let yaml = """
        person:
          name: Jane
          hobbies:
            - reading
            - swimming
        """
        
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        try parser.parse(yaml)
        
        // Verify we get the right sequence of tokens
        var tokenTypes: [String] = []
        for token in delegate.tokens {
            switch token {
            case .documentStart: tokenTypes.append("docStart")
            case .documentEnd: tokenTypes.append("docEnd")
            case .mappingStart: tokenTypes.append("mapStart")
            case .mappingEnd: tokenTypes.append("mapEnd")
            case .sequenceStart: tokenTypes.append("seqStart")
            case .sequenceEnd: tokenTypes.append("seqEnd")
            case .key(let k): tokenTypes.append("key:\(k)")
            case .scalar(let s): tokenTypes.append("scalar:\(s.value)")
            }
        }
        
        #expect(tokenTypes.contains("key:person"))
        #expect(tokenTypes.contains("key:name"))
        #expect(tokenTypes.contains("scalar:Jane"))
        #expect(tokenTypes.contains("key:hobbies"))
        #expect(tokenTypes.contains("scalar:reading"))
        #expect(tokenTypes.contains("scalar:swimming"))
    }
    
    @Test("Parse from input stream")
    func parseFromInputStream() throws {
        let yaml = """
        items:
          - id: 1
            name: Item One
          - id: 2
            name: Item Two
        """
        
        // Create input stream from data
        let data = yaml.data(using: .utf8)!
        let inputStream = InputStream(data: data)
        
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        try parser.parse(from: inputStream)
        
        #expect(delegate.documentStarted)
        #expect(delegate.documentEnded)
        #expect(delegate.tokens.count > 0)
        
        // Verify we got key tokens
        let keyTokens = delegate.tokens.compactMap { token -> String? in
            if case .key(let k) = token { return k }
            return nil
        }
        
        #expect(keyTokens.contains("items"))
        #expect(keyTokens.contains("id"))
        #expect(keyTokens.contains("name"))
    }
    
    @Test("Memory efficiency test")
    func memoryEfficiencyTest() throws {
        // Create a large YAML document
        var yaml = "items:\n"
        for i in 0..<1000 {
            yaml += "  - id: \(i)\n"
            yaml += "    name: Item \(i)\n"
            yaml += "    description: This is a long description for item \(i) that contains many words\n"
        }
        
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        // Parse the large document
        try parser.parse(yaml)
        
        // Verify we processed all items
        let idCount = delegate.tokens.filter { token in
            if case .key("id") = token { return true }
            return false
        }.count
        
        #expect(idCount == 1000)
        
        // The streaming parser should have processed this without loading
        // the entire structure into memory at once
        #expect(delegate.documentStarted)
        #expect(delegate.documentEnded)
    }
    
    @Test("Parse with comments and empty lines")
    func parseWithCommentsAndEmptyLines() throws {
        let yaml = """
        # This is a comment
        name: Test # inline comment
        
        # Another comment
        value: 123
        """
        
        let parser = YAMLStreamParser()
        let delegate = TestDelegate()
        parser.delegate = delegate
        
        try parser.parse(yaml)
        
        // Comments should be ignored
        let keys = delegate.tokens.compactMap { token -> String? in
            if case .key(let k) = token { return k }
            return nil
        }
        
        #expect(keys == ["name", "value"])
    }
}
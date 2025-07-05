import Testing
@testable import YAML

@Suite("YAML Quoted Null Tests")
struct YAMLQuotedNullTest {
    
    @Test("Quoted null should be string")
    func quotedNullIsString() throws {
        let yaml = """
        plain_null: null
        quoted_null: "null"
        single_quoted_null: 'null'
        empty_string: ""
        plain_tilde: ~
        quoted_tilde: "~"
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        // Plain null should be null
        #expect(dict["plain_null"]?.isNull == true)
        
        // Quoted null should be string "null"
        #expect(dict["quoted_null"]?.string == "null")
        #expect(dict["quoted_null"]?.isNull == false)
        
        // Single quoted null should be string "null"
        #expect(dict["single_quoted_null"]?.string == "null")
        #expect(dict["single_quoted_null"]?.isNull == false)
        
        // Empty string
        #expect(dict["empty_string"]?.string == "")
        
        // Plain tilde should be null
        #expect(dict["plain_tilde"]?.isNull == true)
        
        // Quoted tilde should be string "~"
        #expect(dict["quoted_tilde"]?.string == "~")
        #expect(dict["quoted_tilde"]?.isNull == false)
    }
    
    @Test("Round-trip quoted null")
    func roundTripQuotedNull() throws {
        let yaml = """
        quoted_null: "null"
        quoted_tilde: "~"
        quoted_empty: ""
        """
        
        let node = try YAML.parse(yaml)
        let emitted = YAML.emit(node)
        let reparsed = try YAML.parse(emitted)
        
        guard case .mapping(let original) = node,
              case .mapping(let reparsedDict) = reparsed else {
            #expect(Bool(false), "Expected mappings")
            return
        }
        
        // Check all values remain as strings
        #expect(original["quoted_null"]?.string == reparsedDict["quoted_null"]?.string)
        #expect(original["quoted_tilde"]?.string == reparsedDict["quoted_tilde"]?.string)
        #expect(original["quoted_empty"]?.string == reparsedDict["quoted_empty"]?.string)
    }
}
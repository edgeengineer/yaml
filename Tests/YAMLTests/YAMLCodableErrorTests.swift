import Testing
@testable import YAML

@Suite("YAML Codable Error Tests")
struct YAMLCodableErrorTests {
    
    @Test("Type mismatch - string to int")
    func stringToIntMismatch() throws {
        struct Model: Decodable {
            let count: Int
        }
        
        let yaml = """
        count: "not a number"
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        // Verify the error provides useful context
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch(let type, let context):
                #expect(type is Int.Type)
                #expect(context.codingPath.count == 1)
                #expect(context.codingPath[0].stringValue == "count")
                #expect(context.debugDescription.contains("Int") || context.debugDescription.contains("number"))
            default:
                Issue.record("Expected typeMismatch error, got \(error)")
            }
        }
    }
    
    @Test("Type mismatch - int to string")
    func intToStringMismatch() throws {
        struct Model: Decodable {
            let name: String
        }
        
        let yaml = """
        name: 12345
        """
        
        // This should actually work as YAML scalars can be interpreted as strings
        let model = try YAMLDecoder().decode(Model.self, from: yaml)
        #expect(model.name == "12345")
    }
    
    @Test("Type mismatch - array to dictionary")
    func arrayToDictionaryMismatch() throws {
        struct Model: Decodable {
            let config: [String: String]
        }
        
        let yaml = """
        config:
          - item1
          - item2
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch(_, let context):
                #expect(context.codingPath.count == 1)
                #expect(context.codingPath[0].stringValue == "config")
            default:
                Issue.record("Expected typeMismatch error")
            }
        }
    }
    
    @Test("Type mismatch - dictionary to array")
    func dictionaryToArrayMismatch() throws {
        struct Model: Decodable {
            let items: [String]
        }
        
        let yaml = """
        items:
          key1: value1
          key2: value2
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
    }
    
    @Test("Missing required field")
    func missingRequiredField() throws {
        struct Model: Decodable {
            let name: String
            let age: Int
        }
        
        let yaml = """
        name: John
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .keyNotFound(let key, let context):
                #expect(key.stringValue == "age")
                #expect(context.codingPath.isEmpty || context.codingPath.count == 1)
            default:
                Issue.record("Expected keyNotFound error")
            }
        }
    }
    
    @Test("Null value for non-optional")
    func nullForNonOptional() throws {
        struct Model: Decodable {
            let value: String
        }
        
        let yaml = """
        value: null
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .valueNotFound(let type, let context):
                #expect(type is String.Type)
                #expect(context.codingPath.count >= 1)
                #expect(context.codingPath.last?.stringValue == "value")
            default:
                Issue.record("Expected valueNotFound error, got \(error)")
            }
        }
    }
    
    @Test("Invalid enum value")
    func invalidEnumValue() throws {
        enum Status: String, Decodable {
            case active
            case inactive
            case pending
        }
        
        struct Model: Decodable {
            let status: Status
        }
        
        let yaml = """
        status: unknown
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
    }
    
    @Test("Nested type mismatch")
    func nestedTypeMismatch() throws {
        struct Inner: Decodable {
            let value: Int
        }
        
        struct Model: Decodable {
            let nested: Inner
        }
        
        let yaml = """
        nested:
          value: "not a number"
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch(_, let context):
                #expect(context.codingPath.count == 2)
                #expect(context.codingPath[0].stringValue == "nested")
                #expect(context.codingPath[1].stringValue == "value")
            default:
                Issue.record("Expected typeMismatch with nested path")
            }
        }
    }
    
    @Test("Array element type mismatch")
    func arrayElementTypeMismatch() throws {
        struct Model: Decodable {
            let numbers: [Int]
        }
        
        let yaml = """
        numbers:
          - 1
          - 2
          - "three"
          - 4
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .typeMismatch(_, let context):
                // Should indicate which array element failed
                #expect(context.codingPath.count >= 2)
                #expect(context.codingPath[0].stringValue == "numbers")
                #expect(context.codingPath[1].intValue == 2) // Third element (index 2)
            default:
                Issue.record("Expected typeMismatch with array index")
            }
        }
    }
    
    @Test("Custom decoding error")
    func customDecodingError() throws {
        struct Model: Decodable {
            let value: Int
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let value = try container.decode(Int.self, forKey: .value)
                
                // Custom validation
                guard value > 0 else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: decoder.codingPath + [CodingKeys.value],
                            debugDescription: "Value must be positive"
                        )
                    )
                }
                
                self.value = value
            }
            
            enum CodingKeys: String, CodingKey {
                case value
            }
        }
        
        let yaml = """
        value: -5
        """
        
        #expect(throws: DecodingError.self) {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        }
        
        do {
            _ = try YAMLDecoder().decode(Model.self, from: yaml)
        } catch let error as DecodingError {
            switch error {
            case .dataCorrupted(let context):
                #expect(context.debugDescription == "Value must be positive")
            default:
                Issue.record("Expected dataCorrupted error")
            }
        }
    }
}
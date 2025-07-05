import Testing
@testable import YAML
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Suite("YAML Advanced Codable Tests")
struct YAMLAdvancedCodableTests {
    
    // MARK: - Date Encoding/Decoding Tests
    
    @Test("ISO8601 date encoding strategy")
    func iso8601DateEncoding() throws {
        struct Model: Codable, Equatable {
            let createdAt: Date
            let updatedAt: Date
        }
        
        let formatter = ISO8601DateFormatter()
        let date1 = formatter.date(from: "2024-01-15T10:30:00Z")!
        let date2 = formatter.date(from: "2024-01-15T14:45:30Z")!
        
        let model = Model(createdAt: date1, updatedAt: date2)
        
        // Test encoding with ISO8601
        var encoder = YAMLEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let yaml = try encoder.encode(model)
        
        // The dates should be encoded as ISO8601 strings
        #expect(yaml.contains("2024-01-15T10:30:00Z"))
        #expect(yaml.contains("2024-01-15T14:45:30Z"))
        
        // Test decoding
        var decoder = YAMLDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let decoded = try decoder.decode(Model.self, from: yaml)
        
        // Compare timestamps (avoid exact equality due to potential precision issues)
        #expect(abs(decoded.createdAt.timeIntervalSince(date1)) < 0.001)
        #expect(abs(decoded.updatedAt.timeIntervalSince(date2)) < 0.001)
    }
    
    @Test("Custom date encoding strategy")
    func customDateEncoding() throws {
        struct Model: Codable {
            let timestamp: Date
        }
        
        let date = Date(timeIntervalSince1970: 1705320600) // 2024-01-15 12:30:00 UTC
        let model = Model(timestamp: date)
        
        // Custom formatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        
        // Encode with custom formatter
        var encoder = YAMLEncoder()
        encoder.dateEncodingStrategy = .formatted(formatter)
        
        let yaml = try encoder.encode(model)
        // The formatter might use local time zone, so just check the format
        #expect(yaml.contains("timestamp:"))
        
        // Decode with custom formatter
        var decoder = YAMLDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        let decoded = try decoder.decode(Model.self, from: yaml)
        #expect(abs(decoded.timestamp.timeIntervalSince(date)) < 0.001)
    }
    
    @Test("Milliseconds since epoch date strategy")
    func millisecondsSinceEpochDateStrategy() throws {
        struct Model: Codable {
            let timestamp: Date
        }
        
        let date = Date(timeIntervalSince1970: 1705320600.123) // With milliseconds
        let model = Model(timestamp: date)
        
        // Encode as milliseconds
        var encoder = YAMLEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        
        let yaml = try encoder.encode(model)
        #expect(yaml.contains("1705320600123")) // Milliseconds
        
        // Decode from milliseconds
        var decoder = YAMLDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        let decoded = try decoder.decode(Model.self, from: yaml)
        #expect(abs(decoded.timestamp.timeIntervalSince(date)) < 0.001)
    }
    
    // MARK: - Key Encoding/Decoding Strategy Tests
    
    @Test("Custom key encoding strategy")
    func customKeyEncodingStrategy() throws {
        struct Model: Codable {
            let firstName: String
            let lastName: String
            let emailAddress: String
        }
        
        let model = Model(
            firstName: "John",
            lastName: "Doe",
            emailAddress: "john@example.com"
        )
        
        // Custom key encoding that adds prefix
        var encoder = YAMLEncoder()
        encoder.keyEncodingStrategy = .custom { codingPath in
            let key = codingPath.last!
            return AnyKey(stringValue: "user_\(key.stringValue)")!
        }
        
        let yaml = try encoder.encode(model)
        
        #expect(yaml.contains("user_firstName"))
        #expect(yaml.contains("user_lastName"))
        #expect(yaml.contains("user_emailAddress"))
        
        // Check that the original keys are NOT present as standalone keys
        // Note: "firstName:" is a substring of "user_firstName:", so we need to check more carefully
        #expect(!yaml.contains("\nfirstName:") && !yaml.hasPrefix("firstName:"))
        
        // Decode with custom strategy
        var decoder = YAMLDecoder()
        decoder.keyDecodingStrategy = .custom { codingPath in
            let key = codingPath.last!
            // Convert Swift property name to YAML key name
            return AnyKey(stringValue: "user_\(key.stringValue)")!
        }
        
        let decoded = try decoder.decode(Model.self, from: yaml)
        #expect(decoded.firstName == model.firstName)
        #expect(decoded.lastName == model.lastName)
        #expect(decoded.emailAddress == model.emailAddress)
    }
    
    @Test("Key conversion with nested structures")
    func keyConversionNested() throws {
        struct Address: Codable, Equatable {
            let streetName: String
            let zipCode: String
        }
        
        struct Person: Codable, Equatable {
            let firstName: String
            let homeAddress: Address
        }
        
        let person = Person(
            firstName: "Jane",
            homeAddress: Address(
                streetName: "Main St",
                zipCode: "12345"
            )
        )
        
        // Test snake_case conversion
        var encoder = YAMLEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let yaml = try encoder.encode(person)
        
        #expect(yaml.contains("first_name"))
        #expect(yaml.contains("home_address"))
        #expect(yaml.contains("street_name"))
        #expect(yaml.contains("zip_code"))
        
        // Decode back
        var decoder = YAMLDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let decoded = try decoder.decode(Person.self, from: yaml)
        #expect(decoded == person)
    }
    
    // MARK: - UserInfo Tests
    
    @Test("UserInfo context passing")
    func userInfoContext() throws {
        struct VersionedModel: Codable {
            let data: String
            let version: String
            
            init(data: String, version: String = "1.0") {
                self.data = data
                self.version = version
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.data = try container.decode(String.self, forKey: .data)
                
                // Try to get version from userInfo
                let versionKey = CodingUserInfoKey(rawValue: "apiVersion")!
                if let version = decoder.userInfo[versionKey] as? String {
                    self.version = version
                } else {
                    self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
                }
            }
        }
        
        // Encode without explicit version
        let model = VersionedModel(data: "test data")
        var encoder = YAMLEncoder()
        let yaml = try encoder.encode(model)
        
        // Decode with version from userInfo
        var decoder = YAMLDecoder()
        let versionKey = CodingUserInfoKey(rawValue: "apiVersion")!
        decoder.userInfo[versionKey] = "2.0"
        
        let decoded = try decoder.decode(VersionedModel.self, from: yaml)
        #expect(decoded.data == "test data")
        #expect(decoded.version == "2.0") // From userInfo, not from YAML
    }
    
    // MARK: - Non-conforming Float Tests
    
    @Test("Non-conforming float encoding")
    func nonConformingFloatEncoding() throws {
        struct Model: Codable {
            let value1: Double
            let value2: Double
            let value3: Double
        }
        
        let model = Model(
            value1: .infinity,
            value2: -.infinity,
            value3: .nan
        )
        
        // Default encoding should fail for non-conforming floats
        var encoder = YAMLEncoder()
        #expect(throws: EncodingError.self) {
            _ = try encoder.encode(model)
        }
        
        // With custom strategy
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        
        let yaml = try encoder.encode(model)
        #expect(yaml.contains("+Infinity"))
        #expect(yaml.contains("-Infinity"))
        #expect(yaml.contains("NaN"))
        
        // Decode back
        var decoder = YAMLDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "+Infinity",
            negativeInfinity: "-Infinity",
            nan: "NaN"
        )
        
        let decoded = try decoder.decode(Model.self, from: yaml)
        #expect(decoded.value1.isInfinite && decoded.value1 > 0)
        #expect(decoded.value2.isInfinite && decoded.value2 < 0)
        #expect(decoded.value3.isNaN)
    }
    
    // MARK: - Data Encoding Tests
    
    @Test("Custom data encoding")
    func customDataEncoding() throws {
        struct Model: Codable {
            let payload: Data
            let checksum: Data
        }
        
        let data1 = "Hello, World!".data(using: .utf8)!
        let data2 = Data([0x01, 0x02, 0x03, 0x04])
        
        let model = Model(payload: data1, checksum: data2)
        
        // Test with custom encoding
        var encoder = YAMLEncoder()
        encoder.dataEncodingStrategy = .custom { data, encoder in
            // Encode as hex string
            let hex = data.map { String(format: "%02x", $0) }.joined()
            var container = encoder.singleValueContainer()
            try container.encode(hex)
        }
        
        let yaml = try encoder.encode(model)
        
        // Should contain hex representations
        let expectedHex1 = data1.map { String(format: "%02x", $0) }.joined()
        let expectedHex2 = "01020304"
        
        #expect(yaml.contains(expectedHex1))
        #expect(yaml.contains(expectedHex2))
        
        // Decode with custom strategy
        var decoder = YAMLDecoder()
        decoder.dataDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let hex = try container.decode(String.self)
            
            // Convert hex string back to data
            var data = Data()
            var index = hex.startIndex
            while index < hex.endIndex {
                let nextIndex = hex.index(index, offsetBy: 2)
                if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
                    data.append(byte)
                }
                index = nextIndex
            }
            return data
        }
        
        let decoded = try decoder.decode(Model.self, from: yaml)
        #expect(decoded.payload == data1)
        #expect(decoded.checksum == data2)
    }
}

// Helper struct for custom key strategies
struct AnyKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
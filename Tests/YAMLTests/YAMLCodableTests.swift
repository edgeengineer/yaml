import Testing
import Foundation
@testable import YAML

@Suite("YAML Codable Tests")
struct YAMLCodableTests {
    struct Person: Codable, Equatable {
        let name: String
        let age: Int
        let email: String?
    }
    
    struct Company: Codable, Equatable {
        let name: String
        let employees: [Person]
        let founded: Int
    }
    
    @Test("Encode simple struct")
    func encodeSimpleStruct() throws {
        let person = Person(name: "John Doe", age: 30, email: "john@example.com")
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(person)
        
        #expect(yaml.contains("name: John Doe"))
        #expect(yaml.contains("age: 30"))
        #expect(yaml.contains("email: john@example.com"))
    }
    
    @Test("Decode simple struct")
    func decodeSimpleStruct() throws {
        let yaml = """
        name: Jane Smith
        age: 25
        email: jane@example.com
        """
        
        let decoder = YAMLDecoder()
        let person = try decoder.decode(Person.self, from: yaml)
        
        #expect(person.name == "Jane Smith")
        #expect(person.age == 25)
        #expect(person.email == "jane@example.com")
    }
    
    @Test("Encode and decode nil values")
    func encodeDecodeNilValues() throws {
        let person = Person(name: "Bob", age: 40, email: nil)
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(person)
        
        let decoder = YAMLDecoder()
        let decoded = try decoder.decode(Person.self, from: yaml)
        
        #expect(decoded.name == person.name)
        #expect(decoded.age == person.age)
        #expect(decoded.email == nil)
    }
    
    @Test("Encode nested structures")
    func encodeNestedStructures() throws {
        let company = Company(
            name: "Tech Corp",
            employees: [
                Person(name: "Alice", age: 28, email: "alice@tech.com"),
                Person(name: "Bob", age: 35, email: nil)
            ],
            founded: 2020
        )
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(company)
        
        #expect(yaml.contains("name: Tech Corp"))
        #expect(yaml.contains("founded: 2020"))
        #expect(yaml.contains("employees:"))
        #expect(yaml.contains("- name: Alice"))
        #expect(yaml.contains("age: 28"))
    }
    
    @Test("Decode nested structures")
    func decodeNestedStructures() throws {
        let yaml = """
        name: StartUp Inc
        founded: 2022
        employees:
          - name: Charlie
            age: 30
            email: charlie@startup.com
          - name: David
            age: 45
            email: ~
        """
        
        let decoder = YAMLDecoder()
        let company = try decoder.decode(Company.self, from: yaml)
        
        #expect(company.name == "StartUp Inc")
        #expect(company.founded == 2022)
        #expect(company.employees.count == 2)
        #expect(company.employees[0].name == "Charlie")
        #expect(company.employees[1].email == nil)
    }
    
    @Test("Round trip codable")
    func roundTripCodable() throws {
        let original = Company(
            name: "Round Trip Co",
            employees: [
                Person(name: "Eve", age: 33, email: "eve@rt.com"),
                Person(name: "Frank", age: 29, email: nil)
            ],
            founded: 2018
        )
        
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(original)
        
        let decoder = YAMLDecoder()
        let decoded = try decoder.decode(Company.self, from: yaml)
        
        #expect(decoded == original)
    }
    
    @Test("Encode with sorted keys")
    func encodeWithSortedKeys() throws {
        let person = Person(name: "Sorted", age: 20, email: "sorted@test.com")
        
        var options = YAMLEncoder.Options()
        options.outputFormatting = .sortedKeys
        let encoder = YAMLEncoder(options: options)
        
        let yaml = try encoder.encode(person)
        let lines = yaml.split(separator: "\n").map(String.init)
        
        #expect(lines[0] == "age: 20")
        #expect(lines[1] == "email: sorted@test.com")
        #expect(lines[2] == "name: Sorted")
    }
    
    struct SnakeCaseStruct: Codable {
        let firstName: String
        let lastName: String
        let emailAddress: String
    }
    
    @Test("Decode with snake case conversion")
    func decodeWithSnakeCaseConversion() throws {
        let yaml = """
        first_name: John
        last_name: Snake
        email_address: john.snake@example.com
        """
        
        var options = YAMLDecoder.Options()
        options.keyDecodingStrategy = .convertFromSnakeCase
        let decoder = YAMLDecoder(options: options)
        
        let decoded = try decoder.decode(SnakeCaseStruct.self, from: yaml)
        
        #expect(decoded.firstName == "John")
        #expect(decoded.lastName == "Snake")
        #expect(decoded.emailAddress == "john.snake@example.com")
    }
    
    @Test("Encode with snake case conversion")
    func encodeWithSnakeCaseConversion() throws {
        let data = SnakeCaseStruct(
            firstName: "Jane",
            lastName: "Camel",
            emailAddress: "jane.camel@example.com"
        )
        
        var options = YAMLEncoder.Options()
        options.keyEncodingStrategy = .convertToSnakeCase
        let encoder = YAMLEncoder(options: options)
        
        let yaml = try encoder.encode(data)
        
        #expect(yaml.contains("first_name: Jane"))
        #expect(yaml.contains("last_name: Camel"))
        #expect(yaml.contains("email_address: jane.camel@example.com"))
    }
    
    @Test("Encode and decode dates")
    func encodeDecodeDates() throws {
        struct DateContainer: Codable {
            let created: Date
            let updated: Date?
        }
        
        let now = Date()
        let container = DateContainer(created: now, updated: nil)
        
        var encoder = YAMLEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        
        let yaml = try encoder.encode(container)
        
        var decoder = YAMLDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        
        let decoded = try decoder.decode(DateContainer.self, from: yaml)
        
        #expect(abs(decoded.created.timeIntervalSince1970 - now.timeIntervalSince1970) < 0.001)
        #expect(decoded.updated == nil)
    }
    
    @Test("Encode and decode data")
    func encodeDecodeData() throws {
        struct DataContainer: Codable {
            let payload: Data
        }
        
        let originalData = "Hello, YAML!".data(using: .utf8)!
        let container = DataContainer(payload: originalData)
        
        var encoder = YAMLEncoder()
        encoder.dataEncodingStrategy = .base64
        let yaml = try encoder.encode(container)
        
        // Check that the data is encoded as base64
        #expect(yaml.contains("SGVsbG8sIFlBTUwh"))
        
        var decoder = YAMLDecoder()
        decoder.dataDecodingStrategy = .base64
        let decoded = try decoder.decode(DataContainer.self, from: yaml)
        
        #expect(decoded.payload == originalData)
    }
}
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
/// A decoder that decodes instances of data types from YAML objects.
public struct YAMLDecoder {
    /// Options for customizing the decoding process.
    public struct Options: Sendable {
        /// The strategy to use for decoding `Date` values.
        public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
        
        /// The strategy to use for decoding `Data` values.
        public var dataDecodingStrategy: DataDecodingStrategy = .base64
        
        /// The strategy to use for non-conforming floating-point values (IEEE 754 infinity and NaN).
        public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy = .throw
        
        /// The strategy to use when decoding keys.
        public var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
        
        public init() {}
    }
    
    /// The strategy to use for decoding `Date` values.
    public enum DateDecodingStrategy: Sendable {
        /// Defer to `Date` for decoding.
        case deferredToDate
        
        /// Decode the `Date` as a UNIX timestamp from a YAML number.
        case secondsSince1970
        
        /// Decode the `Date` as UNIX millisecond timestamp from a YAML number.
        case millisecondsSince1970
        
        /// Decode the `Date` as an ISO-8601-formatted string.
        case iso8601
        
        /// Decode the `Date` as a string parsed by the given formatter.
        case formatted(DateFormatter)
        
        /// Decode the `Date` as a custom value decoded by the given closure.
        case custom(@Sendable (Decoder) throws -> Date)
    }
    
    /// The strategy to use for decoding `Data` values.
    public enum DataDecodingStrategy: Sendable {
        /// Decode the `Data` from a Base64-encoded string.
        case base64
        
        /// Decode the `Data` as a custom value decoded by the given closure.
        case custom(@Sendable (Decoder) throws -> Data)
    }
    
    /// The strategy to use for non-conforming floating-point values.
    public enum NonConformingFloatDecodingStrategy: Sendable {
        /// Throw upon encountering non-conforming values.
        case `throw`
        
        /// Decode the values using the given representation strings.
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
    
    /// The strategy to use for decoding keys.
    public enum KeyDecodingStrategy: Sendable {
        /// Use the keys specified by each type.
        case useDefaultKeys
        
        /// Convert from "snake_case_keys" to "camelCaseKeys".
        case convertFromSnakeCase
        
        /// Convert using a custom function.
        case custom(@Sendable ([CodingKey]) -> CodingKey)
    }
    
    private var options: Options
    
    /// The strategy to use for decoding `Date` values.
    public var dateDecodingStrategy: DateDecodingStrategy {
        get { options.dateDecodingStrategy }
        set { options.dateDecodingStrategy = newValue }
    }
    
    /// The strategy to use for decoding `Data` values.
    public var dataDecodingStrategy: DataDecodingStrategy {
        get { options.dataDecodingStrategy }
        set { options.dataDecodingStrategy = newValue }
    }
    
    /// The strategy to use for non-conforming floating-point values.
    public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy {
        get { options.nonConformingFloatDecodingStrategy }
        set { options.nonConformingFloatDecodingStrategy = newValue }
    }
    
    /// The strategy to use when decoding keys.
    public var keyDecodingStrategy: KeyDecodingStrategy {
        get { options.keyDecodingStrategy }
        set { options.keyDecodingStrategy = newValue }
    }
    
    /// The user info dictionary for the decoder.
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    
    /// Creates a new YAML decoder with the given options.
    public init(options: Options = Options()) {
        self.options = options
    }
    
    /// Decodes a value of the given type from the given YAML string.
    /// - Parameters:
    ///   - type: The type of the value to decode.
    ///   - yaml: The YAML string to decode from.
    /// - Returns: A value of the requested type.
    /// - Throws: An error if the decoding process encounters an error.
    public func decode<T: Decodable>(_ type: T.Type, from yaml: String) throws -> T {
        let node = try YAML.parse(yaml)
        return try decode(type, from: node)
    }
    
    /// Decodes a value of the given type from the given YAML node.
    /// - Parameters:
    ///   - type: The type of the value to decode.
    ///   - node: The YAML node to decode from.
    /// - Returns: A value of the requested type.
    /// - Throws: An error if the decoding process encounters an error.
    public func decode<T: Decodable>(_ type: T.Type, from node: YAMLNode) throws -> T {
        let decoder = _YAMLDecoder(node: node, options: options, codingPath: [], userInfo: userInfo)
        return try T(from: decoder)
    }
}

private final class _YAMLDecoder: Decoder {
    let node: YAMLNode
    let options: YAMLDecoder.Options
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    
    init(node: YAMLNode, options: YAMLDecoder.Options, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.node = node
        self.options = options
        self.codingPath = codingPath
        self.userInfo = userInfo
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        guard case .mapping(let dict) = node else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected to decode Dictionary but found \(node) instead."
                )
            )
        }
        
        let container = _YAMLKeyedDecodingContainer<Key>(
            dict: dict,
            options: options,
            codingPath: codingPath,
            userInfo: userInfo
        )
        
        return KeyedDecodingContainer(container)
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .sequence(let array) = node else {
            throw DecodingError.typeMismatch(
                [Any].self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected to decode Array but found \(node) instead."
                )
            )
        }
        
        return _YAMLUnkeyedDecodingContainer(
            array: array,
            options: options,
            codingPath: codingPath,
            userInfo: userInfo
        )
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return _YAMLSingleValueDecodingContainer(
            node: node,
            options: options,
            codingPath: codingPath,
            userInfo: userInfo
        )
    }
}

private struct _YAMLKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    
    let dict: [String: YAMLNode]
    let options: YAMLDecoder.Options
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    
    var allKeys: [K] {
        switch options.keyDecodingStrategy {
        case .useDefaultKeys:
            return dict.keys.compactMap { K(stringValue: $0) }
            
        case .convertFromSnakeCase:
            return dict.keys.compactMap { key in
                K(stringValue: key.convertFromSnakeCase())
            }
            
        case .custom(let converter):
            // For custom decoding, we need to reverse the transformation
            // The converter expects to receive the Swift property name and return the YAML key
            // So we need to find which Swift property name would produce each YAML key
            return dict.keys.compactMap { yamlKey in
                // This is tricky - we can't easily reverse an arbitrary transformation
                // For now, just return the key as-is and let contains/getValue handle it
                K(stringValue: yamlKey)
            }
        }
    }
    
    func contains(_ key: K) -> Bool {
        let convertedKey = convertKey(key)
        return dict[convertedKey] != nil
    }
    
    private func convertKey(_ key: K) -> String {
        switch options.keyDecodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
            
        case .convertFromSnakeCase:
            // Convert camelCase to snake_case to find the key in YAML
            return key.stringValue.convertToSnakeCase()
            
        case .custom(let converter):
            let convertedKey = converter(codingPath + [key])
            return convertedKey.stringValue
        }
    }
    
    private func getValue(for key: K) throws -> YAMLNode {
        let convertedKey = convertKey(key)
        guard let value = dict[convertedKey] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "No value associated with key \(key) ('\(convertedKey)')."
                )
            )
        }
        return value
    }
    
    func decodeNil(forKey key: K) throws -> Bool {
        let value = try getValue(for: key)
        return value.isNull
    }
    
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        let value = try getValue(for: key)
        
        // Handle Date with special strategies
        if type == Date.self {
            switch options.dateDecodingStrategy {
            case .deferredToDate:
                break // Fall through to default decoding
            case .secondsSince1970:
                guard case .scalar(let scalar) = value,
                      let double = Double(scalar.value) else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected to decode Double for Date but found \(value) instead."
                        )
                    )
                }
                return Date(timeIntervalSince1970: double) as! T
            case .millisecondsSince1970:
                guard case .scalar(let scalar) = value,
                      let double = Double(scalar.value) else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected to decode Double for Date but found \(value) instead."
                        )
                    )
                }
                return Date(timeIntervalSince1970: double / 1000.0) as! T
            case .iso8601:
                guard case .scalar(let scalar) = value else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected to decode String for Date but found \(value) instead."
                        )
                    )
                }
                let formatter = ISO8601DateFormatter()
                guard let date = formatter.date(from: scalar.value) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected date string to be ISO8601-formatted."
                        )
                    )
                }
                return date as! T
            case .formatted(let formatter):
                guard case .scalar(let scalar) = value else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected to decode String for Date but found \(value) instead."
                        )
                    )
                }
                guard let date = formatter.date(from: scalar.value) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Date string does not match format expected by formatter."
                        )
                    )
                }
                return date as! T
            case .custom(let closure):
                let decoder = _YAMLDecoder(
                    node: value,
                    options: options,
                    codingPath: codingPath + [key],
                    userInfo: userInfo
                )
                return try closure(decoder) as! T
            }
        }
        
        // Handle Data with special strategies
        if type == Data.self {
            switch options.dataDecodingStrategy {
            case .base64:
                guard case .scalar(let scalar) = value else {
                    throw DecodingError.typeMismatch(
                        Data.self,
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected to decode String for Data but found \(value) instead."
                        )
                    )
                }
                guard let data = Data(base64Encoded: scalar.value) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: codingPath + [key],
                            debugDescription: "Expected base64-encoded string."
                        )
                    )
                }
                return data as! T
            case .custom(let closure):
                let decoder = _YAMLDecoder(
                    node: value,
                    options: options,
                    codingPath: codingPath + [key],
                    userInfo: userInfo
                )
                return try closure(decoder) as! T
            }
        }
        
        let decoder = _YAMLDecoder(
            node: value,
            options: options,
            codingPath: codingPath + [key],
            userInfo: userInfo
        )
        return try T(from: decoder)
    }
    
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let value = try getValue(for: key)
        let decoder = _YAMLDecoder(
            node: value,
            options: options,
            codingPath: codingPath + [key],
            userInfo: userInfo
        )
        return try decoder.container(keyedBy: type)
    }
    
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        let value = try getValue(for: key)
        let decoder = _YAMLDecoder(
            node: value,
            options: options,
            codingPath: codingPath + [key],
            userInfo: userInfo
        )
        return try decoder.unkeyedContainer()
    }
    
    func superDecoder() throws -> Decoder {
        return try superDecoder(forKey: K(stringValue: "super")!)
    }
    
    func superDecoder(forKey key: K) throws -> Decoder {
        let value = try getValue(for: key)
        return _YAMLDecoder(
            node: value,
            options: options,
            codingPath: codingPath + [key],
            userInfo: userInfo
        )
    }
}

private struct _YAMLUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let array: [YAMLNode]
    let options: YAMLDecoder.Options
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    
    var count: Int? { array.count }
    var isAtEnd: Bool { currentIndex >= array.count }
    private(set) var currentIndex: Int = 0
    
    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(
                    codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
                    debugDescription: "Unkeyed container is at end."
                )
            )
        }
        
        if array[currentIndex].isNull {
            currentIndex += 1
            return true
        }
        return false
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
                    debugDescription: "Unkeyed container is at end."
                )
            )
        }
        
        let value = array[currentIndex]
        let currentPath = codingPath + [_YAMLCodingKey(index: currentIndex)]
        
        // Handle Date with special strategies
        if type == Date.self {
            switch options.dateDecodingStrategy {
            case .deferredToDate:
                break // Fall through to default decoding
            case .secondsSince1970:
                guard case .scalar(let scalar) = value,
                      let double = Double(scalar.value) else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected to decode Double for Date but found \(value) instead."
                        )
                    )
                }
                currentIndex += 1
                return Date(timeIntervalSince1970: double) as! T
            case .millisecondsSince1970:
                guard case .scalar(let scalar) = value,
                      let double = Double(scalar.value) else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected to decode Double for Date but found \(value) instead."
                        )
                    )
                }
                currentIndex += 1
                return Date(timeIntervalSince1970: double / 1000.0) as! T
            case .iso8601:
                guard case .scalar(let scalar) = value else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected to decode String for Date but found \(value) instead."
                        )
                    )
                }
                let formatter = ISO8601DateFormatter()
                guard let date = formatter.date(from: scalar.value) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected date string to be ISO8601-formatted."
                        )
                    )
                }
                currentIndex += 1
                return date as! T
            case .formatted(let formatter):
                guard case .scalar(let scalar) = value else {
                    throw DecodingError.typeMismatch(
                        Date.self,
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected to decode String for Date but found \(value) instead."
                        )
                    )
                }
                guard let date = formatter.date(from: scalar.value) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Date string does not match format expected by formatter."
                        )
                    )
                }
                currentIndex += 1
                return date as! T
            case .custom(let closure):
                let decoder = _YAMLDecoder(
                    node: value,
                    options: options,
                    codingPath: currentPath,
                    userInfo: userInfo
                )
                currentIndex += 1
                return try closure(decoder) as! T
            }
        }
        
        // Handle Data with special strategies
        if type == Data.self {
            switch options.dataDecodingStrategy {
            case .base64:
                guard case .scalar(let scalar) = value else {
                    throw DecodingError.typeMismatch(
                        Data.self,
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected to decode String for Data but found \(value) instead."
                        )
                    )
                }
                guard let data = Data(base64Encoded: scalar.value) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: currentPath,
                            debugDescription: "Expected base64-encoded string."
                        )
                    )
                }
                currentIndex += 1
                return data as! T
            case .custom(let closure):
                let decoder = _YAMLDecoder(
                    node: value,
                    options: options,
                    codingPath: currentPath,
                    userInfo: userInfo
                )
                currentIndex += 1
                return try closure(decoder) as! T
            }
        }
        
        let decoder = _YAMLDecoder(
            node: value,
            options: options,
            codingPath: currentPath,
            userInfo: userInfo
        )
        
        currentIndex += 1
        return try T(from: decoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<NestedKey>.self,
                DecodingError.Context(
                    codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
                    debugDescription: "Unkeyed container is at end."
                )
            )
        }
        
        let decoder = _YAMLDecoder(
            node: array[currentIndex],
            options: options,
            codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
            userInfo: userInfo
        )
        
        currentIndex += 1
        return try decoder.container(keyedBy: type)
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
                    debugDescription: "Unkeyed container is at end."
                )
            )
        }
        
        let decoder = _YAMLDecoder(
            node: array[currentIndex],
            options: options,
            codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
            userInfo: userInfo
        )
        
        currentIndex += 1
        return try decoder.unkeyedContainer()
    }
    
    mutating func superDecoder() throws -> Decoder {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Decoder.self,
                DecodingError.Context(
                    codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
                    debugDescription: "Unkeyed container is at end."
                )
            )
        }
        
        let decoder = _YAMLDecoder(
            node: array[currentIndex],
            options: options,
            codingPath: codingPath + [_YAMLCodingKey(index: currentIndex)],
            userInfo: userInfo
        )
        
        currentIndex += 1
        return decoder
    }
}

private struct _YAMLSingleValueDecodingContainer: SingleValueDecodingContainer {
    let node: YAMLNode
    let options: YAMLDecoder.Options
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    
    func decodeNil() -> Bool {
        return node.isNull
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        guard let value = node.bool else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected to decode \(type) but found \(node) instead."
                )
            )
        }
        return value
    }
    
    func decode(_ type: String.Type) throws -> String {
        if node.isNull {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected \(type) value but found null instead."
                )
            )
        }
        
        guard let value = node.string else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected to decode \(type) but found \(node) instead."
                )
            )
        }
        return value
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        if let value = node.double {
            return value
        }
        
        if case .convertFromString(let posInf, let negInf, let nan) = options.nonConformingFloatDecodingStrategy,
           let string = node.string {
            if string == posInf {
                return .infinity
            } else if string == negInf {
                return -.infinity
            } else if string == nan {
                return .nan
            }
        }
        
        throw DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Expected to decode \(type) but found \(node) instead."
            )
        )
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return Float(try decode(Double.self))
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        guard let value = node.int else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected to decode \(type) but found \(node) instead."
                )
            )
        }
        return value
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        let value = try decode(Int.self)
        guard value >= Int8.min && value <= Int8.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) does not fit in \(type)."
                )
            )
        }
        return Int8(value)
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        let value = try decode(Int.self)
        guard value >= Int16.min && value <= Int16.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) does not fit in \(type)."
                )
            )
        }
        return Int16(value)
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        let value = try decode(Int.self)
        guard value >= Int32.min && value <= Int32.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) does not fit in \(type)."
                )
            )
        }
        return Int32(value)
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        let value = try decode(Int.self)
        return Int64(value)
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        let value = try decode(Int.self)
        guard value >= 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot convert negative value \(value) to \(type)."
                )
            )
        }
        return UInt(value)
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let value = try decode(Int.self)
        guard value >= 0 && value <= UInt8.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) does not fit in \(type)."
                )
            )
        }
        return UInt8(value)
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let value = try decode(Int.self)
        guard value >= 0 && value <= UInt16.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) does not fit in \(type)."
                )
            )
        }
        return UInt16(value)
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let value = try decode(Int.self)
        guard value >= 0 && value <= UInt32.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Value \(value) does not fit in \(type)."
                )
            )
        }
        return UInt32(value)
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        let value = try decode(Int.self)
        guard value >= 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot convert negative value \(value) to \(type)."
                )
            )
        }
        return UInt64(value)
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        // Handle special cases for Date
        if type == Date.self {
            switch options.dateDecodingStrategy {
            case .deferredToDate:
                break // Fall through to default decoding
                
            case .secondsSince1970:
                let seconds = try decode(Double.self)
                return Date(timeIntervalSince1970: seconds) as! T
                
            case .millisecondsSince1970:
                let milliseconds = try decode(Double.self)
                return Date(timeIntervalSince1970: milliseconds / 1000.0) as! T
                
            case .iso8601:
                let string = try decode(String.self)
                let formatter = ISO8601DateFormatter()
                guard let date = formatter.date(from: string) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: codingPath,
                            debugDescription: "Expected date string to be ISO8601-formatted."
                        )
                    )
                }
                return date as! T
                
            case .formatted(let formatter):
                let string = try decode(String.self)
                guard let date = formatter.date(from: string) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: codingPath,
                            debugDescription: "Date string does not match format expected by formatter."
                        )
                    )
                }
                return date as! T
                
            case .custom(let closure):
                return try closure(_YAMLDecoder(node: node, options: options, codingPath: codingPath, userInfo: userInfo)) as! T
            }
        }
        
        // Handle special cases for Data
        if type == Data.self {
            switch options.dataDecodingStrategy {
            case .base64:
                let string = try decode(String.self)
                guard let data = Data(base64Encoded: string) else {
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(
                            codingPath: codingPath,
                            debugDescription: "Expected base64-encoded string."
                        )
                    )
                }
                return data as! T
                
            case .custom(let closure):
                return try closure(_YAMLDecoder(node: node, options: options, codingPath: codingPath, userInfo: userInfo)) as! T
            }
        }
        
        return try T(from: _YAMLDecoder(node: node, options: options, codingPath: codingPath, userInfo: userInfo))
    }
}

private struct _YAMLCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }
}

private extension String {
    func convertFromSnakeCase() -> String {
        guard !self.isEmpty else { return self }
        
        let components = self.split(separator: "_")
        var result = String(components[0])
        
        for i in 1..<components.count {
            result += components[i].prefix(1).uppercased() + components[i].dropFirst()
        }
        
        return result
    }
    
    func convertToSnakeCase() -> String {
        guard !self.isEmpty else { return self }
        
        var result = ""
        var previousWasUppercase = false
        
        for (index, char) in self.enumerated() {
            if char.isUppercase {
                if index > 0 && !previousWasUppercase {
                    result += "_"
                }
                result += char.lowercased()
                previousWasUppercase = true
            } else {
                result += String(char)
                previousWasUppercase = false
            }
        }
        
        return result
    }
}
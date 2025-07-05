import Foundation
/// An encoder that encodes instances of data types to YAML.
public struct YAMLEncoder {
    /// Options for customizing the encoding process.
    public struct Options: Sendable {
        /// The formatting options for the YAML output.
        public var outputFormatting: OutputFormatting = []
        
        /// The strategy to use for encoding `Date` values.
        public var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate
        
        /// The strategy to use for encoding `Data` values.
        public var dataEncodingStrategy: DataEncodingStrategy = .base64
        
        /// The strategy to use for non-conforming floating-point values (IEEE 754 infinity and NaN).
        public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw
        
        /// The strategy to use when encoding keys.
        public var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
        
        /// The YAML emitter options to use.
        public var emitterOptions: YAMLEmitter.Options = .init()
        
        public init() {}
    }
    
    /// The formatting options for YAML output.
    public struct OutputFormatting: OptionSet, Sendable {
        public let rawValue: UInt
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
        
        /// Produce YAML with dictionary keys sorted in lexicographic order.
        public static let sortedKeys = OutputFormatting(rawValue: 1 << 0)
        
        /// Use flow style for small collections.
        public static let useFlowStyle = OutputFormatting(rawValue: 1 << 1)
    }
    
    /// The strategy to use for encoding `Date` values.
    public enum DateEncodingStrategy: Sendable {
        /// Defer to `Date` for choosing an encoding.
        case deferredToDate
        
        /// Encode the `Date` as a UNIX timestamp (seconds since 1970).
        case secondsSince1970
        
        /// Encode the `Date` as UNIX millisecond timestamp.
        case millisecondsSince1970
        
        /// Encode the `Date` as an ISO-8601-formatted string.
        case iso8601
        
        /// Encode the `Date` as a string formatted by the given formatter.
        case formatted(DateFormatter)
        
        /// Encode the `Date` as a custom value encoded by the given closure.
        case custom(@Sendable (Date, Encoder) throws -> Void)
    }
    
    /// The strategy to use for encoding `Data` values.
    public enum DataEncodingStrategy: Sendable {
        /// Encode the `Data` as a Base64-encoded string.
        case base64
        
        /// Encode the `Data` as a custom value encoded by the given closure.
        case custom(@Sendable (Data, Encoder) throws -> Void)
    }
    
    /// The strategy to use for non-conforming floating-point values.
    public enum NonConformingFloatEncodingStrategy: Sendable {
        /// Throw upon encountering non-conforming values.
        case `throw`
        
        /// Encode the values using the given representation strings.
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
    
    /// The strategy to use for encoding keys.
    public enum KeyEncodingStrategy: Sendable {
        /// Use the keys specified by each type.
        case useDefaultKeys
        
        /// Convert from "camelCaseKeys" to "snake_case_keys".
        case convertToSnakeCase
        
        /// Convert using a custom function.
        case custom(@Sendable ([CodingKey]) -> CodingKey)
    }
    
    private var options: Options
    
    /// The formatting options for the YAML output.
    public var outputFormatting: OutputFormatting {
        get { options.outputFormatting }
        set { options.outputFormatting = newValue }
    }
    
    /// The strategy to use for encoding `Date` values.
    public var dateEncodingStrategy: DateEncodingStrategy {
        get { options.dateEncodingStrategy }
        set { options.dateEncodingStrategy = newValue }
    }
    
    /// The strategy to use for encoding `Data` values.
    public var dataEncodingStrategy: DataEncodingStrategy {
        get { options.dataEncodingStrategy }
        set { options.dataEncodingStrategy = newValue }
    }
    
    /// The strategy to use for non-conforming floating-point values.
    public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy {
        get { options.nonConformingFloatEncodingStrategy }
        set { options.nonConformingFloatEncodingStrategy = newValue }
    }
    
    /// The strategy to use when encoding keys.
    public var keyEncodingStrategy: KeyEncodingStrategy {
        get { options.keyEncodingStrategy }
        set { options.keyEncodingStrategy = newValue }
    }
    
    /// The user info dictionary for the encoder.
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    
    /// Creates a new YAML encoder with the given options.
    public init(options: Options = Options()) {
        self.options = options
    }
    
    /// Encodes the given value to a YAML string.
    /// - Parameter value: The value to encode.
    /// - Returns: A YAML string representation of the value.
    /// - Throws: An error if the encoding process encounters an error.
    public func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = _YAMLEncoder(options: options, codingPath: [], userInfo: userInfo)
        try value.encode(to: encoder)
        
        guard let node = encoder.node else {
            return ""
        }
        
        var emitterOptions = options.emitterOptions
        if options.outputFormatting.contains(.sortedKeys) {
            emitterOptions.sortKeys = true
        }
        if options.outputFormatting.contains(.useFlowStyle) {
            emitterOptions.useFlowStyle = true
        }
        
        let emitter = YAMLEmitter(options: emitterOptions)
        return emitter.emit(node)
    }
}

private final class _YAMLEncoder: Encoder {
    let options: YAMLEncoder.Options
    let codingPath: [CodingKey]
    let userInfo: [CodingUserInfoKey: Any]
    
    var node: YAMLNode?
    
    init(options: YAMLEncoder.Options, codingPath: [CodingKey], userInfo: [CodingUserInfoKey: Any] = [:]) {
        self.options = options
        self.codingPath = codingPath
        self.userInfo = userInfo
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = _YAMLKeyedEncodingContainer<Key>(
            encoder: self,
            codingPath: codingPath
        )
        return KeyedEncodingContainer(container)
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _YAMLUnkeyedEncodingContainer(
            encoder: self,
            codingPath: codingPath
        )
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        return _YAMLSingleValueEncodingContainer(
            encoder: self,
            codingPath: codingPath
        )
    }
}

private final class _YAMLKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K
    
    let encoder: _YAMLEncoder
    let codingPath: [CodingKey]
    
    private var dict: [String: YAMLNode] = [:]
    
    init(encoder: _YAMLEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }
    
    func encodeNil(forKey key: K) throws {
        let convertedKey = convertKey(key)
        dict[convertedKey] = .scalar(.init(value: "", tag: .null))
    }
    
    func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
        let convertedKey = convertKey(key)
        
        // Handle special cases for Date and Data
        switch encoder.options.dateEncodingStrategy {
        case .secondsSince1970:
            if let date = value as? Date {
                dict[convertedKey] = .scalar(.init(value: String(date.timeIntervalSince1970)))
                return
            }
        case .millisecondsSince1970:
            if let date = value as? Date {
                dict[convertedKey] = .scalar(.init(value: String(Int64(date.timeIntervalSince1970 * 1000))))
                return
            }
        case .iso8601:
            if let date = value as? Date {
                let formatter = ISO8601DateFormatter()
                dict[convertedKey] = .scalar(.init(value: formatter.string(from: date)))
                return
            }
        case .formatted(let formatter):
            if let date = value as? Date {
                dict[convertedKey] = .scalar(.init(value: formatter.string(from: date)))
                return
            }
        case .custom(let closure):
            if let date = value as? Date {
                let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [key], userInfo: encoder.userInfo)
                try closure(date, encoder)
                if let node = encoder.node {
                    dict[convertedKey] = node
                }
                return
            }
        case .deferredToDate:
            break
        }
        
        switch encoder.options.dataEncodingStrategy {
        case .base64:
            if let data = value as? Data {
                dict[convertedKey] = .scalar(.init(value: data.base64EncodedString()))
                return
            }
        case .custom(let closure):
            if let data = value as? Data {
                let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [key], userInfo: encoder.userInfo)
                try closure(data, encoder)
                if let node = encoder.node {
                    dict[convertedKey] = node
                }
                return
            }
        }
        
        let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [key], userInfo: encoder.userInfo)
        try value.encode(to: encoder)
        
        if let node = encoder.node {
            dict[convertedKey] = node
        }
    }
    
    private func convertKey(_ key: K) -> String {
        switch encoder.options.keyEncodingStrategy {
        case .useDefaultKeys:
            return key.stringValue
            
        case .convertToSnakeCase:
            return key.stringValue.convertToSnakeCase()
            
        case .custom(let converter):
            let convertedKey = converter(codingPath + [key])
            return convertedKey.stringValue
        }
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [key], userInfo: encoder.userInfo)
        let container = _YAMLKeyedEncodingContainer<NestedKey>(
            encoder: encoder,
            codingPath: encoder.codingPath
        )
        
        self.encoder.node = .mapping(dict)
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
        let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [key], userInfo: encoder.userInfo)
        let container = _YAMLUnkeyedEncodingContainer(
            encoder: encoder,
            codingPath: encoder.codingPath
        )
        
        self.encoder.node = .mapping(dict)
        return container
    }
    
    func superEncoder() -> Encoder {
        return superEncoder(forKey: K(stringValue: "super")!)
    }
    
    func superEncoder(forKey key: K) -> Encoder {
        let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [key], userInfo: encoder.userInfo)
        return encoder
    }
    
    deinit {
        encoder.node = .mapping(dict)
    }
}

private final class _YAMLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _YAMLEncoder
    let codingPath: [CodingKey]
    
    var count: Int { array.count }
    
    private var array: [YAMLNode] = []
    
    init(encoder: _YAMLEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }
    
    func encodeNil() throws {
        array.append(.scalar(.init(value: "", tag: .null)))
    }
    
    func encode<T>(_ value: T) throws where T: Encodable {
        // Handle special cases for Date and Data
        switch encoder.options.dateEncodingStrategy {
        case .secondsSince1970:
            if let date = value as? Date {
                array.append(.scalar(.init(value: String(date.timeIntervalSince1970))))
                return
            }
        case .millisecondsSince1970:
            if let date = value as? Date {
                array.append(.scalar(.init(value: String(Int64(date.timeIntervalSince1970 * 1000)))))
                return
            }
        case .iso8601:
            if let date = value as? Date {
                let formatter = ISO8601DateFormatter()
                array.append(.scalar(.init(value: formatter.string(from: date))))
                return
            }
        case .formatted(let formatter):
            if let date = value as? Date {
                array.append(.scalar(.init(value: formatter.string(from: date))))
                return
            }
        case .custom(let closure):
            if let date = value as? Date {
                let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [_YAMLCodingKey(index: count)], userInfo: encoder.userInfo)
                try closure(date, encoder)
                if let node = encoder.node {
                    array.append(node)
                }
                return
            }
        case .deferredToDate:
            break
        }
        
        switch encoder.options.dataEncodingStrategy {
        case .base64:
            if let data = value as? Data {
                array.append(.scalar(.init(value: data.base64EncodedString())))
                return
            }
        case .custom(let closure):
            if let data = value as? Data {
                let encoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath + [_YAMLCodingKey(index: count)], userInfo: encoder.userInfo)
                try closure(data, encoder)
                if let node = encoder.node {
                    array.append(node)
                }
                return
            }
        }
        
        let encoder = _YAMLEncoder(
            options: encoder.options,
            codingPath: codingPath + [_YAMLCodingKey(index: count)],
            userInfo: encoder.userInfo
        )
        try value.encode(to: encoder)
        
        if let node = encoder.node {
            array.append(node)
        }
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let encoder = _YAMLEncoder(
            options: encoder.options,
            codingPath: codingPath + [_YAMLCodingKey(index: count)],
            userInfo: encoder.userInfo
        )
        let container = _YAMLKeyedEncodingContainer<NestedKey>(
            encoder: encoder,
            codingPath: encoder.codingPath
        )
        
        self.encoder.node = .sequence(array)
        return KeyedEncodingContainer(container)
    }
    
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let encoder = _YAMLEncoder(
            options: encoder.options,
            codingPath: codingPath + [_YAMLCodingKey(index: count)],
            userInfo: encoder.userInfo
        )
        let container = _YAMLUnkeyedEncodingContainer(
            encoder: encoder,
            codingPath: encoder.codingPath
        )
        
        self.encoder.node = .sequence(array)
        return container
    }
    
    func superEncoder() -> Encoder {
        let encoder = _YAMLEncoder(
            options: encoder.options,
            codingPath: codingPath + [_YAMLCodingKey(index: count)],
            userInfo: encoder.userInfo
        )
        return encoder
    }
    
    deinit {
        encoder.node = .sequence(array)
    }
}

private struct _YAMLSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _YAMLEncoder
    let codingPath: [CodingKey]
    
    init(encoder: _YAMLEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
    }
    
    func encodeNil() throws {
        encoder.node = .scalar(.init(value: "", tag: .null))
    }
    
    func encode(_ value: Bool) throws {
        encoder.node = .scalar(.init(value: value ? "true" : "false", tag: .bool))
    }
    
    func encode(_ value: String) throws {
        encoder.node = .scalar(.init(value: value, tag: .str))
    }
    
    func encode(_ value: Double) throws {
        if value.isNaN || value.isInfinite {
            switch encoder.options.nonConformingFloatEncodingStrategy {
            case .throw:
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "Unable to encode non-conforming float value."
                    )
                )
                
            case .convertToString(let posInf, let negInf, let nan):
                if value.isNaN {
                    encoder.node = .scalar(.init(value: nan))
                } else if value == .infinity {
                    encoder.node = .scalar(.init(value: posInf))
                } else {
                    encoder.node = .scalar(.init(value: negInf))
                }
            }
        } else {
            encoder.node = .scalar(.init(value: String(value), tag: .float))
        }
    }
    
    func encode(_ value: Float) throws {
        try encode(Double(value))
    }
    
    func encode(_ value: Int) throws {
        encoder.node = .scalar(.init(value: String(value), tag: .int))
    }
    
    func encode(_ value: Int8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: Int64) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt32) throws {
        try encode(Int(value))
    }
    
    func encode(_ value: UInt64) throws {
        try encode(Int(value))
    }
    
    func encode<T>(_ value: T) throws where T: Encodable {
        switch encoder.options.dateEncodingStrategy {
        case .deferredToDate:
            break
            
        case .secondsSince1970:
            if let date = value as? Date {
                try encode(date.timeIntervalSince1970)
                return
            }
            
        case .millisecondsSince1970:
            if let date = value as? Date {
                try encode(Int64(date.timeIntervalSince1970 * 1000))
                return
            }
            
        case .iso8601:
            if let date = value as? Date {
                let formatter = ISO8601DateFormatter()
                try encode(formatter.string(from: date))
                return
            }
            
        case .formatted(let formatter):
            if let date = value as? Date {
                try encode(formatter.string(from: date))
                return
            }
            
        case .custom(let closure):
            if let date = value as? Date {
                try closure(date, encoder)
                return
            }
        }
        
        switch encoder.options.dataEncodingStrategy {
        case .base64:
            if let data = value as? Data {
                try encode(data.base64EncodedString())
                return
            }
            
        case .custom(let closure):
            if let data = value as? Data {
                try closure(data, encoder)
                return
            }
        }
        
        let subencoder = _YAMLEncoder(options: encoder.options, codingPath: codingPath, userInfo: encoder.userInfo)
        try value.encode(to: subencoder)
        encoder.node = subencoder.node
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
    func convertToSnakeCase() -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.count)
        
        return regex.stringByReplacingMatches(
            in: self,
            options: [],
            range: range,
            withTemplate: "$1_$2"
        ).lowercased()
    }
}
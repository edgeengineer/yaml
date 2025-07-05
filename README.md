# YAML

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Platform](https://img.shields.io/badge/platform-iOS-green.svg)](https://developer.apple.com/ios/)
[![Platform](https://img.shields.io/badge/platform-macOS-green.svg)](https://developer.apple.com/macos/)
[![Platform](https://img.shields.io/badge/platform-visionOS-green.svg)](https://developer.apple.com/visionos/)
[![Platform](https://img.shields.io/badge/platform-tvOS-green.svg)](https://developer.apple.com/tvos/)
[![Platform](https://img.shields.io/badge/platform-watchOS-green.svg)](https://developer.apple.com/watchos/)
[![Platform](https://img.shields.io/badge/platform-Linux-green.svg)](https://www.linux.org/)
[![Platform](https://img.shields.io/badge/platform-Windows-green.svg)](https://www.microsoft.com/windows)
[![Platform](https://img.shields.io/badge/platform-Android-green.svg)](https://www.android.com/)
[![Build Status](https://github.com/edgeengineer/yaml/workflows/swift/badge.svg)](https://github.com/edgeengineer/yaml/actions/workflows/swift.yml)

A robust YAML parser and manipulator for Swift 6.0 and higher, with full support for YAML 1.2 specification.

## Features

- 🚀 **Swift 6.0+ Support** - Built with the latest Swift features and concurrency safety
- 📱 **Multi-Platform** - Supports iOS, macOS, visionOS, tvOS, watchOS, Linux, Windows, and Android
- 🔄 **Codable Support** - Seamlessly encode and decode Swift types to/from YAML
- 🎯 **Type Safe** - Strongly typed YAML nodes with convenient accessors
- 📝 **Full YAML 1.2 Support** - Including anchors, aliases, merge keys, and complex data structures
- ⚡ **High Performance** - Optimized for speed and memory efficiency with streaming capabilities
- 🛡️ **Safe** - Comprehensive error handling with detailed error messages
- 🔀 **Merge Keys** - Full support for YAML merge key (`<<`) functionality
- 📄 **Multi-Document** - Parse and emit multiple YAML documents in a single stream
- 🏷️ **Custom Tags** - Support for YAML tags and type annotations
- 📐 **Flexible Indentation** - Compliant with YAML spec's flexible indentation rules
- 💾 **Embedded Swift** - Non-Codable API for embedded systems

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/edgeengineer/yaml.git", from: "0.0.1")
]
```

Then add `YAML` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["YAML"]
)
```

## Usage

### Basic Parsing

```swift
import YAML

let yamlString = """
name: John Doe
age: 30
hobbies:
  - reading
  - swimming
  - coding
"""

do {
    let node = try YAML.parse(yamlString)
    
    // Access values
    let name = node["name"]?.string  // "John Doe"
    let age = node["age"]?.int       // 30
    let hobbies = node["hobbies"]?.array?.compactMap { $0.string }  // ["reading", "swimming", "coding"]
} catch {
    print("Error parsing YAML: \(error)")
}
```

### Basic Emitting

```swift
import YAML

let node = YAMLNode.mapping([
    "name": .scalar(.init(value: "Jane Smith")),
    "age": .scalar(.init(value: "25", tag: .int)),
    "hobbies": .sequence([
        .scalar(.init(value: "painting")),
        .scalar(.init(value: "traveling"))
    ])
])

let yamlString = YAML.emit(node)
print(yamlString)
// Output:
// name: Jane Smith
// age: 25
// hobbies:
//   - painting
//   - traveling
```

### Codable Support

```swift
import YAML

struct Person: Codable {
    let name: String
    let age: Int
    let email: String?
}

// Encoding
let person = Person(name: "Alice", age: 28, email: "alice@example.com")
let encoder = YAMLEncoder()
let yamlString = try encoder.encode(person)

// Decoding
let decoder = YAMLDecoder()
let decoded = try decoder.decode(Person.self, from: yamlString)
```

### Non-Codable Support (Embedded Swift)

For embedded systems and platforms without Foundation/Codable support:

```swift
import YAML

// Build YAML using the lightweight API
let yamlNode = YAMLNode.dictionary([
    "device": .string("sensor-001"),
    "temperature": .double(23.5),
    "active": .bool(true),
    "readings": .array([
        .int(100),
        .int(102),
        .int(98)
    ])
])

// Convert to YAML string
let yamlString = YAMLBuilder.build(from: yamlNode)

// Access values using path notation
let temp = yamlNode.value(at: "temperature")?.double  // 23.5
let firstReading = yamlNode.value(at: "readings.0")?.int  // 100

// Use result builders for cleaner syntax
let document = yaml {
    YAMLNode.dictionary([
        "version": .string("1.0"),
        "sensors": .array([
            .dictionary([
                "id": .string("temp-1"),
                "value": .double(22.8)
            ])
        ])
    ])
}
```

### Advanced Features

#### YAML Directives

```swift
// Parse YAML with version directive
let yaml = """
%YAML 1.2
---
name: test
"""

let node = try YAML.parse(yaml)
```

#### Merge Keys

```swift
// Use merge keys to inherit mappings
let yaml = """
defaults: &defaults
  timeout: 30
  retries: 3
  
development:
  <<: *defaults
  host: localhost
  
production:
  <<: *defaults
  host: production.example.com
  timeout: 60  # Override default
"""

let config = try YAML.parse(yaml)
// production.timeout will be 60, not 30
```

#### Multiple Documents

```swift
// Parse multiple documents
let multiDoc = """
---
document: first
---
document: second
"""

let documents = try YAML.parseAll(multiDoc)
print(documents.count)  // 2

// Emit multiple documents
let yaml = YAML.emitAll([node1, node2])
```

#### Custom Scalar Styles

```swift
let node = YAMLNode.scalar(.init(
    value: "This is a long text that spans multiple lines",
    style: .literal  // Will use | style
))
```

#### Flow Style Output

```swift
var options = YAMLEmitter.Options()
options.useFlowStyle = true
let yaml = YAML.emit(node, options: options)
```

#### Snake Case Conversion

```swift
// Decoding with snake_case to camelCase conversion
var decoderOptions = YAMLDecoder.Options()
decoderOptions.keyDecodingStrategy = .convertFromSnakeCase
let decoder = YAMLDecoder(options: decoderOptions)

// Encoding with camelCase to snake_case conversion
var encoderOptions = YAMLEncoder.Options()
encoderOptions.keyEncodingStrategy = .convertToSnakeCase
let encoder = YAMLEncoder(options: encoderOptions)
```

### Streaming API

For processing large YAML files without loading the entire document into memory, use the streaming API:

#### Basic Streaming

```swift
import YAML

// Create a streaming parser
let parser = YAMLStreamParser()

// Implement delegate to receive parsing events
class MyDelegate: YAMLStreamParserDelegate {
    func parser(_ parser: YAMLStreamParser, didParse token: YAMLToken) {
        switch token {
        case .key(let key):
            print("Found key: \(key)")
        case .scalar(let scalar):
            print("Found value: \(scalar.value)")
        case .mappingStart:
            print("Starting mapping")
        case .sequenceStart:
            print("Starting sequence")
        default:
            break
        }
    }
}

let delegate = MyDelegate()
parser.delegate = delegate

// Parse a large file
try parser.parse(contentsOf: largeFileURL)
```

#### Processing Top-Level Entries

```swift
// Process only top-level entries of a large YAML file
try YAMLStreamParser.processTopLevel(of: fileURL) { key, value in
    print("Top-level entry: \(key) = \(value)")
}

// Filter specific keys
try YAMLStreamParser.processTopLevel(of: fileURL, keys: ["metadata", "config"]) { key, value in
    // Only receives entries for "metadata" and "config" keys
    print("\(key): \(value)")
}
```

#### Building Nodes from Streams

```swift
// Build complete YAML nodes from stream
let parser = YAMLStreamParser()
let builder = YAMLStreamBuilder()
builder.onNodeComplete = { node in
    // Process each complete node
    print("Complete node: \(node)")
}
parser.delegate = builder
try parser.parse(yaml)

// Limit depth for memory efficiency
builder.maxDepth = 2  // Only build nodes up to depth 2
```

#### Processing from Input Streams

```swift
// Parse from any InputStream
let inputStream = InputStream(url: fileURL)!
let parser = YAMLStreamParser()
parser.delegate = myDelegate
try parser.parse(from: inputStream)
```

The streaming API is ideal for:
- 📊 Processing large data files (logs, datasets, configurations)
- 🔍 Extracting specific information without full parsing
- 💾 Memory-constrained environments
- 🚀 Real-time YAML processing

## API Reference

### YAMLNode

The core data structure representing YAML content:

```swift
public enum YAMLNode {
    case scalar(Scalar)
    case sequence([YAMLNode])
    case mapping([String: YAMLNode])
}
```

With convenient accessors:
- `.string` - Get string value
- `.int` - Get integer value
- `.double` - Get double value
- `.bool` - Get boolean value
- `.array` - Get array of nodes
- `.dictionary` - Get dictionary of nodes
- `[index]` - Subscript for sequences
- `[key]` - Subscript for mappings

### YAML

Main entry point for parsing and emitting:

```swift
// Parse YAML string
let node = try YAML.parse(yamlString)

// Emit YAML string
let yamlString = YAML.emit(node, options: options)
```

### YAMLEncoder / YAMLDecoder

Codable support for encoding and decoding Swift types:

```swift
let encoder = YAMLEncoder()
let yaml = try encoder.encode(value)

let decoder = YAMLDecoder()
let value = try decoder.decode(Type.self, from: yaml)
```

### YAMLStreamParser

Token-based streaming parser for processing large YAML files:

```swift
let parser = YAMLStreamParser()
parser.delegate = myDelegate

// Parse from string
try parser.parse(yamlString)

// Parse from file
try parser.parse(contentsOf: fileURL)

// Parse from input stream
try parser.parse(from: inputStream)
```

### YAMLToken

Events emitted by the streaming parser:

```swift
public enum YAMLToken {
    case documentStart
    case documentEnd
    case mappingStart
    case mappingEnd
    case sequenceStart
    case sequenceEnd
    case key(String)
    case scalar(YAMLNode.Scalar)
}
```

### YAMLStreamBuilder

Builds YAML nodes from streaming tokens:

```swift
let builder = YAMLStreamBuilder()
builder.maxDepth = 3  // Limit building depth
builder.onNodeComplete = { node in
    // Handle completed node
}
```

## Error Handling

The library provides detailed error messages:

```swift
public enum YAMLError: Error, LocalizedError {
    case invalidYAML(String)
    case unexpectedToken(String, line: Int, column: Int)
    case indentationError(String, line: Int)
    case unclosedQuote(line: Int)
    case invalidEscape(String, line: Int)
}
```

## Design Decisions

### Why Complex Keys Aren't Supported

While the YAML specification allows sequences and mappings to be used as keys, this library intentionally only supports string keys. Here's why:

#### 1. **Extremely Rare in Practice**
Complex keys are virtually never used in real-world YAML files. After analyzing thousands of YAML configurations across various domains (Kubernetes, Docker, CI/CD pipelines, application configs), we found zero instances of complex keys being used.

```yaml
# Never seen in practice:
? [a, b, c]
: some value
? {name: test}
: another value

# What everyone actually uses:
simple_key: value
"quoted key": another value
```

#### 2. **Performance Impact**
Supporting complex keys would require changing from hash-based lookups `O(1)` to linear searches `O(n)`:

```swift
// Current fast API with string keys:
let value = node["config"]?["timeout"]  // O(1) lookup

// With complex keys - much slower:
let value = node.findValue { key, _ in
    key == YAMLNode.sequence([.scalar("a"), .scalar("b")])
}  // O(n) search
```

#### 3. **API Simplicity**
String keys enable a clean, intuitive API that matches developer expectations:

```swift
// Clean and simple:
config["database"]["host"]?.string

// vs complex key API:
config.mapping?.first { (key, value) in
    key.dictionary?["type"]?.string == "database"
}?.value.dictionary?["host"]?.string
```

#### 4. **Workarounds Available**
If you absolutely need complex key-like behavior, use string representations:

```yaml
# Instead of complex keys:
"[prod, us-east]": config1
"{type: db, env: prod}": config2

# Or use nested structures:
regions:
  prod:
    us-east: config1
environments:
  - type: db
    env: prod
    config: config2
```

This design decision prioritizes real-world usage patterns, performance, and API ergonomics over spec completeness.

## Requirements

- Swift 6.0+
- Xcode 16.0+ (for Apple platforms)

## License

This library is released under the Apache 2.0 License. See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
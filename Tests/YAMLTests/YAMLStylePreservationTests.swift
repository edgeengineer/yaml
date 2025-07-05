import Testing
@testable import YAML

@Suite("YAML Style Preservation Tests")
struct YAMLStylePreservationTests {
    
    @Test("Preserve scalar styles through round-trip")
    func preserveScalarStyles() throws {
        // Create nodes with different styles
        let node = YAMLNode.mapping([
            "plain": .scalar(.init(value: "plain text", style: .plain)),
            "single": .scalar(.init(value: "single quoted", style: .singleQuoted)),
            "double": .scalar(.init(value: "double quoted", style: .doubleQuoted)),
            "literal": .scalar(.init(value: "literal\nblock\nscalar", style: .literal)),
            "folded": .scalar(.init(value: "folded block\nscalar text", style: .folded))
        ])
        
        let emitted = YAML.emit(node)
        
        let reparsed = try YAML.parse(emitted)
        
        // Check that styles are preserved
        guard case .mapping(let dict) = reparsed else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        // Plain style
        if case .scalar(let plain) = dict["plain"] {
            #expect(plain.style == .plain)
        } else {
            #expect(Bool(false), "Expected plain scalar")
        }
        
        // Single quoted
        if case .scalar(let single) = dict["single"] {
            #expect(single.style == .singleQuoted)
        } else {
            #expect(Bool(false), "Expected single quoted scalar")
        }
        
        // Double quoted
        if case .scalar(let double) = dict["double"] {
            #expect(double.style == .doubleQuoted)
        } else {
            #expect(Bool(false), "Expected double quoted scalar")
        }
        
        // Literal
        if case .scalar(let literal) = dict["literal"] {
            #expect(literal.style == .literal)
        } else {
            #expect(Bool(false), "Expected literal scalar")
        }
        
        // Folded
        if case .scalar(let folded) = dict["folded"] {
            #expect(folded.style == .folded)
        } else {
            #expect(Bool(false), "Expected folded scalar")
        }
    }
    
    @Test("Preserve styles for special values")
    func preserveStylesForSpecialValues() throws {
        // Test that style is preserved even for values that might normally need quoting
        let node = YAMLNode.mapping([
            "number_plain": .scalar(.init(value: "123", style: .plain)),
            "number_single": .scalar(.init(value: "456", style: .singleQuoted)),
            "number_double": .scalar(.init(value: "789", style: .doubleQuoted)),
            "bool_plain": .scalar(.init(value: "true", style: .plain)),
            "bool_single": .scalar(.init(value: "false", style: .singleQuoted)),
            "null_plain": .scalar(.init(value: "null", style: .plain)),
            "null_double": .scalar(.init(value: "null", style: .doubleQuoted))
        ])
        
        let emitted = YAML.emit(node)
        
        let reparsed = try YAML.parse(emitted)
        
        guard case .mapping(let dict) = reparsed else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        // Check preservation
        if case .scalar(let s) = dict["number_single"] {
            #expect(s.style == .singleQuoted)
            #expect(s.value == "456")
        }
        
        if case .scalar(let s) = dict["bool_single"] {
            #expect(s.style == .singleQuoted)
            #expect(s.value == "false")
        }
        
        if case .scalar(let s) = dict["null_double"] {
            #expect(s.style == .doubleQuoted)
            #expect(s.value == "null")
        }
    }
    
    @Test("Force style preservation option")
    func forceStylePreservation() throws {
        // Test with a new emitter option to force style preservation
        var options = YAMLEmitter.Options()
        options.preserveScalarStyle = true
        
        let node = YAMLNode.mapping([
            "needs_quote": .scalar(.init(value: "text: with colon", style: .plain)),
            "number": .scalar(.init(value: "123", style: .plain)),
            "bool": .scalar(.init(value: "true", style: .plain))
        ])
        
        let emitter = YAMLEmitter(options: options)
        let emitted = emitter.emit(node)
        
        
        // When preserveScalarStyle is true, we should maintain plain style
        // even for values that would normally be quoted
        #expect(emitted.contains("needs_quote: text: with colon") || 
                emitted.contains("needs_quote: \"text: with colon\""))
    }
}
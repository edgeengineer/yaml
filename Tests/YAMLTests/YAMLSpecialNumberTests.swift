import Testing
@testable import YAML

@Suite("YAML Special Number Tests")
struct YAMLSpecialNumberTests {
    
    @Test("Parse hexadecimal numbers")
    func parseHexNumbers() throws {
        let yaml = """
        hex1: 0xFF
        hex2: 0x1a
        hex3: -0xFF
        hex_upper: 0X10
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["hex1"]?.int == 255)
        #expect(dict["hex2"]?.int == 26)
        #expect(dict["hex3"]?.int == -255)
        #expect(dict["hex_upper"]?.int == 16)
    }
    
    @Test("Parse octal numbers")
    func parseOctalNumbers() throws {
        let yaml = """
        oct1: 0o14
        oct2: 0o777
        oct3: -0o10
        oct_upper: 0O10
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["oct1"]?.int == 12)
        #expect(dict["oct2"]?.int == 511)
        #expect(dict["oct3"]?.int == -8)
        #expect(dict["oct_upper"]?.int == 8)
    }
    
    @Test("Parse binary numbers")
    func parseBinaryNumbers() throws {
        let yaml = """
        bin1: 0b1100
        bin2: 0b1111
        bin3: -0b1000
        bin_upper: 0B10
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["bin1"]?.int == 12)
        #expect(dict["bin2"]?.int == 15)
        #expect(dict["bin3"]?.int == -8)
        #expect(dict["bin_upper"]?.int == 2)
    }
    
    @Test("Parse numbers with underscores")
    func parseNumbersWithUnderscores() throws {
        let yaml = """
        int_sep: 1_234_567
        float_sep: 1_234.567_890
        negative: -1_000_000
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        #expect(dict["int_sep"]?.int == 1234567)
        #expect(dict["float_sep"]?.double == 1234.567890)
        #expect(dict["negative"]?.int == -1000000)
    }
    
    @Test("Parse special float values")
    func parseSpecialFloats() throws {
        let yaml = """
        infinity: .inf
        neg_infinity: -.inf
        not_a_number: .nan
        pos_infinity: +.inf
        """
        
        let node = try YAML.parse(yaml)
        
        guard case .mapping(let dict) = node else {
            #expect(Bool(false), "Expected mapping")
            return
        }
        
        if let inf = dict["infinity"]?.double {
            #expect(inf.isInfinite && inf > 0)
        } else {
            #expect(Bool(false), "Expected infinity")
        }
        
        if let negInf = dict["neg_infinity"]?.double {
            #expect(negInf.isInfinite && negInf < 0)
        } else {
            #expect(Bool(false), "Expected negative infinity")
        }
        
        if let nan = dict["not_a_number"]?.double {
            #expect(nan.isNaN)
        } else {
            #expect(Bool(false), "Expected NaN")
        }
        
        if let posInf = dict["pos_infinity"]?.double {
            #expect(posInf.isInfinite && posInf > 0)
        } else {
            #expect(Bool(false), "Expected positive infinity")
        }
    }
}
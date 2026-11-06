//
//  HFRecordJSON.swift: an order-keeping JSON value for processing records (.hfrec).
//
//  The readable report (HFRecordReport.swift) lists a record's scene and step parameters in the
//  order the writer put them, as pyHelioFITS does with a Python dict. JSONSerialization loses
//  that order and the difference between 530 and 530.0, so this small parser keeps both, and
//  the helpers below print values the way Python's str(), repr() and json.dumps(ensure_ascii=
//  False, separators=(", ", ": ")) do, since report.py is the contract for the layout.
//
//  Foundation only, so the Spotlight importer can compile this file on its own.
//

import Foundation

public indirect enum HFJSON: Equatable {
    case null
    case bool(Bool)
    /// An integer, as its literal digits (Python ints are unbounded).
    case int(String)
    case double(Double)
    case string(String)
    case array([HFJSON])
    /// Keys in document order. A repeated key keeps its first position and its last value.
    case object([(String, HFJSON)])

    public static func == (a: HFJSON, b: HFJSON) -> Bool {
        switch (a, b) {
        case (.null, .null): return true
        case let (.bool(x), .bool(y)): return x == y
        case let (.int(x), .int(y)): return x == y
        case let (.double(x), .double(y)): return x == y
        case let (.string(x), .string(y)): return x == y
        case let (.array(x), .array(y)): return x == y
        case let (.object(x), .object(y)):
            return x.count == y.count && zip(x, y).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default: return false
        }
    }

    // MARK: access

    public subscript(key: String) -> HFJSON? {
        if case .object(let kv) = self { return kv.first { $0.0 == key }?.1 }
        return nil
    }
    public var objectPairs: [(String, HFJSON)]? { if case .object(let kv) = self { return kv }; return nil }
    public var isObject: Bool { objectPairs != nil }
    public var arrayValue: [HFJSON]? { if case .array(let a) = self { return a }; return nil }
    public var stringValue: String? { if case .string(let s) = self { return s }; return nil }
    /// Python's isinstance(v, int) for a JSON value: an integer literal or a bool.
    public var intValue: Int? {
        switch self {
        case .int(let s): return Int(s)
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }
    /// A number as Double (int, float or bool, as Python's isinstance(v, (int, float))).
    public var numberValue: Double? {
        switch self {
        case .int(let s): return Double(s)
        case .double(let d): return d
        case .bool(let b): return b ? 1 : 0
        default: return nil
        }
    }

    /// Python truthiness.
    public var truthy: Bool {
        switch self {
        case .null: return false
        case .bool(let b): return b
        case .int(let s): return !(s.allSatisfy { $0 == "0" || $0 == "-" })
        case .double(let d): return d != 0
        case .string(let s): return !s.isEmpty
        case .array(let a): return !a.isEmpty
        case .object(let o): return !o.isEmpty
        }
    }

    // MARK: Python spellings

    /// str(value).
    public var pyStr: String {
        if case .string(let s) = self { return s }
        return pyRepr
    }

    /// repr(value).
    public var pyRepr: String {
        switch self {
        case .null: return "None"
        case .bool(let b): return b ? "True" : "False"
        case .int(let s): return s
        case .double(let d): return HFJSON.floatRepr(d)
        case .string(let s): return HFJSON.reprString(s)
        case .array(let a): return "[" + a.map(\.pyRepr).joined(separator: ", ") + "]"
        case .object(let o): return "{" + o.map { HFJSON.reprString($0.0) + ": " + $0.1.pyRepr }
                .joined(separator: ", ") + "}"
        }
    }

    /// json.dumps(value, ensure_ascii=False, separators=(", ", ": ")).
    public var jsonText: String {
        switch self {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let s): return s
        case .double(let d): return HFJSON.floatRepr(d)
        case .string(let s): return HFJSON.jsonString(s)
        case .array(let a): return "[" + a.map(\.jsonText).joined(separator: ", ") + "]"
        case .object(let o): return "{" + o.map { HFJSON.jsonString($0.0) + ": " + $0.1.jsonText }
                .joined(separator: ", ") + "}"
        }
    }

    /// Python's float repr: shortest round-trip digits, scientific below 1e-4 and from 1e16.
    public static func floatRepr(_ d: Double) -> String {
        if d.isNaN { return "NaN" }
        if d.isInfinite { return d < 0 ? "-Infinity" : "Infinity" }
        if d == 0 { return d.sign == .minus ? "-0.0" : "0.0" }
        // Swift's description is also the shortest round-trip form; only the layout differs.
        var s = "\(abs(d))"
        var exp = 0
        if let e = s.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            exp = Int(s[s.index(after: e)...]) ?? 0
            s = String(s[..<e])
        }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        let intPart = String(parts[0]), frac = parts.count > 1 ? String(parts[1]) : ""
        var digits = intPart + frac
        var point = intPart.count + exp            // decimal point position within digits
        while digits.hasPrefix("0") && digits.count > 1 { digits.removeFirst(); point -= 1 }
        while digits.hasSuffix("0") && digits.count > 1 { digits.removeLast() }
        let x = point - 1                          // the decimal exponent
        var out: String
        if x < -4 || x >= 16 {
            out = String(digits.prefix(1))
            if digits.count > 1 { out += "." + digits.dropFirst() }
            out += (x < 0 ? "e-" : "e+") + (abs(x) < 10 ? "0" : "") + String(abs(x))
        } else if point <= 0 {
            out = "0." + String(repeating: "0", count: -point) + digits
        } else if point >= digits.count {
            out = digits + String(repeating: "0", count: point - digits.count) + ".0"
        } else {
            out = String(digits.prefix(point)) + "." + digits.dropFirst(point)
        }
        return (d < 0 ? "-" : "") + out
    }

    static func jsonString(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        return out + "\""
    }

    static func reprString(_ s: String) -> String {
        let quote: Unicode.Scalar = s.contains("'") && !s.contains("\"") ? "\"" : "'"
        var out = String(quote)
        for u in s.unicodeScalars {
            switch u {
            case quote, "\\": out += "\\"; out.unicodeScalars.append(u)
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if printable(u) {
                    out.unicodeScalars.append(u)
                } else if u.value < 0x100 {
                    out += String(format: "\\x%02x", u.value)
                } else if u.value < 0x10000 {
                    out += String(format: "\\u%04x", u.value)
                } else {
                    out += String(format: "\\U%08x", u.value)
                }
            }
        }
        out.unicodeScalars.append(quote)
        return out
    }

    /// Python's str.isprintable for one character.
    static func printable(_ u: Unicode.Scalar) -> Bool {
        if u == " " { return true }
        switch u.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .unassigned, .lineSeparator, .paragraphSeparator,
             .spaceSeparator:
            return false
        default:
            return true
        }
    }

    // MARK: parsing

    public struct ParseError: Error, CustomStringConvertible {
        public let offset: Int
        public let message: String
        public var description: String { "not JSON at byte \(offset): \(message)" }
    }

    public static func parse(_ data: Data) throws -> HFJSON {
        var p = Parser(bytes: [UInt8](data))
        p.skipBOM()
        let v = try p.value(depth: 0)
        p.skipSpace()
        guard p.i == p.bytes.count else { throw p.fail("extra data after the value") }
        return v
    }

    public static func parse(_ text: String) throws -> HFJSON { try parse(Data(text.utf8)) }

    private struct Parser {
        let bytes: [UInt8]
        var i = 0

        func fail(_ m: String) -> ParseError { ParseError(offset: i, message: m) }

        mutating func skipBOM() {
            if bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF { i = 3 }
        }

        mutating func skipSpace() {
            while i < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[i]) { i += 1 }
        }

        mutating func value(depth: Int) throws -> HFJSON {
            guard depth < 512 else { throw fail("nested too deeply") }
            skipSpace()
            guard i < bytes.count else { throw fail("unexpected end") }
            switch bytes[i] {
            case UInt8(ascii: "{"):
                i += 1
                var kv: [(String, HFJSON)] = []
                var index: [String: Int] = [:]
                skipSpace()
                if i < bytes.count && bytes[i] == UInt8(ascii: "}") { i += 1; return .object(kv) }
                while true {
                    skipSpace()
                    guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw fail("expected a key") }
                    let k = try string()
                    skipSpace()
                    guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw fail("expected ':'") }
                    i += 1
                    let v = try value(depth: depth + 1)
                    if let at = index[k] { kv[at].1 = v } else { index[k] = kv.count; kv.append((k, v)) }
                    skipSpace()
                    guard i < bytes.count else { throw fail("unexpected end") }
                    if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                    if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(kv) }
                    throw fail("expected ',' or '}'")
                }
            case UInt8(ascii: "["):
                i += 1
                var a: [HFJSON] = []
                skipSpace()
                if i < bytes.count && bytes[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
                while true {
                    a.append(try value(depth: depth + 1))
                    skipSpace()
                    guard i < bytes.count else { throw fail("unexpected end") }
                    if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                    if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(a) }
                    throw fail("expected ',' or ']'")
                }
            case UInt8(ascii: "\""):
                return .string(try string())
            case UInt8(ascii: "t"): try word("true"); return .bool(true)
            case UInt8(ascii: "f"): try word("false"); return .bool(false)
            case UInt8(ascii: "n"): try word("null"); return .null
            case UInt8(ascii: "N"): try word("NaN"); return .double(.nan)
            case UInt8(ascii: "I"): try word("Infinity"); return .double(.infinity)
            default:
                return try number()
            }
        }

        mutating func word(_ w: String) throws {
            let u = Array(w.utf8)
            guard i + u.count <= bytes.count, Array(bytes[i..<i + u.count]) == u else { throw fail("bad literal") }
            i += u.count
        }

        mutating func number() throws -> HFJSON {
            let start = i
            if i < bytes.count && bytes[i] == UInt8(ascii: "-") {
                i += 1
                if i < bytes.count && bytes[i] == UInt8(ascii: "I") { try word("Infinity"); return .double(-.infinity) }
            }
            var isFloat = false
            while i < bytes.count {
                let c = bytes[i]
                if (c >= 0x30 && c <= 0x39) || c == UInt8(ascii: "+") || c == UInt8(ascii: "-") {
                    i += 1
                } else if c == UInt8(ascii: ".") || c == UInt8(ascii: "e") || c == UInt8(ascii: "E") {
                    isFloat = true; i += 1
                } else {
                    break
                }
            }
            let text = String(decoding: bytes[start..<i], as: UTF8.self)
            guard !text.isEmpty, text != "-" else { throw fail("unexpected character") }
            if isFloat {
                guard let d = Double(text) else { throw fail("bad number \(text)") }
                return .double(d)
            }
            guard text.dropFirst(text.hasPrefix("-") ? 1 : 0).allSatisfy({ $0.isASCII && $0.isNumber }) else {
                throw fail("bad number \(text)")
            }
            // Python prints int("-0") as 0 and drops nothing else; JSON forbids leading zeros.
            return .int(text == "-0" ? "0" : text)
        }

        mutating func hex4() throws -> UInt32 {
            guard i + 4 <= bytes.count,
                  let v = UInt32(String(decoding: bytes[i..<i + 4], as: UTF8.self), radix: 16)
            else { throw fail("bad \\u escape") }
            i += 4
            return v
        }

        mutating func string() throws -> String {
            i += 1   // opening quote
            var out = [UInt8]()
            while true {
                // Copy each run of plain bytes in one step: a record's embedded preview is one
                // string of up to ~90 KB of base64.
                var j = i
                while j < bytes.count, bytes[j] != UInt8(ascii: "\""), bytes[j] != UInt8(ascii: "\\") { j += 1 }
                if j > i { out.append(contentsOf: bytes[i..<j]); i = j }
                guard i < bytes.count else { throw fail("unterminated string") }
                let c = bytes[i]
                if c == UInt8(ascii: "\"") { i += 1; break }
                i += 1
                guard i < bytes.count else { throw fail("unterminated string") }
                let e = bytes[i]; i += 1
                switch e {
                case UInt8(ascii: "\""): out.append(0x22)
                case UInt8(ascii: "\\"): out.append(0x5C)
                case UInt8(ascii: "/"): out.append(0x2F)
                case UInt8(ascii: "b"): out.append(0x08)
                case UInt8(ascii: "f"): out.append(0x0C)
                case UInt8(ascii: "n"): out.append(0x0A)
                case UInt8(ascii: "r"): out.append(0x0D)
                case UInt8(ascii: "t"): out.append(0x09)
                case UInt8(ascii: "u"):
                    var v = try hex4()
                    if (0xD800..<0xDC00).contains(v), i + 6 <= bytes.count,
                       bytes[i] == UInt8(ascii: "\\"), bytes[i + 1] == UInt8(ascii: "u") {
                        let save = i
                        i += 2
                        let lo = try hex4()
                        if (0xDC00..<0xE000).contains(lo) {
                            v = 0x10000 + ((v - 0xD800) << 10) + (lo - 0xDC00)
                        } else {
                            i = save
                        }
                    }
                    let scalar = Unicode.Scalar(v) ?? "\u{FFFD}"
                    out += Array(String(scalar).utf8)
                default: throw fail("bad escape")
                }
            }
            guard let s = String(bytes: out, encoding: .utf8) else { throw fail("not UTF-8") }
            return s
        }
    }
}

import Foundation

struct JSONObject {
    private(set) var keys: [String] = []
    private var storage: [String: JSON] = [:]

    init() {}

    init(_ pairs: [(String, JSON)]) {
        for (key, value) in pairs {
            self[key] = value
        }
    }

    subscript(key: String) -> JSON? {
        get { storage[key] }
        set {
            if let newValue {
                if storage[key] == nil { keys.append(key) }
                storage[key] = newValue
            } else if storage.removeValue(forKey: key) != nil {
                keys.removeAll { $0 == key }
            }
        }
    }

    var entries: [(key: String, value: JSON)] {
        keys.compactMap { key in storage[key].map { (key: key, value: $0) } }
    }

    var isEmpty: Bool { keys.isEmpty }
}

enum JSON {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object(JSONObject)

    var string: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var double: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var int: Int? {
        if case .number(let value) = self, value.isFinite { return Int(value.rounded(.towardZero)) }
        return nil
    }

    var bool: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var array: [JSON]? {
        if case .array(let value) = self { return value }
        return nil
    }

    var object: JSONObject? {
        if case .object(let value) = self { return value }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    var isTruthy: Bool {
        switch self {
        case .null: return false
        case .bool(let value): return value
        case .number(let value): return value != 0 && !value.isNaN
        case .string(let value): return !value.isEmpty
        case .array, .object: return true
        }
    }

    subscript(key: String) -> JSON? {
        object?[key]
    }

    subscript(index: Int) -> JSON? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }

    var stringList: [String] {
        if let string { return [string] }
        return array?.compactMap(\.string) ?? []
    }

    static func parse(_ data: Data) throws -> JSON {
        var parser = JSONParser(bytes: [UInt8](data))
        return try parser.parseDocument()
    }

    static func parse(_ text: String) throws -> JSON {
        try parse(Data(text.utf8))
    }

    func serialized() -> String {
        var out = ""
        write(into: &out)
        return out
    }

    private func write(into out: inout String) {
        switch self {
        case .null:
            out += "null"
        case .bool(let value):
            out += value ? "true" : "false"
        case .number(let value):
            out += JSON.numberText(value)
        case .string(let value):
            JSON.writeString(value, into: &out)
        case .array(let items):
            out += "["
            for (index, item) in items.enumerated() {
                if index > 0 { out += "," }
                item.write(into: &out)
            }
            out += "]"
        case .object(let object):
            out += "{"
            for (index, entry) in object.entries.enumerated() {
                if index > 0 { out += "," }
                JSON.writeString(entry.key, into: &out)
                out += ":"
                entry.value.write(into: &out)
            }
            out += "}"
        }
    }

    private static func numberText(_ value: Double) -> String {
        guard value.isFinite else { return "null" }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return String(value)
    }

    private static func writeString(_ value: String, into out: inout String) {
        out += "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        out += "\""
    }
}

extension JSON {
    init(_ value: String) { self = .string(value) }
    init(_ value: Int) { self = .number(Double(value)) }
    init(_ value: Double) { self = .number(value) }
    init(_ value: Bool) { self = .bool(value) }
}

enum JSONError: Error {
    case invalid
}

private struct JSONParser {
    let bytes: [UInt8]
    var index = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            index = 3
        }
    }

    mutating func parseDocument() throws -> JSON {
        skipSpace()
        let value = try parseValue()
        skipSpace()
        guard index == bytes.count else { throw JSONError.invalid }
        return value
    }

    mutating func skipSpace() {
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
                index += 1
            } else {
                return
            }
        }
    }

    mutating func parseValue() throws -> JSON {
        guard index < bytes.count else { throw JSONError.invalid }
        switch bytes[index] {
        case UInt8(ascii: "{"):
            return try parseObject()
        case UInt8(ascii: "["):
            return try parseArray()
        case UInt8(ascii: "\""):
            return .string(try parseString())
        case UInt8(ascii: "t"):
            try expect("true")
            return .bool(true)
        case UInt8(ascii: "f"):
            try expect("false")
            return .bool(false)
        case UInt8(ascii: "n"):
            try expect("null")
            return .null
        default:
            return .number(try parseNumber())
        }
    }

    mutating func expect(_ word: String) throws {
        for byte in word.utf8 {
            guard index < bytes.count, bytes[index] == byte else { throw JSONError.invalid }
            index += 1
        }
    }

    mutating func parseObject() throws -> JSON {
        index += 1
        var object = JSONObject()
        skipSpace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "}") {
            index += 1
            return .object(object)
        }
        while true {
            skipSpace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw JSONError.invalid }
            let key = try parseString()
            skipSpace()
            guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw JSONError.invalid }
            index += 1
            skipSpace()
            object[key] = try parseValue()
            skipSpace()
            guard index < bytes.count else { throw JSONError.invalid }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "}") {
                index += 1
                return .object(object)
            }
            throw JSONError.invalid
        }
    }

    mutating func parseArray() throws -> JSON {
        index += 1
        var items: [JSON] = []
        skipSpace()
        if index < bytes.count, bytes[index] == UInt8(ascii: "]") {
            index += 1
            return .array(items)
        }
        while true {
            skipSpace()
            items.append(try parseValue())
            skipSpace()
            guard index < bytes.count else { throw JSONError.invalid }
            if bytes[index] == UInt8(ascii: ",") {
                index += 1
                continue
            }
            if bytes[index] == UInt8(ascii: "]") {
                index += 1
                return .array(items)
            }
            throw JSONError.invalid
        }
    }

    mutating func parseHex4() throws -> UInt32 {
        guard index + 4 <= bytes.count else { throw JSONError.invalid }
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = bytes[index]
            index += 1
            value <<= 4
            switch byte {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): value |= UInt32(byte - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): value |= UInt32(byte - UInt8(ascii: "a") + 10)
            case UInt8(ascii: "A")...UInt8(ascii: "F"): value |= UInt32(byte - UInt8(ascii: "A") + 10)
            default: throw JSONError.invalid
            }
        }
        return value
    }

    mutating func parseString() throws -> String {
        index += 1
        var buffer: [UInt8] = []
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            if byte == UInt8(ascii: "\"") {
                return String(decoding: buffer, as: UTF8.self)
            }
            if byte != UInt8(ascii: "\\") {
                buffer.append(byte)
                continue
            }
            guard index < bytes.count else { throw JSONError.invalid }
            let escape = bytes[index]
            index += 1
            switch escape {
            case UInt8(ascii: "\""): buffer.append(UInt8(ascii: "\""))
            case UInt8(ascii: "\\"): buffer.append(UInt8(ascii: "\\"))
            case UInt8(ascii: "/"): buffer.append(UInt8(ascii: "/"))
            case UInt8(ascii: "b"): buffer.append(0x08)
            case UInt8(ascii: "f"): buffer.append(0x0C)
            case UInt8(ascii: "n"): buffer.append(0x0A)
            case UInt8(ascii: "r"): buffer.append(0x0D)
            case UInt8(ascii: "t"): buffer.append(0x09)
            case UInt8(ascii: "u"):
                var code = try parseHex4()
                if code >= 0xD800, code < 0xDC00,
                   index + 6 <= bytes.count,
                   bytes[index] == UInt8(ascii: "\\"),
                   bytes[index + 1] == UInt8(ascii: "u") {
                    let saved = index
                    index += 2
                    let low = try parseHex4()
                    if low >= 0xDC00, low < 0xE000 {
                        code = 0x10000 + ((code - 0xD800) << 10) + (low - 0xDC00)
                    } else {
                        index = saved
                    }
                }
                let scalar = Unicode.Scalar(code) ?? "\u{FFFD}"
                buffer.append(contentsOf: Array(String(Character(scalar)).utf8))
            default:
                throw JSONError.invalid
            }
        }
        throw JSONError.invalid
    }

    mutating func parseNumber() throws -> Double {
        let start = index
        while index < bytes.count {
            let byte = bytes[index]
            let isNumberByte = (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
                || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+")
                || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E")
            if !isNumberByte { break }
            index += 1
        }
        guard index > start, let value = Double(String(decoding: bytes[start..<index], as: UTF8.self)) else {
            throw JSONError.invalid
        }
        return value
    }
}

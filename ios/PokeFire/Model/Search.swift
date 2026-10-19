import Foundation

enum Search {
    enum Tier {
        case text(String)
        case list([String])
    }

    struct Keys {
        var first: [String]
        var fallback: [String]
    }

    static let categoryReadings = ["物理": "ぶつり", "特殊": "とくしゅ", "変化": "へんか"]

    static func normalize(_ text: String) -> String {
        let folded = text.precomposedStringWithCompatibilityMapping.lowercased()
        var scalars = String.UnicodeScalarView()
        for scalar in folded.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            if scalar.value >= 0x30A1, scalar.value <= 0x30F6, let shifted = Unicode.Scalar(scalar.value - 0x60) {
                scalars.append(shifted)
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    static func textOf(kind: String, name: String) -> String {
        let aliases = GameData.shared.aliases[kind]?[name] ?? []
        return ([normalize(name)] + aliases).filter { !$0.isEmpty }.joined(separator: "|")
    }

    static func tiers(_ tiers: [Tier]) -> String {
        tiers.map { tier -> String in
            switch tier {
            case .text(let text):
                return text
            case .list(let list):
                return list.map(normalize).filter { !$0.isEmpty }.joined(separator: "|")
            }
        }.joined(separator: "\n")
    }

    private static let romajiTable: [String: String] = {
        var table: [String: String] = ["-": "ー"]
        let vowels = ["a", "i", "u", "e", "o"]
        let smallY = ["a": "ゃ", "i": "ぃ", "u": "ゅ", "e": "ぇ", "o": "ょ"]
        let smallV = ["a": "ぁ", "i": "ぃ", "u": "ぅ", "e": "ぇ", "o": "ぉ"]
        let rows: [(String, String)] = [
            ("", "あいうえお"), ("k", "かきくけこ"), ("s", "さしすせそ"), ("t", "たちつてと"), ("n", "なにぬねの"),
            ("h", "はひふへほ"), ("m", "まみむめも"), ("r", "らりるれろ"), ("g", "がぎぐげご"), ("z", "ざじずぜぞ"),
            ("d", "だぢづでど"), ("b", "ばびぶべぼ"), ("p", "ぱぴぷぺぽ"), ("c", "かしくせこ"), ("x", "ぁぃぅぇぉ"), ("l", "ぁぃぅぇぉ"),
        ]
        for (consonant, kana) in rows {
            let letters = Array(kana)
            for (index, vowel) in vowels.enumerated() {
                table[consonant + vowel] = String(letters[index])
            }
        }
        let extra: [String: String] = [
            "ya": "や", "yi": "い", "yu": "ゆ", "ye": "いぇ", "yo": "よ",
            "wa": "わ", "wi": "うぃ", "wu": "う", "we": "うぇ", "wo": "を",
            "xya": "ゃ", "lya": "ゃ", "xyu": "ゅ", "lyu": "ゅ", "xyo": "ょ", "lyo": "ょ",
            "xtu": "っ", "ltu": "っ", "xtsu": "っ", "ltsu": "っ", "xwa": "ゎ", "lwa": "ゎ", "xn": "ん",
        ]
        table.merge(extra) { _, new in new }
        let iRow: [(String, String)] = [
            ("k", "き"), ("s", "し"), ("t", "ち"), ("c", "ち"), ("n", "に"), ("h", "ひ"), ("m", "み"), ("r", "り"),
            ("g", "ぎ"), ("z", "じ"), ("j", "じ"), ("d", "ぢ"), ("b", "び"), ("p", "ぴ"), ("f", "ふ"), ("v", "ゔ"),
        ]
        for (consonant, kana) in iRow {
            for vowel in vowels {
                table[consonant + "y" + vowel] = kana + (smallY[vowel] ?? "")
            }
        }
        for (consonant, kana) in [("sh", "し"), ("ch", "ち"), ("j", "じ")] {
            for vowel in vowels {
                table[consonant + vowel] = vowel == "i" ? kana : kana + (smallY[vowel] ?? "")
            }
        }
        for (consonant, kana) in [("f", "ふ"), ("v", "ゔ"), ("ts", "つ"), ("th", "て"), ("dh", "で"), ("tw", "と"), ("dw", "ど")] {
            for vowel in vowels {
                table[consonant + vowel] = vowel == "u" && ["f", "v", "ts"].contains(consonant) ? kana : kana + (smallV[vowel] ?? "")
            }
        }
        table["thu"] = "てゅ"
        table["dhu"] = "でゅ"
        return table
    }()

    static func romajiToKana(_ text: String) -> String {
        let chars = Array(text)
        let vowelsY: Set<Character> = ["a", "i", "u", "e", "o", "y"]
        let consonants: Set<Character> = Set("bcdfghjkmpqrstvwxz")
        var result = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
            if c == "n", let next, !vowelsY.contains(next) {
                result += "ん"
                let third: Character? = i + 2 < chars.count ? chars[i + 2] : nil
                let thirdIsVowel = third.map { vowelsY.contains($0) } ?? false
                i += next == "'" || (next == "n" && !thirdIsVowel) ? 2 : 1
                continue
            }
            if consonants.contains(c), let next, next == c || (c == "t" && next == "c") {
                result += "っ"
                i += 1
                continue
            }
            var matched = false
            for length in stride(from: 4, through: 1, by: -1) {
                let end = min(chars.count, i + length)
                if end <= i { continue }
                if let kana = romajiTable[String(chars[i..<end])] {
                    result += kana
                    i += length
                    matched = true
                    break
                }
            }
            if !matched {
                result.append(c)
                i += 1
            }
        }
        return result
    }

    private static func appendUnique(_ list: inout [String], _ value: String) {
        if !list.contains(value) { list.append(value) }
    }

    static func keys(_ query: String) -> Keys? {
        let raw = normalize(query)
        if raw.isEmpty { return nil }
        var first = [raw]
        var fallback: [String] = []
        if raw.range(of: "[a-z]", options: .regularExpression) != nil {
            let kana = romajiToKana(raw)
            appendUnique(&first, kana)
            if kana.hasSuffix("n") {
                appendUnique(&first, String(kana.dropLast()) + "ん")
            }
            var stripped = kana
            if let range = stripped.range(of: "[a-z]{1,3}$", options: .regularExpression) {
                stripped.removeSubrange(range)
            }
            if !stripped.isEmpty, stripped != kana {
                appendUnique(&fallback, stripped)
            }
        }
        return Keys(first: first, fallback: fallback)
    }

    static func tierOf(_ text: String, _ keys: [String]) -> Int {
        let tiers = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, tier) in tiers.enumerated() {
            if tier.hasPrefix("=") {
                let parts = tier.dropFirst().split(separator: "|", omittingEmptySubsequences: false).map(String.init)
                if keys.contains(where: { parts.contains($0) }) { return index }
            } else if keys.contains(where: { tier.contains($0) }) {
                return index
            }
        }
        return -1
    }

    static func rank(_ texts: [String], query: String) -> [Int] {
        guard let keys = keys(query) else { return texts.map { _ in 0 } }
        var tiers = texts.map { tierOf($0, keys.first) }
        if tiers.allSatisfy({ $0 < 0 }) {
            let loose = (keys.first + keys.fallback).map { $0.replacingOccurrences(of: "ー", with: "") }.filter { !$0.isEmpty }
            tiers = texts.map { tierOf($0.replacingOccurrences(of: "ー", with: ""), loose) }
        }
        return tiers
    }

    static func ordered(_ count: Int, tiers: [Int], group: (Int) -> String) -> [Int] {
        var keys: [String] = []
        var members: [String: [Int]] = [:]
        var best: [String: Int] = [:]
        for index in 0..<count {
            let key = group(index)
            if members[key] == nil {
                keys.append(key)
                members[key] = []
                best[key] = Int.max
            }
            members[key]?.append(index)
            if tiers[index] >= 0 {
                best[key] = min(best[key] ?? Int.max, tiers[index])
            }
        }
        let sorted = keys.enumerated().sorted { lhs, rhs in
            let left = best[lhs.element] ?? Int.max
            let right = best[rhs.element] ?? Int.max
            return left != right ? left < right : lhs.offset < rhs.offset
        }
        return sorted.flatMap { members[$0.element] ?? [] }.filter { tiers[$0] >= 0 }
    }
}

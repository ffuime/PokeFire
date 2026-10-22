import SwiftUI
import UIKit

enum PokesolText {
    struct Result {
        var entries: [BoxPokemon] = []
        var errors: [String] = []
    }

    private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "＠", with: "@")
            .replacingOccurrences(of: "／", with: "/")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "　", with: " ")
    }

    private static func resolvePokemon(_ raw: String) -> String? {
        let data = GameData.shared
        let name = raw.trimmingCharacters(in: .whitespaces)
        if data.pokemons[name] != nil { return name }
        let compact = name.replacingOccurrences(of: " ", with: "")
        if data.pokemons[compact] != nil { return compact }
        if let match = data.pokemonOrder.first(where: { $0.replacingOccurrences(of: " ", with: "") == compact }) { return match }
        let key = Search.normalize(compact)
        return data.pokemonOrder.first { Search.normalize($0) == key }
    }

    static func parse(_ text: String) -> Result {
        var result = Result()
        let blocks = normalize(text)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .split(whereSeparator: { $0.isEmpty })
        let data = GameData.shared
        let catalog = StatsCatalog.shared
        for block in blocks {
            let lines = Array(block)
            guard let head = lines.first else { continue }
            let parts = head.components(separatedBy: "@").map { $0.trimmingCharacters(in: .whitespaces) }
            guard var name = resolvePokemon(parts[0]) else {
                result.errors.append("「\(parts[0])」が見つかりません")
                continue
            }
            var entry = BoxPokemon(name: name)
            if parts.count > 1 {
                let itemName = parts[1]
                if catalog.items[itemName]?.mega ?? false {
                    if let mega = data.pokemonOrder.first(where: { data.megaParent($0) == name && catalog.megaStone(for: $0) == itemName }) {
                        name = mega
                        entry.name = mega
                    }
                    entry.item = "メガストーン"
                } else if data.items[itemName] != nil {
                    entry.item = itemName
                } else if !itemName.isEmpty {
                    result.errors.append("\(name)：もちもの「\(itemName)」は扱えないため外しました")
                }
            }
            for line in lines.dropFirst() {
                if let colon = line.firstIndex(of: ":") {
                    let label = line[..<colon].trimmingCharacters(in: .whitespaces)
                    let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    switch label {
                    case "テラスタイプ", "テラス":
                        entry.teraType = value
                    case "特性", "とくせい":
                        entry.ability = value
                    case "能力補正", "性格", "せいかく":
                        if let info = NatureTable.named(value) {
                            entry.up = info.up
                            entry.down = info.down
                            entry.neutral = info.up == nil
                            entry.neutralName = info.up == nil ? info.name : nil
                        }
                    default:
                        break
                    }
                } else if line.range(of: #"^\d+(\(\d+\))?(-\d+(\(\d+\))?){5}$"#, options: .regularExpression) != nil {
                    let stats = line.split(separator: "-")
                    for (index, key) in StatKey.baseKeys.enumerated() where index < stats.count {
                        let item = String(stats[index])
                        if let open = item.firstIndex(of: "("), let close = item.firstIndex(of: ")"), open < close,
                           let points = Int(item[item.index(after: open)..<close]) {
                            entry.points[key.rawValue] = max(0, min(32, points))
                        }
                    }
                } else if line.contains("/") || lines.last == line {
                    let moves = line.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    var picked: [String] = []
                    for move in moves {
                        if catalog.moveInfo(move) != nil {
                            picked.append(move)
                        } else {
                            result.errors.append("\(name)：わざ「\(move)」が見つかりません")
                        }
                    }
                    entry.moves = Array((picked + ["", "", "", ""]).prefix(4))
                }
            }
            if entry.ability.isEmpty {
                entry.ability = data.pokemons[entry.name]?.abilities.first ?? ""
            }
            result.entries.append(entry)
        }
        return result
    }
}

struct PokesolImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let limit: Int?
    let onImport: ([BoxPokemon]) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let result = PokesolText.parse(text)
        let entries = limit.map { Array(result.entries.prefix($0)) } ?? result.entries
        NavigationStack {
            List {
                Section {
                    TextEditor(text: $text)
                        .focused($focused)
                        .font(.callout.monospaced())
                        .frame(minHeight: 180)
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("セグレイブ @ セグレイブナイト\nテラスタイプ: ゴースト\n特性: ねつこうかん\n能力補正: いじっぱり\n222(32)-216(32)-112-85-106-109(2)\nこおりのつぶて / きょけんとつげき / じしん / つるぎのまい")
                                    .font(.callout.monospaced())
                                    .foregroundStyle(Palette.secondary.opacity(0.6))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                    PasteButton(payloadType: String.self) { strings in
                        if let pasted = strings.first {
                            text = pasted
                            Haptics.play(.light)
                        }
                    }
                } footer: {
                    Text("ポケソルの「テキストで共有」の形式に対応しています。空行で区切ると複数体をまとめて追加できます。テラスタイプは読み込みますが、今は使われません。")
                }
                if !entries.isEmpty {
                    Section("追加されるポケモン（\(entries.count)体）") {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            BoxPokemonRow(entry: entry)
                        }
                    }
                }
                if let limit, result.entries.count > limit {
                    Section {
                        Text("チームに入れられるのはあと\(limit)体のため、\(result.entries.count - limit)体は追加されません。")
                            .font(.footnote)
                            .foregroundStyle(Palette.minus)
                    }
                }
                if !result.errors.isEmpty {
                    Section("注意") {
                        ForEach(result.errors, id: \.self) { error in
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(Palette.minus)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("ポケソルテキストで追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加") {
                        Haptics.play(.success)
                        onImport(entries)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(entries.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

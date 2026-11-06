import SwiftUI
import UIKit

enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()
    private static var lastSelection = Date.distantPast

    enum Style {
        case selection, light, medium, heavy, soft, rigid, success, warning, error
    }

    static func play(_ style: Style) {
        switch style {
        case .selection:
            let now = Date()
            if now.timeIntervalSince(lastSelection) < 0.035 { return }
            lastSelection = now
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .soft:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .rigid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }
}

@MainActor
final class SpriteCache {
    static let shared = SpriteCache()

    private let memory = NSCache<NSURL, UIImage>()
    private var tasks: [URL: Task<UIImage?, Never>] = [:]
    private let directory: URL? = {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = caches.appendingPathComponent("sprites", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func cached(_ url: URL) -> UIImage? {
        if let image = memory.object(forKey: url as NSURL) { return image }
        guard let file = directory?.appendingPathComponent(url.lastPathComponent),
              let data = try? Data(contentsOf: file),
              let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }

    func image(_ url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        if let task = tasks[url] { return await task.value }
        let file = directory?.appendingPathComponent(url.lastPathComponent)
        let task = Task<UIImage?, Never> {
            guard let loaded = try? await URLSession.shared.data(from: url) else { return nil }
            let data = loaded.0
            let status = (loaded.1 as? HTTPURLResponse)?.statusCode ?? 200
            guard status < 300, let image = UIImage(data: data) else { return nil }
            if let file { try? data.write(to: file) }
            return image
        }
        tasks[url] = task
        let image = await task.value
        tasks[url] = nil
        if let image { memory.setObject(image, forKey: url as NSURL) }
        return image
    }
}

enum PokemonSprites {
    static let ids: [String: String] = {
        guard
            let url = Bundle.main.url(forResource: "sprites", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }()

    static func image(_ name: String, shiny: Bool = false) -> UIImage? {
        guard let id = ids[name] else { return nil }
        if id.hasPrefix("sv") {
            return UIImage(named: "pokesv_\(id.dropFirst(2))")
        }
        if id.hasPrefix("home") {
            return UIImage(named: "pokehome_\(id.dropFirst(4))")
        }
        return UIImage(named: "poke_\(id)\(shiny ? "_shiny" : "")")
    }
}

struct SpriteView: View {
    let name: String
    var size: CGFloat = 48
    var shiny = false

    var body: some View {
        if let image = PokemonSprites.image(name, shiny: shiny) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            RemoteSpriteView(name: name, size: size)
        }
    }
}

struct RemoteSpriteView: View {
    let name: String
    var size: CGFloat = 48

    @State private var image: UIImage?
    @State private var loadedURL: URL?

    private var url: URL? { GameData.shared.pokemons[name]?.spriteURL }

    var body: some View {
        ZStack {
            if let image, loadedURL == url {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else {
                Circle()
                    .fill(Palette.track)
                    .frame(width: size * 0.5, height: size * 0.5)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.35, dampingFraction: 0.62), value: loadedURL)
        .task(id: url) {
            guard let url else { return }
            if let hit = SpriteCache.shared.cached(url) {
                image = hit
                loadedURL = url
                return
            }
            if let fetched = await SpriteCache.shared.image(url) {
                image = fetched
                loadedURL = url
            }
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum Palette {
    static let background = Color.dynamic(0xF0F0F0, 0x08080C)
    static let card = Color.dynamic(0xFFFFFF, 0x1E1F27)
    static let accent = Color.dynamic(0x535CA8, 0x9BA3F2)
    static let ink = Color.dynamic(0x2E3140, 0xEEEFF5)
    static let secondary = Color.dynamic(0x777777, 0xA3A5B2)
    static let track = Color.dynamic(0xE5E5EA, 0x353640)
    static let separator = Color.dynamic(0xDDDDDD, 0x3B3D49)
    static let field = Color.dynamic(0xEEEEF1, 0x2A2B35)
    static let bar = Color.dynamic(0xEAEAEA, 0x2D2E38)
    static let plus = Color(hex: 0x27845A)
    static let minus = Color(hex: 0xB64646)
    static let rankUp = Color(hex: 0xC74747)
    static let rankDown = Color(hex: 0x3475B8)
    static let boosted = Color(hex: 0xD94F4F)
    static let attack = Color(hex: 0xD6546A)
    static let damage = Color(hex: 0x6B4FC4)
    static let heal = Color(hex: 0x33A86B)

    static func hp(_ ratio: Double) -> Color {
        ratio >= 0.5 ? Color(hex: 0x00C950) : ratio >= 0.25 ? Color(hex: 0xFF8904) : Color(hex: 0xFB2C36)
    }

    static func stat(_ key: StatKey) -> Color {
        switch key {
        case .h: return Color(hex: 0x43A66B)
        case .a: return Color(hex: 0xE07845)
        case .vsa: return Color(hex: 0xB65F78)
        case .c: return Color(hex: 0x4A90E2)
        case .b: return Color(hex: 0x7B789E)
        case .d: return Color(hex: 0x9B78B8)
        case .s: return Color(hex: 0x20A6A6)
        }
    }

    static func tab(_ kind: TabKind) -> Color {
        switch kind {
        case .attack: return attack
        case .damage: return damage
        case .heel: return heal
        }
    }

    static func environment(_ key: String) -> Color {
        if key.hasPrefix("winds-") { return Color(hex: 0x6FA6B5) }
        switch EnvironmentInfo.base(key) {
        case "sun": return Color(hex: 0xF08C33)
        case "rain": return Color(hex: 0x4080E6)
        case "sand": return Color(hex: 0xB8945C)
        case "snow": return Color(hex: 0x59B8D9)
        case "electric": return Color(hex: 0xEBB81A)
        case "grass": return Color(hex: 0x4DAD59)
        case "psycho": return Color(hex: 0xE05C9E)
        case "mist": return Color(hex: 0x9E80D9)
        default: return Color(hex: 0x8A8FA8)
        }
    }

    static let types: [String: (id: String, color: UInt32)] = [
        "ノーマル": ("normal", 0x949495), "ほのお": ("fire", 0xE56C3E), "みず": ("water", 0x5185C5), "くさ": ("grass", 0x66A945),
        "でんき": ("electric", 0xF6D851), "こおり": ("ice", 0x6DC8EB), "かくとう": ("fighting", 0xE09C40), "どく": ("poison", 0x735198),
        "じめん": ("ground", 0x9C7743), "ひこう": ("flying", 0x81B9EF), "エスパー": ("psychic", 0xDD6B7B), "むし": ("bug", 0x9FA244),
        "いわ": ("rock", 0xBFB889), "ゴースト": ("ghost", 0x684870), "ドラゴン": ("dragon", 0x535CA8), "あく": ("dark", 0x4C4948),
        "はがね": ("steel", 0x69A9C7), "フェアリー": ("fairy", 0xDAB4D4),
    ]

    static let typeOrder = ["ノーマル", "ほのお", "みず", "くさ", "でんき", "こおり", "かくとう", "どく", "じめん", "ひこう", "エスパー", "むし", "いわ", "ゴースト", "ドラゴン", "あく", "はがね", "フェアリー"]

    static func typeColor(_ type: String) -> Color {
        Color(hex: types[type]?.color ?? 0x999999)
    }

    static func typeInk(_ type: String) -> Color {
        let hex = types[type]?.color ?? 0x999999
        let red = Double((hex >> 16) & 0xFF)
        let green = Double((hex >> 8) & 0xFF)
        let blue = Double(hex & 0xFF)
        let luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
        return luminance > 0.62 ? Color(hex: 0x1C1C1E) : .white
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct Icon: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct TypeIcon: View {
    let type: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let id = Palette.types[type]?.id {
                Image("type_\(id)")
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(Palette.track)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(type)
    }
}

struct CategoryIcon: View {
    let category: String
    var size: CGFloat = 18

    var body: some View {
        Icon(name: category == "物理" ? "category_physical" : category == "特殊" ? "category_special" : "category_status", size: size)
            .accessibilityLabel(category)
    }
}

struct NumberText: View {
    let text: String
    var value: Double?

    init(_ text: String, value: Double? = nil) {
        self.text = text
        self.value = value
    }

    init(_ number: Int) {
        self.text = String(number)
        self.value = Double(number)
    }

    var body: some View {
        Text(text)
            .monospacedDigit()
            .contentTransition(value.map { ContentTransition.numericText(value: $0) } ?? ContentTransition.numericText())
            .animation(.snappy(duration: 0.32), value: text)
    }
}

extension View {
    func card(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    func sectionTitle() -> some View {
        self
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Palette.secondary)
    }
}

enum BundleSprite {
    static func image(_ name: String) -> UIImage? {
        let hex = Array(name.precomposedStringWithCanonicalMapping.utf8).map { String(format: "%02x", $0) }.joined()
        return UIImage(named: "sprite_\(hex)")
    }
}

struct SpriteIcon: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Group {
            if let image = BundleSprite.image(name) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Circle()
                    .fill(Palette.track)
                    .padding(size * 0.2)
            }
        }
        .frame(width: size, height: size)
    }
}

struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChanged: (CGPoint) -> Void
    var onEnded: () -> Void = {}

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        switch recognizer.state {
        case .began, .changed:
            onChanged(context.converter.localLocation)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}

struct CloseButtonLabel: View {
    var size: CGFloat = 15

    var body: some View {
        Image(systemName: "xmark")
            .font(.system(size: size, weight: .semibold))
    }
}

struct UnevenBox: Shape {
    var strong: CGFloat = 24
    var weak: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: strong,
            bottomLeadingRadius: weak,
            bottomTrailingRadius: strong,
            topTrailingRadius: weak,
            style: .continuous
        ).path(in: rect)
    }
}

func tintedImage(_ name: String, _ color: Color) -> Image {
    guard let image = UIImage(named: name)?.withTintColor(UIColor(color), renderingMode: .alwaysOriginal) else {
        return Image(name)
    }
    return Image(uiImage: image)
}

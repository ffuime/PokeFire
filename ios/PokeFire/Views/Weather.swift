import Charts
import MapKit
import SwiftUI

enum WeatherScene: String, CaseIterable, Identifiable {
    case clearDay, clearNight, partlyDay, partlyNight, cloudy, fog, rain, heavyRain, snow, thunder

    static let debugKey = "weather-debug-scene"
    static let debugNightKey = "weather-debug-night"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clearDay: return "快晴（昼）"
        case .clearNight: return "快晴（夜）"
        case .partlyDay: return "晴れ時々曇り（昼）"
        case .partlyNight: return "晴れ時々曇り（夜）"
        case .cloudy: return "曇り"
        case .fog: return "霧"
        case .rain: return "雨"
        case .heavyRain: return "強い雨"
        case .snow: return "雪"
        case .thunder: return "雷雨"
        }
    }

    var code: Int {
        switch self {
        case .clearDay, .clearNight: return 0
        case .partlyDay, .partlyNight: return 2
        case .cloudy: return 3
        case .fog: return 45
        case .rain: return 63
        case .heavyRain: return 65
        case .snow: return 73
        case .thunder: return 95
        }
    }

    var fixedNight: Bool? {
        switch self {
        case .clearDay, .partlyDay: return false
        case .clearNight, .partlyNight: return true
        default: return nil
        }
    }

    static func from(code: Int, isDay: Bool) -> WeatherScene {
        switch code {
        case 0, 1: return isDay ? .clearDay : .clearNight
        case 2: return isDay ? .partlyDay : .partlyNight
        case 3: return .cloudy
        case 45, 48: return .fog
        case 65, 82: return .heavyRain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 99: return .thunder
        case 51, 53, 55, 56, 57, 61, 63, 66, 67, 80, 81: return .rain
        default: return .cloudy
        }
    }

    var colors: [Color] {
        let pair: (UInt32, UInt32)
        switch self {
        case .clearDay: pair = (0x2F7BD9, 0x74B5EF)
        case .clearNight: pair = (0x08122B, 0x22355E)
        case .partlyDay: pair = (0x4682C6, 0x93B6DB)
        case .partlyNight: pair = (0x121C34, 0x33435F)
        case .cloudy: pair = (0x5E6F82, 0x9AA9B8)
        case .fog: pair = (0x7C858D, 0xB6BDC3)
        case .rain: pair = (0x3B4A5C, 0x6A7B8E)
        case .heavyRain: pair = (0x2A3542, 0x52606D)
        case .snow: pair = (0x7B91A8, 0xC3CFDB)
        case .thunder: pair = (0x1C2130, 0x434A62)
        }
        return [Color(hex: pair.0), Color(hex: pair.1)]
    }

    var clouds: Int {
        switch self {
        case .clearDay, .clearNight: return 0
        case .partlyDay, .partlyNight: return 3
        case .fog: return 5
        default: return 6
        }
    }
}

private struct WeatherBackground: View {
    let scene: WeatherScene
    let night: Bool

    private func noise(_ index: Int, _ salt: Double) -> Double {
        let value = sin(Double(index) * 12.9898 + salt * 78.233) * 43758.5453
        return value - value.rounded(.down)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: scene.colors, startPoint: .top, endPoint: .bottom)
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    draw(&context, size, time)
                }
            }
            if night && scene.fixedNight == nil {
                Color.black.opacity(0.35)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: scene)
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let width = size.width
        let height = size.height
        if scene == .clearDay || scene == .partlyDay {
            let pulse = 1 + 0.04 * sin(time * 0.8)
            let center = CGPoint(x: width * 0.82, y: height * 0.06)
            let radius = 240 * pulse
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6C8).opacity(0.75), Color(hex: 0xFFE38A).opacity(0.2), .clear]), center: center, startRadius: 0, endRadius: radius)
            )
        }
        if scene == .clearNight || scene == .partlyNight {
            for index in 0..<80 {
                let x = noise(index, 1) * width
                let y = noise(index, 2) * height * 0.6
                let twinkle = 0.3 + 0.6 * abs(sin(time * (0.6 + noise(index, 3)) + noise(index, 4) * 6))
                let dot = 0.8 + noise(index, 5) * 1.6
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(.white.opacity(twinkle)))
            }
        }
        if scene.clouds > 0 {
            var layer = context
            layer.addFilter(.blur(radius: 22))
            let alpha = scene == .partlyNight ? 0.12 : scene == .fog ? 0.3 : 0.22
            for index in 0..<scene.clouds {
                let speed = 6 + noise(index, 6) * 10
                let span = width + 360
                let x = (noise(index, 7) * span + time * speed).truncatingRemainder(dividingBy: span) - 180
                let y = scene == .fog ? height * (0.15 + noise(index, 8) * 0.7) : height * (0.02 + noise(index, 8) * 0.32)
                let scale = 0.8 + noise(index, 9) * 0.8
                for part in 0..<4 {
                    let dx = (Double(part) - 1.5) * 46 * scale
                    let dy = (part % 2 == 0 ? -10.0 : 8.0) * scale
                    let w = (120 + noise(index * 4 + part, 10) * 60) * scale
                    let h = w * 0.55
                    layer.fill(Path(ellipseIn: CGRect(x: x + dx - w / 2, y: y + dy - h / 2, width: w, height: h)), with: .color(.white.opacity(alpha)))
                }
            }
        }
        switch scene {
        case .rain, .heavyRain, .thunder:
            let count = scene == .heavyRain ? 150 : 80
            let length = scene == .heavyRain ? 22.0 : 15.0
            var path = Path()
            for index in 0..<count {
                let speed = 520 + noise(index, 11) * 260
                let span = height + 60
                let y = (noise(index, 12) * span + time * speed).truncatingRemainder(dividingBy: span) - 30
                let x = noise(index, 13) * (width + 40) - 20 - y * 0.08
                path.move(to: CGPoint(x: x, y: y))
                path.addLine(to: CGPoint(x: x - length * 0.08, y: y + length))
            }
            context.stroke(path, with: .color(.white.opacity(0.32)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            if scene == .thunder {
                let phase = time.truncatingRemainder(dividingBy: 6.5)
                if phase < 0.09 || (phase > 0.16 && phase < 0.22) {
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.28)))
                }
            }
        case .snow:
            for index in 0..<70 {
                let speed = 28 + noise(index, 14) * 34
                let span = height + 20
                let y = (noise(index, 15) * span + time * speed).truncatingRemainder(dividingBy: span) - 10
                let x = noise(index, 16) * width + sin(time * 0.9 + noise(index, 17) * 6) * 14
                let dot = 2 + noise(index, 18) * 3
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: dot, height: dot)), with: .color(.white.opacity(0.75)))
            }
        default:
            break
        }
    }
}

struct TemperatureText: View {
    let value: Double
    var size: CGFloat
    var weight: Font.Weight = .regular
    var unit: CGFloat = 0.6

    var body: some View {
        Text("\(Int(value.rounded()))\(Text("℃").font(.system(size: size * unit, weight: weight)))")
            .font(.system(size: size, weight: weight))
            .monospacedDigit()
            .accessibilityLabel("\(Int(value.rounded()))度")
    }
}

private struct WeatherCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct WeatherBarButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.play(.light)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
    }
}

private enum HourlyItem: Identifiable {
    case hour(WeatherHour, first: Bool)
    case sun(Date, rise: Bool)

    var date: Date {
        switch self {
        case .hour(let hour, _): return hour.time
        case .sun(let date, _): return date
        }
    }

    var id: String {
        switch self {
        case .hour(let hour, _): return "h\(hour.time.timeIntervalSince1970)"
        case .sun(let date, let rise): return "\(rise ? "r" : "s")\(date.timeIntervalSince1970)"
        }
    }

    static func build(_ report: WeatherReport, day: WeatherDay? = nil) -> [HourlyItem] {
        let now = Date()
        let hours: [WeatherHour]
        if let day {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = report.zone
            let start = max(day.date, now.addingTimeInterval(-3600))
            let end = calendar.date(byAdding: .day, value: 1, to: day.date) ?? day.date
            hours = report.hours.filter { $0.time > start && $0.time < end }
        } else {
            hours = report.upcomingHours(25)
        }
        guard let first = hours.first, let last = hours.last else { return [] }
        let firstIsNow = first.time <= now
        var items = hours.enumerated().map { HourlyItem.hour($1, first: $0 == 0 && firstIsNow) }
        for entry in report.days.prefix(4) {
            for (date, rise) in [(entry.sunrise, true), (entry.sunset, false)] {
                guard let date, date > now, date > first.time, date < last.time.addingTimeInterval(3600) else { continue }
                items.append(.sun(date, rise: rise))
            }
        }
        return items.sorted { $0.date < $1.date }
    }
}

private struct HourlyStrip: View {
    let report: WeatherReport
    let items: [HourlyItem]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(items) { item in
                    switch item {
                    case .hour(let hour, let first):
                        VStack(spacing: 8) {
                            Text(first ? "今" : WeatherFormat.time(hour.time, report.zone, "H時"))
                                .font(.system(size: 15, weight: first ? .bold : .medium))
                                .opacity(first ? 1 : 0.8)
                            Image(systemName: WeatherCondition.symbol(hour.code, isDay: hour.isDay))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 22))
                                .frame(height: 28)
                            Text((hour.precipitationProbability ?? 0) >= 10 ? "\(hour.precipitationProbability ?? 0)%" : " ")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: 0x8FD3FF))
                            TemperatureText(value: hour.temperature, size: 19, weight: .medium)
                        }
                        .frame(minWidth: 40)
                    case .sun(let date, let rise):
                        VStack(spacing: 8) {
                            Text(WeatherFormat.time(date, report.zone, "H:mm"))
                                .font(.system(size: 15, weight: .medium))
                                .opacity(0.8)
                            Image(systemName: rise ? "sunrise.fill" : "sunset.fill")
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 22))
                                .frame(height: 28)
                            Text(" ")
                                .font(.system(size: 12, weight: .bold))
                            Text(rise ? "日の出" : "日の入")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(minWidth: 46)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct FlipFace: ViewModifier, Animatable {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .opacity(abs(angle) <= 90 ? 1 : 0)
            .allowsHitTesting(abs(angle) < 90)
    }
}

private struct Skeleton: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .redacted(reason: .placeholder)
                .allowsHitTesting(false)
                .phaseAnimator([0.45, 0.85]) { view, phase in
                    view.opacity(phase)
                } animation: { _ in
                    .easeInOut(duration: 0.85)
                }
        } else {
            content
        }
    }
}

extension WeatherReport {
    static var placeholder: WeatherReport {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let today = calendar.startOfDay(for: now)
        return WeatherReport(
            fetchedAt: now,
            timeZone: TimeZone.current.identifier,
            current: WeatherCurrent(temperature: 18, apparent: 18, humidity: 50, code: 2, isDay: true, windSpeed: 2, windDirection: 0, pressure: 1013, precipitation: 0),
            hours: (0..<48).map { WeatherHour(time: hour.addingTimeInterval(Double($0) * 3600), temperature: 18, code: 2, isDay: true) },
            days: (0..<10).map { WeatherDay(date: calendar.date(byAdding: .day, value: $0, to: today) ?? today, code: 2, high: 22, low: 12, uvIndex: 3, precipitationProbability: 0, precipitationSum: 0, humidity: 50) },
            yesterday: nil
        )
    }
}

struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var store = WeatherStore.shared
    @State private var radar = RadarModel()
    @State private var showSettings = false
    @State private var showRadar = false
    @AppStorage(YahooWeather.idKey) private var clientID = ""
    @AppStorage(WeatherScene.debugKey) private var debugScene = ""
    @AppStorage(WeatherScene.debugNightKey) private var debugNight = ""
    @AppStorage("weather-header-mode") private var headerMode = 0
    @State private var selectedDay = 0

    private static let faceHeight: CGFloat = DaysFace.cardHeight + 10 + DaysFace.stripHeight

    private var condition: (code: Int, isDay: Bool, scene: WeatherScene) {
        let report = store.report
        let actualDay = report?.current.isDay ?? true
        if let forced = WeatherScene(rawValue: debugScene) {
            let isDay = forced.fixedNight.map { !$0 } ?? (debugNight == "night" ? false : debugNight == "day" ? true : actualDay)
            return (forced.code, isDay, forced)
        }
        let code = report?.current.code ?? 2
        let isDay = debugNight == "night" ? false : debugNight == "day" ? true : actualDay
        return (code, isDay, WeatherScene.from(code: code, isDay: isDay))
    }

    var body: some View {
        let condition = self.condition
        let loading = store.report == nil
        let report = store.report ?? .placeholder
        ZStack {
            WeatherBackground(scene: condition.scene, night: !condition.isDay)
            ScrollView {
                VStack(spacing: 14) {
                    header(condition, report, loading)
                    if let error = store.error {
                        Text(error)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    rainCard
                    hourlyCard(report)
                        .modifier(Skeleton(active: loading))
                    radarCard
                    dailyCard(report)
                        .modifier(Skeleton(active: loading))
                    details(report)
                        .modifier(Skeleton(active: loading))
                    credits
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .refreshable {
                async let weather: Void = store.reload()
                async let maps: Void = radar.load()
                _ = await (weather, maps)
                Haptics.play(.success)
                await radar.sample(store.coordinate)
            }
            .safeAreaInset(edge: .top, spacing: 0) { topBar }
        }
        .environment(\.colorScheme, .dark)
        .foregroundStyle(.white)
        .task {
            store.refresh()
            await radar.load()
            radar.play()
        }
        .task(id: store.report?.fetchedAt) {
            await radar.sample(store.coordinate)
        }
        .onChange(of: phase) { _, value in
            if value == .active { store.refresh() }
        }
        .sheet(isPresented: $showSettings, onDismiss: { store.refresh() }) {
            WeatherSettingsSheet()
        }
        .fullScreenCover(isPresented: $showRadar) {
            RadarScreen(radar: radar, center: store.coordinate, place: store.title, pinned: store.selected != nil)
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            WeatherBarButton(symbol: "chevron.left", label: "戻る") {
                radar.stop()
                dismiss()
            }
            Spacer(minLength: 0)
            Menu {
                Button {
                    store.select(nil)
                } label: {
                    Label("現在地", systemImage: "location.fill")
                }
                ForEach(store.places) { place in
                    Button(place.name) { store.select(place.id) }
                }
                Divider()
                Button {
                    showSettings = true
                } label: {
                    Label("地点を管理", systemImage: "list.bullet")
                }
            } label: {
                HStack(spacing: 6) {
                    if store.selection == nil {
                        Image(systemName: "location.fill")
                            .font(.caption.weight(.semibold))
                    }
                    Text(store.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.heavy))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .contentShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: Capsule())
            Spacer(minLength: 0)
            WeatherBarButton(symbol: "gearshape", label: "天気の設定") {
                showSettings = true
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func header(_ condition: (code: Int, isDay: Bool, scene: WeatherScene), _ report: WeatherReport, _ loading: Bool) -> some View {
        let flipped = headerMode == 1 && report.days.count >= 3
        return VStack(spacing: 2) {
            Text(store.title)
                .font(.system(size: 30, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .modifier(Skeleton(active: loading && store.selected == nil && store.here == nil))
            ZStack {
                currentHeader(report, condition)
                    .frame(height: Self.faceHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { flip() }
                    .modifier(FlipFace(angle: flipped ? 180 : 0))
                if report.days.count >= 3 {
                    DaysFace(report: report, selected: $selectedDay) { flip() }
                        .frame(height: Self.faceHeight, alignment: .top)
                        .modifier(FlipFace(angle: flipped ? 0 : -180))
                }
            }
            .modifier(Skeleton(active: loading))
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { mode in
                    Capsule()
                        .fill(.white.opacity(mode == headerMode ? 0.9 : 0.35))
                        .frame(width: mode == headerMode ? 14 : 6, height: 6)
                }
            }
            .padding(.top, 12)
            .animation(.snappy, value: headerMode)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func flip() {
        Haptics.play(.light)
        withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) {
            headerMode = headerMode == 1 ? 0 : 1
        }
    }

    private func currentHeader(_ report: WeatherReport, _ condition: (code: Int, isDay: Bool, scene: WeatherScene)) -> some View {
        VStack(spacing: 2) {
            TemperatureText(value: report.current.temperature, size: 96, weight: .thin, unit: 0.42)
                .contentTransition(.numericText(value: report.current.temperature))
            HStack(spacing: 6) {
                Image(systemName: WeatherCondition.symbol(condition.code, isDay: condition.isDay))
                    .symbolRenderingMode(.multicolor)
                Text(WeatherCondition.label(condition.code))
            }
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            if let today = report.today {
                HStack(spacing: 14) {
                    HStack(spacing: 3) {
                        Text("最高").font(.system(size: 15, weight: .medium)).opacity(0.7)
                        TemperatureText(value: today.high, size: 18, weight: .semibold)
                    }
                    HStack(spacing: 3) {
                        Text("最低").font(.system(size: 15, weight: .medium)).opacity(0.7)
                        TemperatureText(value: today.low, size: 18, weight: .semibold)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップで日ごとの天気に切り替えます")
    }

    private var rainCard: some View {
        WeatherCard(title: "60分間の降水", symbol: "umbrella.fill") {
            if clientID.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Yahoo! の Client ID を設定すると、60分先までの降水予報が見られます。")
                    .font(.subheadline.weight(.medium))
                Button("Client ID を設定") { showSettings = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: 0x8FD3FF))
            } else if let nowcast = store.nowcast {
                Text(nowcast.summary)
                    .font(.system(size: 17, weight: .semibold))
                RainChart(points: nowcast.timeline)
            } else if let message = store.nowcastError {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("この先1時間は雨の心配はありません。")
                        .font(.system(size: 17, weight: .semibold))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .frame(height: 120)
                }
                .modifier(Skeleton(active: true))
            }
        }
    }

    private func hourlyCard(_ report: WeatherReport) -> some View {
        WeatherCard(title: "1時間ごとの予報", symbol: "clock") {
            HourlyStrip(report: report, items: HourlyItem.build(report))
        }
    }

    private var radarCard: some View {
        WeatherCard(title: "雨雲レーダー", symbol: "cloud.rain") {
            ZStack(alignment: .bottom) {
                RadarMapView(frames: radar.frames, index: radar.index, center: store.coordinate, pinned: store.selected != nil, interactive: false)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if radar.failed {
                    Text("レーダーを読み込めませんでした")
                        .font(.footnote.weight(.semibold))
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 100)
                }
                RadarTimeLabel(radar: radar)
                    .padding(10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.play(.light)
                showRadar = true
            }
        }
    }

    private func dailyCard(_ report: WeatherReport) -> some View {
        let low = report.days.map(\.low).min() ?? 0
        let high = report.days.map(\.high).max() ?? 1
        return WeatherCard(title: "10日間の予報", symbol: "calendar") {
            VStack(spacing: 0) {
                ForEach(Array(report.days.enumerated()), id: \.element.id) { index, day in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.15))
                    }
                    HStack(spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(index == 0 ? "今日" : WeatherFormat.time(day.date, report.zone, "M/d"))
                                .font(.system(size: 17, weight: index == 0 ? .bold : .semibold))
                                .monospacedDigit()
                            Text(WeatherFormat.time(day.date, report.zone, "E"))
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(DayStyle.weekday(day.date, report.zone).opacity(0.7))
                        }
                        .lineLimit(1)
                        .frame(width: 62, alignment: .leading)
                        VStack(spacing: 1) {
                            Image(systemName: WeatherCondition.symbol(day.code))
                                .symbolRenderingMode(.multicolor)
                                .font(.system(size: 20))
                                .frame(height: 24)
                            Text((day.precipitationProbability ?? 0) >= 10 ? "\(day.precipitationProbability ?? 0)%" : " ")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: 0x8FD3FF))
                                .frame(height: 13)
                        }
                        .frame(width: 40)
                        TemperatureText(value: day.low, size: 18, weight: .medium)
                            .opacity(0.55)
                            .frame(width: 44, alignment: .trailing)
                        TemperatureRange(low: low, high: high, dayLow: day.low, dayHigh: day.high, current: index == 0 ? report.current.temperature : nil)
                        TemperatureText(value: day.high, size: 18, weight: .semibold)
                            .frame(width: 44, alignment: .trailing)
                    }
                    .frame(height: 50)
                }
            }
        }
    }

    private func details(_ report: WeatherReport) -> some View {
        let current = report.current
        let today = report.today
        var tiles: [(title: String, symbol: String, value: String, note: String?, temperature: Double?)] = [
            ("体感温度", "thermometer.medium", "", current.apparent > current.temperature + 1 ? "実際より暖かく感じます" : current.apparent < current.temperature - 1 ? "実際より涼しく感じます" : "実際の気温と同じくらい", current.apparent),
            ("湿度", "humidity.fill", "\(current.humidity)%", today?.humidity.map { "今日の平均 \($0)%" }, nil),
            ("風", "wind", String(format: "%.1fm/s", current.windSpeed), "\(WeatherFormat.wind(current.windDirection))の風", nil),
            ("気圧", "gauge.with.dots.needle.33percent", "\(Int(current.pressure.rounded()))hPa", nil, nil),
        ]
        if let uv = today?.uvIndex {
            tiles.append(("UV指数", "sun.max", "\(Int(uv.rounded()))", WeatherFormat.uv(uv), nil))
        }
        if let sum = today?.precipitationSum {
            tiles.append(("降水量", "drop.fill", String(format: "%.1fmm", sum), "今日の合計", nil))
        }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(tiles, id: \.title) { tile in
                WeatherCard(title: tile.title, symbol: tile.symbol) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let temperature = tile.temperature {
                            TemperatureText(value: temperature, size: 30, weight: .medium)
                        } else {
                            Text(tile.value)
                                .font(.system(size: 30, weight: .medium))
                                .monospacedDigit()
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                        }
                        Text(tile.note ?? " ")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                    }
                }
            }
        }
    }

    private var credits: some View {
        VStack(spacing: 6) {
            Link("天気データ: Open-Meteo.com（CC BY 4.0）", destination: URL(string: "https://open-meteo.com/")!)
            Link("雨雲レーダー: 気象庁 降水ナウキャスト", destination: URL(string: "https://www.jma.go.jp/bosai/nowc/")!)
            if !clientID.isEmpty {
                Link("Webサービス by Yahoo! JAPAN", destination: YahooWeather.creditURL)
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 6)
    }
}

private enum DayStyle {
    static func weekday(_ date: Date, _ zone: TimeZone) -> Color {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        switch calendar.component(.weekday, from: date) {
        case 1: return Color(hex: 0xFF9A8F)
        case 7: return Color(hex: 0x8FCBFF)
        default: return .white
        }
    }

    static func diff(_ value: Double, _ previous: Double?) -> String? {
        guard let previous else { return nil }
        let delta = Int(value.rounded()) - Int(previous.rounded())
        return delta == 0 ? "±0" : delta > 0 ? "+\(delta)" : "\(delta)"
    }
}

private struct DayCard: View {
    let report: WeatherReport
    let index: Int
    let compact: Bool
    let selected: Bool

    private static let high = Color(hex: 0xFFA28F)
    private static let low = Color(hex: 0x8FCBFF)

    var body: some View {
        let day = report.days[index]
        let previous: WeatherDay? = index == 0 ? report.yesterday : report.days[index - 1]
        VStack(spacing: compact ? 6 : 8) {
            VStack(spacing: 1) {
                Text(["今日", "明日", "明後日"][index])
                    .font(.system(size: compact ? 14 : 16, weight: .bold))
                HStack(spacing: 2) {
                    Text(WeatherFormat.time(day.date, report.zone, "M/d"))
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .opacity(0.75)
                    Text(WeatherFormat.time(day.date, report.zone, "(E)"))
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(DayStyle.weekday(day.date, report.zone).opacity(0.75))
                }
            }
            Image(systemName: WeatherCondition.symbol(day.code))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: compact ? 30 : 44))
                .frame(height: compact ? 36 : 50)
            if !compact {
                Text(WeatherCondition.label(day.code))
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 3) {
                Image(systemName: "drop.fill")
                    .font(.system(size: compact ? 9 : 10))
                    .foregroundStyle(Color(hex: 0x8FD3FF))
                Text("\(day.precipitationProbability ?? 0)%")
                    .font(.system(size: compact ? 12 : 14, weight: .medium))
                    .monospacedDigit()
            }
            if compact {
                VStack(spacing: 0) {
                    TemperatureText(value: day.high, size: 16, weight: .semibold)
                        .foregroundStyle(Self.high)
                    TemperatureText(value: day.low, size: 16, weight: .semibold)
                        .foregroundStyle(Self.low)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    temperature(day.high, previous?.high, Self.high)
                    temperature(day.low, previous?.low, Self.low)
                }
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(selected ? 0.35 : 0), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func temperature(_ value: Double, _ previous: Double?, _ color: Color) -> some View {
        VStack(spacing: 0) {
            TemperatureText(value: value, size: 26, weight: .medium)
                .foregroundStyle(color)
            Text(DayStyle.diff(value, previous).map { "[\($0)]" } ?? " ")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(color.opacity(0.75))
        }
    }
}

private struct DaysFace: View {
    let report: WeatherReport
    @Binding var selected: Int
    let onClose: () -> Void
    @State private var drag: CGFloat = 0

    static let cardHeight: CGFloat = 200
    static let stripHeight: CGFloat = 118
    private static let spacing: CGFloat = 8

    private func select(_ index: Int) {
        let target = min(2, max(0, index))
        guard target != selected else { return }
        Haptics.play(.selection)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            selected = target
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let large = (width - Self.spacing) * 0.7
                let small = width - Self.spacing - large
                let shift: CGFloat = selected == 0 ? 0 : small + Self.spacing
                HStack(spacing: Self.spacing) {
                    ForEach(0..<3, id: \.self) { index in
                        DayCard(report: report, index: index, compact: index != selected, selected: index == selected)
                            .frame(width: index == selected ? large : small, height: Self.cardHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if index == selected {
                                    onClose()
                                } else {
                                    select(index)
                                }
                            }
                    }
                }
                .offset(x: drag - shift)
            }
            .frame(height: Self.cardHeight)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        drag = value.translation.width * 0.5
                    }
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let predicted = value.predictedEndTranslation.width
                        if abs(horizontal) > abs(value.translation.height) {
                            if horizontal < -40 || predicted < -120 {
                                select(selected + 1)
                            } else if horizontal > 40 || predicted > 120 {
                                select(selected - 1)
                            }
                        }
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { drag = 0 }
                    }
            )
            HourlyStrip(report: report, items: HourlyItem.build(report, day: report.days[selected]))
                .id(selected)
                .transition(.opacity)
                .padding(12)
                .frame(height: Self.stripHeight)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .animation(.easeInOut(duration: 0.2), value: selected)
        }
    }
}

private struct TemperatureRange: View {
    let low: Double
    let high: Double
    let dayLow: Double
    let dayHigh: Double
    let current: Double?

    var body: some View {
        GeometryReader { geometry in
            let span = max(1, high - low)
            let width = geometry.size.width
            let start = (dayLow - low) / span * width
            let end = (dayHigh - low) / span * width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0x7FD0FF), Color(hex: 0xB7E66B), Color(hex: 0xFFC94A), Color(hex: 0xFF8A3D)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, end - start))
                    .offset(x: start)
                if let current {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                        .offset(x: min(width - 8, max(0, (current - low) / span * width - 4)))
                }
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity)
        }
        .frame(height: 20)
    }
}

private struct RainChart: View {
    let points: [RainPoint]

    private func label(_ date: Date?) -> String {
        guard let date else { return "" }
        if date == points.first?.date { return "今" }
        return WeatherFormat.time(date, TimeZone(identifier: "Asia/Tokyo") ?? .current, "H:mm")
    }

    var body: some View {
        let peak = max(4, points.map(\.rainfall).max() ?? 0)
        Chart(points) { point in
            BarMark(
                x: .value("時刻", point.date, unit: .minute),
                y: .value("降水量", point.rainfall),
                width: .fixed(14)
            )
            .foregroundStyle(point.forecast ? Color(hex: 0x6CC4FF) : Color(hex: 0x6CC4FF).opacity(0.5))
            .cornerRadius(3)
        }
        .chartYScale(domain: 0...peak)
        .chartXAxis {
            AxisMarks(values: points.map(\.date)) { value in
                AxisValueLabel {
                    Text(label(value.as(Date.self)))
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 120)
        .accessibilityLabel("60分間の降水量のグラフ")
    }
}

@MainActor
private enum RadarText {
    static func relative(_ radar: RadarModel) -> String {
        guard let frame = radar.current, radar.frames.indices.contains(radar.nowIndex) else { return "" }
        let minutes = Int((frame.date.timeIntervalSince(radar.frames[radar.nowIndex].date) / 60).rounded())
        if minutes == 0 { return "現在" }
        return minutes < 0 ? "過去" : "予測"
    }
}

private struct RadarTimeLabel: View {
    let radar: RadarModel

    var body: some View {
        if let frame = radar.current {
            HStack(spacing: 6) {
                Text(WeatherFormat.time(frame.date, .current, "H:mm"))
                    .monospacedDigit()
                Text(RadarText.relative(radar))
                    .foregroundStyle(.secondary)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.regularMaterial, in: Capsule())
        }
    }
}

private enum RadarStyle {
    static let rain = Color(hex: 0x1EA7FF)
}

private struct RadarTicks: View {
    @Bindable var radar: RadarModel

    var body: some View {
        GeometryReader { geometry in
            let count = max(1, radar.frames.count)
            let slot = geometry.size.width / CGFloat(count)
            ZStack(alignment: .topLeading) {
                ForEach(radar.frames.indices, id: \.self) { position in
                    let active = position == radar.index
                    let now = position == radar.nowIndex
                    Capsule()
                        .fill(active ? Color.primary : Color.secondary.opacity(now ? 0.9 : 0.45))
                        .frame(width: active ? 3.5 : 2.5, height: active ? 30 : now ? 24 : 18)
                        .position(x: slot * (CGFloat(position) + 0.5), y: 17)
                }
            }
            .frame(width: geometry.size.width, height: 34)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let position = min(count - 1, max(0, Int(value.location.x / slot)))
                        guard position != radar.index else { return }
                        radar.stop()
                        radar.index = position
                        Haptics.play(.selection)
                    }
            )
        }
        .frame(height: 34)
        .animation(.snappy(duration: 0.18), value: radar.index)
        .accessibilityElement()
        .accessibilityLabel("時刻")
        .accessibilityValue(RadarText.relative(radar))
        .accessibilityAdjustableAction { direction in
            radar.stop()
            switch direction {
            case .increment: radar.index = min(radar.frames.count - 1, radar.index + 1)
            case .decrement: radar.index = max(0, radar.index - 1)
            @unknown default: break
            }
        }
    }
}

private struct RadarRain: View {
    @Bindable var radar: RadarModel
    let expanded: Bool
    let scale: Double

    static let barHeight: CGFloat = 130

    var body: some View {
        GeometryReader { geometry in
            let count = max(1, radar.frames.count)
            let slot = geometry.size.width / CGFloat(count)
            ZStack(alignment: .topLeading) {
                if expanded {
                    ForEach(radar.frames.indices, id: \.self) { position in
                        let value = radar.rainfall(position) ?? 0
                        if value > 0 {
                            RoundedRectangle(cornerRadius: min(4, slot * 0.3), style: .continuous)
                                .fill(RadarStyle.rain.opacity(position == radar.index ? 1 : 0.75))
                                .frame(width: max(2, slot * 0.82), height: max(4, CGFloat(min(value, scale) / scale) * Self.barHeight))
                                .offset(x: slot * CGFloat(position) + slot * 0.09)
                        }
                    }
                } else {
                    ForEach(runs(), id: \.0) { run in
                        Capsule()
                            .fill(RadarStyle.rain)
                            .frame(width: max(4, slot * CGFloat(run.1 - run.0 + 1) - slot * 0.3), height: 4)
                            .offset(x: slot * CGFloat(run.0) + slot * 0.15)
                    }
                }
            }
            .frame(width: geometry.size.width, height: expanded ? Self.barHeight : 6, alignment: .topLeading)
            .contentShape(Rectangle())
            .onTapGesture { location in
                let position = min(count - 1, max(0, Int(location.x / slot)))
                radar.stop()
                radar.index = position
                Haptics.play(.selection)
            }
        }
        .frame(height: expanded ? Self.barHeight : 6)
    }

    private func runs() -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        var start: Int?
        for position in radar.frames.indices {
            let raining = (radar.rainfall(position) ?? 0) > 0
            if raining, start == nil { start = position }
            if !raining, let begin = start {
                result.append((begin, position - 1))
                start = nil
            }
        }
        if let start { result.append((start, radar.frames.count - 1)) }
        return result
    }
}

private struct RadarAxis: View {
    let scale: Double

    var body: some View {
        let step = scale / 3
        ZStack(alignment: .topTrailing) {
            ForEach(1...3, id: \.self) { mark in
                let value = step * Double(mark)
                HStack(spacing: 4) {
                    Text("\(Int(value.rounded()))mm")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Capsule()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 2)
                }
                .offset(y: CGFloat(value / scale) * RadarRain.barHeight - 7)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: RadarRain.barHeight, alignment: .topTrailing)
    }
}

private struct RadarLegend: View {
    private let steps: [(String, UInt32)] = [
        ("1", 0xA0D2FF), ("5", 0x218CFF), ("10", 0x0041FF), ("20", 0xFAF500),
        ("30", 0xFF9900), ("50", 0xFF2800), ("80", 0xB40068),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(steps, id: \.0) { step in
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(Color(hex: step.1))
                        .frame(height: 5)
                    Text(step.0)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text("mm/h")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

struct RadarScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var radar: RadarModel
    let center: CLLocationCoordinate2D?
    let place: String
    let pinned: Bool
    @State private var expanded = false

    private var scale: Double {
        let peak = radar.frames.indices.compactMap { radar.rainfall($0) }.max() ?? 0
        return max(15, (peak / 15).rounded(.up) * 15)
    }

    private var hasRain: Bool {
        radar.frames.indices.contains { (radar.rainfall($0) ?? 0) > 0 }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RadarMapView(frames: radar.frames, index: radar.index, center: center, pinned: pinned, interactive: true)
                .ignoresSafeArea()
            panel
        }
        .overlay(alignment: .top) {
            HStack {
                WeatherBarButton(symbol: "xmark", label: "閉じる") { dismiss() }
                Spacer()
                Text(place)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glassEffect(.regular, in: Capsule())
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .task {
            await radar.sample(center)
        }
    }

    private var panel: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(radar.current.map { WeatherFormat.time($0.date, .current, "H:mm") } ?? "--:--")
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(RadarText.relative(radar))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let value = radar.rainfall(radar.index), value > 0 {
                    Text(RainLevel.label(value))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(RadarStyle.rain)
                }
            }
            .animation(.snappy(duration: 0.2), value: radar.index)
            HStack(spacing: 12) {
                circleButton(radar.playing ? "pause.fill" : "play.fill", label: radar.playing ? "一時停止" : "再生") {
                    radar.toggle()
                }
                RadarTicks(radar: radar)
                circleButton("arrow.uturn.backward", label: "現在に戻る") {
                    radar.returnToNow()
                }
            }
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if expanded {
                        RadarAxis(scale: scale)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 44, height: expanded ? RadarRain.barHeight : 6)
                ZStack {
                    RadarRain(radar: radar, expanded: expanded, scale: scale)
                    if expanded && !hasRain {
                        Text(radar.sampling ? "読み込み中…" : "この時間帯、この地点に雨は予想されていません")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                Color.clear.frame(width: 44, height: expanded ? RadarRain.barHeight : 6)
            }
            if expanded {
                RadarLegend()
                    .padding(.top, 4)
                Text("出典：気象庁 降水ナウキャスト")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 16)
                .onEnded { value in
                    let vertical = value.translation.height
                    guard abs(vertical) > abs(value.translation.width) * 1.3 else { return }
                    if vertical < -30, !expanded {
                        Haptics.play(.light)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { expanded = true }
                    } else if vertical > 30, expanded {
                        Haptics.play(.light)
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { expanded = false }
                    }
                }
        )
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.play(.light)
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.secondary.opacity(0.18)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

final class RadarOverlay: MKTileOverlay {
    var index = 0
}

struct RadarMapView: UIViewRepresentable {
    let frames: [RadarFrame]
    let index: Int
    let center: CLLocationCoordinate2D?
    let pinned: Bool
    let interactive: Bool

    private static let alpha: CGFloat = 0.85

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        map.preferredConfiguration = configuration
        map.showsUserLocation = true
        map.showsCompass = false
        map.showsScale = false
        map.isUserInteractionEnabled = interactive
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 40_000, maxCenterCoordinateDistance: 4_000_000)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        if let center, coordinator.centered.map({ abs($0.latitude - center.latitude) > 0.0001 || abs($0.longitude - center.longitude) > 0.0001 }) ?? true {
            coordinator.centered = center
            map.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: 160_000, longitudinalMeters: 160_000), animated: false)
            map.removeAnnotations(map.annotations.filter { !($0 is MKUserLocation) })
            if pinned {
                let pin = MKPointAnnotation()
                pin.coordinate = center
                map.addAnnotation(pin)
            }
        }
        let ids = frames.map(\.id)
        if coordinator.frameIDs != ids {
            map.removeOverlays(map.overlays)
            coordinator.renderers = [:]
            coordinator.frameIDs = ids
            coordinator.index = index
            for (position, frame) in frames.enumerated() {
                let overlay = RadarOverlay(urlTemplate: frame.template)
                overlay.index = position
                overlay.minimumZ = 3
                overlay.maximumZ = 10
                overlay.canReplaceMapContent = false
                map.addOverlay(overlay, level: .aboveRoads)
            }
        }
        coordinator.index = index
        for (position, renderer) in coordinator.renderers {
            let alpha: CGFloat = position == index ? Self.alpha : 0
            if renderer.alpha != alpha {
                renderer.alpha = alpha
                renderer.setNeedsDisplay()
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var frameIDs: [String] = []
        var renderers: [Int: MKTileOverlayRenderer] = [:]
        var index = 0
        var centered: CLLocationCoordinate2D?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let tile = overlay as? RadarOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKTileOverlayRenderer(tileOverlay: tile)
            renderer.alpha = tile.index == index ? RadarMapView.alpha : 0
            renderers[tile.index] = renderer
            return renderer
        }
    }
}

struct WeatherSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = WeatherStore.shared
    @AppStorage(YahooWeather.idKey) private var clientID = ""
    @AppStorage(WeatherAlerts.enabledKey) private var notify = false
    @AppStorage(WeatherScene.debugKey) private var debugScene = ""
    @AppStorage(WeatherScene.debugNightKey) private var debugNight = ""
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        store.select(nil)
                    } label: {
                        HStack {
                            Label("現在地", systemImage: "location.fill")
                                .foregroundStyle(.primary)
                            Spacer()
                            if store.selection == nil {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    ForEach(store.places) { place in
                        Button {
                            store.select(place.id)
                        } label: {
                            HStack {
                                Text(place.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if store.selection == place.id {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                    .onDelete { store.remove(at: $0) }
                    .onMove { store.move(from: $0, to: $1) }
                    NavigationLink {
                        PlaceSearchView()
                    } label: {
                        Label("地点を追加", systemImage: "plus")
                    }
                } header: {
                    Text("地点")
                } footer: {
                    Text("左にスワイプで削除できます。ロック画面のウィジェットは常に現在地を表示します。")
                }
                Section {
                    TextField("Client ID", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.footnote.monospaced())
                    Link(destination: YahooWeather.registerURL) {
                        Label("Client ID を発行する", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("Yahoo! 気象情報API")
                } footer: {
                    Text("Yahoo! デベロッパーネットワークでアプリケーションを登録すると発行されます。60分先までの降水予報と通知に使います。")
                }
                Section {
                    Toggle("雨が降り始める前に通知", isOn: $notify)
                        .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("通知")
                } footer: {
                    Text("最後に取得した現在地について、iOS がバックグラウンド更新を許可したタイミングで確認します。そのため雨の直前に届かないことがあります。")
                }
                Section {
                    Picker("現在の天気", selection: $debugScene) {
                        Text("自動").tag("")
                        ForEach(WeatherScene.allCases) { scene in
                            Text(scene.label).tag(scene.rawValue)
                        }
                    }
                    Picker("昼夜", selection: $debugNight) {
                        Text("自動").tag("")
                        Text("昼").tag("day")
                        Text("夜").tag("night")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("開発用")
                } footer: {
                    Text("背景と現在の天気の表示だけを切り替えます。予報のデータは変わりません。")
                }
                Section("データ") {
                    Link("Open-Meteo.com（CC BY 4.0）", destination: URL(string: "https://open-meteo.com/")!)
                    Link("気象庁 降水ナウキャスト", destination: URL(string: "https://www.jma.go.jp/bosai/nowc/")!)
                    Link("Webサービス by Yahoo! JAPAN", destination: YahooWeather.creditURL)
                }
                .font(.footnote)
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("天気の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Haptics.play(.light)
                        withAnimation(.snappy) {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Image(systemName: editMode.isEditing ? "checkmark" : "pencil")
                            .fontWeight(.semibold)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityLabel(editMode.isEditing ? "完了" : "編集")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    CloseToolbarButton { dismiss() }
                }
            }
        }
        .onChange(of: notify) { _, value in
            guard value else {
                WeatherAlerts.schedule()
                return
            }
            Task {
                let granted = await WeatherAlerts.requestPermission()
                if !granted { notify = false }
                WeatherAlerts.schedule()
            }
        }
    }
}

private struct PlaceSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = WeatherStore.shared
    @State private var query = ""
    @State private var results: [WeatherPlace] = []
    @State private var searching = false

    var body: some View {
        List {
            if searching {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
            ForEach(results) { place in
                Button {
                    Haptics.play(.success)
                    store.add(place)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .foregroundStyle(.primary)
                        Text(PlaceSearch.subtitle(place))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("地点を追加")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "地名・住所・施設名")
        .onSubmit(of: .search) {
            let text = query.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return }
            searching = true
            Task {
                results = await PlaceSearch.search(text)
                searching = false
            }
        }
    }
}

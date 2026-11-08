import Charts
import MapKit
import SwiftUI

private struct WeatherCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var store = WeatherStore.shared
    @State private var radar = RadarModel()
    @State private var showSettings = false
    @State private var showRadar = false
    @AppStorage(YahooWeather.idKey) private var clientID = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                if let error = store.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                rainCard
                if let report = store.report {
                    hourlyCard(report)
                }
                radarCard
                if let report = store.report {
                    dailyCard(report)
                    details(report)
                }
                credits
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .refreshable {
            store.refresh()
            await radar.load()
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .task {
            store.refresh()
            await radar.load()
            radar.play()
        }
        .onChange(of: phase) { _, value in
            if value == .active { store.refresh() }
        }
        .sheet(isPresented: $showSettings, onDismiss: { store.refresh() }) {
            WeatherSettingsSheet()
        }
        .fullScreenCover(isPresented: $showRadar) {
            RadarScreen(radar: radar, center: store.coordinate)
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
                            .font(.caption)
                    }
                    Text(store.title)
                        .font(.headline)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.primary)
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

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 4) {
            Text("Weather")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.secondary)
            if let report = store.report {
                Text(WeatherFormat.degree(report.current.temperature))
                    .font(.system(size: 86, weight: .thin))
                    .contentTransition(.numericText(value: report.current.temperature))
                HStack(spacing: 6) {
                    Image(systemName: WeatherCondition.symbol(report.current.code, isDay: report.current.isDay))
                        .symbolRenderingMode(.multicolor)
                    Text(WeatherCondition.label(report.current.code))
                }
                .font(.title3.weight(.semibold))
                if let today = report.today {
                    Text("最高 \(WeatherFormat.degree(today.high))  最低 \(WeatherFormat.degree(today.low))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            } else if store.loading {
                ProgressView()
                    .frame(height: 140)
            } else {
                Text("--°")
                    .font(.system(size: 86, weight: .thin))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var rainCard: some View {
        WeatherCard(title: "60分間の降水", symbol: "umbrella.fill") {
            if clientID.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("Yahoo! の Client ID を設定すると、60分先までの降水予報が見られます。")
                    .font(.subheadline)
                Button("Client ID を設定") { showSettings = true }
                    .font(.subheadline.weight(.semibold))
            } else if let nowcast = store.nowcast {
                Text(nowcast.summary)
                    .font(.subheadline.weight(.semibold))
                RainChart(points: nowcast.timeline)
            } else if let message = store.nowcastError {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func hourlyCard(_ report: WeatherReport) -> some View {
        WeatherCard(title: "1時間ごとの予報", symbol: "clock") {
            ScrollView(.horizontal) {
                HStack(spacing: 18) {
                    ForEach(Array(report.upcomingHours(25).enumerated()), id: \.element.id) { index, hour in
                        VStack(spacing: 8) {
                            Text(index == 0 ? "今" : WeatherFormat.time(hour.time, report.zone, "H時"))
                                .font(.footnote.weight(.semibold))
                            Image(systemName: WeatherCondition.symbol(hour.code, isDay: hour.isDay))
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)
                                .frame(height: 28)
                            Text((hour.precipitationProbability ?? 0) >= 10 ? "\(hour.precipitationProbability ?? 0)%" : " ")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.blue)
                            Text(WeatherFormat.degree(hour.temperature))
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()
                        }
                        .frame(minWidth: 38)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var radarCard: some View {
        WeatherCard(title: "雨雲レーダー", symbol: "cloud.rain") {
            ZStack(alignment: .bottom) {
                RadarMapView(frames: radar.frames, index: radar.index, center: store.coordinate, interactive: false)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if radar.failed {
                    Text("レーダーを読み込めませんでした")
                        .font(.footnote.weight(.semibold))
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 100)
                }
                RadarTimeLabel(frame: radar.current)
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
                    if index > 0 { Divider() }
                    HStack(spacing: 10) {
                        Text(index == 0 ? "今日" : WeatherFormat.time(day.date, report.zone, "E"))
                            .font(.body.weight(.semibold))
                            .frame(width: 40, alignment: .leading)
                        VStack(spacing: 0) {
                            Image(systemName: WeatherCondition.symbol(day.code))
                                .symbolRenderingMode(.multicolor)
                                .font(.title3)
                            if let chance = day.precipitationProbability, chance >= 10 {
                                Text("\(chance)%")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(width: 40)
                        Text(WeatherFormat.degree(day.low))
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                        TemperatureRange(low: low, high: high, dayLow: day.low, dayHigh: day.high, current: index == 0 ? report.current.temperature : nil)
                        Text(WeatherFormat.degree(day.high))
                            .frame(width: 38, alignment: .trailing)
                    }
                    .font(.body.weight(.medium))
                    .monospacedDigit()
                    .padding(.vertical, 9)
                }
            }
        }
    }

    private func details(_ report: WeatherReport) -> some View {
        let current = report.current
        let today = report.today
        var tiles: [(String, String, String, String?)] = [
            ("体感温度", "thermometer.medium", WeatherFormat.degree(current.apparent), nil),
            ("湿度", "humidity.fill", "\(current.humidity)%", today?.humidity.map { "今日の平均 \($0)%" }),
            ("風", "wind", String(format: "%.1fm/s", current.windSpeed), "\(WeatherFormat.wind(current.windDirection))の風"),
            ("気圧", "gauge.with.dots.needle.33percent", "\(Int(current.pressure.rounded()))hPa", nil),
        ]
        if let uv = today?.uvIndex {
            tiles.append(("UV指数", "sun.max", "\(Int(uv.rounded()))", WeatherFormat.uv(uv)))
        }
        if let sum = today?.precipitationSum {
            tiles.append(("降水量", "drop.fill", String(format: "%.1fmm", sum), "今日の合計"))
        }
        if let sunrise = today?.sunrise {
            tiles.append(("日の出", "sunrise.fill", WeatherFormat.time(sunrise, report.zone, "H:mm"), nil))
        }
        if let sunset = today?.sunset {
            tiles.append(("日の入", "sunset.fill", WeatherFormat.time(sunset, report.zone, "H:mm"), nil))
        }
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(tiles, id: \.0) { tile in
                WeatherCard(title: tile.0, symbol: tile.1) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tile.2)
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Text(tile.3 ?? " ")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var credits: some View {
        VStack(spacing: 6) {
            Link("天気データ: Open-Meteo.com（CC BY 4.0）", destination: URL(string: "https://open-meteo.com/")!)
            Link("雨雲レーダー: 気象庁 降水ナウキャスト", destination: URL(string: "https://www.jma.go.jp/bosai/nowc/")!)
            Link("地図: 地理院タイル（国土地理院）", destination: URL(string: "https://maps.gsi.go.jp/development/ichiran.html")!)
            if !clientID.isEmpty {
                Link("Webサービス by Yahoo! JAPAN", destination: YahooWeather.creditURL)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.top, 6)
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
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, end - start))
                    .offset(x: start)
                if let current {
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                        .frame(width: 7, height: 7)
                        .offset(x: min(width - 7, max(0, (current - low) / span * width - 3.5)))
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
            .foregroundStyle(point.forecast ? Color.blue : Color.blue.opacity(0.45))
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

private struct RadarTimeLabel: View {
    let frame: RadarFrame?

    var body: some View {
        if let frame {
            HStack(spacing: 6) {
                Text(WeatherFormat.time(frame.date, .current, "H:mm"))
                    .monospacedDigit()
                Text(frame.forecast ? "予測" : "実況")
                    .foregroundStyle(frame.forecast ? Color.orange : Color.secondary)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(.regularMaterial, in: Capsule())
        }
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
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color(hex: step.1))
                        .frame(height: 6)
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
    }
}

struct RadarScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var radar: RadarModel
    let center: CLLocationCoordinate2D?

    var body: some View {
        ZStack(alignment: .bottom) {
            RadarMapView(frames: radar.frames, index: radar.index, center: center, interactive: true)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        Haptics.play(.light)
                        radar.toggle()
                    } label: {
                        Image(systemName: radar.playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .accessibilityLabel(radar.playing ? "一時停止" : "再生")
                    if radar.frames.count > 1 {
                        Slider(
                            value: Binding(
                                get: { Double(radar.index) },
                                set: { value in
                                    radar.stop()
                                    radar.index = Int(value.rounded())
                                }
                            ),
                            in: 0...Double(radar.frames.count - 1),
                            step: 1
                        )
                    }
                    RadarTimeLabel(frame: radar.current)
                }
                RadarLegend()
                Text("出典：気象庁 降水ナウキャスト・地理院タイル")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .topLeading) {
            WeatherBarButton(symbol: "xmark", label: "閉じる") { dismiss() }
                .padding(.leading, 16)
                .padding(.top, 8)
        }
    }
}

final class RadarOverlay: MKTileOverlay {
    var index = 0
}

final class BaseMapOverlay: MKTileOverlay {}

struct RadarMapView: UIViewRepresentable {
    let frames: [RadarFrame]
    let index: Int
    let center: CLLocationCoordinate2D?
    let interactive: Bool

    private static let alpha: CGFloat = 0.8

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        map.pointOfInterestFilter = .excludingAll
        map.showsUserLocation = true
        map.isUserInteractionEnabled = interactive
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.cameraZoomRange = MKMapView.CameraZoomRange(minCenterCoordinateDistance: 40_000, maxCenterCoordinateDistance: 4_000_000)
        let base = BaseMapOverlay(urlTemplate: "https://cyberjapandata.gsi.go.jp/xyz/pale/{z}/{x}/{y}.png")
        base.minimumZ = 2
        base.maximumZ = 18
        base.canReplaceMapContent = true
        map.addOverlay(base, level: .aboveRoads)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        if let center, coordinator.centered.map({ abs($0.latitude - center.latitude) > 0.0001 || abs($0.longitude - center.longitude) > 0.0001 }) ?? true {
            coordinator.centered = center
            map.setRegion(MKCoordinateRegion(center: center, latitudinalMeters: 160_000, longitudinalMeters: 160_000), animated: false)
        }
        let ids = frames.map(\.id)
        if coordinator.frameIDs != ids {
            map.removeOverlays(map.overlays.filter { $0 is RadarOverlay })
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
            renderer.alpha = position == index ? Self.alpha : 0
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var frameIDs: [String] = []
        var renderers: [Int: MKTileOverlayRenderer] = [:]
        var index = 0
        var centered: CLLocationCoordinate2D?

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let base = overlay as? BaseMapOverlay {
                return MKTileOverlayRenderer(tileOverlay: base)
            }
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
                Section("データ") {
                    Link("Open-Meteo.com（CC BY 4.0）", destination: URL(string: "https://open-meteo.com/")!)
                    Link("気象庁 降水ナウキャスト", destination: URL(string: "https://www.jma.go.jp/bosai/nowc/")!)
                    Link("地理院タイル（国土地理院）", destination: URL(string: "https://maps.gsi.go.jp/development/ichiran.html")!)
                    Link("Webサービス by Yahoo! JAPAN", destination: YahooWeather.creditURL)
                }
                .font(.footnote)
            }
            .navigationTitle("天気の設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
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

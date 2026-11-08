import CoreLocation
import SwiftUI
import WidgetKit

private func temperature(_ value: Double, unit: CGFloat) -> Text {
    Text("\(Int(value.rounded()))\(Text("℃").font(.system(size: unit)))")
}

struct WeatherEntry: TimelineEntry {
    var date: Date
    var report: WeatherReport?
    var message: String?
}

struct WeatherProvider: TimelineProvider {
    private static let latitudeKey = "widget-latitude"
    private static let longitudeKey = "widget-longitude"
    private static let reportKey = "widget-report"

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), report: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        if context.isPreview {
            completion(WeatherEntry(date: Date(), report: Self.cached ?? Self.sample))
            return
        }
        Task { completion(await Self.load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        Task {
            let entry = await Self.load()
            let next = Date(timeIntervalSinceNow: entry.report == nil ? 15 * 60 : 30 * 60)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private static var cached: WeatherReport? {
        guard let data = UserDefaults.standard.data(forKey: reportKey) else { return nil }
        return try? JSONDecoder().decode(WeatherReport.self, from: data)
    }

    private static func load() async -> WeatherEntry {
        let defaults = UserDefaults.standard
        let location = await MainActor.run { OneShotLocation() }
        var coordinate = await location.request(ask: false)?.coordinate
        if let coordinate {
            defaults.set(coordinate.latitude, forKey: latitudeKey)
            defaults.set(coordinate.longitude, forKey: longitudeKey)
        } else if defaults.object(forKey: latitudeKey) != nil {
            coordinate = CLLocationCoordinate2D(latitude: defaults.double(forKey: latitudeKey), longitude: defaults.double(forKey: longitudeKey))
        }
        guard let coordinate else {
            return WeatherEntry(date: Date(), report: nil, message: "位置情報を許可")
        }
        do {
            let report = try await OpenMeteo.fetch(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let data = try? JSONEncoder().encode(report) { defaults.set(data, forKey: reportKey) }
            return WeatherEntry(date: Date(), report: report)
        } catch {
            if let cached, Calendar.current.isDateInToday(cached.fetchedAt) {
                return WeatherEntry(date: Date(), report: cached)
            }
            return WeatherEntry(date: Date(), report: nil, message: "取得できません")
        }
    }

    static let sample = WeatherReport(
        fetchedAt: Date(),
        timeZone: TimeZone.current.identifier,
        current: WeatherCurrent(temperature: 15, apparent: 13, humidity: 55, code: 2, isDay: true, windSpeed: 2, windDirection: 0, pressure: 1015, precipitation: 0),
        hours: [],
        days: [WeatherDay(date: Date(), code: 2, high: 19, low: 9, humidity: 60)]
    )
}

private struct WeatherValues {
    let symbol: String
    let label: String
    let humidity: Int
    let low: Double
    let high: Double
    let current: Double

    init?(_ report: WeatherReport?) {
        guard let report, let today = report.today else { return nil }
        symbol = WeatherCondition.symbol(today.code)
        label = WeatherCondition.label(today.code)
        humidity = today.humidity ?? report.current.humidity
        current = report.current.temperature
        low = min(today.low, current)
        high = max(today.high, current)
    }
}

struct WeatherRectangularView: View {
    let entry: WeatherEntry

    var body: some View {
        if let values = WeatherValues(entry.report) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: values.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .accessibilityLabel(values.label)
                    HStack(spacing: 2) {
                        Image(systemName: "humidity.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("\(values.humidity)%")
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("湿度 \(values.humidity)%")
                    Spacer(minLength: 0)
                }
                Gauge(value: values.current, in: values.low...max(values.low + 0.1, values.high)) {
                    Text("気温")
                } currentValueLabel: {
                    temperature(values.current, unit: 9)
                } minimumValueLabel: {
                    temperature(values.low, unit: 8)
                } maximumValueLabel: {
                    temperature(values.high, unit: 8)
                }
                .gaugeStyle(.accessoryLinear)
            }
        } else {
            Label(entry.message ?? "読み込み中", systemImage: "location.slash")
                .font(.system(size: 14, weight: .semibold))
        }
    }
}

struct WeatherCircularView: View {
    let entry: WeatherEntry

    var body: some View {
        if let values = WeatherValues(entry.report) {
            Gauge(value: values.current, in: values.low...max(values.low + 0.1, values.high)) {
                Image(systemName: values.symbol)
            } currentValueLabel: {
                temperature(values.current, unit: 9)
            } minimumValueLabel: {
                temperature(values.low, unit: 8)
            } maximumValueLabel: {
                temperature(values.high, unit: 8)
            }
            .gaugeStyle(.accessoryCircular)
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "location.slash")
            }
        }
    }
}

struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                WeatherCircularView(entry: entry)
            default:
                WeatherRectangularView(entry: entry)
            }
        }
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "pokefire://weather"))
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "me.ffui.pokefire.weather", provider: WeatherProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("Weather")
        .description("現在地の今日の天気・平均湿度・最低／最高気温と今の気温を表示します。")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

@main
struct PokelootWidgets: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
    }
}

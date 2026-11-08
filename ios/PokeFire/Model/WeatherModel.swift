import BackgroundTasks
import CoreLocation
import Foundation
import MapKit
import Observation
import UIKit
import UserNotifications

struct WeatherPlace: Codable, Equatable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

struct RainPoint: Identifiable, Equatable {
    var date: Date
    var rainfall: Double
    var forecast: Bool

    var id: Date { date }
}

enum RainLevel {
    static func label(_ rainfall: Double) -> String {
        switch rainfall {
        case ..<1: return "小雨"
        case ..<3: return "弱い雨"
        case ..<10: return "雨"
        case ..<20: return "やや強い雨"
        case ..<30: return "強い雨"
        case ..<50: return "激しい雨"
        case ..<80: return "非常に激しい雨"
        default: return "猛烈な雨"
        }
    }
}

struct Nowcast: Equatable {
    var points: [RainPoint]

    var now: RainPoint? { points.last { !$0.forecast } }
    var forecast: [RainPoint] { points.filter(\.forecast) }
    var timeline: [RainPoint] { (now.map { [$0] } ?? []) + forecast }

    private func minutes(_ point: RainPoint) -> Int {
        max(0, Int(((point.date.timeIntervalSince(now?.date ?? Date())) / 60).rounded()))
    }

    var startsIn: (minutes: Int, peak: Double)? {
        guard (now?.rainfall ?? 0) <= 0, let first = forecast.first(where: { $0.rainfall > 0 }) else { return nil }
        return (minutes(first), forecast.map(\.rainfall).max() ?? first.rainfall)
    }

    var summary: String {
        let current = now?.rainfall ?? 0
        let peak = forecast.map(\.rainfall).max() ?? 0
        if current > 0 {
            if let stop = forecast.first(where: { $0.rainfall <= 0 }) {
                return "\(RainLevel.label(current))が降っています。\(minutes(stop))分後にやむ見込みです。"
            }
            return "この先1時間は\(RainLevel.label(max(current, peak)))が続く見込みです。"
        }
        if let start = startsIn {
            return "雨雲が近づいています。\(start.minutes)分後に\(RainLevel.label(start.peak))が降り始める見込みです。"
        }
        return "この先1時間は雨の心配はありません。"
    }
}

enum YahooWeather {
    static let idKey = "weather-yahoo-id"
    static let registerURL = URL(string: "https://e.developer.yahoo.co.jp/register")!
    static let creditURL = URL(string: "https://developer.yahoo.co.jp/sitemap/")!

    static var clientID: String {
        (UserDefaults.standard.string(forKey: idKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct Item: Decodable {
        let kind: String
        let date: String
        let rainfall: Double

        enum CodingKeys: String, CodingKey {
            case kind = "Type"
            case date = "Date"
            case rainfall = "Rainfall"
        }
    }

    private struct List: Decodable {
        let items: [Item]

        enum CodingKeys: String, CodingKey {
            case items = "Weather"
        }
    }

    private struct Property: Decodable {
        let list: List

        enum CodingKeys: String, CodingKey {
            case list = "WeatherList"
        }
    }

    private struct Feature: Decodable {
        let property: Property

        enum CodingKeys: String, CodingKey {
            case property = "Property"
        }
    }

    private struct Response: Decodable {
        let features: [Feature]?

        enum CodingKeys: String, CodingKey {
            case features = "Feature"
        }
    }

    static func fetch(_ coordinate: CLLocationCoordinate2D) async throws -> Nowcast {
        let id = clientID
        guard !id.isEmpty else { throw URLError(.userAuthenticationRequired) }
        var components = URLComponents(string: "https://map.yahooapis.jp/weather/V1/place")!
        components.queryItems = [
            URLQueryItem(name: "appid", value: id),
            URLQueryItem(name: "coordinates", value: String(format: "%.6f,%.6f", coordinate.longitude, coordinate.latitude)),
            URLQueryItem(name: "output", value: "json"),
            URLQueryItem(name: "past", value: "1"),
            URLQueryItem(name: "interval", value: "10"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        let raw = try JSONDecoder().decode(Response.self, from: data)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")
        formatter.dateFormat = "yyyyMMddHHmm"
        let items = raw.features?.first?.property.list.items ?? []
        return Nowcast(points: items.compactMap { item in
            formatter.date(from: item.date).map { RainPoint(date: $0, rainfall: item.rainfall, forecast: item.kind == "forecast") }
        })
    }
}

struct RadarFrame: Equatable, Identifiable {
    var base: String
    var valid: String
    var date: Date
    var forecast: Bool

    var id: String { base + valid }

    var template: String {
        "https://www.jma.go.jp/bosai/jmatile/data/nowc/\(base)/none/\(valid)/surf/hrpns/{z}/{x}/{y}.png"
    }
}

enum JMARadar {
    private struct Time: Decodable {
        let basetime: String
        let validtime: String
    }

    static func frames() async throws -> [RadarFrame] {
        async let past = list("N1")
        async let future = list("N2")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMddHHmmss"
        func make(_ time: Time, _ forecast: Bool) -> RadarFrame? {
            formatter.date(from: time.validtime).map { RadarFrame(base: time.basetime, valid: time.validtime, date: $0, forecast: forecast) }
        }
        let observed = try await past.compactMap { make($0, false) }.sorted { $0.date < $1.date }
        let predicted = try await future.compactMap { make($0, true) }.sorted { $0.date < $1.date }
        let latest = observed.last?.date ?? Date()
        let recent = observed.filter { latest.timeIntervalSince($0.date) <= 3600 }
        return recent + predicted.filter { $0.date > latest }
    }

    private static func list(_ name: String) async throws -> [Time] {
        let url = URL(string: "https://www.jma.go.jp/bosai/jmatile/data/nowc/targetTimes_\(name).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Time].self, from: data)
    }
}

@Observable
@MainActor
final class WeatherStore {
    static let shared = WeatherStore()
    static let placesKey = "weather-places"
    static let selectionKey = "weather-selection"
    static let latitudeKey = "weather-last-latitude"
    static let longitudeKey = "weather-last-longitude"

    var places: [WeatherPlace] = []
    var selection: UUID?
    var here: CLLocation?
    var hereName = "現在地"
    var locationDenied = false
    var report: WeatherReport?
    var nowcast: Nowcast?
    var nowcastError: String?
    var loading = false
    var error: String?
    @ObservationIgnored private let locator = OneShotLocation()
    @ObservationIgnored private var task: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.placesKey),
           let list = try? JSONDecoder().decode([WeatherPlace].self, from: data) {
            places = list
        }
        if let text = UserDefaults.standard.string(forKey: Self.selectionKey), let id = UUID(uuidString: text), places.contains(where: { $0.id == id }) {
            selection = id
        }
    }

    var selected: WeatherPlace? { places.first { $0.id == selection } }
    var title: String { selected?.name ?? hereName }

    var coordinate: CLLocationCoordinate2D? {
        selected?.coordinate ?? here?.coordinate
    }

    private func savePlaces() {
        if let data = try? JSONEncoder().encode(places) {
            UserDefaults.standard.set(data, forKey: Self.placesKey)
        }
    }

    func select(_ id: UUID?) {
        guard selection != id else { return }
        selection = id
        UserDefaults.standard.set(id?.uuidString, forKey: Self.selectionKey)
        report = nil
        nowcast = nil
        refresh()
    }

    func add(_ place: WeatherPlace) {
        places.append(place)
        savePlaces()
        select(place.id)
    }

    func remove(at offsets: IndexSet) {
        let removed = offsets.map { places[$0].id }
        places.remove(atOffsets: offsets)
        savePlaces()
        if let selection, removed.contains(selection) { select(nil) }
    }

    func move(from source: IndexSet, to destination: Int) {
        places.move(fromOffsets: source, toOffset: destination)
        savePlaces()
    }

    func refresh() {
        task?.cancel()
        task = Task { [weak self] in await self?.load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        if selected == nil {
            if let location = await locator.request(ask: true) {
                here = location
                locationDenied = false
                UserDefaults.standard.set(location.coordinate.latitude, forKey: Self.latitudeKey)
                UserDefaults.standard.set(location.coordinate.longitude, forKey: Self.longitudeKey)
                Task { await self.name(location) }
            } else {
                locationDenied = !locator.isAuthorized
                if here == nil {
                    error = locationDenied ? "位置情報の利用が許可されていません。設定アプリで許可するか、地点を登録してください。" : "現在地を取得できませんでした。"
                    return
                }
            }
        }
        guard let coordinate else { return }
        async let weather = OpenMeteo.fetch(latitude: coordinate.latitude, longitude: coordinate.longitude)
        async let rain = loadNowcast(coordinate)
        do {
            report = try await weather
        } catch {
            if !Task.isCancelled { self.error = "天気を取得できませんでした。\n\(error.localizedDescription)" }
        }
        await rain
    }

    private func loadNowcast(_ coordinate: CLLocationCoordinate2D) async {
        guard !YahooWeather.clientID.isEmpty else {
            nowcast = nil
            nowcastError = nil
            return
        }
        do {
            nowcast = try await YahooWeather.fetch(coordinate)
            nowcastError = nil
        } catch {
            nowcast = nil
            nowcastError = "降水予報を取得できませんでした。Client ID を確認してください。"
        }
    }

    private func name(_ location: CLLocation) async {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP")).first else { return }
        let parts = [placemark.locality, placemark.subLocality].compactMap { $0 }
        if !parts.isEmpty { hereName = parts.joined(separator: " ") }
    }
}

enum RadarSampler {
    private static let zoom = 10
    private static let palette: [(UInt32, Double)] = [
        (0xF2F2FF, 0.5), (0xA0D2FF, 3), (0x218CFF, 7.5), (0x0041FF, 15),
        (0xFAF500, 25), (0xFF9900, 40), (0xFF2800, 65), (0xB40068, 90),
    ]

    static func rainfall(_ frame: RadarFrame, at coordinate: CLLocationCoordinate2D) async -> Double {
        let scale = pow(2.0, Double(zoom))
        let x = (coordinate.longitude + 180) / 360 * scale
        let latitude = coordinate.latitude * .pi / 180
        let y = (1 - log(tan(latitude) + 1 / cos(latitude)) / .pi) / 2 * scale
        let tileX = Int(x.rounded(.down))
        let tileY = Int(y.rounded(.down))
        let path = frame.template
            .replacingOccurrences(of: "{z}", with: String(zoom))
            .replacingOccurrences(of: "{x}", with: String(tileX))
            .replacingOccurrences(of: "{y}", with: String(tileY))
        guard let url = URL(string: path),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data)?.cgImage else { return 0 }
        let pixelX = min(image.width - 1, max(0, Int((x - Double(tileX)) * Double(image.width))))
        let pixelY = min(image.height - 1, max(0, Int((y - Double(tileY)) * Double(image.height))))
        guard let color = pixel(image, pixelX, pixelY) else { return 0 }
        return value(color)
    }

    private static func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (Int, Int, Int, Int)? {
        var bytes = [UInt8](repeating: 0, count: 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: -CGFloat(x), y: -CGFloat(image.height - 1 - y), width: CGFloat(image.width), height: CGFloat(image.height)))
            return true
        }
        guard drawn else { return nil }
        let alpha = Int(bytes[3])
        guard alpha > 40 else { return (0, 0, 0, 0) }
        func channel(_ value: UInt8) -> Int { min(255, Int(value) * 255 / alpha) }
        return (channel(bytes[0]), channel(bytes[1]), channel(bytes[2]), alpha)
    }

    private static func value(_ color: (Int, Int, Int, Int)) -> Double {
        guard color.3 > 40 else { return 0 }
        var best = 0.0
        var distance = Int.max
        for (hex, amount) in palette {
            let r = Int((hex >> 16) & 0xFF) - color.0
            let g = Int((hex >> 8) & 0xFF) - color.1
            let b = Int(hex & 0xFF) - color.2
            let d = r * r + g * g + b * b
            if d < distance {
                distance = d
                best = amount
            }
        }
        return best
    }
}

@Observable
@MainActor
final class RadarModel {
    var frames: [RadarFrame] = []
    var index = 0
    var nowIndex = 0
    var playing = false
    var failed = false
    var rain: [String: Double] = [:]
    var sampling = false
    @ObservationIgnored private var player: Task<Void, Never>?
    @ObservationIgnored private var sampledKey = ""

    var current: RadarFrame? { frames.indices.contains(index) ? frames[index] : nil }

    func rainfall(_ position: Int) -> Double? {
        guard frames.indices.contains(position) else { return nil }
        return rain[frames[position].id]
    }

    func load() async {
        do {
            let list = try await JMARadar.frames()
            let wasNow = index == nowIndex
            frames = list
            nowIndex = list.lastIndex { !$0.forecast } ?? 0
            if wasNow || !frames.indices.contains(index) { index = nowIndex }
            failed = false
        } catch {
            failed = frames.isEmpty
        }
    }

    func sample(_ coordinate: CLLocationCoordinate2D?) async {
        guard let coordinate, !frames.isEmpty else { return }
        let key = String(format: "%.3f,%.3f|", coordinate.latitude, coordinate.longitude) + (frames.last?.id ?? "")
        guard key != sampledKey else { return }
        sampledKey = key
        sampling = true
        defer { sampling = false }
        let list = frames
        var result: [String: Double] = [:]
        await withTaskGroup(of: (String, Double).self) { group in
            for frame in list {
                group.addTask { (frame.id, await RadarSampler.rainfall(frame, at: coordinate)) }
            }
            for await (id, value) in group {
                result[id] = value
            }
        }
        rain = result
    }

    func toggle() {
        playing ? stop() : play()
    }

    func play() {
        guard frames.count > 1 else { return }
        playing = true
        player?.cancel()
        player = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled, self.playing {
                try? await Task.sleep(for: .milliseconds(self.index == self.frames.count - 1 ? 1200 : 380))
                guard !Task.isCancelled, self.playing else { return }
                self.index = (self.index + 1) % self.frames.count
            }
        }
    }

    func stop() {
        playing = false
        player?.cancel()
        player = nil
    }

    func returnToNow() {
        stop()
        index = nowIndex
    }
}

enum WeatherAlerts {
    static let taskID = "me.ffui.pokefire.weather-refresh"
    static let enabledKey = "weather-notify"
    private static let lastKey = "weather-notified-at"

    static var enabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func schedule() {
        guard enabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskID)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func check() async {
        let defaults = UserDefaults.standard
        guard enabled, !YahooWeather.clientID.isEmpty,
              defaults.object(forKey: WeatherStore.latitudeKey) != nil else { return }
        let coordinate = CLLocationCoordinate2D(
            latitude: defaults.double(forKey: WeatherStore.latitudeKey),
            longitude: defaults.double(forKey: WeatherStore.longitudeKey)
        )
        guard let nowcast = try? await YahooWeather.fetch(coordinate), let start = nowcast.startsIn else { return }
        let last = defaults.double(forKey: lastKey)
        if last > 0, Date().timeIntervalSince1970 - last < 90 * 60 { return }
        let content = UNMutableNotificationContent()
        content.title = "雨雲が近づいています"
        content.body = start.minutes <= 5
            ? "まもなく\(RainLevel.label(start.peak))が降り始める見込みです。"
            : "\(start.minutes)分後に\(RainLevel.label(start.peak))が降り始める見込みです（最大\(String(format: "%.1f", start.peak))mm/h）。"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "weather-rain", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        defaults.set(Date().timeIntervalSince1970, forKey: lastKey)
    }
}

enum PlaceSearch {
    static func search(_ query: String) async -> [WeatherPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.compactMap { item in
            let coordinate = item.placemark.coordinate
            return WeatherPlace(name: item.name ?? query, latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    static func subtitle(_ place: WeatherPlace) -> String {
        String(format: "%.3f, %.3f", place.latitude, place.longitude)
    }
}

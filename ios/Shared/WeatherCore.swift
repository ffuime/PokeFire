import CoreLocation
import Foundation

struct WeatherCurrent: Codable, Equatable {
    var temperature: Double
    var apparent: Double
    var humidity: Int
    var code: Int
    var isDay: Bool
    var windSpeed: Double
    var windDirection: Double
    var pressure: Double
    var precipitation: Double
}

struct WeatherHour: Codable, Equatable, Identifiable {
    var time: Date
    var temperature: Double
    var code: Int
    var isDay: Bool
    var precipitationProbability: Int?

    var id: Date { time }
}

struct WeatherDay: Codable, Equatable, Identifiable {
    var date: Date
    var code: Int
    var high: Double
    var low: Double
    var sunrise: Date?
    var sunset: Date?
    var uvIndex: Double?
    var precipitationProbability: Int?
    var precipitationSum: Double?
    var humidity: Int?

    var id: Date { date }
}

struct WeatherReport: Codable, Equatable {
    var fetchedAt: Date
    var timeZone: String
    var current: WeatherCurrent
    var hours: [WeatherHour]
    var days: [WeatherDay]
    var yesterday: WeatherDay?

    var zone: TimeZone { TimeZone(identifier: timeZone) ?? .current }
    var today: WeatherDay? { days.first }

    func upcomingHours(_ count: Int = 24, from now: Date = Date()) -> [WeatherHour] {
        let start = now.addingTimeInterval(-3600)
        return Array(hours.filter { $0.time > start }.prefix(count))
    }
}

enum WeatherCondition {
    static func label(_ code: Int) -> String {
        switch code {
        case 0: return "快晴"
        case 1: return "晴れ"
        case 2: return "晴れ時々曇り"
        case 3: return "曇り"
        case 45, 48: return "霧"
        case 51, 53, 55: return "霧雨"
        case 56, 57: return "着氷性の霧雨"
        case 61: return "弱い雨"
        case 63: return "雨"
        case 65: return "強い雨"
        case 66, 67: return "みぞれ"
        case 71: return "弱い雪"
        case 73: return "雪"
        case 75: return "強い雪"
        case 77: return "霧雪"
        case 80, 81: return "にわか雨"
        case 82: return "激しいにわか雨"
        case 85, 86: return "にわか雪"
        case 95: return "雷雨"
        case 96, 99: return "雷雨（ひょう）"
        default: return "不明"
        }
    }

    static func symbol(_ code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "sun.max.fill" : "moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

enum WeatherFormat {
    static func degree(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    static func time(_ date: Date, _ zone: TimeZone, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    static func wind(_ degrees: Double) -> String {
        let names = ["北", "北北東", "北東", "東北東", "東", "東南東", "南東", "南南東", "南", "南南西", "南西", "西南西", "西", "西北西", "北西", "北北西"]
        let index = Int((degrees / 22.5).rounded()) % 16
        return names[(index + 16) % 16]
    }

    static func uv(_ value: Double) -> String {
        switch value {
        case ..<3: return "弱い"
        case ..<6: return "中程度"
        case ..<8: return "強い"
        case ..<11: return "非常に強い"
        default: return "極端に強い"
        }
    }
}

enum OpenMeteo {
    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature2m: Double?
            let apparentTemperature: Double?
            let relativeHumidity2m: Double?
            let weatherCode: Int?
            let isDay: Int?
            let windSpeed10m: Double?
            let windDirection10m: Double?
            let surfacePressure: Double?
            let precipitation: Double?

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
                case apparentTemperature = "apparent_temperature"
                case relativeHumidity2m = "relative_humidity_2m"
                case weatherCode = "weather_code"
                case isDay = "is_day"
                case windSpeed10m = "wind_speed_10m"
                case windDirection10m = "wind_direction_10m"
                case surfacePressure = "surface_pressure"
                case precipitation
            }
        }

        struct Hourly: Decodable {
            let time: [String]
            let temperature2m: [Double?]
            let weatherCode: [Int?]
            let isDay: [Int?]
            let precipitationProbability: [Double?]

            enum CodingKeys: String, CodingKey {
                case time
                case temperature2m = "temperature_2m"
                case weatherCode = "weather_code"
                case isDay = "is_day"
                case precipitationProbability = "precipitation_probability"
            }
        }

        struct Daily: Decodable {
            let time: [String]
            let weatherCode: [Int?]
            let temperature2mMax: [Double?]
            let temperature2mMin: [Double?]
            let sunrise: [String?]
            let sunset: [String?]
            let uvIndexMax: [Double?]
            let precipitationProbabilityMax: [Double?]
            let precipitationSum: [Double?]
            let relativeHumidity2mMean: [Double?]

            enum CodingKeys: String, CodingKey {
                case time
                case weatherCode = "weather_code"
                case temperature2mMax = "temperature_2m_max"
                case temperature2mMin = "temperature_2m_min"
                case sunrise
                case sunset
                case uvIndexMax = "uv_index_max"
                case precipitationProbabilityMax = "precipitation_probability_max"
                case precipitationSum = "precipitation_sum"
                case relativeHumidity2mMean = "relative_humidity_2m_mean"
            }
        }

        let timezone: String
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    static func fetch(latitude: Double, longitude: Double) async throws -> WeatherReport {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m,wind_direction_10m,surface_pressure,precipitation"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day,precipitation_probability"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max,precipitation_sum,relative_humidity_2m_mean"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "10"),
            URLQueryItem(name: "past_days", value: "1"),
            URLQueryItem(name: "wind_speed_unit", value: "ms"),
        ]
        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        let raw = try JSONDecoder().decode(Response.self, from: data)
        let zone = TimeZone(identifier: raw.timezone) ?? .current
        let minute = formatter("yyyy-MM-dd'T'HH:mm", zone)
        let day = formatter("yyyy-MM-dd", zone)

        let current = WeatherCurrent(
            temperature: raw.current.temperature2m ?? 0,
            apparent: raw.current.apparentTemperature ?? raw.current.temperature2m ?? 0,
            humidity: Int((raw.current.relativeHumidity2m ?? 0).rounded()),
            code: raw.current.weatherCode ?? 0,
            isDay: (raw.current.isDay ?? 1) == 1,
            windSpeed: raw.current.windSpeed10m ?? 0,
            windDirection: raw.current.windDirection10m ?? 0,
            pressure: raw.current.surfacePressure ?? 0,
            precipitation: raw.current.precipitation ?? 0
        )

        let hours: [WeatherHour] = raw.hourly.time.enumerated().compactMap { index, text in
            guard let time = minute.date(from: text) else { return nil }
            return WeatherHour(
                time: time,
                temperature: value(raw.hourly.temperature2m, index) ?? 0,
                code: value(raw.hourly.weatherCode, index) ?? 0,
                isDay: (value(raw.hourly.isDay, index) ?? 1) == 1,
                precipitationProbability: value(raw.hourly.precipitationProbability, index).map { Int($0.rounded()) }
            )
        }

        let allDays: [WeatherDay] = raw.daily.time.enumerated().compactMap { index, text in
            guard let date = day.date(from: text) else { return nil }
            return WeatherDay(
                date: date,
                code: value(raw.daily.weatherCode, index) ?? 0,
                high: value(raw.daily.temperature2mMax, index) ?? 0,
                low: value(raw.daily.temperature2mMin, index) ?? 0,
                sunrise: value(raw.daily.sunrise, index).flatMap { minute.date(from: $0) },
                sunset: value(raw.daily.sunset, index).flatMap { minute.date(from: $0) },
                uvIndex: value(raw.daily.uvIndexMax, index),
                precipitationProbability: value(raw.daily.precipitationProbabilityMax, index).map { Int($0.rounded()) },
                precipitationSum: value(raw.daily.precipitationSum, index),
                humidity: value(raw.daily.relativeHumidity2mMean, index).map { Int($0.rounded()) }
            )
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.startOfDay(for: Date())
        let days = allDays.filter { $0.date >= start }
        let yesterday = allDays.last { $0.date < start }
        return WeatherReport(fetchedAt: Date(), timeZone: raw.timezone, current: current, hours: hours, days: days, yesterday: yesterday)
    }

    private static func value<T>(_ list: [T?], _ index: Int) -> T? {
        list.indices.contains(index) ? list[index] : nil
    }

    private static func formatter(_ format: String, _ zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = zone
        formatter.dateFormat = format
        return formatter
    }
}

@MainActor
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?
    private var authorization: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var status: CLAuthorizationStatus { manager.authorizationStatus }

    var isAuthorized: Bool {
        status == .authorizedWhenInUse || status == .authorizedAlways
    }

    func request(ask: Bool) async -> CLLocation? {
        if status == .notDetermined, ask {
            await withCheckedContinuation { continuation in
                authorization = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        guard isAuthorized else { return nil }
        if let recent = manager.location, -recent.timestamp.timeIntervalSinceNow < 300 { return recent }
        return await withCheckedContinuation { continuation in
            self.continuation?.resume(returning: nil)
            self.continuation = continuation
            manager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(12))
                self?.finish(self?.manager.location)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let last = locations.last
        Task { @MainActor in self.finish(last) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(self.manager.location) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            guard self.manager.authorizationStatus != .notDetermined else { return }
            self.authorization?.resume()
            self.authorization = nil
        }
    }
}

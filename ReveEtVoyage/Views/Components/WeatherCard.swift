import SwiftUI

// MARK: - WeatherCard

/// Animated weather card showing current temp + 5-day forecast.
/// Background gradient adapts to current weather (sun/cloud/rain/snow/storm/fog/night).
struct WeatherCard: View {
    let weather: WeatherResponse?
    let locationLabel: String?
    let isLoading: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            cardGradient
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Météo en cours…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(16)
            } else if let current = weather?.current {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            if let label = locationLabel, !label.isEmpty {
                                Text(label)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Text("\(Int((current.temp ?? 0).rounded()))°")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(weatherLabel(current.code))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                            if let fl = current.feels_like {
                                Text("Ressenti \(Int(fl.rounded()))°")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                        Spacer()
                        AnimatedWeatherIcon(code: current.code, isDay: current.is_day ?? true, size: 72)
                    }

                    if let forecast = weather?.forecast, !forecast.isEmpty {
                        HStack(alignment: .center, spacing: 4) {
                            ForEach(forecast.prefix(5)) { day in
                                ForecastDayView(day: day)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(16)
            } else {
                Text("Météo indisponible")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var cardGradient: LinearGradient {
        let colors = gradientColors(for: weatherType(code: weather?.current?.code, isDay: weather?.current?.is_day ?? true))
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Forecast day cell

private struct ForecastDayView: View {
    let day: WeatherDay

    var body: some View {
        VStack(spacing: 4) {
            Text(shortDow(day.date))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            AnimatedWeatherIcon(code: day.code, isDay: true, size: 24)
            Text("\(Int((day.temp_max ?? 0).rounded()))°")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("\(Int((day.temp_min ?? 0).rounded()))°")
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
        }
    }
}

// MARK: - Animated SF Symbol icon

struct AnimatedWeatherIcon: View {
    let code: Int?
    let isDay: Bool
    let size: CGFloat

    @State private var pulse: Bool = false
    @State private var rainOffset: CGFloat = 0
    @State private var rotate: Double = 0

    var body: some View {
        ZStack {
            switch weatherType(code: code, isDay: isDay) {
            case .sun:
                Image(systemName: "sun.max.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.31))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotate))
                    .scaleEffect(pulse ? 1.05 : 0.95)
                    .onAppear {
                        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { rotate = 360 }
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
                    }

            case .moon:
                Image(systemName: "moon.stars.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.91))
                    .frame(width: size, height: size)
                    .scaleEffect(pulse ? 1.04 : 0.96)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) { pulse = true }
                    }

            case .cloud:
                Image(systemName: "cloud.fill")
                    .resizable().scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.95))
                    .frame(width: size, height: size)
                    .offset(x: pulse ? 3 : -3)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { pulse = true }
                    }

            case .rain:
                Image(systemName: "cloud.rain.fill")
                    .resizable().scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .onAppear {
                        if #available(iOS 17.0, *) {
                            // Symbol effect handled via modifier below
                        }
                    }
                    .modifier(SymbolBounceIfAvailable())

            case .snow:
                Image(systemName: "cloud.snow.fill")
                    .resizable().scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotate))
                    .onAppear {
                        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) { rotate = 360 }
                    }

            case .storm:
                Image(systemName: "cloud.bolt.rain.fill")
                    .resizable().scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .opacity(pulse ? 1.0 : 0.55)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
                    }

            case .fog:
                Image(systemName: "cloud.fog.fill")
                    .resizable().scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.white)
                    .frame(width: size, height: size)
                    .offset(x: pulse ? 4 : -4)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) { pulse = true }
                    }
            }
        }
    }
}

private struct SymbolBounceIfAvailable: ViewModifier {
    @State private var trigger: Int = 0

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .symbolEffect(.bounce, options: .repeating, value: trigger)
                .onAppear { trigger = 1 }
        } else {
            content
        }
    }
}

// MARK: - Mappings

enum WeatherType { case sun, moon, cloud, rain, snow, storm, fog }

func weatherType(code: Int?, isDay: Bool) -> WeatherType {
    guard let code = code else { return isDay ? .sun : .moon }
    switch code {
    case 0, 1, 2:          return isDay ? .sun : .moon
    case 3:                return .cloud
    case 45, 48:           return .fog
    case 51...67, 80...82: return .rain
    case 71...77, 85, 86:  return .snow
    case 95...99:          return .storm
    default:               return .cloud
    }
}

func gradientColors(for type: WeatherType) -> [Color] {
    switch type {
    case .sun:   return [Color(red: 1.00, green: 0.70, blue: 0.28), Color(red: 1.00, green: 0.44, blue: 0.26)]
    case .moon:  return [Color(red: 0.25, green: 0.30, blue: 0.47), Color(red: 0.10, green: 0.13, blue: 0.22)]
    case .cloud: return [Color(red: 0.47, green: 0.57, blue: 0.62), Color(red: 0.27, green: 0.35, blue: 0.39)]
    case .rain:  return [Color(red: 0.33, green: 0.43, blue: 0.48), Color(red: 0.15, green: 0.20, blue: 0.22)]
    case .snow:  return [Color(red: 0.57, green: 0.79, blue: 0.98), Color(red: 0.36, green: 0.56, blue: 0.80)]
    case .storm: return [Color(red: 0.22, green: 0.28, blue: 0.31), Color(red: 0.11, green: 0.15, blue: 0.16)]
    case .fog:   return [Color(red: 0.69, green: 0.75, blue: 0.77), Color(red: 0.47, green: 0.57, blue: 0.62)]
    }
}

func weatherLabel(_ code: Int?) -> String {
    switch code {
    case .none:           return "—"
    case 0:               return "Ciel clair"
    case 1:               return "Plutôt clair"
    case 2:               return "Partiellement nuageux"
    case 3:               return "Couvert"
    case 45, 48:          return "Brouillard"
    case 51, 53, 55:      return "Bruine"
    case 61, 63, 65:      return "Pluie"
    case 71, 73, 75:      return "Neige"
    case 77:              return "Neige fine"
    case 80, 81, 82:      return "Averses"
    case 85, 86:          return "Averses de neige"
    case 95:              return "Orage"
    case 96, 99:          return "Orage avec grêle"
    default:              return "Variable"
    }
}

private func shortDow(_ isoDate: String) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.locale = Locale(identifier: "fr_FR")
    fmt.timeZone = TimeZone(identifier: "UTC")
    guard let date = fmt.date(from: isoDate) else { return String(isoDate.prefix(3)) }
    let out = DateFormatter()
    out.dateFormat = "EE"
    out.locale = Locale(identifier: "fr_FR")
    return out.string(from: date).replacingOccurrences(of: ".", with: "").capitalized
}

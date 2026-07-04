import SwiftUI

/// A circular speed gauge with a ~270° progress arc, tick marks, and a big
/// centered digital readout — the shared visual language for every live
/// driving/recording screen (LiveDriveView, CreateTrackView), so all of
/// them look and feel consistent rather than each screen inventing its own
/// speed display.
struct SpeedGaugeView: View {
    let value: Double
    let unit: String
    let color: Color

    /// Full-scale value the arc represents. 180 covers virtually any normal
    /// driving speed while still giving meaningful resolution at legal
    /// speeds — the reference app doesn't expose its exact max, so this is
    /// a reasonable choice rather than a copied value.
    private let maxValue: Double = 180
    private let startAngle: Double = 135
    private let sweepDegrees: Double = 270

    private var progress: Double { min(max(value / maxValue, 0), 1) }

    var body: some View {
        ZStack {
            ForEach(0..<28, id: \.self) { i in
                let angle = startAngle + sweepDegrees * (Double(i) / 27)
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 2, height: 10)
                    .offset(y: -145)
                    .rotationEffect(.degrees(angle))
            }

            Circle()
                .trim(from: 0, to: sweepDegrees / 360)
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(startAngle))

            Circle()
                .trim(from: 0, to: (sweepDegrees / 360) * progress)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(startAngle))
                .shadow(color: color.opacity(0.6), radius: 8)

            VStack(spacing: 6) {
                Text("\(Int(value))")
                    .font(.system(size: 92, weight: .heavy))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .frame(width: 320, height: 320)
        .animation(.easeOut(duration: 0.3), value: value)
    }

    /// Standard color scale used everywhere this gauge appears: green under
    /// city speeds, yellow into highway speeds, red beyond that.
    static func colorForSpeed(_ kmh: Double) -> Color {
        if kmh < 60 { return .speedGreen }
        if kmh < 100 { return .yellow }
        return .speedRed
    }
}

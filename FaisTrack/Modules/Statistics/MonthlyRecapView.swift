import SwiftUI

/// The full-screen recap shown when the user taps the "Your [Month] Recap is
/// Here" banner — a shareable summary of last month's driving.
struct MonthlyRecapView: View {
    @ObservedObject var viewModel: StatsViewModel
    let useMetric: Bool
    @Environment(\.dismiss) var dismiss

    private func distance(_ km: Double) -> String {
        useMetric ? String(format: "%.0f km", km) : String(format: "%.0f mi", km * 0.621371)
    }
    private func speed(_ kmh: Double) -> String {
        useMetric ? String(format: "%.0f km/h", kmh) : String(format: "%.0f mph", kmh * 0.621371)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack(spacing: 24) {
                    RecapCard(viewModel: viewModel, distance: distance, speed: speed)
                    FTPrimaryButton(title: NSLocalizedString("general.share", comment: "")) {
                        shareRecap()
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.top, 24)
            }
            .navigationTitle(String(format: NSLocalizedString("stats.recapBanner.title", comment: ""), viewModel.previousMonthName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("general.done", comment: "")) { dismiss() }
                }
            }
        }
    }

    private func shareRecap() {
        // UIGraphicsImageRenderer for iOS 15 compatibility (ImageRenderer is iOS 16+),
        // same pattern used for the car share card.
        let card = RecapCard(viewModel: viewModel, distance: distance, speed: speed)
        let controller = UIHostingController(rootView: card)
        controller.view.bounds = CGRect(x: 0, y: 0, width: 340, height: 440)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 340, height: 440))
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }

        let av = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}

private struct RecapCard: View {
    @ObservedObject var viewModel: StatsViewModel
    let distance: (Double) -> String
    let speed: (Double) -> String

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(hex: "#1A0000")], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 18) {
                Text("FaisTrack").font(.system(size: 14, weight: .bold)).foregroundColor(.ftAccent)
                Text("\(viewModel.previousMonthName) RECAP")
                    .font(.system(size: 26, weight: .black)).foregroundColor(.white)

                VStack(alignment: .leading, spacing: 14) {
                    recapStat(icon: "car.fill", value: distance(viewModel.previousMonthDistanceKm), label: NSLocalizedString("stats.totalDistance", comment: ""))
                    recapStat(icon: "gauge.with.dots.needle.67percent", value: speed(viewModel.previousMonthTopSpeed), label: NSLocalizedString("stats.topSpeed", comment: ""))
                    recapStat(icon: "clock.fill", value: String(format: "%.1f hrs", viewModel.previousMonthHours), label: NSLocalizedString("stats.totalTime", comment: ""))
                    recapStat(icon: "flag.checkered", value: "\(viewModel.previousMonthDriveCount)", label: NSLocalizedString("leaderboard.drives", comment: ""))
                }
                Spacer()
            }
            .padding(24)
        }
        .cornerRadius(24)
        .frame(width: 340, height: 440)
    }

    private func recapStat(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundColor(.ftAccentOrange).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text(label).font(.system(size: 12)).foregroundColor(.gray)
            }
        }
    }
}

import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel = StatsViewModel()
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    @State private var showRecap = false

    private var useMetric: Bool { unitsPreference == "km" }
    private func distanceText(_ km: Double) -> String {
        useMetric ? String(format: "%.0f km", km) : String(format: "%.0f mi", km * 0.621371)
    }
    private func distanceText1dp(_ km: Double) -> String {
        useMetric ? String(format: "%.1f km", km) : String(format: "%.1f mi", km * 0.621371)
    }

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.drives.isEmpty {
                emptyView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if viewModel.showRecapBanner {
                            recapBanner
                        }
                        totalDistanceCard
                        comparisonBars
                        longestDriveCard
                        topSpeedCard
                        fastestDriveCard
                        totalTimeCard
                        safetyScoreCard
                        vehicleBreakdownSection
                        mostDrivenVehicleCard
                        personalBestsSection
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(NSLocalizedString("tab.stats", comment: ""))
        .task { await viewModel.load() }
        .sheet(isPresented: $showRecap) {
            MonthlyRecapView(viewModel: viewModel, useMetric: useMetric)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("stats.empty.title", comment: ""))
                .font(.system(size: 22, weight: .bold))
            Text(NSLocalizedString("stats.empty.subtitle", comment: ""))
                .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
        }.padding(32)
    }

    // MARK: - Monthly Recap banner

    private var recapBanner: some View {
        Button(action: { showRecap = true }) {
            HStack {
                Text("🚗").font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: NSLocalizedString("stats.recapBanner.title", comment: ""), viewModel.previousMonthName))
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                    Text(NSLocalizedString("stats.recapBanner.subtitle", comment: ""))
                        .font(.system(size: 13)).foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.white)
            }
            .padding(16)
            .background(LinearGradient(colors: [.blue, .ftAccent], startPoint: .leading, endPoint: .trailing))
            .cornerRadius(18)
        }
    }

    // MARK: - Safety Score

    private var safetyScoreCard: some View {
        Group {
            if let avg = viewModel.averageSafetyScore {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("stats.safetyScore", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(avg)")
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(safetyColor(avg))
                        Text("/ 100").font(.system(size: 16)).foregroundColor(.ftTextSecondary)
                    }
                    if viewModel.safetyScoreTrend.count > 1 {
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(Array(viewModel.safetyScoreTrend.enumerated()), id: \.offset) { _, score in
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(safetyColor(score))
                                    .frame(width: 14, height: max(6, CGFloat(score) / 100 * 44))
                            }
                        }
                        .frame(height: 44, alignment: .bottom)
                        Text(NSLocalizedString("stats.safetyScore.trend", comment: ""))
                            .font(.system(size: 11)).foregroundColor(.ftTextSecondary)
                    }
                }
            }
        }
    }

    private func safetyColor(_ score: Int) -> Color {
        if score >= 80 { return .speedGreen }
        if score >= 50 { return .speedOrange }
        return .speedRed
    }

    // MARK: - Distance by Vehicle

    private var vehicleBreakdownSection: some View {
        Group {
            if viewModel.carStats.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("stats.distanceByVehicle", comment: ""))
                        .font(.system(size: 17, weight: .semibold))

                    let total = max(viewModel.carStats.reduce(0) { $0 + $1.km }, 0.01)
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(viewModel.carStats.enumerated()), id: \.1.id) { index, stat in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(carColor(index))
                                    .frame(width: geo.size.width * CGFloat(stat.km / total))
                            }
                        }
                    }.frame(height: 14)

                    VStack(spacing: 6) {
                        ForEach(Array(viewModel.carStats.enumerated()), id: \.1.id) { index, stat in
                            HStack {
                                Circle().fill(carColor(index)).frame(width: 10, height: 10)
                                Text(stat.car.displayName).font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("\(distanceText1dp(stat.km)) · \(Int(stat.km / total * 100))%")
                                    .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func carColor(_ index: Int) -> Color {
        let palette: [Color] = [.ftAccent, .blue, .ftAccentOrange, .mint, .purple, .yellow]
        return palette[index % palette.count]
    }

    // MARK: - Total Drive Distance

    private var totalDistanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(NSLocalizedString("stats.totalDistance", comment: ""))
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button(action: shareDistance) {
                    Label(NSLocalizedString("general.share", comment: ""), systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.ftCard)
                        .cornerRadius(14)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(useMetric ? String(format: "%.0f", viewModel.totalDistanceKm) : String(format: "%.0f", viewModel.totalDistanceKm * 0.621371))
                    .font(.system(size: 52, weight: .black))
                Text(useMetric ? "km" : "mi")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.ftTextSecondary)
            }
            Text(String(format: NSLocalizedString("stats.avgDriveDistance", comment: ""), distanceText1dp(viewModel.averageDriveDistanceKm)))
                .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
        }
    }

    // MARK: - Distance comparisons

    private var comparisonBars: some View {
        VStack(spacing: 10) {
            ComparisonRow(emoji: "🏁", value: viewModel.indy500Laps, label: NSLocalizedString("stats.compare.indy500", comment: ""), highlighted: true)
            ComparisonRow(emoji: "🇺🇸", value: viewModel.coastToCoastRatio, label: NSLocalizedString("stats.compare.coastToCoast", comment: ""))
            ComparisonRow(emoji: "🌍", value: viewModel.aroundEarthRatio, label: NSLocalizedString("stats.compare.aroundEarth", comment: ""))
            ComparisonRow(emoji: "🌕", value: viewModel.toTheMoonRatio, label: NSLocalizedString("stats.compare.toTheMoon", comment: ""))
        }
    }

    // MARK: - Longest Drive

    private var longestDriveCard: some View {
        Group {
            if let drive = viewModel.longestDrive {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("stats.longestDrive", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                    FTCard {
                        HStack {
                            Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.system(size: 28)).foregroundColor(.ftAccent).frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dateFormatter.string(from: drive.startTime.dateValue()))
                                    .font(.system(size: 15, weight: .semibold))
                                Text("\(distanceText1dp(drive.distance)) · \(drive.durationFormatted)")
                                    .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(useMetric ? String(format: "%.0f", drive.topSpeed) : String(format: "%.0f", drive.topSpeed * 0.621371))
                                    .font(.system(size: 22, weight: .black)).foregroundColor(.ftAccentOrange)
                                Text(useMetric ? "KM/H" : "MPH").font(.system(size: 10)).foregroundColor(.ftTextSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Top Speed

    private var topSpeedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("stats.topSpeed", comment: ""))
                .font(.system(size: 17, weight: .semibold))
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(useMetric ? String(format: "%.0f", viewModel.topSpeedKmh) : String(format: "%.0f", viewModel.topSpeedKmh * 0.621371))
                    .font(.system(size: 40, weight: .black)).foregroundColor(.ftAccentOrange)
                Text(useMetric ? "km/h" : "mph").font(.system(size: 16)).foregroundColor(.ftTextSecondary)
            }
            Text(NSLocalizedString("stats.speedDistribution", comment: ""))
                .font(.system(size: 14, weight: .medium)).foregroundColor(.ftTextSecondary)
            VStack(spacing: 8) {
                ForEach(viewModel.speedDistribution) { bucket in
                    HStack {
                        Text(bucket.label).font(.system(size: 12)).foregroundColor(.ftTextSecondary).frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(bucket.color)
                                .frame(width: barWidth(bucket.count, total: viewModel.drivingDriveCount, maxWidth: geo.size.width))
                        }.frame(height: 10)
                        Text("\(bucket.count)").font(.system(size: 12, weight: .semibold)).frame(width: 28, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func barWidth(_ count: Int, total: Int, maxWidth: CGFloat) -> CGFloat {
        guard total > 0 else { return 0 }
        return max(4, maxWidth * CGFloat(count) / CGFloat(total))
    }

    // MARK: - Fastest Drive

    private var fastestDriveCard: some View {
        Group {
            if let drive = viewModel.fastestDrive {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("stats.fastestDrive", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                    FTCard {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 28)).foregroundColor(.speedRed).frame(width: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dateFormatter.string(from: drive.startTime.dateValue()))
                                    .font(.system(size: 15, weight: .semibold))
                                Text(distanceText1dp(drive.distance))
                                    .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                            }
                            Spacer()
                            Text(drive.topSpeedFormatted(useMetric: useMetric))
                                .font(.system(size: 18, weight: .bold)).foregroundColor(.speedRed)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Total Time Driven

    private var totalTimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("stats.totalTime", comment: ""))
                .font(.system(size: 17, weight: .semibold))
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(String(format: "%.0f", viewModel.totalDurationHours))
                    .font(.system(size: 40, weight: .black))
                Text("hrs").font(.system(size: 16)).foregroundColor(.ftTextSecondary)
            }
            Text(String(format: NSLocalizedString("stats.avgDriveTime", comment: ""), viewModel.averageDriveMinutes))
                .font(.system(size: 14)).foregroundColor(.ftTextSecondary)

            // Day vs. night split, using the same isNight flag DriveDetectionService
            // already records for each drive.
            let total = max(viewModel.dayHours + viewModel.nightHours, 0.01)
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.ftAccent)
                            .frame(width: geo.size.width * CGFloat(viewModel.dayHours / total))
                        RoundedRectangle(cornerRadius: 4).fill(Color.indigo)
                            .frame(width: geo.size.width * CGFloat(viewModel.nightHours / total))
                    }
                }.frame(height: 14)
                HStack {
                    Label(String(format: "%.1f " + NSLocalizedString("stats.hoursShort", comment: ""), viewModel.dayHours), systemImage: "sun.max.fill")
                        .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
                    Spacer()
                    Label(String(format: "%.1f " + NSLocalizedString("stats.hoursShort", comment: ""), viewModel.nightHours), systemImage: "moon.fill")
                        .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
                }
            }
        }
    }

    // MARK: - Most Driven Vehicle

    private var mostDrivenVehicleCard: some View {
        Group {
            if let stat = viewModel.mostDrivenCar {
                VStack(alignment: .leading, spacing: 12) {
                    Text(NSLocalizedString("stats.mostDrivenVehicles", comment: ""))
                        .font(.system(size: 17, weight: .semibold))
                    ZStack {
                        LinearGradient(colors: [.blue, .ftAccent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("stats.mostDrivenVehicle", comment: ""))
                                .font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
                            Text(stat.car.displayName.uppercased())
                                .font(.system(size: 26, weight: .black)).foregroundColor(.white)
                            HStack(spacing: 32) {
                                VStack(alignment: .leading) {
                                    Text("\(stat.driveCount)").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                                    Text(NSLocalizedString("stats.drivesLabel", comment: "")).font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                                }
                                VStack(alignment: .leading) {
                                    Text(distanceText(stat.km)).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                                    Text(useMetric ? "KM" : "MI").font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }.padding(20)
                    }
                    .cornerRadius(20)
                }
            }
        }
    }

    // MARK: - Personal Bests

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("stats.personalBests", comment: ""))
                .font(.system(size: 17, weight: .semibold))
                .padding(.bottom, 8)

            PersonalBestRow(emoji: "🚀", title: NSLocalizedString("stats.pb.rocketMode", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.rocketMode.sub", comment: ""),
                             value: viewModel.topSpeedKmh > 0 ? "\(Int(useMetric ? viewModel.topSpeedKmh : viewModel.topSpeedKmh * 0.621371)) \(useMetric ? "km/h" : "mph")" : "—")

            PersonalBestRow(emoji: "🛣️", title: NSLocalizedString("stats.pb.longHaul", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.longHaul.sub", comment: ""),
                             value: viewModel.longestDrive.map { distanceText1dp($0.distance) } ?? "—")

            PersonalBestRow(emoji: "⏱️", title: NSLocalizedString("stats.pb.seatTime", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.seatTime.sub", comment: ""),
                             value: viewModel.longestDriveByTime?.durationFormatted ?? "—")

            PersonalBestRow(emoji: "🏎️", title: NSLocalizedString("stats.pb.smoothOperator", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.smoothOperator.sub", comment: ""),
                             value: viewModel.bestAvgSpeedDrive.map { $0.speedFormatted(useMetric: useMetric, value: $0.avgSpeed) } ?? "—")

            PersonalBestRow(emoji: "📍", title: NSLocalizedString("stats.pb.bigDayEnergy", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.bigDayEnergy.sub", comment: ""),
                             value: viewModel.bigDayEnergyKm > 0 ? distanceText1dp(viewModel.bigDayEnergyKm) : "—")

            PersonalBestRow(emoji: "🕰️", title: NSLocalizedString("stats.pb.roadWarrior", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.roadWarrior.sub", comment: ""),
                             value: viewModel.roadWarriorHours > 0 ? String(format: "%.1f hrs", viewModel.roadWarriorHours) : "—")

            PersonalBestRow(emoji: "🔁", title: NSLocalizedString("stats.pb.errandEra", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.errandEra.sub", comment: ""),
                             value: viewModel.errandEraCount > 0 ? "\(viewModel.errandEraCount)" : "—")

            PersonalBestRow(emoji: "🗓️", title: NSLocalizedString("stats.pb.hotWeek", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.hotWeek.sub", comment: ""),
                             value: viewModel.hotWeekKm > 0 ? distanceText1dp(viewModel.hotWeekKm) : "—")

            PersonalBestRow(emoji: "🏁", title: NSLocalizedString("stats.pb.mileageMonster", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.mileageMonster.sub", comment: ""),
                             value: viewModel.mileageMonsterKm > 0 ? distanceText1dp(viewModel.mileageMonsterKm) : "—")

            PersonalBestRow(emoji: "🔥", title: NSLocalizedString("stats.pb.onARoll", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.onARoll.sub", comment: ""),
                             value: viewModel.onARollStreak > 0 ? "\(viewModel.onARollStreak) \(NSLocalizedString("stats.daysShort", comment: ""))" : "—")

            PersonalBestRow(emoji: "👑", title: NSLocalizedString("stats.pb.passengerPrincess", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.passengerPrincess.sub", comment: ""),
                             value: viewModel.passengerMiles > 0 ? distanceText1dp(viewModel.passengerMiles) : "—")

            PersonalBestRow(emoji: "🚗", title: NSLocalizedString("stats.pb.garageRocket", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.garageRocket.sub", comment: ""),
                             value: viewModel.garageRocketCar.map { "\($0.car.displayName)" } ?? "—")

            PersonalBestRow(emoji: "🧭", title: NSLocalizedString("stats.pb.favoriteRide", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.favoriteRide.sub", comment: ""),
                             value: viewModel.favoriteRideCar.map { "\($0.car.displayName)" } ?? "—")

            PersonalBestRow(emoji: "🔑", title: NSLocalizedString("stats.pb.dailyDriver", comment: ""),
                             subtitle: NSLocalizedString("stats.pb.dailyDriver.sub", comment: ""),
                             value: viewModel.mostDrivenCar.map { "\($0.car.displayName)" } ?? "—")
        }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f
    }

    private func shareDistance() {
        let text = String(format: NSLocalizedString("stats.shareText", comment: ""), distanceText(viewModel.totalDistanceKm))
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController?
            .present(av, animated: true)
    }
}

private struct ComparisonRow: View {
    let emoji: String
    let value: Double
    let label: String
    var highlighted: Bool = false

    var body: some View {
        HStack {
            Text(emoji).font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.2)))
            Text(String(format: "%.2fx", value)).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 15)).foregroundColor(.white.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(highlighted ? Color.ftAccent : Color.ftCard)
        .cornerRadius(20)
    }
}

private struct PersonalBestRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack {
            Text(emoji).font(.system(size: 22)).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundColor(.ftTextSecondary)
            }
            Spacer()
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.ftAccent)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

private extension Drive {
    /// Formats an arbitrary speed value (e.g. avgSpeed) the same way topSpeed is formatted.
    func speedFormatted(useMetric: Bool, value: Double) -> String {
        useMetric ? String(format: "%.0f km/h", value) : String(format: "%.0f mph", value * 0.621371)
    }
}




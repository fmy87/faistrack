import SwiftUI

/// Full-screen HUD shown automatically while DriveDetectionService has
/// detected an in-progress drive. Speed/Map toggle, circular speed gauge,
/// live stats grid, and Ghost/Driver controls, modeled directly on the
/// reference screenshot the user provided.
struct LiveDriveView: View {
    @ObservedObject private var driveDetection = DriveDetectionService.shared
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    @State private var displayMode: DisplayMode = .speed
    @State private var friendPins: [FriendMapPin] = []
    @State private var friendPollTask: Task<Void, Never>?
    var onMinimize: (() -> Void)?

    private enum DisplayMode { case speed, map }

    private var useMetric: Bool { unitsPreference == "km" }
    private var speedUnit: String { useMetric ? "KM/H" : "MPH" }
    private var distanceUnit: String { useMetric ? "km" : "mi" }

    private func speedValue(_ kmh: Double) -> Double { useMetric ? kmh : kmh * 0.621371 }
    private func distanceValue(_ km: Double) -> Double { useMetric ? km : km * 0.621371 }
    private func altitudeValue(_ meters: Double) -> Double { useMetric ? meters : meters * 3.28084 }
    private var altitudeUnit: String { useMetric ? "m" : "ft" }

    private var gaugeColor: Color {
        SpeedGaugeView.colorForSpeed(driveDetection.currentSpeedKmh)
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)

                if displayMode == .speed {
                    speedView
                } else {
                    mapView
                }

                Spacer(minLength: 0)
                bottomControls
                endDriveButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        Group {
            if displayMode == .speed {
                RadialGradient(
                    colors: [gaugeColor.opacity(0.35), Color.black],
                    center: .center, startRadius: 20, endRadius: 500
                )
                .ignoresSafeArea()
            } else {
                Color.ftBackground.ignoresSafeArea()
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Picker("", selection: $displayMode) {
                Label(NSLocalizedString("liveDrive.speedTab", comment: ""), systemImage: "speedometer").tag(DisplayMode.speed)
                Label(NSLocalizedString("liveDrive.mapTab", comment: ""), systemImage: "map").tag(DisplayMode.map)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)

            Spacer()

            Menu {
                Button(role: .destructive, action: { driveDetection.endDriveManually() }) {
                    Label(NSLocalizedString("liveDrive.endDrive", comment: ""), systemImage: "stop.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Circle())
            }

            if let onMinimize {
                Button(action: onMinimize) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Speed tab

    private var speedView: some View {
        VStack(spacing: 28) {
            Button(action: { driveDetection.endDriveManually() }) {
                Label(NSLocalizedString("liveDrive.endDrive", comment: ""), systemImage: "square.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
            }

            ZStack {
                SpeedActionLinesView(speedKmh: driveDetection.currentSpeedKmh, color: gaugeColor)
                SpeedGaugeView(
                    value: speedValue(driveDetection.currentSpeedKmh),
                    unit: speedUnit,
                    color: gaugeColor
                )
            }

            statsGrid
        }
    }

    private var statsGrid: some View {
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                statItem(NSLocalizedString("liveDrive.avg", comment: ""), String(format: "%.0f", speedValue(driveDetection.liveAverageSpeedKmh)), useMetric ? "km/h" : "mph")
                statItem(NSLocalizedString("liveDrive.top", comment: ""), String(format: "%.0f", speedValue(driveDetection.liveTopSpeedKmh)), useMetric ? "km/h" : "mph", valueColor: .yellow)
                statItem(NSLocalizedString("liveDrive.distanceShort", comment: ""), String(format: "%.1f", distanceValue(driveDetection.liveDistanceKm)), distanceUnit)
            }
            HStack(spacing: 0) {
                statItem(NSLocalizedString("liveDrive.altitude", comment: ""), String(format: "%.0f", altitudeValue(driveDetection.liveAltitudeMeters)), altitudeUnit)
                statItem(NSLocalizedString("liveDrive.moving", comment: ""), timeString(driveDetection.movingSeconds), "")
                statItem(NSLocalizedString("liveDrive.stopped", comment: ""), timeString(driveDetection.stoppedSeconds), "")
            }
        }
        .padding(.horizontal, 24)
    }

    private func statItem(_ label: String, _ value: String, _ unit: String, valueColor: Color = .white) -> some View {
        VStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(valueColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Map tab

    private var mapView: some View {
        Group {
            if driveDetection.liveRouteCoordinates.count > 1 || !friendPins.isEmpty {
                RouteMapView(coordinates: driveDetection.liveRouteCoordinates, friendPins: friendPins, liveFollow: true)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text(NSLocalizedString("liveDrive.locating", comment: ""))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .onAppear { startFriendPolling() }
        .onDisappear { friendPollTask?.cancel() }
    }

    /// Polls friends' live locations while the map is on screen — matches
    /// the same lightweight polling pattern used in FriendsViewModel rather
    /// than introducing a persistent Firestore listener just for this one
    /// view. 15s keeps pins reasonably fresh without excessive reads.
    private func startFriendPolling() {
        friendPollTask?.cancel()
        friendPollTask = Task {
            while !Task.isCancelled {
                await refreshFriendPins()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func refreshFriendPins() async {
        guard let uid = AuthService.shared.currentUser?.uid,
              let friends = try? await FirebaseService.shared.getFriends(uid: uid) else { return }
        friendPins = (try? await FirebaseService.shared.getFriendsLiveLocations(friendUIDs: friends.map(\.uid))) ?? []
    }

    // MARK: - Bottom controls

    private var bottomControls: some View {
        HStack(spacing: 60) {
            controlButton(
                icon: driveDetection.isGhostMode ? "eye.slash.fill" : "eye.slash",
                label: NSLocalizedString("liveDrive.ghost", comment: ""),
                isActive: driveDetection.isGhostMode
            ) {
                driveDetection.isGhostMode.toggle()
            }
            controlButton(
                icon: "steeringwheel",
                label: driveDetection.isPassengerMode
                    ? NSLocalizedString("liveDrive.passenger", comment: "")
                    : NSLocalizedString("liveDrive.driver", comment: ""),
                isActive: driveDetection.isPassengerMode
            ) {
                driveDetection.isPassengerMode.toggle()
            }
        }
        .padding(.bottom, 20)
    }

    private func controlButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isActive ? .ftAccent : .white)
                    .frame(width: 56, height: 56)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    // MARK: - End Drive (primary)

    private var endDriveButton: some View {
        Button(action: { driveDetection.endDriveManually() }) {
            Label(NSLocalizedString("liveDrive.endDrive", comment: ""), systemImage: "square.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.12))
                .cornerRadius(28)
        }
    }
}

/// A circular speed gauge with a ~270° progress arc, tick marks, and a big
/// centered digital readout — modeled on the reference screenshot. Shared
/// with CreateTrackView (see SpeedGaugeView.swift) so live driving and live
/// track recording use the same visual language.





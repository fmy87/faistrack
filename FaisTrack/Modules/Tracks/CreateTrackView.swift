import SwiftUI

struct CreateTrackView: View {
    @ObservedObject private var service = TrackCreationService.shared
    @AppStorage("unitsPreference") private var unitsPreference: String = "km"
    @Environment(\.dismiss) var dismiss
    @State private var trackName: String = ""
    @State private var isSaving = false
    var onCreated: (() -> Void)?

    private var useMetric: Bool { unitsPreference == "km" }
    private func speedValue(_ kmh: Double) -> Double { useMetric ? kmh : kmh * 0.621371 }
    private var speedUnit: String { useMetric ? "KM/H" : "MPH" }
    private func distanceText(_ meters: Double) -> String {
        let km = meters / 1000
        if useMetric {
            return meters >= 1000 ? String(format: "%.2f km", km) : String(format: "%.0f m", meters)
        } else {
            let miles = meters * 0.000621371
            return String(format: "%.2f mi", miles)
        }
    }

    private var gaugeColor: Color { SpeedGaugeView.colorForSpeed(service.currentSpeedKmh) }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundLayer
                VStack(spacing: 24) {
                    switch service.state {
                    case .idle:
                        idleView
                    case .countingDown(let n):
                        countdownView(n)
                    case .recording(let elapsed, let distance):
                        recordingView(elapsed: elapsed, distance: distance)
                    case .finished(let distance, let duration):
                        finishedView(distance: distance, duration: duration)
                    }
                    if let error = service.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.speedRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(24)
            }
            .navigationTitle(NSLocalizedString("createTrack.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isRecordingActive)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !isRecordingActive {
                        Button(NSLocalizedString("general.cancel", comment: "")) {
                            service.reset()
                            dismiss()
                        }
                    }
                }
            }
            .onDisappear {
                if case .finished = service.state {} else { service.reset() }
            }
        }
    }

    private var isRecordingActive: Bool {
        switch service.state {
        case .countingDown, .recording: return true
        default: return false
        }
    }

    /// Same glowing radial background used on LiveDriveView's speed screen
    /// while recording, so the two live-tracking screens feel like one
    /// consistent design language rather than a plain flat one here.
    private var backgroundLayer: some View {
        Group {
            if case .recording = service.state {
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

    private var idleView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 56)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("createTrack.explainer", comment: ""))
                .font(.system(size: 16)).foregroundColor(.ftTextSecondary)
                .multilineTextAlignment(.center)
            FTPrimaryButton(title: NSLocalizedString("createTrack.startCountdown", comment: "")) {
                service.beginCountdown()
            }
        }
    }

    /// Same F1-style starting lights as CompeteView's race countdown (see
    /// F1StartingLightsView) — this was previously just a plain number with
    /// no lights at all, which looked inconsistent with the "compete" flow's
    /// countdown right next to it in the same tab.
    private func countdownView(_ n: Int) -> some View {
        VStack(spacing: 32) {
            F1StartingLightsView(litCount: F1StartingLightsView.litCount(
                remaining: n, total: TrackCreationService.countdownDurationSeconds
            ))
            Text("\(n)")
                .font(.system(size: 64, weight: .black))
                .foregroundColor(.ftAccent)
                .id(n)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func recordingView(elapsed: TimeInterval, distance: Double) -> some View {
        VStack(spacing: 28) {
            // Small pill mirroring LiveDriveView's top "End Drive" pill —
            // this was missing before, which is why the two screens still
            // looked subtly different even after sharing the same gauge.
            Button(action: { service.endRecording() }) {
                Label(NSLocalizedString("compete.endRace", comment: ""), systemImage: "square.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
            }

            SpeedGaugeView(
                value: speedValue(service.currentSpeedKmh),
                unit: speedUnit,
                color: gaugeColor
            )

            VStack(spacing: 4) {
                Text(String(format: "%.1f", elapsed))
                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                Text(distanceText(distance))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Button(action: { service.endRecording() }) {
                Label(NSLocalizedString("compete.endRace", comment: ""), systemImage: "square.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.speedRed)
                    .cornerRadius(28)
            }
            .padding(.horizontal, 8)
        }
    }

    private func finishedView(distance: Double, duration: TimeInterval) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 56)).foregroundColor(.ftAccent)
            Text(String(format: "%.2fs", duration))
                .font(.system(size: 48, weight: .black)).foregroundColor(.ftAccent)
            Text(distanceText(distance))
                .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
            TextField(NSLocalizedString("createTrack.namePlaceholder", comment: ""), text: $trackName)
                .padding(14).background(Color.ftCard).cornerRadius(12)
            // The track's name is required to come from the person who
            // created it — this used to silently fall back to "Untitled
            // Track" if left blank, which meant it wasn't really guaranteed
            // to be user-named at all.
            if trackName.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(NSLocalizedString("createTrack.nameRequired", comment: ""))
                    .font(.system(size: 12)).foregroundColor(.ftTextSecondary)
            }
            FTPrimaryButton(title: NSLocalizedString("createTrack.save", comment: ""), isLoading: isSaving) {
                Task {
                    isSaving = true
                    let success = await service.saveTrack(name: trackName)
                    isSaving = false
                    if success {
                        onCreated?()
                        dismiss()
                    }
                }
            }
            .disabled(trackName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
    }
}




import SwiftUI

struct CreateTrackView: View {
    @ObservedObject private var service = TrackCreationService.shared
    @Environment(\.dismiss) var dismiss
    @State private var trackName: String = ""
    @State private var isSaving = false
    var onCreated: (() -> Void)?

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
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

    private func countdownView(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 96, weight: .black))
            .foregroundColor(.ftAccent)
            .id(n)
            .transition(.scale.combined(with: .opacity))
    }

    private func recordingView(elapsed: TimeInterval, distance: Double) -> some View {
        VStack(spacing: 24) {
            Text(String(format: "%.1f", elapsed))
                .font(.system(size: 64, weight: .black, design: .monospaced))
                .foregroundColor(.ftAccent)
            Text(distance >= 1000 ? String(format: "%.2f km", distance / 1000) : String(format: "%.0f m", distance))
                .font(.system(size: 16)).foregroundColor(.ftTextSecondary)
            Button(action: { service.endRecording() }) {
                Text(NSLocalizedString("compete.endRace", comment: ""))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.speedRed)
                    .cornerRadius(16)
            }
        }
    }

    private func finishedView(distance: Double, duration: TimeInterval) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 56)).foregroundColor(.ftAccent)
            Text(String(format: "%.2fs", duration))
                .font(.system(size: 48, weight: .black)).foregroundColor(.ftAccent)
            Text(distance >= 1000 ? String(format: "%.2f km", distance / 1000) : String(format: "%.0f m", distance))
                .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
            TextField(NSLocalizedString("createTrack.namePlaceholder", comment: ""), text: $trackName)
                .padding(14).background(Color.ftCard).cornerRadius(12)
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
        }
    }
}

import SwiftUI
import UIKit

struct CompeteView: View {
    let track: Track
    @ObservedObject private var race = TrackRaceService.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var pulseCountdown = false

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                switch race.state {
                case .idle, .cancelled:
                    idleView
                case .navigatingToStart:
                    navigatingView
                case .readyToStart:
                    readyView
                case .countingDown(let n):
                    countdownView(n)
                case .racing(let elapsed, let distanceToFinish):
                    racingView(elapsed: elapsed, distanceToFinish: distanceToFinish)
                case .finished(let duration):
                    finishedView(duration)
                }
            }
            .padding(24)
        }
        .navigationTitle(track.name)
        .navigationBarBackButtonHidden(isRaceActive)
        .onAppear {
            if case .idle = race.state {
                race.beginApproaching(track: track)
            }
        }
        .onDisappear {
            if case .finished = race.state {
                race.reset()
            } else if case .navigatingToStart = race.state {
                race.reset()
            } else if case .readyToStart = race.state {
                race.reset()
            }
        }
    }

    private var isRaceActive: Bool {
        switch race.state {
        case .countingDown, .racing: return true
        default: return false
        }
    }

    private var idleView: some View {
        ProgressView(NSLocalizedString("compete.locating", comment: ""))
    }

    private var navigatingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 48)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("compete.headToStart", comment: ""))
                .font(.system(size: 20, weight: .bold)).multilineTextAlignment(.center)
            Text(String(format: NSLocalizedString("compete.distanceAway", comment: ""), Int(race.distanceToStart)))
                .font(.system(size: 32, weight: .black)).foregroundColor(.ftAccent)

            // Manual fallback if GPS proximity to the start line is slow to
            // trigger — GPS tracking keeps running in the background either way.
            Button(action: { race.skipToReadyToStart() }) {
                Text(NSLocalizedString("compete.startManually", comment: ""))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.ftAccent)
            }

            Button(NSLocalizedString("general.cancel", comment: "")) {
                race.reset()
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(.ftTextSecondary)
        }
    }

    private var readyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56)).foregroundColor(.speedGreen)
            Text(NSLocalizedString("compete.arrived", comment: ""))
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
            Button(action: { race.userTappedStart() }) {
                Text(NSLocalizedString("compete.start", comment: ""))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.ftGradient)
                    .cornerRadius(20)
            }
        }
    }

    private func countdownView(_ n: Int) -> some View {
        ZStack {
            Circle()
                .fill(countdownColor(n).opacity(0.18))
                .frame(width: 220, height: 220)
                .scaleEffect(pulseCountdown ? 1.12 : 0.92)
                .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: pulseCountdown)
            Text("\(n)")
                .font(.system(size: 96, weight: .black))
                .foregroundColor(countdownColor(n))
                .id(n)
                .transition(.scale.combined(with: .opacity))
        }
        .onAppear {
            pulseCountdown = true
            fireHaptic()
        }
        .onChange(of: n) { _ in
            fireHaptic()
        }
    }

    /// Mimics drag-racing "starting lights": red while counting down,
    /// flashing green in the final couple of seconds before launch.
    private func countdownColor(_ n: Int) -> Color {
        n <= 2 ? .speedGreen : .ftAccent
    }

    private func fireHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func racingView(elapsed: TimeInterval, distanceToFinish: Double) -> some View {
        VStack(spacing: 24) {
            Text(String(format: "%.1f", elapsed))
                .font(.system(size: 64, weight: .black, design: .monospaced))
                .foregroundColor(.ftAccent)
            Text(String(format: NSLocalizedString("compete.distanceToFinish", comment: ""), Int(distanceToFinish)))
                .font(.system(size: 16)).foregroundColor(.ftTextSecondary)

            // Manual fallback if GPS doesn't register crossing the finish
            // radius — GPS tracking (and auto-finish) keeps running either way.
            Button(action: { race.endRaceManually() }) {
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

    private func finishedView(_ duration: TimeInterval) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "flag.checkered.circle.fill")
                .font(.system(size: 56)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("compete.finished", comment: ""))
                .font(.system(size: 22, weight: .bold))
            Text(String(format: "%.2fs", duration))
                .font(.system(size: 48, weight: .black))
                .foregroundColor(.ftAccent)
            if let best = track.bestTime {
                Text(duration < best
                     ? NSLocalizedString("compete.newRecord", comment: "")
                     : String(format: NSLocalizedString("compete.comparedToBest", comment: ""), best))
                    .foregroundColor(.ftTextSecondary)
                    .multilineTextAlignment(.center)
            }
            Button(NSLocalizedString("general.done", comment: "")) {
                race.reset()
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.ftGradient)
            .cornerRadius(16)
        }
    }
}


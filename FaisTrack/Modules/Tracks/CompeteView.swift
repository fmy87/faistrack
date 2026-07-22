import SwiftUI
import UIKit
import CoreLocation

struct CompeteView: View {
    let track: Track
    @ObservedObject private var race = TrackRaceService.shared
    @Environment(\.presentationMode) var presentationMode

    private var routeCoordinates: [CLLocationCoordinate2D] {
        PolylineCodec.decode(track.polylineEncoded)
    }

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

    /// Mirrors a real Formula 1 start: 5 red lights illuminate one at a
    /// time, then all extinguish together the instant the race actually
    /// starts (the switch to racingView happens immediately when the
    /// countdown reaches zero, standing in for "lights out"). Shared with
    /// CreateTrackView's countdown via F1StartingLightsView so both
    /// countdowns in the app look identical.
    private func countdownView(_ n: Int) -> some View {
        VStack(spacing: 32) {
            F1StartingLightsView(litCount: F1StartingLightsView.litCount(
                remaining: n, total: TrackRaceService.countdownDurationSeconds
            ))
            Text("\(n)")
                .font(.system(size: 64, weight: .black))
                .foregroundColor(.white)
                .id(n)
                .transition(.scale.combined(with: .opacity))
        }
        .onAppear { fireHaptic() }
        .onChange(of: n) { _ in fireHaptic() }
    }

    private func fireHaptic() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func racingView(elapsed: TimeInterval, distanceToFinish: Double) -> some View {
        VStack(spacing: 16) {
            Text(String(format: "%.1f", elapsed))
                .font(.system(size: 56, weight: .black, design: .monospaced))
                .foregroundColor(.ftAccent)

            if let delta = race.liveDeltaSeconds {
                // Negative means ahead of the ghost's pace at this same
                // point in the run — green. Positive means behind — red.
                // This is the one number that answers "am I winning right
                // now," not just at the very end.
                Text(String(format: "%@%.1fs", delta <= 0 ? "-" : "+", abs(delta)))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(delta <= 0 ? .speedGreen : .speedRed)
                Text(NSLocalizedString("compete.vsGhost", comment: ""))
                    .font(.system(size: 11)).foregroundColor(.ftTextSecondary)
            }

            if routeCoordinates.count > 1 {
                RaceMapView(routeCoordinates: routeCoordinates, ghostPosition: race.ghostPosition)
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text(String(format: NSLocalizedString("compete.distanceToFinish", comment: ""), Int(distanceToFinish)))
                .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
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




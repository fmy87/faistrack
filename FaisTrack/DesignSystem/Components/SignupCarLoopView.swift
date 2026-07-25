import SwiftUI
import AVFoundation
import AVKit

/// Real drifting-350Z footage behind the sign-in screen, replacing the old
/// SF Symbol car silhouette (DriftingCarEffectView) — looped seamlessly via
/// AVPlayerLooper so it reads as ambient atmosphere rather than something
/// someone is expected to sit and watch.
///
/// Plays with sound by default, same reasoning as the intro video: a mute
/// toggle the person can reach is the more natural direction than silencing
/// it outright and hoping nobody minds. Two things had to be true for that
/// sound to actually be audible, not just "not explicitly muted":
///   1. `player.isMuted` has to be false (it was hardcoded true before).
///   2. The audio session category has to be `.playback`, not whatever the
///      default/ambient category is — AVPlayer's audio otherwise respects
///      the hardware silent switch the way ambient sounds do, so even an
///      unmuted player would play silently on a phone with the silent
///      switch flipped, which looks identical to "the video has no sound"
///      from the person's perspective. This is the same fix IntroVideoView
///      already needed for the same reason.
struct SignupCarLoopView: View {
    @Binding var isMuted: Bool
    @State private var queuePlayer: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?

    var body: some View {
        Group {
            if let queuePlayer {
                LoopingVideoPlayerContainer(player: queuePlayer)
            } else {
                Color.ftBackground
            }
        }
        .onAppear { setupIfNeeded() }
        .onChange(of: isMuted) { queuePlayer?.isMuted = $0 }
        .onDisappear {
            queuePlayer?.pause()
        }
    }

    private func setupIfNeeded() {
        guard queuePlayer == nil,
              let url = Bundle.main.url(forResource: "Signup_350Z", withExtension: "mp4") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = isMuted
        // AVPlayerLooper (backed by an AVQueuePlayer) loops without the
        // brief black flash a manual "seek to zero on end" approach gets —
        // important here since the loop point is far more noticeable on a
        // background visual than it would be on something the person is
        // actively watching.
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
        queuePlayer = player
    }
}

private struct LoopingVideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVQueuePlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

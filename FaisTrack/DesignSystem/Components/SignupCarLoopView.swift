import SwiftUI
import AVFoundation
import AVKit

/// Real drifting-350Z footage behind the sign-in screen, replacing the old
/// SF Symbol car silhouette (DriftingCarEffectView) — muted and looped
/// seamlessly via AVPlayerLooper so it reads as ambient atmosphere rather
/// than a video someone is expected to watch or unmute.
struct SignupCarLoopView: View {
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
        .onDisappear {
            queuePlayer?.pause()
        }
    }

    private func setupIfNeeded() {
        guard queuePlayer == nil,
              let url = Bundle.main.url(forResource: "Signup_350Z", withExtension: "mp4") else { return }
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
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

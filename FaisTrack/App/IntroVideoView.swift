import SwiftUI
import AVKit
import AVFoundation

/// A short branded video shown once, on the very first launch after
/// install — right after the system's static Launch Screen dismisses.
/// Apple requires the actual Launch Screen itself to be a static image
/// (not something this can work around), so this is the earliest point in
/// the app a video can play. Gated to first-launch-only (or every launch,
/// per the Settings toggle) via AppState.
struct IntroVideoView: View {
    @EnvironmentObject var appState: AppState
    @State private var player: AVPlayer?
    // Plays with sound by default — a silent "intro video" undersells an
    // engine/burnout clip. The person can still mute it themselves via the
    // button, which is the more natural direction for this kind of content.
    @State private var isMuted = false
    @State private var endObserver: NSObjectProtocol?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayerContainer(player: player)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: toggleMute) {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                FlameWelcomeText(text: NSLocalizedString("intro.welcome", comment: ""))
                    .padding(.bottom, 24)

                Spacer()

                Button(action: finish) {
                    Text(NSLocalizedString("intro.skip", comment: ""))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.black.opacity(0.45))
                        .cornerRadius(20)
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear { setupPlayer() }
        .onDisappear {
            player?.pause()
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
        }
    }

    private func setupPlayer() {
        // By default, AVPlayer's audio respects the hardware silent switch
        // the way "ambient" sounds do — meaning even with isMuted = false,
        // a phone with the silent switch flipped on would still play this
        // silently, which looks identical to "the video is muted" from the
        // person's perspective. Setting the session to .playback makes this
        // behave like actual video/music content and ignore the silent
        // switch, matching what people expect from an intro video with sound.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)

        guard let url = Bundle.main.url(forResource: "GTR_Burnout", withExtension: "mp4") else {
            // Video missing from the bundle for some reason — don't strand
            // the person on a black screen forever, just skip straight past
            // to whatever screen they'd normally see next.
            finish()
            return
        }
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.isMuted = isMuted
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in
            finish()
        }
        player = newPlayer
        newPlayer.play()
    }

    private func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    private func finish() {
        appState.finishIntro()
    }
}

/// Wraps AVPlayerViewController rather than using AVKit's native SwiftUI
/// VideoPlayer, so playback chrome (scrubber, play/pause bar) can be fully
/// hidden and the video can fill the screen edge-to-edge via
/// .resizeAspectFill — neither is easily achievable with the plain
/// VideoPlayer view.
private struct VideoPlayerContainer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

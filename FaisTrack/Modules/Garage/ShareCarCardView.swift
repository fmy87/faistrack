import SwiftUI

struct ShareCarCardView: View {
    let car: Car
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.ftBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Text(NSLocalizedString("garage.shareCard", comment: ""))
                    .font(.system(size: 22, weight: .bold))
                CarShareCard(car: car)
                FTPrimaryButton(title: NSLocalizedString("general.share", comment: "")) {
                    shareCard()
                }
                .padding(.horizontal, 40)
            }.padding(24)
        }
    }

    private func shareCard() {
        // Use UIGraphicsImageRenderer for iOS 15 compatibility (ImageRenderer is iOS 16+)
        let cardView = CarShareCard(car: car)
        let controller = UIHostingController(rootView: cardView)
        controller.view.bounds = CGRect(x: 0, y: 0, width: 320, height: 180)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 180))
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

struct CarShareCard: View {
    let car: Car
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(hex: "#1A0000")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 12) {
                Text("FaisTrack").font(.system(size: 14, weight: .bold))
                    .foregroundColor(.ftAccent)
                Text(car.displayName).font(.system(size: 28, weight: .black)).foregroundColor(.white)
                Text("\(car.year) \(car.make) \(car.model)").foregroundColor(.gray)
                if let hp = car.horsepower {
                    HStack {
                        Image(systemName: "bolt.fill").foregroundColor(.ftAccentOrange)
                        Text("\(hp) \(NSLocalizedString("garage.hpUnit", comment: ""))").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                    }
                }
            }.padding(24)
        }
        .cornerRadius(20)
        .frame(width: 320, height: 180)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

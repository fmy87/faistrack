import SwiftUI

struct CarCardView: View {
    let car: Car
    var isActive: Bool = false
    @State private var shineOffset: CGFloat = -1

    var body: some View {
        FTCard {
            HStack(spacing: 16) {
                if let url = car.photoURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: { Color.ftBackground }
                    .frame(width: 80, height: 80).cornerRadius(12)
                } else {
                    ZStack {
                        Color.ftBackground.cornerRadius(12)
                        Image(systemName: "car.fill").font(.system(size: 32)).foregroundColor(.ftAccent)
                    }.frame(width: 80, height: 80)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(car.displayName).font(.system(size: 17, weight: .bold))
                        Spacer()
                        if isActive {
                            Label(NSLocalizedString("garage.active", comment: ""), systemImage: "flag.checkered")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.ftGradient)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    Text("\(car.year) • \(car.make) \(car.model)")
                        .font(.system(size: 14)).foregroundColor(.ftTextSecondary)
                    if let hp = car.horsepower {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill").font(.caption).foregroundColor(.ftAccentOrange)
                            Text("\(hp) \(NSLocalizedString("garage.hpUnit", comment: ""))").font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(.ftTextSecondary)
            }
        }
        // The active car gets a glowing gradient border and a slow
        // diagonal light sweep — a quiet, ambient cue for "this is the one
        // currently being driven" that doesn't rely on the badge text alone.
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isActive ? AnyShapeStyle(Color.ftGradient) : AnyShapeStyle(Color.clear),
                    lineWidth: 2
                )
        )
        .shadow(color: isActive ? Color.ftAccent.opacity(0.35) : .clear, radius: 12)
        .overlay(shineOverlay)
        .onAppear {
            guard isActive else { return }
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                shineOffset = 2
            }
        }
    }

    @ViewBuilder
    private var shineOverlay: some View {
        if isActive {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.12), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: geo.size.width * 0.4)
                .rotationEffect(.degrees(20))
                .offset(x: shineOffset * geo.size.width)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

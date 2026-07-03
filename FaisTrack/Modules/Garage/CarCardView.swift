import SwiftUI

struct CarCardView: View {
    let car: Car
    var isActive: Bool = false

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
                            Text(NSLocalizedString("garage.active", comment: ""))
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.ftAccent).foregroundColor(.white)
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
    }
}

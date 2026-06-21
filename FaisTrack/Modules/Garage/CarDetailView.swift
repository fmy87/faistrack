import SwiftUI

struct CarDetailView: View {
    let car: Car
    @ObservedObject var viewModel: GarageViewModel
    @State private var showShare = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let url = car.photoURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.ftCard }
                    .frame(maxWidth: .infinity).frame(height: 220).cornerRadius(16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(car.displayName).font(.system(size: 28, weight: .black))
                    Text("\(car.year) \(car.make) \(car.model)")
                        .foregroundColor(.ftTextSecondary)
                }

                if let hp = car.horsepower {
                    FTCard {
                        HStack {
                            FTStatBadge(value: "\(hp)", label: "HP", color: .ftAccent)
                            Divider()
                            if let torque = car.torque {
                                FTStatBadge(value: "\(torque)", label: "Nm", color: .ftAccentOrange)
                                Divider()
                            }
                            if let engine = car.engineSize {
                                FTStatBadge(value: engine, label: NSLocalizedString("garage.engine", comment: ""))
                            }
                        }
                    }
                }

                if car.isTurbo || car.isSupercharged || car.suspensionNotes != nil || car.wheels != nil {
                    FTCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("garage.mods", comment: ""))
                                .font(.system(size: 16, weight: .bold))
                            if car.isTurbo { ModTag(label: NSLocalizedString("garage.turbo", comment: "")) }
                            if car.isSupercharged { ModTag(label: NSLocalizedString("garage.supercharged", comment: "")) }
                            if let susp = car.suspensionNotes { ModTag(label: susp) }
                            if let wheels = car.wheels { ModTag(label: wheels) }
                        }
                    }
                }

                FTPrimaryButton(title: car.isActive ?
                    NSLocalizedString("garage.active", comment: "") :
                    NSLocalizedString("garage.setActive", comment: "")) {
                    viewModel.setActive(car)
                }
                .disabled(car.isActive)
                .opacity(car.isActive ? 0.5 : 1)

                FTSecondaryButton(title: NSLocalizedString("garage.shareCard", comment: "")) {
                    showShare = true
                }
            }
            .padding(20)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(car.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShare) { ShareCarCardView(car: car) }
    }
}

struct ModTag: View {
    let label: String
    var body: some View {
        Text(label).font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.ftAccent.opacity(0.2))
            .foregroundColor(.ftAccent).cornerRadius(8)
    }
}

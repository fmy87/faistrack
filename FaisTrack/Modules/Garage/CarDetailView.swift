import SwiftUI

struct CarDetailView: View {
    let car: Car
    @ObservedObject var viewModel: GarageViewModel
    @State private var showShare = false
    @State private var showEdit = false

    /// Looks up the latest version of this car from the view model so that
    /// edits made via the Edit sheet (which calls GarageViewModel.saveCar,
    /// then reloads viewModel.cars) are reflected immediately here, instead
    /// of this screen staying stuck on the stale snapshot it was pushed with.
    private var currentCar: Car {
        viewModel.cars.first(where: { $0.id != nil && $0.id == car.id }) ?? car
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let url = currentCar.photoURL, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { img in img.resizable().scaledToFill() }
                    placeholder: { Color.ftCard }
                    .frame(maxWidth: .infinity).frame(height: 220).cornerRadius(16)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentCar.displayName).font(.system(size: 28, weight: .black))
                    Text("\(currentCar.year) \(currentCar.make) \(currentCar.model)")
                        .foregroundColor(.ftTextSecondary)
                }

                if let hp = currentCar.horsepower {
                    FTCard {
                        HStack {
                            FTStatBadge(value: "\(hp)", label: NSLocalizedString("garage.hpUnit", comment: ""), color: .ftAccent)
                            Divider()
                            if let torque = currentCar.torque {
                                FTStatBadge(value: "\(torque)", label: NSLocalizedString("garage.torqueUnit", comment: ""), color: .ftAccentOrange)
                                Divider()
                            }
                            if let engine = currentCar.engineSize {
                                FTStatBadge(value: engine, label: NSLocalizedString("garage.engine", comment: ""))
                            }
                        }
                    }
                }

                if currentCar.isTurbo || currentCar.isSupercharged || currentCar.suspensionNotes != nil || currentCar.wheels != nil {
                    FTCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("garage.mods", comment: ""))
                                .font(.system(size: 16, weight: .bold))
                            if currentCar.isTurbo { ModTag(label: NSLocalizedString("garage.turbo", comment: "")) }
                            if currentCar.isSupercharged { ModTag(label: NSLocalizedString("garage.supercharged", comment: "")) }
                            if let susp = currentCar.suspensionNotes { ModTag(label: susp) }
                            if let wheels = currentCar.wheels { ModTag(label: wheels) }
                        }
                    }
                }

                FTPrimaryButton(title: currentCar.isActive ?
                    NSLocalizedString("garage.active", comment: "") :
                    NSLocalizedString("garage.setActive", comment: "")) {
                    viewModel.setActive(currentCar)
                }
                .disabled(currentCar.isActive)
                .opacity(currentCar.isActive ? 0.5 : 1)

                FTSecondaryButton(title: NSLocalizedString("garage.shareCard", comment: "")) {
                    showShare = true
                }
            }
            .padding(20)
        }
        .background(Color.ftBackground.ignoresSafeArea())
        .navigationTitle(currentCar.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(NSLocalizedString("garage.edit", comment: "")) { showEdit = true }
            }
        }
        .sheet(isPresented: $showShare) { ShareCarCardView(car: currentCar) }
        .sheet(isPresented: $showEdit) { AddCarView(viewModel: viewModel, editingCar: currentCar) }
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

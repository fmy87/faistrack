import SwiftUI

struct GarageView: View {
    @StateObject private var viewModel = GarageViewModel()
    @EnvironmentObject var appState: AppState
    @State private var showAddCar = false
    @State private var showProPaywall = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                if viewModel.cars.isEmpty {
                    GarageEmptyState { showAddCar = true }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(viewModel.cars.enumerated()), id: \.1.id) { index, car in
                                StaggeredAppear(index: index) {
                                    NavigationLink(destination: CarDetailView(car: car, viewModel: viewModel)) {
                                        CarCardView(car: car, isActive: car.isActive)
                                            .contextMenu {
                                                Button { viewModel.setActive(car) } label: {
                                                    Label(NSLocalizedString("garage.setActive", comment: ""), systemImage: "checkmark.circle")
                                                }
                                                Button(role: .destructive) { viewModel.delete(car) } label: {
                                                    Label(NSLocalizedString("garage.delete", comment: ""), systemImage: "trash")
                                                }
                                            }
                                    }
                                }
                            }
                        }.padding(16)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("garage.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { handleAddCar() } label: {
                        Image(systemName: "plus").foregroundColor(.ftAccent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddCar) { AddCarView(viewModel: viewModel) }
        .sheet(isPresented: $showProPaywall) { ProPaywallView() }
        .task { await viewModel.loadCars() }
    }

    private func handleAddCar() {
        if viewModel.cars.count >= 3 && !appState.isProUser {
            showProPaywall = true
        } else {
            showAddCar = true
        }
    }
}

struct GarageEmptyState: View {
    let onAdd: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "car.2.fill").font(.system(size: 64)).foregroundColor(.ftAccent)
            Text(NSLocalizedString("garage.empty.title", comment: ""))
                .font(.system(size: 22, weight: .bold))
            Text(NSLocalizedString("garage.empty.subtitle", comment: ""))
                .foregroundColor(.ftTextSecondary).multilineTextAlignment(.center)
            FTPrimaryButton(title: NSLocalizedString("garage.addCar", comment: ""), action: onAdd)
                .padding(.horizontal, 40)
        }.padding(32)
    }
}


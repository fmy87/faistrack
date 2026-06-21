import SwiftUI
import FirebaseAuth

@MainActor
class GarageViewModel: ObservableObject {
    @Published var cars: [Car] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var uid: String { Auth.auth().currentUser?.uid ?? "" }

    func loadCars() async {
        isLoading = true
        cars = (try? await FirebaseService.shared.getCars(uid: uid)) ?? []
        isLoading = false
    }

    func saveCar(_ car: Car) async {
        var c = car
        c.ownerUID = uid
        try? await FirebaseService.shared.saveCar(c, uid: uid)
        await loadCars()
    }

    func delete(_ car: Car) {
        guard let id = car.id else { return }
        Task {
            try? await FirebaseService.shared.deleteCar(carId: id, uid: uid)
            await loadCars()
        }
    }

    func setActive(_ car: Car) {
        guard let id = car.id else { return }
        UserDefaults.standard.set(id, forKey: "activeCarId")
        Task {
            try? await FirebaseService.shared.setActiveCar(carId: id, uid: uid)
            await loadCars()
        }
    }
}

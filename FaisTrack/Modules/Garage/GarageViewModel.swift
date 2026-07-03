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
        errorMessage = nil
        do {
            cars = try await FirebaseService.shared.getCars(uid: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Returns true on success. Callers should only dismiss their UI when
    /// this returns true — previously this swallowed all errors via `try?`
    /// and the Add Car sheet dismissed unconditionally, so a failed save
    /// (e.g. a network blip or a permissions issue) looked identical to a
    /// successful one from the user's point of view.
    @discardableResult
    func saveCar(_ car: Car) async -> Bool {
        var c = car
        c.ownerUID = uid
        errorMessage = nil
        do {
            try await FirebaseService.shared.saveCar(c, uid: uid)
            await loadCars()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func delete(_ car: Car) {
        guard let id = car.id else { return }
        Task {
            do {
                try await FirebaseService.shared.deleteCar(carId: id, uid: uid)
                await loadCars()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func setActive(_ car: Car) {
        guard let id = car.id else { return }
        UserDefaults.standard.set(id, forKey: "activeCarId")
        Task {
            do {
                try await FirebaseService.shared.setActiveCar(carId: id, uid: uid)
                await loadCars()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

import SwiftUI
import PhotosUI

struct AddCarView: View {
    @ObservedObject var viewModel: GarageViewModel
    @Environment(\.dismiss) var dismiss
    @State private var step = 0
    @State private var car = Car(ownerUID: "", nickname: "", make: "", model: "", year: Calendar.current.component(.year, from: Date()))
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack {
                    ProgressView(value: Double(step + 1), total: 4)
                        .tint(.ftAccent).padding(.horizontal)

                    TabView(selection: $step) {
                        BasicInfoStep(car: $car).tag(0)
                        SpecsStep(car: $car).tag(1)
                        ModsStep(car: $car).tag(2)
                        PhotoStep(car: $car, selectedPhoto: $selectedPhoto, photoData: $photoData).tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    HStack(spacing: 16) {
                        if step > 0 {
                            FTSecondaryButton(title: NSLocalizedString("general.back", comment: "")) {
                                withAnimation { step -= 1 }
                            }
                        }
                        FTPrimaryButton(
                            title: step < 3 ? NSLocalizedString("general.next", comment: "") : NSLocalizedString("garage.saveCar", comment: ""),
                            isLoading: isSaving
                        ) {
                            if step < 3 { withAnimation { step += 1 } }
                            else { saveCar() }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 32)
                }
            }
            .navigationTitle(NSLocalizedString("garage.addCar", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }

    private func saveCar() {
        isSaving = true
        Task {
            await viewModel.saveCar(car)
            isSaving = false
            dismiss()
        }
    }
}

struct BasicInfoStep: View {
    @Binding var car: Car
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("garage.step.basic", comment: ""))
                    .font(.system(size: 24, weight: .bold))
                FTInputField(title: NSLocalizedString("garage.nickname", comment: ""),
                             placeholder: "e.g. The Beast", text: $car.nickname)
                FTInputField(title: NSLocalizedString("garage.make", comment: ""),
                             placeholder: "e.g. Nissan", text: $car.make)
                FTInputField(title: NSLocalizedString("garage.model", comment: ""),
                             placeholder: "e.g. 350Z", text: $car.model)
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("garage.year", comment: ""))
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.ftTextSecondary)
                    Stepper("\(car.year)", value: $car.year, in: 1950...2026)
                        .padding().background(Color.ftCard).cornerRadius(12)
                }
            }.padding(24)
        }
    }
}

struct SpecsStep: View {
    @Binding var car: Car
    @State private var hpString = ""
    @State private var torqueString = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("garage.step.specs", comment: ""))
                    .font(.system(size: 24, weight: .bold))
                FTInputField(title: NSLocalizedString("garage.engineSize", comment: ""),
                             placeholder: "e.g. 3.5L", text: Binding(
                                get: { car.engineSize ?? "" },
                                set: { car.engineSize = $0 }))
                FTInputField(title: NSLocalizedString("garage.hp", comment: ""),
                             placeholder: "e.g. 300", text: $hpString, keyboardType: .numberPad)
                    .onChange(of: hpString) { car.horsepower = Int($0) }
                FTInputField(title: NSLocalizedString("garage.torque", comment: ""),
                             placeholder: "e.g. 400 Nm", text: $torqueString, keyboardType: .numberPad)
                    .onChange(of: torqueString) { car.torque = Int($0) }
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("garage.forced", comment: ""))
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.ftTextSecondary)
                    Toggle(NSLocalizedString("garage.turbo", comment: ""), isOn: $car.isTurbo)
                    Toggle(NSLocalizedString("garage.supercharged", comment: ""), isOn: $car.isSupercharged)
                }
                .padding().background(Color.ftCard).cornerRadius(12)
            }.padding(24)
        }
    }
}

struct ModsStep: View {
    @Binding var car: Car
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(NSLocalizedString("garage.step.mods", comment: ""))
                    .font(.system(size: 24, weight: .bold))
                FTInputField(title: NSLocalizedString("garage.suspension", comment: ""),
                             placeholder: "e.g. KW Coilovers", text: Binding(
                                get: { car.suspensionNotes ?? "" },
                                set: { car.suspensionNotes = $0 }))
                FTInputField(title: NSLocalizedString("garage.wheels", comment: ""),
                             placeholder: "e.g. 19\" Rays", text: Binding(
                                get: { car.wheels ?? "" },
                                set: { car.wheels = $0 }))
            }.padding(24)
        }
    }
}

struct PhotoStep: View {
    @Binding var car: Car
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var photoData: Data?
    var body: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("garage.step.photo", comment: ""))
                .font(.system(size: 24, weight: .bold))
            if let data = photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 240, height: 160).cornerRadius(16)
            } else {
                RoundedRectangle(cornerRadius: 16).fill(Color.ftCard)
                    .frame(width: 240, height: 160)
                    .overlay(Image(systemName: "camera.fill").font(.system(size: 40)).foregroundColor(.ftAccent))
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text(NSLocalizedString("garage.addPhoto", comment: ""))
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.ftAccent)
            }
            .onChange(of: selectedPhoto) { item in
                Task {
                    photoData = try? await item?.loadTransferable(type: Data.self)
                }
            }
        }.padding(24)
    }
}

struct FTInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(.ftTextSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(14).background(Color.ftCard).cornerRadius(12)
        }
    }
}

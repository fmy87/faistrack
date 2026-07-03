import SwiftUI
import PhotosUI

struct AddCarView: View {
    @ObservedObject var viewModel: GarageViewModel
    @Environment(\.dismiss) var dismiss
    @State private var step = 0
    @State private var car: Car
    @State private var photoData: Data?
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    private let isEditing: Bool

    /// Pass `editingCar` to reuse this flow for editing an existing car —
    /// it pre-fills every step with the car's current values and saves back
    /// to the same document instead of creating a new one (GarageViewModel.saveCar
    /// already updates in place when the car has an id).
    init(viewModel: GarageViewModel, editingCar: Car? = nil) {
        self.viewModel = viewModel
        self.isEditing = editingCar != nil
        _car = State(initialValue: editingCar ?? Car(
            ownerUID: "", nickname: "", make: "", model: "",
            year: Calendar.current.component(.year, from: Date())
        ))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.ftBackground.ignoresSafeArea()
                VStack {
                    ProgressView(value: Double(step + 1), total: 4)
                        .tint(.ftAccent).padding(.horizontal)

                    if let saveErrorMessage {
                        Text(saveErrorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.speedRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }

                    TabView(selection: $step) {
                        BasicInfoStep(car: $car).tag(0)
                        SpecsStep(car: $car).tag(1)
                        ModsStep(car: $car).tag(2)
                        PhotoStep(car: $car, photoData: $photoData).tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    HStack(spacing: 16) {
                        if step > 0 {
                            FTSecondaryButton(title: NSLocalizedString("general.back", comment: "")) {
                                withAnimation { step -= 1 }
                            }
                        }
                        FTPrimaryButton(
                            title: step < 3 ? NSLocalizedString("general.next", comment: "") : (isEditing ? NSLocalizedString("garage.saveChanges", comment: "") : NSLocalizedString("garage.saveCar", comment: "")),
                            isLoading: isSaving
                        ) {
                            if step < 3 { withAnimation { step += 1 } }
                            else { saveCar() }
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 32)
                }
            }
            .navigationTitle(isEditing ? NSLocalizedString("garage.editCar", comment: "") : NSLocalizedString("garage.addCar", comment: ""))
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
        saveErrorMessage = nil
        Task {
            let success = await viewModel.saveCar(car)
            isSaving = false
            if success {
                dismiss()
            } else {
                saveErrorMessage = viewModel.errorMessage ?? NSLocalizedString("garage.saveFailed", comment: "")
            }
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
                             placeholder: NSLocalizedString("garage.nicknamePlaceholder", comment: ""), text: $car.nickname)
                FTInputField(title: NSLocalizedString("garage.make", comment: ""),
                             placeholder: NSLocalizedString("garage.makePlaceholder", comment: ""), text: $car.make)
                FTInputField(title: NSLocalizedString("garage.model", comment: ""),
                             placeholder: NSLocalizedString("garage.modelPlaceholder", comment: ""), text: $car.model)
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
                             placeholder: NSLocalizedString("garage.engineSizePlaceholder", comment: ""), text: Binding(
                                get: { car.engineSize ?? "" },
                                set: { car.engineSize = $0 }))
                FTInputField(title: NSLocalizedString("garage.hp", comment: ""),
                             placeholder: NSLocalizedString("garage.hpPlaceholder", comment: ""), text: $hpString, keyboardType: .numberPad)
                    .onChange(of: hpString) { newVal in car.horsepower = Int(newVal) }
                FTInputField(title: NSLocalizedString("garage.torque", comment: ""),
                             placeholder: NSLocalizedString("garage.torquePlaceholder", comment: ""), text: $torqueString, keyboardType: .numberPad)
                    .onChange(of: torqueString) { newVal in car.torque = Int(newVal) }
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
                             placeholder: NSLocalizedString("garage.suspensionPlaceholder", comment: ""), text: Binding(
                                get: { car.suspensionNotes ?? "" },
                                set: { car.suspensionNotes = $0 }))
                FTInputField(title: NSLocalizedString("garage.wheels", comment: ""),
                             placeholder: NSLocalizedString("garage.wheelsPlaceholder", comment: ""), text: Binding(
                                get: { car.wheels ?? "" },
                                set: { car.wheels = $0 }))
            }.padding(24)
        }
    }
}

// UIImagePickerController wrapper for iOS 15 compatibility
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct PhotoStep: View {
    @Binding var car: Car
    @Binding var photoData: Data?
    @State private var showPicker = false

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
            Button {
                showPicker = true
            } label: {
                Text(NSLocalizedString("garage.addPhoto", comment: ""))
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.ftAccent)
            }
            .sheet(isPresented: $showPicker) {
                ImagePicker(imageData: $photoData)
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


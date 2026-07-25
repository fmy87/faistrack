import SwiftUI
import CoreLocation
import MapKit

/// Lets the admin create a track by naming it and tapping two points on a
/// map — no driving required. Answers "how do I add tracks remotely
/// without physically driving them" directly, rather than needing manual
/// Firestore console edits every time. Restricted to AdminConfig's UID
/// both here and (for the underlying write itself, more importantly) via
/// the Firestore rules you'll need to update — this UI gate alone isn't
/// real security.
struct AdminCreateTrackView: View {
    @Environment(\.dismiss) var dismiss
    var onCreated: (() -> Void)?

    @State private var trackName = ""
    @State private var startCoordinate: CLLocationCoordinate2D?
    @State private var endCoordinate: CLLocationCoordinate2D?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var distanceMeters: Double? {
        guard let start = startCoordinate, let end = endCoordinate else { return nil }
        return CLLocation(latitude: start.latitude, longitude: start.longitude)
            .distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
    }

    private var canSave: Bool {
        !isSaving && !trackName.trimmingCharacters(in: .whitespaces).isEmpty &&
        (distanceMeters ?? 0) >= Track.minimumDistanceMeters
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text(NSLocalizedString("admin.createTrack.instructions", comment: ""))
                    .font(.system(size: 13)).foregroundColor(.ftTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                AdminTrackMapPicker(startCoordinate: $startCoordinate, endCoordinate: $endCoordinate)
                    .frame(height: 300)
                    .cornerRadius(16)
                    .padding(.horizontal)

                TextField(NSLocalizedString("createTrack.namePlaceholder", comment: ""), text: $trackName)
                    .padding(14).background(Color.ftCard).cornerRadius(12)
                    .padding(.horizontal)

                if let distanceMeters {
                    Text(String(format: "%.0f m", distanceMeters))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(distanceMeters >= Track.minimumDistanceMeters ? .ftAccent : .speedRed)
                }

                if let errorMessage {
                    Text(errorMessage).font(.system(size: 12)).foregroundColor(.speedRed)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                Spacer()

                FTPrimaryButton(title: NSLocalizedString("admin.createTrack.save", comment: ""), isLoading: isSaving) {
                    Task { await save() }
                }
                .disabled(!canSave)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .padding(.top, 12)
            .background(Color.ftBackground.ignoresSafeArea())
            .navigationTitle(NSLocalizedString("admin.createTrack.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("general.cancel", comment: "")) { dismiss() }
                }
            }
        }
    }

    private func save() async {
        guard let start = startCoordinate, let end = endCoordinate,
              let uid = AuthService.shared.currentUser?.uid,
              let straightLineDistance = distanceMeters else { return }
        isSaving = true
        errorMessage = nil
        do {
            let username = (try? await FirebaseService.shared.getUser(uid: uid))?.username
                ?? NSLocalizedString("general.defaultUsername", comment: "")
            // Ask Apple Maps for an actual driving route between the two
            // tapped points instead of just connecting them with a straight
            // line — previously every admin-created track showed as a
            // ruler-straight red line cutting across fields and buildings
            // on the detail map, regardless of what roads were actually
            // there. Falls back to the straight line only if routing
            // genuinely fails (offline, no road route found, etc.) — a
            // straight-line track is still usable, just not accurate.
            let (routeCoordinates, routeDistance) = await fetchRoadRoute(from: start, to: end) ?? ([start, end], straightLineDistance)
            let track = Track(
                ownerUID: uid,
                ownerUsername: username,
                name: trackName,
                startLatitude: start.latitude,
                startLongitude: start.longitude,
                endLatitude: end.latitude,
                endLongitude: end.longitude,
                distance: routeDistance,
                polylineEncoded: PolylineCodec.encode(routeCoordinates)
            )
            _ = try await FirebaseService.shared.createTrack(track)
            onCreated?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    /// Returns the actual road-following route (coordinates + real driving
    /// distance) between two points, or nil if Apple's routing couldn't
    /// find one (e.g. offline, or the points aren't reachable by road).
    private func fetchRoadRoute(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) async -> ([CLLocationCoordinate2D], Double)? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
        request.transportType = .automobile
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }
            let polyline = route.polyline
            var coordinates = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
            polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
            return (coordinates, route.distance)
        } catch {
            return nil
        }
    }
}

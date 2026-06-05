import CoreLocation
import Foundation
import UIKit

/// Asks the user for "When in use" location permission, fetches a single GPS sample,
/// and pings the backend at `/api/activity/location` whenever the app comes to foreground.
@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    /// Latest GPS sample. Updated on each `requestLocation()` callback.
    @Published private(set) var lastKnownLocation: CLLocation?

    private let manager = CLLocationManager()
    private let apiClient = APIClient.shared
    private var lastPingedAt: Date?
    private let minPingInterval: TimeInterval = 60 // seconds

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 200

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    /// Called from AuthService once the user is authenticated.
    /// Triggers the permission prompt on first call.
    @Published private(set) var isTracking = false

    func startIfPermitted() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            isTracking = true
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        isTracking = false
        lastKnownLocation = nil
    }

    @objc private func handleForeground() {
        guard apiClient.isAuthenticated() else { return }
        guard manager.authorizationStatus == .authorizedWhenInUse
           || manager.authorizationStatus == .authorizedAlways else { return }

        if let last = lastPingedAt, Date().timeIntervalSince(last) < minPingInterval {
            return
        }
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in
                guard apiClient.isAuthenticated() else { return }
                manager.startUpdatingLocation()
                self.isTracking = true
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastKnownLocation = loc
            await self.sendLocation(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
        print("[LocationService] error: \(error)")
        #endif
    }

    private func sendLocation(_ loc: CLLocation) async {
        guard apiClient.isAuthenticated() else { return }
        if let last = lastPingedAt, Date().timeIntervalSince(last) < minPingInterval { return }

        let body = LocationPingRequest(
            latitude:  loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            accuracy:  loc.horizontalAccuracy >= 0 ? loc.horizontalAccuracy : nil,
            platform:  "ios"
        )

        do {
            try await apiClient.postVoid(
                path: APIConfig.Endpoints.activityLocation,
                body: body,
                requiresAuth: true
            )
            lastPingedAt = Date()
        } catch {
            #if DEBUG
            print("[LocationService] ping failed: \(error)")
            #endif
        }
    }
}

private struct LocationPingRequest: Encodable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?
    let platform: String
}

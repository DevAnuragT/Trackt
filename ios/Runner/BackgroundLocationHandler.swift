import Foundation
import CoreLocation
import UIKit

@available(iOS 10.0, *)
class BackgroundLocationHandler: NSObject, CLLocationManagerDelegate {
    
    static let shared = BackgroundLocationHandler()
    private let locationManager = CLLocationManager()
    
    private override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2.0 // 2 meters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request always authorization for background location
        locationManager.requestAlwaysAuthorization()
    }
    
    func startBackgroundLocationUpdates() {
        print("🔄 Starting iOS background location updates...")
        
        // Ensure background location is enabled
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                locationManager.startUpdatingLocation()
                print("✅ iOS background location started successfully")
            case .authorizedWhenInUse:
                print("⚠️ Need 'Always' location permission for background tracking")
                locationManager.requestAlwaysAuthorization()
            case .denied, .restricted:
                print("❌ Location permission denied")
            case .notDetermined:
                print("⏳ Location permission not determined")
                locationManager.requestAlwaysAuthorization()
            @unknown default:
                print("❓ Unknown authorization status")
            }
        } else {
            print("❌ Location services disabled")
        }
    }
    
    func stopBackgroundLocationUpdates() {
        print("🔄 Stopping iOS background location updates...")
        locationManager.stopUpdatingLocation()
        print("✅ iOS background location stopped")
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Log location updates for debugging
        print("📍 iOS Location Update: \(location.coordinate.latitude), \(location.coordinate.longitude) ±\(location.horizontalAccuracy)m")
        
        // Send location to Flutter via method channel if needed
        // This would be implemented if you need to bridge location data
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ iOS Location Error: \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            print("✅ iOS location permission granted (Always)")
            // Auto-start location updates if we have permission
            if UIApplication.shared.applicationState == .background {
                startBackgroundLocationUpdates()
            }
        case .authorizedWhenInUse:
            print("⚠️ iOS location permission granted (When In Use)")
        case .denied:
            print("❌ iOS location permission denied")
        case .restricted:
            print("🚫 iOS location permission restricted")
        case .notDetermined:
            print("⏳ iOS location permission not determined")
        @unknown default:
            print("❓ Unknown iOS location authorization status")
        }
    }
    
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("⏸️ iOS location updates paused automatically")
        // Restart location updates to ensure continuous tracking
        locationManager.startUpdatingLocation()
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("▶️ iOS location updates resumed")
    }
}

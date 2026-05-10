import SwiftUI

@main
struct ReveEtVoyageApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(AuthService.shared)
        }
    }
}

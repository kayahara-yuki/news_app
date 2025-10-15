import SwiftUI

@main
struct LocationNewsSNSApp: App {
    @StateObject private var dependencyContainer = DependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .withDependencies()
                .environmentObject(dependencyContainer)
                .environmentObject(dependencyContainer.nearbyPostsViewModel)
        }
    }
}
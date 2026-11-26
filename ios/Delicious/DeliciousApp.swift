import DeliciousCore
import SwiftUI

@main
struct DeliciousApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(.white)
                .onOpenURL { url in model.handleOpenURL(url) }
        }
    }
}

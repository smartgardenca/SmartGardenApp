
import SwiftUI

@main
struct SmartGardenAppApp: App {
    var body: some Scene {
        WindowGroup {
            WebView(url: URL(string: "https://app.smart-garden.ca")!)
        }
    }
}

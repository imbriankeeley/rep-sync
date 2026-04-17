import CoreData
import SwiftUI

@main
struct RepSyncApp: App {
    private let persistenceController = PersistenceController.shared
    @StateObject private var appModel: RepSyncAppModel

    init() {
        let controller = PersistenceController.shared
        self._appModel = StateObject(wrappedValue: RepSyncAppModel(context: controller.container.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            RepSyncRootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appModel)
        }
    }
}

import CoreData
import SwiftUI

final class RepSyncApplicationDelegate: NSObject, UIApplicationDelegate {
    static var urlHandler: ((URL) -> Void)?

    func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Self.urlHandler?(url)
        return true
    }
}

@main
struct RepSyncApp: App {
    @UIApplicationDelegateAdaptor(RepSyncApplicationDelegate.self) private var applicationDelegate
    private let persistenceController = PersistenceController.shared
    @StateObject private var appModel: RepSyncAppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let controller = PersistenceController.shared
        self._appModel = StateObject(wrappedValue: RepSyncAppModel(context: controller.container.viewContext))
    }

    var body: some Scene {
        WindowGroup {
            RepSyncRootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appModel)
                .onAppear {
                    RepSyncApplicationDelegate.urlHandler = { url in
                        appModel.handleIncomingURL(url)
                    }
                }
                .onOpenURL { url in
                    appModel.handleIncomingURL(url)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                appModel.handleSceneDidBecomeActive()
            case .inactive, .background:
                appModel.handleSceneWillResignActive()
            @unknown default:
                break
            }
        }
    }
}

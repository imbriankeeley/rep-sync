import CoreData
import Foundation

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = PersistenceController.makeContainer(inMemory: inMemory)
        PersistenceController.configureViewContext(container.viewContext)
    }

    @MainActor
    static let preview: PersistenceController = PersistenceController(inMemory: true)

    private static func makeContainer(inMemory: Bool) -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(name: "RepSync")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.cloudKitContainerOptions = cloudKitOptionsIfConfigured()

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let loadError, description.cloudKitContainerOptions != nil {
            let fallback = NSPersistentCloudKitContainer(name: "RepSync")
            guard let fallbackDescription = fallback.persistentStoreDescriptions.first else {
                fatalError("Missing fallback persistent store description.")
            }

            if inMemory {
                fallbackDescription.url = URL(fileURLWithPath: "/dev/null")
            }

            fallbackDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            fallbackDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            fallbackDescription.cloudKitContainerOptions = nil

            var fallbackError: Error?
            fallback.loadPersistentStores { _, error in
                fallbackError = error
            }

            if let fallbackError {
                let nsError = fallbackError as NSError
                fatalError("Failed to load persistent stores after local fallback. Original error: \(loadError). Fallback error: \(nsError), \(nsError.userInfo)")
            }

            return fallback
        } else if let loadError {
            let nsError = loadError as NSError
            fatalError("Failed to load persistent stores: \(nsError), \(nsError.userInfo)")
        }

        return container
    }

    private static func configureViewContext(_ context: NSManagedObjectContext) {
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.undoManager = nil
    }

    private static func cloudKitOptionsIfConfigured() -> NSPersistentCloudKitContainerOptions? {
        guard
            let entitlementsPath = Bundle.main.path(forResource: "RepSync", ofType: "entitlements"),
            let entitlements = NSDictionary(contentsOfFile: entitlementsPath),
            let identifiers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String],
            let identifier = identifiers.first,
            !identifier.isEmpty
        else {
            return nil
        }

        return NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
    }
}

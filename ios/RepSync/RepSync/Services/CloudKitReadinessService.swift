import Foundation

struct CloudKitReadinessService {
    static var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
}

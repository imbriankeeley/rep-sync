import SpotifyiOS
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    lazy var rootViewController = ViewController()
    var sessionManager: SPTSessionManager!
    var appRemote: SPTAppRemote!

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {

        // Use this method if your SpotifyRedirectURL is a custom URL scheme

        guard let urlContext = URLContexts.first else { return }
        _ = rootViewController.sessionManager.application(UIApplication.shared, open: urlContext.url)
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {

        // Use this method if your SpotifyRedirectURL is a universal link

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            _ = rootViewController.sessionManager.application(UIApplication.shared, open: url)
        }
    }
}

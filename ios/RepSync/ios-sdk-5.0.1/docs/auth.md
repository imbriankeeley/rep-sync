# Auth

This is only necessary if you want to authenticate even if the Spotify app isn't installed or without starting music playback.

## SPTSessionManager

Use the `SPTSessionManager` to start the authentication flow and get an access token.

- If the Spotify app is installed: The SDK constructs a custom URL scheme request and opens it, which triggers the Spotify app to handle the authorization.
- If the Spotify app is not installed: The SDK falls back to ASWebAuthentication to open a web-based login flow.

## PKCE vs Token Swap

The SDK exchanges the authorization code for access and refresh tokens:

- **PKCE Method**: The SDK implements the Proof Key for Code Exchange (PKCE) flow. It directly sends a request to the Spotify token exchange endpoint.

- **Token Swap URL**: This optional configuration protects your client secret by keeping it on your backend server instead of in your mobile app. When using this method:
  - Set up two endpoints on your backend: one for token exchange and one for token refresh
  - The SDK sends the authorization code to your backend service
  - Your backend service securely communicates with Spotify's token endpoint using your client secret
  - This approach prevents exposing your client secret in your mobile app
  - See `../DemoProjects/spotify_token_swap.rb` for a reference implementation

### Using the `SPTSessionManager` Authorization Flow

1. Add the Spotify scheme to your app's Info.plist file:

    ```xml
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>spotify</string>
    </array>
    ```

2. Initialize `SPTConfiguration` with your client ID and redirect URI.

    ```swift
    let configuration = SPTConfiguration(
        clientID: "your_client_id",
        redirectURL: URL(string: "your_redirect_uri")!
    )

    // Optional: If you plan to connect SPTAppRemote you can start playback during authorization by setting playURI to a non-nil string. If Spotify is already playing it will continue playing even though a URI is provided.
    configuration.playURI = ""
    ```

3. (Optional) If you want to implement the token swap URL method, set your token swap and refresh URLs. These endpoints will hold your client secret and communicate with Spotify's servers to get an OAuth token.

    ```swift
    // Set these URLs to your backend which contains the secret to exchange for an access token
    configuration.tokenSwapURL = URL(string: "http://[your_server]/swap")
    configuration.tokenRefreshURL = URL(string: "http://[your_server]/refresh")
    ```

4. Initialize `SPTSessionManager` with your configuration and delegate.

    ```swift
    self.sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
    ```

5. Configure your `SceneDelegate` to parse the returned token from the Spotify app.

    **Custom URL Schemes**

    If your redirect URI is configured as a custom URL scheme (myapp://callback), implement the `scene:openURLContexts:` method:

    ```swift
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        sessionManager.application(UIApplication.shared, open: url, options: [:])
    }
    ```

    **Universal Links**

    If your redirect URI is configured as a Universal Link, implement the `scene:continueUserActivity:` method:

    ```swift
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb {
            sessionManager.application(UIApplication.shared, continue: userActivity, restorationHandler: nil)
        }
    }
    ```

    **For Legacy AppDelegate Pattern (iOS 12 and below)**

    If you are using the legacy AppDelegate pattern, use the following methods instead:

    ```swift
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Use this method if your SpotifyRedirectURL is a custom URL scheme (myapp://callback)
        return sessionManager.application(application, open: url, options: options)
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Use this method if your SpotifyRedirectURL is a universal link (https://myapp.com/callback)
        return sessionManager.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }
    ```

7. Implement the `SPTSessionManagerDelegate` to handle authorization responses.

    ```swift
    // MARK: - SPTSessionManagerDelegate

    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        // Authorization Failed
    }

    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        // Session Renewed
    }

    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        // Authorization Succeeded
    }
    ```

7. (Optional) If using `SPTAppRemote` to control playback, be sure to set the returned token on its connection parameters in the `SPTSessionManager` delegate callback.

    ```swift
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        appRemote.connectionParameters.accessToken = session.accessToken
    }
    ```

8. Initiate the authorization process

    ```swift
    /*
    Scopes let you specify exactly what types of data your application wants to
    access, and the set of scopes you pass in your call determines what access
    permissions the user is asked to grant.
    For more information, see https://developer.spotify.com/web-api/using-scopes/.
    */
    let scope: SPTScope = [.userFollowRead, .appRemoteControl]

    sessionManager.initiateSession(with: scope, options: .default, campaign: nil)
    ```

## Authorization Options

The SDK supports different authorization strategies through the `SPTAuthorizationOptions` parameter:

### `SPTDefaultAuthorizationOption`
Uses automatic detection to choose the best authentication method based on whether the Spotify app is installed.

```swift
sessionManager.initiateSession(with: scope, options: .default, campaign: nil)
```

### `SPTClientAuthorizationOption`
Forces authentication through the Spotify app only. Authorization will fail if the Spotify app is not installed.

```swift
sessionManager.initiateSession(with: scope, options: .clientOnly, campaign: nil)
```

### `SPTSpotifySchemeNotRegisteredAuthorizationOption`

iOS restricts apps to a maximum of 50 URL schemes in `LSApplicationQueriesSchemes`. This option bypasses the `canOpenURL` check and attempts to open the Spotify app directly using `openURL:options:completionHandler:`.

**Note:** This option does NOT require adding the Spotify URL scheme to `LSApplicationQueriesSchemes`, making it useful when you've reached the 50 scheme limit. This is recommended only for apps that have reached the limit in the Info.plist file.


```swift
sessionManager.initiateSession(with: scope, options: .spotifySchemeNotRegistered, campaign: nil)
```

You can combine options:

```swift
let options: SPTAuthorizationOptions = [.clientOnly, .spotifySchemeNotRegistered]
sessionManager.initiateSession(with: scope, options: options, campaign: nil)
```

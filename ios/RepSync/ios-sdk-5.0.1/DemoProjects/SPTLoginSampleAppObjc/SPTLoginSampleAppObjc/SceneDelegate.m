#import "SceneDelegate.h"
#import "ViewController.h"

@implementation SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions
{
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    if (![windowScene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    self.window = [[UIWindow alloc] initWithWindowScene:windowScene];
    self.rootViewController = [[ViewController alloc] init];
    self.window.rootViewController = self.rootViewController;
    [self.window makeKeyAndVisible];
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
    // Use this method if your SpotifyRedirectURL is a custom URL scheme

    if (URLContexts.count > 0) {
        NSURL *url = [URLContexts.anyObject URL];
        if (url != nil) {
            [self.rootViewController.sessionManager application:[UIApplication sharedApplication]
                                                        openURL:url
                                                        options:@{}];
        }
    }
}

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity
{
    // Use this method if your SpotifyRedirectURL is a universal link

    if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSURL *url = userActivity.webpageURL;
        if (url != nil) {
            [self.rootViewController.sessionManager application:[UIApplication sharedApplication]
                                                        openURL:url
                                                        options:@{}];
        }
    }
}

@end

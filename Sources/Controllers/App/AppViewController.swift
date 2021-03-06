////
///  AppViewController.swift
//

import SwiftyUserDefaults
import Crashlytics


struct NavigationNotifications {
    static let showingNotificationsTab = TypedNotification<[String]>(name: "co.ello.NavigationNotification.NotificationsTab")
}


@objc
protocol HasAppController {
    var parentAppController: AppViewController? { get set }
}


public class AppViewController: BaseElloViewController {
    var mockScreen: AppScreenProtocol?
    var screen: AppScreenProtocol { return mockScreen ?? (self.view as! AppScreenProtocol) }

    var visibleViewController: UIViewController?
    private var userLoggedOutObserver: NotificationObserver?
    private var receivedPushNotificationObserver: NotificationObserver?
    private var externalWebObserver: NotificationObserver?
    private var apiOutOfDateObserver: NotificationObserver?

    private var pushPayload: PushPayload?

    private var deepLinkPath: String?

    override public func loadView() {
        self.view = AppScreen()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupNotificationObservers()
    }

    deinit {
        removeNotificationObservers()
    }

    var isStartup = true
    override public func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if isStartup {
            isStartup = false
            checkIfLoggedIn()
        }
    }

    public override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        postNotification(Application.Notifications.ViewSizeWillChange, value: size)
    }

    public override func didSetCurrentUser() {
        super.didSetCurrentUser()
        ElloWebBrowserViewController.currentUser = currentUser

        if let vc = visibleViewController as? ControllerThatMightHaveTheCurrentUser {
            vc.currentUser = currentUser
        }
    }

// MARK: - Private

    private func checkIfLoggedIn() {
        let authToken = AuthToken()
        let introDisplayed = GroupDefaults["IntroDisplayed"].bool ?? false

        if authToken.isPasswordBased {
            self.loadCurrentUser()
        }
        else if !introDisplayed {
            presentViewController(IntroViewController(), animated: false) {
                GroupDefaults["IntroDisplayed"] = true
                self.showStartupScreen()
            }
        }
        else {
            self.showLoginScreen(animated: false)
        }
    }

    public func loadCurrentUser(failure: ElloErrorCompletion? = nil) {
        let failureCompletion: ElloErrorCompletion
        if let failure = failure {
            failureCompletion = failure
        }
        else {
            screen.animateLogo()
            failureCompletion = { _ in
                self.screen.stopAnimatingLogo()
            }
        }

        ProfileService().loadCurrentUser(
            success: { user in
                self.screen.stopAnimatingLogo()
                self.currentUser = user

                let shouldShowOnboarding = Onboarding.shared().showOnboarding(user)
                if shouldShowOnboarding {
                    self.showOnboardingScreen(user)
                }
                else {
                    self.showMainScreen(user)
                }
            },
            failure: { (error, _) in
                self.failedToLoadCurrentUser(failureCompletion, error: error)
            })
    }

    func failedToLoadCurrentUser(failure: ElloErrorCompletion?, error: NSError) {
        showStartupScreen()
        failure?(error: error)
    }

    private func setupNotificationObservers() {
        userLoggedOutObserver = NotificationObserver(notification: AuthenticationNotifications.userLoggedOut) { [unowned self] in
            self.userLoggedOut()
        }
        receivedPushNotificationObserver = NotificationObserver(notification: PushNotificationNotifications.interactedWithPushNotification) { [unowned self] payload in
            self.receivedPushNotification(payload)
        }
        externalWebObserver = NotificationObserver(notification: ExternalWebNotification) { [unowned self] url in
            self.showExternalWebView(url)
        }
        apiOutOfDateObserver = NotificationObserver(notification: ErrorStatusCode.Status410.notification) { [unowned self] error in
            let message = InterfaceString.App.OldVersion
            let alertController = AlertViewController(message: message)

            let action = AlertAction(title: InterfaceString.OK, style: .Dark, handler: nil)
            alertController.addAction(action)

            self.presentViewController(alertController, animated: true, completion: nil)
            self.apiOutOfDateObserver?.removeObserver()
            postNotification(AuthenticationNotifications.invalidToken, value: false)
        }
    }

    private func removeNotificationObservers() {
        userLoggedOutObserver?.removeObserver()
        receivedPushNotificationObserver?.removeObserver()
        externalWebObserver?.removeObserver()
        apiOutOfDateObserver?.removeObserver()
    }

}


// MARK: Screens
extension AppViewController {

    private func showStartupScreen(completion: ElloEmptyCompletion = {}) {
        guard !((visibleViewController as? UINavigationController)?.visibleViewController is StartupViewController) else { return }

        Tracker.sharedTracker.screenAppeared("Startup")
        let startupController = StartupViewController()
        startupController.parentAppController = self
        let nav = ElloNavigationController(rootViewController: startupController)
        nav.navigationBarHidden = true
        swapViewController(nav, completion: completion)
    }

    public func showJoinScreen(animated animated: Bool, invitationCode: String? = nil) {
        guard let nav = visibleViewController as? UINavigationController else {
            showStartupScreen() { self.showJoinScreen(animated: animated) }
            return
        }

        if !(nav.visibleViewController is StartupViewController) {
            nav.popToRootViewControllerAnimated(false)
        }
        guard let startupController = nav.visibleViewController as? StartupViewController else { return }

        pushPayload = .None
        let joinController = JoinViewController()
        joinController.parentAppController = self
        joinController.invitationCode = invitationCode
        nav.setViewControllers([startupController, joinController], animated: animated)
    }

    public func showLoginScreen(animated animated: Bool) {
        showStartupScreen()
        guard let nav = visibleViewController as? UINavigationController else { return }

        if !(nav.visibleViewController is StartupViewController) {
            nav.popToRootViewControllerAnimated(false)
        }
        guard let startupController = nav.visibleViewController as? StartupViewController else { return }

        pushPayload = .None
        let loginController = LoginViewController()
        loginController.parentAppController = self
        nav.setViewControllers([startupController, loginController], animated: animated)
    }

    public func showOnboardingScreen(user: User) {
        currentUser = user

        let vc = OnboardingViewController()
        vc.parentAppController = self
        vc.currentUser = user

        swapViewController(vc) {}
    }

    public func doneOnboarding() {
        Onboarding.shared().updateVersionToLatest()
        self.showMainScreen(currentUser!)
    }

    public func showMainScreen(user: User) {
        Tracker.sharedTracker.identify(user)

        let vc = ElloTabBarController.instantiateFromStoryboard()
        ElloWebBrowserViewController.elloTabBarController = vc
        vc.currentUser = user

        swapViewController(vc) {
            if let payload = self.pushPayload {
                self.navigateToDeepLink(payload.applicationTarget)
                self.pushPayload = .None
            }
            if let deepLinkPath = self.deepLinkPath {
                self.navigateToDeepLink(deepLinkPath)
                self.deepLinkPath = .None
            }

            vc.activateTabBar()
            if let alert = PushNotificationController.sharedController.requestPushAccessIfNeeded() {
                vc.presentViewController(alert, animated: true, completion: .None)
            }
        }
    }
}

extension AppViewController {

    func showExternalWebView(url: String) {
        Tracker.sharedTracker.webViewAppeared(url)
        if let externalURL = NSURL(string: url) where ElloWebViewHelper.bypassInAppBrowser(externalURL) {
            UIApplication.sharedApplication().openURL(externalURL)
        }
        else {
            let externalWebController = ElloWebBrowserViewController.navigationControllerWithWebBrowser()
            presentViewController(externalWebController, animated: true, completion: nil)

            if let externalWebView = externalWebController.rootWebBrowser() {
                externalWebView.tintColor = UIColor.greyA()
                externalWebView.loadURLString(url)
            }
        }
    }

    public override func presentViewController(viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        // Unsure why WKWebView calls this controller - instead of it's own parent controller
        if let vc = presentedViewController {
            vc.presentViewController(viewControllerToPresent, animated: flag, completion: completion)
        } else {
            super.presentViewController(viewControllerToPresent, animated: flag, completion: completion)
        }
    }

}

// MARK: Screen transitions
extension AppViewController {

    public func swapViewController(newViewController: UIViewController, completion: ElloEmptyCompletion) {
        newViewController.view.alpha = 0

        visibleViewController?.willMoveToParentViewController(nil)
        newViewController.willMoveToParentViewController(self)

        prepareToShowViewController(newViewController)

        if let tabBarController = visibleViewController as? ElloTabBarController {
            tabBarController.deactivateTabBar()
        }

        UIView.animateWithDuration(0.2, animations: {
            self.visibleViewController?.view.alpha = 0
            newViewController.view.alpha = 1
            self.screen.hide()
        }, completion: { _ in
            self.visibleViewController?.view.removeFromSuperview()
            self.visibleViewController?.removeFromParentViewController()

            self.addChildViewController(newViewController)
            if let childController = newViewController as? HasAppController {
                childController.parentAppController = self
            }

            newViewController.didMoveToParentViewController(self)

            self.visibleViewController = newViewController
            completion()
        })
    }

    public func removeViewController(completion: ElloEmptyCompletion? = nil) {
        if presentingViewController != nil {
            dismissViewControllerAnimated(false, completion: .None)
        }
        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Slide)

        if let visibleViewController = visibleViewController {
            visibleViewController.willMoveToParentViewController(nil)

            if let tabBarController = visibleViewController as? ElloTabBarController {
                tabBarController.deactivateTabBar()
            }

            UIView.animateWithDuration(0.2, animations: {
                self.showStartupScreen()
                visibleViewController.view.alpha = 0
            }, completion: { _ in
                visibleViewController.view.removeFromSuperview()
                visibleViewController.removeFromParentViewController()
                self.visibleViewController = nil
                completion?()
            })
        }
        else {
            showStartupScreen()
            completion?()
        }
    }

    private func prepareToShowViewController(newViewController: UIViewController) {
        let controller = (newViewController as? UINavigationController)?.topViewController ?? newViewController
        Tracker.sharedTracker.screenAppeared(controller)

        view.addSubview(newViewController.view)
        newViewController.view.frame = self.view.bounds
        newViewController.view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
    }

}


// MARK: Logout events
public extension AppViewController {
    func userLoggedOut() {
        logOutCurrentUser()

        if isLoggedIn() {
            removeViewController()
        }
    }

    public func forceLogOut(shouldAlert: Bool) {
        logOutCurrentUser()

        if isLoggedIn() {
            removeViewController() {
                if shouldAlert {
                    let message = InterfaceString.App.LoggedOut
                    let alertController = AlertViewController(message: message)

                    let action = AlertAction(title: InterfaceString.OK, style: .Dark, handler: nil)
                    alertController.addAction(action)

                    self.presentViewController(alertController, animated: true, completion: nil)
                }
            }
        }
    }

    func isLoggedIn() -> Bool {
        if let visibleViewController = visibleViewController
        where visibleViewController is ElloTabBarController
        {
            return true
        }
        return false
    }

    private func logOutCurrentUser() {
        PushNotificationController.sharedController.deregisterStoredToken()
        ElloProvider.shared.logout()
        GroupDefaults[CurrentStreamKey] = nil
        UIApplication.sharedApplication().applicationIconBadgeNumber = 0
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        TemporaryCache.clear()
        InviteCache().clear()
        currentUser = nil
    }
}

// MARK: Push Notification Handling
extension AppViewController {
    func receivedPushNotification(payload: PushPayload) {
        if self.visibleViewController is ElloTabBarController {
            navigateToDeepLink(payload.applicationTarget)
        } else {
            self.pushPayload = payload
        }
    }
}

// MARK: URL Handling
extension AppViewController {
    func navigateToDeepLink(path: String) {
        Tracker.sharedTracker.deepLinkVisited(path)

        let (type, data) = ElloURI.match(path)

        guard type.shouldLoadInApp else {
            if let pathURL = NSURL(string: path) {
                UIApplication.sharedApplication().openURL(pathURL)
            }
            return
        }

        guard !stillLoggingIn() else {
            self.deepLinkPath = path
            return
        }

        guard isLoggedIn() else {
            switch type {
            case .Invite:
                showJoinScreen(animated: false, invitationCode: data)
            case .Join:
                showJoinScreen(animated: false)
            case .Login:
                showLoginScreen(animated: false)
            default:
                presentLoginOrSafariAlert(path)
            }
            return
        }

        guard let vc = self.visibleViewController as? ElloTabBarController else {
            return
        }

        switch type {
        case .Invite, .Join, .Login:
            break
        case .ExploreRecommended,
             .ExploreRecent,
             .ExploreTrending:
            showDiscoverScreen(vc)
        case .Discover:
            showDiscoverScreen(vc)
        case .DiscoverRandom,
             .DiscoverRecent,
             .DiscoverRelated,
             .DiscoverTrending,
             .Category:
            showCategoryScreen(vc, slug: data)
        case .Invitations:
            showInvitationScreen(vc)
        case .Enter, .Exit, .Root, .Explore:
            break
        case .Friends,
             .Following,
             .Noise,
             .Starred:
            showStreamContainerScreen(vc: vc, type: type)
        case .Notifications:
            showNotificationsScreen(vc, category: data)
        case .Onboarding:
            if let user = currentUser {
                showOnboardingScreen(user)
            }
        case .Post:
            showPostDetailScreen(data, path: path)
        case .PushNotificationComment,
             .PushNotificationPost:
            showPostDetailScreen(data, path: path, isSlug: false)
        case .Profile:
            showProfileScreen(data, path: path)
        case .PushNotificationUser:
            showProfileScreen(data, path: path, isSlug: false)
        case .ProfileFollowers:
            showProfileFollowersScreen(data)
        case .ProfileFollowing:
            showProfileFollowingScreen(data)
        case .ProfileLoves:
            showProfileLovesScreen(data)
        case .Search,
             .SearchPeople,
             .SearchPosts:
            showSearchScreen(data)
        case .Settings:
            showSettingsScreen()
        case .WTF:
            showExternalWebView(path)
        default:
            if let pathURL = NSURL(string: path) {
                UIApplication.sharedApplication().openURL(pathURL)
            }
        }
    }

    private func stillLoggingIn() -> Bool {
        let authToken = AuthToken()
        return !isLoggedIn() && authToken.isPasswordBased
    }

    private func presentLoginOrSafariAlert(path: String) {
        guard !isLoggedIn() else {
            return
        }

        let alertController = AlertViewController(message: path)

        let yes = AlertAction(title: InterfaceString.App.LoginAndView, style: .Dark) { _ in
            self.deepLinkPath = path
            self.showLoginScreen(animated: true)
        }
        alertController.addAction(yes)

        let viewBrowser = AlertAction(title: InterfaceString.App.OpenInSafari, style: .Light) { _ in
            if let pathURL = NSURL(string: path) {
                UIApplication.sharedApplication().openURL(pathURL)
            }
        }
        alertController.addAction(viewBrowser)

        self.presentViewController(alertController, animated: true, completion: nil)
    }

    private func showInvitationScreen(vc: ElloTabBarController) {
        vc.selectedTab = .Discover

        let responder = targetForAction(#selector(InviteResponder.onInviteFriends), withSender: self) as? InviteResponder
        responder?.onInviteFriends()
    }

    private func showDiscoverScreen(vc: ElloTabBarController) {
        guard let
            navVC = vc.selectedViewController as? ElloNavigationController
        where !(navVC.visibleViewController is DiscoverAllCategoriesViewController)
        else { return }

        let vc = DiscoverAllCategoriesViewController()
        vc.currentUser = currentUser
        pushDeepLinkViewController(vc)
    }

    private func showCategoryScreen(vc: ElloTabBarController, slug: String) {
        guard let
            navVC = vc.selectedViewController as? ElloNavigationController
        where !DeepLinking.alreadyOnCurrentCategory(navVC: navVC, slug: slug)
        else { return }

        Tracker.sharedTracker.categoryOpened(slug)
        let vc = CategoryViewController(slug: slug)
        vc.currentUser = currentUser
        pushDeepLinkViewController(vc)
    }


    private func showStreamContainerScreen(vc vc: ElloTabBarController, type: ElloURI) {
        vc.selectedTab = .Stream

        guard let
            navVC = vc.selectedViewController as? ElloNavigationController,
            streamVC = navVC.visibleViewController as? StreamContainerViewController
        else { return }

        streamVC.currentUser = currentUser

        switch type {
        case .Noise, .Starred: streamVC.showNoise()
        case .Friends, .Following: streamVC.showFriends()
        default: break
        }
    }

    private func showNotificationsScreen(vc: ElloTabBarController, category: String) {
        vc.selectedTab = .Notifications
        guard let
            navVC = vc.selectedViewController as? ElloNavigationController,
            notificationsVC = navVC.visibleViewController as? NotificationsViewController
        else { return }

        let notificationFilterType = NotificationFilterType.fromCategory(category)
        notificationsVC.categoryFilterType = notificationFilterType
        notificationsVC.activatedCategory(notificationFilterType)
        notificationsVC.currentUser = currentUser
    }

    private func showProfileScreen(userParam: String, path: String, isSlug: Bool = true) {
        let param = isSlug ? "~\(userParam)" : userParam
        let profileVC = ProfileViewController(userParam: param)
        profileVC.deeplinkPath = path
        profileVC.currentUser = currentUser
        pushDeepLinkViewController(profileVC)
    }

    private func showPostDetailScreen(postParam: String, path: String, isSlug: Bool = true) {
        let param = isSlug ? "~\(postParam)" : postParam
        let postDetailVC = PostDetailViewController(postParam: param)
        postDetailVC.deeplinkPath = path
        postDetailVC.currentUser = currentUser
        pushDeepLinkViewController(postDetailVC)
    }

    private func showProfileFollowersScreen(username: String) {
        let endpoint = ElloAPI.UserStreamFollowers(userId: "~\(username)")
        let noResultsTitle: String
        let noResultsBody: String
        if username == currentUser?.username {
            noResultsTitle = InterfaceString.Followers.CurrentUserNoResultsTitle
            noResultsBody = InterfaceString.Followers.CurrentUserNoResultsBody
        }
        else {
            noResultsTitle = InterfaceString.Followers.NoResultsTitle
            noResultsBody = InterfaceString.Followers.NoResultsBody
        }
        let followersVC = SimpleStreamViewController(endpoint: endpoint, title: "@" + username + "'s " + InterfaceString.Followers.Title)
        followersVC.streamViewController.noResultsMessages = (title: noResultsTitle, body: noResultsBody)
        followersVC.currentUser = currentUser
        pushDeepLinkViewController(followersVC)
    }

    private func showProfileFollowingScreen(username: String) {
        let endpoint = ElloAPI.UserStreamFollowing(userId: "~\(username)")
        let noResultsTitle: String
        let noResultsBody: String
        if username == currentUser?.username {
            noResultsTitle = InterfaceString.Following.CurrentUserNoResultsTitle
            noResultsBody = InterfaceString.Following.CurrentUserNoResultsBody
        }
        else {
            noResultsTitle = InterfaceString.Following.NoResultsTitle
            noResultsBody = InterfaceString.Following.NoResultsBody
        }
        let vc = SimpleStreamViewController(endpoint: endpoint, title: "@" + username + "'s " + InterfaceString.Following.Title)
        vc.streamViewController.noResultsMessages = (title: noResultsTitle, body: noResultsBody)
        vc.currentUser = currentUser
        pushDeepLinkViewController(vc)
    }

    private func showProfileLovesScreen(username: String) {
        let endpoint = ElloAPI.Loves(userId: "~\(username)")
        let noResultsTitle: String
        let noResultsBody: String
        if username == currentUser?.username {
            noResultsTitle = InterfaceString.Loves.CurrentUserNoResultsTitle
            noResultsBody = InterfaceString.Loves.CurrentUserNoResultsBody
        }
        else {
            noResultsTitle = InterfaceString.Loves.NoResultsTitle
            noResultsBody = InterfaceString.Loves.NoResultsBody
        }
        let vc = SimpleStreamViewController(endpoint: endpoint, title: "@" + username + "'s " + InterfaceString.Loves.Title)
        vc.streamViewController.noResultsMessages = (title: noResultsTitle, body: noResultsBody)
        vc.currentUser = currentUser
        pushDeepLinkViewController(vc)
    }

    private func showSearchScreen(terms: String) {
        let search = SearchViewController()
        search.currentUser = currentUser
        if !terms.isEmpty {
            search.searchForPosts(terms.urlDecoded().stringByReplacingOccurrencesOfString("+", withString: " ", options: NSStringCompareOptions.LiteralSearch, range: nil))
        }
        pushDeepLinkViewController(search)
    }

    private func showSettingsScreen() {
        if let settings = UIStoryboard(name: "Settings", bundle: .None).instantiateInitialViewController() as? SettingsContainerViewController {
            settings.currentUser = currentUser
            pushDeepLinkViewController(settings)
        }
    }

    private func pushDeepLinkViewController(vc: UIViewController) {
        guard let
            tabController = self.visibleViewController as? ElloTabBarController,
            navController = tabController.selectedViewController as? UINavigationController
        else { return }

        if let topNavVC = topViewController(self)?.navigationController {
            topNavVC.pushViewController(vc, animated: true)
        }
        else {
            navController.pushViewController(vc, animated: true)
        }
    }

    private func selectTab(tab: ElloTab) {
        ElloWebBrowserViewController.elloTabBarController?.selectedTab = tab
    }


}

extension AppViewController {

    func topViewController(base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            if let selected = tab.selectedViewController {
                return topViewController(selected)
            }
        }
        if let presented = base?.presentedViewController {
            return topViewController(presented)
        }
        return base
    }
}

#if DEBUG

var isShowingDebug = false
var debugTodoController = DebugTodoController()

public extension AppViewController {

    public override func canBecomeFirstResponder() -> Bool {
        return true
    }

    public override func motionEnded(motion: UIEventSubtype, withEvent event: UIEvent?) {
        if motion == .MotionShake {
            if isShowingDebug {
                closeTodoController()
            }
            else {
                isShowingDebug = true
                let ctlr = debugTodoController
                ctlr.title = "Test Me Test Me"

                let nav = UINavigationController(rootViewController: ctlr)
                let bar = UIView(frame: CGRect(x: 0, y: -20, width: view.frame.width, height: 20))
                bar.autoresizingMask = [.FlexibleWidth, .FlexibleBottomMargin]
                bar.backgroundColor = .blackColor()
                nav.navigationBar.addSubview(bar)

                let closeItem = UIBarButtonItem.closeButton(target: self, action: #selector(AppViewController.closeTodoControllerTapped))
                ctlr.navigationItem.leftBarButtonItem = closeItem

                presentViewController(nav, animated: true, completion: nil)
            }
        }
    }

    func closeTodoControllerTapped() {
        closeTodoController()
    }

    func closeTodoController(completion: (() -> Void)? = nil) {
        isShowingDebug = false
        dismissViewControllerAnimated(true, completion: completion)
    }

}

#endif

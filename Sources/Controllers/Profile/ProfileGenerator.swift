////
///  ProfileGenerator.swift
//

public final class ProfileGenerator: StreamGenerator {

    public var currentUser: User?
    public var streamKind: StreamKind
    weak public var destination: StreamDestination?

    private var user: User?
    private let userParam: String
    private var posts: [Post]?
    private var hasPosts: Bool?
    private var localToken: String!
    private var loadingToken = LoadingToken()

    private let queue = NSOperationQueue()

    func headerItems() -> [StreamCellItem] {
        guard let user = user else { return [] }

        var items = [
            StreamCellItem(jsonable: user, type: .ProfileHeader),
        ]
        if hasPosts != false {
            items += [
                StreamCellItem(jsonable: user, type: .FullWidthSpacer(height: 5))
            ]
        }
        return items
    }

    public init(currentUser: User?,
         userParam: String,
         user: User?,
         streamKind: StreamKind,
         destination: StreamDestination?
        ) {
        self.currentUser = currentUser
        self.user = user
        self.userParam = userParam
        self.streamKind = streamKind
        self.localToken = loadingToken.resetInitialPageLoadingToken()
        self.destination = destination
    }

    public func load(reload reload: Bool = false) {
        let doneOperation = AsyncOperation()
        queue.addOperation(doneOperation)

        localToken = loadingToken.resetInitialPageLoadingToken()
        setPlaceHolders()
        setInitialUser(doneOperation)
        loadUser(doneOperation, reload: reload)
        loadUserPosts(doneOperation)
    }

    public func toggleGrid() {
        if let posts = posts where hasPosts == true {
            destination?.replacePlaceholder(.ProfilePosts, items: parse(posts)) {}
        }
        else if let user = user where hasPosts == false {
            let noItems = [StreamCellItem(jsonable: user, type: .NoPosts)]
            destination?.replacePlaceholder(.ProfilePosts, items: noItems) {}
        }
    }

}

private extension ProfileGenerator {

    func setPlaceHolders() {
        let header = StreamCellItem(type: .ProfileHeaderGhost, placeholderType: .ProfileHeader)
        header.calculatedCellHeights.oneColumn = ProfileHeaderGhostCell.Size.height
        header.calculatedCellHeights.multiColumn = ProfileHeaderGhostCell.Size.height
        destination?.setPlaceholders([
            header,
            StreamCellItem(type: .Placeholder, placeholderType: .ProfilePosts)
        ])
    }

    func setInitialUser(doneOperation: AsyncOperation) {
        guard let user = user else { return }

        destination?.setPrimaryJSONAble(user)
        destination?.replacePlaceholder(.ProfileHeader, items: headerItems()) {}
        doneOperation.run()
    }

    func loadUser(doneOperation: AsyncOperation, reload: Bool = false) {
        guard !doneOperation.finished || reload else { return }

        // load the user with no posts
        StreamService().loadUser(
            streamKind.endpoint,
            streamKind: streamKind,
            success: { [weak self] (user, _) in
                guard let sself = self else { return }
                guard sself.loadingToken.isValidInitialPageLoadingToken(sself.localToken) else { return }

                sself.user = user
                sself.destination?.setPrimaryJSONAble(user)
                sself.destination?.replacePlaceholder(.ProfileHeader, items: sself.headerItems()) {}
                doneOperation.run()
            },
            failure: { [weak self] _ in
                guard let sself = self else { return }
                sself.destination?.primaryJSONAbleNotFound()
                sself.queue.cancelAllOperations()
        })
    }

    func loadUserPosts(doneOperation: AsyncOperation) {
        let displayPostsOperation = AsyncOperation()
        displayPostsOperation.addDependency(doneOperation)
        queue.addOperation(displayPostsOperation)

        self.destination?.replacePlaceholder(.ProfilePosts, items: [StreamCellItem(type: .StreamLoading)]) {}

        StreamService().loadUserPosts(
            userParam,
            success: { [weak self] (posts, responseConfig) in
                guard let sself = self else { return }

                guard sself.loadingToken.isValidInitialPageLoadingToken(sself.localToken) else { return }
                sself.destination?.setPagingConfig(responseConfig)
                sself.posts = posts
                let userPostItems = sself.parse(posts)
                displayPostsOperation.run {
                    inForeground {
                        if userPostItems.count == 0 {
                            sself.hasPosts = false
                            let user: User = sself.user ?? User.empty(id: sself.userParam)
                            let noItems = [StreamCellItem(jsonable: user, type: .NoPosts)]
                            sself.destination?.replacePlaceholder(.ProfilePosts, items: noItems) {
                                sself.destination?.pagingEnabled = false
                            }
                            sself.destination?.replacePlaceholder(.ProfileHeader, items: sself.headerItems()) {}
                        }
                        else {
                            let updateHeaderItems = sself.hasPosts == false
                            sself.hasPosts = true
                            if updateHeaderItems {
                                sself.destination?.replacePlaceholder(.ProfileHeader, items: sself.headerItems()) {}
                            }
                            sself.destination?.replacePlaceholder(.ProfilePosts, items: userPostItems) {
                                sself.destination?.pagingEnabled = true
                            }
                        }
                    }
                }
            },
            failure: { [weak self] _ in
                guard let sself = self else { return }
                sself.destination?.primaryJSONAbleNotFound()
                sself.queue.cancelAllOperations()
        })
    }
}

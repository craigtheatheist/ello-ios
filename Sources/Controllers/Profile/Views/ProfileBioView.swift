////
///  ProfileBioView.swift
//

import WebKit


public class ProfileBioView: ProfileBaseView {
    public struct Size {
        static let margins = UIEdgeInsets(top: 15, left: 15, bottom: 10, right: 15)
    }

    public var bio: String = "" {
        didSet {
            bioView.loadHTMLString(StreamTextCellHTML.postHTML(bio), baseURL: NSURL(string: "/"))
        }
    }
    private let bioView = UIWebView()
    private let grayLine = UIView()
    var grayLineVisible: Bool {
        get { return !grayLine.hidden }
        set { grayLine.hidden = !newValue }
    }

    weak var webLinkDelegate: WebLinkDelegate?

    var onHeightMismatch: OnHeightMismatch?
}

extension ProfileBioView {

    override func style() {
        backgroundColor = .whiteColor()
        bioView.scrollView.scrollEnabled = false
        bioView.scrollView.scrollsToTop = false
        bioView.delegate = self
        grayLine.backgroundColor = .greyE5()
    }

    override func bindActions() {
    }

    override func setText() {
    }

    override func arrange() {
        addSubview(bioView)
        addSubview(grayLine)

        bioView.snp_makeConstraints { make in
            make.top.leading.trailing.equalTo(self).inset(Size.margins)
            make.bottom.equalTo(self)
        }

        grayLine.snp_makeConstraints { make in
            make.height.equalTo(1)
            make.bottom.equalTo(self)
            make.leading.trailing.equalTo(self).inset(ProfileBaseView.Size.grayInset)
        }
    }

    func prepareForReuse() {
        self.bio = ""
        grayLine.hidden = false
        webLinkDelegate = nil
    }
}

extension ProfileBioView: UIWebViewDelegate {

    public func webViewDidFinishLoad(webView: UIWebView) {
        let webViewHeight = webView.windowContentSize()?.height ?? 0
        let totalHeight: CGFloat
        if bio == "" {
            totalHeight = 0
        }
        else {
            totalHeight = ProfileBioSizeCalculator.calculateHeight(webViewHeight: webViewHeight)
        }
        if totalHeight != frame.size.height {
            onHeightMismatch?(totalHeight)
        }
    }

    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
         return ElloWebViewHelper.handleRequest(request, webLinkDelegate: webLinkDelegate)
    }
}

extension ProfileBioView: ProfileViewProtocol {}

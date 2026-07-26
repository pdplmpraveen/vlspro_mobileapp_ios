import Foundation
import WebKit
import Network
import Combine

class WebViewManager: NSObject, ObservableObject {

    static let baseURL = URL(string: "https://vlspro.co.in/vlspro-rental/login.php")!

    @Published var isLoading: Bool = false
    @Published var isOffline: Bool = false

    let webView: WKWebView

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private var hasLoaded = false

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic

        self.webView = webView
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Add custom user agent to help with compatibility
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        startNetworkMonitoring()
    }

    // Called from WebViewContainer once the view is on screen
    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        print("[VLSPro] Starting to load base URL: \(Self.baseURL)")
        loadBaseURL()
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
    }

    func reload() {
        if webView.url == nil {
            loadBaseURL()
        } else {
            webView.reload()
        }
    }

    private func loadBaseURL() {
        let request = URLRequest(
            url: Self.baseURL,
            cachePolicy: isOffline ? .returnCacheDataElseLoad : .useProtocolCachePolicy,
            timeoutInterval: 30
        )
        webView.load(request)
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = self?.isOffline ?? false
                self?.isOffline = path.status != .satisfied
                print("[VLSPro] Network status: \(path.status == .satisfied ? "Online" : "Offline")")
                if wasOffline && path.status == .satisfied {
                    print("[VLSPro] Reconnected - reloading")
                    self?.reload()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewManager: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        isLoading = true
        print("[VLSPro] Started loading: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
        print("[VLSPro] Finished loading: \(webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        print("[VLSPro] Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        isLoading = false
        print("[VLSPro] Load failed: \(error.localizedDescription)")
        if isOffline {
            var req = URLRequest(url: Self.baseURL)
            req.cachePolicy = .returnCacheDataElseLoad
            webView.load(req)
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        if url.host?.contains("vlspro.co.in") == true || url.scheme == "about" {
            decisionHandler(.allow)
        } else if ["http", "https"].contains(url.scheme ?? "") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewManager: WKUIDelegate {

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        topViewController()?.present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        topViewController()?.present(alert, animated: true)
    }

    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

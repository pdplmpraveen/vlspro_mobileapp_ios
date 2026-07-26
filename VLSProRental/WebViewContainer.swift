import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let manager: WebViewManager

    func makeUIView(context: Context) -> WKWebView {
        // Trigger the first load now that the view has a real frame
        DispatchQueue.main.async {
            manager.loadIfNeeded()
        }
        return manager.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

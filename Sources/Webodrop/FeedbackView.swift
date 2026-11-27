import SwiftUI
import WebKit

/// Fenêtre native hébergeant le formulaire officiel Shake'n'Drop (GitHub Pages + Web3Forms client-side)
/// directement dans l'app, sans jamais ouvrir le client Mail.
struct FeedbackView: View {
    @Environment(WebodropEngine.self) private var engine
    let kind: FeedbackHelper.Kind
    let onClose: () -> Void

    @State private var isLoading: Bool = true
    @State private var loadFailed: Bool = false

    private var formURL: URL {
        var components = URLComponents(string: "https://djapssparrow.github.io/shake-n-drop/feedback.html")!
        components.queryItems = [
            URLQueryItem(name: "v", value: engine.updater.currentVersion),
            URLQueryItem(name: "os", value: ProcessInfo.processInfo.operatingSystemVersionString),
            URLQueryItem(name: "type", value: kind == .bug ? "bug" : "idea"),
        ]
        return components.url!
    }

    var body: some View {
        ZStack {
            if loadFailed {
                offlineFallback
            } else {
                FeedbackWebView(url: formURL, isLoading: $isLoading, loadFailed: $loadFailed)
                if isLoading {
                    ProgressView("Chargement du formulaire…")
                        .padding(Space.lg)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .frame(width: 440, height: 420)
    }

    private var offlineFallback: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Connexion requise")
                .font(.headline)
            Text("Le formulaire intégré nécessite une connexion internet. Vous pouvez aussi écrire par Mail.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack {
                Button("Fermer") { onClose() }
                Button("Ouvrir Mail") {
                    FeedbackHelper.openEmailFallback(
                        kind: kind,
                        message: "",
                        appVersion: engine.updater.currentVersion
                    )
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(Space.xl)
    }
}

private struct FeedbackWebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadFailed: $loadFailed)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var loadFailed: Bool

        init(isLoading: Binding<Bool>, loadFailed: Binding<Bool>) {
            _isLoading = isLoading
            _loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            isLoading = false
            loadFailed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            isLoading = false
            loadFailed = true
        }
    }
}

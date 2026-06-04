import SwiftUI
import WebKit

/// Renders dynamic page content fetched from /api/pages/{slug}.
/// HTML wrapped in a brand-styled CSS so it looks native, not webby.
struct PageView: View {
    let slug: String
    let fallbackTitle: String

    @State private var title: String = ""
    @State private var html: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView().tint(.revOrange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.revRed)
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                StyledHtmlView(htmlBody: html)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Color.revBackground.ignoresSafeArea())
        .navigationTitle(title.isEmpty ? fallbackTitle : title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: APIConfig.baseURL.absoluteString + "/pages/\(slug)") else {
            errorMessage = "URL invalide"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                errorMessage = "Page introuvable"
                return
            }

            struct PageResp: Decodable {
                let title: String
                let content_html: String
            }
            let page = try JSONDecoder().decode(PageResp.self, from: data)
            self.title = page.title
            self.html = page.content_html
        } catch {
            errorMessage = "Impossible de charger la page : \(error.localizedDescription)"
        }
    }
}

/// WKWebView wrapper rendering HTML with the brand stylesheet baked in.
struct StyledHtmlView: UIViewRepresentable {
    let htmlBody: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.alwaysBounceVertical = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(wrappedHtml(htmlBody), baseURL: URL(string: "https://www.reveetvoyage.be"))
    }

    private func wrappedHtml(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="fr">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
          :root {
            --rev-brown: #1F1008;
            --rev-orange: #F09D6B;
            --rev-yellow: #F2C61D;
            --rev-red: #E45F60;
            --rev-text-secondary: #7d7d7d;
          }
          @media (prefers-color-scheme: dark) {
            :root { --rev-brown: #f5e6d9; --rev-text-secondary: #b0b0b0; }
            body { background: #000; color: #e8e8e8; }
            h1 {
              background: linear-gradient(90deg, #ffd9b8, #e45f60);
              -webkit-background-clip: text;
              -webkit-text-fill-color: transparent;
            }
            h2, h3 { color: #ffd9b8; }
            a { color: #ffb89e; }
            strong { color: #f5f5f5; }
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            padding: 18px;
            font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Rounded', sans-serif;
            font-size: 15px;
            line-height: 1.55;
            color: var(--rev-brown);
            background: transparent;
          }
          h1 {
            font-size: 22px;
            font-weight: 700;
            color: var(--rev-brown);
            margin: 0 0 12px;
            background: linear-gradient(90deg, var(--rev-brown), var(--rev-red));
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
          }
          h2 {
            font-size: 17px;
            font-weight: 600;
            color: var(--rev-brown);
            margin: 24px 0 8px;
            border-bottom: 2px solid var(--rev-yellow);
            padding-bottom: 4px;
            display: inline-block;
          }
          h3 { font-size: 15px; font-weight: 600; margin: 18px 0 6px; }
          p { margin: 8px 0 12px; }
          a { color: var(--rev-orange); text-decoration: none; font-weight: 500; }
          ul, ol { margin: 8px 0 14px 18px; }
          li { margin: 4px 0; }
          strong { color: var(--rev-brown); }
          em { color: var(--rev-orange); }
          code {
            background: rgba(240, 157, 107, 0.12);
            padding: 2px 5px;
            border-radius: 4px;
            font-size: 13px;
          }
        </style>
        </head>
        <body>\(body)</body>
        </html>
        """
    }
}

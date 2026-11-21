import UIKit
import WebKit

final class AdminViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let spinner = UIActivityIndicatorView(style: .large)
    private let errorPanel = UIStackView()
    private let errorLabel = UILabel()
    private var startURL: URL?
    private let wine = UIColor(red: 122 / 255, green: 24 / 255, blue: 50 / 255, alpha: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "HOANAdmin/iOS"
        config.userContentController.addUserScript(WKUserScript(
            source: "window.__hoanNativeApp = 'ios';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        setupStatusViews()
        let rawURL = Bundle.main.object(forInfoDictionaryKey: "HOANAdminURL") as? String ?? ""
        if let url = URL(string: rawURL), url.scheme == "https", url.host != nil,
           url.user == nil, url.password == nil, url.fragment == "/admin" {
            startURL = url
        }
        retry()
    }

    private func setupStatusViews() {
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = wine
        spinner.hidesWhenStopped = true
        view.addSubview(spinner)
        errorPanel.axis = .vertical
        errorPanel.alignment = .center
        errorPanel.spacing = 18
        errorPanel.translatesAutoresizingMaskIntoConstraints = false
        errorPanel.backgroundColor = .systemBackground
        let image = UIImageView(image: UIImage(systemName: "wifi.exclamationmark"))
        image.tintColor = wine
        image.contentMode = .scaleAspectFit
        image.heightAnchor.constraint(equalToConstant: 48).isActive = true
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.font = .preferredFont(forTextStyle: .body)
        let retryButton = UIButton(type: .system)
        retryButton.setTitle("Thử lại", for: .normal)
        retryButton.tintColor = wine
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
        [image, errorLabel, retryButton].forEach { errorPanel.addArrangedSubview($0) }
        view.addSubview(errorPanel)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorPanel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            errorPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
        errorPanel.isHidden = true
    }

    @objc private func retry() {
        guard let url = startURL else {
            showError("Chưa có địa chỉ quản trị hợp lệ cho ứng dụng này.")
            return
        }
        errorPanel.isHidden = true
        webView.isHidden = false
        spinner.startAnimating()
        webView.load(URLRequest(url: url))
    }

    private func showError(_ message: String = "Không kết nối được HOÀN Admin. Kiểm tra mạng rồi thử lại.") {
        spinner.stopAnimating()
        errorLabel.text = message
        webView.isHidden = true
        errorPanel.isHidden = false
    }

    private func trusted(_ url: URL?) -> Bool {
        guard let url = url, let start = startURL else { return false }
        return url.scheme == "https" && url.host?.lowercased() == start.host?.lowercased()
            && (url.port ?? 443) == (start.port ?? 443) && url.user == nil && url.password == nil
    }

    private func openExternal(_ url: URL, userInitiated: Bool) {
        guard userInitiated, let scheme = url.scheme?.lowercased(),
              ["https", "mailto", "tel"].contains(scheme) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
        } else if trusted(url) {
            decisionHandler(.allow)
        } else {
            openExternal(url, userInitiated: navigationAction.navigationType == .linkActivated)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame,
           let response = navigationResponse.response as? HTTPURLResponse, response.statusCode >= 400 {
            showError("Dịch vụ quản trị chưa sẵn sàng. Vui lòng thử lại sau.")
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showError() }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { showError() }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showError("Màn hình quản lý cần được tải lại. Chạm Thử lại để tiếp tục.")
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, trusted(url) {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard trusted(frame.request.url), presentedViewController == nil else { completionHandler(); return }
        let alert = UIAlertController(title: "HOÀN Admin", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Đóng", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard trusted(frame.request.url), presentedViewController == nil else { completionHandler(false); return }
        let alert = UIAlertController(title: "HOÀN Admin", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Xác nhận", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard trusted(frame.request.url), presentedViewController == nil else { completionHandler(nil); return }
        let alert = UIAlertController(title: "HOÀN Admin", message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { _ in completionHandler(alert.textFields?.first?.text) })
        present(alert, animated: true)
    }
}

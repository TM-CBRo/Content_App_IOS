import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!
    private var bottomToolbar: UIToolbar!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black // Fundal negru ca sa nu se vada margini albe

        // 1. AUDIO SESSION
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio error: \(error)") }

        // 2. WEBVIEW CONFIG
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        // SCRIPT 1: BACKGROUND PLAY
        let backgroundScript = """
            Object.defineProperty(document, 'hidden', { get: () => false });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible' });
            window.addEventListener('visibilitychange', e => e.stopImmediatePropagation(), true);
        """
        #imageLiteral(resourceName: "Screenshot 2026-01-29 at 14.49.56.png")
        contentController.addUserScript(WKUserScript(source: backgroundScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        // SCRIPT 2: AD BLOCKER (CSS CORECTAT)
        // Am scos regula care ascundea Header-ul YouTube, ca sa arate mai natural
        let adBlockScript = """
            const css = `
                .ytp-ad-module, .ad-container,
                ytm-promoted-video-renderer,
                ytm-item-section-renderer[data-is-ad="true"],
                .open-app-banner-container,
                ytd-promoted-sparkles-web-renderer
                { display: none !important; }
            `;
            const style = document.createElement('style');
            style.appendChild(document.createTextNode(css));
            document.head.appendChild(style);

            let video = null;
            setInterval(() => {
                // Skip Ads Logic
                const skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern');
                if(skipBtn) skipBtn.click();
                
                // Overlay Close
                const overlay = document.querySelector('.ytp-ad-overlay-close-button');
                if(overlay) overlay.click();

                // Video Fast Forward
                if (!video) video = document.querySelector('video');
                const player = document.querySelector('#movie_player');
                if (video && player && player.classList.contains('ad-showing')) {
                    video.muted = true;
                    video.playbackRate = 16;
                } else if (video) {
                    if(video.playbackRate > 1) video.playbackRate = 1;
                    if(video.muted && !player.classList.contains('ad-showing')) video.muted = false;
                }
            }, 300);
            
            // Feed Cleaner
             new MutationObserver(() => {
                document.querySelectorAll('ytm-promoted-video-renderer, ytm-item-section-renderer[data-is-ad="true"]').forEach(el => el.remove());
            }).observe(document.body, { childList: true, subtree: true });
        """
        contentController.addUserScript(WKUserScript(source: adBlockScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false))

        config.userContentController = contentController

        // 3. UI SETUP (WEBVIEW + TOOLBAR)
        setupUI(config: config)
        
        // Incarca URL
        webView.load(URLRequest(url: URL(string: "https://m.youtube.com")!))
    }

    private func setupUI(config: WKWebViewConfiguration) {
        // A. Creare WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // B. Creare Toolbar (Bara de jos)
        bottomToolbar = UIToolbar()
        bottomToolbar.barStyle = .black // Stil Negru
        bottomToolbar.isTranslucent = false // Negru solid
        bottomToolbar.tintColor = .white // Icoane albe
        bottomToolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomToolbar)

        // C. Butoanele din Toolbar
        let homeIcon = UIImage(systemName: "house.fill")
        let searchIcon = UIImage(systemName: "magnifyingglass")
        let backIcon = UIImage(systemName: "chevron.backward")
        
        let homeBtn = UIBarButtonItem(image: homeIcon, style: .plain, target: self, action: #selector(goHome))
        let searchBtn = UIBarButtonItem(image: searchIcon, style: .plain, target: self, action: #selector(openSearch))
        let backBtn = UIBarButtonItem(image: backIcon, style: .plain, target: self, action: #selector(goBack))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // Ordinea butoanelor: Back --- Spatiu --- Home --- Spatiu --- Search
        bottomToolbar.items = [backBtn, spacer, homeBtn, spacer, searchBtn]

        // D. Constraints (Asezarea in pagina)
        NSLayoutConstraint.activate([
            // WebView ocupa de sus pana la Toolbar
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor), // Se opreste la toolbar

            // Toolbar ocupa partea de jos
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 44) // Inaltime standard
        ])
    }

    // --- ACTIUNI BUTOANE ---

    @objc private func goHome() {
        let url = URL(string: "https://m.youtube.com")!
        webView.load(URLRequest(url: url))
    }

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            // Daca nu mai ai unde sa dai back, te duce Home
            goHome()
        }
    }

    @objc private func openSearch() {
        let alert = UIAlertController(title: "Search YouTube", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Search..." }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Go", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty,
                  let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
            let url = URL(string: "https://m.youtube.com/results?search_query=\(encoded)")!
            self.webView.load(URLRequest(url: url))
        })
        present(alert, animated: true)
    }
    
    // Status Bar Alb
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

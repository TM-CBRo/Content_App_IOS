import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black // Fundal negru

        // ----------------------------------------------------------------
        // 1. ACTIVARE AUDIO (EXTRAS DIN CODUL VECHI - FIX PENTRU BACKGROUND)
        // ----------------------------------------------------------------
        do {
            // Folosim exact setarile din codul vechi care mergeau
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Eroare audio: \(error)")
        }

        // 2. CONFIGURARE BROWSER
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        // ----------------------------------------------------------------
        // SCRIPT 1: BACKGROUND PLAY (EXTRAS DIN CODUL VECHI - EXACT ACELASI TEXT)
        // ----------------------------------------------------------------
        // Acesta este scriptul "verbos" care pacaleste YouTube sa creada ca e vizibil
        let backgroundScript = """
            // Spunem browserului ca suntem mereu vizibili, chiar si cand ecranul e stins
            Object.defineProperty(document, 'hidden', { get: function() { return false; } });
            Object.defineProperty(document, 'visibilityState', { get: function() { return 'visible'; } });
            Object.defineProperty(document, 'webkitVisibilityState', { get: function() { return 'visible'; } });
            
            // Oprim evenimentul care anunta ca ai iesit din aplicatie
            window.addEventListener('visibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
            window.addEventListener('webkitvisibilitychange', function(e) { e.stopImmediatePropagation(); }, true);
        """
        
        // Injectam LA INCEPUT (.atDocumentStart) - CRITIC
        contentController.addUserScript(WKUserScript(source: backgroundScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        // ----------------------------------------------------------------
        // SCRIPT 2: AD BLOCKER (DIN CODUL NOU - CEL MAI BUN)
        // ----------------------------------------------------------------
        let adBlockScript = """
            const css = `
                /* Ascunde reclamele si bannerele, dar lasa Header-ul (Lupa/Search) */
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

        // 3. UI SETUP (FULL SCREEN - DIN CODUL NOU)
        setupFullScreenUI(config: config)
        
        // Incarca URL
        webView.load(URLRequest(url: URL(string: "https://m.youtube.com")!))
    }

    private func setupFullScreenUI(config: WKWebViewConfiguration) {
        // A. Creare WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        
        // Gesturi Swipe Back/Forward
        webView.allowsBackForwardNavigationGestures = true
        
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)

        // B. Constraints (FULL SCREEN - Pana jos de tot)
        NSLayoutConstraint.activate([
            // Se lipeste de sus (Safe Area)
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            
            // Se lipeste de laterale
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Se lipeste de JOS DE TOT (view.bottomAnchor), acoperind spatiul negru
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // Status Bar Alb
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

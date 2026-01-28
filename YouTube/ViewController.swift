import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController, WKNavigationDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. AUDIO SESSION (UNCHANGED – WORKING CONFIG)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .defaultToSpeaker]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }

        // 2. WEB VIEW CONFIGURATION
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.allowsPictureInPictureMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        // ---------------------------------------------------------------------
        // SCRIPT 1: BACKGROUND PLAY (VISIBILITY HIJACK – SAFE VERSION)
        // ---------------------------------------------------------------------
        let backgroundScript = """
            Object.defineProperty(document, 'hidden', {
                get: function() { return false; },
                configurable: true
            });
            Object.defineProperty(document, 'visibilityState', {
                get: function() { return 'visible'; },
                configurable: true
            });
            Object.defineProperty(document, 'webkitVisibilityState', {
                get: function() { return 'visible'; },
                configurable: true
            });

            window.addEventListener('visibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);

            window.addEventListener('webkitvisibilitychange', function(e) {
                e.stopImmediatePropagation();
            }, true);
        """

        let bgUserScript = WKUserScript(
            source: backgroundScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bgUserScript)

        // ---------------------------------------------------------------------
        // SCRIPT 2: AD BLOCKER (ROBUST + SAFE)
        // ---------------------------------------------------------------------
        let adBlockScript = """
            // ---------------- CSS HIDING ----------------
            var css = `
                /* Video Ads & Overlays */
                .ytp-ad-module, .ad-container, .ytp-ad-image-overlay,
                .ytp-ad-overlay-image, .ytp-ad-text-overlay,
                .ytp-ad-player-overlay, .ytp-paid-content-overlay,

                /* Feed Ads */
                ytd-promoted-sparkles-web-renderer,
                ytd-display-ad-renderer,
                ytd-compact-promoted-video-renderer,
                ytd-promoted-video-renderer,
                ytm-promoted-video-renderer,
                ytm-item-section-renderer[data-is-ad="true"],

                /* App Banners */
                .mobile-topbar-header-content.non-search-mode,
                .open-app-banner-container,
                .ad-interrupting
                { display: none !important; }
            `;

            var style = document.createElement('style');
            style.type = 'text/css';
            style.appendChild(document.createTextNode(css));
            (document.head || document.documentElement).appendChild(style);

            // ---------------- ACTIVE LOGIC ----------------
            var cachedVideo = null;
            var NORMAL_RATE = 1.0;

            setInterval(function() {

                // Skip buttons
                var skipSelectors = [
                    '.ytp-ad-skip-button',
                    '.ytp-ad-skip-button-modern',
                    '.ad-skip-button'
                ];

                skipSelectors.forEach(function(selector) {
                    var btn = document.querySelector(selector);
                    if (btn) btn.click();
                });

                // Close overlay ads
                var overlayClose = document.querySelector('.ytp-ad-overlay-close-button');
                if (overlayClose) overlayClose.click();

                // Cache video element
                if (!cachedVideo || cachedVideo.readyState === 0) {
                    cachedVideo = document.querySelector('video');
                }

                if (!cachedVideo) return;

                var player = document.querySelector('#movie_player');

                if (player && (player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting'))) {
                    cachedVideo.muted = true;
                    cachedVideo.playbackRate = 16.0;
                } else {
                    if (cachedVideo.playbackRate !== NORMAL_RATE) {
                        cachedVideo.playbackRate = NORMAL_RATE;
                        cachedVideo.muted = false;
                    }
                }

                // Feed cleanup (remove empty gaps)
                document.querySelectorAll(
                    'ytm-promoted-video-renderer, ytm-item-section-renderer[data-is-ad="true"]'
                ).forEach(function(el) {
                    el.remove();
                });

                // Remove "Open App" banner if it reappears
                var banner = document.querySelector('.open-app-banner-container');
                if (banner) banner.remove();

            }, 300);

            // ---------------- MUTATION OBSERVER (FEED ONLY) ----------------
            var observer = new MutationObserver(function() {
                document.querySelectorAll(
                    'ytm-promoted-video-renderer, ytm-item-section-renderer[data-is-ad="true"]'
                ).forEach(function(el) {
                    el.remove();
                });
            });

            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
        """

        let adUserScript = WKUserScript(
            source: adBlockScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(adUserScript)

        webConfiguration.userContentController = contentController

        // ---------------------------------------------------------------------
        // WEB VIEW SETUP
        // ---------------------------------------------------------------------
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.isOpaque = false

        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        if let url = URL(string: "https://m.youtube.com") {
            webView.load(URLRequest(url: url))
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

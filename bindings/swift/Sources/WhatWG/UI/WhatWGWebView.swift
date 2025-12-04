#if os(iOS) || os(macOS)
import SwiftUI
import Combine

#if os(iOS)
import UIKit
public typealias PlatformView = UIView
public typealias PlatformViewRepresentable = UIViewRepresentable
public typealias PlatformColor = UIColor
#else
import AppKit
public typealias PlatformView = NSView
public typealias PlatformViewRepresentable = NSViewRepresentable
public typealias PlatformColor = NSColor
#endif

/// A SwiftUI view that displays web content using the WHATWG browser engine.
///
/// `WhatWGWebView` wraps the underlying platform-specific web view and integrates
/// with `WhatWGBrowser` for navigation and JavaScript execution.
///
/// ## Example Usage
///
/// ```swift
/// struct BrowserView: View {
///     @StateObject var browser = WhatWGBrowser()
///
///     var body: some View {
///         VStack {
///             WhatWGWebView(browser: browser)
///                 .background(Color.white)
///
///             ToolbarView(browser: browser)
///         }
///     }
/// }
/// ```
///
@available(iOS 14.0, macOS 11.0, *)
public struct WhatWGWebView: PlatformViewRepresentable {
    
    /// The browser instance controlling this view.
    @ObservedObject var browser: WhatWGBrowser
    
    /// Configuration options for the web view.
    public var configuration: Configuration
    
    /// Creates a new web view with the specified browser.
    ///
    /// - Parameters:
    ///   - browser: The browser instance to use.
    ///   - configuration: Optional configuration. Defaults to standard configuration.
    public init(browser: WhatWGBrowser, configuration: Configuration = .standard) {
        self.browser = browser
        self.configuration = configuration
    }
    
    #if os(iOS)
    public func makeUIView(context: Context) -> WhatWGWebViewContainer {
        let container = WhatWGWebViewContainer(frame: .zero, configuration: configuration)
        container.delegate = context.coordinator
        return container
    }
    
    public func updateUIView(_ container: WhatWGWebViewContainer, context: Context) {
        context.coordinator.updateBrowser(browser)
        container.update(with: browser)
    }
    #else
    public func makeNSView(context: Context) -> WhatWGWebViewContainer {
        let container = WhatWGWebViewContainer(frame: .zero, configuration: configuration)
        container.delegate = context.coordinator
        return container
    }
    
    public func updateNSView(_ container: WhatWGWebViewContainer, context: Context) {
        context.coordinator.updateBrowser(browser)
        container.update(with: browser)
    }
    #endif
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(browser: browser)
    }
}

// MARK: - Configuration

@available(iOS 14.0, macOS 11.0, *)
extension WhatWGWebView {
    
    /// Configuration options for the web view.
    public struct Configuration {
        
        /// Whether JavaScript is enabled.
        public var javaScriptEnabled: Bool
        
        /// Whether to allow inline media playback (iOS).
        public var allowsInlineMediaPlayback: Bool
        
        /// Whether media can play automatically.
        public var mediaAutoplayPolicy: MediaAutoplayPolicy
        
        /// The default background color.
        public var backgroundColor: PlatformColor
        
        /// Whether to show the scroll indicator.
        public var showsScrollIndicator: Bool
        
        /// Whether to allow zooming.
        public var allowsZooming: Bool
        
        /// The minimum zoom scale.
        public var minimumZoomScale: CGFloat
        
        /// The maximum zoom scale.
        public var maximumZoomScale: CGFloat
        
        /// Whether to allow backward/forward navigation gestures.
        public var allowsBackForwardNavigationGestures: Bool
        
        /// Custom user agent string (nil for default).
        public var customUserAgent: String?
        
        /// Creates a configuration with default values.
        public init(
            javaScriptEnabled: Bool = true,
            allowsInlineMediaPlayback: Bool = true,
            mediaAutoplayPolicy: MediaAutoplayPolicy = .userGesture,
            backgroundColor: PlatformColor = .white,
            showsScrollIndicator: Bool = true,
            allowsZooming: Bool = true,
            minimumZoomScale: CGFloat = 1.0,
            maximumZoomScale: CGFloat = 4.0,
            allowsBackForwardNavigationGestures: Bool = true,
            customUserAgent: String? = nil
        ) {
            self.javaScriptEnabled = javaScriptEnabled
            self.allowsInlineMediaPlayback = allowsInlineMediaPlayback
            self.mediaAutoplayPolicy = mediaAutoplayPolicy
            self.backgroundColor = backgroundColor
            self.showsScrollIndicator = showsScrollIndicator
            self.allowsZooming = allowsZooming
            self.minimumZoomScale = minimumZoomScale
            self.maximumZoomScale = maximumZoomScale
            self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
            self.customUserAgent = customUserAgent
        }
        
        /// Standard configuration with common settings.
        public static let standard = Configuration()
        
        /// Minimal configuration with JavaScript disabled.
        public static let minimal = Configuration(
            javaScriptEnabled: false,
            allowsInlineMediaPlayback: false,
            mediaAutoplayPolicy: .never,
            allowsZooming: false,
            allowsBackForwardNavigationGestures: false
        )
        
        /// Configuration optimized for reading content.
        public static let reader = Configuration(
            allowsInlineMediaPlayback: false,
            mediaAutoplayPolicy: .never,
            showsScrollIndicator: false,
            maximumZoomScale: 6.0
        )
    }
    
    /// Policy for automatic media playback.
    public enum MediaAutoplayPolicy {
        /// Always allow autoplay.
        case always
        
        /// Require user gesture to play.
        case userGesture
        
        /// Never allow autoplay.
        case never
    }
}

// MARK: - Coordinator

@available(iOS 14.0, macOS 11.0, *)
extension WhatWGWebView {
    
    /// Coordinator that bridges between SwiftUI and the web view.
    public class Coordinator: NSObject, WhatWGWebViewContainerDelegate {
        
        private var browser: WhatWGBrowser
        private var cancellables = Set<AnyCancellable>()
        
        init(browser: WhatWGBrowser) {
            self.browser = browser
            super.init()
            setupBindings()
        }
        
        func updateBrowser(_ browser: WhatWGBrowser) {
            guard self.browser !== browser else { return }
            self.browser = browser
            cancellables.removeAll()
            setupBindings()
        }
        
        private func setupBindings() {
            // Observe browser state changes if needed
        }
        
        // MARK: - WhatWGWebViewContainerDelegate
        
        public func webViewContainer(_ container: WhatWGWebViewContainer, didStartLoading url: URL) {
            Task { @MainActor in
                browser.onNavigationEvent?(.started(url))
            }
        }
        
        public func webViewContainer(_ container: WhatWGWebViewContainer, didFinishLoading url: URL) {
            Task { @MainActor in
                browser.onNavigationEvent?(.finished(url))
            }
        }
        
        public func webViewContainer(_ container: WhatWGWebViewContainer, didFailWithError error: BrowserError) {
            Task { @MainActor in
                browser.onNavigationEvent?(.failed(error))
            }
        }
        
        public func webViewContainer(_ container: WhatWGWebViewContainer, didUpdateTitle title: String) {
            // Title update handled by container
        }
        
        public func webViewContainer(_ container: WhatWGWebViewContainer, didUpdateProgress progress: Double) {
            // Progress update handled by container
        }
        
        public func webViewContainer(_ container: WhatWGWebViewContainer, didReceiveConsoleMessage message: ConsoleMessage) {
            Task { @MainActor in
                browser.onConsoleMessage?(message)
            }
        }
    }
}

// MARK: - Web View Container

/// Protocol for web view container delegate.
@available(iOS 14.0, macOS 11.0, *)
public protocol WhatWGWebViewContainerDelegate: AnyObject {
    func webViewContainer(_ container: WhatWGWebViewContainer, didStartLoading url: URL)
    func webViewContainer(_ container: WhatWGWebViewContainer, didFinishLoading url: URL)
    func webViewContainer(_ container: WhatWGWebViewContainer, didFailWithError error: BrowserError)
    func webViewContainer(_ container: WhatWGWebViewContainer, didUpdateTitle title: String)
    func webViewContainer(_ container: WhatWGWebViewContainer, didUpdateProgress progress: Double)
    func webViewContainer(_ container: WhatWGWebViewContainer, didReceiveConsoleMessage message: ConsoleMessage)
}

/// The platform-specific container view that hosts the web content.
///
/// This view manages the actual rendering and interaction with web content.
/// It interfaces with the underlying WHATWG browser engine.
///
@available(iOS 14.0, macOS 11.0, *)
public class WhatWGWebViewContainer: PlatformView {
    
    /// The delegate for receiving events.
    public weak var delegate: WhatWGWebViewContainerDelegate?
    
    /// The current configuration.
    public let configuration: WhatWGWebView.Configuration
    
    /// The current URL being displayed.
    public private(set) var currentURL: URL?
    
    /// The content view that displays web content.
    private var contentView: ContentRenderView?
    
    /// The current loading state.
    private var isLoading = false
    
    #if os(iOS)
    /// Creates a new container with the specified frame and configuration.
    public init(frame: CGRect, configuration: WhatWGWebView.Configuration) {
        self.configuration = configuration
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.configuration = .standard
        super.init(coder: coder)
        setupView()
    }
    #else
    /// Creates a new container with the specified frame and configuration.
    public init(frame: NSRect, configuration: WhatWGWebView.Configuration) {
        self.configuration = configuration
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        self.configuration = .standard
        super.init(coder: coder)
        setupView()
    }
    #endif
    
    private func setupView() {
        // Set up the view hierarchy
        #if os(iOS)
        backgroundColor = configuration.backgroundColor
        #else
        wantsLayer = true
        layer?.backgroundColor = configuration.backgroundColor.cgColor
        #endif
        
        // Create content view
        let content = ContentRenderView(frame: bounds)
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        #if os(iOS)
        content.backgroundColor = configuration.backgroundColor
        addSubview(content)
        #else
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        #endif
        contentView = content
    }
    
    /// Updates the container based on browser state.
    public func update(with browser: WhatWGBrowser) {
        // Check if we need to load a new URL
        if let stateURL = browser.navigationState.url,
           stateURL != currentURL,
           browser.isLoading {
            loadURL(stateURL)
        }
    }
    
    /// Loads the specified URL.
    public func loadURL(_ url: URL) {
        guard !isLoading else { return }
        
        isLoading = true
        currentURL = url
        
        delegate?.webViewContainer(self, didStartLoading: url)
        
        // In a real implementation, this would:
        // 1. Create a network request via the WHATWG Fetch API
        // 2. Parse the HTML response using the WHATWG HTML parser
        // 3. Build the DOM tree
        // 4. Execute scripts via the JS engine
        // 5. Render the content
        
        // For now, display a placeholder
        contentView?.displayPlaceholder(for: url)
        
        // Simulate loading completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.delegate?.webViewContainer(self, didFinishLoading: url)
            self.delegate?.webViewContainer(self, didUpdateTitle: url.host ?? "Untitled")
        }
    }
    
    /// Executes JavaScript in the current context.
    public func evaluateJavaScript(_ script: String) async throws -> Any? {
        // Would delegate to the JS engine
        return nil
    }
}

// MARK: - Content Render View

/// Internal view for rendering web content.
@available(iOS 14.0, macOS 11.0, *)
class ContentRenderView: PlatformView {
    
    private var placeholderLabel: PlatformLabel?
    
    #if os(iOS)
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPlaceholder()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlaceholder()
    }
    #else
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupPlaceholder()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPlaceholder()
    }
    #endif
    
    private func setupPlaceholder() {
        #if os(iOS)
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
        
        placeholderLabel = label
        #else
        let label = NSTextField(labelWithString: "")
        label.alignment = .center
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
        
        placeholderLabel = label
        #endif
    }
    
    func displayPlaceholder(for url: URL) {
        let text = """
        WHATWG Browser Engine
        
        Loading: \(url.absoluteString)
        
        (Web rendering implementation pending)
        """
        
        #if os(iOS)
        placeholderLabel?.text = text
        #else
        placeholderLabel?.stringValue = text
        #endif
    }
}

// MARK: - Platform Label Typealias

#if os(iOS)
typealias PlatformLabel = UILabel
#else
typealias PlatformLabel = NSTextField
#endif

// MARK: - View Modifiers

@available(iOS 14.0, macOS 11.0, *)
extension WhatWGWebView {
    
    /// Sets whether JavaScript is enabled.
    public func javaScriptEnabled(_ enabled: Bool) -> WhatWGWebView {
        var copy = self
        copy.configuration.javaScriptEnabled = enabled
        return copy
    }
    
    /// Sets the background color.
    public func webViewBackgroundColor(_ color: PlatformColor) -> WhatWGWebView {
        var copy = self
        copy.configuration.backgroundColor = color
        return copy
    }
    
    /// Sets whether to allow zoom gestures.
    public func allowsZooming(_ allows: Bool) -> WhatWGWebView {
        var copy = self
        copy.configuration.allowsZooming = allows
        return copy
    }
    
    /// Sets whether to allow back/forward navigation gestures.
    public func allowsBackForwardGestures(_ allows: Bool) -> WhatWGWebView {
        var copy = self
        copy.configuration.allowsBackForwardNavigationGestures = allows
        return copy
    }
    
    /// Sets a custom user agent string.
    public func userAgent(_ userAgent: String?) -> WhatWGWebView {
        var copy = self
        copy.configuration.customUserAgent = userAgent
        return copy
    }
}
#endif

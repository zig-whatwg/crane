#if os(iOS) || os(macOS)
import SwiftUI

#if os(iOS)
import UIKit
public typealias PlatformColor = UIColor
#else
import AppKit
public typealias PlatformColor = NSColor
#endif

/// A native SwiftUI view that displays web content using the WHATWG browser engine.
///
/// `WhatWGWebView` uses SwiftUI's Canvas for rendering and native gesture recognizers
/// for interaction. It integrates with `WhatWGBrowser` for navigation and JavaScript execution.
///
/// ## Example Usage
///
/// ```swift
/// struct BrowserView: View {
///     @State var browser = WhatWGBrowser()
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
@available(iOS 17.0, macOS 14.0, *)
public struct WhatWGWebView: View {
    
    /// The browser instance controlling this view.
    var browser: WhatWGBrowser
    
    /// Configuration options for the web view.
    public var configuration: Configuration
    
    /// Current scroll offset for the content.
    @State private var scrollOffset: CGPoint = .zero
    
    /// Current zoom scale.
    @State private var zoomScale: CGFloat = 1.0
    
    /// Whether a drag gesture is active.
    @State private var isDragging: Bool = false
    
    /// Creates a new web view with the specified browser.
    ///
    /// - Parameters:
    ///   - browser: The browser instance to use.
    ///   - configuration: Optional configuration. Defaults to standard configuration.
    public init(browser: WhatWGBrowser, configuration: Configuration = .standard) {
        self.browser = browser
        self.configuration = configuration
    }
    
    public var body: some View {
        GeometryReader { geometry in
            contentCanvas(size: geometry.size)
                .gesture(tapGesture)
                .gesture(dragGesture)
                .gesture(magnificationGesture)
                .focusable()
                .onKeyPress { keyPress in
                    handleKeyPress(keyPress)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Web content")
                .accessibilityValue(browser.title.isEmpty ? "No content loaded" : browser.title)
                .accessibilityAddTraits(.allowsDirectInteraction)
        }
        .background(Color(configuration.backgroundColor))
        .onChange(of: browser.navigationState.url) { oldValue, newValue in
            if newValue != oldValue {
                // Reset scroll position on navigation
                scrollOffset = .zero
                zoomScale = 1.0
            }
        }
    }
    
    // MARK: - Canvas Rendering
    
    @ViewBuilder
    private func contentCanvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            // Render the web content
            renderContent(context: context, size: canvasSize)
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func renderContent(context: GraphicsContext, size: CGSize) {
        // Apply zoom and scroll transforms
        var transformedContext = context
        transformedContext.translateBy(x: -scrollOffset.x, y: -scrollOffset.y)
        transformedContext.scaleBy(x: zoomScale, y: zoomScale)
        
        // Render placeholder content (actual rendering would come from browser engine)
        let placeholderText: String
        if browser.isLoading {
            placeholderText = """
            WHATWG Browser Engine
            
            Loading: \(browser.urlString)
            
            Progress: \(Int(browser.loadingProgress * 100))%
            """
        } else if let url = browser.navigationState.url {
            placeholderText = """
            WHATWG Browser Engine
            
            URL: \(url.absoluteString)
            Title: \(browser.title)
            
            (Web rendering implementation pending)
            """
        } else {
            placeholderText = """
            WHATWG Browser Engine
            
            No content loaded.
            Enter a URL to begin browsing.
            """
        }
        
        // Draw placeholder text centered
        let textRect = CGRect(
            x: 20,
            y: size.height / 2 - 60,
            width: size.width - 40,
            height: 120
        )
        
        let text = Text(placeholderText)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        
        transformedContext.draw(text, in: textRect)
    }
    
    // MARK: - Gesture Handling
    
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                handleTap(at: value.location)
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                handleScroll(translation: value.translation)
            }
            .onEnded { value in
                isDragging = false
                // Apply final scroll with velocity for momentum
                let velocity = CGPoint(
                    x: value.predictedEndTranslation.width - value.translation.width,
                    y: value.predictedEndTranslation.height - value.translation.height
                )
                handleScrollEnd(velocity: velocity)
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard configuration.allowsZooming else { return }
                let newScale = zoomScale * scale
                zoomScale = min(max(newScale, configuration.minimumZoomScale), configuration.maximumZoomScale)
            }
    }
    
    // MARK: - Event Handlers
    
    private func handleTap(at location: CGPoint) {
        // Convert location to content coordinates
        let contentLocation = CGPoint(
            x: (location.x + scrollOffset.x) / zoomScale,
            y: (location.y + scrollOffset.y) / zoomScale
        )
        
        // Notify browser of tap (for hit testing, link activation, etc.)
        browser.handleTap(at: contentLocation)
    }
    
    private func handleScroll(translation: CGSize) {
        // Update scroll offset
        scrollOffset = CGPoint(
            x: max(0, scrollOffset.x - translation.width),
            y: max(0, scrollOffset.y - translation.height)
        )
        
        // Notify browser of scroll
        browser.handleScroll(offset: scrollOffset)
    }
    
    private func handleScrollEnd(velocity: CGPoint) {
        // Apply momentum scrolling (simplified)
        withAnimation(.easeOut(duration: 0.3)) {
            scrollOffset = CGPoint(
                x: max(0, scrollOffset.x - velocity.x * 0.3),
                y: max(0, scrollOffset.y - velocity.y * 0.3)
            )
        }
    }
    
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // Handle keyboard navigation
        switch keyPress.key {
        case .leftArrow:
            if keyPress.modifiers.contains(.command) && configuration.allowsBackForwardNavigationGestures {
                browser.goBack()
                return .handled
            }
        case .rightArrow:
            if keyPress.modifiers.contains(.command) && configuration.allowsBackForwardNavigationGestures {
                browser.goForward()
                return .handled
            }
        case .return:
            if keyPress.modifiers.contains(.command) {
                browser.reload()
                return .handled
            }
        case .escape:
            browser.stopLoading()
            return .handled
        default:
            break
        }
        
        return .ignored
    }
}

// MARK: - Configuration

@available(iOS 17.0, macOS 14.0, *)
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

// MARK: - View Modifiers

@available(iOS 17.0, macOS 14.0, *)
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

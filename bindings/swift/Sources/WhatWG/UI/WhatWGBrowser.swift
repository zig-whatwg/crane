#if os(iOS) || os(macOS)
import Foundation
import Combine

/// Main browser controller for SwiftUI integration.
///
/// `WhatWGBrowser` is an ObservableObject that manages browser state and provides
/// navigation, tab management, and JavaScript execution capabilities.
///
/// ## Example Usage
///
/// ```swift
/// struct ContentView: View {
///     @StateObject var browser = WhatWGBrowser()
///
///     var body: some View {
///         VStack {
///             WhatWGWebView(browser: browser)
///             HStack {
///                 Button("Back") { browser.goBack() }
///                     .disabled(!browser.canGoBack)
///                 Button("Forward") { browser.goForward() }
///                     .disabled(!browser.canGoForward)
///                 Button("Reload") { browser.reload() }
///             }
///             TextField("URL", text: $browser.urlString)
///                 .onSubmit { browser.loadURL() }
///         }
///     }
/// }
/// ```
///
@available(iOS 14.0, macOS 11.0, *)
@MainActor
public final class WhatWGBrowser: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current URL as a string for binding.
    @Published public var urlString: String = ""
    
    /// The current page title.
    @Published public private(set) var title: String = ""
    
    /// Whether the page is currently loading.
    @Published public private(set) var isLoading: Bool = false
    
    /// The estimated loading progress (0.0 to 1.0).
    @Published public private(set) var loadingProgress: Double = 0.0
    
    /// Whether navigation can go back.
    @Published public private(set) var canGoBack: Bool = false
    
    /// Whether navigation can go forward.
    @Published public private(set) var canGoForward: Bool = false
    
    /// Whether the connection is secure (HTTPS).
    @Published public private(set) var isSecure: Bool = false
    
    /// The current navigation state.
    @Published public private(set) var navigationState: NavigationState = .empty
    
    /// All open tabs.
    @Published public private(set) var tabs: [BrowserTab] = []
    
    /// Index of the currently active tab.
    @Published public var activeTabIndex: Int = 0 {
        didSet {
            updateActiveTab()
        }
    }
    
    /// The most recent error, if any.
    @Published public private(set) var lastError: BrowserError?
    
    // MARK: - Properties
    
    /// The underlying platform instance.
    private let platform: WhatWGPlatform
    
    /// History entries for the current tab.
    public private(set) var history: [HistoryEntry] = []
    
    /// Callback for navigation events.
    public var onNavigationEvent: ((NavigationEvent) -> Void)?
    
    /// Callback for JavaScript console messages.
    public var onConsoleMessage: ((ConsoleMessage) -> Void)?
    
    // MARK: - Initialization
    
    /// Creates a new browser instance.
    ///
    /// - Parameter platform: The platform to use. Creates a default one if nil.
    public init(platform: WhatWGPlatform? = nil) {
        self.platform = platform ?? WhatWGPlatform()
        
        // Create initial tab
        let initialTab = BrowserTab(isActive: true)
        tabs.append(initialTab)
    }
    
    // MARK: - Navigation
    
    /// Loads the URL from the current `urlString`.
    public func loadURL() {
        guard !urlString.isEmpty else { return }
        
        // Add scheme if missing
        var urlToLoad = urlString
        if !urlToLoad.contains("://") {
            urlToLoad = "https://\(urlToLoad)"
        }
        
        guard let url = URL(string: urlToLoad) else {
            lastError = .invalidURL(urlString)
            return
        }
        
        loadURL(url)
    }
    
    /// Loads a specific URL.
    ///
    /// - Parameter url: The URL to load.
    public func loadURL(_ url: URL) {
        isLoading = true
        loadingProgress = 0.0
        lastError = nil
        
        // Update URL string
        urlString = url.absoluteString
        
        // Update navigation state
        updateNavigationState(with: url, isLoading: true)
        
        // Emit navigation event
        onNavigationEvent?(.started(url))
        
        // Actual loading would be handled by the underlying engine
        // For now, we simulate the loading process
        simulateLoading(url)
    }
    
    /// Navigates back in history.
    public func goBack() {
        guard canGoBack else { return }
        
        // Update navigation state
        if activeTabIndex < tabs.count {
            onNavigationEvent?(.goingBack)
            // Actual back navigation would be handled by the engine
        }
    }
    
    /// Navigates forward in history.
    public func goForward() {
        guard canGoForward else { return }
        
        onNavigationEvent?(.goingForward)
        // Actual forward navigation would be handled by the engine
    }
    
    /// Reloads the current page.
    public func reload() {
        guard let url = navigationState.url else { return }
        
        onNavigationEvent?(.reloading)
        loadURL(url)
    }
    
    /// Stops loading the current page.
    public func stopLoading() {
        isLoading = false
        onNavigationEvent?(.stopped)
    }
    
    // MARK: - Tab Management
    
    /// Creates a new tab.
    ///
    /// - Parameter makeActive: Whether to switch to the new tab.
    /// - Returns: The new tab's ID.
    @discardableResult
    public func newTab(makeActive: Bool = true) -> UUID {
        let tab = BrowserTab(isActive: makeActive)
        
        if makeActive {
            // Deactivate current tab
            if activeTabIndex < tabs.count {
                tabs[activeTabIndex].isActive = false
            }
            tabs.append(tab)
            activeTabIndex = tabs.count - 1
        } else {
            tabs.append(tab)
        }
        
        return tab.id
    }
    
    /// Closes a tab.
    ///
    /// - Parameter id: The tab's ID.
    public func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        tabs.remove(at: index)
        
        // If we closed the active tab, switch to another
        if tabs.isEmpty {
            newTab()
        } else if index == activeTabIndex {
            activeTabIndex = max(0, index - 1)
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        }
    }
    
    /// Switches to a specific tab.
    ///
    /// - Parameter id: The tab's ID.
    public func switchToTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        activeTabIndex = index
    }
    
    // MARK: - JavaScript Execution
    
    /// Executes JavaScript code in the current page.
    ///
    /// - Parameter script: The JavaScript code to execute.
    /// - Returns: The result of the script execution.
    public func evaluateJavaScript(_ script: String) async throws -> Any? {
        // This would delegate to the underlying engine
        // For now, return nil
        return nil
    }
    
    // MARK: - Private
    
    private func updateNavigationState(with url: URL, isLoading: Bool) {
        navigationState = NavigationState(
            url: url,
            title: title,
            isLoading: isLoading,
            loadingProgress: loadingProgress,
            canGoBack: canGoBack,
            canGoForward: canGoForward,
            isSecure: url.scheme == "https",
            faviconURL: nil
        )
        
        isSecure = url.scheme == "https"
        
        // Update current tab
        if activeTabIndex < tabs.count {
            tabs[activeTabIndex].state = navigationState
        }
    }
    
    private func updateActiveTab() {
        for i in 0..<tabs.count {
            tabs[i].isActive = (i == activeTabIndex)
        }
        
        // Update state from the active tab
        if activeTabIndex < tabs.count {
            let tab = tabs[activeTabIndex]
            navigationState = tab.state
            urlString = tab.state.url?.absoluteString ?? ""
            title = tab.state.title
            isLoading = tab.state.isLoading
            loadingProgress = tab.state.loadingProgress
            canGoBack = tab.state.canGoBack
            canGoForward = tab.state.canGoForward
            isSecure = tab.state.isSecure
        }
    }
    
    private func simulateLoading(_ url: URL) {
        // Simulate loading progress
        Task {
            for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                loadingProgress = progress
            }
            
            // Finished loading
            isLoading = false
            loadingProgress = 1.0
            title = url.host ?? "Untitled"
            canGoBack = true
            
            // Add to history
            history.append(HistoryEntry(url: url, title: title))
            
            // Update state
            updateNavigationState(with: url, isLoading: false)
            
            onNavigationEvent?(.finished(url))
        }
    }
}

// MARK: - Navigation Events

/// Events emitted during navigation.
public enum NavigationEvent {
    /// Navigation started.
    case started(URL)
    
    /// Navigation finished successfully.
    case finished(URL)
    
    /// Navigation failed.
    case failed(BrowserError)
    
    /// Going back in history.
    case goingBack
    
    /// Going forward in history.
    case goingForward
    
    /// Reloading the page.
    case reloading
    
    /// Loading was stopped.
    case stopped
}

// MARK: - Console Message

/// A message from the JavaScript console.
public struct ConsoleMessage: Sendable {
    
    /// The message level.
    public enum Level: String, Sendable {
        case log
        case info
        case warn
        case error
        case debug
    }
    
    /// The message level.
    public let level: Level
    
    /// The message text.
    public let text: String
    
    /// The source URL.
    public let source: String?
    
    /// The line number.
    public let line: Int?
    
    /// Creates a new console message.
    public init(level: Level, text: String, source: String? = nil, line: Int? = nil) {
        self.level = level
        self.text = text
        self.source = source
        self.line = line
    }
}
#endif

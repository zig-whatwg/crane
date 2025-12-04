import Foundation

/// Represents the navigation state of a browser tab.
public struct NavigationState: Sendable {
    
    /// The current URL.
    public var url: URL?
    
    /// The page title.
    public var title: String
    
    /// Whether the page is currently loading.
    public var isLoading: Bool
    
    /// The estimated loading progress (0.0 to 1.0).
    public var loadingProgress: Double
    
    /// Whether the page can navigate back.
    public var canGoBack: Bool
    
    /// Whether the page can navigate forward.
    public var canGoForward: Bool
    
    /// Whether the connection is secure (HTTPS).
    public var isSecure: Bool
    
    /// The favicon URL if available.
    public var faviconURL: URL?
    
    /// Creates a new navigation state.
    public init(
        url: URL? = nil,
        title: String = "",
        isLoading: Bool = false,
        loadingProgress: Double = 0.0,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isSecure: Bool = false,
        faviconURL: URL? = nil
    ) {
        self.url = url
        self.title = title
        self.isLoading = isLoading
        self.loadingProgress = loadingProgress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isSecure = isSecure
        self.faviconURL = faviconURL
    }
    
    /// Empty navigation state.
    public static let empty = NavigationState()
}

/// A history entry in the browser's navigation stack.
public struct HistoryEntry: Identifiable, Sendable {
    
    /// Unique identifier for this entry.
    public let id: UUID
    
    /// The URL of the page.
    public let url: URL
    
    /// The page title.
    public let title: String
    
    /// When this page was visited.
    public let visitedAt: Date
    
    /// Creates a new history entry.
    public init(url: URL, title: String, visitedAt: Date = Date()) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
    }
}

/// Represents a browser tab.
public struct BrowserTab: Identifiable, Sendable {
    
    /// Unique identifier for this tab.
    public let id: UUID
    
    /// The current navigation state.
    public var state: NavigationState
    
    /// Whether this is the active tab.
    public var isActive: Bool
    
    /// Creates a new browser tab.
    public init(
        id: UUID = UUID(),
        state: NavigationState = .empty,
        isActive: Bool = false
    ) {
        self.id = id
        self.state = state
        self.isActive = isActive
    }
}

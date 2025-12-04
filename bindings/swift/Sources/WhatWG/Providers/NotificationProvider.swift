import Foundation

/// Protocol for providing notification functionality.
///
/// Implement this protocol to provide system notification support.
///
public protocol NotificationProvider: AnyObject, Sendable {
    
    /// Requests notification permission.
    ///
    /// - Returns: The permission status.
    func requestPermission() async -> NotificationPermission
    
    /// Gets the current permission status.
    var permission: NotificationPermission { get }
    
    /// Shows a notification.
    ///
    /// - Parameter options: Notification options.
    /// - Returns: A notification handle.
    /// - Throws: If permission is denied.
    func show(options: NotificationOptions) async throws -> NotificationHandle
}

/// Notification permission states.
public enum NotificationPermission: String, Sendable {
    case `default` = "default"
    case granted = "granted"
    case denied = "denied"
}

/// Options for creating a notification.
public struct NotificationOptions: Sendable {
    /// The notification title.
    public var title: String
    
    /// The notification body.
    public var body: String?
    
    /// The notification icon URL.
    public var icon: String?
    
    /// The notification badge URL.
    public var badge: String?
    
    /// The notification image URL.
    public var image: String?
    
    /// The notification tag.
    public var tag: String?
    
    /// Data associated with the notification.
    public var data: Any?
    
    /// Whether to require interaction.
    public var requireInteraction: Bool
    
    /// Whether to suppress sound.
    public var silent: Bool
    
    /// Vibration pattern.
    public var vibrate: [UInt32]?
    
    /// Actions for the notification.
    public var actions: [NotificationAction]
    
    public init(
        title: String,
        body: String? = nil,
        icon: String? = nil,
        badge: String? = nil,
        image: String? = nil,
        tag: String? = nil,
        data: Any? = nil,
        requireInteraction: Bool = false,
        silent: Bool = false,
        vibrate: [UInt32]? = nil,
        actions: [NotificationAction] = []
    ) {
        self.title = title
        self.body = body
        self.icon = icon
        self.badge = badge
        self.image = image
        self.tag = tag
        self.data = data
        self.requireInteraction = requireInteraction
        self.silent = silent
        self.vibrate = vibrate
        self.actions = actions
    }
}

/// An action button for a notification.
public struct NotificationAction: Sendable {
    /// Action identifier.
    public var action: String
    
    /// Action title.
    public var title: String
    
    /// Action icon URL.
    public var icon: String?
    
    public init(action: String, title: String, icon: String? = nil) {
        self.action = action
        self.title = title
        self.icon = icon
    }
}

/// A handle to an active notification.
public protocol NotificationHandle: AnyObject, Sendable {
    /// The notification tag.
    var tag: String? { get }
    
    /// Closes the notification.
    func close()
}

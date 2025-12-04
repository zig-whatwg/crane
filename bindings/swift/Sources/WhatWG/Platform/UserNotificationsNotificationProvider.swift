#if os(iOS) || os(macOS) || os(watchOS)
import Foundation
import UserNotifications

/// Notification provider implementation using UserNotifications framework.
///
/// This provider uses UNUserNotificationCenter for local notifications.
/// Make sure to request notification permissions before showing notifications.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.notificationProvider = UserNotificationsNotificationProvider()
/// ```
///
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public final class UserNotificationsNotificationProvider: NotificationProvider, @unchecked Sendable {
    
    private let notificationCenter: UNUserNotificationCenter
    private var activeNotifications: [String: UNNotificationHandle] = [:]
    private let lock = NSLock()
    
    /// The current permission status.
    public private(set) var permission: NotificationPermission = .default
    
    /// Creates a new iOS notification provider.
    public init() {
        self.notificationCenter = UNUserNotificationCenter.current()
        
        // Check current authorization status
        notificationCenter.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async {
                self?.updatePermission(from: status)
            }
        }
    }
    
    // MARK: - NotificationProvider
    
    public func requestPermission() async -> NotificationPermission {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            permission = granted ? .granted : .denied
            return permission
        } catch {
            permission = .denied
            return .denied
        }
    }
    
    public func show(options: NotificationOptions) async throws -> NotificationHandle {
        guard permission == .granted else {
            throw WhatWGError.operationFailed("Notification permission not granted")
        }
        
        let content = UNMutableNotificationContent()
        content.title = options.title
        
        if let body = options.body {
            content.body = body
        }
        
        if !options.silent {
            content.sound = .default
        }
        
        if let badge = options.badge, let badgeNumber = Int(badge) {
            content.badge = NSNumber(value: badgeNumber)
        }
        
        // Add custom data - safely cast Sendable to [String: Any]
        if let data = options.data as? [String: any Sendable] {
            // Convert to [String: Any] for userInfo
            var userInfo: [String: Any] = [:]
            for (key, value) in data {
                userInfo[key] = value
            }
            content.userInfo = userInfo
        }
        
        // Add actions if provided
        if !options.actions.isEmpty {
            let categoryId = options.tag ?? UUID().uuidString
            var actions: [UNNotificationAction] = []
            
            for action in options.actions {
                let notificationAction = UNNotificationAction(
                    identifier: action.action,
                    title: action.title,
                    options: []
                )
                actions.append(notificationAction)
            }
            
            let category = UNNotificationCategory(
                identifier: categoryId,
                actions: actions,
                intentIdentifiers: [],
                options: []
            )
            
            notificationCenter.setNotificationCategories([category])
            content.categoryIdentifier = categoryId
        }
        
        // Create and schedule the notification
        let identifier = options.tag ?? UUID().uuidString
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Deliver immediately
        )
        
        try await notificationCenter.add(request)
        
        let handle = UNNotificationHandle(
            identifier: identifier,
            tag: options.tag,
            notificationCenter: notificationCenter
        )
        
        // Use withLock to avoid calling lock/unlock in async context
        lock.withLock {
            activeNotifications[identifier] = handle
        }
        
        return handle
    }
    
    // MARK: - Private
    
    private func updatePermission(from status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral:
            permission = .granted
        case .denied:
            permission = .denied
        case .notDetermined:
            permission = .default
        @unknown default:
            permission = .default
        }
    }
}

// MARK: - UNNotificationHandle

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
final class UNNotificationHandle: NotificationHandle, @unchecked Sendable {
    
    private let identifier: String
    public let tag: String?
    private let notificationCenter: UNUserNotificationCenter
    
    init(identifier: String, tag: String?, notificationCenter: UNUserNotificationCenter) {
        self.identifier = identifier
        self.tag = tag
        self.notificationCenter = notificationCenter
    }
    
    public func close() {
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

// MARK: - Backwards Compatibility

/// Deprecated: Use `UserNotificationsNotificationProvider` instead.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
@available(*, deprecated, renamed: "UserNotificationsNotificationProvider")
public typealias iOSNotificationProvider = UserNotificationsNotificationProvider
#endif

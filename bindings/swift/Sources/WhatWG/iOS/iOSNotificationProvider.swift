#if os(iOS) || os(macOS) || os(watchOS)
import Foundation
import UserNotifications

/// iOS/macOS implementation of NotificationProvider using UserNotifications framework.
///
/// This provider uses UNUserNotificationCenter for local notifications.
/// Make sure to request notification permissions before showing notifications.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
/// platform.notificationProvider = iOSNotificationProvider()
/// ```
///
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public final class iOSNotificationProvider: NotificationProvider, @unchecked Sendable {
    
    private let notificationCenter: UNUserNotificationCenter
    private var activeNotifications: [String: iOSNotificationHandle] = [:]
    private let lock = NSLock()
    
    /// The current permission status.
    public private(set) var permission: NotificationPermission = .default
    
    /// Creates a new iOS notification provider.
    public init() {
        self.notificationCenter = UNUserNotificationCenter.current()
        
        // Check current authorization status
        notificationCenter.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.updatePermission(from: settings.authorizationStatus)
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
        
        // Add custom data
        if let data = options.data as? [String: Any] {
            content.userInfo = data
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
        
        let handle = iOSNotificationHandle(
            identifier: identifier,
            tag: options.tag,
            notificationCenter: notificationCenter
        )
        
        lock.lock()
        activeNotifications[identifier] = handle
        lock.unlock()
        
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

// MARK: - iOSNotificationHandle

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
final class iOSNotificationHandle: NotificationHandle, @unchecked Sendable {
    
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
#endif

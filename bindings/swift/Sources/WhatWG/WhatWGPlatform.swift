import Foundation
import CWhatWG

// MARK: - Provider Configuration

/// Configuration struct for platform provider injection.
///
/// `ProviderConfiguration` allows you to customize which platform providers
/// are used by the WHATWG platform. Each provider is optional, allowing you
/// to mix default implementations with custom providers.
///
/// ## Example Usage
///
/// ```swift
/// // Use default configuration
/// let platform = WhatWGPlatform(configuration: .default)
///
/// // Use minimal configuration (no providers)
/// let platform = WhatWGPlatform(configuration: .minimal)
///
/// // Custom configuration with builder
/// let platform = WhatWGPlatform {
///     $0.clipboard = UIPasteboardClipboardProvider()
///     $0.storage = MyCloudStorageProvider()
///     $0.network = URLSessionNetworkProvider()
/// }
/// ```
///
public struct ProviderConfiguration: Sendable {
    
    /// Clipboard capability provider.
    public var clipboard: (any ClipboardProvider)?
    
    /// Timer capability provider.
    public var timer: (any TimerProvider)?
    
    /// Network capability provider.
    public var network: (any NetworkProvider)?
    
    /// Storage capability provider.
    public var storage: (any StorageProvider)?
    
    /// File system capability provider.
    public var fileSystem: (any FileSystemProvider)?
    
    /// Geolocation capability provider.
    public var geolocation: (any GeolocationProvider)?
    
    /// Notification capability provider.
    public var notification: (any NotificationProvider)?
    
    /// UI capability provider.
    public var ui: (any UIProvider)?
    
    /// Creates an empty provider configuration.
    public init() {}
    
    /// Creates a provider configuration with all providers specified.
    ///
    /// - Parameters:
    ///   - clipboard: Clipboard provider.
    ///   - timer: Timer provider.
    ///   - network: Network provider.
    ///   - storage: Storage provider.
    ///   - fileSystem: File system provider.
    ///   - geolocation: Geolocation provider.
    ///   - notification: Notification provider.
    ///   - ui: UI provider.
    public init(
        clipboard: (any ClipboardProvider)? = nil,
        timer: (any TimerProvider)? = nil,
        network: (any NetworkProvider)? = nil,
        storage: (any StorageProvider)? = nil,
        fileSystem: (any FileSystemProvider)? = nil,
        geolocation: (any GeolocationProvider)? = nil,
        notification: (any NotificationProvider)? = nil,
        ui: (any UIProvider)? = nil
    ) {
        self.clipboard = clipboard
        self.timer = timer
        self.network = network
        self.storage = storage
        self.fileSystem = fileSystem
        self.geolocation = geolocation
        self.notification = notification
        self.ui = ui
    }
    
    // MARK: - Static Configurations
    
    /// Minimal configuration with no providers.
    ///
    /// Use this when you want to start with a blank slate and add
    /// only the providers you need.
    public static let minimal = ProviderConfiguration()
    
    /// Default configuration with all standard platform providers.
    ///
    /// This configuration uses the platform's default provider implementations:
    /// - Clipboard: UIPasteboardClipboardProvider (iOS) or system clipboard
    /// - Timer: DispatchTimerProvider (GCD-based timers)
    /// - Network: URLSessionNetworkProvider
    /// - Storage: UserDefaultsStorageProvider
    /// - FileSystem: UIDocumentPickerFileSystemProvider
    /// - Geolocation: CoreLocationGeolocationProvider
    /// - Notification: UserNotificationsNotificationProvider
    /// - UI: UIKitUIProvider (iOS) or AppKitUIProvider (macOS)
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    public static var `default`: ProviderConfiguration {
        var config = ProviderConfiguration()
        
        #if os(iOS)
        config.clipboard = UIPasteboardClipboardProvider()
        config.ui = UIKitUIProvider()
        #elseif os(macOS)
        config.ui = AppKitUIProvider()
        #endif
        
        #if os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
        config.timer = DispatchTimerProvider()
        config.network = URLSessionNetworkProvider()
        config.storage = UserDefaultsStorageProvider()
        #endif
        
        #if os(iOS) || os(macOS)
        config.fileSystem = UIDocumentPickerFileSystemProvider()
        #endif
        
        #if os(iOS) || os(macOS) || os(watchOS)
        config.geolocation = CoreLocationGeolocationProvider()
        config.notification = UserNotificationsNotificationProvider()
        #endif
        
        return config
    }
    
    /// Network-only configuration.
    ///
    /// Use this when you only need network capabilities.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
    public static var networkOnly: ProviderConfiguration {
        var config = ProviderConfiguration()
        config.timer = DispatchTimerProvider()
        config.network = URLSessionNetworkProvider()
        return config
    }
    
    // MARK: - Capability Detection
    
    /// Returns a set of capabilities that are available based on configured providers.
    public var availableCapabilities: Set<Capability> {
        var capabilities = Set<Capability>()
        
        if clipboard != nil { capabilities.insert(.clipboard) }
        if timer != nil { capabilities.insert(.timer) }
        if network != nil { capabilities.insert(.network) }
        if storage != nil { capabilities.insert(.storage) }
        if fileSystem != nil { capabilities.insert(.fileSystem) }
        if geolocation != nil { capabilities.insert(.geolocation) }
        if notification != nil { capabilities.insert(.notification) }
        if ui != nil { capabilities.insert(.ui) }
        
        return capabilities
    }
}

// MARK: - Provider Configuration Builder

/// Builder for creating provider configurations with a fluent API.
///
/// Use `ProviderConfigurationBuilder` to create configurations using
/// a more readable, chainable syntax.
///
/// ## Example Usage
///
/// ```swift
/// let config = ProviderConfigurationBuilder()
///     .clipboard(UIPasteboardClipboardProvider())
///     .network(URLSessionNetworkProvider())
///     .storage(MyCloudStorageProvider())
///     .build()
/// ```
///
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
public final class ProviderConfigurationBuilder {
    
    private var configuration = ProviderConfiguration()
    
    /// Creates a new configuration builder.
    public init() {}
    
    /// Creates a builder starting from an existing configuration.
    ///
    /// - Parameter base: The base configuration to start from.
    public init(from base: ProviderConfiguration) {
        self.configuration = base
    }
    
    /// Sets the clipboard provider.
    @discardableResult
    public func clipboard(_ provider: any ClipboardProvider) -> Self {
        configuration.clipboard = provider
        return self
    }
    
    /// Sets the timer provider.
    @discardableResult
    public func timer(_ provider: any TimerProvider) -> Self {
        configuration.timer = provider
        return self
    }
    
    /// Sets the network provider.
    @discardableResult
    public func network(_ provider: any NetworkProvider) -> Self {
        configuration.network = provider
        return self
    }
    
    /// Sets the storage provider.
    @discardableResult
    public func storage(_ provider: any StorageProvider) -> Self {
        configuration.storage = provider
        return self
    }
    
    /// Sets the file system provider.
    @discardableResult
    public func fileSystem(_ provider: any FileSystemProvider) -> Self {
        configuration.fileSystem = provider
        return self
    }
    
    /// Sets the geolocation provider.
    @discardableResult
    public func geolocation(_ provider: any GeolocationProvider) -> Self {
        configuration.geolocation = provider
        return self
    }
    
    /// Sets the notification provider.
    @discardableResult
    public func notification(_ provider: any NotificationProvider) -> Self {
        configuration.notification = provider
        return self
    }
    
    /// Sets the UI provider.
    @discardableResult
    public func ui(_ provider: any UIProvider) -> Self {
        configuration.ui = provider
        return self
    }
    
    /// Builds the final configuration.
    public func build() -> ProviderConfiguration {
        return configuration
    }
}

// MARK: - WhatWG Platform

/// Main entry point for the WHATWG Platform Backend.
///
/// `WhatWGPlatform` is the unified interface for embedders to provide platform
/// capabilities to the WHATWG browser engine. It wraps the C ABI and provides
/// a Swift-native API.
///
/// ## Example Usage
///
/// ```swift
/// // Using default configuration
/// let platform = WhatWGPlatform(configuration: .default)
///
/// // Using builder closure
/// let platform = WhatWGPlatform {
///     $0.clipboard = UIPasteboardClipboardProvider()
///     $0.storage = MyCloudStorageProvider()
/// }
///
/// // Create a context
/// let context = try platform.createContext()
/// ```
///
public final class WhatWGPlatform {
    
    // MARK: - Properties
    
    /// The underlying C platform handle.
    internal var handle: OpaquePointer?
    
    /// User context pointer for callbacks.
    internal var userContext: UnsafeMutableRawPointer?
    
    /// The JavaScript engine to use.
    public var engine: JSEngine = .javaScriptCore
    
    /// The provider configuration.
    public private(set) var configuration: ProviderConfiguration
    
    // MARK: - Provider Accessors
    
    /// Clipboard capability provider.
    public var clipboardProvider: (any ClipboardProvider)? {
        get { configuration.clipboard }
        set { configuration.clipboard = newValue }
    }
    
    /// Timer capability provider.
    public var timerProvider: (any TimerProvider)? {
        get { configuration.timer }
        set { configuration.timer = newValue }
    }
    
    /// Network capability provider.
    public var networkProvider: (any NetworkProvider)? {
        get { configuration.network }
        set { configuration.network = newValue }
    }
    
    /// Storage capability provider.
    public var storageProvider: (any StorageProvider)? {
        get { configuration.storage }
        set { configuration.storage = newValue }
    }
    
    /// File system capability provider.
    public var fileSystemProvider: (any FileSystemProvider)? {
        get { configuration.fileSystem }
        set { configuration.fileSystem = newValue }
    }
    
    /// Geolocation capability provider.
    public var geolocationProvider: (any GeolocationProvider)? {
        get { configuration.geolocation }
        set { configuration.geolocation = newValue }
    }
    
    /// Notification capability provider.
    public var notificationProvider: (any NotificationProvider)? {
        get { configuration.notification }
        set { configuration.notification = newValue }
    }
    
    /// UI capability provider.
    public var uiProvider: (any UIProvider)? {
        get { configuration.ui }
        set { configuration.ui = newValue }
    }
    
    // MARK: - Initialization
    
    /// Creates a new WHATWG Platform instance with the specified configuration.
    ///
    /// - Parameter configuration: The provider configuration to use.
    public init(configuration: ProviderConfiguration = .minimal) {
        self.configuration = configuration
    }
    
    /// Creates a new WHATWG Platform instance using a builder closure.
    ///
    /// - Parameter builder: A closure that configures the provider configuration.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let platform = WhatWGPlatform {
    ///     $0.clipboard = UIPasteboardClipboardProvider()
    ///     $0.network = URLSessionNetworkProvider()
    ///     $0.storage = MyCloudStorageProvider()
    /// }
    /// ```
    public init(configure builder: (inout ProviderConfiguration) -> Void) {
        var config = ProviderConfiguration()
        builder(&config)
        self.configuration = config
    }
    
    deinit {
        if let handle = handle {
            whatwg_platform_destroy(handle)
        }
    }
    
    // MARK: - Platform Lifecycle
    
    /// Initializes the platform with configured capabilities.
    ///
    /// - Throws: `WhatWGError` if initialization fails.
    public func initialize() throws {
        guard handle == nil else { return }
        
        guard let newHandle = whatwg_platform_create() else {
            throw WhatWGError.initializationFailed
        }
        
        handle = newHandle
        
        // Configure VTables based on providers
        configureVTables()
    }
    
    /// Creates a new execution context (realm/window).
    ///
    /// - Returns: A new `WhatWGContext` instance.
    /// - Throws: `WhatWGError` if context creation fails.
    public func createContext() throws -> WhatWGContext {
        try initialize()
        return try WhatWGContext(platform: self)
    }
    
    // MARK: - Version Information
    
    /// Returns the library version string.
    public static var version: String {
        guard let cString = whatwg_version_string() else {
            return "unknown"
        }
        return String(cString: cString)
    }
    
    /// Returns the expected ABI version.
    public static var abiVersion: UInt32 {
        whatwg_platform_expected_version()
    }
    
    // MARK: - Capabilities
    
    /// Checks if a capability is available.
    ///
    /// - Parameter capability: The capability to check.
    /// - Returns: `true` if the capability is configured.
    public func hasCapability(_ capability: Capability) -> Bool {
        // Check from configuration first
        if configuration.availableCapabilities.contains(capability) {
            return true
        }
        
        // Fall back to C API if initialized
        guard let handle = handle else { return false }
        return whatwg_platform_has_capability(handle, capability.rawValue)
    }
    
    /// Returns a list of all configured capabilities.
    public var configuredCapabilities: [Capability] {
        Array(configuration.availableCapabilities)
    }
    
    // MARK: - Internal
    
    private func configureVTables() {
        // VTable configuration will be implemented in CInterop.swift
        // This sets up the C function pointers to call Swift providers
    }
}

// MARK: - Errors

/// Errors that can occur when using WhatWGPlatform.
public enum WhatWGError: Error, LocalizedError, Equatable {
    case initializationFailed
    case contextCreationFailed
    case notInitialized
    case capabilityNotAvailable(Capability)
    case operationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize WHATWG Platform"
        case .contextCreationFailed:
            return "Failed to create execution context"
        case .notInitialized:
            return "Platform not initialized"
        case .capabilityNotAvailable(let cap):
            return "Capability not available: \(cap)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        }
    }
}

// MARK: - Capability Enum

/// Platform capabilities that can be provided.
public enum Capability: UInt8, CaseIterable, Sendable, Hashable {
    case clipboard = 0
    case timer = 1
    case network = 2
    case storage = 3
    case layout = 4
    case ui = 5
    case screen = 6
    case notification = 7
    case push = 8
    case share = 9
    case fileSystem = 10
    case geolocation = 11
    case bluetooth = 12
    case usb = 13
    case serial = 14
    case hid = 15
    case nfc = 16
    case deviceOrientation = 17
    case vibration = 18
    case battery = 19
    case wakeLock = 20
    case webRTC = 21
    case media = 22
    case audio = 23
    case speech = 24
    case gamepad = 25
    case sensor = 26
    case credentials = 27
    case webAuthn = 28
    case permissions = 29
    case payment = 30
    
    /// Human-readable display name for the capability.
    public var displayName: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .timer: return "Timer"
        case .network: return "Network"
        case .storage: return "Storage"
        case .layout: return "Layout"
        case .ui: return "UI"
        case .screen: return "Screen"
        case .notification: return "Notification"
        case .push: return "Push"
        case .share: return "Share"
        case .fileSystem: return "File System"
        case .geolocation: return "Geolocation"
        case .bluetooth: return "Bluetooth"
        case .usb: return "USB"
        case .serial: return "Serial"
        case .hid: return "HID"
        case .nfc: return "NFC"
        case .deviceOrientation: return "Device Orientation"
        case .vibration: return "Vibration"
        case .battery: return "Battery"
        case .wakeLock: return "Wake Lock"
        case .webRTC: return "WebRTC"
        case .media: return "Media"
        case .audio: return "Audio"
        case .speech: return "Speech"
        case .gamepad: return "Gamepad"
        case .sensor: return "Sensor"
        case .credentials: return "Credentials"
        case .webAuthn: return "WebAuthn"
        case .permissions: return "Permissions"
        case .payment: return "Payment"
        }
    }
}

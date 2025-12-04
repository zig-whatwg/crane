import Foundation
import CWhatWG

/// Main entry point for the WHATWG Platform Backend.
///
/// `WhatWGPlatform` is the unified interface for embedders to provide platform
/// capabilities to the WHATWG browser engine. It wraps the C ABI and provides
/// a Swift-native API.
///
/// ## Example Usage
///
/// ```swift
/// let platform = WhatWGPlatform()
///
/// // Configure capabilities
/// platform.clipboardProvider = MyClipboardProvider()
/// platform.storageProvider = MyStorageProvider()
///
/// // Create a context
/// let context = try platform.createContext()
///
/// // Use the context...
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
    
    // MARK: - Provider Properties
    
    /// Clipboard capability provider.
    public var clipboardProvider: ClipboardProvider?
    
    /// Timer capability provider.
    public var timerProvider: TimerProvider?
    
    /// Network capability provider.
    public var networkProvider: NetworkProvider?
    
    /// Storage capability provider.
    public var storageProvider: StorageProvider?
    
    /// File system capability provider.
    public var fileSystemProvider: FileSystemProvider?
    
    /// Geolocation capability provider.
    public var geolocationProvider: GeolocationProvider?
    
    /// Notification capability provider.
    public var notificationProvider: NotificationProvider?
    
    /// UI capability provider.
    public var uiProvider: UIProvider?
    
    // MARK: - Initialization
    
    /// Creates a new WHATWG Platform instance.
    public init() {
        // Platform will be created when first needed
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
        guard let handle = handle else { return false }
        return whatwg_platform_has_capability(handle, capability.rawValue)
    }
    
    /// Returns a list of all configured capabilities.
    public var configuredCapabilities: [Capability] {
        Capability.allCases.filter { hasCapability($0) }
    }
    
    // MARK: - Internal
    
    private func configureVTables() {
        // VTable configuration will be implemented in CInterop.swift
        // This sets up the C function pointers to call Swift providers
    }
}

// MARK: - Errors

/// Errors that can occur when using WhatWGPlatform.
public enum WhatWGError: Error, LocalizedError {
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
public enum Capability: UInt8, CaseIterable, Sendable {
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
}

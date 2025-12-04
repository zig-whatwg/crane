# Swift Integration Guide

This guide covers integrating Crane into your iOS or macOS application using Swift.

## Requirements

- iOS 17.0+ / macOS 14.0+ / tvOS 17.0+ / watchOS 10.0+
- Xcode 16.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add Crane to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/bcardarella/crane.git", from: "1.0.0")
]
```

Or in Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/bcardarella/crane.git`
3. Select version and add to your target

## Quick Start

### Basic Browser View

```swift
import SwiftUI
import WhatWG

struct ContentView: View {
    @State var browser = WhatWGBrowser()
    
    var body: some View {
        VStack(spacing: 0) {
            // URL bar
            HStack {
                Button(action: { browser.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!browser.canGoBack)
                
                Button(action: { browser.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!browser.canGoForward)
                
                Button(action: { browser.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                
                TextField("URL", text: $browser.urlString)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { browser.loadURL() }
            }
            .padding()
            
            // Loading indicator
            if browser.isLoading {
                ProgressView(value: browser.loadingProgress)
            }
            
            // Web content
            WhatWGWebView(browser: browser)
        }
    }
}
```

### Platform Initialization

```swift
import WhatWG

// Create platform with default providers
let platform = WhatWGPlatform()

// Or with custom provider configuration
let platform = WhatWGPlatform(providers: ProviderConfiguration(
    clipboard: UIPasteboardClipboardProvider(),
    timer: DispatchTimerProvider(),
    network: URLSessionNetworkProvider(),
    storage: UserDefaultsStorageProvider(),
    fileSystem: UIDocumentPickerFileSystemProvider(),
    geolocation: CoreLocationGeolocationProvider(),
    notification: UserNotificationsNotificationProvider(),
    ui: UIKitUIProvider()
))

// Or using the builder pattern
let platform = WhatWGPlatform { config in
    config
        .storage(MyCloudStorageProvider())
        .network(CachingNetworkProvider())
}

// Initialize the platform
try platform.initialize()

// Create execution context
let context = try platform.createContext()
```

## Provider Configuration

### Built-in Configurations

```swift
// Default - all system providers enabled
let platform = WhatWGPlatform(providers: .default)

// Minimal - only required providers (timer, network, storage)
let platform = WhatWGPlatform(providers: .minimal)

// Network only - for headless/API use cases
let platform = WhatWGPlatform(providers: .networkOnly)
```

### Custom Provider Injection

Swap any provider with your own implementation:

```swift
// Create a custom storage provider
final class MyCloudStorageProvider: StorageProvider, Sendable {
    private let api: CloudStorageAPI
    
    init(apiKey: String) {
        self.api = CloudStorageAPI(key: apiKey)
    }
    
    func getItem(key: String) async throws -> String? {
        try await api.get(key: key)
    }
    
    func setItem(key: String, value: String) async throws {
        try await api.put(key: key, value: value)
    }
    
    func removeItem(key: String) async throws {
        try await api.delete(key: key)
    }
    
    func clear() async throws {
        try await api.clearAll()
    }
    
    func length() async throws -> Int {
        try await api.count()
    }
    
    func key(at index: Int) async throws -> String? {
        try await api.keyAt(index: index)
    }
}

// Use it
let platform = WhatWGPlatform { config in
    config.storage(MyCloudStorageProvider(apiKey: "..."))
}
```

### Available Providers

| Protocol | Description | Default Implementation |
|----------|-------------|------------------------|
| `ClipboardProvider` | System clipboard access | `UIPasteboardClipboardProvider` |
| `TimerProvider` | High-resolution timers | `DispatchTimerProvider` |
| `NetworkProvider` | HTTP networking | `URLSessionNetworkProvider` |
| `StorageProvider` | Key-value storage | `UserDefaultsStorageProvider` |
| `GeolocationProvider` | Location services | `CoreLocationGeolocationProvider` |
| `NotificationProvider` | Push/local notifications | `UserNotificationsNotificationProvider` |
| `UIProvider` | Alerts, prompts, dialogs | `UIKitUIProvider` / `AppKitUIProvider` |
| `FileSystemProvider` | OPFS-like file access | `UIDocumentPickerFileSystemProvider` |

### macOS Providers

On macOS, use the AppKit-based providers:

| Protocol | macOS Implementation |
|----------|---------------------|
| `ClipboardProvider` | `NSPasteboardClipboardProvider` |
| `UIProvider` | `AppKitUIProvider` |

## Browser Component

### WhatWGBrowser

The `WhatWGBrowser` class uses the `@Observable` macro for SwiftUI integration:

```swift
@MainActor
@Observable
public final class WhatWGBrowser {
    // Observable state
    var urlString: String
    private(set) var title: String
    private(set) var isLoading: Bool
    private(set) var loadingProgress: Double
    private(set) var canGoBack: Bool
    private(set) var canGoForward: Bool
    private(set) var isSecure: Bool
    private(set) var tabs: [BrowserTab]
    var activeTabIndex: Int
    
    // Navigation
    func loadURL()
    func loadURL(_ url: URL)
    func goBack()
    func goForward()
    func reload()
    func stopLoading()
    
    // Tab management
    func newTab(makeActive: Bool = true) -> UUID
    func closeTab(_ id: UUID)
    func switchToTab(_ id: UUID)
    
    // JavaScript
    func evaluateJavaScript(_ script: String) async throws -> Any?
    
    // Event callbacks
    var onNavigationEvent: ((NavigationEvent) -> Void)?
    var onConsoleMessage: ((ConsoleMessage) -> Void)?
    var onTapEvent: ((CGPoint) -> Void)?
    var onScrollEvent: ((CGSize) -> Void)?
}
```

### WhatWGWebView

The `WhatWGWebView` is a native SwiftUI view using Canvas-based rendering:

```swift
// Basic usage
WhatWGWebView(browser: browser)

// With configuration
WhatWGWebView(browser: browser, configuration: .reader)

// With modifiers
WhatWGWebView(browser: browser)
    .javaScriptEnabled(true)
    .allowsZooming(true)
    .allowsBackForwardGestures(true)
    .userAgent("MyApp/1.0")
```

### Gesture Handling

WhatWGWebView supports native SwiftUI gestures:

- **Tap**: `SpatialTapGesture` for link clicks and interactions
- **Scroll**: `DragGesture` with momentum for content scrolling
- **Zoom**: `MagnificationGesture` for pinch-to-zoom
- **Keyboard**: `onKeyPress` for keyboard navigation

### Configuration Options

```swift
// Standard (default)
WhatWGWebView.Configuration.standard

// Minimal (JS disabled)
WhatWGWebView.Configuration.minimal

// Reader mode
WhatWGWebView.Configuration.reader

// Custom
let config = WhatWGWebView.Configuration(
    javaScriptEnabled: true,
    allowsInlineMediaPlayback: true,
    mediaAutoplayPolicy: .userGesture,
    backgroundColor: .white,
    showsScrollIndicator: true,
    allowsZooming: true,
    minimumZoomScale: 1.0,
    maximumZoomScale: 4.0,
    allowsBackForwardNavigationGestures: true,
    customUserAgent: nil
)
```

## Navigation Events

Subscribe to navigation events:

```swift
browser.onNavigationEvent = { event in
    switch event {
    case .started(let url):
        print("Started loading: \(url)")
    case .finished(let url):
        print("Finished loading: \(url)")
    case .failed(let error):
        print("Failed: \(error)")
    case .goingBack:
        print("Navigating back")
    case .goingForward:
        print("Navigating forward")
    case .reloading:
        print("Reloading")
    case .stopped:
        print("Loading stopped")
    }
}
```

## Console Messages

Receive JavaScript console messages:

```swift
browser.onConsoleMessage = { message in
    switch message.level {
    case .log:
        print("[LOG] \(message.text)")
    case .warn:
        print("[WARN] \(message.text)")
    case .error:
        print("[ERROR] \(message.text)")
    case .info:
        print("[INFO] \(message.text)")
    case .debug:
        print("[DEBUG] \(message.text)")
    }
}
```

## Error Handling

```swift
do {
    try platform.initialize()
} catch let error as BrowserError {
    switch error {
    case .invalidURL(let url):
        print("Invalid URL: \(url)")
    case .networkError(let message, let code):
        print("Network error \(code ?? 0): \(message)")
    case .scriptError(let message, let line, let column):
        print("Script error at \(line ?? 0):\(column ?? 0): \(message)")
    case .timeout:
        print("Request timed out")
    case .cancelled:
        print("Request was cancelled")
    default:
        print("Unknown error: \(error)")
    }
}
```

## Memory Management

Crane follows Swift's standard memory management patterns:

```swift
// Browser is automatically cleaned up when view is dismissed
struct BrowserView: View {
    @State var browser = WhatWGBrowser()
    // browser is automatically cleaned up when view is removed
}

// Manual cleanup if needed
class ViewController: UIViewController {
    var browser: WhatWGBrowser?
    
    deinit {
        browser = nil // Triggers cleanup
    }
}
```

## Thread Safety

All browser operations should be performed on the main thread:

```swift
// Correct - using @MainActor
@MainActor
func loadWebPage() async {
    browser.loadURL(URL(string: "https://example.com")!)
}

// Correct - using Task with MainActor
Task { @MainActor in
    browser.loadURL(URL(string: "https://example.com")!)
}
```

## Migration from Previous Versions

If you're upgrading from a version using `ObservableObject`:

### Before (ObservableObject)
```swift
import Combine

@StateObject var browser = WhatWGBrowser()
```

### After (@Observable)
```swift
@State var browser = WhatWGBrowser()
```

### Provider Name Changes

| Old Name | New Name |
|----------|----------|
| `iOSClipboardProvider` | `UIPasteboardClipboardProvider` |
| `iOSTimerProvider` | `DispatchTimerProvider` |
| `iOSNetworkProvider` | `URLSessionNetworkProvider` |
| `iOSStorageProvider` | `UserDefaultsStorageProvider` |
| `iOSFileSystemProvider` | `UIDocumentPickerFileSystemProvider` |
| `iOSGeolocationProvider` | `CoreLocationGeolocationProvider` |
| `iOSNotificationProvider` | `UserNotificationsNotificationProvider` |
| `iOSUIProvider` | `UIKitUIProvider` |
| `macOSUIProvider` | `AppKitUIProvider` |

Deprecated typealiases are provided for backwards compatibility.

## Troubleshooting

### Common Issues

**Build error: "header not found"**
- Ensure the Zig library is built first: `zig build -Doptimize=ReleaseFast`

**JavaScript not executing**
- Check that `javaScriptEnabled` is true in configuration

**Network requests failing**
- Add App Transport Security exceptions to Info.plist if needed
- Check that `NetworkProvider` is configured

**Geolocation not working**
- Add `NSLocationWhenInUseUsageDescription` to Info.plist
- Request permissions before using geolocation

### Debug Logging

Enable debug logging:

```swift
#if DEBUG
browser.onConsoleMessage = { message in
    print("[\(message.level)] \(message.text)")
}
#endif
```

## Best Practices

1. **Use @State for browser instances** - Ensures proper lifecycle management with @Observable
2. **Handle errors gracefully** - Always wrap operations in do/catch
3. **Request permissions early** - For geolocation, notifications, etc.
4. **Configure providers at startup** - Use ProviderConfiguration before creating contexts
5. **Test on real devices** - Some features behave differently in simulator
6. **Use builder pattern for customization** - Cleaner than manual provider assignment

## Example Project

See `bindings/swift/Examples/WhatWGBrowserApp/` for a complete example iOS/macOS browser application.

## API Reference

For complete API documentation, see:
- [WhatWGPlatform](api/WhatWGPlatform.md)
- [WhatWGBrowser](api/WhatWGBrowser.md)
- [WhatWGWebView](api/WhatWGWebView.md)
- [Provider Protocols](api/Providers.md)
- [ProviderConfiguration](api/ProviderConfiguration.md)

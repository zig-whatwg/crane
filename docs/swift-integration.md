# Swift Integration Guide

This guide covers integrating Crane into your iOS or macOS application using Swift.

## Requirements

- iOS 14.0+ or macOS 11.0+
- Xcode 15.0+
- Swift 5.9+

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
    @StateObject var browser = WhatWGBrowser()
    
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

// Create platform with default iOS providers
let platform = WhatWGPlatform()

// Use default iOS implementations
platform.clipboardProvider = iOSClipboardProvider()
platform.timerProvider = iOSTimerProvider()
platform.networkProvider = iOSNetworkProvider()
platform.storageProvider = iOSStorageProvider()
platform.geolocationProvider = iOSGeolocationProvider()
platform.notificationProvider = iOSNotificationProvider()
platform.uiProvider = iOSUIProvider()
platform.fileSystemProvider = iOSFileSystemProvider()

// Initialize the platform
try platform.initialize()

// Create execution context
let context = try platform.createContext()
```

## Capability Providers

### Implementing Custom Providers

You can implement custom capability providers by conforming to the provider protocols:

```swift
import WhatWG

class MyClipboardProvider: ClipboardProvider {
    func readText() async throws -> String? {
        // Your implementation
        return UIPasteboard.general.string
    }
    
    func writeText(_ text: String) async throws {
        UIPasteboard.general.string = text
    }
    
    func readHTML() async throws -> String? {
        // Return nil if not supported
        return nil
    }
    
    func writeHTML(_ html: String) async throws {
        // No-op if not supported
    }
}
```

### Available Providers

| Protocol | Description | iOS Default |
|----------|-------------|-------------|
| `ClipboardProvider` | System clipboard access | `iOSClipboardProvider` |
| `TimerProvider` | High-resolution timers | `iOSTimerProvider` |
| `NetworkProvider` | HTTP networking | `iOSNetworkProvider` |
| `StorageProvider` | Key-value and file storage | `iOSStorageProvider` |
| `GeolocationProvider` | Location services | `iOSGeolocationProvider` |
| `NotificationProvider` | Push/local notifications | `iOSNotificationProvider` |
| `UIProvider` | Alerts, prompts, file pickers | `iOSUIProvider` |
| `FileSystemProvider` | OPFS-like file access | `iOSFileSystemProvider` |

## Browser Component

### WhatWGBrowser

The `WhatWGBrowser` class is an `ObservableObject` that manages browser state:

```swift
@MainActor
public final class WhatWGBrowser: ObservableObject {
    // Published state
    @Published var urlString: String
    @Published private(set) var title: String
    @Published private(set) var isLoading: Bool
    @Published private(set) var loadingProgress: Double
    @Published private(set) var canGoBack: Bool
    @Published private(set) var canGoForward: Bool
    @Published private(set) var isSecure: Bool
    @Published private(set) var tabs: [BrowserTab]
    @Published var activeTabIndex: Int
    
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
}
```

### WhatWGWebView

The `WhatWGWebView` is a SwiftUI view that displays web content:

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
    @StateObject var browser = WhatWGBrowser()
    // browser.deinit() is called automatically
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

1. **Use StateObject for browser instances** - Ensures proper lifecycle management
2. **Handle errors gracefully** - Always wrap operations in do/catch
3. **Request permissions early** - For geolocation, notifications, etc.
4. **Configure providers at startup** - Before creating contexts
5. **Test on real devices** - Some features behave differently in simulator

## Example Project

See `bindings/swift/Examples/WhatWGBrowserApp/` for a complete example iOS/macOS browser application.

## API Reference

For complete API documentation, see:
- [WhatWGPlatform](api/WhatWGPlatform.md)
- [WhatWGBrowser](api/WhatWGBrowser.md)
- [WhatWGWebView](api/WhatWGWebView.md)
- [Provider Protocols](api/Providers.md)

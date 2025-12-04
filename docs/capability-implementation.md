# Capability Implementation Guide

This guide explains how to implement platform capabilities (clipboard, network, storage, etc.) for the Crane browser engine.

## Architecture Overview

Crane uses a **VTable-based capability system** that allows embedders to provide platform-specific implementations:

```
┌─────────────────────────────────────────────────────────────┐
│                    WHATWG Specifications                     │
│                  (URL, Fetch, DOM, etc.)                    │
├─────────────────────────────────────────────────────────────┤
│                   PlatformBackend (Zig)                      │
│  ┌─────────────┬─────────────┬─────────────┬─────────────┐  │
│  │ ClipboardVT │ NetworkVT   │ StorageVT   │ TimerVT     │  │
│  └─────────────┴─────────────┴─────────────┴─────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                  C ABI (extern struct)                       │
├─────────────────────────────────────────────────────────────┤
│  Swift Protocol  │  Kotlin Interface  │  C/C++ Functions    │
└─────────────────────────────────────────────────────────────┘
```

## VTable Structure

Each capability is defined as a VTable (virtual function table) - a struct of function pointers:

### Zig Definition

```zig
// src/platform/vtables/clipboard.zig
pub const ClipboardVTable = extern struct {
    // Context pointer passed to all functions
    context: ?*anyopaque,
    
    // Read text from clipboard
    read_text: *const fn (
        context: ?*anyopaque,
        callback: *const fn (text: ?[*:0]const u8, user_data: ?*anyopaque) callconv(.C) void,
        user_data: ?*anyopaque,
    ) callconv(.C) void,
    
    // Write text to clipboard
    write_text: *const fn (
        context: ?*anyopaque,
        text: [*:0]const u8,
        callback: *const fn (success: bool, user_data: ?*anyopaque) callconv(.C) void,
        user_data: ?*anyopaque,
    ) callconv(.C) void,
    
    // Read HTML from clipboard
    read_html: *const fn (
        context: ?*anyopaque,
        callback: *const fn (html: ?[*:0]const u8, user_data: ?*anyopaque) callconv(.C) void,
        user_data: ?*anyopaque,
    ) callconv(.C) void,
    
    // Write HTML to clipboard
    write_html: *const fn (
        context: ?*anyopaque,
        html: [*:0]const u8,
        callback: *const fn (success: bool, user_data: ?*anyopaque) callconv(.C) void,
        user_data: ?*anyopaque,
    ) callconv(.C) void,
};
```

### C Header

```c
// include/whatwg_backend.h
typedef struct WhatWGClipboardVTable {
    void* context;
    
    void (*read_text)(
        void* context,
        void (*callback)(const char* text, void* user_data),
        void* user_data
    );
    
    void (*write_text)(
        void* context,
        const char* text,
        void (*callback)(bool success, void* user_data),
        void* user_data
    );
    
    void (*read_html)(
        void* context,
        void (*callback)(const char* html, void* user_data),
        void* user_data
    );
    
    void (*write_html)(
        void* context,
        const char* html,
        void (*callback)(bool success, void* user_data),
        void* user_data
    );
} WhatWGClipboardVTable;
```

## Implementing in Swift

### Protocol Definition

```swift
// bindings/swift/Sources/WhatWG/Providers/ClipboardProvider.swift
public protocol ClipboardProvider {
    func readText() async throws -> String?
    func writeText(_ text: String) async throws
    func readHTML() async throws -> String?
    func writeHTML(_ html: String) async throws
}
```

### iOS Implementation

```swift
// bindings/swift/Sources/WhatWG/iOS/iOSClipboardProvider.swift
import UIKit

public final class iOSClipboardProvider: ClipboardProvider {
    public init() {}
    
    public func readText() async throws -> String? {
        return await MainActor.run {
            UIPasteboard.general.string
        }
    }
    
    public func writeText(_ text: String) async throws {
        await MainActor.run {
            UIPasteboard.general.string = text
        }
    }
    
    public func readHTML() async throws -> String? {
        return await MainActor.run {
            if let data = UIPasteboard.general.data(forPasteboardType: "public.html"),
               let html = String(data: data, encoding: .utf8) {
                return html
            }
            return nil
        }
    }
    
    public func writeHTML(_ html: String) async throws {
        await MainActor.run {
            if let data = html.data(using: .utf8) {
                UIPasteboard.general.setData(data, forPasteboardType: "public.html")
            }
        }
    }
}
```

### VTable Bridge

```swift
// bindings/swift/Sources/WhatWG/Internal/ClipboardBridge.swift
import Foundation

internal final class ClipboardBridge {
    private let provider: ClipboardProvider
    
    init(provider: ClipboardProvider) {
        self.provider = provider
    }
    
    func createVTable() -> WhatWGClipboardVTable {
        var vtable = WhatWGClipboardVTable()
        vtable.context = Unmanaged.passRetained(self).toOpaque()
        vtable.read_text = { context, callback, userData in
            guard let bridge = Unmanaged<ClipboardBridge>
                .fromOpaque(context!)
                .takeUnretainedValue() as ClipboardBridge? else { return }
            
            Task {
                let text = try? await bridge.provider.readText()
                callback?(text?.withCString { $0 }, userData)
            }
        }
        vtable.write_text = { context, text, callback, userData in
            guard let bridge = Unmanaged<ClipboardBridge>
                .fromOpaque(context!)
                .takeUnretainedValue() as ClipboardBridge? else { return }
            
            Task {
                do {
                    try await bridge.provider.writeText(String(cString: text!))
                    callback?(true, userData)
                } catch {
                    callback?(false, userData)
                }
            }
        }
        // ... similar for read_html and write_html
        return vtable
    }
}
```

## Implementing in Kotlin

### Interface Definition

```kotlin
// bindings/kotlin/whatwg/src/main/kotlin/com/whatwg/providers/ClipboardProvider.kt
interface ClipboardProvider {
    suspend fun readText(): String?
    suspend fun writeText(text: String)
    suspend fun readHTML(): String?
    suspend fun writeHTML(html: String)
}
```

### Android Implementation

```kotlin
// bindings/kotlin/whatwg/src/main/kotlin/com/whatwg/android/AndroidClipboardProvider.kt
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AndroidClipboardProvider(
    private val context: Context
) : ClipboardProvider {
    
    private val clipboardManager: ClipboardManager by lazy {
        context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    }
    
    override suspend fun readText(): String? = withContext(Dispatchers.Main) {
        clipboardManager.primaryClip
            ?.getItemAt(0)
            ?.text
            ?.toString()
    }
    
    override suspend fun writeText(text: String) = withContext(Dispatchers.Main) {
        val clip = ClipData.newPlainText("text", text)
        clipboardManager.setPrimaryClip(clip)
    }
    
    override suspend fun readHTML(): String? = withContext(Dispatchers.Main) {
        clipboardManager.primaryClip
            ?.getItemAt(0)
            ?.htmlText
    }
    
    override suspend fun writeHTML(html: String) = withContext(Dispatchers.Main) {
        val clip = ClipData.newHtmlText("html", html, html)
        clipboardManager.setPrimaryClip(clip)
    }
}
```

### JNI Bridge

```cpp
// bindings/kotlin/whatwg/src/main/cpp/clipboard_bridge.cpp
#include <jni.h>
#include "whatwg_backend.h"

static JavaVM* g_jvm = nullptr;
static jclass g_providerClass = nullptr;
static jmethodID g_readTextMethod = nullptr;

extern "C" JNIEXPORT void JNICALL
Java_com_whatwg_internal_JNIBridge_nativeSetClipboardProvider(
    JNIEnv* env,
    jclass clazz,
    jlong platformHandle,
    jobject provider
) {
    env->GetJavaVM(&g_jvm);
    g_providerClass = (jclass)env->NewGlobalRef(env->GetObjectClass(provider));
    g_readTextMethod = env->GetMethodID(g_providerClass, "readText", "()Ljava/lang/String;");
    
    auto* platform = reinterpret_cast<WhatWGPlatformBackend*>(platformHandle);
    
    static WhatWGClipboardVTable vtable = {
        .context = env->NewGlobalRef(provider),
        .read_text = [](void* context, auto callback, void* userData) {
            JNIEnv* env;
            g_jvm->AttachCurrentThread(&env, nullptr);
            
            auto provider = static_cast<jobject>(context);
            auto result = (jstring)env->CallObjectMethod(provider, g_readTextMethod);
            
            if (result) {
                const char* text = env->GetStringUTFChars(result, nullptr);
                callback(text, userData);
                env->ReleaseStringUTFChars(result, text);
            } else {
                callback(nullptr, userData);
            }
        },
        // ... other methods
    };
    
    platform->clipboard = &vtable;
}
```

## Implementing in C/C++

### Direct Implementation

```c
// my_clipboard.c
#include "whatwg_backend.h"
#include <stdlib.h>
#include <string.h>

typedef struct {
    char* current_text;
    char* current_html;
} MyClipboardContext;

static void my_read_text(
    void* context,
    void (*callback)(const char* text, void* user_data),
    void* user_data
) {
    MyClipboardContext* ctx = (MyClipboardContext*)context;
    callback(ctx->current_text, user_data);
}

static void my_write_text(
    void* context,
    const char* text,
    void (*callback)(bool success, void* user_data),
    void* user_data
) {
    MyClipboardContext* ctx = (MyClipboardContext*)context;
    free(ctx->current_text);
    ctx->current_text = strdup(text);
    callback(true, user_data);
}

WhatWGClipboardVTable* create_my_clipboard() {
    MyClipboardContext* ctx = malloc(sizeof(MyClipboardContext));
    ctx->current_text = NULL;
    ctx->current_html = NULL;
    
    WhatWGClipboardVTable* vtable = malloc(sizeof(WhatWGClipboardVTable));
    vtable->context = ctx;
    vtable->read_text = my_read_text;
    vtable->write_text = my_write_text;
    vtable->read_html = my_read_html;
    vtable->write_html = my_write_html;
    
    return vtable;
}
```

## Available Capabilities

| Capability | VTable | Description |
|------------|--------|-------------|
| **Clipboard** | `ClipboardVTable` | Read/write text and HTML |
| **Timer** | `TimerVTable` | setTimeout, setInterval, requestAnimationFrame |
| **Network** | `NetworkVTable` | HTTP/HTTPS requests, WebSocket |
| **Storage** | `StorageVTable` | localStorage, sessionStorage, IndexedDB |
| **FileSystem** | `FileSystemVTable` | OPFS-like file access |
| **Geolocation** | `GeolocationVTable` | GPS/location services |
| **Notification** | `NotificationVTable` | Push and local notifications |
| **UI** | `UIVTable` | Alerts, confirms, prompts, file pickers |
| **Screen** | `ScreenVTable` | Screen dimensions, orientation |
| **Vibration** | `VibrationVTable` | Haptic feedback |
| **Battery** | `BatteryVTable` | Battery status |
| **Bluetooth** | `BluetoothVTable` | Web Bluetooth API |
| **USB** | `USBVTable` | WebUSB API |
| **Serial** | `SerialVTable` | Web Serial API |
| **Media** | `MediaVTable` | Media playback, capture |

## Thread Safety

**Critical**: All VTable callbacks are invoked from the engine's event loop thread. Your implementation must handle thread synchronization:

### Swift
```swift
// Use @MainActor for UI operations
@MainActor
func readText() async throws -> String? {
    return UIPasteboard.general.string
}

// Or dispatch explicitly
func readText() async throws -> String? {
    return await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            continuation.resume(returning: UIPasteboard.general.string)
        }
    }
}
```

### Kotlin
```kotlin
// Use Dispatchers.Main for UI operations
override suspend fun readText(): String? = withContext(Dispatchers.Main) {
    clipboardManager.primaryClip?.getItemAt(0)?.text?.toString()
}
```

### C/C++
```c
// Use platform-specific synchronization
#include <pthread.h>

static pthread_mutex_t clipboard_mutex = PTHREAD_MUTEX_INITIALIZER;

static void my_read_text(void* context, ...) {
    pthread_mutex_lock(&clipboard_mutex);
    // Access shared state
    pthread_mutex_unlock(&clipboard_mutex);
}
```

## Error Handling

Errors should be communicated through callback parameters or by returning null/empty values:

```swift
// Swift - use async throws
func readText() async throws -> String? {
    guard hasPermission else {
        throw ClipboardError.permissionDenied
    }
    return UIPasteboard.general.string
}
```

```kotlin
// Kotlin - use suspending functions with exceptions
override suspend fun readText(): String? {
    if (!hasPermission) {
        throw SecurityException("Clipboard access denied")
    }
    return clipboardManager.primaryClip?.getItemAt(0)?.text?.toString()
}
```

## Testing

### Stub Implementation

For testing, use the provided stub implementations:

```zig
// src/platform/stubs/clipboard_stub.zig
pub const ClipboardStub = struct {
    text: ?[]const u8 = null,
    html: ?[]const u8 = null,
    
    pub fn createVTable(self: *ClipboardStub) ClipboardVTable {
        return .{
            .context = self,
            .read_text = readText,
            .write_text = writeText,
            .read_html = readHtml,
            .write_html = writeHtml,
        };
    }
    
    fn readText(context: ?*anyopaque, callback: ..., user_data: ?*anyopaque) callconv(.C) void {
        const self = @ptrCast(*ClipboardStub, @alignCast(@alignOf(ClipboardStub), context));
        if (self.text) |text| {
            callback(text.ptr, user_data);
        } else {
            callback(null, user_data);
        }
    }
    // ...
};
```

### Unit Testing

```swift
// Swift test
class MockClipboardProvider: ClipboardProvider {
    var storedText: String?
    
    func readText() async throws -> String? {
        return storedText
    }
    
    func writeText(_ text: String) async throws {
        storedText = text
    }
    // ...
}

func testClipboardRoundtrip() async throws {
    let provider = MockClipboardProvider()
    try await provider.writeText("Hello")
    let text = try await provider.readText()
    XCTAssertEqual(text, "Hello")
}
```

## Best Practices

1. **Keep VTable callbacks lightweight** - Offload heavy work to background threads
2. **Handle null contexts** - Always check if context is valid
3. **Free resources properly** - Implement cleanup when platform is destroyed
4. **Use async patterns** - Don't block the callback thread
5. **Log errors** - Use platform logging for debugging
6. **Test with stubs** - Use stub implementations for unit testing
7. **Document permissions** - List required permissions for each capability

## See Also

- [Swift Integration Guide](swift-integration.md)
- [Kotlin Integration Guide](kotlin-integration.md)
- [Engine Selection Guide](engine-selection.md)
- [VTable Reference](api/vtables.md)

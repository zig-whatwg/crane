# Kotlin/Android Integration Guide

This guide covers integrating Crane into your Android application using Kotlin.

## Requirements

- Android API 24+ (Android 7.0 Nougat)
- Kotlin 1.9+
- Android Studio Hedgehog or later
- Gradle 8.0+

## Installation

### Gradle

Add the repository and dependency to your `build.gradle.kts`:

```kotlin
repositories {
    mavenCentral()
}

dependencies {
    implementation("com.whatwg:whatwg:1.0.0")
}
```

### NDK Setup

Crane requires the NDK for native library loading. Add to your `build.gradle.kts`:

```kotlin
android {
    ndkVersion = "25.1.8937393"
    
    defaultConfig {
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64", "x86")
        }
    }
}
```

## Quick Start

### Basic Browser Composable

```kotlin
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import com.whatwg.compose.*

@Composable
fun BrowserScreen() {
    val browser = rememberWhatWGBrowser()
    
    Column {
        // URL bar
        Row(
            modifier = Modifier.padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            IconButton(
                onClick = { browser.goBack() },
                enabled = browser.canGoBack
            ) {
                Icon(Icons.Default.ArrowBack, "Back")
            }
            
            IconButton(
                onClick = { browser.goForward() },
                enabled = browser.canGoForward
            ) {
                Icon(Icons.Default.ArrowForward, "Forward")
            }
            
            IconButton(onClick = { browser.reload() }) {
                Icon(Icons.Default.Refresh, "Reload")
            }
            
            OutlinedTextField(
                value = browser.urlString,
                onValueChange = { browser.urlString = it },
                modifier = Modifier.weight(1f),
                singleLine = true,
                keyboardActions = KeyboardActions(
                    onDone = { browser.loadUrl() }
                )
            )
        }
        
        // Loading indicator
        if (browser.isLoading) {
            LinearProgressIndicator(
                progress = { browser.loadingProgress },
                modifier = Modifier.fillMaxWidth()
            )
        }
        
        // Web content
        WhatWGWebView(
            browser = browser,
            modifier = Modifier.weight(1f)
        )
    }
}
```

### Platform Initialization

```kotlin
import android.content.Context
import com.whatwg.*
import com.whatwg.android.*

class MyApplication : Application() {
    lateinit var platform: WhatWGPlatform
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize platform with Android providers
        platform = WhatWGPlatform().apply {
            clipboardProvider = AndroidClipboardProvider(this@MyApplication)
            timerProvider = AndroidTimerProvider()
            networkProvider = AndroidNetworkProvider()
            storageProvider = AndroidStorageProvider(this@MyApplication)
            geolocationProvider = AndroidGeolocationProvider(this@MyApplication)
            notificationProvider = AndroidNotificationProvider(this@MyApplication)
            uiProvider = AndroidUIProvider()
            fileSystemProvider = AndroidFileSystemProvider(this@MyApplication)
        }
        
        platform.initialize()
    }
}
```

## Capability Providers

### Implementing Custom Providers

Implement custom capability providers by implementing the provider interfaces:

```kotlin
import com.whatwg.providers.*

class MyClipboardProvider(
    private val context: Context
) : ClipboardProvider {
    
    private val clipboardManager = context.getSystemService(
        Context.CLIPBOARD_SERVICE
    ) as ClipboardManager
    
    override suspend fun readText(): String? {
        return clipboardManager.primaryClip
            ?.getItemAt(0)
            ?.text
            ?.toString()
    }
    
    override suspend fun writeText(text: String) {
        val clip = ClipData.newPlainText("text", text)
        clipboardManager.setPrimaryClip(clip)
    }
    
    override suspend fun readHTML(): String? {
        return clipboardManager.primaryClip
            ?.getItemAt(0)
            ?.htmlText
    }
    
    override suspend fun writeHTML(html: String) {
        val clip = ClipData.newHtmlText("html", html, html)
        clipboardManager.setPrimaryClip(clip)
    }
}
```

### Available Providers

| Interface | Description | Android Default |
|-----------|-------------|-----------------|
| `ClipboardProvider` | System clipboard | `AndroidClipboardProvider` |
| `TimerProvider` | High-resolution timers | `AndroidTimerProvider` |
| `NetworkProvider` | HTTP networking | `AndroidNetworkProvider` |
| `StorageProvider` | SharedPreferences + File | `AndroidStorageProvider` |
| `GeolocationProvider` | Location services | `AndroidGeolocationProvider` |
| `NotificationProvider` | Notifications | `AndroidNotificationProvider` |
| `UIProvider` | Dialogs, pickers | `AndroidUIProvider` |
| `FileSystemProvider` | OPFS-like file access | `AndroidFileSystemProvider` |

## Browser Component

### WhatWGBrowser

The `WhatWGBrowser` class manages browser state with Compose-compatible state:

```kotlin
@Stable
class WhatWGBrowser {
    // Observable state
    var urlString: String by mutableStateOf("")
    val navigationState: NavigationState by derivedStateOf { ... }
    val tabs: List<BrowserTab>
    var activeTabIndex: Int
    var lastError: BrowserError? by mutableStateOf(null)
    
    // Derived state
    val title: String
    val isLoading: Boolean
    val loadingProgress: Float
    val canGoBack: Boolean
    val canGoForward: Boolean
    val isSecure: Boolean
    val activeTab: BrowserTab?
    
    // Events
    val navigationEvents: SharedFlow<NavigationEvent>
    val consoleMessages: SharedFlow<ConsoleMessage>
    
    // Navigation
    fun loadUrl()
    fun loadUrl(url: URL, options: NavigationOptions = NavigationOptions.Default)
    fun loadUrl(urlString: String)
    fun goBack()
    fun goForward()
    fun reload(bypassCache: Boolean = false)
    fun stopLoading()
    
    // Tab management
    fun newTab(makeActive: Boolean = true): UUID
    fun closeTab(id: UUID)
    fun switchToTab(id: UUID)
    fun switchToTab(index: Int)
    
    // JavaScript
    suspend fun evaluateJavaScript(script: String): JavaScriptResult
}
```

### WhatWGWebView

The `WhatWGWebView` composable displays web content:

```kotlin
// Basic usage
WhatWGWebView(browser = browser)

// With modifier
WhatWGWebView(
    browser = browser,
    modifier = Modifier.fillMaxSize()
)

// With configuration
WhatWGWebView(
    browser = browser,
    configuration = WebViewConfiguration.Reader
)
```

### Configuration Options

```kotlin
// Standard (default)
WebViewConfiguration.Default

// Minimal (JS disabled)
WebViewConfiguration.Minimal

// Reader mode
WebViewConfiguration.Reader

// Kiosk mode
WebViewConfiguration.Kiosk

// Custom
val config = WebViewConfiguration(
    javaScriptEnabled = true,
    allowsZooming = true,
    minimumZoomScale = 1f,
    maximumZoomScale = 4f,
    allowsBackForwardNavigationGestures = true,
    backgroundColor = Color.WHITE,
    customUserAgent = null,
    domStorageEnabled = true,
    databaseEnabled = true,
    allowFileAccess = false,
    mediaPlaybackPolicy = MediaPlaybackPolicy.USER_GESTURE_REQUIRED
)
```

## Navigation Events

Collect navigation events using Kotlin flows:

```kotlin
@Composable
fun BrowserWithEvents() {
    val browser = rememberWhatWGBrowser()
    
    LaunchedEffect(browser) {
        browser.navigationEvents.collect { event ->
            when (event) {
                is NavigationEvent.Started -> {
                    Log.d("Browser", "Started: ${event.url}")
                }
                is NavigationEvent.Finished -> {
                    Log.d("Browser", "Finished: ${event.url}")
                }
                is NavigationEvent.Failed -> {
                    Log.e("Browser", "Failed: ${event.error}")
                }
                is NavigationEvent.GoingBack -> {
                    Log.d("Browser", "Going back")
                }
                is NavigationEvent.GoingForward -> {
                    Log.d("Browser", "Going forward")
                }
                is NavigationEvent.Reloading -> {
                    Log.d("Browser", "Reloading")
                }
                is NavigationEvent.Stopped -> {
                    Log.d("Browser", "Stopped")
                }
                is NavigationEvent.Redirected -> {
                    Log.d("Browser", "Redirected: ${event.from} -> ${event.to}")
                }
            }
        }
    }
    
    WhatWGWebView(browser = browser)
}
```

## Console Messages

```kotlin
LaunchedEffect(browser) {
    browser.consoleMessages.collect { message ->
        when (message.level) {
            ConsoleMessage.Level.LOG -> Log.d("JS", message.text)
            ConsoleMessage.Level.INFO -> Log.i("JS", message.text)
            ConsoleMessage.Level.WARN -> Log.w("JS", message.text)
            ConsoleMessage.Level.ERROR -> Log.e("JS", message.text)
            ConsoleMessage.Level.DEBUG -> Log.v("JS", message.text)
        }
    }
}
```

## Error Handling

```kotlin
when (val error = browser.lastError) {
    is BrowserError.InvalidUrl -> {
        showSnackbar("Invalid URL: ${error.url}")
    }
    is BrowserError.NetworkError -> {
        showSnackbar("Network error: ${error.message}")
    }
    is BrowserError.ScriptError -> {
        Log.e("JS", "Script error at ${error.line}:${error.column}: ${error.message}")
    }
    is BrowserError.Timeout -> {
        showSnackbar("Request timed out")
    }
    is BrowserError.Cancelled -> {
        // User cancelled, no action needed
    }
    is BrowserError.EngineUnavailable -> {
        showSnackbar("Browser engine not available")
    }
    is BrowserError.Unknown -> {
        Log.e("Browser", "Unknown error", error.cause)
    }
    null -> { /* No error */ }
}
```

## Coroutines

Crane uses Kotlin coroutines for async operations:

```kotlin
// JavaScript execution
lifecycleScope.launch {
    when (val result = browser.evaluateJavaScript("document.title")) {
        is JavaScriptResult.Success -> {
            Log.d("JS", "Result: ${result.value}")
        }
        is JavaScriptResult.Error -> {
            Log.e("JS", "Error: ${result.error.message}")
        }
    }
}

// With timeout
withTimeout(5000) {
    browser.evaluateJavaScript("fetch('/api/data').then(r => r.json())")
}
```

## Permissions

Request necessary permissions for capabilities:

```kotlin
// Geolocation
val locationPermission = rememberLauncherForActivityResult(
    ActivityResultContracts.RequestMultiplePermissions()
) { permissions ->
    val granted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                  permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true
    if (granted) {
        // Enable geolocation
    }
}

// In AndroidManifest.xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## ProGuard Rules

Add to `proguard-rules.pro`:

```proguard
# Keep WhatWG native methods
-keepclasseswithmembernames class com.whatwg.** {
    native <methods>;
}

# Keep callback interfaces
-keep interface com.whatwg.providers.** { *; }
-keep class com.whatwg.compose.** { *; }
```

## JNI Considerations

The Crane library uses JNI for native code integration:

```kotlin
// Native library is loaded automatically
// If manual loading is needed:
companion object {
    init {
        System.loadLibrary("whatwg")
    }
}

// JNI methods are called on background threads
// UI updates should be dispatched to main thread
withContext(Dispatchers.Main) {
    browser.loadUrl(url)
}
```

## Troubleshooting

### Common Issues

**UnsatisfiedLinkError**
- Ensure NDK is properly configured
- Check that ABI filters include your device's architecture
- Verify native library is included in APK

**Network requests failing**
- Add `INTERNET` permission to AndroidManifest.xml
- Check network security config for cleartext traffic

**Geolocation not working**
- Request location permissions at runtime
- Enable location services on device
- Check Play Services availability

**OutOfMemoryError**
- Monitor WebView memory usage
- Implement `onTrimMemory` callback
- Consider using process isolation

### Debug Logging

```kotlin
// Enable verbose logging
if (BuildConfig.DEBUG) {
    browser.consoleMessages
        .onEach { Log.d("WhatWG", "[${it.level}] ${it.text}") }
        .launchIn(lifecycleScope)
}
```

## Best Practices

1. **Use `rememberWhatWGBrowser()`** - Proper lifecycle management
2. **Handle configuration changes** - Browser state survives rotation
3. **Request permissions early** - Better user experience
4. **Monitor memory** - WebViews can be memory-intensive
5. **Test on real devices** - Emulator may not match real behavior
6. **Use coroutines properly** - Avoid blocking main thread

## Example Project

See `bindings/kotlin/examples/browser/` for a complete example Android browser application with Material Design 3.

## API Reference

For complete API documentation, see:
- [WhatWGPlatform](api/WhatWGPlatform.md)
- [WhatWGBrowser](api/WhatWGBrowser.md)
- [WhatWGWebView](api/WhatWGWebView.md)
- [Provider Interfaces](api/Providers.md)

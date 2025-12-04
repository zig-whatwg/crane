# 🏗️ Crane

**Production-ready WHATWG standards implementation in Zig**

Crane is a comprehensive, spec-compliant implementation of the [WHATWG](https://whatwg.org/) web platform standards written in [Zig](https://ziglang.org/). Built for performance, safety, and correctness, Crane provides the foundational building blocks for web-compatible applications and runtimes.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zig Version](https://img.shields.io/badge/Zig-0.15.2-orange.svg)](https://ziglang.org/download/)
[![CI](https://github.com/bcardarella/whatwg/actions/workflows/test.yml/badge.svg)](https://github.com/bcardarella/whatwg/actions/workflows/test.yml)

## 🎯 Why Crane?

- **🔒 Memory Safe** - Zero tolerance for memory leaks, leveraging Zig's allocator system and defer patterns
- **📐 Spec Compliant** - Every algorithm implemented exactly as specified by WHATWG standards
- **🚀 Tiny Footprint** - Complete implementation compiles to just 52 KB (optimized)
- **⚡ High Performance** - Zero-cost abstractions, aggressive dead code elimination
- **🧪 Comprehensive Testing** - 1100+ tests covering edge cases and Web Platform Tests (WPT)
- **🌐 Browser Compatible** - Behavior matches Chrome, Firefox, and Safari

## 📦 What's Implemented

### Core Infrastructure ✅

| Standard | Status | Key Features |
|----------|--------|--------------|
| **[Infra](https://infra.spec.whatwg.org/)** | ✅ Complete | Lists, OrderedMaps, byte sequences, code points, base64, bloom filters |
| **[WebIDL](https://webidl.spec.whatwg.org/)** | ✅ Complete | Type system, interfaces, namespaces, mixins, code generation |

### Specifications ✅

| Standard | Status | Key Features |
|----------|--------|--------------|
| **[Encoding](https://encoding.spec.whatwg.org/)** | ✅ Complete | UTF-8/16, legacy encodings (ISO-8859, Windows-1252, EUC-JP, Shift_JIS, GB18030), TextEncoder/Decoder, BOM handling |
| **[URL](https://url.spec.whatwg.org/)** | ✅ Complete | URL parsing, serialization, URLSearchParams, IDNA (6391 UTS46 tests), IPv4/IPv6, form-urlencoded |
| **[Console](https://console.spec.whatwg.org/)** | ✅ Complete | Console logging, formatting, groups, timers, assertions |
| **[Streams](https://streams.spec.whatwg.org/)** | ✅ Complete | ReadableStream, WritableStream, TransformStream, BYOB readers, async iteration |
| **[DOM](https://dom.spec.whatwg.org/)** | 🚧 In Progress | EventTarget, Node, Element, CharacterData, Document, Events, XPath |
| **[MIME Sniffing](https://mimesniff.spec.whatwg.org/)** | ✅ Complete | MIME type parsing, content sniffing, resource detection |
| **[Quirks Mode](https://quirks.spec.whatwg.org/)** | ✅ Complete | Document mode detection, CSS value quirks, selector quirks |
| **[Fetch](https://fetch.spec.whatwg.org/)** | ✅ Complete | Request/Response, Headers, Body mixin, data/about URL schemes, HTTP fetch algorithms |

### CSS Support 🎨

| Module | Status | Key Features |
|--------|--------|--------------|
| **CSS Syntax** | ✅ Complete | CSS Syntax Module Level 3 tokenizer |
| **CSS Values** | ✅ Complete | Color parser (hex, rgb, named), length parser (all units) |
| **CSS Selectors** | ✅ Complete | Full selector parsing, specificity, matching engine |
| **Quirks Integration** | ✅ Complete | Hashless hex colors, unitless lengths |

### Runtime Infrastructure 🔧

| Module | Status | Key Features |
|--------|--------|--------------|
| **V8 Integration** | 🚧 In Progress | JavaScript engine bindings, wrapper caching |
| **Instance System** | ✅ Complete | Zig-JS object identity, GC integration |
| **ArrayBufferView** | ✅ Complete | TypedArray introspection (all 13 types) |

### Platform Bindings 📱

| Platform | Status | Key Features |
|----------|--------|--------------|
| **Swift (iOS/macOS)** | ✅ Complete | SwiftUI integration, async/await, capability protocols |
| **Kotlin (Android)** | ✅ Complete | Jetpack Compose, coroutines, JNI bridge |
| **C ABI** | ✅ Complete | Platform-agnostic C exports for any language |

### Planned 🚧

- **Web Sockets** - WebSocket protocol implementation  
- **Storage** - localStorage, sessionStorage
- **HTML Parser** - Full HTML5 parsing algorithm
- Additional DOM APIs

## 🚀 Quick Start

### Installation

Add Crane as a dependency using Zig's package manager:

```bash
zig fetch --save https://github.com/bcardarella/crane/archive/main.tar.gz
```

Or add to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .crane = .{
            .url = "https://github.com/bcardarella/crane/archive/main.tar.gz",
            .hash = "1220...", // zig fetch will provide this
        },
    },
}
```

### Usage Examples

#### URL Parsing

```zig
const std = @import("std");
const crane = @import("crane");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse a URL
    const url = try crane.url.parse(allocator, "https://example.com:8080/path?query=value#fragment");
    defer url.deinit();

    std.debug.print("Scheme: {s}\n", .{url.scheme}); // "https"
    std.debug.print("Host: {s}\n", .{url.host.?.domain}); // "example.com"
    std.debug.print("Port: {d}\n", .{url.port.?}); // 8080
}
```

#### Text Encoding/Decoding

```zig
const std = @import("std");
const crane = @import("crane");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Encode UTF-8
    const encoder = crane.encoding.TextEncoder.init(allocator);
    const bytes = try encoder.encode("Hello, 世界! 🦀");
    defer allocator.free(bytes);

    // Decode UTF-8
    var decoder = crane.encoding.TextDecoder.init(allocator);
    defer decoder.deinit();
    const text = try decoder.decode(bytes);
    defer allocator.free(text);

    std.debug.print("Decoded: {s}\n", .{text}); // "Hello, 世界! 🦀"
}
```

#### Streams

```zig
const std = @import("std");
const crane = @import("crane");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a readable stream
    var stream = try crane.streams.ReadableStream.init(allocator, .{
        .pull = myPullFunction,
    });
    defer stream.deinit();

    // Get a reader
    const reader = try stream.getReader();
    defer reader.releaseLock();

    // Read chunks
    while (true) {
        const result = try reader.read();
        if (result.done) break;
        // Process result.value
    }
}
```

#### Fetch API

```zig
const std = @import("std");
const crane = @import("crane");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a Request
    const request = try crane.fetch.Request.init(allocator, .{
        .url = "https://api.example.com/data",
    }, .{
        .method = "GET",
    });
    defer request.deinit();

    // Work with Headers
    const headers = try crane.fetch.Headers.init(allocator, .none);
    defer headers.deinit();
    
    try headers.append("Content-Type", "application/json");
    try headers.append("Authorization", "Bearer token");
    
    // Check if header exists
    const has_auth = try headers.has("Authorization"); // true

    // Create a Response
    const response = try crane.fetch.Response.init(allocator, "Hello, World!", .{
        .status = 200,
        .statusText = "OK",
    });
    defer response.deinit();
    
    std.debug.print("Response status: {d}\n", .{response.status()}); // 200
    std.debug.print("Response ok: {}\n", .{response.ok()}); // true
}
```

#### Console Logging

```zig
const crane = @import("crane");

pub fn main() !void {
    const console = crane.console.console;
    
    console.log("Hello from Crane!");
    console.warn("Warning: This is awesome");
    console.error("Just kidding, no errors here");
    
    console.time("operation");
    // Do some work...
    console.timeEnd("operation");
}
```

## 🏛️ Architecture

### Unified Platform Backend

Crane uses a **Unified Platform Backend** architecture that provides a single entry point for embedders:

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Application                          │
├─────────────────────────────────────────────────────────────┤
│  Swift (iOS/macOS)  │  Kotlin (Android)  │   Zig / C / ...  │
├─────────────────────────────────────────────────────────────┤
│                   PlatformBackend (C ABI)                    │
├─────────────────────────────────────────────────────────────┤
│ ClipboardVTable │ NetworkVTable │ StorageVTable │ ...       │
├─────────────────────────────────────────────────────────────┤
│             WHATWG Specifications (Zig Core)                 │
└─────────────────────────────────────────────────────────────┘
```

**Key Components:**

- **PlatformBackend** - Single extern struct with all capability VTables
- **Capability VTables** - Pluggable implementations for clipboard, network, storage, etc.
- **C ABI** - Platform-agnostic exports (`whatwg_init`, `whatwg_deinit`, etc.)

### Mobile Integration

#### Swift (iOS/macOS)

```swift
import WhatWG

// Initialize platform with default iOS providers
let platform = WhatWGPlatform()
platform.clipboardProvider = iOSClipboardProvider()
platform.storageProvider = iOSStorageProvider()

// Create a browser view
struct ContentView: View {
    @StateObject var browser = WhatWGBrowser()
    
    var body: some View {
        VStack {
            WhatWGWebView(browser: browser)
            HStack {
                Button("Back") { browser.goBack() }
                    .disabled(!browser.canGoBack)
                Button("Forward") { browser.goForward() }
                    .disabled(!browser.canGoForward)
            }
            TextField("URL", text: $browser.urlString)
                .onSubmit { browser.loadURL() }
        }
    }
}
```

#### Kotlin (Android)

```kotlin
import com.whatwg.*
import com.whatwg.compose.*

// Initialize platform with Android providers
val platform = WhatWGPlatform().apply {
    clipboardProvider = AndroidClipboardProvider(context)
    storageProvider = AndroidStorageProvider(context)
}

// Create a browser composable
@Composable
fun BrowserScreen() {
    val browser = rememberWhatWGBrowser()
    
    Column {
        WhatWGWebView(browser = browser)
        
        Row {
            Button(
                onClick = { browser.goBack() },
                enabled = browser.canGoBack
            ) { Text("Back") }
            
            Button(
                onClick = { browser.goForward() },
                enabled = browser.canGoForward
            ) { Text("Forward") }
        }
        
        TextField(
            value = browser.urlString,
            onValueChange = { browser.urlString = it }
        )
    }
}
```

### Capability Providers

Implement platform-specific capabilities by providing your own implementations:

| Capability | iOS Implementation | Android Implementation |
|------------|-------------------|----------------------|
| **Clipboard** | UIPasteboard | ClipboardManager |
| **Network** | URLSession | HttpURLConnection |
| **Storage** | UserDefaults + FileManager | SharedPreferences + File |
| **Geolocation** | CoreLocation | LocationManager |
| **Notifications** | UserNotifications | NotificationManager |
| **Timer** | DispatchSourceTimer | Handler/Looper |
| **UI** | UIAlertController | AlertDialog |
| **FileSystem** | UIDocumentPicker | Storage Access Framework |

See [docs/capability-implementation.md](docs/capability-implementation.md) for detailed implementation guide.

## 🏗️ Building from Source

### Prerequisites

- **Zig 0.15.1** or later ([download](https://ziglang.org/download/))

### Build Commands

```bash
# Clone the repository
git clone https://github.com/bcardarella/crane.git
cd crane

# Run all tests
zig build test

# Build the demo CLI
zig build

# Build the comprehensive binary (includes all specs)
zig build comprehensive

# Generate WebIDL code
zig build codegen

# Run specific spec tests
zig build test -- --test-filter "URL"
zig build test -- --test-filter "Streams"
```

### Build Targets

| Target | Description | Size |
|--------|-------------|------|
| `whatwg` | Demo CLI application | 1.1 MB (debug) |
| `whatwg-comprehensive` | All 8 specs in one binary | 52 KB (optimized) |
| `webidl-codegen` | WebIDL code generator | 1.9 MB (debug) |
| `parse-idls` | IDL parser utility | 1.8 MB (debug) |

### Optimization Levels

```bash
# Debug build (default) - Full symbols, no optimization
zig build

# Fast release - Optimized for speed
zig build -Doptimize=ReleaseFast

# Small release - Optimized for size (52 KB!)
zig build -Doptimize=ReleaseSmall

# Safe release - Optimizations + safety checks
zig build -Doptimize=ReleaseSafe
```

## 📊 Binary Size Comparison

Crane's **52 KB** comprehensive binary includes **8 complete WHATWG specifications**:

| Platform | Size | Comparison |
|----------|------|------------|
| **Crane (ReleaseSmall)** | **52 KB** | Baseline |
| Crane (ReleaseFast) | 68 KB | +31% (optimized for speed) |
| Crane (Debug) | 1.2 MB | +2,300% (debug symbols) |
| Go "Hello World" | ~2 MB | +3,800% |
| Minimal Rust binary | ~300 KB | +577% |
| Node.js runtime | ~100 MB | +192,000% |

This makes Crane ideal for:
- 🔌 Embedded systems
- 🌐 WebAssembly modules  
- ⚡ Serverless functions
- 🖥️ CLI tools
- 📦 Any size-constrained environment

## 🧪 Testing

Crane has **1100+ tests** covering:

- ✅ **Unit tests** - Every algorithm, edge case, and error condition
- ✅ **Integration tests** - Cross-spec interactions
- ✅ **Web Platform Tests (WPT)** - Browser compatibility tests
- ✅ **IDNA Conformance** - 6,391 UTS46 tests (100% pass rate)
- ✅ **Memory leak detection** - Using `std.testing.allocator`

```bash
# Run all tests
zig build test

# Run with summary
zig build test --summary all

# Run specific spec tests
zig build test -Dspec=url
zig build test -Dspec=encoding
zig build test -Dspec=css
zig build test -Dspec=quirks

# Run specific test filter
zig build test -- --test-filter "URLSearchParams"

# Memory leak detection is automatic with std.testing.allocator
```

## 📁 Project Structure

```
crane/
├── src/                      # Source implementations
│   ├── infra/               # Infra Standard (primitives, bloom filters)
│   ├── webidl/              # WebIDL type system + codegen
│   ├── encoding/            # Encoding Standard (UTF-8, legacy encodings)
│   ├── url/                 # URL Standard (parsing, IDNA, form-urlencoded)
│   ├── console/             # Console Standard
│   ├── streams/             # Streams Standard (readable, writable, transform)
│   ├── dom/                 # DOM Standard (nodes, events, XPath)
│   ├── mimesniff/           # MIME Sniffing Standard
│   ├── quirks/              # Quirks Mode Standard
│   ├── css/                 # CSS Syntax + Value Parsing
│   ├── selector/            # CSS Selector Parsing + Matching
│   ├── platform/            # Platform backend VTables
│   ├── runtime/             # V8 integration, instance management
│   └── root.zig             # Main entry point
├── bindings/                 # Platform-specific bindings
│   ├── swift/               # Swift package for iOS/macOS
│   │   ├── Sources/WhatWG/  # Swift library source
│   │   │   ├── UI/          # SwiftUI components (WhatWGBrowser, WhatWGWebView)
│   │   │   ├── Providers/   # Capability protocols
│   │   │   └── iOS/         # iOS default implementations
│   │   └── Tests/           # Swift tests
│   └── kotlin/              # Kotlin library for Android
│       └── whatwg/
│           └── src/main/
│               ├── kotlin/  # Kotlin source
│               │   ├── compose/  # Jetpack Compose UI
│               │   ├── providers/# Capability interfaces
│               │   └── android/  # Android implementations
│               └── cpp/     # JNI bridge code
├── include/                  # C ABI headers
│   ├── whatwg.h             # Main header
│   ├── whatwg_types.h       # Type definitions
│   └── whatwg_backend.h     # Backend VTables
├── specs/                   # Complete WHATWG specification markdown files
│   ├── whatwg/              # WHATWG spec sections (HTML, DOM, etc.)
│   ├── idl/                 # Official WebIDL definitions (symlink)
│   └── algorithms/          # Algorithm definitions (JSON)
├── tests/                   # Test suites
├── docs/                    # Documentation
│   ├── swift-integration.md # Swift/iOS integration guide
│   ├── kotlin-integration.md# Kotlin/Android integration guide
│   └── capability-implementation.md # How to implement capabilities
├── skills/                  # AI agent skill definitions
├── build.zig                # Build configuration
└── build.zig.zon            # Package manifest
```

## 🔧 Development

### Code Generation

Crane uses a custom WebIDL code generator to create optimized Zig code from WebIDL definitions:

```bash
# Generate code from WebIDL source
zig build codegen

# Generated files appear in webidl/generated/ (gitignored)
# These are enhanced with:
#   - Flattened inheritance hierarchies (all fields in derived classes)
#   - Optimized field layouts (consistent memory ordering)
#   - Method inheritance with @ptrCast (zero overhead polymorphism)
#   - Property getters/setters
#   - Full type safety
```

#### WebIDL Code Generation Features

The codegen system provides:

- **Flattened Inheritance** - All parent fields copied into child classes for optimal layout
- **Zero-Cost Method Inheritance** - Methods copied with smart `@ptrCast` for parent field access
- **Smart Self Rewriting** - Method calls use `self`, field access uses `self_parent` cast
- **Private Method Inheritance** - All methods (public and private) inherited for complete functionality
- **Conditional Parent Casting** - Only generates `self_parent` when actually needed (avoids unused variable warnings)

### Memory Management

All Crane APIs follow Zig's explicit allocator pattern:

```zig
// ✅ Correct - explicit allocation and cleanup
const url = try URL.parse(allocator, "https://example.com");
defer url.deinit();

// ✅ Correct - arena for batch operations
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_alloc = arena.allocator();

// Process many URLs, free all at once
for (urls) |url_string| {
    const url = try URL.parse(arena_alloc, url_string);
    // No individual deinit needed
}
```

### Continuous Integration

Crane runs automated tests on every push and pull request:

```bash
# CI runs on:
# - Ubuntu (latest)
# - macOS (latest)  
# - Windows (latest)

# Tests executed:
zig build test --summary all  # All 1324+ tests
```

All tests must pass on all platforms before merging.

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. **Pick a task** - Check `bd ready` for available work
2. **Create a branch** - `git checkout -b feature/your-feature`
3. **Implement with tests** - Test-driven development
4. **Run checks** - `zig build test`
5. **Commit frequently** - Small, logical commits
6. **Submit PR** - With clear description

### Issue Tracking

We use **[bd (beads)](https://github.com/bcardarella/beads)** for issue tracking:

```bash
# See available work
bd ready

# Create a new issue
bd create "Issue description" -t bug|feature|task -p 0-4

# Work on an issue
bd update bd-123 --status in_progress

# Complete work
bd close bd-123 --reason "Implemented"
```

## 📚 Documentation

- **[WHATWG Standards](https://spec.whatwg.org/)** - Official specifications
- **[Swift Integration Guide](docs/swift-integration.md)** - iOS/macOS integration
- **[Kotlin Integration Guide](docs/kotlin-integration.md)** - Android integration
- **[Capability Implementation Guide](docs/capability-implementation.md)** - Custom providers
- **[Engine Selection Guide](docs/engine-selection.md)** - V8, JSC, QuickJS comparison
- **[API Documentation](docs/)** - Crane API reference (coming soon)
- **[Examples](examples/)** - Usage examples (coming soon)
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribution guidelines

### Spec References

Complete WHATWG specifications are available in the `specs/` directory:

| Spec | File | Description |
|------|------|-------------|
| **Infra** | `specs/whatwg/infra/` | Infra Standard primitives |
| **WebIDL** | `specs/whatwg/webidl/` | WebIDL specification |
| **Encoding** | `specs/whatwg/encoding/` | Encoding Standard |
| **URL** | `specs/whatwg/url/` | URL Standard |
| **Console** | `specs/whatwg/console/` | Console Standard |
| **Streams** | `specs/whatwg/streams/` | Streams Standard |
| **DOM** | `specs/whatwg/dom/` | DOM Standard |
| **MIME Sniff** | `specs/whatwg/mimesniff/` | MIME Sniffing Standard |
| **Quirks** | `specs/whatwg/quirks/` | Quirks Mode Standard |
| **HTML** | `specs/whatwg/html/` | HTML Standard (60+ sections) |

Official WebIDL definitions from [w3c/webref](https://github.com/w3c/webref) are symlinked in `specs/idl/` (333 IDL files).

## 🎓 Learning Resources

### Understanding WHATWG Specs

Each WHATWG specification defines:
- **Algorithms** - Step-by-step processing rules
- **Data structures** - Internal representations
- **APIs** - Public interfaces
- **Error handling** - How to handle edge cases

Crane implements these **exactly as specified** to ensure web platform compatibility.

### Zig Learning

New to Zig? Check out:
- [Zig Learn](https://ziglearn.org/) - Official Zig learning resource
- [Zig Documentation](https://ziglang.org/documentation/master/) - Language reference
- [Zig by Example](https://zig-by-example.com/) - Practical examples

## 🐛 Known Issues & Limitations

### Current Status

| Module | Status | Notes |
|--------|--------|-------|
| **Infra** | ✅ Complete | All primitives, lists, maps, byte sequences, bloom filters |
| **WebIDL** | ✅ Complete | Type system, codegen with full inheritance, async_iterable |
| **Encoding** | ✅ Complete | UTF-8/16, legacy encodings (ISO-8859, Windows-1252, EUC-JP, Shift_JIS, GB18030) |
| **URL** | ✅ Complete | Full spec compliance, 6391 IDNA tests passing, form-urlencoded |
| **Console** | ✅ Complete | All logging, timing, grouping, and assertion APIs |
| **Streams** | ✅ Complete | ReadableStream, WritableStream, TransformStream, BYOB, async iteration |
| **MIME Sniffing** | ✅ Complete | Type detection, parsing, content sniffing |
| **Quirks Mode** | ✅ Complete | Document modes, CSS value quirks, selector quirks |
| **CSS** | ✅ Complete | Tokenizer, color/length parsers, property routing |
| **Selectors** | ✅ Complete | Full CSS selector parsing, specificity, matching engine |
| **DOM** | 🚧 In Progress | EventTarget, Node, Element, Document, Events, XPath |
| **Runtime** | 🚧 In Progress | V8 integration, wrapper caching, GC integration |

### Reporting Issues

Found a bug? Please report it:

1. Search existing issues: `bd list --json | jq '.[] | select(.title | contains("your search"))'`
2. Create a new issue: `bd create "Bug description" -t bug -p 1`
3. Or open a GitHub issue with:
   - Zig version
   - Minimal reproduction
   - Expected vs actual behavior

## 📄 License

**MIT License** - Copyright (c) 2025 Brian Cardarella

See [LICENSE](LICENSE) for full text.

## 🙏 Acknowledgments

- **[WHATWG](https://whatwg.org/)** - For maintaining the web platform standards
- **[Zig](https://ziglang.org/)** - For the excellent programming language
- **Web Platform Tests** - For comprehensive test suites
- **Browser implementations** - Chrome, Firefox, Safari for reference behavior

## 📞 Contact

- **Author**: Brian Cardarella
- **GitHub**: [@bcardarella](https://github.com/bcardarella)
- **Project**: [github.com/zig-whatwg/crane](https://github.com/zig-whatwg/crane)

---

Built with ❤️ in Zig. Lifting web standards to new heights. 🏗️

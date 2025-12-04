# Engine Selection Guide

This guide helps you choose the right JavaScript engine for your Crane-based application.

## Overview

Crane supports multiple JavaScript engines through its `EngineBinding` abstraction:

| Engine | Status | Best For |
|--------|--------|----------|
| **V8** | ✅ Implemented | Production apps, performance-critical |
| **JavaScriptCore** | 🚧 Planned | iOS/macOS apps, system integration |
| **QuickJS** | 🚧 Planned | Embedded systems, minimal footprint |

## Engine Comparison

### Performance

| Metric | V8 | JavaScriptCore | QuickJS |
|--------|-----|----------------|---------|
| Startup time | ~50ms | ~30ms | ~5ms |
| Peak performance | Fastest | Fast | Moderate |
| JIT compilation | Yes (TurboFan) | Yes (FTL) | No |
| Garbage collection | Generational | Generational | Mark & sweep |

### Memory Usage

| Scenario | V8 | JavaScriptCore | QuickJS |
|----------|-----|----------------|---------|
| Minimal runtime | ~10 MB | ~5 MB | ~1 MB |
| Typical web app | ~50-100 MB | ~40-80 MB | ~10-30 MB |
| Memory-constrained | Not recommended | Possible | Recommended |

### Binary Size

| Platform | V8 | JavaScriptCore | QuickJS |
|----------|-----|----------------|---------|
| Static library | ~20 MB | System (0) | ~1 MB |
| Dynamic library | ~8 MB | System (0) | ~500 KB |
| WebAssembly | ~5 MB | N/A | ~300 KB |

### Feature Support

| Feature | V8 | JavaScriptCore | QuickJS |
|---------|-----|----------------|---------|
| ES2023 | Full | Full | Most |
| ES Modules | Full | Full | Full |
| Top-level await | Yes | Yes | Yes |
| WeakRefs | Yes | Yes | No |
| BigInt | Yes | Yes | Yes |
| Atomics | Yes | Yes | No |
| SharedArrayBuffer | Yes | Yes | No |
| WASM | Full | Full | Partial |

### Platform Availability

| Platform | V8 | JavaScriptCore | QuickJS |
|----------|-----|----------------|---------|
| Linux x86_64 | ✅ | Build required | ✅ |
| Linux ARM64 | ✅ | Build required | ✅ |
| macOS | ✅ | ✅ System | ✅ |
| iOS | Build required | ✅ System | ✅ |
| Android | ✅ | Build required | ✅ |
| Windows | ✅ | Build required | ✅ |
| WebAssembly | ✅ | N/A | ✅ |

## Choosing an Engine

### Use V8 When:

- **Performance is critical** - V8's JIT compiler produces the fastest code
- **Full ES2023+ support needed** - V8 has the most complete spec coverage
- **Building for desktop/server** - Binary size is less of a concern
- **Chrome DevTools debugging** - V8's debugging integration is excellent
- **WebAssembly performance matters** - V8's WASM implementation is highly optimized

```zig
const platform = try Platform.init(.{
    .engine = .v8,
    .v8_options = .{
        .max_heap_size = 256 * 1024 * 1024, // 256 MB
        .enable_turbofan = true,
    },
});
```

### Use JavaScriptCore When:

- **Building for iOS/macOS** - JSC is the system framework, no additional binary size
- **Already using WebKit** - Natural integration with WebKit-based views
- **Safari compatibility testing** - Same engine as Safari browser
- **Apple ecosystem integration** - Best integration with Apple frameworks

```swift
let platform = WhatWGPlatform()
platform.engine = .javaScriptCore

// JSC is automatically available on Apple platforms
let context = try platform.createContext()
```

### Use QuickJS When:

- **Binary size is critical** - QuickJS adds only ~500 KB
- **Memory is constrained** - Runs in as little as 1 MB
- **Embedded systems** - Perfect for IoT, microcontrollers
- **Predictable performance** - No JIT warmup delays
- **Sandboxing needed** - Easy to embed and isolate

```zig
const platform = try Platform.init(.{
    .engine = .quickjs,
    .quickjs_options = .{
        .memory_limit = 8 * 1024 * 1024, // 8 MB
        .stack_size = 256 * 1024, // 256 KB
    },
});
```

## Configuration Examples

### V8 Configuration

```zig
const v8_config = V8Config{
    // Memory limits
    .max_heap_size = 512 * 1024 * 1024, // 512 MB
    .max_old_space_size = 256 * 1024 * 1024,
    .max_young_space_size = 64 * 1024 * 1024,
    
    // Performance options
    .enable_turbofan = true, // JIT optimization
    .enable_lazy_parsing = true, // Faster startup
    .expose_gc = false, // Don't expose gc() to scripts
    
    // Debugging
    .enable_inspector = true, // Chrome DevTools
    .inspector_port = 9229,
};
```

### JavaScriptCore Configuration

```swift
let jscConfig = JSCConfiguration()
jscConfig.maxHeapSize = 256 * 1024 * 1024 // 256 MB
jscConfig.enableJIT = true
jscConfig.enableGCLogging = false

// iOS-specific
jscConfig.backgroundExecution = true
jscConfig.jitCodeCache = .shared
```

### QuickJS Configuration

```zig
const quickjs_config = QuickJSConfig{
    // Memory limits
    .memory_limit = 32 * 1024 * 1024, // 32 MB
    .stack_size = 1 * 1024 * 1024, // 1 MB stack
    .atom_table_size = 64 * 1024, // String interning
    
    // Features
    .enable_bignum = true, // BigInt/BigDecimal
    .enable_regexp_dotall = true,
    .enable_generators = true,
    
    // Module loading
    .module_loader = customModuleLoader,
};
```

## Runtime Engine Selection

### Zig

```zig
const Engine = enum { v8, jsc, quickjs };

pub fn createPlatform(engine: Engine) !*Platform {
    return switch (engine) {
        .v8 => try Platform.initWithV8(.{}),
        .jsc => try Platform.initWithJSC(.{}),
        .quickjs => try Platform.initWithQuickJS(.{}),
    };
}
```

### Swift

```swift
enum JSEngine {
    case v8
    case javaScriptCore
    case quickJS
}

let platform = WhatWGPlatform()

switch selectedEngine {
case .v8:
    platform.engine = .v8
case .javaScriptCore:
    platform.engine = .javaScriptCore
case .quickJS:
    platform.engine = .quickJS
}
```

### Kotlin

```kotlin
enum class JSEngine {
    V8,
    JAVASCRIPT_CORE,
    QUICKJS
}

val platform = WhatWGPlatform().apply {
    engine = when (selectedEngine) {
        JSEngine.V8 -> JSEngine.V8
        JSEngine.JAVASCRIPT_CORE -> JSEngine.JAVASCRIPT_CORE
        JSEngine.QUICKJS -> JSEngine.QUICKJS
    }
}
```

## Debugging

### V8 (Chrome DevTools)

```bash
# Enable inspector on port 9229
platform.v8_options.enable_inspector = true
platform.v8_options.inspector_port = 9229

# Connect with Chrome
# Navigate to: chrome://inspect
```

### JavaScriptCore (Safari Web Inspector)

```bash
# Enable remote debugging (macOS)
defaults write com.apple.Safari WebKitDeveloperExtras -bool true

# Or use JSContext API
JSContext.currentContext?.exceptionHandler = { context, exception in
    print("JS Error: \(exception)")
}
```

### QuickJS (Built-in Debugger)

```zig
// Enable stack traces
quickjs_config.enable_stack_trace = true;

// Log to stderr
quickjs_config.error_handler = fn(msg: []const u8) void {
    std.debug.print("QuickJS Error: {s}\n", .{msg});
};
```

## Performance Tips

### V8

1. **Warm up code paths** - Run hot functions before timing
2. **Use typed arrays** - Avoid boxing overhead
3. **Minimize GC pressure** - Reuse objects when possible
4. **Profile with DevTools** - Use Chrome's CPU profiler

### JavaScriptCore

1. **Use JSValue caching** - Avoid repeated lookups
2. **Batch DOM operations** - Minimize JS/native transitions
3. **Enable FTL JIT** - For long-running applications

### QuickJS

1. **Pre-compile scripts** - Use bytecode compilation
2. **Limit recursion** - Stack is limited
3. **Avoid eval()** - Slower without JIT
4. **Use typed arrays** - Native performance for binary data

## Migration Between Engines

Code written for Crane's EngineBinding abstraction works across all engines. However, some engine-specific features may need adaptation:

### V8-specific

```javascript
// V8-only: Expose GC for testing
if (typeof gc !== 'undefined') gc();

// Portable alternative
if (globalThis.gc) globalThis.gc();
```

### JSC-specific

```javascript
// JSC-only: Engine identification
if (globalThis.$vm) {
    // Running on JavaScriptCore
}
```

### QuickJS-specific

```javascript
// QuickJS-only: std module
import * as std from 'std';
std.gc(); // Force GC

// Portable alternative
globalThis.gc?.();
```

## Benchmarks

Typical benchmark results (operations per second):

| Benchmark | V8 | JSC | QuickJS |
|-----------|-----|-----|---------|
| Richards | 35,000 | 30,000 | 8,000 |
| DeltaBlue | 42,000 | 38,000 | 10,000 |
| Crypto | 28,000 | 25,000 | 12,000 |
| RayTrace | 18,000 | 15,000 | 4,000 |
| NavierStokes | 32,000 | 28,000 | 9,000 |
| RegExp | 8,000 | 7,500 | 3,000 |
| JSON | 95,000 | 85,000 | 40,000 |

*Results vary by platform and workload. Always benchmark your specific use case.*

## Recommendations by Use Case

| Use Case | Recommended Engine |
|----------|-------------------|
| Production web browser | V8 |
| iOS/macOS app | JavaScriptCore |
| Android app | V8 |
| Desktop app (performance) | V8 |
| Desktop app (size) | QuickJS |
| Embedded system | QuickJS |
| Serverless function | QuickJS |
| WebAssembly target | QuickJS |
| Development/debugging | V8 |

## See Also

- [Swift Integration Guide](swift-integration.md)
- [Kotlin Integration Guide](kotlin-integration.md)
- [Capability Implementation Guide](capability-implementation.md)
- [EngineBinding API Reference](api/engine-binding.md)

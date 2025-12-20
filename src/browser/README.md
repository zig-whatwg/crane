# Browser API

A browser abstraction that maintains a single V8 isolate for its entire lifetime, creating new V8 contexts per navigation.

## Architecture

```
Browser (single isolate)
    └── Context (per navigation)
            ├── Window globals
            ├── Document
            └── WebIDL bindings
```

## Quick Start

```zig
const browser = @import("browser");

var b = try browser.Browser.init(allocator, .{});
defer b.deinit();

// Navigate creates new context, preserves storage
try b.navigate("http://example.com/test.html", .window);

// Execute script in current context
const result = try b.evaluateScript("document.title");
```

## API Reference

### Browser

| Method | Description |
|--------|-------------|
| `init(allocator, config)` | Create a new browser instance |
| `deinit()` | Release all resources |
| `navigate(url, context_type)` | Navigate to URL, creates new context |
| `reload()` | Reload current page |
| `evaluateScript(script)` | Execute JavaScript |
| `runEventLoop(timeout_ms)` | Run event loop until timeout |
| `getCurrentUrl()` | Get current page URL |
| `getIsolate()` | Get V8 isolate (advanced) |
| `getV8Context()` | Get V8 context (advanced) |
| `getStorage()` | Get storage subsystem |

### BrowserConfig

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `storage_root` | `?[]const u8` | `~/.whatwg/` | Storage directory |
| `persist_storage` | `bool` | `true` | Enable persistence |
| `initial_url` | `?[]const u8` | `null` | Initial navigation URL |
| `debug` | `bool` | `false` | Enable debug logging |

### Context Types

- `.window` - Standard browser window context
- `.worker` - Web Worker context
- `.service_worker` - Service Worker context

## Performance

- **Isolate creation**: ~50-100ms (done once per Browser)
- **Context creation**: ~1-5ms (done per navigation)

This enables efficient WPT test execution by reusing the isolate.

## Specification References

- [HTML Standard: Browsing contexts](https://html.spec.whatwg.org/multipage/document-sequences.html)
- [HTML Standard: Navigation](https://html.spec.whatwg.org/multipage/nav-history-apis.html)
- [HTML Standard: Window object](https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-window-object)

## Migration from browser_context.zig

The old `browser_context.zig` is deprecated. Migration:

| Old | New |
|-----|-----|
| `BrowserContext.init()` | `Browser.init()` then `navigate()` |
| `BrowserContext.executeScript()` | `Browser.evaluateScript()` |
| Direct context access | Use `Browser.getV8Context()` |

See `tests/wpt_runner/browser_context.zig` for the deprecation notice.

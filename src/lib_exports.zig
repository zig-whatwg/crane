//! Full Browser Runtime Library Exports
//!
//! This module exports C ABI functions for the complete browser runtime,
//! including all WebIDL interfaces, V8 bindings, and browser initialization.
//!
//! ## Purpose
//!
//! This module exports the full browser runtime for use cases that need:
//! - All WebIDL interfaces (Document, Element, Window, etc.)
//! - All WebIDL namespaces (console, CSS, etc.)
//! - V8 JavaScript engine bindings
//! - Browser initialization APIs
//!
//! ## Usage
//!
//! ```c
//! // Initialize the browser runtime
//! WhatwgBrowser* browser = whatwg_browser_create();
//!
//! // Navigate to a URL
//! whatwg_browser_navigate(browser, "https://example.com");
//!
//! // Execute JavaScript
//! const char* result = whatwg_browser_evaluate(browser, "document.title");
//!
//! // Cleanup
//! whatwg_browser_destroy(browser);
//! ```
//!
//! ## Build
//!
//! ```bash
//! zig build lib-full  # Builds libwhatwg_full.a (~60MB with all interfaces)
//! ```

const std = @import("std");

// ============================================================================
// Core Modules - Force compilation by referencing types
// ============================================================================

// Runtime infrastructure
const runtime = @import("runtime");
const webidl = @import("webidl");
const infra = @import("infra");

// The JavaScript engine, through the engine protocol (the build selects the
// adapter behind it).
const engine = @import("engine");

// WebIDL generated interfaces
const interfaces = @import("interfaces");
const impls = @import("impls");
const namespaces = @import("namespaces");
const dictionaries = @import("dictionaries");
const typedefs = @import("typedefs");
const enums = @import("enums");
const callbacks = @import("callbacks");
const mixins = @import("mixins");

// Browser module
const browser = @import("browser");

// Spec implementations
const dom = @import("dom");
const encoding = @import("encoding");
const url = @import("url");
const console = @import("console");
const streams = @import("streams");
const mimesniff = @import("mimesniff");
const fetch = @import("fetch");
const html_core = @import("html_core");
const html = @import("html");
const storage = @import("storage");
const trusted_types = @import("trusted_types");
const csp = @import("csp");
const hr_time = @import("hr_time");
const websocket = @import("websocket");
const permissions = @import("permissions");
const intl = @import("intl");

// Platform abstraction (VTables for native integration)

// ============================================================================
// Force Zig to compile all modules by referencing their types
// ============================================================================

/// This comptime block forces Zig to analyze and compile all the interface types
/// even if they're not directly used. Without this, dead code elimination would
/// remove them from the library.
fn forceModuleCompilation() void {
    // Reference runtime types
    _ = runtime.Instance;
    _ = runtime.Context;

    // Reference the engine and its adapter
    _ = engine;

    // Reference browser types
    _ = browser.Browser;
    _ = browser.Context;

    // Reference DOM types
    _ = dom.tree;

    // Reference encoding
    _ = encoding.Encoding;
    _ = encoding.Decoder;

    // Reference URL
    _ = url.internal.url_record;

    // Reference streams (access via internal.common)
    _ = streams.internal.common;
}

// ============================================================================
// C ABI Exports - Browser Lifecycle
// ============================================================================

/// Opaque browser handle for C API
pub const WhatwgBrowser = browser.Browser;

/// Create a new browser instance with default configuration.
///
/// The browser manages a single V8 isolate and supports multiple navigation
/// contexts. Storage (cookies, localStorage, IndexedDB) persists across
/// navigations.
///
/// @return Pointer to browser instance, or null on failure
pub export fn whatwg_browser_create() callconv(.c) ?*WhatwgBrowser {
    return createBrowser(std.heap.c_allocator);
}

/// A browser made from `allocator`, or null on failure. The browser records
/// its allocator, and `Browser.deinit` frees it with that allocator - which
/// is all `whatwg_browser_destroy` has to do.
fn createBrowser(allocator: std.mem.Allocator) ?*WhatwgBrowser {
    return browser.Browser.init(allocator, .{}) catch null;
}

/// Destroy a browser instance and free all resources.
///
/// This also destroys the V8 isolate and all associated contexts.
/// `Browser.deinit` frees the browser itself, with the allocator it was
/// made from; freeing it again here was a double free on every destroy.
///
/// @param b Pointer to browser instance to destroy
pub export fn whatwg_browser_destroy(b: ?*WhatwgBrowser) callconv(.c) void {
    if (b) |ptr| ptr.deinit();
}

/// Navigate the browser to a URL.
///
/// This creates a new V8 context while preserving storage state.
/// The previous context is destroyed.
///
/// @param b Pointer to browser instance
/// @param url URL to navigate to (null-terminated C string)
/// @return 0 on success, non-zero error code on failure
pub export fn whatwg_browser_navigate(b: ?*WhatwgBrowser, url_cstr: [*:0]const u8) callconv(.c) i32 {
    if (b) |ptr| {
        const url_slice = std.mem.span(url_cstr);
        // navigate() takes URL and context type (default to window)
        ptr.navigate(url_slice, .window) catch |err| {
            return switch (err) {
                error.OutOfMemory => -1,
                error.NotInitialized => -2,
                else => -99,
            };
        };
        return 0;
    }
    return -100;
}

/// Evaluate JavaScript code in the current browser context.
///
/// @param b Pointer to browser instance
/// @param code JavaScript code to evaluate (null-terminated C string)
/// @param result_buf Buffer to receive the result string
/// @param result_buf_len Length of result buffer
/// @return Length of result written, or negative error code
pub export fn whatwg_browser_evaluate(
    b: ?*WhatwgBrowser,
    code: [*:0]const u8,
    result_buf: [*]u8,
    result_buf_len: usize,
) callconv(.c) i32 {
    if (b) |ptr| {
        const code_slice = std.mem.span(code);
        const ctx = ptr.current_context orelse return -1;
        // The completion value, ToString'd; what the script throws fails the
        // call.
        const result = ctx.evaluateScriptToString(code_slice, std.heap.c_allocator) catch return -99;
        defer std.heap.c_allocator.free(result);
        const copy_len = @min(result.len, result_buf_len);
        @memcpy(result_buf[0..copy_len], result[0..copy_len]);
        return @intCast(copy_len);
    }
    return -100;
}

// ============================================================================
// C ABI Exports - Runtime Initialization
// ============================================================================

/// Start the engine (call once at program start), before creating any
/// browser instance: engine.initializeEngine, which on V8 sets the RUNTIME
/// flag set before starting the platform. (`--predictable` and
/// `--hash-seed=0` belong to snapshot generation: applied to an embedding
/// application they would disable V8's parallelism, make `Math.random()`
/// deterministic and drop hash-flooding protection.)
pub export fn whatwg_runtime_init() callconv(.c) void {
    // crane.Process: the engine and every hook, once (docs/instances.md).
    browser.Process.ensureStarted(.{}) catch {};
}

/// End the engine (call once at program end), after destroying all browser
/// instances. An engine that cannot start again in the same process - V8 -
/// keeps its platform until the process exits.
pub export fn whatwg_runtime_shutdown() callconv(.c) void {
    engine.deinitializeEngine();
}

/// Get the library version.
///
/// @return Version string (null-terminated)
pub export fn whatwg_version() callconv(.c) [*:0]const u8 {
    return "1.0.0";
}

// ============================================================================
// C ABI Exports - Interface Registration
// ============================================================================

/// Get the number of registered WebIDL interfaces.
///
/// This is useful for debugging and introspection.
///
/// @return Number of registered interfaces
pub export fn whatwg_interface_count() callconv(.c) u32 {
    // Force reference to interfaces module to ensure it's compiled
    comptime {
        forceModuleCompilation();
    }
    // Return approximate count based on registered interfaces
    return 800; // Approximate number of interfaces in the full runtime
}

// ============================================================================
// Tests
// ============================================================================

test "lib_exports - version" {
    const version = whatwg_version();
    try std.testing.expect(std.mem.len(version) > 0);
}

test "lib_exports - module compilation" {
    forceModuleCompilation();
}

// An embedder that destroys a browser: Browser.deinit ends with its own
// `allocator.destroy(self)`, and whatwg_browser_destroy then freed the same
// pointer again with the C heap - a double free on every destroy. Under
// std.testing.allocator the second free reaches a pointer the C heap never
// handed out.
test "whatwg_browser_destroy frees a browser once" {
    const b = createBrowser(std.testing.allocator) orelse return error.BrowserCreateFailed;
    whatwg_browser_destroy(b);
}

test "whatwg_browser_create and whatwg_browser_destroy pair up on the C heap" {
    const b = whatwg_browser_create() orelse return error.BrowserCreateFailed;
    whatwg_browser_destroy(b);
}

test "whatwg_browser_destroy takes null" {
    whatwg_browser_destroy(null);
}

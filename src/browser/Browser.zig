//! Browser - Single V8 Isolate Browser Implementation
//!
//! This module implements a browser abstraction that maintains a single V8 isolate
//! for its entire lifetime, creating new V8 contexts per navigation. This is more
//! efficient than creating/destroying isolates per page.
//!
//! ## Architecture
//!
//! ```
//! Browser (single isolate)
//!     └── Context (per navigation)
//!             ├── Window globals
//!             ├── Document
//!             └── WebIDL bindings
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const browser = @import("browser");
//!
//! var b = try browser.Browser.init(allocator, .{});
//! defer b.deinit();
//!
//! // Navigate creates new context, preserves storage
//! try b.navigate("http://example.com/test.html");
//!
//! // Execute script in current context
//! const result = try b.evaluateScript("document.title");
//! ```
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Navigation and session history https://html.spec.whatwg.org/multipage/nav-history-apis.html

const std = @import("std");
const v8 = @import("v8");
const runtime = @import("runtime");

const context_mod = @import("Context.zig");
const Context = context_mod.Context;
const storage_mod = @import("storage/Storage.zig");
const Storage = storage_mod.Storage;

/// Browser configuration options
pub const BrowserConfig = struct {
    /// Root directory for persistent storage (default: ~/.whatwg/)
    storage_root: ?[]const u8 = null,
    /// Whether to enable storage persistence (default: true)
    persist_storage: bool = true,
    /// Initial URL to navigate to (optional)
    initial_url: ?[]const u8 = null,
    /// Enable debug logging
    debug: bool = false,
};

/// Browser instance managing a single V8 isolate
pub const Browser = struct {
    allocator: std.mem.Allocator,
    /// V8 isolate - lives for the entire browser lifetime
    isolate: ?*v8.ffi.Isolate,
    /// Current browsing context (V8 context + DOM)
    current_context: ?*Context,
    /// Persistent storage subsystem
    storage: *Storage,
    /// Browser configuration
    config: BrowserConfig,
    /// Whether the browser has been initialized
    initialized: bool,
    /// V8 event loop with timer support
    event_loop: ?*v8.V8EventLoop,

    /// Initialize a new Browser instance
    ///
    /// Creates a V8 isolate that will be reused across all navigations.
    /// The isolate is only destroyed when the browser is deinitialized.
    pub fn init(allocator: std.mem.Allocator, config: BrowserConfig) !*Browser {
        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(allocator);
        errdefer runtime.deinitializeRuntime();

        // Initialize V8 platform (once per process)
        v8.ffi.v8_Platform_Initialize();

        // Create V8 isolate
        const isolate = v8.ffi.v8_Isolate_New() orelse {
            runtime.deinitializeRuntime();
            return error.V8InitFailed;
        };
        errdefer {
            v8.ffi.v8_Isolate_Dispose(isolate);
        }

        v8.ffi.v8_Isolate_Enter(isolate);

        // Register V8 lifecycle cleanup handlers
        v8.registerBuiltinHandlers() catch |err| {
            std.debug.print("Warning: Failed to register lifecycle handlers: {}\n", .{err});
        };

        // Create storage subsystem
        const storage = try Storage.init(allocator, config.storage_root, config.persist_storage);
        errdefer storage.deinit();

        // Create V8 event loop with timer support
        const event_loop = try allocator.create(v8.V8EventLoop);
        errdefer allocator.destroy(event_loop);
        event_loop.* = try v8.V8EventLoop.init(isolate, allocator);

        // Allocate browser struct
        const browser = try allocator.create(Browser);
        errdefer allocator.destroy(browser);

        browser.* = Browser{
            .allocator = allocator,
            .isolate = isolate,
            .current_context = null,
            .storage = storage,
            .config = config,
            .initialized = true,
            .event_loop = event_loop,
        };

        // Navigate to initial URL if specified
        if (config.initial_url) |url| {
            try browser.navigate(url);
        }

        return browser;
    }

    /// Deinitialize the browser and release all resources
    ///
    /// This destroys the V8 isolate and all associated contexts.
    /// All storage is flushed to disk before cleanup.
    pub fn deinit(self: *Browser) void {
        // Destroy current context if any
        if (self.current_context) |ctx| {
            ctx.deinit();
            self.allocator.destroy(ctx);
            self.current_context = null;
        }

        // Flush and cleanup storage
        self.storage.flush() catch {};
        self.storage.deinit();
        self.allocator.destroy(self.storage);

        // Cleanup event loop
        if (self.event_loop) |event_loop| {
            event_loop.deinit();
            self.allocator.destroy(event_loop);
        }

        // Use the isolate lifecycle manager for centralized cleanup
        // This ensures all V8-dependent modules are cleaned up in the correct order
        // See src/runtime/engines/v8/isolate_lifecycle.zig for the full list

        if (self.isolate) |isolate| {
            // Central cleanup - calls all registered handlers in priority order
            // This includes: isolate_templates, template_registry, context_manager, etc.
            v8.cleanupAll(isolate, self.allocator);

            // Force V8 garbage collection before isolate disposal
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
            v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);
            v8.ffi.v8_Isolate_RequestGarbageCollection(isolate);
            v8.ffi.v8_Isolate_PerformMicrotaskCheckpoint(isolate);

            // Dispose isolate
            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_Isolate_Dispose(isolate);
        }

        // Cleanup WebIDL runtime
        runtime.deinitializeRuntime();

        self.initialized = false;
        self.allocator.destroy(self);
    }

    /// Navigate to a URL
    ///
    /// This destroys the current V8 context (if any) and creates a new one.
    /// Storage persists across navigations.
    ///
    /// Navigation flow:
    /// 1. Destroy current V8 context (if any)
    /// 2. Create new V8 context
    /// 3. Register browser globals
    /// 4. Fetch URL content
    /// 5. Parse HTML and execute scripts
    /// 6. Fire DOMContentLoaded and load events
    pub fn navigate(self: *Browser, url: []const u8) !void {
        const isolate = self.isolate orelse return error.NotInitialized;

        // Destroy current context if any
        if (self.current_context) |old_ctx| {
            old_ctx.deinit();
            self.allocator.destroy(old_ctx);
            self.current_context = null;
        }

        // Create new context
        const ctx = try Context.init(
            self.allocator,
            isolate,
            self.storage,
            url,
            self.event_loop,
        );
        errdefer {
            ctx.deinit();
            self.allocator.destroy(ctx);
        }

        self.current_context = ctx;

        // Navigation loading is handled by Context.loadPage()
        try ctx.loadPage();
    }

    /// Reload the current page
    ///
    /// Re-navigates to the current URL, destroying and recreating the context.
    pub fn reload(self: *Browser) !void {
        const ctx = self.current_context orelse return error.NoContext;
        const url = try self.allocator.dupe(u8, ctx.url);
        defer self.allocator.free(url);
        try self.navigate(url);
    }

    /// Evaluate JavaScript in the current context
    ///
    /// Returns the result as a V8 Value pointer (caller must handle lifetime).
    pub fn evaluateScript(self: *Browser, script: []const u8) !?*v8.ffi.Value {
        const ctx = self.current_context orelse return error.NoContext;
        return ctx.evaluateScript(script);
    }

    /// Run the event loop until a condition is met or timeout
    ///
    /// Used for running async tests or waiting for page load.
    pub fn runEventLoop(self: *Browser, timeout_ms: u64) !void {
        const event_loop = self.event_loop orelse return error.NotInitialized;
        const start_time = std.time.milliTimestamp();

        while (true) {
            // Run one iteration
            _ = event_loop.eventLoop().runOnce();

            // Check timeout
            const now = std.time.milliTimestamp();
            const elapsed: u64 = @intCast(now - start_time);
            if (elapsed > timeout_ms) {
                return;
            }

            // Short sleep to avoid busy-waiting
            std.Thread.sleep(1 * std.time.ns_per_ms);
        }
    }

    /// Get the current URL
    pub fn getCurrentUrl(self: *Browser) ?[]const u8 {
        const ctx = self.current_context orelse return null;
        return ctx.url;
    }

    /// Check if browser is initialized
    pub fn isInitialized(self: *Browser) bool {
        return self.initialized and self.isolate != null;
    }

    /// Get the V8 isolate (for advanced usage)
    pub fn getIsolate(self: *Browser) ?*v8.ffi.Isolate {
        return self.isolate;
    }

    /// Get the current V8 context (for advanced usage)
    pub fn getV8Context(self: *Browser) ?*v8.ffi.Context {
        const ctx = self.current_context orelse return null;
        return ctx.v8_context;
    }

    /// Get the storage subsystem
    pub fn getStorage(self: *Browser) *Storage {
        return self.storage;
    }
};

test "Browser - basic lifecycle" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Note: This test requires V8 to be initialized, which may not be available
    // in all test environments. Skip if V8 is not available.
    var browser = Browser.init(allocator, .{
        .persist_storage = false, // Use memory-only storage for tests
    }) catch |err| {
        // V8 not available in test environment
        if (err == error.V8InitFailed) return;
        return err;
    };
    defer browser.deinit();

    try testing.expect(browser.isInitialized());
    try testing.expect(browser.getIsolate() != null);
}

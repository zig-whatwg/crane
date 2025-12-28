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
//! ## Snapshot Support
//!
//! For fast startup, the browser can use V8 heap snapshots containing pre-registered
//! WebIDL interfaces. When a snapshot is available:
//! - Isolate is created from snapshot (~2ms vs ~40ms fresh)
//! - Contexts skip interface registration (already in snapshot)
//!
//! Generate a snapshot:
//! ```bash
//! zig build snapshot-generator -- whatwg_snapshot.bin
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
const impls = @import("impls");
const namespaces = @import("namespaces");
const fetch = @import("fetch");
const network = fetch.network;
const html = @import("html");

const context_mod = @import("Context.zig");
const Context = context_mod.Context;
const storage_mod = @import("storage/Storage.zig");
const Storage = storage_mod.Storage;

/// Default snapshot file paths to check (in order of priority)
/// IMPORTANT: zig-out/bin/ is checked FIRST because it contains the freshly
/// generated snapshot from `zig build`. The root whatwg_snapshot.bin is a
/// committed fallback that may be stale after codegen changes.
const DEFAULT_SNAPSHOT_PATHS = [_][]const u8{
    "zig-out/bin/whatwg_snapshot.bin", // Zig build output (highest priority - always fresh)
    "whatwg_snapshot.bin", // Current directory (committed fallback)
    "../whatwg_snapshot.bin", // Parent directory (for tests run from subdirs)
};

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
    /// Path to V8 snapshot file (optional, auto-detected if null)
    /// Set to empty string "" to explicitly disable snapshot loading
    snapshot_path: ?[]const u8 = null,
    /// Whether to log performance information
    log_performance: bool = false,
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
    /// Whether isolate was created from a snapshot (affects context initialization)
    used_snapshot: bool,
    /// Async HTTP manager for non-blocking fetch()
    async_curl_manager: ?*network.AsyncCurlManager,

    /// Initialize a new Browser instance
    ///
    /// Creates a V8 isolate that will be reused across all navigations.
    /// The isolate is only destroyed when the browser is deinitialized.
    ///
    /// If a V8 snapshot is available, uses it for fast isolate startup (~2ms vs ~40ms).
    /// Note: The snapshot contains V8 builtins only. WebIDL interfaces are registered
    /// at runtime on each context creation.
    pub fn init(allocator: std.mem.Allocator, config: BrowserConfig) !*Browser {
        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(allocator);
        errdefer runtime.deinitializeRuntime();

        // Initialize V8 platform with proper flags for snapshot support.
        // This MUST use initializePlatformForSnapshots() to ensure flags are set
        // BEFORE platform initialization, which is critical for snapshot loading.
        // The flags (--hash-seed=0, --predictable) ensure deterministic behavior
        // between snapshot creation and loading.
        v8.initializePlatformForSnapshots();

        // Determine snapshot path to use
        const snapshot_path = resolveSnapshotPath(config.snapshot_path);
        const use_snapshot = snapshot_path != null;

        // Create V8 isolate (from snapshot if available)
        var isolate: *v8.ffi.Isolate = undefined;
        var used_snapshot = false;

        if (use_snapshot) {
            // Register external references for snapshot loading
            // These MUST match the order used when creating the snapshot
            registerSnapshotExternalReferences();

            // Try to initialize from snapshot
            const init_result = v8.snapshot_loader.initializeV8(allocator, .{
                .snapshot_path = snapshot_path,
                .log_performance = config.log_performance,
            }) catch |err| {
                if (config.log_performance) {
                    std.log.warn("Snapshot initialization failed: {}, falling back to fresh isolate", .{err});
                }
                // Fall through to create fresh isolate
                isolate = v8.ffi.v8_Isolate_New() orelse {
                    runtime.deinitializeRuntime();
                    return error.V8InitFailed;
                };
                v8.ffi.v8_Isolate_Enter(isolate);
                used_snapshot = false;
                // Continue execution below
                return initBrowserWithIsolate(allocator, isolate, used_snapshot, config);
            };

            isolate = init_result.isolate;
            used_snapshot = init_result.used_snapshot;

            // Note: v8_Isolate_Enter is already called by snapshot_loader.initializeV8
            // when it creates the isolate

            if (config.log_performance) {
                if (used_snapshot) {} else {}
            }
        } else {
            // No snapshot - create fresh isolate
            isolate = v8.ffi.v8_Isolate_New() orelse {
                runtime.deinitializeRuntime();
                return error.V8InitFailed;
            };
            v8.ffi.v8_Isolate_Enter(isolate);
        }

        return initBrowserWithIsolate(allocator, isolate, used_snapshot, config);
    }

    /// Complete browser initialization with an already-created isolate
    fn initBrowserWithIsolate(
        allocator: std.mem.Allocator,
        isolate: *v8.ffi.Isolate,
        used_snapshot: bool,
        config: BrowserConfig,
    ) !*Browser {
        errdefer {
            v8.ffi.v8_Isolate_Exit(isolate);
            v8.ffi.v8_Isolate_Dispose(isolate);
        }

        // Register V8 lifecycle cleanup handlers
        v8.registerBuiltinHandlers() catch |err| {
            std.debug.print("Warning: Failed to register lifecycle handlers: {}\n", .{err});
        };

        // Initialize isolate-scoped allocator for template caching
        // This allows FunctionTemplates to be cached at the isolate level.
        v8.isolate_allocator.initIsolateAllocator(isolate, allocator, false) catch |err| {
            // Already initialized is OK (e.g., from snapshot loading)
            if (err != error.AllocatorAlreadyInitialized) {
                std.debug.print("Warning: Failed to init isolate allocator: {}\n", .{err});
            }
        };

        // Create storage subsystem
        const storage = try Storage.init(allocator, config.storage_root, config.persist_storage);
        errdefer storage.deinit();

        // Create V8 event loop with timer support
        const event_loop = try allocator.create(v8.V8EventLoop);
        errdefer allocator.destroy(event_loop);
        event_loop.* = try v8.V8EventLoop.init(isolate, allocator);

        // Create async curl manager for non-blocking fetch()
        // Initialize curl globally first (safe to call multiple times)
        try network.globalInit();
        const async_curl = try network.AsyncCurlManager.init(allocator);
        errdefer async_curl.deinit();

        // Register curl manager with event loop so it gets polled
        // Note: AsyncCurlManager.Pollable and V8EventLoop.Pollable are structurally identical
        // but different types, so we cast the compatible struct
        const curl_pollable = async_curl.pollable();
        event_loop.setExternalPollable(.{
            .ptr = curl_pollable.ptr,
            .poll_fn = curl_pollable.poll_fn,
        });

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
            .used_snapshot = used_snapshot,
            .async_curl_manager = async_curl,
        };

        // Always create initial about:blank context - a real browser always has a window/document
        // Then navigate to initial URL if specified
        const initial_url = config.initial_url orelse "about:blank";
        try browser.navigate(initial_url, .window);

        return browser;
    }

    /// Resolve snapshot path from config or auto-detect
    fn resolveSnapshotPath(config_path: ?[]const u8) ?[]const u8 {
        // If explicitly set in config, use that
        if (config_path) |path| {
            // Empty string means explicitly disabled
            if (path.len == 0) return null;
            // Check if the file exists
            if (std.fs.cwd().access(path, .{})) |_| {
                return path;
            } else |_| {
                return null;
            }
        }

        // Auto-detect: check default paths
        for (DEFAULT_SNAPSHOT_PATHS) |path| {
            if (std.fs.cwd().access(path, .{})) |_| {
                return path;
            } else |_| {
                continue;
            }
        }

        return null;
    }

    /// Register external references required for snapshot loading
    ///
    /// NOTE: With the minimal snapshot approach, the snapshot only contains V8 builtins,
    /// NOT WebIDL interfaces. Therefore, no external references are needed for loading.
    /// WebIDL interfaces are registered at runtime on fresh contexts.
    fn registerSnapshotExternalReferences() void {
        // Register external references required for snapshot loading.
        // This must be called before initializeV8() when using snapshots.
        // The snapshot_loader's registerExternalReferences() registers
        // C++ and Zig callbacks that V8 needs to properly deserialize
        // the snapshot's function pointers.
        v8.snapshot_loader.registerExternalReferences();
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

        // Cleanup async curl manager
        if (self.async_curl_manager) |curl_mgr| {
            curl_mgr.deinit();
            // Note: deinit deallocates self, no need for allocator.destroy
        }
        network.globalCleanup();

        // Use the isolate lifecycle manager for centralized cleanup
        // This ensures all V8-dependent modules are cleaned up in the correct order
        // See src/runtime/engines/v8/isolate_lifecycle.zig for the full list

        if (self.isolate) |isolate| {
            // IMPORTANT: Clean up orphaned DOM nodes BEFORE cleaning up V8 resources!
            // DOM node internal states may use the isolate's allocator, which gets
            // freed by cleanupAll(). We must clean them up while allocators are valid.
            impls.cleanup.cleanupAllDomRegistries();

            // Clean up global worker threading state (EventWakeup, worker registry HashMap)
            html.workers.ThreadedWorkerRegistry.deinit();

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

            // Clean up snapshot data that was allocated during V8 initialization.
            // This must be done AFTER the isolate is disposed because V8 keeps a
            // reference to the snapshot data for lazy deserialization.
            v8.snapshot_loader.cleanupSnapshotData();
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
    /// 3. Register browser globals (skipped if using snapshot)
    /// 4. Fetch URL content
    /// 5. Parse HTML and execute scripts
    /// 6. Fire DOMContentLoaded and load events
    pub fn navigate(self: *Browser, url: []const u8, context_type: context_mod.ContextType) !void {
        const isolate = self.isolate orelse return error.NotInitialized;

        // Terminate all workers from the previous context before destroying it.
        // This prevents workers from spinning indefinitely after their context is gone.
        html.workers.ThreadedWorkerRegistry.terminateAllWorkers();

        // Destroy current context if any
        if (self.current_context) |old_ctx| {
            old_ctx.deinit();
            self.allocator.destroy(old_ctx);
            self.current_context = null;
        }

        // Create new context
        // Pass used_snapshot flag so Context knows whether to skip initializeBindings
        // Pass network_manager for async fetch()
        const ctx = try Context.init(
            self.allocator,
            isolate,
            self.storage,
            url,
            self.event_loop,
            context_type,
            self.used_snapshot,
            @ptrCast(self.async_curl_manager),
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
        const context_type = ctx.context_type;
        defer self.allocator.free(url);
        try self.navigate(url, context_type);
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
    ///
    /// Uses efficient wakeup mechanism when workers are active:
    /// - Workers signal via EventWakeup when posting messages
    /// - Main thread wakes immediately instead of polling at 1ms intervals
    /// - Falls back to short sleep if no wakeup is available
    pub fn runEventLoop(self: *Browser, timeout_ms: u64) !void {
        const event_loop = self.event_loop orelse return error.NotInitialized;
        const isolate = self.isolate orelse return error.NotInitialized;
        const start_time = std.time.milliTimestamp();

        var iteration: u32 = 0;
        while (true) {
            iteration += 1;

            // Run one iteration
            _ = event_loop.eventLoop().runOnce();

            // Flush pending worker messages to the main thread
            // Workers post messages via postMessage() which queue to pending_messages.
            // This transfers them to message_queue and dispatches to handlers.
            //
            // CRITICAL: Create a HandleScope before flushing worker messages.
            // Message dispatch can trigger V8 GC, which may fire weak callbacks.
            // Without a HandleScope, V8 crashes with "Cannot create a handle without a HandleScope".
            // This was discovered investigating Bus error crashes during WPT worker tests.
            {
                const handle_scope = v8.ffi.v8_HandleScope_New(isolate);
                defer if (handle_scope) |h| v8.ffi.v8_HandleScope_Dispose(h);
                impls.Worker.flushPendingWorkerMessages();
            }

            // Check timeout
            const now = std.time.milliTimestamp();
            const elapsed: u64 = @intCast(now - start_time);
            if (elapsed > timeout_ms) {
                return;
            }

            // Wait for worker wakeup or short timeout
            // This is the key optimization: instead of busy-polling at 1ms,
            // we wait on the wakeup primitive that workers signal when posting messages
            // Access through impls.Worker which has the ThreadedWorkerRegistry
            if (impls.Worker.getGlobalWorkerWakeup()) |wakeup| {
                // Wait up to 1ms for a signal, then loop to run event loop again
                _ = wakeup.wait(1) catch {};
            } else {
                // No wakeup available, fall back to short sleep
                std.Thread.sleep(1 * std.time.ns_per_ms);
            }
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

    /// Check if the browser was initialized from a V8 snapshot
    ///
    /// Returns true if the browser's isolate was created from a snapshot,
    /// which means interface bindings are pre-registered and context creation
    /// is faster.
    pub fn isUsingSnapshot(self: *Browser) bool {
        return self.used_snapshot;
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

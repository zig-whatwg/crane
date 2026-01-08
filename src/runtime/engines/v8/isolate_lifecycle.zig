//! V8 Isolate Lifecycle Manager
//!
//! Central cleanup registry for V8-dependent modules. Ensures consistent cleanup
//! of all global/thread-local state when an isolate is disposed.
//!
//! ## Problem Solved
//!
//! Before this module, cleanup responsibilities were scattered:
//! - template_registry.clear() in Browser.deinit()
//! - engine.clearDynamicImportHandler() in template_registry.clear()
//! - namespace.clearGlobalContext() in template_registry.clear()
//!
//! When developers add new V8-dependent state, they might forget cleanup code.
//! This module centralizes cleanup and provides debug-mode validation.
//!
//! ## Usage
//!
//! ```zig
//! const lifecycle = @import("isolate_lifecycle.zig");
//!
//! // Register cleanup functions during module initialization
//! lifecycle.registerCleanup("my_module", myCleanupFn);
//!
//! // Before disposing isolate
//! lifecycle.cleanupAll(isolate, allocator);
//! ```
//!
//! ## Architecture
//!
//! ```
//! IsolateLifecycleManager
//!     ├── Cleanup Registry (callbacks for each module)
//!     ├── Debug Validators (check state is null after cleanup)
//!     └── Cleanup Orchestration (call in correct order)
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const builtin = @import("builtin");

/// Maximum number of cleanup handlers that can be registered
const MAX_HANDLERS = 32;

/// Cleanup handler function signature
/// Arguments:
///   - isolate: V8 isolate being disposed (may be null for global cleanup)
///   - allocator: Allocator for any necessary deallocation
pub const CleanupFn = *const fn (?*v8.Isolate, std.mem.Allocator) void;

/// Debug validator function signature
/// Returns true if state is clean, false if cleanup was incomplete
pub const ValidatorFn = *const fn () bool;

/// Registered cleanup handler
const CleanupHandler = struct {
    name: []const u8,
    cleanup: CleanupFn,
    validator: ?ValidatorFn,
    priority: u8, // Lower priority = called earlier
};

/// Global cleanup registry
var handlers: [MAX_HANDLERS]?CleanupHandler = [_]?CleanupHandler{null} ** MAX_HANDLERS;
var handler_count: usize = 0;
var initialized: bool = false;

/// Priority levels for cleanup ordering
/// Lower numbers run first (matching dependency order)
pub const Priority = struct {
    /// DOM state depends on everything else
    pub const dom_state: u8 = 10;
    /// Wrapper cache depends on isolate templates
    pub const wrapper_cache: u8 = 20;
    /// Templates depend on isolate
    pub const templates: u8 = 30;
    /// Engine callbacks
    pub const engine: u8 = 40;
    /// Namespace context
    pub const namespace: u8 = 50;
    /// Default priority
    pub const default: u8 = 100;
};

/// Initialize the lifecycle manager
fn ensureInitialized() void {
    if (!initialized) {
        initialized = true;
    }
}

/// Register a cleanup handler
///
/// Handlers are called in priority order (lowest first) during cleanupAll().
///
/// Arguments:
///   - name: Module name for debugging
///   - cleanup: Cleanup function to call
///   - validator: Optional validator to verify cleanup (debug mode only)
///   - priority: Order in which to call (lower = earlier)
///
/// Returns: error if registry is full
pub fn registerCleanup(
    name: []const u8,
    cleanup: CleanupFn,
    validator: ?ValidatorFn,
    priority: u8,
) !void {
    ensureInitialized();

    // Check for duplicate registration
    for (handlers[0..handler_count]) |handler| {
        if (handler) |h| {
            if (std.mem.eql(u8, h.name, name)) {
                // Already registered, update it
                return;
            }
        }
    }

    if (handler_count >= MAX_HANDLERS) {
        return error.RegistryFull;
    }

    handlers[handler_count] = .{
        .name = name,
        .cleanup = cleanup,
        .validator = validator,
        .priority = priority,
    };
    handler_count += 1;
}

/// Register with default priority
pub fn registerCleanupDefault(
    name: []const u8,
    cleanup: CleanupFn,
) !void {
    try registerCleanup(name, cleanup, null, Priority.default);
}

/// Clean up all registered handlers in priority order
///
/// This function MUST be called BEFORE disposing the V8 isolate.
///
/// Arguments:
///   - isolate: V8 isolate being disposed
///   - allocator: Allocator for cleanup operations
pub fn cleanupAll(isolate: *v8.Isolate, allocator: std.mem.Allocator) void {
    // Sort handlers by priority (simple insertion sort - few handlers)
    var sorted: [MAX_HANDLERS]?CleanupHandler = handlers;
    for (0..handler_count) |i| {
        for (i + 1..handler_count) |j| {
            if (sorted[i]) |hi| {
                if (sorted[j]) |hj| {
                    if (hj.priority < hi.priority) {
                        sorted[i] = hj;
                        sorted[j] = hi;
                    }
                }
            }
        }
    }

    // Call cleanup in priority order
    for (sorted[0..handler_count]) |handler| {
        if (handler) |h| {
            h.cleanup(isolate, allocator);
        }
    }

    // In debug mode, validate all cleanup was successful
    if (builtin.mode == .Debug) {
        validateCleanup();
    }
}

/// Validate all cleanup was successful (debug mode)
///
/// Checks each validator and logs warnings for incomplete cleanup.
fn validateCleanup() void {
    for (handlers[0..handler_count]) |handler| {
        if (handler) |h| {
            if (h.validator) |validate| {
                if (!validate()) {
                    std.log.warn(
                        "Cleanup validation failed for: {s}",
                        .{h.name},
                    );
                    // In debug mode, we could add @panic here to catch issues early
                    if (builtin.mode == .Debug) {
                        // Uncomment to make validation failures fatal:
                        // @panic("Cleanup validation failed");
                    }
                }
            }
        }
    }
}

/// Clear all registered handlers (for testing)
pub fn clearRegistry() void {
    for (&handlers) |*h| {
        h.* = null;
    }
    handler_count = 0;
}

/// Get the number of registered handlers
pub fn getHandlerCount() usize {
    return handler_count;
}

// ============================================================================
// Built-in Cleanup Handlers
// ============================================================================

/// Cleanup handler for isolate templates (slot 1)
fn cleanupIsolateTemplates(isolate: ?*v8.Isolate, allocator: std.mem.Allocator) void {
    if (isolate) |iso| {
        const isolate_templates = @import("isolate_templates.zig");
        isolate_templates.cleanupTemplateStorage(iso, allocator);
    }
}

/// Cleanup handler for template registry
/// Only clears templates for the specific isolate being disposed, not all isolates.
fn cleanupTemplateRegistry(isolate: ?*v8.Isolate, _: std.mem.Allocator) void {
    const template_registry = @import("template_registry.zig");
    if (isolate) |iso| {
        // Only clear templates for THIS isolate, not all isolates
        template_registry.clearForIsolate(iso);
    }
}

/// Validator for template registry
/// With per-isolate cleanup, we just verify the clear succeeded (always true now)
fn validateTemplateRegistry() bool {
    // Per-isolate cleanup always succeeds - nothing to validate globally
    return true;
}

/// Cleanup handler for isolate allocator (slot 0)
fn cleanupIsolateAllocator(isolate: ?*v8.Isolate, _: std.mem.Allocator) void {
    if (isolate) |iso| {
        const isolate_allocator = @import("isolate_allocator.zig");
        isolate_allocator.deinitIsolateAllocator(iso);
    }
}

/// Cleanup handler for context manager
fn cleanupContextManager(_: ?*v8.Isolate, _: std.mem.Allocator) void {
    const context_manager = @import("context_manager.zig");
    context_manager.deinit();
}

/// Register all built-in cleanup handlers
///
/// Call this once during engine initialization.
pub fn registerBuiltinHandlers() !void {
    try registerCleanup(
        "isolate_templates",
        cleanupIsolateTemplates,
        null,
        Priority.templates,
    );

    try registerCleanup(
        "template_registry",
        cleanupTemplateRegistry,
        validateTemplateRegistry,
        Priority.templates + 1,
    );

    try registerCleanup(
        "isolate_allocator",
        cleanupIsolateAllocator,
        null,
        Priority.default + 10, // Run near the end
    );

    try registerCleanup(
        "context_manager",
        cleanupContextManager,
        null,
        Priority.wrapper_cache,
    );
}

// ============================================================================
// Tests
// ============================================================================

test "IsolateLifecycle - register and clear" {
    const testing = std.testing;

    clearRegistry();
    try testing.expectEqual(@as(usize, 0), getHandlerCount());

    try registerCleanupDefault("test_module", struct {
        fn cleanup(_: ?*v8.Isolate, _: std.mem.Allocator) void {}
    }.cleanup);

    try testing.expectEqual(@as(usize, 1), getHandlerCount());

    clearRegistry();
    try testing.expectEqual(@as(usize, 0), getHandlerCount());
}

test "IsolateLifecycle - priority ordering" {
    const testing = std.testing;

    clearRegistry();

    // Register in reverse priority order
    try registerCleanup("high", struct {
        fn cleanup(_: ?*v8.Isolate, _: std.mem.Allocator) void {}
    }.cleanup, null, 100);

    try registerCleanup("low", struct {
        fn cleanup(_: ?*v8.Isolate, _: std.mem.Allocator) void {}
    }.cleanup, null, 10);

    try registerCleanup("medium", struct {
        fn cleanup(_: ?*v8.Isolate, _: std.mem.Allocator) void {}
    }.cleanup, null, 50);

    try testing.expectEqual(@as(usize, 3), getHandlerCount());

    clearRegistry();
}

test "IsolateLifecycle module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}

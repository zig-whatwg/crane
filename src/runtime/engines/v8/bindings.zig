//! V8 WebIDL Bindings Entry Point
//!
//! This module provides the main entry point for V8 bindings using Zig's
//! comptime reflection system. It automatically generates V8 bindings from
//! generated WebIDL namespaces and interfaces.
//!
//! ## Architecture
//!
//! ```
//! IDL files → Parse → Generate Zig interfaces/namespaces
//!                              ↓
//!                         Comptime reflection
//!                              ↓
//!                         V8 bindings (this module)
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const v8_bindings = @import("v8/bindings.zig");
//!
//! // Initialize V8 bindings for all namespaces
//! v8_bindings.initializeNamespaces(isolate, context);
//!
//! // Now JavaScript can call:
//! // console.log("Hello from Zig!");
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const namespace = @import("namespace.zig");

// Import generated namespaces
const namespaces = @import("namespaces");
const console_ns = namespaces.console;

// ============================================================================
// Namespace Bindings
// ============================================================================

/// Console namespace V8 binding
pub const Console = namespace.V8Namespace(console_ns.console);

// ============================================================================
// Initialization
// ============================================================================

/// Initialize all namespace bindings in the global scope
///
/// This function registers all WebIDL namespaces as global objects in V8,
/// making them accessible from JavaScript.
///
/// Example JavaScript usage after initialization:
/// ```javascript
/// console.log("Hello from Zig!");
/// console.error("An error occurred");
/// console.time("operation");
/// // ... do work ...
/// console.timeEnd("operation");
/// ```
pub fn initializeNamespaces(
    isolate: *v8.Isolate,
    context: *v8.Context,
) void {
    Console.registerGlobal(isolate, context, "console");

    // Future namespaces will be added here as they're implemented:
    // GPU.registerGlobal(isolate, context, "GPU");
    // WebGL2.registerGlobal(isolate, context, "WebGL2RenderingContext");
    // etc.
}

/// Create a new V8 context with all WebIDL bindings
///
/// This is a convenience function that creates a V8 context and initializes
/// all WebIDL bindings in one call.
///
/// Note: This assumes you have a V8 isolate already created.
pub fn createContext(isolate: *v8.Isolate) *v8.Context {
    // Create new V8 context
    // TODO: Need to add context creation to FFI bindings
    // For now, assume context is created externally
    const context = v8.v8_Isolate_GetCurrentContext(isolate);

    // Initialize all bindings
    initializeNamespaces(isolate, context);

    return context;
}

// ============================================================================
// Metadata
// ============================================================================

/// Get list of all registered namespaces
///
/// Useful for debugging and introspection.
pub fn getRegisteredNamespaces() []const NamespaceInfo {
    return &.{
        .{
            .name = "console",
            .method_count = Console.all_methods.len,
        },
        // Add more as implemented
    };
}

/// Information about a registered namespace
pub const NamespaceInfo = struct {
    name: []const u8,
    method_count: usize,
};

// ============================================================================
// Testing
// ============================================================================

test "bindings module compiles" {
    const testing = std.testing;
    testing.refAllDecls(@This());
}

test "Console binding extracted methods" {
    const testing = std.testing;

    // Verify console namespace has methods
    try testing.expect(Console.all_methods.len > 0);

    // Check for known console methods
    var has_log = false;
    var has_error = false;
    var has_warn = false;

    for (Console.all_methods) |method| {
        if (std.mem.eql(u8, method.name, "log")) has_log = true;
        if (std.mem.eql(u8, method.name, "error")) has_error = true;
        if (std.mem.eql(u8, method.name, "warn")) has_warn = true;
    }

    try testing.expect(has_log);
    try testing.expect(has_error);
    try testing.expect(has_warn);
}

test "getRegisteredNamespaces" {
    const testing = std.testing;

    const registered = getRegisteredNamespaces();
    try testing.expectEqual(@as(usize, 1), registered.len);
    try testing.expectEqualStrings("console", registered[0].name);
}

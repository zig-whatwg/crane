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
const V8Namespace = @import("namespace.zig").V8Namespace;

// Import generated namespaces
const namespaces = @import("namespaces");

// Import Intl binding (pure Zig i18n implementation)
const intl_binding = @import("intl_binding.zig");

// ============================================================================
// Initialization
// ============================================================================

/// Initialize all namespace bindings in the global scope
///
/// This function registers all WebIDL namespaces as global objects in V8,
/// making them accessible from JavaScript. Uses comptime reflection to
/// automatically discover and register all namespaces.
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
    // Use comptime reflection to register ALL namespaces automatically
    const ns_decls = @typeInfo(namespaces).@"struct".decls;

    inline for (ns_decls) |decl| {
        const NamespaceType = @field(namespaces, decl.name);

        // Only bind types that have Meta (actual namespaces)
        if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
            // Use V8Namespace to create object with all methods bound
            const NamespaceBinding = V8Namespace(NamespaceType);
            NamespaceBinding.registerGlobal(isolate, context, decl.name);
        }
    }

    // Register Intl namespace (pure Zig i18n - replaces ICU)
    // This is special because it's not a WebIDL namespace
    intl_binding.registerGlobal(isolate, context);
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

/// Namespace registration info for debugging and introspection
pub const NamespaceInfo = struct {
    name: []const u8,
    method_count: usize,
};

/// Get list of all registered namespaces
pub fn getRegisteredNamespaces() []const NamespaceInfo {
    comptime {
        const ns_decls = @typeInfo(namespaces).@"struct".decls;
        var count: usize = 0;

        for (ns_decls) |decl| {
            const NamespaceType = @field(namespaces, decl.name);
            if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
                count += 1;
            }
        }

        var infos: [count]NamespaceInfo = undefined;
        var i: usize = 0;

        for (ns_decls) |decl| {
            const NamespaceType = @field(namespaces, decl.name);
            if (@typeInfo(NamespaceType) == .@"struct" and @hasDecl(NamespaceType, "Meta")) {
                const method_count = if (@hasDecl(NamespaceType.Meta, "methods"))
                    NamespaceType.Meta.methods.len
                else
                    0;

                infos[i] = .{
                    .name = decl.name,
                    .method_count = method_count,
                };
                i += 1;
            }
        }

        return &infos;
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "namespace discovery" {
    const registered = getRegisteredNamespaces();

    // Should find at least console namespace
    try testing.expect(registered.len >= 1);

    // Verify console namespace has methods
    var found_console = false;
    for (registered) |ns| {
        if (std.mem.eql(u8, ns.name, "console")) {
            found_console = true;
            // Check for known console methods
            try testing.expect(ns.method_count > 0);
            break;
        }
    }
    try testing.expect(found_console);
}

test "getRegisteredNamespaces returns expected namespaces" {
    const registered = getRegisteredNamespaces();

    // Should have at least console
    try testing.expect(registered.len >= 1);
    try testing.expectEqualStrings("console", registered[0].name);
}

//! V8 JavaScript Engine Integration
//!
//! This module provides complete V8 bindings for WebIDL using Zig's comptime
//! reflection system. It eliminates the need for generated C++ code by directly
//! introspecting generated Zig structs and creating V8 bindings at compile time.
//!
//! ## Architecture
//!
//! ```
//! IDL Files
//!    ↓ Parse (runtime)
//! Intermediate Representation (IR)
//!    ↓ Generate (runtime)
//! Zig Interfaces & Namespaces (generated/*.zig)
//!    ↓ Introspect (COMPTIME)
//! V8 Bindings (this module)
//!    ↓ Compile (COMPTIME)
//! Native Code (no generated C++!)
//! ```
//!
//! ## Key Innovation
//!
//! **Before (Old System)**:
//! - Generated 1,239 C++ files for V8 bindings
//! - Separate C++ compilation step
//! - Runtime code generation
//! - Type errors at runtime or in generated C++
//!
//! **After (This System)**:
//! - **ZERO generated C++ files**
//! - Single Zig compilation step
//! - Comptime code generation
//! - Type errors at compile time in original Zig source
//!
//! ## Modules
//!
//! - `ffi` - V8 C API bindings (opaque types, extern functions)
//! - `conversions` - Bidirectional type conversion (Zig ↔ V8)
//! - `namespace` - Comptime namespace binding generator
//! - `bindings` - Main entry point for all V8 bindings
//!
//! ## Usage
//!
//! ```zig
//! const v8 = @import("v8");
//!
//! // Initialize V8 bindings
//! v8.bindings.initializeNamespaces(isolate, context);
//!
//! // JavaScript can now call:
//! // console.log("Hello from Zig!");
//! ```

/// V8 C API FFI bindings
pub const ffi = @import("ffi.zig");

/// Type conversions between Zig and V8
pub const conversions = @import("conversions.zig");

/// Comptime namespace binding generator
pub const namespace_mod = @import("namespace.zig");
pub const V8Namespace = namespace_mod.V8Namespace;

/// Comptime interface binding generator
pub const interface_mod = @import("interface.zig");
pub const V8Interface = interface_mod.V8Interface;

/// V8 Context Manager - Maps V8 contexts to runtime contexts
pub const context_manager = @import("context_manager.zig");

/// Main bindings entry point
/// NOTE: Commented out because bindings.zig requires 'namespaces' module
///       which is only available in REPL context, not root module
/// TODO: Refactor to make bindings available conditionally
// pub const bindings = @import("v8/bindings.zig");
pub const interface_bindings = @import("interface_bindings.zig");

/// V8 Event Loop Integration
pub const event_loop_mod = @import("event_loop.zig");
pub const V8EventLoop = event_loop_mod.V8EventLoop;

// Re-export commonly used types for convenience
pub const Isolate = ffi.Isolate;
pub const Context = ffi.Context;
pub const Value = ffi.Value;
pub const Object = ffi.Object;
pub const String = ffi.String;
pub const Symbol = ffi.Symbol;
pub const FunctionCallbackInfo = ffi.FunctionCallbackInfo;

// Re-export main initialization function
// NOTE: Commented out because bindings is not available
// pub const initializeNamespaces = bindings.initializeNamespaces;

test "v8 module compiles" {
    const testing = @import("std").testing;
    testing.refAllDecls(@This());
}

//! JavaScriptCore JavaScript Engine Integration
//!
//! This module provides complete JSC bindings for WebIDL using Zig.
//! JSC is the JavaScript engine used in Safari and on iOS/macOS.
//!
//! ## Architecture
//!
//! JSC uses a different model than V8:
//! - JSContextGroupRef (similar to V8 Isolate) - execution environment
//! - JSGlobalContextRef (similar to V8 Context) - JavaScript execution context
//! - Reference counting (JSValueProtect/Unprotect) instead of V8 handles
//! - Pure C API (no C++ like V8)
//!
//! ## Key Differences from V8
//!
//! | Feature | V8 | JSC |
//! |---------|-----|-----|
//! | Execution env | Isolate | Context Group |
//! | Context | Context | Global Context |
//! | Object template | FunctionTemplate | JSClassRef |
//! | Value management | Handles/Scopes | Reference counting |
//! | API language | C++ | C |
//!
//! ## Modules
//!
//! - `ffi` - JSC C API bindings (JSContextRef, JSValueRef, etc.)
//! - `engine` - Main JSC engine interface (implements EngineInterface)
//! - `binding` - EngineBinding implementation for WebIDL support
//!
//! ## Usage
//!
//! ```zig
//! const jsc = @import("jsc");
//!
//! // Create a JSC context
//! const ctx = jsc.ffi.JSGlobalContextCreate(null);
//! defer jsc.ffi.JSGlobalContextRelease(ctx);
//!
//! // Use the engine binding for WebIDL interfaces
//! const binding = jsc.jsc_engine_binding;
//! ```

/// JSC C API FFI bindings
pub const ffi = @import("ffi.zig");

/// JSC Engine Interface (implements runtime.EngineInterface)
pub const engine = @import("engine.zig");
pub const jsc_engine_interface = engine.jsc_engine_interface;

/// JSC Engine Binding (implements runtime.EngineBinding)
pub const binding_mod = @import("binding.zig");
pub const jsc_engine_binding = binding_mod.jsc_engine_binding;

// Re-export commonly used types
pub const JSContextGroupRef = ffi.JSContextGroupRef;
pub const JSGlobalContextRef = ffi.JSGlobalContextRef;
pub const JSContextRef = ffi.JSContextRef;
pub const JSValueRef = ffi.JSValueRef;
pub const JSObjectRef = ffi.JSObjectRef;
pub const JSStringRef = ffi.JSStringRef;
pub const JSClassRef = ffi.JSClassRef;
pub const JSClassDefinition = ffi.JSClassDefinition;

// Re-export binding types
pub const EngineBinding = binding_mod.EngineBinding;
pub const BindingError = binding_mod.BindingError;
pub const TemplateHandle = binding_mod.TemplateHandle;

// Registry management
pub const initRegistry = binding_mod.initRegistry;
pub const deinitRegistry = binding_mod.deinitRegistry;

test "jsc module compiles" {
    const testing = @import("std").testing;
    testing.refAllDecls(@This());
}

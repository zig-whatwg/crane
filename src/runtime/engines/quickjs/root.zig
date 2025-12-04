//! QuickJS Engine Integration
//!
//! This module provides QuickJS JavaScript engine bindings for the WHATWG
//! runtime. QuickJS is a small and embeddable JavaScript engine that supports
//! ES2020 specifications.
//!
//! ## Key Features
//!
//! - Small footprint (~210KB binary size)
//! - ES2020 specification support
//! - Async/await and generators
//! - Promise support
//! - BigInt support
//! - Modules (ES6 and CommonJS)
//!
//! ## Usage
//!
//! ```zig
//! const quickjs = @import("quickjs");
//!
//! // Create runtime and context
//! const rt = quickjs.ffi.JS_NewRuntime();
//! defer quickjs.ffi.JS_FreeRuntime(rt);
//!
//! const ctx = quickjs.ffi.JS_NewContext(rt);
//! defer quickjs.ffi.JS_FreeContext(ctx);
//!
//! // Use the engine interface
//! const engine = &quickjs.engine.quickjs_engine_interface;
//!
//! // Use the binding interface
//! const binding = &quickjs.binding.quickjs_engine_binding;
//! ```
//!
//! ## Architecture
//!
//! QuickJS uses a simpler model than V8/JSC:
//! - JSRuntime: Manages memory and GC (like V8's Isolate)
//! - JSContext: Execution context (like V8's Context)
//! - JSValue: 64-bit tagged union (not a pointer like V8/JSC handles)
//! - Reference counting via JS_DupValue/JS_FreeValue
//!
//! ## Memory Management
//!
//! QuickJS uses reference counting for values:
//! - JS_DupValue: Increment reference count
//! - JS_FreeValue: Decrement reference count
//! - Objects are garbage collected when reference count reaches zero
//!
//! ## Thread Safety
//!
//! QuickJS is single-threaded by design. Each JSRuntime must be used from
//! a single thread. For multi-threaded applications, create separate runtimes
//! for each thread.

/// QuickJS C API FFI bindings
pub const ffi = @import("ffi.zig");

/// QuickJS EngineInterface implementation
pub const engine = @import("engine.zig");

/// QuickJS EngineBinding implementation
pub const binding = @import("binding.zig");

// Re-export commonly used types
pub const JSRuntime = ffi.JSRuntime;
pub const JSContext = ffi.JSContext;
pub const JSValue = ffi.JSValue;
pub const JSAtom = ffi.JSAtom;
pub const JSClassID = ffi.JSClassID;
pub const JSClassDef = ffi.JSClassDef;

/// QuickJS EngineInterface VTable
pub const quickjs_engine_interface = engine.quickjs_engine_interface;

/// QuickJS EngineBinding VTable
pub const quickjs_engine_binding = binding.quickjs_engine_binding;

// Re-export registry initialization
pub const initRegistry = binding.initRegistry;
pub const deinitRegistry = binding.deinitRegistry;

test {
    // Run all tests from submodules
    @import("std").testing.refAllDecls(@This());
}

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

/// V8 Engine Interface (implements runtime.EngineInterface)
/// Use this to create engine-agnostic contexts that work with V8
pub const engine = @import("engine.zig");
pub const v8_engine_interface = engine.v8_engine_interface;

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

/// External references registry for V8 snapshots
pub const external_references = @import("external_references.zig");

/// V8 Event Loop Integration
pub const event_loop_mod = @import("event_loop.zig");
pub const V8EventLoop = event_loop_mod.V8EventLoop;

/// V8 Promise Integration (Phase 2: Runtime Infrastructure)
pub const promise_mod = @import("promise.zig");
pub const Promise = promise_mod.Promise;
pub const invokeCallback = promise_mod.invokeCallback;

/// Streams API Callback Helpers (Phase 3: Runtime Infrastructure)
pub const streams_callbacks = @import("streams_callbacks.zig");

/// Zig to V8 Callback Wrappers (Phase 5: Streams Integration)
pub const zig_callbacks = @import("zig_callbacks.zig");

/// WrapperTypeInfo for type-safe V8 object unwrapping
pub const wrapper_type_info_mod = @import("wrapper_type_info.zig");
pub const WrapperTypeInfo = wrapper_type_info_mod.WrapperTypeInfo;
pub const TypeTag = wrapper_type_info_mod.TypeTag;
pub const WrapperClassId = wrapper_type_info_mod.WrapperClassId;
pub const TypeRegistry = wrapper_type_info_mod.TypeRegistry;
pub const getGlobalRegistry = wrapper_type_info_mod.getGlobalRegistry;
pub const INTERNAL_FIELD_COUNT = wrapper_type_info_mod.INTERNAL_FIELD_COUNT;

/// DOM WrapperTypeInfo definitions (pre-defined until codegen generates them)
pub const dom_type_info = @import("dom_type_info.zig");

/// V8 Callback Wrapper for callback interfaces (EventListener, NodeFilter, etc.)
pub const callback_wrapper_mod = @import("callback_wrapper.zig");
pub const CallbackWrapper = callback_wrapper_mod.CallbackWrapper;
pub const EventListenerCallback = callback_wrapper_mod.EventListenerCallback;
pub const createCallbackFromV8Value = callback_wrapper_mod.createFromV8Value;

/// V8 Wrapper Identity Cache - Maintains 1:1 mapping between instances and V8 wrappers
pub const wrapper_cache_mod = @import("wrapper_cache.zig");
pub const WrapperCache = wrapper_cache_mod.WrapperCache;

/// libuv FFI bindings for timer support
pub const libuv = @import("libuv.zig");

/// libuv-based timer manager for V8 isolates
pub const libuv_timer = @import("libuv_timer.zig");
pub const LibuvTimerManager = libuv_timer.LibuvTimerManager;

/// Template registry for wrapping Zig instances as V8 objects
pub const template_registry = @import("template_registry.zig");

/// Isolate-local template storage (per-isolate HashMap for templates)
pub const isolate_templates = @import("isolate_templates.zig");
pub const IsolateTemplates = isolate_templates.IsolateTemplates;
pub const getOrCreateTemplateStorage = isolate_templates.getOrCreateTemplateStorage;
pub const getTemplateStorage = isolate_templates.getTemplateStorage;
pub const cleanupTemplateStorage = isolate_templates.cleanupTemplateStorage;

/// Isolate allocator (per-isolate memory management)
pub const isolate_allocator = @import("isolate_allocator.zig");

/// Isolate lifecycle manager (central cleanup registry)
pub const isolate_lifecycle = @import("isolate_lifecycle.zig");
pub const registerCleanup = isolate_lifecycle.registerCleanup;
pub const registerCleanupDefault = isolate_lifecycle.registerCleanupDefault;
pub const cleanupAll = isolate_lifecycle.cleanupAll;
pub const registerBuiltinHandlers = isolate_lifecycle.registerBuiltinHandlers;

/// RAII Handle Wrappers for V8 memory safety
pub const handles = @import("handles.zig");
pub const V8Value = handles.V8Value;
pub const V8String = handles.V8String;
pub const V8Object = handles.V8Object;
pub const V8Array = handles.V8Array;
pub const V8Function = handles.V8Function;
pub const V8Promise = handles.V8Promise;
pub const V8PromiseResolver = handles.V8PromiseResolver;
pub const V8Context = handles.V8Context;
pub const V8Script = handles.V8Script;
pub const V8Module = handles.V8Module;
pub const HandleBag = handles.HandleBag;

/// Global Handle Management for cross-scope persistence
/// Use GlobalHandle to store V8 callbacks that need to survive HandleScope destruction
pub const global_handles = @import("global_handles.zig");
pub const GlobalHandle = global_handles.GlobalHandle;
pub const OptionalGlobalHandle = global_handles.OptionalGlobalHandle;
pub const disposeOptionalGlobalHandle = global_handles.disposeOptional;
pub const createOptionalGlobalHandle = global_handles.createOptional;

/// Pointer Tagging for anyopaque type discrimination
/// Use when anyopaque values could be Global handles, runtime.Instance, or Local values
pub const pointer_tag = @import("pointer_tag.zig");
pub const AnyopaqueTag = pointer_tag.AnyopaqueTag;
pub const tagPointer = pointer_tag.tagPointer;
pub const tagConstPointer = pointer_tag.tagConstPointer;
pub const untagPointer = pointer_tag.untagPointer;
pub const isTaggedPointer = pointer_tag.isTagged;
pub const getPointerTag = pointer_tag.getTag;

/// Type-Safe JavaScript Value Representation
/// Use JSValue instead of *const anyopaque for type safety
pub const js_value = @import("js_value.zig");
pub const JSValue = js_value.JSValue;
pub const OptionalJSValue = js_value.OptionalJSValue;

/// Type-Safe Stored Error for Stream Implementations
/// Use StoredError instead of stored_error: ?*anyopaque
pub const stored_error = @import("stored_error.zig");
pub const StoredError = stored_error.StoredError;

/// Thread safety primitives for V8 isolate access
pub const locker = @import("locker.zig");
pub const IsolateLock = locker.IsolateLock;
pub const IsolateUnlock = locker.IsolateUnlock;
pub const ThreadCheck = locker.ThreadCheck;

/// Snapshot-based V8 initialization for fast startup
pub const snapshot_loader = @import("snapshot_loader.zig");
pub const initializeV8FromSnapshot = snapshot_loader.initializeV8;
pub const SnapshotInitResult = snapshot_loader.InitResult;
pub const SnapshotInitOptions = snapshot_loader.InitOptions;

/// Bfcache (Back-Forward Cache) Frozen Context Manager
pub const frozen_context_manager = @import("frozen_context_manager.zig");
pub const FrozenContextManager = frozen_context_manager.FrozenContextManager;
pub const FrozenContext = frozen_context_manager.FrozenContext;
pub const FrozenTimer = frozen_context_manager.FrozenTimer;

// Re-export commonly used types for convenience
pub const Isolate = ffi.Isolate;
pub const Context = ffi.Context;
pub const Value = ffi.Value;
pub const Object = ffi.Object;
pub const Function = ffi.Function;
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

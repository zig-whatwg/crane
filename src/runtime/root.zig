//! WebIDL Runtime Library
//!
//! This module provides runtime support for generated WebIDL bindings.
//!
//! Core Components:
//! - Instance: WebIDL interface instances with state and vtable
//! - VTable: Virtual function table for interface methods
//! - Type system: WebIDL types (DOMString, sequences, etc.)
//! - Timer: Host-agnostic timer interface for setTimeout/clearTimeout

const std = @import("std");

pub const Instance = @import("instance.zig").Instance;

/// CEReactions - Custom Element Reactions
///
/// Stubs for DOM mutation tracking per Custom Elements spec.
/// Used by [CEReactions] extended attribute in WebIDL.
pub const CEReactions = struct {
    pub fn begin() void {
        // TODO: Implement Custom Element reaction queue
    }

    pub fn end() void {
        // TODO: Invoke queued Custom Element callbacks
    }
};
pub const VTable = @import("instance.zig").VTable;
pub const MethodMap = @import("instance.zig").MethodMap;
pub const Method = @import("instance.zig").Method;

// Runtime context and logging
pub const Context = @import("context.zig").Context;
pub const ContextData = @import("context.zig").ContextData;
pub const ConsoleState = @import("context.zig").ConsoleState;
pub const createNullContext = @import("context.zig").createNullContext;
pub const Logger = @import("logger.zig").Logger;

// Realm and context type infrastructure (WHATWG HTML/WebIDL)
pub const realm = @import("realm.zig");
pub const ContextType = realm.ContextType;
pub const GlobalScopeKind = realm.GlobalScopeKind;
pub const Exposure = realm.Exposure;
pub const RealmInfo = realm.RealmInfo;
pub const Realm = realm.Realm;
pub const Intrinsics = realm.Intrinsics;
pub const LogLevel = @import("logger.zig").LogLevel;

// Environment Settings Object (WHATWG HTML §8.1.5)
pub const environment_settings = @import("environment_settings.zig");
pub const EnvironmentSettingsObject = environment_settings.EnvironmentSettingsObject;
pub const Origin = environment_settings.Origin;
pub const PolicyContainer = environment_settings.PolicyContainer;
pub const ConsoleValue = @import("console_value.zig").ConsoleValue;

// Engine-agnostic callback wrapper for callback interfaces
// (EventListener, NodeFilter, XPathNSResolver)
pub const CallbackWrapper = @import("callback_wrapper.zig").CallbackWrapper;

// Engine-agnostic JavaScript value type
// Use this in impl files instead of v8.JSValue
pub const js_value = @import("js_value.zig");
pub const JSValue = js_value.JSValue;
pub const OptionalJSValue = js_value.OptionalJSValue;

// WebIDL type system
pub const types = @import("types.zig");
pub const DOMString = types.DOMString;
pub const USVString = types.USVString;
pub const ByteString = types.ByteString;

// WebIDL primitive types
pub const Boolean = types.Boolean;
pub const Long = types.Long;
pub const UnsignedLong = types.UnsignedLong;
pub const LongLong = types.LongLong;
pub const UnsignedLongLong = types.UnsignedLongLong;
pub const Float = types.Float;
pub const Double = types.Double;
pub const Any = types.Any;
pub const Object = types.Object;

// WebIDL parameterized types
pub const FrozenArray = types.FrozenArray;
pub const sequence = types.sequence;
pub const Promise = types.Promise;
pub const ObservableArray = types.ObservableArray;
pub const ObservableArrayExotic = @import("observable_array_exotic.zig");
pub const record = types.record;

// JavaScript built-in types (V8 provides these, we define Zig-side wrappers)
// These wrap V8's ArrayBuffer/TypedArray objects
pub const ArrayBuffer = types.ArrayBuffer;
pub const SharedArrayBuffer = types.SharedArrayBuffer;
pub const DataView = types.DataView;
pub const Int8Array = types.Int8Array;
pub const Int16Array = types.Int16Array;
pub const Int32Array = types.Int32Array;
pub const Uint8Array = types.Uint8Array;
pub const Uint8ClampedArray = types.Uint8ClampedArray;
pub const Uint16Array = types.Uint16Array;
pub const Uint32Array = types.Uint32Array;
pub const Float32Array = types.Float32Array;
pub const Float64Array = types.Float64Array;
pub const BigInt64Array = types.BigInt64Array;
pub const BigUint64Array = types.BigUint64Array;

// ArrayBufferView introspection for Streams BYOB operations
pub const arraybuffer_view = @import("arraybuffer_view.zig");

// Memory allocators
pub const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
pub const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

// Compile-time utilities
pub const buildVTable = @import("vtable_builder.zig").buildVTable;
pub const buildVTableWithDeinit = @import("vtable_builder.zig").buildVTableWithDeinit;
pub const FlattenedState = @import("field_merger.zig").FlattenedState;

// GC integration
pub const gc = @import("gc_integration.zig");
pub const onObjectFreed = gc.onObjectFreed;
pub const onGCSweep = gc.onGCSweep;
pub const GCStats = gc.GCStats;

// Cleanup coordination (RC2 fix - prevents dual cleanup path conflicts)
pub const cleanup_coordinator = @import("cleanup_coordinator.zig");
pub const CleanupCoordinator = cleanup_coordinator.CleanupCoordinator;
pub const CleanupPhase = cleanup_coordinator.CleanupPhase;
pub const CleanupStats = cleanup_coordinator.CleanupStats;
pub const isContextTearingDown = cleanup_coordinator.isContextTearingDown;

// Instance lifecycle tracking (RC2 fix - tracks cleanup state per instance)
pub const instance_lifecycle = @import("instance_lifecycle.zig");
pub const LifecycleFlags = instance_lifecycle.LifecycleFlags;

// Internal state registry and accessors
// Provides type-safe access to impl internal state from external code
pub const internal_state = @import("internal_state.zig");
pub const getInternal = internal_state.getInternal;
pub const setInternal = internal_state.setInternal;
pub const removeInternal = internal_state.removeInternal;
pub const hasInternal = internal_state.hasInternal;
pub const resetInternalStateRegistry = internal_state.resetRegistry;
pub const initInternalStateRegistry = internal_state.initRegistry;

// JS Engine abstraction
pub const jsengine = @import("jsengine.zig");
pub const EngineInterface = @import("engine_interface.zig").EngineInterface;
pub const EngineError = @import("engine_interface.zig").EngineError;
pub const MainThreadCallback = @import("engine_interface.zig").MainThreadCallback;
pub const PromiseFulfillCallback = @import("engine_interface.zig").PromiseFulfillCallback;
pub const PromiseRejectCallback = @import("engine_interface.zig").PromiseRejectCallback;
pub const ForEachCallback = @import("engine_interface.zig").ForEachCallback;
pub const stub_engine = @import("engine_interface.zig").stub_engine;

// Engine Context abstraction - type-safe wrapper for engine_ctx pointers
// Replaces direct use of engine_ctx: *anyopaque with structured type
pub const engine_context = @import("engine_context.zig");
pub const EngineContext = engine_context.EngineContext;
pub const EngineType = engine_context.EngineType;
pub const OptionalEngineContext = engine_context.OptionalEngineContext;

// Engine Binding abstraction (WebIDL binding generation)
pub const engine_binding = @import("engine_binding.zig");
pub const EngineBinding = engine_binding.EngineBinding;
pub const BindingError = engine_binding.BindingError;
pub const InterfaceBindingConfig = engine_binding.InterfaceBindingConfig;
pub const TemplateHandle = engine_binding.TemplateHandle;
pub const stub_binding = engine_binding.stub_binding;

// WebIDL binding descriptor types
pub const binding_types = @import("binding_types.zig");
pub const TypeDescriptor = binding_types.TypeDescriptor;
pub const TypeKind = binding_types.TypeKind;
pub const PrimitiveType = binding_types.PrimitiveType;
pub const MethodDescriptor = binding_types.MethodDescriptor;
pub const PropertyDescriptor = binding_types.PropertyDescriptor;
pub const InterfaceDescriptor = binding_types.InterfaceDescriptor;
pub const DictionaryDescriptor = binding_types.DictionaryDescriptor;
pub const EnumDescriptor = binding_types.EnumDescriptor;
pub const CallbackDescriptor = binding_types.CallbackDescriptor;

// Binding generator (comptime interface descriptor generation)
pub const binding_generator = @import("binding_generator.zig");
pub const InterfaceBindingGenerator = binding_generator.InterfaceBindingGenerator;
pub const generateDescriptor = binding_generator.generateDescriptor;
pub const getDescriptorPtr = binding_generator.getDescriptorPtr;

// NOTE: V8 engine is in src/runtime/engines/v8/ but is imported as a SEPARATE module.
// It is NOT part of the runtime module to avoid circular dependencies.
// Use @import("v8") to access V8 bindings and v8.engine for the EngineInterface.

// Timer interface - Host-agnostic timer support for setTimeout/clearTimeout
// Each host (V8+libuv, etc.) provides its own implementation
pub const timer = @import("timer.zig");
pub const TimerId = timer.TimerId;
pub const TimerCallback = timer.TimerCallback;
pub const TimerInterface = timer.TimerInterface;
pub const TimerVTable = timer.TimerVTable;
pub const TimerError = timer.TimerError;

// Network pollable interface - Host-agnostic async HTTP support
// Used by call_fetch to make non-blocking HTTP requests
pub const network_pollable = @import("network_pollable.zig");
pub const NetworkPollable = network_pollable.NetworkPollable;

// Typed callback wrappers for type-safe callback handling
// Replaces *anyopaque user data with typed alternatives
pub const typed_callback = @import("typed_callback.zig");
pub const TypedCallback = typed_callback.TypedCallback;
pub const TypedTimerCallback = typed_callback.TypedTimerCallback;
pub const TypedMicrotaskCallback = typed_callback.TypedMicrotaskCallback;
pub const TypedGCCallback = typed_callback.TypedGCCallback;
pub const SelfContainedCallback = typed_callback.SelfContainedCallback;
// Work/completion callbacks for thread pool operations
pub const TypedWorkCallback = typed_callback.TypedWorkCallback;
pub const TypedCompletionCallback = typed_callback.TypedCompletionCallback;
pub const SelfContainedWorkCallback = typed_callback.SelfContainedWorkCallback;
// Promise callback types
pub const TypedPromiseFulfillCallback = typed_callback.TypedPromiseFulfillCallback;
pub const TypedPromiseRejectCallback = typed_callback.TypedPromiseRejectCallback;
pub const SelfContainedPromiseCallback = typed_callback.SelfContainedPromiseCallback;
// Context callback (for DOM/parser patterns)
pub const TypedContextCallback = typed_callback.TypedContextCallback;
// Legacy interop
pub const AnyopaqueCallback = typed_callback.AnyopaqueCallback;

// Convenience re-exports
pub const initRuntime = initializeRuntime;
pub const deinitRuntime = deinitializeRuntime;

// WebIDL helper functions
// These are used by generated code for validation and clamping

/// Clamp a numeric value to a valid range
/// Used by WebIDL operations that require clamping semantics
pub fn clamp(comptime T: type, value: anytype) T {
    const type_info = @typeInfo(T);

    // For integers, clamp to type min/max
    if (type_info == .int) {
        const min_val = std.math.minInt(T);
        const max_val = std.math.maxInt(T);

        // Convert input to i64/u64 for comparison
        const val_i64 = switch (@typeInfo(@TypeOf(value))) {
            .int => |int_info| if (int_info.signedness == .signed)
                @as(i64, @intCast(value))
            else
                @as(i64, @intCast(value)),
            .float => @as(i64, @intFromFloat(value)),
            else => @compileError("clamp requires numeric type"),
        };

        if (val_i64 < min_val) return min_val;
        if (val_i64 > max_val) return max_val;
        return @intCast(val_i64);
    }

    // For floats, just convert
    if (type_info == .float) {
        return @floatCast(value);
    }

    @compileError("clamp only supports integer and float types");
}

/// Check if a value is in valid range for target type
/// Used by WebIDL operations that require range checking
pub fn isInRange(comptime T: type, value: anytype) bool {
    const type_info = @typeInfo(T);

    if (type_info == .int) {
        const min_val = std.math.minInt(T);
        const max_val = std.math.maxInt(T);

        // Convert input for comparison
        const val_i64 = switch (@typeInfo(@TypeOf(value))) {
            .int => |int_info| if (int_info.signedness == .signed)
                @as(i64, @intCast(value))
            else
                @as(i64, @intCast(value)),
            .float => @as(i64, @intFromFloat(value)),
            else => return false,
        };

        return val_i64 >= min_val and val_i64 <= max_val;
    }

    return true; // Non-integers always in range
}

/// Initialize the WebIDL runtime
///
/// Must be called before using any runtime functionality.
/// Initializes both SlabAllocator and ArenaAllocator.
///
/// Thread safety: Not thread-safe, call once during startup
///
/// Example:
/// ```zig
/// const std = @import("std");
/// const runtime = @import("runtime");
///
/// pub fn main() !void {
///     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
///     defer _ = gpa.deinit();
///     const allocator = gpa.allocator();
///
///     runtime.initRuntime(allocator);
///     defer runtime.deinitRuntime();
///
///     // Use runtime...
/// }
/// ```
pub fn initializeRuntime(allocator: std.mem.Allocator) void {
    SlabAllocator.init(allocator);
    ArenaAllocator.init(allocator);
    // Initialize internal state registry with provided allocator
    // This prevents memory fragmentation from using page_allocator
    internal_state.initRegistry(allocator);
}

/// Deinitialize the WebIDL runtime
///
/// Frees all resources allocated by the runtime.
/// Must be called after all WebIDL objects have been freed.
///
/// Thread safety: Not thread-safe, call once during shutdown
pub fn deinitializeRuntime() void {
    // Call any registered cleanup hooks (e.g., EventTarget registry cleanup)
    if (runtime_cleanup_hook) |hook| {
        hook();
    }

    // Deinitialize instance lifecycle registry
    // This tracks cleanup state for instances (cleanup_started, cleanup_complete, etc.)
    instance_lifecycle.deinit();

    // Reset internal state registry
    // This removes all instance→InternalState mappings to prevent stale references
    // when running multiple tests sequentially (each test gets a fresh environment)
    internal_state.resetRegistry();

    ArenaAllocator.deinit();
    SlabAllocator.deinit();
}

/// Cleanup hook function type
pub const CleanupHookFn = *const fn () void;

/// Global cleanup hook (set by impls that need cleanup during deinit)
var runtime_cleanup_hook: ?CleanupHookFn = null;

/// Register a cleanup hook to be called during deinitializeRuntime
/// This allows impl modules to register cleanup without circular dependencies
pub fn registerCleanupHook(hook: CleanupHookFn) void {
    runtime_cleanup_hook = hook;
}

/// Set a property on a runtime.Instance target using JavaScript [[Set]] semantics
///
/// This is used by [PutForwards] extended attribute to forward property assignments.
/// Per WebIDL spec §4.3.10: the assignment is performed by invoking the [[Set]]
/// internal method of the object with the forwarded property name.
///
/// Arguments:
///   - target: The target runtime.Instance (e.g., CSSStyleDeclaration)
///   - property_name: Name of the property to set (e.g., "cssText")
///   - value: String value to assign
///
/// Errors:
///   - error.NoEngine if no JS engine is configured
///   - error.TypeError if target cannot have properties set
///   - error.OperationFailed if [[Set]] returns false
pub fn setPropertyOnInstance(target: *Instance, property_name: []const u8, value: DOMString) !void {
    // Context is already *ContextData
    const ctx = target.ctx;

    // Get the engine interface
    const engine = ctx.getEngine() orelse return error.NoEngine;

    // Get the engine context
    const engine_ctx = ctx.getEngineContext() orelse return error.NoEngine;

    // Get the JS wrapper cache from context
    const wrapper_cache = ctx.getV8WrapperCacheStorage() orelse return error.NoEngine;

    // Get the getWrapperForInstance function
    const getWrapper = engine.getWrapperForInstance orelse return error.NoEngine;

    // Get the JS wrapper for the target
    const target_wrapper = getWrapper(
        engine_ctx,
        wrapper_cache,
        target,
    ) orelse {
        // If no wrapper exists, the target hasn't been exposed to JS yet
        // This shouldn't happen in normal [PutForwards] usage
        return error.TypeError;
    };

    // Use engine's setPropertyOnObject to set the property with [[Set]] semantics
    const setProperty = engine.setPropertyOnObject orelse return error.NoEngine;
    // Convert DOMString to slice for the engine interface
    const value_slice = value.asSlice();
    try setProperty(engine_ctx, target_wrapper, property_name, value_slice);
}

/// Set a property on a JSValue using JavaScript [[Set]] semantics
///
/// This is used by [PutForwards] extended attribute when the target attribute returns
/// a JSValue (e.g., when [SameObject] caching is used). Per WebIDL spec §4.3.10:
/// [PutForwards=X] means setting the attribute forwards to property X on the attribute's value.
///
/// The target JSValue may be:
/// - A .handle (JS engine object) - property is set directly on the JS object
/// - An .instance (*Instance) - property is set on the JS wrapper for that instance
///
/// Arguments:
///   - target: The target JSValue (result of getting the attribute)
///   - instance: The originating instance (used to access engine context)
///   - property_name: Name of the forwarded property (e.g., "cssText")
///   - value: String value to assign
///
/// Errors:
///   - error.NoEngine if no JS engine is configured
///   - error.TypeError if target cannot have properties set
///   - error.OperationFailed if [[Set]] returns false
pub fn setPropertyOnJSValue(target: JSValue, instance: *Instance, property_name: []const u8, value: DOMString) !void {
    const ctx = instance.ctx;

    // Get the engine interface
    const engine = ctx.getEngine() orelse return error.NoEngine;

    // Get the engine context
    const engine_ctx = ctx.getEngineContext() orelse return error.NoEngine;

    // Get the setPropertyOnObject function
    const setProperty = engine.setPropertyOnObject orelse return error.NoEngine;

    // Convert DOMString to slice for the engine interface
    const value_slice = value.asSlice();

    // Handle different JSValue types
    switch (target) {
        .handle => |handle| {
            // Direct JS object handle - set property directly
            try setProperty(engine_ctx, handle.ptr, property_name, value_slice);
        },
        .instance => |inst| {
            // Zig instance - need to get its JS wrapper first
            const wrapper_cache = ctx.getV8WrapperCacheStorage() orelse return error.NoEngine;
            const getWrapper = engine.getWrapperForInstance orelse return error.NoEngine;
            const target_wrapper = getWrapper(engine_ctx, wrapper_cache, inst) orelse {
                return error.TypeError;
            };
            try setProperty(engine_ctx, target_wrapper, property_name, value_slice);
        },
        else => {
            // Other JSValue types (undefined, null, boolean, number, string) cannot have properties set
            return error.TypeError;
        },
    }
}

/// Define an own property on a runtime.Instance using JavaScript [[DefineOwnProperty]] semantics
///
/// This is used by [Replaceable] extended attribute to create own properties that shadow
/// the inherited getter. Per WebIDL spec §4.3.10: the setter steps are to perform
/// ? [[DefineOwnProperty]] on this with the attribute's identifier as the property name
/// and PropertyDescriptor{[[Value]]: V, [[Writable]]: true, [[Enumerable]]: true,
/// [[Configurable]]: true}.
///
/// Arguments:
///   - target: The target runtime.Instance (e.g., Window)
///   - property_name: Name of the property to define (e.g., "scrollX")
///   - value: Any JavaScript value to assign
///
/// Errors:
///   - error.NoEngine if no JS engine is configured
///   - error.TypeError if target cannot have properties defined
///   - error.OperationFailed if [[DefineOwnProperty]] returns false
pub fn defineOwnProperty(target: *Instance, property_name: []const u8, value: JSValue) !void {
    // Context is already *ContextData
    const ctx = target.ctx;

    // Get the engine interface
    const engine = ctx.getEngine() orelse return error.NoEngine;

    // Get the engine context
    const engine_ctx = ctx.getEngineContext() orelse return error.NoEngine;

    // Get the JS wrapper cache from context
    const wrapper_cache = ctx.getV8WrapperCacheStorage() orelse return error.NoEngine;

    // Get the getWrapperForInstance function
    const getWrapper = engine.getWrapperForInstance orelse return error.NoEngine;

    // Get the JS wrapper for the target
    const target_wrapper = getWrapper(
        engine_ctx,
        wrapper_cache,
        target,
    ) orelse {
        // If no wrapper exists, the target hasn't been exposed to JS yet
        // This shouldn't happen in normal [Replaceable] usage
        return error.TypeError;
    };

    // Use engine's defineOwnPropertyOnObject to define the property with [[DefineOwnProperty]] semantics
    const defineProperty = engine.defineOwnPropertyOnObject orelse return error.NoEngine;

    // Convert runtime.JSValue to engine-native value
    // This properly handles all JSValue variants (undefined, null, boolean, number, string, handle, instance)
    const convertValue = engine.convertJSValueToEngine orelse return error.NoEngine;
    const value_ptr = convertValue(engine_ctx, value) catch return error.TypeError;

    try defineProperty(engine_ctx, target_wrapper, property_name, value_ptr);
}

// Standard library dependency

// Unit tests
const testing = std.testing;

test "runtime exports" {
    // Verify all expected exports are available
    _ = Instance;
    _ = VTable;
    _ = MethodMap;
    _ = Method;

    _ = types;
    _ = DOMString;
    _ = USVString;
    _ = ByteString;

    _ = SlabAllocator;
    _ = ArenaAllocator;

    _ = buildVTable;
    _ = FlattenedState;

    _ = gc;
    _ = onObjectFreed;
    _ = onGCSweep;
    _ = GCStats;

    _ = initRuntime;
    _ = deinitRuntime;
}

test "initRuntime and deinitRuntime work" {
    initializeRuntime(testing.allocator);
    defer deinitializeRuntime();

    // Verify allocators are initialized and can allocate
    const slab = SlabAllocator.get();
    const arena = ArenaAllocator.get();

    // Can allocate after init
    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    const instance = try slab.alloc(&vtable);
    const value = try arena.create(u32);
    value.* = 42;

    try testing.expectEqual(@as(u32, 42), value.*);

    slab.free(instance);
}

test "initRuntime initializes both allocators" {
    initializeRuntime(testing.allocator);
    defer deinitializeRuntime();

    // SlabAllocator should be usable
    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };
    const inst = try SlabAllocator.get().alloc(&vtable);
    SlabAllocator.get().free(inst);

    // ArenaAllocator should be usable
    const val = try ArenaAllocator.get().create(u64);
    val.* = 123;
    try testing.expectEqual(@as(u64, 123), val.*);
}

test "convenience aliases work" {
    // initRuntime is an alias for initializeRuntime
    try testing.expect(initRuntime == initializeRuntime);
    try testing.expect(deinitRuntime == deinitializeRuntime);
}

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
pub const Exposure = realm.Exposure;
pub const RealmInfo = realm.RealmInfo;
pub const LogLevel = @import("logger.zig").LogLevel;
pub const ConsoleValue = @import("console_value.zig").ConsoleValue;

// Engine-agnostic callback wrapper for callback interfaces
// (EventListener, NodeFilter, XPathNSResolver)
pub const CallbackWrapper = @import("callback_wrapper.zig").CallbackWrapper;

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

// JS Engine abstraction
pub const jsengine = @import("jsengine.zig");
pub const EngineInterface = @import("engine_interface.zig").EngineInterface;
pub const EngineError = @import("engine_interface.zig").EngineError;
pub const MainThreadCallback = @import("engine_interface.zig").MainThreadCallback;
pub const PromiseFulfillCallback = @import("engine_interface.zig").PromiseFulfillCallback;
pub const PromiseRejectCallback = @import("engine_interface.zig").PromiseRejectCallback;
pub const stub_engine = @import("engine_interface.zig").stub_engine;

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
}

/// Deinitialize the WebIDL runtime
///
/// Frees all resources allocated by the runtime.
/// Must be called after all WebIDL objects have been freed.
///
/// Thread safety: Not thread-safe, call once during shutdown
pub fn deinitializeRuntime() void {
    ArenaAllocator.deinit();
    SlabAllocator.deinit();
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

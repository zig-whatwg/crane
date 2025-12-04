//! QuickJS Engine Binding Implementation
//!
//! This module implements the EngineBinding interface for QuickJS, providing
//! WebIDL binding generation capabilities on top of the base EngineInterface.
//!
//! ## Design
//!
//! The QuickJS EngineBinding:
//! 1. Composes with the quickjs_engine_interface (base operations)
//! 2. Implements all EngineBinding operations using QuickJS's JSClassDef APIs
//! 3. Uses JSClassID for interface templates (registered with JS_NewClass)
//! 4. Maintains wrapper identity through a class registry
//!
//! ## Key Differences from V8/JSC
//!
//! - QuickJS uses JSClassID (integer) instead of pointer-based templates
//! - QuickJS uses JSValue (64-bit tagged union) instead of pointer-based values
//! - QuickJS uses JS_SetOpaque/GetOpaque for internal data
//! - QuickJS is single-threaded (no isolate or context group concepts)
//! - Reference counting via JS_DupValue/JS_FreeValue

const std = @import("std");
const engine_binding = @import("../../engine_binding.zig");
const binding_types = @import("../../binding_types.zig");
const engine_interface = @import("../../engine_interface.zig");
const engine_mod = @import("engine.zig");
const ffi = @import("ffi.zig");

// Re-export types for convenience
pub const EngineBinding = engine_binding.EngineBinding;
pub const BindingError = engine_binding.BindingError;
pub const EngineError = engine_interface.EngineError;
pub const InterfaceDescriptor = binding_types.InterfaceDescriptor;
pub const InterfaceBindingConfig = engine_binding.InterfaceBindingConfig;
pub const TemplateHandle = engine_binding.TemplateHandle;
pub const TypeDescriptor = binding_types.TypeDescriptor;
pub const DictionaryDescriptor = binding_types.DictionaryDescriptor;
pub const EnumDescriptor = binding_types.EnumDescriptor;
pub const CallbackDescriptor = binding_types.CallbackDescriptor;

// =============================================================================
// Template Registry
// =============================================================================

/// Entry in the class registry
const ClassEntry = struct {
    class_id: ffi.JSClassID,
    name: []const u8,
    descriptor: *const InterfaceDescriptor,
    config: *const InterfaceBindingConfig,
};

/// Simple registry for QuickJS classes
var class_registry: std.StringHashMapUnmanaged(ClassEntry) = .{};
var registry_allocator: ?std.mem.Allocator = null;

/// Next class ID to allocate
var next_class_id: ffi.JSClassID = 1;

/// Initialize the registry with an allocator
pub fn initRegistry(allocator: std.mem.Allocator) void {
    registry_allocator = allocator;
}

/// Deinitialize the registry
pub fn deinitRegistry() void {
    if (registry_allocator) |alloc| {
        var it = class_registry.iterator();
        while (it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
        }
        class_registry.deinit(alloc);
    }
    registry_allocator = null;
}

/// Get a class by name
fn getClass(name: []const u8) ?ClassEntry {
    return class_registry.get(name);
}

/// Register a class
fn registerClass(name: []const u8, class_id: ffi.JSClassID, descriptor: *const InterfaceDescriptor, config: *const InterfaceBindingConfig) !void {
    const allocator = registry_allocator orelse return error.OutOfMemory;
    const name_copy = try allocator.dupe(u8, name);

    try class_registry.put(allocator, name_copy, .{
        .class_id = class_id,
        .name = name_copy,
        .descriptor = descriptor,
        .config = config,
    });
}

// =============================================================================
// QuickJS Engine Binding VTable
// =============================================================================

/// QuickJS implementation of the EngineBinding interface
pub const quickjs_engine_binding: EngineBinding = .{
    // Base EngineInterface (composition)
    .base = &engine_mod.quickjs_engine_interface,

    // Interface Registration
    .registerInterface = quickjsRegisterInterface,
    .registerDictionary = quickjsRegisterDictionary,
    .registerEnum = quickjsRegisterEnum,
    .registerCallback = quickjsRegisterCallback,

    // Template Management
    .getInterfaceTemplate = quickjsGetInterfaceTemplate,
    .createInstance = quickjsCreateInstance,
    .setPrototype = quickjsSetPrototype,
    .includeMixin = quickjsIncludeMixin,

    // Global Object Setup
    .exposeOnGlobal = quickjsExposeOnGlobal,
    .setupGlobalObject = quickjsSetupGlobalObject,

    // Value Conversion
    .toJSValue = quickjsToJSValue,
    .fromJSValue = quickjsFromJSValue,
    .isInstanceOf = quickjsIsInstanceOf,
    .unwrapInstance = quickjsUnwrapInstance,

    // Error Throwing
    .throwTypeError = quickjsThrowTypeError,
    .throwRangeError = quickjsThrowRangeError,
    .throwDOMException = quickjsThrowDOMException,

    // Async Support
    .createAsyncIterator = quickjsCreateAsyncIterator,
    .createReadableStream = quickjsCreateReadableStream,

    // Structured Clone Support
    .isSerializable = quickjsIsSerializable,
    .isTransferable = quickjsIsTransferable,

    // Metadata
    .name = "QuickJS",
    .version = "2024-01",
};

// =============================================================================
// Interface Registration
// =============================================================================

/// Register a WebIDL interface with QuickJS
fn quickjsRegisterInterface(
    engine_ctx: *anyopaque,
    descriptor: *const InterfaceDescriptor,
    config: *const InterfaceBindingConfig,
) (BindingError || EngineError)!TemplateHandle {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const rt = ffi.JS_GetRuntime(ctx);

    // Get interface name
    const name = std.mem.span(descriptor.name);

    // Check if already registered
    if (getClass(name)) |existing| {
        // Return a pointer to the class_id
        // Since class_id is a u32, we encode it as a pointer
        return @ptrFromInt(@as(usize, existing.class_id));
    }

    // Allocate a new class ID
    var class_id: ffi.JSClassID = 0;
    _ = ffi.JS_NewClassID(&class_id);

    // Build the class definition
    var class_def = ffi.JSClassDef{
        .class_name = descriptor.name,
        .finalizer = null,
        .gc_mark = null,
        .call = null,
        .exotic = null,
    };

    // Set up finalize callback if destructor provided
    if (config.destructor) |_| {
        class_def.finalizer = quickjsFinalizeCallback;
    }

    // Create the class
    const result = ffi.JS_NewClass(rt, class_id, &class_def);
    if (result < 0) {
        return BindingError.TemplateCreationFailed;
    }

    // Register in our registry
    registerClass(name, class_id, descriptor, config) catch {
        return BindingError.OutOfMemory;
    };

    // Return class_id encoded as a pointer
    return @ptrFromInt(@as(usize, class_id));
}

/// Finalize callback - called when QuickJS object is garbage collected
fn quickjsFinalizeCallback(rt: *ffi.JSRuntime, val: ffi.JSValue) callconv(.c) void {
    _ = rt;
    // Get the opaque data (Zig instance pointer)
    // Note: We need the class_id to get the opaque, but we don't have it here
    // In QuickJS, finalize callbacks don't receive the class_id
    // We'd need to store it in the opaque data structure
    const instance = ffi.JS_GetOpaque(val, 0);
    if (instance) |inst| {
        // TODO: Look up the destructor from the registry and call it
        _ = inst;
    }
}

/// Register a WebIDL dictionary type
fn quickjsRegisterDictionary(
    engine_ctx: *anyopaque,
    descriptor: *const DictionaryDescriptor,
) (BindingError || EngineError)!void {
    // Dictionaries in QuickJS are handled at runtime during type conversion
    _ = engine_ctx;
    _ = descriptor;
}

/// Register a WebIDL enumeration type
fn quickjsRegisterEnum(
    engine_ctx: *anyopaque,
    descriptor: *const EnumDescriptor,
) (BindingError || EngineError)!void {
    // Enums are validated at the boundary during type conversion
    _ = engine_ctx;
    _ = descriptor;
}

/// Register a WebIDL callback type
fn quickjsRegisterCallback(
    engine_ctx: *anyopaque,
    descriptor: *const CallbackDescriptor,
) (BindingError || EngineError)!void {
    // Callbacks are handled at runtime during type conversion
    _ = engine_ctx;
    _ = descriptor;
}

// =============================================================================
// Template Management
// =============================================================================

/// Get a previously registered interface template by name
fn quickjsGetInterfaceTemplate(
    engine_ctx: *anyopaque,
    name: [*:0]const u8,
) ?TemplateHandle {
    _ = engine_ctx;
    const name_str = std.mem.span(name);
    if (getClass(name_str)) |entry| {
        return @ptrFromInt(@as(usize, entry.class_id));
    }
    return null;
}

/// Create a new instance of a registered interface
fn quickjsCreateInstance(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    zig_instance: *anyopaque,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const class_id: ffi.JSClassID = @intCast(@intFromPtr(template));

    // Create a new object with the class
    const obj = ffi.JS_NewObjectClass(ctx, @intCast(class_id));
    if (obj.isException()) {
        return EngineError.OperationFailed;
    }

    // Store the Zig instance as opaque data
    ffi.JS_SetOpaque(obj, zig_instance);

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = obj;

    return @ptrCast(boxed);
}

/// Set up the prototype chain for an interface
fn quickjsSetPrototype(
    engine_ctx: *anyopaque,
    child_template: TemplateHandle,
    parent_template: TemplateHandle,
) BindingError!void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const child_class_id: ffi.JSClassID = @intCast(@intFromPtr(child_template));
    const parent_class_id: ffi.JSClassID = @intCast(@intFromPtr(parent_template));

    // Get parent prototype
    const parent_proto = ffi.JS_GetClassProto(ctx, parent_class_id);
    if (parent_proto.isException() or parent_proto.isUndefined()) {
        return BindingError.ParentNotFound;
    }

    // Get child prototype and set its prototype to parent
    const child_proto = ffi.JS_GetClassProto(ctx, child_class_id);
    if (child_proto.isException() or child_proto.isUndefined()) {
        return BindingError.PrototypeSetupFailed;
    }

    _ = ffi.JS_SetPrototype(ctx, child_proto, parent_proto);
}

/// Include a mixin's members in an interface
fn quickjsIncludeMixin(
    engine_ctx: *anyopaque,
    interface_template: TemplateHandle,
    mixin_template: TemplateHandle,
) BindingError!void {
    _ = engine_ctx;
    _ = interface_template;
    _ = mixin_template;
    // TODO: Copy mixin methods and properties to interface prototype
}

// =============================================================================
// Global Object Setup
// =============================================================================

/// Expose an interface constructor on the global object
fn quickjsExposeOnGlobal(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    name: [*:0]const u8,
) EngineError!void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const class_id: ffi.JSClassID = @intCast(@intFromPtr(template));

    // Get the global object
    const global = ffi.JS_GetGlobalObject(ctx);
    defer ffi.JS_FreeValue(ctx, global);

    // Create a constructor function
    // For now, create a simple constructor that creates instances of the class
    const constructor = ffi.JS_NewCFunction2(
        ctx,
        quickjsGenericConstructor,
        name,
        0,
        ffi.JS_CFUNC_constructor,
        @intCast(class_id),
    );

    if (constructor.isException()) {
        return EngineError.OperationFailed;
    }

    // Set constructor bit
    ffi.JS_SetConstructorBit(ctx, constructor, true);

    // Set the property on global
    const result = ffi.JS_SetPropertyStr(ctx, global, name, constructor);
    if (result < 0) {
        return EngineError.OperationFailed;
    }
}

/// Generic constructor callback for QuickJS
fn quickjsGenericConstructor(
    ctx: *ffi.JSContext,
    this_val: ffi.JSValue,
    argc: c_int,
    argv: [*]ffi.JSValue,
) callconv(.c) ffi.JSValue {
    _ = this_val;
    _ = argc;
    _ = argv;

    // Create a new object
    // The magic number should contain the class_id
    // TODO: Look up the constructor from the registry and call it
    return ffi.JS_NewObject(ctx);
}

/// Set up the global object (Window, WorkerGlobalScope, etc.)
fn quickjsSetupGlobalObject(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    zig_instance: *anyopaque,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    _ = template;

    // Get the global object
    const global = ffi.JS_GetGlobalObject(ctx);

    // Store the Zig instance in the global object
    ffi.JS_SetOpaque(global, zig_instance);

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = global;

    return @ptrCast(boxed);
}

// =============================================================================
// Value Conversion
// =============================================================================

/// Convert a Zig value to a JavaScript value
fn quickjsToJSValue(
    engine_ctx: *anyopaque,
    type_desc: *const TypeDescriptor,
    zig_value: *const anyopaque,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    const js_value: ffi.JSValue = switch (type_desc.kind) {
        .primitive => switch (type_desc.primitive) {
            .void, .undefined => ffi.JSValue.UNDEFINED,
            .boolean => blk: {
                const bool_val: *const bool = @ptrCast(@alignCast(zig_value));
                break :blk ffi.JS_NewBool(ctx, bool_val.*);
            },
            .long, .short, .byte => blk: {
                const int_val: *const i32 = @ptrCast(@alignCast(zig_value));
                break :blk ffi.JS_NewInt32(ctx, int_val.*);
            },
            .unsigned_long, .unsigned_short, .octet => blk: {
                const uint_val: *const u32 = @ptrCast(@alignCast(zig_value));
                break :blk ffi.JS_NewInt32(ctx, @intCast(uint_val.*));
            },
            .double, .float, .unrestricted_double, .unrestricted_float => blk: {
                const num_val: *const f64 = @ptrCast(@alignCast(zig_value));
                break :blk ffi.JS_NewFloat64(ctx, num_val.*);
            },
            .DOMString, .USVString, .ByteString => blk: {
                const str_slice: *const []const u8 = @ptrCast(@alignCast(zig_value));
                break :blk ffi.createString(ctx, str_slice.*);
            },
            else => return EngineError.OperationFailed,
        },
        .interface => blk: {
            // Interface values are wrapped as QuickJS objects
            const instance_ptr: *const *anyopaque = @ptrCast(@alignCast(zig_value));
            const obj = ffi.JS_NewObject(ctx);
            if (!obj.isException()) {
                ffi.JS_SetOpaque(obj, @constCast(instance_ptr.*));
            }
            break :blk obj;
        },
        .nullable => blk: {
            // Check if the inner value is null
            const opt_ptr: *const ?*anyopaque = @ptrCast(@alignCast(zig_value));
            if (opt_ptr.*) |inner| {
                // Recursively convert the inner value
                const inner_desc = type_desc.inner_type orelse return EngineError.OperationFailed;
                return quickjsToJSValue(engine_ctx, inner_desc, inner);
            } else {
                break :blk ffi.JSValue.NULL;
            }
        },
        else => return EngineError.OperationFailed,
    };

    if (js_value.isException()) {
        return EngineError.OperationFailed;
    }

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = js_value;
    return @ptrCast(boxed);
}

/// Convert a JavaScript value to a Zig value
fn quickjsFromJSValue(
    engine_ctx: *anyopaque,
    type_desc: *const TypeDescriptor,
    js_value: *const anyopaque,
    out_value: *anyopaque,
) EngineError!void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));
    const value = boxed.*;

    switch (type_desc.kind) {
        .primitive => switch (type_desc.primitive) {
            .boolean => {
                const out_bool: *bool = @ptrCast(@alignCast(out_value));
                const result = ffi.JS_ToBool(ctx, value);
                out_bool.* = result != 0;
            },
            .long, .short, .byte => {
                const out_int: *i32 = @ptrCast(@alignCast(out_value));
                const result = ffi.JS_ToInt32(ctx, out_int, value);
                if (result < 0) return EngineError.TypeError;
            },
            .unsigned_long, .unsigned_short, .octet => {
                const out_uint: *u32 = @ptrCast(@alignCast(out_value));
                var int_val: i32 = 0;
                const result = ffi.JS_ToInt32(ctx, &int_val, value);
                if (result < 0) return EngineError.TypeError;
                out_uint.* = @intCast(int_val);
            },
            .double, .float, .unrestricted_double, .unrestricted_float => {
                const out_num: *f64 = @ptrCast(@alignCast(out_value));
                const result = ffi.JS_ToFloat64(ctx, out_num, value);
                if (result < 0) return EngineError.TypeError;
            },
            else => return EngineError.OperationFailed,
        },
        .interface => {
            // Extract the Zig instance from the QuickJS wrapper
            const instance_ptr = ffi.JS_GetOpaque(value, 0);
            const out_inst: **anyopaque = @ptrCast(@alignCast(out_value));
            out_inst.* = instance_ptr orelse return EngineError.OperationFailed;
        },
        else => return EngineError.OperationFailed,
    }
}

/// Check if a JS object is an instance of a registered interface
fn quickjsIsInstanceOf(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    interface_name: [*:0]const u8,
) bool {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));
    const value = boxed.*;

    const name_str = std.mem.span(interface_name);
    const entry = getClass(name_str) orelse return false;

    // Check if the value's class matches
    // QuickJS doesn't have a direct API for this, we'd need to compare class IDs
    // For now, try to get opaque with the class_id and see if it succeeds
    const ptr = ffi.JS_GetOpaque2(ctx, value, entry.class_id);
    return ptr != null;
}

/// Extract the Zig instance from a JS wrapper object
fn quickjsUnwrapInstance(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) ?*anyopaque {
    _ = engine_ctx;
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));
    const value = boxed.*;

    if (!value.isObject()) {
        return null;
    }

    // Try to get opaque data with class_id 0 (generic)
    return ffi.JS_GetOpaque(value, 0);
}

// =============================================================================
// Error Throwing
// =============================================================================

/// Throw a JavaScript TypeError
fn quickjsThrowTypeError(
    engine_ctx: *anyopaque,
    message: [*:0]const u8,
) void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    _ = ffi.JS_ThrowTypeError(ctx, "%s", message);
}

/// Throw a JavaScript RangeError
fn quickjsThrowRangeError(
    engine_ctx: *anyopaque,
    message: [*:0]const u8,
) void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    _ = ffi.JS_ThrowRangeError(ctx, "%s", message);
}

/// Throw a DOMException
fn quickjsThrowDOMException(
    engine_ctx: *anyopaque,
    name: [*:0]const u8,
    message: [*:0]const u8,
) void {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    // QuickJS doesn't have DOMException built-in
    // Create a custom error with name and message
    const error_obj = ffi.JS_NewError(ctx);
    if (!error_obj.isException()) {
        // Set name property
        const name_val = ffi.JS_NewString(ctx, name);
        _ = ffi.JS_SetPropertyStr(ctx, error_obj, "name", name_val);

        // Set message property
        const msg_val = ffi.JS_NewString(ctx, message);
        _ = ffi.JS_SetPropertyStr(ctx, error_obj, "message", msg_val);

        // Throw it
        _ = ffi.JS_Throw(ctx, error_obj);
    }
}

// =============================================================================
// Async Support
// =============================================================================

/// Create an async iterator wrapper for Symbol.asyncIterator
fn quickjsCreateAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
    descriptor: *const TypeDescriptor,
) EngineError!*anyopaque {
    _ = descriptor;
    // Delegate to the base engine interface
    return engine_mod.quickjs_engine_interface.wrapAsyncIterator(engine_ctx, zig_iterator);
}

/// Create a ReadableStream wrapper
fn quickjsCreateReadableStream(
    engine_ctx: *anyopaque,
    zig_stream: *anyopaque,
) EngineError!*anyopaque {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));

    // Wrap the ReadableStream
    const obj = ffi.JS_NewObject(ctx);
    if (obj.isException()) {
        return EngineError.OperationFailed;
    }

    ffi.JS_SetOpaque(obj, zig_stream);

    // Box the JSValue
    const boxed = std.heap.page_allocator.create(ffi.JSValue) catch
        return EngineError.OutOfMemory;
    boxed.* = obj;

    return @ptrCast(boxed);
}

// =============================================================================
// Structured Clone Support
// =============================================================================

/// Check if a value is serializable (for structured clone)
fn quickjsIsSerializable(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) bool {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));
    const value = boxed.*;

    // Most primitive types are serializable
    if (value.isUndefined() or
        value.isNull() or
        value.isBool() or
        value.isNumber() or
        value.isString())
    {
        return true;
    }

    // Arrays and plain objects are generally serializable
    if (value.isObject()) {
        const is_array = ffi.JS_IsArray(ctx, value);
        if (is_array != 0) {
            return true;
        }
        // Plain objects are also serializable
        return true;
    }

    return false;
}

/// Check if a value is transferable (for structured clone)
fn quickjsIsTransferable(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) bool {
    const ctx: *ffi.JSContext = @ptrCast(@alignCast(engine_ctx));
    const boxed: *const ffi.JSValue = @ptrCast(@alignCast(js_value));
    const value = boxed.*;

    // Check if it's an ArrayBuffer (most common transferable)
    if (!value.isObject()) {
        return false;
    }

    // Try to get ArrayBuffer data - if it succeeds, it's an ArrayBuffer
    var size: usize = 0;
    const data = ffi.JS_GetArrayBuffer(ctx, &size, value);
    return data != null;
}

// =============================================================================
// Tests
// =============================================================================

test "quickjs_engine_binding - has all required operations" {
    const testing = std.testing;

    // Check that all required operations are present
    try testing.expect(quickjs_engine_binding.registerInterface != null);
    try testing.expect(quickjs_engine_binding.registerDictionary != null);
    try testing.expect(quickjs_engine_binding.registerEnum != null);
    try testing.expect(quickjs_engine_binding.registerCallback != null);
    try testing.expect(quickjs_engine_binding.getInterfaceTemplate != null);
    try testing.expect(quickjs_engine_binding.createInstance != null);
    try testing.expect(quickjs_engine_binding.setPrototype != null);
    try testing.expect(quickjs_engine_binding.includeMixin != null);
    try testing.expect(quickjs_engine_binding.exposeOnGlobal != null);
    try testing.expect(quickjs_engine_binding.setupGlobalObject != null);
    try testing.expect(quickjs_engine_binding.toJSValue != null);
    try testing.expect(quickjs_engine_binding.fromJSValue != null);
    try testing.expect(quickjs_engine_binding.isInstanceOf != null);
    try testing.expect(quickjs_engine_binding.unwrapInstance != null);
    try testing.expect(quickjs_engine_binding.throwTypeError != null);
    try testing.expect(quickjs_engine_binding.throwRangeError != null);
    try testing.expect(quickjs_engine_binding.throwDOMException != null);
    try testing.expect(quickjs_engine_binding.createAsyncIterator != null);
    try testing.expect(quickjs_engine_binding.createReadableStream != null);
    try testing.expect(quickjs_engine_binding.isSerializable != null);
    try testing.expect(quickjs_engine_binding.isTransferable != null);
}

test "quickjs_engine_binding - metadata" {
    const testing = std.testing;

    try testing.expectEqualStrings("QuickJS", quickjs_engine_binding.name);
    try testing.expectEqualStrings("2024-01", quickjs_engine_binding.version);
}

test "quickjs_engine_binding - base interface accessible" {
    const testing = std.testing;

    // Verify base EngineInterface is accessible
    try testing.expectEqualStrings("QuickJS", quickjs_engine_binding.base.name);
}

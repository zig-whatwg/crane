//! JSC Engine Binding Implementation
//!
//! This module implements the EngineBinding interface for JavaScriptCore, providing
//! WebIDL binding generation capabilities on top of the base EngineInterface.
//!
//! ## Design
//!
//! The JSC EngineBinding:
//! 1. Composes with the jsc_engine_interface (base operations)
//! 2. Implements all EngineBinding operations using JSC's JSClass APIs
//! 3. Uses JSClassRef for interface templates (similar to V8's FunctionTemplate)
//! 4. Maintains wrapper identity through a class registry
//!
//! ## Key Differences from V8
//!
//! - JSC uses JSClassRef instead of FunctionTemplate
//! - JSC uses reference counting (JSValueProtect) instead of handles
//! - JSC class callbacks have different signatures
//! - JSC uses JSObjectGetPrivate/SetPrivate for internal data

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
    class: ffi.JSClassRef,
    name: []const u8,
    descriptor: *const InterfaceDescriptor,
    config: *const InterfaceBindingConfig,
};

/// Simple registry for JSC classes
var class_registry: std.StringHashMapUnmanaged(ClassEntry) = .{};
var registry_allocator: ?std.mem.Allocator = null;

/// Initialize the registry with an allocator
pub fn initRegistry(allocator: std.mem.Allocator) void {
    registry_allocator = allocator;
}

/// Deinitialize the registry
pub fn deinitRegistry() void {
    if (registry_allocator) |alloc| {
        var it = class_registry.iterator();
        while (it.next()) |entry| {
            ffi.JSClassRelease(entry.value_ptr.class);
            alloc.free(entry.key_ptr.*);
        }
        class_registry.deinit(alloc);
    }
    registry_allocator = null;
}

/// Get a class by name
fn getClass(name: []const u8) ?ffi.JSClassRef {
    if (class_registry.get(name)) |entry| {
        return entry.class;
    }
    return null;
}

/// Register a class
fn registerClass(name: []const u8, class: ffi.JSClassRef, descriptor: *const InterfaceDescriptor, config: *const InterfaceBindingConfig) !void {
    const allocator = registry_allocator orelse return error.OutOfMemory;
    const name_copy = try allocator.dupe(u8, name);

    try class_registry.put(allocator, name_copy, .{
        .class = class,
        .name = name_copy,
        .descriptor = descriptor,
        .config = config,
    });
}

// =============================================================================
// JSC Engine Binding VTable
// =============================================================================

/// JSC implementation of the EngineBinding interface
pub const jsc_engine_binding: EngineBinding = .{
    // Base EngineInterface (composition)
    .base = &engine_mod.jsc_engine_interface,

    // Interface Registration
    .registerInterface = jscRegisterInterface,
    .registerDictionary = jscRegisterDictionary,
    .registerEnum = jscRegisterEnum,
    .registerCallback = jscRegisterCallback,

    // Template Management
    .getInterfaceTemplate = jscGetInterfaceTemplate,
    .createInstance = jscCreateInstance,
    .setPrototype = jscSetPrototype,
    .includeMixin = jscIncludeMixin,

    // Global Object Setup
    .exposeOnGlobal = jscExposeOnGlobal,
    .setupGlobalObject = jscSetupGlobalObject,

    // Value Conversion
    .toJSValue = jscToJSValue,
    .fromJSValue = jscFromJSValue,
    .isInstanceOf = jscIsInstanceOf,
    .unwrapInstance = jscUnwrapInstance,

    // Error Throwing
    .throwTypeError = jscThrowTypeError,
    .throwRangeError = jscThrowRangeError,
    .throwDOMException = jscThrowDOMException,

    // Async Support
    .createAsyncIterator = jscCreateAsyncIterator,
    .createReadableStream = jscCreateReadableStream,

    // Structured Clone Support
    .isSerializable = jscIsSerializable,
    .isTransferable = jscIsTransferable,

    // Metadata
    .name = "JavaScriptCore",
    .version = "WebKit",
};

// =============================================================================
// Interface Registration
// =============================================================================

/// Register a WebIDL interface with JSC
fn jscRegisterInterface(
    engine_ctx: *anyopaque,
    descriptor: *const InterfaceDescriptor,
    config: *const InterfaceBindingConfig,
) (BindingError || EngineError)!TemplateHandle {
    _ = engine_ctx;

    // Get interface name
    const name = std.mem.span(descriptor.name);

    // Check if already registered
    if (getClass(name)) |existing| {
        return @ptrCast(existing);
    }

    // Build the class definition
    var class_def = ffi.kJSClassDefinitionEmpty;
    class_def.className = descriptor.name;
    class_def.attributes = ffi.kJSClassAttributeNone;

    // Set up finalize callback if destructor provided
    if (config.destructor) |_| {
        class_def.finalize = jscFinalizeCallback;
    }

    // Set up constructor if interface has one
    if (descriptor.has_constructor) {
        class_def.callAsConstructor = jscConstructorCallback;
    }

    // Set up property getter/setter if interface has properties
    if (descriptor.properties != null and descriptor.properties_len > 0) {
        class_def.getProperty = jscGetPropertyCallback;
        class_def.setProperty = jscSetPropertyCallback;
    }

    // Create the class
    const class = ffi.JSClassCreate(&class_def);

    // Register in our registry
    registerClass(name, class, descriptor, config) catch {
        ffi.JSClassRelease(class);
        return BindingError.OutOfMemory;
    };

    // Set up inheritance if parent is specified
    if (descriptor.parent) |parent_name| {
        const parent_name_str = std.mem.span(parent_name);
        if (getClass(parent_name_str)) |parent_class| {
            // JSC doesn't have direct class inheritance like V8
            // We'd need to set up the prototype chain manually
            _ = parent_class;
        }
    }

    return @ptrCast(class);
}

/// Finalize callback - called when JSC object is garbage collected
fn jscFinalizeCallback(object: ffi.JSObjectRef) callconv(.c) void {
    // Get the private data (Zig instance pointer)
    const instance = ffi.JSObjectGetPrivate(object);
    if (instance) |inst| {
        // TODO: Look up the destructor from the registry and call it
        _ = inst;
    }
}

/// Constructor callback - called when JavaScript invokes `new InterfaceName()`
fn jscConstructorCallback(
    ctx: ffi.JSContextRef,
    constructor: ffi.JSObjectRef,
    argumentCount: usize,
    arguments: [*]const ffi.JSValueRef,
    exception: *?ffi.JSValueRef,
) callconv(.c) ffi.JSObjectRef {
    _ = constructor;
    _ = argumentCount;
    _ = arguments;
    _ = exception;

    // Create a new instance
    // TODO: Look up the constructor from the registry and call it
    return ffi.JSObjectMake(ctx, null, null);
}

/// Property getter callback
fn jscGetPropertyCallback(
    ctx: ffi.JSContextRef,
    object: ffi.JSObjectRef,
    propertyName: ffi.JSStringRef,
    exception: *?ffi.JSValueRef,
) callconv(.c) ffi.JSValueRef {
    _ = object;
    _ = propertyName;
    _ = exception;

    // TODO: Look up property in registry and call getter
    return ffi.JSValueMakeUndefined(ctx);
}

/// Property setter callback
fn jscSetPropertyCallback(
    ctx: ffi.JSContextRef,
    object: ffi.JSObjectRef,
    propertyName: ffi.JSStringRef,
    value: ffi.JSValueRef,
    exception: *?ffi.JSValueRef,
) callconv(.c) bool {
    _ = ctx;
    _ = object;
    _ = propertyName;
    _ = value;
    _ = exception;

    // TODO: Look up property in registry and call setter
    return false;
}

/// Register a WebIDL dictionary type
fn jscRegisterDictionary(
    engine_ctx: *anyopaque,
    descriptor: *const DictionaryDescriptor,
) (BindingError || EngineError)!void {
    // Dictionaries in JSC are handled at runtime during type conversion
    _ = engine_ctx;
    _ = descriptor;
}

/// Register a WebIDL enumeration type
fn jscRegisterEnum(
    engine_ctx: *anyopaque,
    descriptor: *const EnumDescriptor,
) (BindingError || EngineError)!void {
    // Enums are validated at the boundary during type conversion
    _ = engine_ctx;
    _ = descriptor;
}

/// Register a WebIDL callback type
fn jscRegisterCallback(
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
fn jscGetInterfaceTemplate(
    engine_ctx: *anyopaque,
    name: [*:0]const u8,
) ?TemplateHandle {
    _ = engine_ctx;
    const name_str = std.mem.span(name);
    if (getClass(name_str)) |class| {
        return @ptrCast(class);
    }
    return null;
}

/// Create a new instance of a registered interface
fn jscCreateInstance(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    zig_instance: *anyopaque,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const class: ffi.JSClassRef = @ptrCast(@alignCast(template));

    // Create a new object with the class and store the Zig instance
    const obj = ffi.JSObjectMake(ctx, class, zig_instance);

    return @ptrCast(obj);
}

/// Set up the prototype chain for an interface
fn jscSetPrototype(
    engine_ctx: *anyopaque,
    child_template: TemplateHandle,
    parent_template: TemplateHandle,
) BindingError!void {
    _ = engine_ctx;
    _ = child_template;
    _ = parent_template;
    // JSC class inheritance is set up at class creation time via parentClass
    // We can't change it after the fact, so this is mostly a no-op for JSC
}

/// Include a mixin's members in an interface
fn jscIncludeMixin(
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
fn jscExposeOnGlobal(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    name: [*:0]const u8,
) EngineError!void {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const class: ffi.JSClassRef = @ptrCast(@alignCast(template));

    // Get the global object
    const global = ffi.JSContextGetGlobalObject(ctx);

    // Create a constructor object
    const constructor = ffi.JSObjectMakeConstructor(ctx, class, jscConstructorCallback);

    // Create property name
    const prop_name = ffi.JSStringCreateWithUTF8CString(name);
    defer ffi.JSStringRelease(prop_name);

    // Set the property
    var exception: ?ffi.JSValueRef = null;
    ffi.JSObjectSetProperty(ctx, global, prop_name, @ptrCast(constructor), ffi.kJSPropertyAttributeNone, &exception);

    if (exception != null) {
        return EngineError.OperationFailed;
    }
}

/// Set up the global object (Window, WorkerGlobalScope, etc.)
fn jscSetupGlobalObject(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    zig_instance: *anyopaque,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    _ = template;

    // Get the global object
    const global = ffi.JSContextGetGlobalObject(ctx);

    // Store the Zig instance in the global object
    _ = ffi.JSObjectSetPrivate(global, zig_instance);

    return @ptrCast(global);
}

// =============================================================================
// Value Conversion
// =============================================================================

/// Convert a Zig value to a JavaScript value
fn jscToJSValue(
    engine_ctx: *anyopaque,
    type_desc: *const TypeDescriptor,
    zig_value: *const anyopaque,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    return switch (type_desc.kind) {
        .primitive => switch (type_desc.primitive) {
            .void, .undefined => @ptrCast(ffi.JSValueMakeUndefined(ctx)),
            .boolean => blk: {
                const bool_val: *const bool = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.JSValueMakeBoolean(ctx, bool_val.*));
            },
            .long, .short, .byte => blk: {
                const int_val: *const i32 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.JSValueMakeNumber(ctx, @floatFromInt(int_val.*)));
            },
            .unsigned_long, .unsigned_short, .octet => blk: {
                const uint_val: *const u32 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.JSValueMakeNumber(ctx, @floatFromInt(uint_val.*)));
            },
            .double, .float, .unrestricted_double, .unrestricted_float => blk: {
                const num_val: *const f64 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.JSValueMakeNumber(ctx, num_val.*));
            },
            .DOMString, .USVString, .ByteString => blk: {
                const str_slice: *const []const u8 = @ptrCast(@alignCast(zig_value));
                var buf: [65536]u8 = undefined;
                if (str_slice.*.len >= buf.len) {
                    return EngineError.OutOfMemory;
                }
                @memcpy(buf[0..str_slice.*.len], str_slice.*);
                buf[str_slice.*.len] = 0;
                const jsc_str = ffi.JSStringCreateWithUTF8CString(@ptrCast(&buf));
                defer ffi.JSStringRelease(jsc_str);
                break :blk @ptrCast(ffi.JSValueMakeString(ctx, jsc_str));
            },
            else => return EngineError.OperationFailed,
        },
        .interface => blk: {
            // Interface values are wrapped as JSC objects
            const instance_ptr: *const *anyopaque = @ptrCast(@alignCast(zig_value));
            const obj = ffi.JSObjectMake(ctx, null, @constCast(instance_ptr.*));
            break :blk @ptrCast(obj);
        },
        .nullable => blk: {
            // Check if the inner value is null
            const opt_ptr: *const ?*anyopaque = @ptrCast(@alignCast(zig_value));
            if (opt_ptr.*) |inner| {
                // Recursively convert the inner value
                const inner_desc = type_desc.inner_type orelse return EngineError.OperationFailed;
                break :blk try jscToJSValue(engine_ctx, inner_desc, inner);
            } else {
                break :blk @ptrCast(ffi.JSValueMakeNull(ctx));
            }
        },
        else => return EngineError.OperationFailed,
    };
}

/// Convert a JavaScript value to a Zig value
fn jscFromJSValue(
    engine_ctx: *anyopaque,
    type_desc: *const TypeDescriptor,
    js_value: *const anyopaque,
    out_value: *anyopaque,
) EngineError!void {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const value: ffi.JSValueRef = @ptrCast(@alignCast(@constCast(js_value)));
    var exception: ?ffi.JSValueRef = null;

    switch (type_desc.kind) {
        .primitive => switch (type_desc.primitive) {
            .boolean => {
                const out_bool: *bool = @ptrCast(@alignCast(out_value));
                out_bool.* = ffi.JSValueToBoolean(ctx, value);
            },
            .long, .short, .byte => {
                const out_int: *i32 = @ptrCast(@alignCast(out_value));
                const num = ffi.JSValueToNumber(ctx, value, &exception);
                if (exception != null) return EngineError.TypeError;
                out_int.* = @intFromFloat(num);
            },
            .unsigned_long, .unsigned_short, .octet => {
                const out_uint: *u32 = @ptrCast(@alignCast(out_value));
                const num = ffi.JSValueToNumber(ctx, value, &exception);
                if (exception != null) return EngineError.TypeError;
                out_uint.* = @intFromFloat(num);
            },
            .double, .float, .unrestricted_double, .unrestricted_float => {
                const out_num: *f64 = @ptrCast(@alignCast(out_value));
                out_num.* = ffi.JSValueToNumber(ctx, value, &exception);
                if (exception != null) return EngineError.TypeError;
            },
            else => return EngineError.OperationFailed,
        },
        .interface => {
            // Extract the Zig instance from the JSC wrapper
            const obj: ffi.JSObjectRef = ffi.JSValueToObject(ctx, value, &exception);
            if (exception != null) return EngineError.TypeError;
            const instance_ptr = ffi.JSObjectGetPrivate(obj);
            const out_inst: **anyopaque = @ptrCast(@alignCast(out_value));
            out_inst.* = instance_ptr orelse return EngineError.OperationFailed;
        },
        else => return EngineError.OperationFailed,
    }
}

/// Check if a JS object is an instance of a registered interface
fn jscIsInstanceOf(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    interface_name: [*:0]const u8,
) bool {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const value: ffi.JSValueRef = @ptrCast(@alignCast(@constCast(js_value)));

    const name_str = std.mem.span(interface_name);
    const class = getClass(name_str) orelse return false;

    return ffi.JSValueIsObjectOfClass(ctx, value, class);
}

/// Extract the Zig instance from a JS wrapper object
fn jscUnwrapInstance(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) ?*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const value: ffi.JSValueRef = @ptrCast(@alignCast(@constCast(js_value)));

    if (!ffi.JSValueIsObject(ctx, value)) {
        return null;
    }

    var exception: ?ffi.JSValueRef = null;
    const obj = ffi.JSValueToObject(ctx, value, &exception);
    if (exception != null) return null;

    return ffi.JSObjectGetPrivate(obj);
}

// =============================================================================
// Error Throwing
// =============================================================================

/// Throw a JavaScript TypeError
fn jscThrowTypeError(
    engine_ctx: *anyopaque,
    message: [*:0]const u8,
) void {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    const msg_str = ffi.JSStringCreateWithUTF8CString(message);
    defer ffi.JSStringRelease(msg_str);

    const msg_value = ffi.JSValueMakeString(ctx, msg_str);
    var exception: ?ffi.JSValueRef = null;
    const args = [_]ffi.JSValueRef{msg_value};

    _ = ffi.JSObjectMakeError(ctx, 1, &args, &exception);
    // Note: In JSC, we'd typically store this exception in a context-specific location
    // or throw it via the current call frame
}

/// Throw a JavaScript RangeError
fn jscThrowRangeError(
    engine_ctx: *anyopaque,
    message: [*:0]const u8,
) void {
    // JSC doesn't have separate error constructors in the C API
    // We create a generic error with a RangeError-like message
    jscThrowTypeError(engine_ctx, message);
}

/// Throw a DOMException
fn jscThrowDOMException(
    engine_ctx: *anyopaque,
    name: [*:0]const u8,
    message: [*:0]const u8,
) void {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    // Create error message combining name and message
    var buf: [512]u8 = undefined;
    const name_str = std.mem.span(name);
    const msg_str = std.mem.span(message);
    const full_msg = std.fmt.bufPrint(&buf, "{s}: {s}", .{ name_str, msg_str }) catch return;

    var null_terminated: [513]u8 = undefined;
    @memcpy(null_terminated[0..full_msg.len], full_msg);
    null_terminated[full_msg.len] = 0;

    const jsc_str = ffi.JSStringCreateWithUTF8CString(@ptrCast(&null_terminated));
    defer ffi.JSStringRelease(jsc_str);

    const msg_value = ffi.JSValueMakeString(ctx, jsc_str);
    var exception: ?ffi.JSValueRef = null;
    const args = [_]ffi.JSValueRef{msg_value};

    _ = ffi.JSObjectMakeError(ctx, 1, &args, &exception);
}

// =============================================================================
// Async Support
// =============================================================================

/// Create an async iterator wrapper for Symbol.asyncIterator
fn jscCreateAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
    descriptor: *const TypeDescriptor,
) EngineError!*anyopaque {
    _ = descriptor;
    // Delegate to the base engine interface
    return engine_mod.jsc_engine_interface.wrapAsyncIterator(engine_ctx, zig_iterator);
}

/// Create a ReadableStream wrapper
fn jscCreateReadableStream(
    engine_ctx: *anyopaque,
    zig_stream: *anyopaque,
) EngineError!*anyopaque {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));

    // Wrap the ReadableStream
    const obj = ffi.JSObjectMake(ctx, null, zig_stream);

    return @ptrCast(obj);
}

// =============================================================================
// Structured Clone Support
// =============================================================================

/// Check if a value is serializable (for structured clone)
fn jscIsSerializable(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) bool {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const value: ffi.JSValueRef = @ptrCast(@alignCast(@constCast(js_value)));

    // Most primitive types are serializable
    if (ffi.JSValueIsUndefined(ctx, value) or
        ffi.JSValueIsNull(ctx, value) or
        ffi.JSValueIsBoolean(ctx, value) or
        ffi.JSValueIsNumber(ctx, value) or
        ffi.JSValueIsString(ctx, value))
    {
        return true;
    }

    // Arrays and plain objects are generally serializable
    if (ffi.JSValueIsArray(ctx, value) or ffi.JSValueIsObject(ctx, value)) {
        return true;
    }

    return false;
}

/// Check if a value is transferable (for structured clone)
fn jscIsTransferable(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) bool {
    const ctx: ffi.JSContextRef = @ptrCast(@alignCast(engine_ctx));
    const value: ffi.JSValueRef = @ptrCast(@alignCast(@constCast(js_value)));

    // Check if it's an ArrayBuffer (most common transferable)
    var exception: ?ffi.JSValueRef = null;
    const obj = ffi.JSValueToObject(ctx, value, &exception);
    if (exception != null) return false;

    // Try to get ArrayBuffer byte length - if it succeeds, it's an ArrayBuffer
    const byte_len = ffi.JSObjectGetArrayBufferByteLength(ctx, obj, &exception);
    if (exception == null and byte_len > 0) {
        return true;
    }

    return false;
}

// =============================================================================
// Tests
// =============================================================================

test "jsc_engine_binding - has all required operations" {
    const testing = std.testing;

    // Check that all required operations are present
    try testing.expect(jsc_engine_binding.registerInterface != null);
    try testing.expect(jsc_engine_binding.registerDictionary != null);
    try testing.expect(jsc_engine_binding.registerEnum != null);
    try testing.expect(jsc_engine_binding.registerCallback != null);
    try testing.expect(jsc_engine_binding.getInterfaceTemplate != null);
    try testing.expect(jsc_engine_binding.createInstance != null);
    try testing.expect(jsc_engine_binding.setPrototype != null);
    try testing.expect(jsc_engine_binding.includeMixin != null);
    try testing.expect(jsc_engine_binding.exposeOnGlobal != null);
    try testing.expect(jsc_engine_binding.setupGlobalObject != null);
    try testing.expect(jsc_engine_binding.toJSValue != null);
    try testing.expect(jsc_engine_binding.fromJSValue != null);
    try testing.expect(jsc_engine_binding.isInstanceOf != null);
    try testing.expect(jsc_engine_binding.unwrapInstance != null);
    try testing.expect(jsc_engine_binding.throwTypeError != null);
    try testing.expect(jsc_engine_binding.throwRangeError != null);
    try testing.expect(jsc_engine_binding.throwDOMException != null);
    try testing.expect(jsc_engine_binding.createAsyncIterator != null);
    try testing.expect(jsc_engine_binding.createReadableStream != null);
    try testing.expect(jsc_engine_binding.isSerializable != null);
    try testing.expect(jsc_engine_binding.isTransferable != null);
}

test "jsc_engine_binding - metadata" {
    const testing = std.testing;

    try testing.expectEqualStrings("JavaScriptCore", jsc_engine_binding.name);
    try testing.expectEqualStrings("WebKit", jsc_engine_binding.version);
}

test "jsc_engine_binding - base interface accessible" {
    const testing = std.testing;

    // Verify base EngineInterface is accessible
    try testing.expectEqualStrings("JavaScriptCore", jsc_engine_binding.base.name);
}

//! V8 Engine Binding Implementation
//!
//! This module implements the EngineBinding interface for V8, providing
//! WebIDL binding generation capabilities on top of the base EngineInterface.
//!
//! ## Design
//!
//! The V8 EngineBinding:
//! 1. Composes with the existing v8_engine_interface (base operations)
//! 2. Implements all EngineBinding operations using V8's FunctionTemplate/ObjectTemplate APIs
//! 3. Uses the existing template_registry for interface management
//! 4. Maintains wrapper identity through wrapper_cache
//!
//! ## Usage
//!
//! ```zig
//! const v8_binding = @import("engines/v8/binding.zig");
//!
//! // Get the V8 EngineBinding
//! const binding = v8_binding.v8_engine_binding;
//!
//! // Register an interface
//! const handle = try binding.registerInterface.?(ctx, &descriptor, &config);
//! ```

const std = @import("std");
const engine_binding = @import("../../engine_binding.zig");
const binding_types = @import("../../binding_types.zig");
const engine_interface = @import("../../engine_interface.zig");
const engine_mod = @import("engine.zig");
const ffi = @import("ffi.zig");
const template_registry = @import("template_registry.zig");
const wrapper_cache_mod = @import("wrapper_cache.zig");
const context_manager = @import("context_manager.zig");
const dom_type_info = @import("dom_type_info.zig");

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

/// V8 implementation of the EngineBinding interface
pub const v8_engine_binding: EngineBinding = .{
    // Base EngineInterface (composition)
    .base = &engine_mod.v8_engine_interface,

    // Interface Registration
    .registerInterface = v8RegisterInterface,
    .registerDictionary = v8RegisterDictionary,
    .registerEnum = v8RegisterEnum,
    .registerCallback = v8RegisterCallback,

    // Template Management
    .getInterfaceTemplate = v8GetInterfaceTemplate,
    .createInstance = v8CreateInstance,
    .setPrototype = v8SetPrototype,
    .includeMixin = v8IncludeMixin,

    // Global Object Setup
    .exposeOnGlobal = v8ExposeOnGlobal,
    .setupGlobalObject = v8SetupGlobalObject,

    // Value Conversion
    .toJSValue = v8ToJSValue,
    .fromJSValue = v8FromJSValue,
    .isInstanceOf = v8IsInstanceOf,
    .unwrapInstance = v8UnwrapInstance,

    // Error Throwing
    .throwTypeError = v8ThrowTypeError,
    .throwRangeError = v8ThrowRangeError,
    .throwDOMException = v8ThrowDOMException,

    // Async Support
    .createAsyncIterator = v8CreateAsyncIterator,
    .createReadableStream = v8CreateReadableStream,

    // Structured Clone Support
    .isSerializable = v8IsSerializable,
    .isTransferable = v8IsTransferable,

    // Metadata
    .name = "V8",
    .version = "12.x",
};

// =============================================================================
// Interface Registration
// =============================================================================

/// Register a WebIDL interface with V8
fn v8RegisterInterface(
    engine_ctx: *anyopaque,
    descriptor: *const InterfaceDescriptor,
    config: *const InterfaceBindingConfig,
) (BindingError || EngineError)!TemplateHandle {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    // Get interface name
    const name = std.mem.span(descriptor.name);

    // Check if already registered
    if (template_registry.getTemplate(name)) |existing| {
        return @ptrCast(existing);
    }

    // Create a new FunctionTemplate for this interface
    const template = ffi.v8_FunctionTemplate_New(isolate) orelse
        return BindingError.TemplateCreationFailed;

    // Set the class name
    const class_name = ffi.v8_String_NewFromUtf8(
        isolate,
        descriptor.name,
        @intCast(name.len),
    ) orelse return EngineError.OutOfMemory;
    ffi.v8_FunctionTemplate_SetClassName(template, class_name);

    // Configure the instance template
    const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(template);

    // Set internal field count for wrapper storage
    ffi.v8_ObjectTemplate_SetInternalFieldCount(instance_template, 2);

    // If has constructor, set up the constructor callback
    if (descriptor.has_constructor) {
        if (config.constructor) |ctor| {
            _ = ctor; // TODO: Set constructor callback via FFI
            // ffi.v8_FunctionTemplate_SetCallHandler(template, constructorCallback, config.user_data);
        }
    }

    // Add methods to the prototype template
    const prototype_template = ffi.v8_FunctionTemplate_PrototypeTemplate(template);

    if (descriptor.methods) |methods| {
        const methods_slice = methods[0..descriptor.methods_len];
        for (methods_slice, 0..) |method, i| {
            if (method.name) |method_name| {
                const method_name_v8 = ffi.v8_String_NewFromUtf8(
                    isolate,
                    method_name,
                    @intCast(std.mem.span(method_name).len),
                ) orelse continue;

                // Get the native method callback if provided
                if (config.methods) |methods_arr| {
                    if (i < config.methods_len) {
                        _ = methods_arr; // TODO: Set method callback
                        // const method_fn = methods_arr[i];
                        // const method_template = ffi.v8_FunctionTemplate_NewWithCallback(isolate, method_fn);
                        // ffi.v8_ObjectTemplate_Set(prototype_template, method_name_v8, method_template);
                    }
                }

                _ = method_name_v8;
                _ = prototype_template;
            }
        }
    }

    // Add properties to the instance template
    if (descriptor.properties) |properties| {
        const props_slice = properties[0..descriptor.properties_len];
        for (props_slice, 0..) |prop, i| {
            const prop_name = ffi.v8_String_NewFromUtf8(
                isolate,
                prop.name,
                @intCast(std.mem.span(prop.name).len),
            ) orelse continue;

            _ = prop_name;
            _ = i;
            // TODO: Set property accessors via FFI
            // if (config.getters) |getters| {
            //     if (i < config.getters_len) {
            //         const getter = getters[i];
            //         const setter = if (!prop.readonly and config.setters != null)
            //             config.setters.?[i] else null;
            //         ffi.v8_ObjectTemplate_SetAccessor(instance_template, prop_name, getter, setter);
            //     }
            // }
        }
    }

    // Register the template in the global registry
    template_registry.register(name, template, isolate);

    // Set up inheritance if parent is specified
    if (descriptor.parent) |parent_name| {
        const parent_name_str = std.mem.span(parent_name);
        if (template_registry.getTemplate(parent_name_str)) |parent_template| {
            ffi.v8_FunctionTemplate_Inherit(template, parent_template);
        }
    }

    // Expose on global if not a mixin and has constructor
    if (!descriptor.is_mixin and !descriptor.legacy_no_interface_object) {
        if (descriptor.has_constructor) {
            const global = ffi.v8_Context_Global(context);
            const func = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse
                return BindingError.ConstructorFailed;
            const name_str = ffi.v8_String_NewFromUtf8(
                isolate,
                descriptor.name,
                @intCast(name.len),
            ) orelse return EngineError.OutOfMemory;
            _ = ffi.v8_Object_Set(global, context, @ptrCast(name_str), @ptrCast(func));
        }
    }

    return @ptrCast(template);
}

/// Register a WebIDL dictionary type
fn v8RegisterDictionary(
    engine_ctx: *anyopaque,
    descriptor: *const DictionaryDescriptor,
) (BindingError || EngineError)!void {
    // Dictionaries in V8 are handled at runtime during type conversion
    // We just need to store the descriptor for later use
    _ = engine_ctx;
    _ = descriptor;
    // TODO: Store dictionary descriptor in a registry for type conversion
}

/// Register a WebIDL enumeration type
fn v8RegisterEnum(
    engine_ctx: *anyopaque,
    descriptor: *const EnumDescriptor,
) (BindingError || EngineError)!void {
    // Enums are validated at the boundary during type conversion
    // We just need to store the descriptor for later use
    _ = engine_ctx;
    _ = descriptor;
    // TODO: Store enum descriptor in a registry for validation
}

/// Register a WebIDL callback type
fn v8RegisterCallback(
    engine_ctx: *anyopaque,
    descriptor: *const CallbackDescriptor,
) (BindingError || EngineError)!void {
    // Callbacks are handled at runtime during type conversion
    _ = engine_ctx;
    _ = descriptor;
    // TODO: Store callback descriptor for later use
}

// =============================================================================
// Template Management
// =============================================================================

/// Get a previously registered interface template by name
fn v8GetInterfaceTemplate(
    engine_ctx: *anyopaque,
    name: [*:0]const u8,
) ?TemplateHandle {
    _ = engine_ctx;
    const name_str = std.mem.span(name);
    if (template_registry.getTemplate(name_str)) |template| {
        return @ptrCast(template);
    }
    return null;
}

/// Create a new instance of a registered interface
fn v8CreateInstance(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    zig_instance: *anyopaque,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const func_template: *ffi.FunctionTemplate = @ptrCast(@alignCast(template));

    // Get the instance template and create a new object
    const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(func_template);
    const v8_object = ffi.v8_ObjectTemplate_NewInstance(instance_template, context);

    // Store the Zig instance in internal field 0
    ffi.v8_Object_SetAlignedPointerInInternalField(v8_object, 0, zig_instance);

    return @ptrCast(v8_object);
}

/// Set up the prototype chain for an interface
fn v8SetPrototype(
    engine_ctx: *anyopaque,
    child_template: TemplateHandle,
    parent_template: TemplateHandle,
) BindingError!void {
    _ = engine_ctx;
    const child: *ffi.FunctionTemplate = @ptrCast(@alignCast(child_template));
    const parent: *ffi.FunctionTemplate = @ptrCast(@alignCast(parent_template));

    ffi.v8_FunctionTemplate_Inherit(child, parent);
}

/// Include a mixin's members in an interface
fn v8IncludeMixin(
    engine_ctx: *anyopaque,
    interface_template: TemplateHandle,
    mixin_template: TemplateHandle,
) BindingError!void {
    _ = engine_ctx;
    _ = interface_template;
    _ = mixin_template;
    // TODO: Copy mixin methods and properties to interface prototype
    // This requires iterating over the mixin template and copying members
}

// =============================================================================
// Global Object Setup
// =============================================================================

/// Expose an interface constructor on the global object
fn v8ExposeOnGlobal(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    name: [*:0]const u8,
) EngineError!void {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;
    const func_template: *ffi.FunctionTemplate = @ptrCast(@alignCast(template));

    const global = ffi.v8_Context_Global(context);
    const func = ffi.v8_FunctionTemplate_GetFunction(func_template, context) orelse
        return EngineError.OperationFailed;

    const name_str = std.mem.span(name);
    const v8_name = ffi.v8_String_NewFromUtf8(
        isolate,
        name,
        @intCast(name_str.len),
    ) orelse return EngineError.OutOfMemory;

    _ = ffi.v8_Object_Set(global, context, @ptrCast(v8_name), @ptrCast(func));
}

/// Set up the global object (Window, WorkerGlobalScope, etc.)
fn v8SetupGlobalObject(
    engine_ctx: *anyopaque,
    template: TemplateHandle,
    zig_instance: *anyopaque,
) EngineError!*anyopaque {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const func_template: *ffi.FunctionTemplate = @ptrCast(@alignCast(template));

    // For [Global] interfaces, we need to configure the global object
    // to have the correct prototype chain and internal fields
    const global = ffi.v8_Context_Global(context);

    // Store the Zig instance in the global object
    ffi.v8_Object_SetAlignedPointerInInternalField(global, 0, zig_instance);

    // Set up the prototype from the template
    const instance_template = ffi.v8_FunctionTemplate_InstanceTemplate(func_template);
    _ = instance_template;

    // TODO: Configure global prototype chain

    return @ptrCast(global);
}

// =============================================================================
// Value Conversion
// =============================================================================

/// Convert a Zig value to a JavaScript value
fn v8ToJSValue(
    engine_ctx: *anyopaque,
    type_desc: *const TypeDescriptor,
    zig_value: *const anyopaque,
) EngineError!*anyopaque {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    return switch (type_desc.kind) {
        .primitive => switch (type_desc.primitive) {
            .void, .undefined => @ptrCast(ffi.v8_Undefined(isolate) orelse
                return EngineError.OperationFailed),
            .boolean => blk: {
                const bool_val: *const bool = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.v8_Boolean_New(isolate, bool_val.*) orelse
                    return EngineError.OperationFailed);
            },
            .long, .short, .byte => blk: {
                const int_val: *const i32 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.v8_Integer_New(isolate, int_val.*) orelse
                    return EngineError.OperationFailed);
            },
            .unsigned_long, .unsigned_short, .octet => blk: {
                const uint_val: *const u32 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.v8_Integer_NewFromUnsigned(isolate, uint_val.*) orelse
                    return EngineError.OperationFailed);
            },
            .double, .float, .unrestricted_double, .unrestricted_float => blk: {
                const num_val: *const f64 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.v8_Number_New(isolate, num_val.*) orelse
                    return EngineError.OperationFailed);
            },
            .DOMString, .USVString, .ByteString => blk: {
                const str_slice: *const []const u8 = @ptrCast(@alignCast(zig_value));
                break :blk @ptrCast(ffi.v8_String_NewFromUtf8(
                    isolate,
                    str_slice.*.ptr,
                    @intCast(str_slice.*.len),
                ) orelse return EngineError.OperationFailed);
            },
            else => return EngineError.OperationFailed,
        },
        .interface => blk: {
            // Interface values are wrapped as V8 objects
            // The zig_value is a pointer to the instance
            const instance_ptr: *const *anyopaque = @ptrCast(@alignCast(zig_value));
            const runtime = @import("runtime");
            const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr.*));

            // Use template registry to wrap the instance
            const interface_name = template_registry.getInstanceInterfaceName(instance);
            const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse
                return EngineError.OperationFailed;
            const v8_obj = template_registry.wrapInstanceAsV8Object(
                instance,
                interface_name,
                isolate,
                context,
            ) catch return EngineError.OperationFailed;
            break :blk @ptrCast(v8_obj);
        },
        .nullable => blk: {
            // Check if the inner value is null
            const opt_ptr: *const ?*anyopaque = @ptrCast(@alignCast(zig_value));
            if (opt_ptr.*) |inner| {
                // Recursively convert the inner value
                const inner_desc = type_desc.inner_type orelse return EngineError.OperationFailed;
                break :blk try v8ToJSValue(engine_ctx, inner_desc, inner);
            } else {
                break :blk @ptrCast(ffi.v8_Null(isolate) orelse return EngineError.OperationFailed);
            }
        },
        else => return EngineError.OperationFailed,
    };
}

/// Convert a JavaScript value to a Zig value
fn v8FromJSValue(
    engine_ctx: *anyopaque,
    type_desc: *const TypeDescriptor,
    js_value: *const anyopaque,
    out_value: *anyopaque,
) EngineError!void {
    _ = engine_ctx;
    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;

    switch (type_desc.kind) {
        .primitive => switch (type_desc.primitive) {
            .boolean => {
                const out_bool: *bool = @ptrCast(@alignCast(out_value));
                out_bool.* = ffi.v8_Value_BooleanValue(value, isolate);
            },
            .long, .short, .byte => {
                const out_int: *i32 = @ptrCast(@alignCast(out_value));
                out_int.* = ffi.v8_Value_Int32Value(value, isolate);
            },
            .unsigned_long, .unsigned_short, .octet => {
                const out_uint: *u32 = @ptrCast(@alignCast(out_value));
                out_uint.* = ffi.v8_Value_Uint32Value(value, isolate);
            },
            .double, .float, .unrestricted_double, .unrestricted_float => {
                const out_num: *f64 = @ptrCast(@alignCast(out_value));
                out_num.* = ffi.v8_Value_NumberValue(value, isolate);
            },
            else => return EngineError.OperationFailed,
        },
        .interface => {
            // Extract the Zig instance from the V8 wrapper
            const obj: *ffi.Object = @ptrCast(value);
            const instance_ptr = ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0);
            const out_inst: **anyopaque = @ptrCast(@alignCast(out_value));
            out_inst.* = instance_ptr;
        },
        else => return EngineError.OperationFailed,
    }
}

/// Check if a JS object is an instance of a registered interface
fn v8IsInstanceOf(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
    interface_name: [*:0]const u8,
) bool {
    const context: *ffi.Context = @ptrCast(@alignCast(engine_ctx));
    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));

    if (!ffi.v8_Value_IsObject(value)) {
        return false;
    }

    const name_str = std.mem.span(interface_name);
    const template = template_registry.getTemplate(name_str) orelse return false;
    const func = ffi.v8_FunctionTemplate_GetFunction(template, context) orelse return false;

    return ffi.v8_Value_InstanceOf(value, context, @ptrCast(func));
}

/// Extract the Zig instance from a JS wrapper object
fn v8UnwrapInstance(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) ?*anyopaque {
    _ = engine_ctx;
    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));

    if (!ffi.v8_Value_IsObject(value)) {
        return null;
    }

    const obj: *ffi.Object = @ptrCast(value);
    return ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0);
}

// =============================================================================
// Error Throwing
// =============================================================================

/// Throw a JavaScript TypeError
fn v8ThrowTypeError(
    engine_ctx: *anyopaque,
    message: [*:0]const u8,
) void {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return;

    const msg_str = std.mem.span(message);
    const v8_msg = ffi.v8_String_NewFromUtf8(
        isolate,
        message,
        @intCast(msg_str.len),
    ) orelse return;

    const exception = ffi.v8_Exception_TypeError(v8_msg) orelse return;
    ffi.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a JavaScript RangeError
fn v8ThrowRangeError(
    engine_ctx: *anyopaque,
    message: [*:0]const u8,
) void {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return;

    const msg_str = std.mem.span(message);
    const v8_msg = ffi.v8_String_NewFromUtf8(
        isolate,
        message,
        @intCast(msg_str.len),
    ) orelse return;

    const exception = ffi.v8_Exception_RangeError(v8_msg) orelse return;
    ffi.v8_Isolate_ThrowException(isolate, exception);
}

/// Throw a DOMException
fn v8ThrowDOMException(
    engine_ctx: *anyopaque,
    name: [*:0]const u8,
    message: [*:0]const u8,
) void {
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return;

    // Create error message combining name and message
    var buf: [512]u8 = undefined;
    const name_str = std.mem.span(name);
    const msg_str = std.mem.span(message);
    const full_msg = std.fmt.bufPrint(&buf, "{s}: {s}", .{ name_str, msg_str }) catch return;

    const v8_msg = ffi.v8_String_NewFromUtf8(
        isolate,
        full_msg.ptr,
        @intCast(full_msg.len),
    ) orelse return;

    // Use generic Error for DOMException (could be enhanced to create proper DOMException)
    const exception = ffi.v8_Exception_Error(v8_msg) orelse return;
    ffi.v8_Isolate_ThrowException(isolate, exception);
}

// =============================================================================
// Async Support
// =============================================================================

/// Create an async iterator wrapper for Symbol.asyncIterator
fn v8CreateAsyncIterator(
    engine_ctx: *anyopaque,
    zig_iterator: *anyopaque,
    descriptor: *const TypeDescriptor,
) EngineError!*anyopaque {
    _ = descriptor;
    // Delegate to the base engine interface
    return engine_mod.v8_engine_interface.wrapAsyncIterator(engine_ctx, zig_iterator);
}

/// Create a ReadableStream wrapper
fn v8CreateReadableStream(
    engine_ctx: *anyopaque,
    zig_stream: *anyopaque,
) EngineError!*anyopaque {
    // Wrap the ReadableStream using the existing template registry
    _ = engine_ctx;
    const isolate = ffi.v8_Isolate_GetCurrent() orelse
        return EngineError.OperationFailed;
    const context = ffi.v8_Isolate_GetCurrentContext(isolate) orelse
        return EngineError.OperationFailed;

    const runtime = @import("runtime");
    const instance: *runtime.Instance = @ptrCast(@alignCast(zig_stream));

    const v8_obj = template_registry.wrapInstanceAsV8Object(
        instance,
        "ReadableStream",
        isolate,
        context,
    ) catch return EngineError.OperationFailed;

    return @ptrCast(v8_obj);
}

// =============================================================================
// Structured Clone Support
// =============================================================================

/// Check if a value is serializable (for structured clone)
fn v8IsSerializable(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) bool {
    _ = engine_ctx;
    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));

    // Most primitive types are serializable
    if (ffi.v8_Value_IsUndefined(value) or
        ffi.v8_Value_IsNull(value) or
        ffi.v8_Value_IsBoolean(value) or
        ffi.v8_Value_IsNumber(value) or
        ffi.v8_Value_IsString(value) or
        ffi.v8_Value_IsBigInt(value))
    {
        return true;
    }

    // Arrays and plain objects are generally serializable
    if (ffi.v8_Value_IsArray(value) or ffi.v8_Value_IsObject(value)) {
        // TODO: Check for cycles and non-serializable properties
        return true;
    }

    // ArrayBuffer and TypedArrays are serializable
    if (ffi.v8_Value_IsArrayBuffer(value) or
        ffi.v8_Value_IsArrayBufferView(value))
    {
        return true;
    }

    return false;
}

/// Check if a value is transferable (for structured clone)
fn v8IsTransferable(
    engine_ctx: *anyopaque,
    js_value: *const anyopaque,
) bool {
    _ = engine_ctx;
    const value: *ffi.Value = @ptrCast(@alignCast(@constCast(js_value)));

    // ArrayBuffer is transferable
    if (ffi.v8_Value_IsArrayBuffer(value)) {
        return true;
    }

    // MessagePort would be transferable (not implemented yet)
    // ImageBitmap would be transferable (not implemented yet)
    // OffscreenCanvas would be transferable (not implemented yet)

    return false;
}

// =============================================================================
// Tests
// =============================================================================

test "v8_engine_binding - has all required operations" {
    const testing = std.testing;

    // Check that all required operations are present
    try testing.expect(v8_engine_binding.registerInterface != null);
    try testing.expect(v8_engine_binding.registerDictionary != null);
    try testing.expect(v8_engine_binding.registerEnum != null);
    try testing.expect(v8_engine_binding.registerCallback != null);
    try testing.expect(v8_engine_binding.getInterfaceTemplate != null);
    try testing.expect(v8_engine_binding.createInstance != null);
    try testing.expect(v8_engine_binding.setPrototype != null);
    try testing.expect(v8_engine_binding.includeMixin != null);
    try testing.expect(v8_engine_binding.exposeOnGlobal != null);
    try testing.expect(v8_engine_binding.setupGlobalObject != null);
    try testing.expect(v8_engine_binding.toJSValue != null);
    try testing.expect(v8_engine_binding.fromJSValue != null);
    try testing.expect(v8_engine_binding.isInstanceOf != null);
    try testing.expect(v8_engine_binding.unwrapInstance != null);
    try testing.expect(v8_engine_binding.throwTypeError != null);
    try testing.expect(v8_engine_binding.throwRangeError != null);
    try testing.expect(v8_engine_binding.throwDOMException != null);
    try testing.expect(v8_engine_binding.createAsyncIterator != null);
    try testing.expect(v8_engine_binding.createReadableStream != null);
    try testing.expect(v8_engine_binding.isSerializable != null);
    try testing.expect(v8_engine_binding.isTransferable != null);
}

test "v8_engine_binding - metadata" {
    const testing = std.testing;

    try testing.expectEqualStrings("V8", v8_engine_binding.name);
    try testing.expectEqualStrings("12.x", v8_engine_binding.version);
}

test "v8_engine_binding - base interface accessible" {
    const testing = std.testing;

    // Verify base EngineInterface is accessible
    try testing.expectEqualStrings("V8", v8_engine_binding.base.name);
}

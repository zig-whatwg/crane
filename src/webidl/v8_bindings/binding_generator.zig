//! V8 Binding Code Generator
//!
//! This module generates explicit V8 binding code for each WebIDL interface.
//! Instead of using runtime reflection, we generate direct callback functions
//! that are compiled with full type information.
//!
//! ## Generated Code Structure
//!
//! For each interface (e.g., Element), we generate:
//!
//! ```zig
//! // v8_element.zig (generated)
//! pub const wrapper_type_info = WrapperTypeInfo{
//!     .interface_name = "Element",
//!     .parent = &v8_node.wrapper_type_info,
//!     .this_tag = 120,
//!     .max_subclass_tag = 179,
//!     .install_template_fn = installTemplate,
//! };
//!
//! pub fn installTemplate(isolate: *v8.Isolate) *v8.FunctionTemplate {
//!     // Create template with internal fields
//!     // Register all methods with signatures
//!     // Set up property accessors
//! }
//!
//! fn constructorCallback(info: *v8.FunctionCallbackInfo) callconv(.c) void {
//!     // Explicit constructor implementation
//! }
//!
//! fn getAttributeCallback(info: *v8.FunctionCallbackInfo) callconv(.c) void {
//!     // Explicit method callback with argument parsing
//! }
//! ```
//!
//! ## Benefits
//!
//! 1. Type-safe: All types known at compile time
//! 2. Debuggable: Can set breakpoints in generated code
//! 3. Optimized: No runtime reflection overhead
//! 4. Explicit: Easy to see what's happening

const std = @import("std");

/// Configuration for generating V8 bindings
pub const BindingConfig = struct {
    /// Interface name (e.g., "Element")
    interface_name: []const u8,
    /// Parent interface name (null for root interfaces)
    parent_name: ?[]const u8,
    /// Type tag for this interface
    this_tag: u16,
    /// Max tag for subclasses
    max_subclass_tag: u16,
    /// Whether this interface is constructible
    has_constructor: bool,
    /// Is this a Node subclass (for GC)
    is_node: bool,
    /// Methods to generate (name, arity, has_optional_params)
    methods: []const MethodInfo,
    /// Properties to generate (name, has_setter)
    properties: []const PropertyInfo,
};

pub const MethodInfo = struct {
    js_name: []const u8,
    zig_name: []const u8,
    arity: u8,
    /// Parameter types for argument conversion
    param_types: []const ParamType,
    /// Return type
    return_type: ReturnType,
};

pub const PropertyInfo = struct {
    js_name: []const u8,
    getter_name: []const u8,
    setter_name: ?[]const u8,
    property_type: ReturnType,
};

pub const ParamType = enum {
    dom_string,
    boolean,
    long,
    unsigned_long,
    double,
    instance, // *runtime.Instance
    callback, // CallbackWrapper
    any, // *anyopaque
    optional_any, // ?*anyopaque
};

pub const ReturnType = enum {
    void,
    dom_string,
    boolean,
    long,
    unsigned_long,
    double,
    instance,
    optional_instance,
};

/// Generate V8 binding file for an interface
pub fn generateBinding(
    allocator: std.mem.Allocator,
    writer: anytype,
    config: BindingConfig,
) !void {
    // Write header
    try writer.writeAll("//! V8 Bindings for ");
    try writer.writeAll(config.interface_name);
    try writer.writeAll("\n//!\n//! AUTO-GENERATED - Do not edit manually.\n\n");

    // Write imports
    try writeImports(writer, config);

    // Write WrapperTypeInfo
    try writeWrapperTypeInfo(writer, config);

    // Write installTemplate function
    try writeInstallTemplate(writer, config);

    // Write constructor callback (if constructible)
    if (config.has_constructor) {
        try writeConstructorCallback(allocator, writer, config);
    }

    // Write method callbacks
    for (config.methods) |method| {
        try writeMethodCallback(allocator, writer, config, method);
    }

    // Write property accessor callbacks
    for (config.properties) |prop| {
        try writePropertyGetterCallback(allocator, writer, config, prop);
        if (prop.setter_name != null) {
            try writePropertySetterCallback(allocator, writer, config, prop);
        }
    }
}

fn writeImports(writer: anytype, config: BindingConfig) !void {
    try writer.writeAll("const std = @import(\"std\");\n");
    try writer.writeAll("const v8 = @import(\"v8_ffi\");\n");
    try writer.writeAll("const runtime = @import(\"runtime\");\n");
    try writer.writeAll("const wrapper = @import(\"wrapper_type_info\");\n");
    try writer.writeAll("const WrapperTypeInfo = wrapper.WrapperTypeInfo;\n");
    try writer.writeAll("const conv = @import(\"conversions\");\n");

    // Import impl
    try writer.print("const {s}Impl = @import(\"impls\").{s};\n", .{
        config.interface_name,
        config.interface_name,
    });

    // Import parent binding if exists
    if (config.parent_name) |parent| {
        try writer.print("const v8_{s} = @import(\"v8_{s}.zig\");\n", .{
            toLowerSnakeCase(parent),
            toLowerSnakeCase(parent),
        });
    }

    try writer.writeAll("\n");
}

fn writeWrapperTypeInfo(writer: anytype, config: BindingConfig) !void {
    try writer.writeAll("/// Static type metadata for V8 binding\n");
    try writer.writeAll("pub const wrapper_type_info = WrapperTypeInfo{\n");
    try writer.print("    .interface_name = \"{s}\",\n", .{config.interface_name});

    if (config.parent_name) |parent| {
        try writer.print("    .parent = &v8_{s}.wrapper_type_info,\n", .{toLowerSnakeCase(parent)});
    } else {
        try writer.writeAll("    .parent = null,\n");
    }

    try writer.print("    .this_tag = {d},\n", .{config.this_tag});
    try writer.print("    .max_subclass_tag = {d},\n", .{config.max_subclass_tag});

    if (config.is_node) {
        try writer.writeAll("    .wrapper_class_id = .node,\n");
    } else {
        try writer.writeAll("    .wrapper_class_id = .object,\n");
    }

    try writer.writeAll("    .idl_definition_kind = .interface,\n");
    try writer.writeAll("    .install_template_fn = installTemplate,\n");
    try writer.writeAll("};\n\n");
}

fn writeInstallTemplate(writer: anytype, config: BindingConfig) !void {
    try writer.writeAll("/// Install V8 FunctionTemplate for this interface\n");
    try writer.writeAll("pub fn installTemplate(isolate: *v8.Isolate) *v8.FunctionTemplate {\n");

    // Create FunctionTemplate
    if (config.has_constructor) {
        try writer.writeAll("    const template = v8.v8_FunctionTemplate_New(isolate, constructorCallback, null).?;\n");
    } else {
        try writer.writeAll("    const template = v8.v8_FunctionTemplate_New(isolate, nonConstructorCallback, null).?;\n");
    }

    // Set class name
    try writer.print("    const name = v8.v8_String_NewFromUtf8(isolate, \"{s}\", {d}).?;\n", .{
        config.interface_name,
        config.interface_name.len,
    });
    try writer.writeAll("    v8.v8_FunctionTemplate_SetClassName(template, name);\n");

    // Set internal field count
    try writer.writeAll("    const instance_tmpl = v8.v8_FunctionTemplate_InstanceTemplate(template);\n");
    try writer.writeAll("    v8.v8_ObjectTemplate_SetInternalFieldCount(instance_tmpl, wrapper.INTERNAL_FIELD_COUNT);\n");

    // Set up inheritance
    if (config.parent_name) |parent| {
        try writer.print("    const parent_template = v8_{s}.installTemplate(isolate);\n", .{toLowerSnakeCase(parent)});
        try writer.writeAll("    v8.v8_FunctionTemplate_Inherit(template, parent_template);\n");
    }

    // Get prototype template
    try writer.writeAll("    const proto_tmpl = v8.v8_FunctionTemplate_PrototypeTemplate(template);\n");

    // Register methods with signatures
    for (config.methods) |method| {
        try writer.print("\n    // Method: {s}\n", .{method.js_name});
        try writer.print("    const {s}_tmpl = v8.v8_FunctionTemplate_NewWithSignature(\n", .{method.zig_name});
        try writer.print("        isolate, {s}Callback, null, template);\n", .{method.zig_name});
        try writer.print("    v8.v8_FunctionTemplate_SetLength({s}_tmpl, {d});\n", .{ method.zig_name, method.arity });
        try writer.print("    const {s}_name = v8.v8_String_NewFromUtf8(isolate, \"{s}\", {d}).?;\n", .{
            method.zig_name,
            method.js_name,
            method.js_name.len,
        });
        try writer.print("    v8.v8_ObjectTemplate_SetWithAttributes(proto_tmpl, {s}_name, @ptrCast({s}_tmpl), v8.PropertyAttribute.DontEnum);\n", .{
            method.zig_name,
            method.zig_name,
        });
    }

    // Register properties
    for (config.properties) |prop| {
        try writer.print("\n    // Property: {s}\n", .{prop.js_name});
        // TODO: Implement proper accessor registration
    }

    try writer.writeAll("\n    return template;\n");
    try writer.writeAll("}\n\n");
}

fn writeConstructorCallback(allocator: std.mem.Allocator, writer: anytype, config: BindingConfig) !void {
    _ = allocator;

    try writer.writeAll("/// Constructor callback - called when JS does: new ");
    try writer.writeAll(config.interface_name);
    try writer.writeAll("()\n");
    try writer.writeAll("fn constructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {\n");
    try writer.writeAll("    const isolate = info.getIsolate();\n");
    try writer.writeAll("    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {\n");
    try writer.writeAll("        conv.throwError(isolate, \"No current context\");\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n\n");

    try writer.writeAll("    // Get allocator\n");
    try writer.writeAll("    const isolate_alloc = @import(\"isolate_allocator.zig\");\n");
    try writer.writeAll("    const allocator = isolate_alloc.getOrInitAllocator(isolate, std.heap.page_allocator) catch {\n");
    try writer.writeAll("        conv.throwError(isolate, \"Failed to get allocator\");\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n\n");

    try writer.writeAll("    // Get runtime context\n");
    try writer.writeAll("    const ctx_mgr = @import(\"context_manager.zig\");\n");
    try writer.writeAll("    const ctx = ctx_mgr.getOrCreate(v8_context, allocator) catch {\n");
    try writer.writeAll("        conv.throwError(isolate, \"Failed to get runtime context\");\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n\n");

    try writer.writeAll("    // Call impl constructor\n");
    try writer.print("    const instance = {s}Impl.call_constructor(allocator, ctx) catch |err| {{\n", .{config.interface_name});
    try writer.writeAll("        conv.throwError(isolate, @errorName(err));\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n\n");

    try writer.writeAll("    // Wrap instance in V8 object\n");
    try writer.writeAll("    const this_obj = info.getThis();\n");
    try writer.writeAll("    wrapper.wrapInstance(this_obj, instance, &wrapper_type_info);\n");
    try writer.writeAll("}\n\n");

    // Non-constructor callback for non-constructible interfaces
    try writer.writeAll("fn nonConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {\n");
    try writer.writeAll("    const isolate = info.getIsolate();\n");
    try writer.print("    conv.throwTypeError(isolate, \"Illegal constructor: {s}\");\n", .{config.interface_name});
    try writer.writeAll("}\n\n");
}

fn writeMethodCallback(allocator: std.mem.Allocator, writer: anytype, config: BindingConfig, method: MethodInfo) !void {
    _ = allocator;

    try writer.print("/// Method callback for {s}.{s}\n", .{ config.interface_name, method.js_name });
    try writer.print("fn {s}Callback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {{\n", .{method.zig_name});
    try writer.writeAll("    const isolate = info.getIsolate();\n");
    try writer.writeAll("    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {\n");
    try writer.writeAll("        conv.throwError(isolate, \"No current context\");\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n\n");

    // Get instance with type checking
    try writer.writeAll("    // Unwrap instance with type checking\n");
    try writer.writeAll("    const this_obj = info.getThis();\n");
    try writer.writeAll("    const instance = wrapper.unwrapInstance(this_obj, &wrapper_type_info) orelse {\n");
    try writer.print("        conv.throwTypeError(isolate, \"Illegal invocation: not a {s}\");\n", .{config.interface_name});
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n\n");

    // Get allocator for argument conversion
    try writer.writeAll("    const isolate_alloc = @import(\"isolate_allocator.zig\");\n");
    try writer.writeAll("    const allocator = isolate_alloc.getOrInitAllocator(isolate, std.heap.page_allocator) catch {\n");
    try writer.writeAll("        conv.throwError(isolate, \"Failed to get allocator\");\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n");
    try writer.writeAll("    _ = allocator;\n");
    try writer.writeAll("    _ = v8_context;\n\n");

    // Parse arguments
    try writer.writeAll("    // Parse arguments\n");
    try writer.print("    const arg_count = info.length();\n", .{});
    try writer.print("    _ = arg_count;\n", .{});

    // TODO: Generate argument parsing based on param_types

    // Call impl
    try writer.writeAll("\n    // Call implementation\n");
    try writer.print("    const result = {s}Impl.{s}(instance) catch |err| {{\n", .{
        config.interface_name,
        method.zig_name,
    });
    try writer.writeAll("        conv.throwError(isolate, @errorName(err));\n");
    try writer.writeAll("        return;\n");
    try writer.writeAll("    };\n");

    // Handle return value
    switch (method.return_type) {
        .void => {
            try writer.writeAll("    _ = result;\n");
        },
        .boolean => {
            try writer.writeAll("    info.setReturnValue(@ptrCast(v8.v8_Boolean_New(isolate, result)));\n");
        },
        else => {
            try writer.writeAll("    // TODO: Convert return value\n");
            try writer.writeAll("    _ = result;\n");
        },
    }

    try writer.writeAll("}\n\n");
}

fn writePropertyGetterCallback(allocator: std.mem.Allocator, writer: anytype, config: BindingConfig, prop: PropertyInfo) !void {
    _ = allocator;
    _ = config;
    _ = prop;
    // TODO: Implement property getter generation
    _ = writer;
}

fn writePropertySetterCallback(allocator: std.mem.Allocator, writer: anytype, config: BindingConfig, prop: PropertyInfo) !void {
    _ = allocator;
    _ = config;
    _ = prop;
    // TODO: Implement property setter generation
    _ = writer;
}

/// Convert CamelCase to lower_snake_case
fn toLowerSnakeCase(name: []const u8) []const u8 {
    // For now, just return as-is (proper implementation would convert)
    // TODO: Implement proper conversion
    return name;
}

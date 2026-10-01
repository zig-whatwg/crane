//! WebIDL namespace: WebAssembly
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const webidl = @import("webidl");
const WebAssembly_impl = @import("impls").WebAssembly;

pub const WebAssembly = struct {
    pub const Meta = struct {
        pub const name = "WebAssembly";
        pub const is_namespace = true;
        pub const BaseType = null;
        pub const MixinTypes = &.{};

        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
            .{ "instantiate", "call_instantiate" },
            .{ "compileStreaming", "call_compileStreaming" },
            .{ "instantiateStreaming", "call_instantiateStreaming" },
            .{ "compile", "call_compile" },
            .{ "validate", "call_validate" },
        };

        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_instantiate(ctx: runtime.Context, bytes: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_instantiate(ctx, bytes, importObject, options);
    }

    pub fn call_instantiate__1(ctx: runtime.Context, moduleObject: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        if (comptime @hasDecl(WebAssembly_impl, "call_instantiate__1")) {
            return try WebAssembly_impl.call_instantiate__1(ctx, moduleObject, importObject);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_compileStreaming(ctx: runtime.Context, source: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_compileStreaming(ctx, source, options);
    }

    pub fn call_instantiateStreaming(ctx: runtime.Context, source: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_instantiateStreaming(ctx, source, importObject, options);
    }

    pub fn call_compile(ctx: runtime.Context, bytes: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_compile(ctx, bytes, options);
    }

    pub fn call_validate(ctx: runtime.Context, bytes: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!bool {
        return try WebAssembly_impl.call_validate(ctx, bytes, options);
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "instantiate", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_instantiate", .args = &.{ .{ .kinds = &.{ .array_buffer, .{ .typed_array = "Int8Array" }, .{ .typed_array = "Int16Array" }, .{ .typed_array = "Int32Array" }, .{ .typed_array = "Uint8Array" }, .{ .typed_array = "Uint16Array" }, .{ .typed_array = "Uint32Array" }, .{ .typed_array = "Uint8ClampedArray" }, .{ .typed_array = "BigInt64Array" }, .{ .typed_array = "BigUint64Array" }, .{ .typed_array = "Float16Array" }, .{ .typed_array = "Float32Array" }, .{ .typed_array = "Float64Array" }, .data_view } }, .{ .kinds = &.{.object}, .optionality = .optional }, .{ .kinds = &.{.other}, .optionality = .optional } } },
            .{ .function = "call_instantiate__1", .implemented = @hasDecl(WebAssembly_impl, "call_instantiate__1"), .args = &.{ .{ .kinds = &.{.other} }, .{ .kinds = &.{.object}, .optionality = .optional } } },
        } },
    };

    pub const JSTag: runtime.JSValue = undefined;
};

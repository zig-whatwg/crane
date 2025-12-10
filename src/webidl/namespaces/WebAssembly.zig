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
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        
        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
            .{ "instantiate_BufferSource_object_WebAssemblyCompileOptions", "call_instantiate_BufferSource_object_WebAssemblyCompileOptions" },
            .{ "instantiate_Module_object", "call_instantiate_Module_object" },
            .{ "compile", "call_compile" },
            .{ "validate", "call_validate" },
        };
        
        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_instantiate_BufferSource_object_WebAssemblyCompileOptions(ctx: runtime.Context, bytes: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue), options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_instantiate_BufferSource_object_WebAssemblyCompileOptions(ctx, bytes, importObject, options);
    }

    pub fn call_instantiate_Module_object(ctx: runtime.Context, moduleObject: runtime.JSValue, importObject: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_instantiate_Module_object(ctx, moduleObject, importObject);
    }

    pub fn call_compile(ctx: runtime.Context, bytes: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        return try WebAssembly_impl.call_compile(ctx, bytes, options);
    }

    pub fn call_validate(ctx: runtime.Context, bytes: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!bool {
        return try WebAssembly_impl.call_validate(ctx, bytes, options);
    }

    pub const JSTag: runtime.JSValue = undefined;

};

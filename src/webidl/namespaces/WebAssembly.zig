//! WebIDL namespace: WebAssembly
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const runtime = @import("runtime");
const WebAssembly_impl = @import("impls").WebAssembly;

pub const WebAssembly = struct {
    pub const Meta = struct {
        pub const name = "WebAssembly";
        pub const is_namespace = true;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        
        /// Method binding hints for V8Interface (JS name, Zig function name)
        pub const methods = .{
            .{ "compile", "call_compile" },
            .{ "instantiate_BufferSource_object_WebAssemblyCompileOptions", "call_instantiate_BufferSource_object_WebAssemblyCompileOptions" },
            .{ "instantiate_Module_object", "call_instantiate_Module_object" },
            .{ "validate", "call_validate" },
        };
        
        pub const has_constructor = false;
        pub const properties = .{};
    };

    pub const State = struct {};

    pub fn call_compile(ctx: runtime.Context, bytes: *const anyopaque, options: *const anyopaque) *const anyopaque {
        return WebAssembly_impl.call_compile(ctx, bytes, options);
    }

    pub fn call_instantiate_BufferSource_object_WebAssemblyCompileOptions(ctx: runtime.Context, bytes: *const anyopaque, importObject: *const anyopaque, options: *const anyopaque) *const anyopaque {
        return WebAssembly_impl.call_instantiate_BufferSource_object_WebAssemblyCompileOptions(ctx, bytes, importObject, options);
    }

    pub fn call_instantiate_Module_object(ctx: runtime.Context, moduleObject: *const anyopaque, importObject: *const anyopaque) *const anyopaque {
        return WebAssembly_impl.call_instantiate_Module_object(ctx, moduleObject, importObject);
    }

    pub fn call_validate(ctx: runtime.Context, bytes: *const anyopaque, options: *const anyopaque) bool {
        return WebAssembly_impl.call_validate(ctx, bytes, options);
    }

    pub const JSTag: *const anyopaque = undefined;

};

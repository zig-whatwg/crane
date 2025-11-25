//! Generated from: fetch.idl
//! Generated at: 2025-11-25T13:07:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HeadersImpl = @import("impls").Headers;
const ByteString = @import("interfaces").ByteString;
const HeadersInit = @import("typedefs").HeadersInit;

pub const Headers = struct {
    pub const Meta = struct {
        pub const name = "Headers";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "get", "call_get", 1 },
            .{ "getSetCookie", "call_getSetCookie", 0 },
            .{ "has", "call_has", 1 },
            .{ "set", "call_set", 2 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "append",
            "delete",
            "get",
            "getSetCookie",
            "has",
            "set",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.ByteString",
            .key_type = "runtime.ByteString",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*HeadersImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_forEach = &call_forEach,
        .call_get = &call_get,
        .call_getSetCookie = &call_getSetCookie,
        .call_has = &call_has,
        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HeadersImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HeadersImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: HeadersInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HeadersImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.ByteString) anyerror!void {
        
        return try HeadersImpl.call_delete(instance, name);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        
        return try HeadersImpl.call_append(instance, name, value);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.ByteString) anyerror!bool {
        
        return try HeadersImpl.call_has(instance, name);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try HeadersImpl.call_forEach(instance, callback);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.ByteString, value: runtime.ByteString) anyerror!void {
        
        return try HeadersImpl.call_set(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.ByteString) anyerror!?runtime.ByteString {
        
        return try HeadersImpl.call_get(instance, name);
    }

    pub fn call_getSetCookie(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try HeadersImpl.call_getSetCookie(instance);
    }

};

//! Generated from: url.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const URLSearchParamsImpl = @import("impls").URLSearchParams;
const sequence = @import("interfaces").sequence;
const record = @import("interfaces").record;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const URLSearchParams = struct {
    pub const Meta = struct {
        pub const name = "URLSearchParams";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "get", "call_get", 1 },
            .{ "getAll", "call_getAll", 1 },
            .{ "has", "call_has", 1 },
            .{ "set", "call_set", 2 },
            .{ "sort", "call_sort", 0 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "append",
            "delete",
            "get",
            "getAll",
            "has",
            "set",
            "sort",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "size", "get_size", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.USVString",
            .key_type = "runtime.USVString",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            size: u32 = undefined,
            _internal: ?*URLSearchParamsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_size = &get_size,

        .call_append = &call_append,
        .call_delete = &call_delete,
        .call_forEach = &call_forEach,
        .call_get = &call_get,
        .call_getAll = &call_getAll,
        .call_has = &call_has,
        .call_set = &call_set,
        .call_sort = &call_sort,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return URLSearchParamsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        URLSearchParamsImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try URLSearchParamsImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
        return try URLSearchParamsImpl.get_size(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try URLSearchParamsImpl.call_delete(instance, name, value);
    }

    pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try URLSearchParamsImpl.call_append(instance, name, value);
    }

    pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
        
        return try URLSearchParamsImpl.call_getAll(instance, name);
    }

    pub fn call_has(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!bool {
        
        return try URLSearchParamsImpl.call_has(instance, name, value);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try URLSearchParamsImpl.call_forEach(instance, callback);
    }

    pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
        
        return try URLSearchParamsImpl.call_set(instance, name, value);
    }

    pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.USVString {
        
        return try URLSearchParamsImpl.call_get(instance, name);
    }

    pub fn call_sort(instance: *runtime.Instance) anyerror!void {
        return try URLSearchParamsImpl.call_sort(instance);
    }

};

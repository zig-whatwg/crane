//! Generated from: css-typed-om.idl
//! Generated at: 2025-11-23T14:26:29Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StylePropertyMapImpl = @import("impls").StylePropertyMap;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const CSSStyleValue = @import("interfaces").CSSStyleValue;
const USVString = @import("interfaces").USVString;

pub const StylePropertyMap = struct {
    pub const Meta = struct {
        pub const name = "StylePropertyMap";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *StylePropertyMapReadOnly;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "set", "call_set", 2 },
            .{ "append", "call_append", 2 },
            .{ "delete", "call_delete", 1 },
            .{ "clear", "call_clear", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "set",
            "append",
            "delete",
            "clear",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "get",
            "getAll",
            "has",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_append = &call_append,
        .call_clear = &call_clear,
        .call_delete = &call_delete,
        .call_set = &call_set,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return StylePropertyMapImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        StylePropertyMapImpl.deinit(instance);
    }

    pub fn call_delete(instance: *runtime.Instance, property: runtime.USVString) anyerror!void {
        
        return try StylePropertyMapImpl.call_delete(instance, property);
    }

    pub fn call_append(instance: *runtime.Instance, property: runtime.USVString, values: *const anyopaque) anyerror!void {
        
        return try StylePropertyMapImpl.call_append(instance, property, values);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try StylePropertyMapImpl.call_clear(instance);
    }

    pub fn call_set(instance: *runtime.Instance, property: runtime.USVString, values: *const anyopaque) anyerror!void {
        
        return try StylePropertyMapImpl.call_set(instance, property, values);
    }

};

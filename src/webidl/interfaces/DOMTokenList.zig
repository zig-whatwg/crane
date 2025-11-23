//! Generated from: dom.idl
//! Generated at: 2025-11-23T19:57:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DOMTokenListImpl = @import("impls").DOMTokenList;
const DOMString = @import("typedefs").DOMString;

pub const DOMTokenList = struct {
    pub const Meta = struct {
        pub const name = "DOMTokenList";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "value", "get_value", "set_value" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "contains", "call_contains", 1 },
            .{ "add", "call_add", 1 },
            .{ "remove", "call_remove", 1 },
            .{ "toggle", "call_toggle", 1 },
            .{ "replace", "call_replace", 2 },
            .{ "supports", "call_supports", 1 },
            .{ "forEach", "call_forEach", 1 },
            .{ "forEach", "call_forEach", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "contains",
            "add",
            "remove",
            "toggle",
            "replace",
            "supports",
            "forEach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
            .{ "value", "get_value", "set_value" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
        
        /// Iterable declaration (for Symbol.iterator support)
        pub const iterable = .{
            .value_type = "runtime.DOMString",
            .key_type = null,
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            value: runtime.DOMString = undefined,
            _internal: ?*DOMTokenListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_value = &get_value,

        .set_value = &set_value,

        .call_add = &call_add,
        .call_contains = &call_contains,
        .call_forEach = &call_forEach,
        .call_item = &call_item,
        .call_remove = &call_remove,
        .call_replace = &call_replace,
        .call_supports = &call_supports,
        .call_toggle = &call_toggle,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DOMTokenListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DOMTokenListImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try DOMTokenListImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try DOMTokenListImpl.get_value(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try DOMTokenListImpl.set_value(instance, value);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!DOMString {
        
        return try DOMTokenListImpl.call_item(instance, index);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replace(instance: *runtime.Instance, token: DOMString, newToken: DOMString) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_replace(instance, token, newToken);
    }

    pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
        
        return try DOMTokenListImpl.call_forEach(instance, callback);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggle(instance: *runtime.Instance, token: DOMString, force: bool) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_toggle(instance, token, force);
    }

    pub fn call_contains(instance: *runtime.Instance, token: DOMString) anyerror!bool {
        
        return try DOMTokenListImpl.call_contains(instance, token);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, tokens: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_add(instance, tokens);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, tokens: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try DOMTokenListImpl.call_remove(instance, tokens);
    }

    pub fn call_supports(instance: *runtime.Instance, token: DOMString) anyerror!bool {
        
        return try DOMTokenListImpl.call_supports(instance, token);
    }

};

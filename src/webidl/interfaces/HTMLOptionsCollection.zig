//! Generated from: html.idl
//! Generated at: 2025-11-28T22:33:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLOptionsCollectionImpl = @import("impls").HTMLOptionsCollection;
const mixins = @import("mixins");
const HTMLCollection = @import("interfaces").HTMLCollection;
const Element = @import("interfaces").Element;
const HTMLElement = @import("interfaces").HTMLElement;
const HTMLOptionElement = @import("interfaces").HTMLOptionElement;
const DOMString = @import("typedefs").DOMString;
const HTMLOptGroupElement = @import("interfaces").HTMLOptGroupElement;

pub const HTMLOptionsCollection = struct {
    pub const Meta = struct {
        pub const name = "HTMLOptionsCollection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *HTMLCollection;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", "set_length" },
            .{ "selectedIndex", "get_selectedIndex", "set_selectedIndex" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "add", "call_add", 1 },
            .{ "remove", "call_remove", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "add",
            "remove",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
            "namedItem",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", "set_length" },
            .{ "selectedIndex", "get_selectedIndex", "set_selectedIndex" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            _internal: ?*HTMLOptionsCollectionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_selectedIndex = &get_selectedIndex,

        .set_length = &set_length,
        .set_selectedIndex = &set_selectedIndex,

        .call_add = &call_add,
        .call_remove = &call_remove,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLOptionsCollectionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLOptionsCollectionImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HTMLOptionsCollectionImpl.get_length(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_length(instance: *runtime.Instance, value: u32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLOptionsCollectionImpl.set_length(instance, value);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try HTMLOptionsCollectionImpl.get_selectedIndex(instance);
    }

    pub fn set_selectedIndex(instance: *runtime.Instance, value: i32) anyerror!void {
        try HTMLOptionsCollectionImpl.set_selectedIndex(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_add(instance: *runtime.Instance, element: *const anyopaque, before: webidl.Opt(?*const anyopaque)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLOptionsCollectionImpl.call_add(instance, element, before);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_remove(instance: *runtime.Instance, index: i32) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try HTMLOptionsCollectionImpl.call_remove(instance, index);
    }

};

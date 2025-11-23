//! Generated from: html.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PopoverTargetAttributesImpl = @import("impls").PopoverTargetAttributes;
const Element = @import("interfaces").Element;
const DOMString = @import("typedefs").DOMString;

pub const PopoverTargetAttributes = struct {
    pub const Meta = struct {
        pub const name = "PopoverTargetAttributes";
        pub const is_mixin = true;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "popoverTargetElement", "get_popoverTargetElement", "set_popoverTargetElement" },
            .{ "popoverTargetAction", "get_popoverTargetAction", "set_popoverTargetAction" },
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
            popoverTargetElement: ?*runtime.Instance = null,
            popoverTargetAction: runtime.DOMString = undefined,
            _internal: ?*PopoverTargetAttributesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_popoverTargetAction = &get_popoverTargetAction,
        .get_popoverTargetElement = &get_popoverTargetElement,

        .set_popoverTargetAction = &set_popoverTargetAction,
        .set_popoverTargetElement = &set_popoverTargetElement,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return PopoverTargetAttributesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PopoverTargetAttributesImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_popoverTargetElement(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try PopoverTargetAttributesImpl.get_popoverTargetElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_popoverTargetElement(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try PopoverTargetAttributesImpl.set_popoverTargetElement(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_popoverTargetAction(instance: *runtime.Instance) anyerror!DOMString {
        return try PopoverTargetAttributesImpl.get_popoverTargetAction(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_popoverTargetAction(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try PopoverTargetAttributesImpl.set_popoverTargetAction(instance, value);
    }

};

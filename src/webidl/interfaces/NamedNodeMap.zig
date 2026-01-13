//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const NamedNodeMapImpl = @import("impls").NamedNodeMap;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Attr = @import("interfaces").Attr;
const DOMString = @import("typedefs").DOMString;

pub const NamedNodeMap = struct {
    pub const Meta = struct {
        pub const name = "NamedNodeMap";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "LegacyUnenumerableNamedProperties" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "item", "call_item", 1 },
            .{ "getNamedItem", "call_getNamedItem", 1 },
            .{ "getNamedItemNS", "call_getNamedItemNS", 2 },
            .{ "setNamedItem", "call_setNamedItem", 1 },
            .{ "setNamedItemNS", "call_setNamedItemNS", 1 },
            .{ "removeNamedItem", "call_removeNamedItem", 1 },
            .{ "removeNamedItemNS", "call_removeNamedItemNS", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "item",
            "getNamedItem",
            "getNamedItemNS",
            "setNamedItem",
            "setNamedItemNS",
            "removeNamedItem",
            "removeNamedItemNS",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "length", "get_length", null },
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
            _internal: ?*NamedNodeMapImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,

        .call_getNamedItem = &call_getNamedItem,
        .call_getNamedItemNS = &call_getNamedItemNS,
        .call_item = &call_item,
        .call_removeNamedItem = &call_removeNamedItem,
        .call_removeNamedItemNS = &call_removeNamedItemNS,
        .call_setNamedItem = &call_setNamedItem,
        .call_setNamedItemNS = &call_setNamedItemNS,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NamedNodeMapImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return NamedNodeMapImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NamedNodeMapImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try NamedNodeMapImpl.get_length(instance);
    }

    pub fn call_getNamedItem(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!?*runtime.Instance {
        
        return try NamedNodeMapImpl.call_getNamedItem(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItem(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_removeNamedItem(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItem(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_setNamedItem(instance, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setNamedItemNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_setNamedItemNS(instance, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeNamedItemNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try NamedNodeMapImpl.call_removeNamedItemNS(instance, namespace, localName);
    }

    pub fn call_getNamedItemNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!?*runtime.Instance {
        
        return try NamedNodeMapImpl.call_getNamedItemNS(instance, namespace, localName);
    }

    pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
        
        return try NamedNodeMapImpl.call_item(instance, index);
    }

    /// Get supported property names for named property enumeration (Reflect.ownKeys, etc.)
    /// Per WebIDL spec §3.9.3, returns names in list order for proper enumeration
    pub fn getSupportedPropertyNames(instance: *runtime.Instance, allocator: std.mem.Allocator) ![]runtime.DOMString {
        return NamedNodeMapImpl.getSupportedPropertyNames(instance, allocator);
    }

};

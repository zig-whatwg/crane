//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RadioNodeListImpl = @import("impls").RadioNodeList;
const mixins = @import("mixins");
const NodeList = @import("interfaces").NodeList;
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const RadioNodeList = struct {
    pub const Meta = struct {
        pub const name = "RadioNodeList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = NodeList.State;
        pub const ParentInterface = NodeList;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "value", "get_value", "set_value" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "item",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "value", "get_value", "set_value" },
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
            value: runtime.DOMString = undefined,
            _internal: ?*RadioNodeListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_value = &get_value,

        .set_value = &set_value,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RadioNodeListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RadioNodeListImpl.deinit(instance);
    }

    pub fn get_value(instance: *runtime.Instance) anyerror!DOMString {
        return try RadioNodeListImpl.get_value(instance);
    }

    pub fn set_value(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try RadioNodeListImpl.set_value(instance, value);
    }

};

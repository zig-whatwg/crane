//! Generated from: dom.idl
//! Generated at: 2025-11-28T18:57:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ChildNodeImpl = @import("impls").ChildNode;
const mixins = @import("mixins");
const Node = @import("interfaces").Node;
const DOMString = @import("typedefs").DOMString;

pub const ChildNode = struct {
    pub const Meta = struct {
        pub const name = "ChildNode";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "before", "call_before", 1 },
            .{ "after", "call_after", 1 },
            .{ "replaceWith", "call_replaceWith", 1 },
            .{ "remove", "call_remove", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "before",
            "after",
            "replaceWith",
            "remove",
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
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*ChildNodeImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_after = &call_after,
        .call_before = &call_before,
        .call_remove = &call_remove,
        .call_replaceWith = &call_replaceWith,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ChildNodeImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ChildNodeImpl.deinit(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ChildNodeImpl.call_replaceWith(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ChildNodeImpl.call_before(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ChildNodeImpl.call_after(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try ChildNodeImpl.call_remove(instance);
    }

};

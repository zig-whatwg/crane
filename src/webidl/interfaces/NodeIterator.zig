//! Generated from: dom.idl
//! Generated at: 2025-11-23T16:59:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NodeIteratorImpl = @import("impls").NodeIterator;
const Node = @import("interfaces").Node;
const NodeFilter = @import("interfaces").NodeFilter;

pub const NodeIterator = struct {
    pub const Meta = struct {
        pub const name = "NodeIterator";
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
            .{ "root", "get_root", null },
            .{ "referenceNode", "get_referenceNode", null },
            .{ "pointerBeforeReferenceNode", "get_pointerBeforeReferenceNode", null },
            .{ "whatToShow", "get_whatToShow", null },
            .{ "filter", "get_filter", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "nextNode", "call_nextNode", 0 },
            .{ "previousNode", "call_previousNode", 0 },
            .{ "detach", "call_detach", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "nextNode",
            "previousNode",
            "detach",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "root", "get_root", null },
            .{ "referenceNode", "get_referenceNode", null },
            .{ "pointerBeforeReferenceNode", "get_pointerBeforeReferenceNode", null },
            .{ "whatToShow", "get_whatToShow", null },
            .{ "filter", "get_filter", null },
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
            root: Node = undefined,
            referenceNode: Node = undefined,
            pointerBeforeReferenceNode: bool = undefined,
            whatToShow: u32 = undefined,
            filter: ?NodeFilter = null,
            cached_root: ?Node = null,
            _internal: ?*NodeIteratorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_filter = &get_filter,
        .get_pointerBeforeReferenceNode = &get_pointerBeforeReferenceNode,
        .get_referenceNode = &get_referenceNode,
        .get_root = &get_root,
        .get_whatToShow = &get_whatToShow,

        .call_detach = &call_detach,
        .call_nextNode = &call_nextNode,
        .call_previousNode = &call_previousNode,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return NodeIteratorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NodeIteratorImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_root(instance: *runtime.Instance) anyerror!Node {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_root) |cached| {
            return cached;
        }
        const value = try NodeIteratorImpl.get_root(instance);
        state.own.cached_root = value;
        return value;
    }

    pub fn get_referenceNode(instance: *runtime.Instance) anyerror!Node {
        return try NodeIteratorImpl.get_referenceNode(instance);
    }

    pub fn get_pointerBeforeReferenceNode(instance: *runtime.Instance) anyerror!bool {
        return try NodeIteratorImpl.get_pointerBeforeReferenceNode(instance);
    }

    pub fn get_whatToShow(instance: *runtime.Instance) anyerror!u32 {
        return try NodeIteratorImpl.get_whatToShow(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!NodeFilter {
        return try NodeIteratorImpl.get_filter(instance);
    }

    pub fn call_nextNode(instance: *runtime.Instance) anyerror!Node {
        return try NodeIteratorImpl.call_nextNode(instance);
    }

    pub fn call_detach(instance: *runtime.Instance) anyerror!void {
        return try NodeIteratorImpl.call_detach(instance);
    }

    pub fn call_previousNode(instance: *runtime.Instance) anyerror!Node {
        return try NodeIteratorImpl.call_previousNode(instance);
    }

};

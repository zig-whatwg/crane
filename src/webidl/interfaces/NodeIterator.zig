//! Generated from: dom.idl
//! Generated at: 2025-11-19T20:02:01Z
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
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            root: Node = undefined,
            referenceNode: Node = undefined,
            pointerBeforeReferenceNode: bool = undefined,
            whatToShow: u32 = undefined,
            filter: ?NodeFilter = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NodeIterator, .{
        .deinit_fn = &deinit_wrapper,

        .get_filter = &get_filter,
        .get_pointerBeforeReferenceNode = &get_pointerBeforeReferenceNode,
        .get_referenceNode = &get_referenceNode,
        .get_root = &get_root,
        .get_whatToShow = &get_whatToShow,

        .call_detach = &call_detach,
        .call_nextNode = &call_nextNode,
        .call_previousNode = &call_previousNode,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return NodeIteratorImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NodeIteratorImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_root(instance: *runtime.Instance) anyerror!Node {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_root) |cached| {
            return cached;
        }
        const value = try NodeIteratorImpl.get_root(instance);
        state.cached_root = value;
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

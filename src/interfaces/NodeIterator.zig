//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NodeIteratorImpl = @import("../impls/NodeIterator.zig");

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        NodeIteratorImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        NodeIteratorImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_root(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_root) |cached| {
            return cached;
        }
        const value = NodeIteratorImpl.get_root(state);
        state.cached_root = value;
        return value;
    }

    pub fn get_referenceNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeIteratorImpl.get_referenceNode(state);
    }

    pub fn get_pointerBeforeReferenceNode(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return NodeIteratorImpl.get_pointerBeforeReferenceNode(state);
    }

    pub fn get_whatToShow(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return NodeIteratorImpl.get_whatToShow(state);
    }

    pub fn get_filter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeIteratorImpl.get_filter(state);
    }

    pub fn call_nextNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeIteratorImpl.call_nextNode(state);
    }

    pub fn call_detach(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeIteratorImpl.call_detach(state);
    }

    pub fn call_previousNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return NodeIteratorImpl.call_previousNode(state);
    }

};

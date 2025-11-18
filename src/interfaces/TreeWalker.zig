//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TreeWalkerImpl = @import("../impls/TreeWalker.zig");

pub const TreeWalker = struct {
    pub const Meta = struct {
        pub const name = "TreeWalker";
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
            whatToShow: u32 = undefined,
            filter: ?NodeFilter = null,
            currentNode: Node = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TreeWalker, .{
        .deinit_fn = &deinit_wrapper,

        .get_currentNode = &get_currentNode,
        .get_filter = &get_filter,
        .get_root = &get_root,
        .get_whatToShow = &get_whatToShow,

        .set_currentNode = &set_currentNode,

        .call_firstChild = &call_firstChild,
        .call_lastChild = &call_lastChild,
        .call_nextNode = &call_nextNode,
        .call_nextSibling = &call_nextSibling,
        .call_parentNode = &call_parentNode,
        .call_previousNode = &call_previousNode,
        .call_previousSibling = &call_previousSibling,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TreeWalkerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TreeWalkerImpl.deinit(state);
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
        const value = TreeWalkerImpl.get_root(state);
        state.cached_root = value;
        return value;
    }

    pub fn get_whatToShow(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return TreeWalkerImpl.get_whatToShow(state);
    }

    pub fn get_filter(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.get_filter(state);
    }

    pub fn get_currentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.get_currentNode(state);
    }

    pub fn set_currentNode(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        TreeWalkerImpl.set_currentNode(state, value);
    }

    pub fn call_parentNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_parentNode(state);
    }

    pub fn call_previousNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_previousNode(state);
    }

    pub fn call_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_lastChild(state);
    }

    pub fn call_nextNode(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_nextNode(state);
    }

    pub fn call_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_firstChild(state);
    }

    pub fn call_previousSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_previousSibling(state);
    }

    pub fn call_nextSibling(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return TreeWalkerImpl.call_nextSibling(state);
    }

};

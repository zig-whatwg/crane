//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TreeWalkerImpl = @import("impls").TreeWalker;
const Node = @import("interfaces").Node;
const NodeFilter = @import("interfaces").NodeFilter;

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
        
        // Initialize the instance (Impl receives full instance)
        TreeWalkerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TreeWalkerImpl.deinit(instance);
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
        const value = try TreeWalkerImpl.get_root(instance);
        state.cached_root = value;
        return value;
    }

    pub fn get_whatToShow(instance: *runtime.Instance) anyerror!u32 {
        return try TreeWalkerImpl.get_whatToShow(instance);
    }

    pub fn get_filter(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.get_filter(instance);
    }

    pub fn get_currentNode(instance: *runtime.Instance) anyerror!Node {
        return try TreeWalkerImpl.get_currentNode(instance);
    }

    pub fn set_currentNode(instance: *runtime.Instance, value: Node) anyerror!void {
        try TreeWalkerImpl.set_currentNode(instance, value);
    }

    pub fn call_parentNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_parentNode(instance);
    }

    pub fn call_previousNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_previousNode(instance);
    }

    pub fn call_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_lastChild(instance);
    }

    pub fn call_nextNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_nextNode(instance);
    }

    pub fn call_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_firstChild(instance);
    }

    pub fn call_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_previousSibling(instance);
    }

    pub fn call_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try TreeWalkerImpl.call_nextSibling(instance);
    }

};

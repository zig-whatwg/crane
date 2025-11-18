//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ChildNodeImpl = @import("../impls/ChildNode.zig");

pub const ChildNode = struct {
    pub const Meta = struct {
        pub const name = "ChildNode";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ChildNode, .{
        .deinit_fn = &deinit_wrapper,

        .call_after = &call_after,
        .call_before = &call_before,
        .call_remove = &call_remove,
        .call_replaceWith = &call_replaceWith,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ChildNodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ChildNodeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ChildNodeImpl.call_replaceWith(state, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ChildNodeImpl.call_before(state, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ChildNodeImpl.call_after(state, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return ChildNodeImpl.call_remove(state);
    }

};

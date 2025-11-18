//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ParentNodeImpl = @import("../impls/ParentNode.zig");

pub const ParentNode = struct {
    pub const Meta = struct {
        pub const name = "ParentNode";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            children: HTMLCollection = undefined,
            firstElementChild: ?Element = null,
            lastElementChild: ?Element = null,
            childElementCount: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ParentNode, .{
        .deinit_fn = &deinit_wrapper,

        .get_childElementCount = &get_childElementCount,
        .get_children = &get_children,
        .get_firstElementChild = &get_firstElementChild,
        .get_lastElementChild = &get_lastElementChild,

        .call_append = &call_append,
        .call_moveBefore = &call_moveBefore,
        .call_prepend = &call_prepend,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_replaceChildren = &call_replaceChildren,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ParentNodeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ParentNodeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = ParentNodeImpl.get_children(state);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ParentNodeImpl.get_firstElementChild(state);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ParentNodeImpl.get_lastElementChild(state);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return ParentNodeImpl.get_childElementCount(state);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return ParentNodeImpl.call_querySelectorAll(state, selectors);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ParentNodeImpl.call_append(state, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ParentNodeImpl.call_replaceChildren(state, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: anyopaque, child: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ParentNodeImpl.call_moveBefore(state, node, child);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return ParentNodeImpl.call_prepend(state, nodes);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return ParentNodeImpl.call_querySelector(state, selectors);
    }

};

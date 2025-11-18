//! Generated from: web-animations-2.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SequenceEffectImpl = @import("../impls/SequenceEffect.zig");
const GroupEffect = @import("GroupEffect.zig");

pub const SequenceEffect = struct {
    pub const Meta = struct {
        pub const name = "SequenceEffect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *GroupEffect;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SequenceEffect, .{
        .deinit_fn = &deinit_wrapper,

        .get_children = &get_children,
        .get_firstChild = &get_firstChild,
        .get_lastChild = &get_lastChild,

        .call_append = &call_append,
        .call_clone = &call_clone,
        .call_clone = &call_clone,
        .call_prepend = &call_prepend,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SequenceEffectImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SequenceEffectImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, children: anyopaque, timing: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SequenceEffectImpl.constructor(state, children, timing);
        
        return instance;
    }

    pub fn get_children(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SequenceEffectImpl.get_children(state);
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SequenceEffectImpl.get_firstChild(state);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SequenceEffectImpl.get_lastChild(state);
    }

    /// Arguments for clone (WebIDL overloading)
    pub const CloneArgs = union(enum) {
        /// clone()
        no_params: void,
        /// clone()
        no_params: void,
    };

    pub fn call_clone(instance: *runtime.Instance, args: CloneArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return SequenceEffectImpl.no_params(state),
            .no_params => return SequenceEffectImpl.no_params(state),
        }
    }

    pub fn call_append(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SequenceEffectImpl.call_append(state, effects);
    }

    pub fn call_prepend(instance: *runtime.Instance, effects: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SequenceEffectImpl.call_prepend(state, effects);
    }

};

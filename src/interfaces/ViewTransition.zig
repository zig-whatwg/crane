//! Generated from: css-view-transitions.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewTransitionImpl = @import("../impls/ViewTransition.zig");

pub const ViewTransition = struct {
    pub const Meta = struct {
        pub const name = "ViewTransition";
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
            updateCallbackDone: Promise<undefined> = undefined,
            ready: Promise<undefined> = undefined,
            finished: Promise<undefined> = undefined,
            types: ViewTransitionTypeSet = undefined,
            transitionRoot: Element = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ViewTransition, .{
        .deinit_fn = &deinit_wrapper,

        .get_finished = &get_finished,
        .get_ready = &get_ready,
        .get_transitionRoot = &get_transitionRoot,
        .get_types = &get_types,
        .get_updateCallbackDone = &get_updateCallbackDone,

        .set_types = &set_types,

        .call_skipTransition = &call_skipTransition,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ViewTransitionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ViewTransitionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_updateCallbackDone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ViewTransitionImpl.get_updateCallbackDone(state);
    }

    pub fn get_ready(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ViewTransitionImpl.get_ready(state);
    }

    pub fn get_finished(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ViewTransitionImpl.get_finished(state);
    }

    pub fn get_types(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ViewTransitionImpl.get_types(state);
    }

    pub fn set_types(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        ViewTransitionImpl.set_types(state, value);
    }

    pub fn get_transitionRoot(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ViewTransitionImpl.get_transitionRoot(state);
    }

    pub fn call_skipTransition(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return ViewTransitionImpl.call_skipTransition(state);
    }

};

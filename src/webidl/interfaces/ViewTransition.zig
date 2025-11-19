//! Generated from: css-view-transitions.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewTransitionImpl = @import("impls").ViewTransition;
const ViewTransitionTypeSet = @import("interfaces").ViewTransitionTypeSet;
const Element = @import("interfaces").Element;

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
            updateCallbackDone: runtime.Promise(undefined) = undefined,
            ready: runtime.Promise(undefined) = undefined,
            finished: runtime.Promise(undefined) = undefined,
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
        .call_waitUntil = &call_waitUntil,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return ViewTransitionImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewTransitionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_updateCallbackDone(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTransitionImpl.get_updateCallbackDone(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTransitionImpl.get_ready(instance);
    }

    pub fn get_finished(instance: *runtime.Instance) anyerror!anyopaque {
        return try ViewTransitionImpl.get_finished(instance);
    }

    pub fn get_types(instance: *runtime.Instance) anyerror!ViewTransitionTypeSet {
        return try ViewTransitionImpl.get_types(instance);
    }

    pub fn set_types(instance: *runtime.Instance, value: ViewTransitionTypeSet) anyerror!void {
        try ViewTransitionImpl.set_types(instance, value);
    }

    pub fn get_transitionRoot(instance: *runtime.Instance) anyerror!Element {
        return try ViewTransitionImpl.get_transitionRoot(instance);
    }

    pub fn call_waitUntil(instance: *runtime.Instance, promise: anyopaque) anyerror!void {
        
        return try ViewTransitionImpl.call_waitUntil(instance, promise);
    }

    pub fn call_skipTransition(instance: *runtime.Instance) anyerror!void {
        return try ViewTransitionImpl.call_skipTransition(instance);
    }

};

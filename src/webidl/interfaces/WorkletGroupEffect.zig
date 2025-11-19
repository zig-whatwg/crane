//! Generated from: css-animation-worklet.idl
//! Generated at: 2025-11-19T20:02:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WorkletGroupEffectImpl = @import("impls").WorkletGroupEffect;
const WorkletAnimationEffect = @import("interfaces").WorkletAnimationEffect;

pub const WorkletGroupEffect = struct {
    pub const Meta = struct {
        pub const name = "WorkletGroupEffect";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "AnimationWorklet" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .AnimationWorklet = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WorkletGroupEffect, .{
        .deinit_fn = &deinit_wrapper,

        .call_getChildren = &call_getChildren,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return WorkletGroupEffectImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WorkletGroupEffectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getChildren(instance: *runtime.Instance) anyerror!anyopaque {
        return try WorkletGroupEffectImpl.call_getChildren(instance);
    }

};

//! Generated from: web-animations-2.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SequenceEffectImpl = @import("impls").SequenceEffect;
const GroupEffect = @import("interfaces").GroupEffect;
const AnimationEffect = @import("interfaces").AnimationEffect;
const AnimationNodeList = @import("interfaces").AnimationNodeList;
const EffectTiming = @import("dictionaries").EffectTiming;

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
        .call_prepend = &call_prepend,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return SequenceEffectImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SequenceEffectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, children: anyopaque, timing: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SequenceEffectImpl.constructor(instance, children, timing);
        
        return instance;
    }

    pub fn get_children(instance: *runtime.Instance) anyerror!AnimationNodeList {
        return try SequenceEffectImpl.get_children(instance);
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!AnimationEffect {
        return try SequenceEffectImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!AnimationEffect {
        return try SequenceEffectImpl.get_lastChild(instance);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!GroupEffect {
        return try SequenceEffectImpl.call_clone(instance);
    }

    pub fn call_append(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try SequenceEffectImpl.call_append(instance, effects);
    }

    pub fn call_prepend(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try SequenceEffectImpl.call_prepend(instance, effects);
    }

};

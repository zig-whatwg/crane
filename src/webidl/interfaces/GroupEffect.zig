//! Generated from: web-animations-2.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GroupEffectImpl = @import("impls").GroupEffect;
const sequence = @import("interfaces").sequence;
const AnimationNodeList = @import("interfaces").AnimationNodeList;
const AnimationEffect = @import("interfaces").AnimationEffect;
const (unrestricted double or EffectTiming) = @import("interfaces").(unrestricted double or EffectTiming);

pub const GroupEffect = struct {
    pub const Meta = struct {
        pub const name = "GroupEffect";
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
            children: AnimationNodeList = undefined,
            firstChild: ?AnimationEffect = null,
            lastChild: ?AnimationEffect = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GroupEffect, .{
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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GroupEffectImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GroupEffectImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, children: anyopaque, timing: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try GroupEffectImpl.constructor(instance, children, timing);
        
        return instance;
    }

    pub fn get_children(instance: *runtime.Instance) anyerror!AnimationNodeList {
        return try GroupEffectImpl.get_children(instance);
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try GroupEffectImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try GroupEffectImpl.get_lastChild(instance);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!GroupEffect {
        return try GroupEffectImpl.call_clone(instance);
    }

    pub fn call_append(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try GroupEffectImpl.call_append(instance, effects);
    }

    pub fn call_prepend(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try GroupEffectImpl.call_prepend(instance, effects);
    }

};

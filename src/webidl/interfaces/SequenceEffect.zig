//! Generated from: web-animations-2.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SequenceEffectImpl = @import("impls").SequenceEffect;
const GroupEffect = @import("interfaces").GroupEffect;
const sequence = @import("interfaces").sequence;
const (unrestricted double or EffectTiming) = @import("interfaces").(unrestricted double or EffectTiming);

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
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SequenceEffectImpl.init(instance);
        
        return instance;
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

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try SequenceEffectImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try SequenceEffectImpl.get_lastChild(instance);
    }

    /// Arguments for clone (WebIDL overloading)
    pub const CloneArgs = union(enum) {
        /// clone()
        no_params: void,
        /// clone()
        no_params: void,
    };

    pub fn call_clone(instance: *runtime.Instance, args: CloneArgs) anyerror!GroupEffect {
        switch (args) {
            .no_params => return try SequenceEffectImpl.no_params(instance),
            .no_params => return try SequenceEffectImpl.no_params(instance),
        }
    }

    pub fn call_append(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try SequenceEffectImpl.call_append(instance, effects);
    }

    pub fn call_prepend(instance: *runtime.Instance, effects: AnimationEffect) anyerror!void {
        
        return try SequenceEffectImpl.call_prepend(instance, effects);
    }

};

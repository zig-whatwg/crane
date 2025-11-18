//! Generated from: dom.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const StaticRangeImpl = @import("../impls/StaticRange.zig");
const AbstractRange = @import("AbstractRange.zig");

pub const StaticRange = struct {
    pub const Meta = struct {
        pub const name = "StaticRange";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbstractRange;
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

    pub const vtable = runtime.buildVTable(StaticRange, .{
        .deinit_fn = &deinit_wrapper,

        .get_collapsed = &get_collapsed,
        .get_endContainer = &get_endContainer,
        .get_endOffset = &get_endOffset,
        .get_startContainer = &get_startContainer,
        .get_startOffset = &get_startOffset,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        StaticRangeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        StaticRangeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, init: anyopaque) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try StaticRangeImpl.constructor(state, init);
        
        return instance;
    }

    pub fn get_startContainer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StaticRangeImpl.get_startContainer(state);
    }

    pub fn get_startOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StaticRangeImpl.get_startOffset(state);
    }

    pub fn get_endContainer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return StaticRangeImpl.get_endContainer(state);
    }

    pub fn get_endOffset(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return StaticRangeImpl.get_endOffset(state);
    }

    pub fn get_collapsed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return StaticRangeImpl.get_collapsed(state);
    }

};

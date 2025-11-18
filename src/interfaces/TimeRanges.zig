//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TimeRangesImpl = @import("../impls/TimeRanges.zig");

pub const TimeRanges = struct {
    pub const Meta = struct {
        pub const name = "TimeRanges";
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
            length: u32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TimeRanges, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,

        .call_end = &call_end,
        .call_start = &call_start,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        TimeRangesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        TimeRangesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return TimeRangesImpl.get_length(state);
    }

    pub fn call_start(instance: *runtime.Instance, index: u32) f64 {
        const state = instance.getState(State);
        
        return TimeRangesImpl.call_start(state, index);
    }

    pub fn call_end(instance: *runtime.Instance, index: u32) f64 {
        const state = instance.getState(State);
        
        return TimeRangesImpl.call_end(state, index);
    }

};

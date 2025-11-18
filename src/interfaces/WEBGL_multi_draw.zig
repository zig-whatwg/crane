//! Generated from: WEBGL_multi_draw.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_multi_drawImpl = @import("../impls/WEBGL_multi_draw.zig");

pub const WEBGL_multi_draw = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_multi_draw";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WEBGL_multi_draw, .{
        .deinit_fn = &deinit_wrapper,

        .call_multiDrawArraysInstancedWEBGL = &call_multiDrawArraysInstancedWEBGL,
        .call_multiDrawArraysWEBGL = &call_multiDrawArraysWEBGL,
        .call_multiDrawElementsInstancedWEBGL = &call_multiDrawElementsInstancedWEBGL,
        .call_multiDrawElementsWEBGL = &call_multiDrawElementsWEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_multi_drawImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_multi_drawImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_multiDrawArraysWEBGL(instance: *runtime.Instance, mode: anyopaque, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, drawcount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_multi_drawImpl.call_multiDrawArraysWEBGL(state, mode, firstsList, firstsOffset, countsList, countsOffset, drawcount);
    }

    pub fn call_multiDrawElementsWEBGL(instance: *runtime.Instance, mode: anyopaque, countsList: anyopaque, countsOffset: u64, type_: anyopaque, offsetsList: anyopaque, offsetsOffset: u64, drawcount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_multi_drawImpl.call_multiDrawElementsWEBGL(state, mode, countsList, countsOffset, type_, offsetsList, offsetsOffset, drawcount);
    }

    pub fn call_multiDrawArraysInstancedWEBGL(instance: *runtime.Instance, mode: anyopaque, firstsList: anyopaque, firstsOffset: u64, countsList: anyopaque, countsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, drawcount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_multi_drawImpl.call_multiDrawArraysInstancedWEBGL(state, mode, firstsList, firstsOffset, countsList, countsOffset, instanceCountsList, instanceCountsOffset, drawcount);
    }

    pub fn call_multiDrawElementsInstancedWEBGL(instance: *runtime.Instance, mode: anyopaque, countsList: anyopaque, countsOffset: u64, type_: anyopaque, offsetsList: anyopaque, offsetsOffset: u64, instanceCountsList: anyopaque, instanceCountsOffset: u64, drawcount: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WEBGL_multi_drawImpl.call_multiDrawElementsInstancedWEBGL(state, mode, countsList, countsOffset, type_, offsetsList, offsetsOffset, instanceCountsList, instanceCountsOffset, drawcount);
    }

};

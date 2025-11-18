//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingStrokeImpl = @import("../impls/HandwritingStroke.zig");

pub const HandwritingStroke = struct {
    pub const Meta = struct {
        pub const name = "HandwritingStroke";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
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

    pub const vtable = runtime.buildVTable(HandwritingStroke, .{
        .deinit_fn = &deinit_wrapper,

        .call_addPoint = &call_addPoint,
        .call_clear = &call_clear,
        .call_getPoints = &call_getPoints,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HandwritingStrokeImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HandwritingStrokeImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try HandwritingStrokeImpl.constructor(state);
        
        return instance;
    }

    pub fn call_addPoint(instance: *runtime.Instance, point: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HandwritingStrokeImpl.call_addPoint(state, point);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HandwritingStrokeImpl.call_clear(state);
    }

    pub fn call_getPoints(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HandwritingStrokeImpl.call_getPoints(state);
    }

};

//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingDrawingImpl = @import("../impls/HandwritingDrawing.zig");

pub const HandwritingDrawing = struct {
    pub const Meta = struct {
        pub const name = "HandwritingDrawing";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(HandwritingDrawing, .{
        .deinit_fn = &deinit_wrapper,

        .call_addStroke = &call_addStroke,
        .call_clear = &call_clear,
        .call_getPrediction = &call_getPrediction,
        .call_getStrokes = &call_getStrokes,
        .call_removeStroke = &call_removeStroke,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HandwritingDrawingImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HandwritingDrawingImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_addStroke(instance: *runtime.Instance, stroke: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HandwritingDrawingImpl.call_addStroke(state, stroke);
    }

    pub fn call_getStrokes(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HandwritingDrawingImpl.call_getStrokes(state);
    }

    pub fn call_getPrediction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HandwritingDrawingImpl.call_getPrediction(state);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HandwritingDrawingImpl.call_clear(state);
    }

    pub fn call_removeStroke(instance: *runtime.Instance, stroke: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HandwritingDrawingImpl.call_removeStroke(state, stroke);
    }

};

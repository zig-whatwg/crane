//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingDrawingImpl = @import("impls").HandwritingDrawing;
const HandwritingStroke = @import("interfaces").HandwritingStroke;
const Promise<sequence<HandwritingPrediction>> = @import("interfaces").Promise<sequence<HandwritingPrediction>>;

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
        
        // Initialize the instance (Impl receives full instance)
        HandwritingDrawingImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HandwritingDrawingImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_addStroke(instance: *runtime.Instance, stroke: HandwritingStroke) anyerror!void {
        
        return try HandwritingDrawingImpl.call_addStroke(instance, stroke);
    }

    pub fn call_getStrokes(instance: *runtime.Instance) anyerror!anyopaque {
        return try HandwritingDrawingImpl.call_getStrokes(instance);
    }

    pub fn call_getPrediction(instance: *runtime.Instance) anyerror!anyopaque {
        return try HandwritingDrawingImpl.call_getPrediction(instance);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try HandwritingDrawingImpl.call_clear(instance);
    }

    pub fn call_removeStroke(instance: *runtime.Instance, stroke: HandwritingStroke) anyerror!void {
        
        return try HandwritingDrawingImpl.call_removeStroke(instance, stroke);
    }

};

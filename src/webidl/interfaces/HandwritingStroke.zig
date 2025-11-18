//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingStrokeImpl = @import("impls").HandwritingStroke;
const HandwritingPoint = @import("dictionaries").HandwritingPoint;

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
        
        // Initialize the instance (Impl receives full instance)
        HandwritingStrokeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HandwritingStrokeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try HandwritingStrokeImpl.constructor(instance);
        
        return instance;
    }

    pub fn call_addPoint(instance: *runtime.Instance, point: HandwritingPoint) anyerror!void {
        
        return try HandwritingStrokeImpl.call_addPoint(instance, point);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try HandwritingStrokeImpl.call_clear(instance);
    }

    pub fn call_getPoints(instance: *runtime.Instance) anyerror!anyopaque {
        return try HandwritingStrokeImpl.call_getPoints(instance);
    }

};

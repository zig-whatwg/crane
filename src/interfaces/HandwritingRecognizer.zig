//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingRecognizerImpl = @import("../impls/HandwritingRecognizer.zig");

pub const HandwritingRecognizer = struct {
    pub const Meta = struct {
        pub const name = "HandwritingRecognizer";
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

    pub const vtable = runtime.buildVTable(HandwritingRecognizer, .{
        .deinit_fn = &deinit_wrapper,

        .call_finish = &call_finish,
        .call_startDrawing = &call_startDrawing,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HandwritingRecognizerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HandwritingRecognizerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_finish(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HandwritingRecognizerImpl.call_finish(state);
    }

    pub fn call_startDrawing(instance: *runtime.Instance, hints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HandwritingRecognizerImpl.call_startDrawing(state, hints);
    }

};

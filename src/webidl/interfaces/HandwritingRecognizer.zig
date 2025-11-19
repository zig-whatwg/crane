//! Generated from: handwriting-recognition.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HandwritingRecognizerImpl = @import("impls").HandwritingRecognizer;
const HandwritingDrawing = @import("interfaces").HandwritingDrawing;
const HandwritingHints = @import("dictionaries").HandwritingHints;

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
        return HandwritingRecognizerImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HandwritingRecognizerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_finish(instance: *runtime.Instance) anyerror!void {
        return try HandwritingRecognizerImpl.call_finish(instance);
    }

    pub fn call_startDrawing(instance: *runtime.Instance, hints: HandwritingHints) anyerror!HandwritingDrawing {
        
        return try HandwritingRecognizerImpl.call_startDrawing(instance, hints);
    }

};

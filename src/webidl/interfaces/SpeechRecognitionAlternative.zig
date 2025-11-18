//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionAlternativeImpl = @import("impls").SpeechRecognitionAlternative;

pub const SpeechRecognitionAlternative = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionAlternative";
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
        struct {
            transcript: runtime.DOMString = undefined,
            confidence: f32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechRecognitionAlternative, .{
        .deinit_fn = &deinit_wrapper,

        .get_confidence = &get_confidence,
        .get_transcript = &get_transcript,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SpeechRecognitionAlternativeImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionAlternativeImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_transcript(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechRecognitionAlternativeImpl.get_transcript(instance);
    }

    pub fn get_confidence(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechRecognitionAlternativeImpl.get_confidence(instance);
    }

};

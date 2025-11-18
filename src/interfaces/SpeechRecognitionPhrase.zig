//! Generated from: speech-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionPhraseImpl = @import("../impls/SpeechRecognitionPhrase.zig");

pub const SpeechRecognitionPhrase = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognitionPhrase";
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
            phrase: runtime.DOMString = undefined,
            boost: f32 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechRecognitionPhrase, .{
        .deinit_fn = &deinit_wrapper,

        .get_boost = &get_boost,
        .get_phrase = &get_phrase,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SpeechRecognitionPhraseImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SpeechRecognitionPhraseImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, phrase: runtime.DOMString, boost: f32) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SpeechRecognitionPhraseImpl.constructor(state, phrase, boost);
        
        return instance;
    }

    pub fn get_phrase(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SpeechRecognitionPhraseImpl.get_phrase(state);
    }

    pub fn get_boost(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SpeechRecognitionPhraseImpl.get_boost(state);
    }

};

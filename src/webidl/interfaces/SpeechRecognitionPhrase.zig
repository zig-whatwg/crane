//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionPhraseImpl = @import("impls").SpeechRecognitionPhrase;

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
        
        // Initialize the instance (Impl receives full instance)
        SpeechRecognitionPhraseImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionPhraseImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, phrase: DOMString, boost: f32) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SpeechRecognitionPhraseImpl.constructor(instance, phrase, boost);
        
        return instance;
    }

    pub fn get_phrase(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechRecognitionPhraseImpl.get_phrase(instance);
    }

    pub fn get_boost(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechRecognitionPhraseImpl.get_boost(instance);
    }

};

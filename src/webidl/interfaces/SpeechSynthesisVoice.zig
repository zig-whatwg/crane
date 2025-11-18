//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisVoiceImpl = @import("impls").SpeechSynthesisVoice;

pub const SpeechSynthesisVoice = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisVoice";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            voiceURI: runtime.DOMString = undefined,
            name: runtime.DOMString = undefined,
            lang: runtime.DOMString = undefined,
            localService: bool = undefined,
            default: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechSynthesisVoice, .{
        .deinit_fn = &deinit_wrapper,

        .get_default = &get_default,
        .get_lang = &get_lang,
        .get_localService = &get_localService,
        .get_name = &get_name,
        .get_voiceURI = &get_voiceURI,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        SpeechSynthesisVoiceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisVoiceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_voiceURI(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_voiceURI(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_name(instance);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisVoiceImpl.get_lang(instance);
    }

    pub fn get_localService(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisVoiceImpl.get_localService(instance);
    }

    pub fn get_default(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisVoiceImpl.get_default(instance);
    }

};

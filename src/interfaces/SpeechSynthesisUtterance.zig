//! Generated from: speech-api.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisUtteranceImpl = @import("../impls/SpeechSynthesisUtterance.zig");
const EventTarget = @import("EventTarget.zig");

pub const SpeechSynthesisUtterance = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisUtterance";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            text: runtime.DOMString = undefined,
            lang: runtime.DOMString = undefined,
            voice: ?SpeechSynthesisVoice = null,
            volume: f32 = undefined,
            rate: f32 = undefined,
            pitch: f32 = undefined,
            onstart: EventHandler = undefined,
            onend: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onpause: EventHandler = undefined,
            onresume: EventHandler = undefined,
            onmark: EventHandler = undefined,
            onboundary: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechSynthesisUtterance, .{
        .deinit_fn = &deinit_wrapper,

        .get_lang = &get_lang,
        .get_onboundary = &get_onboundary,
        .get_onend = &get_onend,
        .get_onerror = &get_onerror,
        .get_onmark = &get_onmark,
        .get_onpause = &get_onpause,
        .get_onresume = &get_onresume,
        .get_onstart = &get_onstart,
        .get_pitch = &get_pitch,
        .get_rate = &get_rate,
        .get_text = &get_text,
        .get_voice = &get_voice,
        .get_volume = &get_volume,

        .set_lang = &set_lang,
        .set_onboundary = &set_onboundary,
        .set_onend = &set_onend,
        .set_onerror = &set_onerror,
        .set_onmark = &set_onmark,
        .set_onpause = &set_onpause,
        .set_onresume = &set_onresume,
        .set_onstart = &set_onstart,
        .set_pitch = &set_pitch,
        .set_rate = &set_rate,
        .set_text = &set_text,
        .set_voice = &set_voice,
        .set_volume = &set_volume,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SpeechSynthesisUtteranceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, text: runtime.DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SpeechSynthesisUtteranceImpl.constructor(state, text);
        
        return instance;
    }

    pub fn get_text(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_text(state);
    }

    pub fn set_text(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_text(state, value);
    }

    pub fn get_lang(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_lang(state);
    }

    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_lang(state, value);
    }

    pub fn get_voice(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_voice(state);
    }

    pub fn set_voice(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_voice(state, value);
    }

    pub fn get_volume(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_volume(state);
    }

    pub fn set_volume(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_volume(state, value);
    }

    pub fn get_rate(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_rate(state);
    }

    pub fn set_rate(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_rate(state, value);
    }

    pub fn get_pitch(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_pitch(state);
    }

    pub fn set_pitch(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_pitch(state, value);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onstart(state);
    }

    pub fn set_onstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onstart(state, value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onend(state);
    }

    pub fn set_onend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onend(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onerror(state, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onpause(state);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onpause(state, value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onresume(state);
    }

    pub fn set_onresume(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onresume(state, value);
    }

    pub fn get_onmark(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onmark(state);
    }

    pub fn set_onmark(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onmark(state, value);
    }

    pub fn get_onboundary(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisUtteranceImpl.get_onboundary(state);
    }

    pub fn set_onboundary(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisUtteranceImpl.set_onboundary(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SpeechSynthesisUtteranceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisUtteranceImpl.call_when(state, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisUtteranceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisUtteranceImpl.call_removeEventListener(state, type_, callback, options);
    }

};

//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisUtteranceImpl = @import("impls").SpeechSynthesisUtterance;
const EventTarget = @import("interfaces").EventTarget;
const SpeechSynthesisVoice = @import("interfaces").SpeechSynthesisVoice;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        SpeechSynthesisUtteranceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisUtteranceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, text: DOMString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SpeechSynthesisUtteranceImpl.constructor(instance, text);
        
        return instance;
    }

    pub fn get_text(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisUtteranceImpl.get_text(instance);
    }

    pub fn set_text(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_text(instance, value);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechSynthesisUtteranceImpl.get_lang(instance);
    }

    pub fn set_lang(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_lang(instance, value);
    }

    pub fn get_voice(instance: *runtime.Instance) anyerror!anyopaque {
        return try SpeechSynthesisUtteranceImpl.get_voice(instance);
    }

    pub fn set_voice(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_voice(instance, value);
    }

    pub fn get_volume(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisUtteranceImpl.get_volume(instance);
    }

    pub fn set_volume(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_volume(instance, value);
    }

    pub fn get_rate(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisUtteranceImpl.get_rate(instance);
    }

    pub fn set_rate(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_rate(instance, value);
    }

    pub fn get_pitch(instance: *runtime.Instance) anyerror!f32 {
        return try SpeechSynthesisUtteranceImpl.get_pitch(instance);
    }

    pub fn set_pitch(instance: *runtime.Instance, value: f32) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_pitch(instance, value);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onstart(instance);
    }

    pub fn set_onstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onstart(instance, value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onend(instance);
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onend(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onerror(instance, value);
    }

    pub fn get_onpause(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onpause(instance);
    }

    pub fn set_onpause(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onpause(instance, value);
    }

    pub fn get_onresume(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onresume(instance);
    }

    pub fn set_onresume(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onresume(instance, value);
    }

    pub fn get_onmark(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onmark(instance);
    }

    pub fn set_onmark(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onmark(instance, value);
    }

    pub fn get_onboundary(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisUtteranceImpl.get_onboundary(instance);
    }

    pub fn set_onboundary(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisUtteranceImpl.set_onboundary(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SpeechSynthesisUtteranceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SpeechSynthesisUtteranceImpl.call_when(instance, type_, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SpeechSynthesisUtteranceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SpeechSynthesisUtteranceImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

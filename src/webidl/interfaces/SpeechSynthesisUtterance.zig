//! Generated from: speech-api.idl
//! Generated at: 2025-11-29T05:01:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechSynthesisUtteranceImpl = @import("impls").SpeechSynthesisUtterance;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const SpeechSynthesisVoice = @import("interfaces").SpeechSynthesisVoice;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const SpeechSynthesisUtterance = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesisUtterance";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "text", "get_text", "set_text" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "voice", "get_voice", "set_voice" },
            .{ "volume", "get_volume", "set_volume" },
            .{ "rate", "get_rate", "set_rate" },
            .{ "pitch", "get_pitch", "set_pitch" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onmark", "get_onmark", "set_onmark" },
            .{ "onboundary", "get_onboundary", "set_onboundary" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "text", "get_text", "set_text" },
            .{ "voice", "get_voice", "set_voice" },
            .{ "volume", "get_volume", "set_volume" },
            .{ "rate", "get_rate", "set_rate" },
            .{ "pitch", "get_pitch", "set_pitch" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onpause", "get_onpause", "set_onpause" },
            .{ "onresume", "get_onresume", "set_onresume" },
            .{ "onmark", "get_onmark", "set_onmark" },
            .{ "onboundary", "get_onboundary", "set_onboundary" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "lang", "get_lang", "set_lang" },
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            text: runtime.DOMString = undefined,
            lang: runtime.DOMString = undefined,
            voice: ?*runtime.Instance = null,
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
            _internal: ?*SpeechSynthesisUtteranceImpl.InternalState = null,
        },
    );

    const delegates = .{

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
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechSynthesisUtteranceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisUtteranceImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, text: webidl.Opt(DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechSynthesisUtteranceImpl.call_constructor(allocator, ctx, text);
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

    pub fn get_voice(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try SpeechSynthesisUtteranceImpl.get_voice(instance);
    }

    pub fn set_voice(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
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

};

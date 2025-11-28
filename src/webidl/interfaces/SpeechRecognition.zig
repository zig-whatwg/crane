//! Generated from: speech-api.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionImpl = @import("impls").SpeechRecognition;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AvailabilityStatus = @import("enums").AvailabilityStatus;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const SpeechRecognitionOptions = @import("dictionaries").SpeechRecognitionOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SpeechGrammarList = @import("interfaces").SpeechGrammarList;
const EventListener = @import("interfaces").EventListener;
const SpeechRecognitionPhrase = @import("interfaces").SpeechRecognitionPhrase;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const SpeechRecognition = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognition";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "grammars", "get_grammars", "set_grammars" },
            .{ "lang", "get_lang", "set_lang" },
            .{ "continuous", "get_continuous", "set_continuous" },
            .{ "interimResults", "get_interimResults", "set_interimResults" },
            .{ "maxAlternatives", "get_maxAlternatives", "set_maxAlternatives" },
            .{ "processLocally", "get_processLocally", "set_processLocally" },
            .{ "phrases", "get_phrases", "set_phrases" },
            .{ "onaudiostart", "get_onaudiostart", "set_onaudiostart" },
            .{ "onsoundstart", "get_onsoundstart", "set_onsoundstart" },
            .{ "onspeechstart", "get_onspeechstart", "set_onspeechstart" },
            .{ "onspeechend", "get_onspeechend", "set_onspeechend" },
            .{ "onsoundend", "get_onsoundend", "set_onsoundend" },
            .{ "onaudioend", "get_onaudioend", "set_onaudioend" },
            .{ "onresult", "get_onresult", "set_onresult" },
            .{ "onnomatch", "get_onnomatch", "set_onnomatch" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
            .{ "start", "call_start", 1 },
            .{ "stop", "call_stop", 0 },
            .{ "abort", "call_abort", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "available", "call_available", 1 },
            .{ "install", "call_install", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "start",
            "start",
            "stop",
            "abort",
            "available",
            "install",
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
            .{ "grammars", "get_grammars", "set_grammars" },
            .{ "continuous", "get_continuous", "set_continuous" },
            .{ "interimResults", "get_interimResults", "set_interimResults" },
            .{ "maxAlternatives", "get_maxAlternatives", "set_maxAlternatives" },
            .{ "processLocally", "get_processLocally", "set_processLocally" },
            .{ "phrases", "get_phrases", "set_phrases" },
            .{ "onaudiostart", "get_onaudiostart", "set_onaudiostart" },
            .{ "onsoundstart", "get_onsoundstart", "set_onsoundstart" },
            .{ "onspeechstart", "get_onspeechstart", "set_onspeechstart" },
            .{ "onspeechend", "get_onspeechend", "set_onspeechend" },
            .{ "onsoundend", "get_onsoundend", "set_onsoundend" },
            .{ "onaudioend", "get_onaudioend", "set_onaudioend" },
            .{ "onresult", "get_onresult", "set_onresult" },
            .{ "onnomatch", "get_onnomatch", "set_onnomatch" },
            .{ "onerror", "get_onerror", "set_onerror" },
            .{ "onstart", "get_onstart", "set_onstart" },
            .{ "onend", "get_onend", "set_onend" },
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
            grammars: *runtime.Instance = undefined,
            lang: runtime.DOMString = undefined,
            continuous: bool = undefined,
            interimResults: bool = undefined,
            maxAlternatives: u32 = undefined,
            processLocally: bool = undefined,
            phrases: runtime.ObservableArray(SpeechRecognitionPhrase) = undefined,
            onaudiostart: EventHandler = undefined,
            onsoundstart: EventHandler = undefined,
            onspeechstart: EventHandler = undefined,
            onspeechend: EventHandler = undefined,
            onsoundend: EventHandler = undefined,
            onaudioend: EventHandler = undefined,
            onresult: EventHandler = undefined,
            onnomatch: EventHandler = undefined,
            onerror: EventHandler = undefined,
            onstart: EventHandler = undefined,
            onend: EventHandler = undefined,
            _internal: ?*SpeechRecognitionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_continuous = &get_continuous,
        .get_grammars = &get_grammars,
        .get_interimResults = &get_interimResults,
        .get_lang = &get_lang,
        .get_maxAlternatives = &get_maxAlternatives,
        .get_onaudioend = &get_onaudioend,
        .get_onaudiostart = &get_onaudiostart,
        .get_onend = &get_onend,
        .get_onerror = &get_onerror,
        .get_onnomatch = &get_onnomatch,
        .get_onresult = &get_onresult,
        .get_onsoundend = &get_onsoundend,
        .get_onsoundstart = &get_onsoundstart,
        .get_onspeechend = &get_onspeechend,
        .get_onspeechstart = &get_onspeechstart,
        .get_onstart = &get_onstart,
        .get_phrases = &get_phrases,
        .get_processLocally = &get_processLocally,

        .set_continuous = &set_continuous,
        .set_grammars = &set_grammars,
        .set_interimResults = &set_interimResults,
        .set_lang = &set_lang,
        .set_maxAlternatives = &set_maxAlternatives,
        .set_onaudioend = &set_onaudioend,
        .set_onaudiostart = &set_onaudiostart,
        .set_onend = &set_onend,
        .set_onerror = &set_onerror,
        .set_onnomatch = &set_onnomatch,
        .set_onresult = &set_onresult,
        .set_onsoundend = &set_onsoundend,
        .set_onsoundstart = &set_onsoundstart,
        .set_onspeechend = &set_onspeechend,
        .set_onspeechstart = &set_onspeechstart,
        .set_onstart = &set_onstart,
        .set_phrases = &set_phrases,
        .set_processLocally = &set_processLocally,

        .call_abort = &call_abort,
        .call_available = &call_available,
        .call_install = &call_install,
        .call_start = &call_start,
        .call_stop = &call_stop,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechRecognitionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try SpeechRecognitionImpl.call_constructor(allocator, ctx);
    }

    pub fn get_grammars(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try SpeechRecognitionImpl.get_grammars(instance);
    }

    pub fn set_grammars(instance: *runtime.Instance, value: *runtime.Instance) anyerror!void {
        try SpeechRecognitionImpl.set_grammars(instance, value);
    }

    pub fn get_lang(instance: *runtime.Instance) anyerror!DOMString {
        return try SpeechRecognitionImpl.get_lang(instance);
    }

    pub fn set_lang(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try SpeechRecognitionImpl.set_lang(instance, value);
    }

    pub fn get_continuous(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_continuous(instance);
    }

    pub fn set_continuous(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_continuous(instance, value);
    }

    pub fn get_interimResults(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_interimResults(instance);
    }

    pub fn set_interimResults(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_interimResults(instance, value);
    }

    pub fn get_maxAlternatives(instance: *runtime.Instance) anyerror!u32 {
        return try SpeechRecognitionImpl.get_maxAlternatives(instance);
    }

    pub fn set_maxAlternatives(instance: *runtime.Instance, value: u32) anyerror!void {
        try SpeechRecognitionImpl.set_maxAlternatives(instance, value);
    }

    pub fn get_processLocally(instance: *runtime.Instance) anyerror!bool {
        return try SpeechRecognitionImpl.get_processLocally(instance);
    }

    pub fn set_processLocally(instance: *runtime.Instance, value: bool) anyerror!void {
        try SpeechRecognitionImpl.set_processLocally(instance, value);
    }

    pub fn get_phrases(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SpeechRecognitionImpl.get_phrases(instance);
    }

    pub fn set_phrases(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try SpeechRecognitionImpl.set_phrases(instance, value);
    }

    pub fn get_onaudiostart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onaudiostart(instance);
    }

    pub fn set_onaudiostart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onaudiostart(instance, value);
    }

    pub fn get_onsoundstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onsoundstart(instance);
    }

    pub fn set_onsoundstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onsoundstart(instance, value);
    }

    pub fn get_onspeechstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onspeechstart(instance);
    }

    pub fn set_onspeechstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onspeechstart(instance, value);
    }

    pub fn get_onspeechend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onspeechend(instance);
    }

    pub fn set_onspeechend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onspeechend(instance, value);
    }

    pub fn get_onsoundend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onsoundend(instance);
    }

    pub fn set_onsoundend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onsoundend(instance, value);
    }

    pub fn get_onaudioend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onaudioend(instance);
    }

    pub fn set_onaudioend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onaudioend(instance, value);
    }

    pub fn get_onresult(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onresult(instance);
    }

    pub fn set_onresult(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onresult(instance, value);
    }

    pub fn get_onnomatch(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onnomatch(instance);
    }

    pub fn set_onnomatch(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onnomatch(instance, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onerror(instance);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onerror(instance, value);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onstart(instance);
    }

    pub fn set_onstart(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onstart(instance, value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechRecognitionImpl.get_onend(instance);
    }

    pub fn set_onend(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechRecognitionImpl.set_onend(instance, value);
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_stop(instance);
    }

    pub fn call_available(instance: *runtime.Instance, options: SpeechRecognitionOptions) anyerror!*const anyopaque {
        
        return try SpeechRecognitionImpl.call_available(instance, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_abort(instance);
    }

    pub fn call_start(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_start(instance);
    }

    pub fn call_install(instance: *runtime.Instance, options: SpeechRecognitionOptions) anyerror!*const anyopaque {
        
        return try SpeechRecognitionImpl.call_install(instance, options);
    }

};

//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionImpl = @import("impls").SpeechRecognition;
const EventTarget = @import("interfaces").EventTarget;
const SpeechRecognitionOptions = @import("dictionaries").SpeechRecognitionOptions;
const Promise<boolean> = @import("interfaces").Promise<boolean>;
const Promise<AvailabilityStatus> = @import("interfaces").Promise<AvailabilityStatus>;
const ObservableArray<SpeechRecognitionPhrase> = @import("interfaces").ObservableArray<SpeechRecognitionPhrase>;
const SpeechGrammarList = @import("interfaces").SpeechGrammarList;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const EventHandler = @import("typedefs").EventHandler;

pub const SpeechRecognition = struct {
    pub const Meta = struct {
        pub const name = "SpeechRecognition";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            grammars: SpeechGrammarList = undefined,
            lang: runtime.DOMString = undefined,
            continuous: bool = undefined,
            interimResults: bool = undefined,
            maxAlternatives: u32 = undefined,
            processLocally: bool = undefined,
            phrases: ObservableArray<SpeechRecognitionPhrase> = undefined,
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
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechRecognition, .{
        .deinit_fn = &deinit_wrapper,

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
        .call_addEventListener = &call_addEventListener,
        .call_available = &call_available,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_install = &call_install,
        .call_removeEventListener = &call_removeEventListener,
        .call_start = &call_start,
        .call_stop = &call_stop,
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
        SpeechRecognitionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechRecognitionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try SpeechRecognitionImpl.constructor(instance);
        
        return instance;
    }

    pub fn get_grammars(instance: *runtime.Instance) anyerror!SpeechGrammarList {
        return try SpeechRecognitionImpl.get_grammars(instance);
    }

    pub fn set_grammars(instance: *runtime.Instance, value: SpeechGrammarList) anyerror!void {
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

    pub fn get_phrases(instance: *runtime.Instance) anyerror!anyopaque {
        return try SpeechRecognitionImpl.get_phrases(instance);
    }

    pub fn set_phrases(instance: *runtime.Instance, value: anyopaque) anyerror!void {
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

    pub fn call_available(instance: *runtime.Instance, options: SpeechRecognitionOptions) anyerror!anyopaque {
        
        return try SpeechRecognitionImpl.call_available(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SpeechRecognitionImpl.call_when(instance, type_, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyerror!void {
        return try SpeechRecognitionImpl.call_abort(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SpeechRecognitionImpl.call_dispatchEvent(instance, event);
    }

    /// Arguments for start (WebIDL overloading)
    pub const StartArgs = union(enum) {
        /// start()
        no_params: void,
        /// start(audioTrack)
        MediaStreamTrack: MediaStreamTrack,
    };

    pub fn call_start(instance: *runtime.Instance, args: StartArgs) anyerror!void {
        switch (args) {
            .no_params => return try SpeechRecognitionImpl.no_params(instance),
            .MediaStreamTrack => |arg| return try SpeechRecognitionImpl.MediaStreamTrack(instance, arg),
        }
    }

    pub fn call_install(instance: *runtime.Instance, options: SpeechRecognitionOptions) anyerror!anyopaque {
        
        return try SpeechRecognitionImpl.call_install(instance, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SpeechRecognitionImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SpeechRecognitionImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

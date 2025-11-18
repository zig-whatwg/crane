//! Generated from: speech-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechRecognitionImpl = @import("../impls/SpeechRecognition.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        SpeechRecognitionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try SpeechRecognitionImpl.constructor(state);
        
        return instance;
    }

    pub fn get_grammars(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_grammars(state);
    }

    pub fn set_grammars(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_grammars(state, value);
    }

    pub fn get_lang(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_lang(state);
    }

    pub fn set_lang(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_lang(state, value);
    }

    pub fn get_continuous(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_continuous(state);
    }

    pub fn set_continuous(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_continuous(state, value);
    }

    pub fn get_interimResults(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_interimResults(state);
    }

    pub fn set_interimResults(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_interimResults(state, value);
    }

    pub fn get_maxAlternatives(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_maxAlternatives(state);
    }

    pub fn set_maxAlternatives(instance: *runtime.Instance, value: u32) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_maxAlternatives(state, value);
    }

    pub fn get_processLocally(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_processLocally(state);
    }

    pub fn set_processLocally(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_processLocally(state, value);
    }

    pub fn get_phrases(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_phrases(state);
    }

    pub fn set_phrases(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_phrases(state, value);
    }

    pub fn get_onaudiostart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onaudiostart(state);
    }

    pub fn set_onaudiostart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onaudiostart(state, value);
    }

    pub fn get_onsoundstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onsoundstart(state);
    }

    pub fn set_onsoundstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onsoundstart(state, value);
    }

    pub fn get_onspeechstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onspeechstart(state);
    }

    pub fn set_onspeechstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onspeechstart(state, value);
    }

    pub fn get_onspeechend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onspeechend(state);
    }

    pub fn set_onspeechend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onspeechend(state, value);
    }

    pub fn get_onsoundend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onsoundend(state);
    }

    pub fn set_onsoundend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onsoundend(state, value);
    }

    pub fn get_onaudioend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onaudioend(state);
    }

    pub fn set_onaudioend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onaudioend(state, value);
    }

    pub fn get_onresult(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onresult(state);
    }

    pub fn set_onresult(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onresult(state, value);
    }

    pub fn get_onnomatch(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onnomatch(state);
    }

    pub fn set_onnomatch(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onnomatch(state, value);
    }

    pub fn get_onerror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onerror(state);
    }

    pub fn set_onerror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onerror(state, value);
    }

    pub fn get_onstart(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onstart(state);
    }

    pub fn set_onstart(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onstart(state, value);
    }

    pub fn get_onend(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.get_onend(state);
    }

    pub fn set_onend(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechRecognitionImpl.set_onend(state, value);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.call_stop(state);
    }

    pub fn call_available(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechRecognitionImpl.call_available(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechRecognitionImpl.call_when(state, type_, options);
    }

    pub fn call_abort(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechRecognitionImpl.call_abort(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SpeechRecognitionImpl.call_dispatchEvent(state, event);
    }

    /// Arguments for start (WebIDL overloading)
    pub const StartArgs = union(enum) {
        /// start()
        no_params: void,
        /// start(audioTrack)
        MediaStreamTrack: anyopaque,
    };

    pub fn call_start(instance: *runtime.Instance, args: StartArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return SpeechRecognitionImpl.no_params(state),
            .MediaStreamTrack => |arg| return SpeechRecognitionImpl.MediaStreamTrack(state, arg),
        }
    }

    pub fn call_install(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechRecognitionImpl.call_install(state, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechRecognitionImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechRecognitionImpl.call_removeEventListener(state, type_, callback, options);
    }

};

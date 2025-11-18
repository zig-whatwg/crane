//! Generated from: speech-api.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisImpl = @import("impls").SpeechSynthesis;
const EventTarget = @import("interfaces").EventTarget;
const EventHandler = @import("typedefs").EventHandler;
const SpeechSynthesisUtterance = @import("interfaces").SpeechSynthesisUtterance;

pub const SpeechSynthesis = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesis";
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
            pending: bool = undefined,
            speaking: bool = undefined,
            paused: bool = undefined,
            onvoiceschanged: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SpeechSynthesis, .{
        .deinit_fn = &deinit_wrapper,

        .get_onvoiceschanged = &get_onvoiceschanged,
        .get_paused = &get_paused,
        .get_pending = &get_pending,
        .get_speaking = &get_speaking,

        .set_onvoiceschanged = &set_onvoiceschanged,

        .call_addEventListener = &call_addEventListener,
        .call_cancel = &call_cancel,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getVoices = &call_getVoices,
        .call_pause = &call_pause,
        .call_removeEventListener = &call_removeEventListener,
        .call_resume = &call_resume,
        .call_speak = &call_speak,
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
        SpeechSynthesisImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_pending(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisImpl.get_pending(instance);
    }

    pub fn get_speaking(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisImpl.get_speaking(instance);
    }

    pub fn get_paused(instance: *runtime.Instance) anyerror!bool {
        return try SpeechSynthesisImpl.get_paused(instance);
    }

    pub fn get_onvoiceschanged(instance: *runtime.Instance) anyerror!EventHandler {
        return try SpeechSynthesisImpl.get_onvoiceschanged(instance);
    }

    pub fn set_onvoiceschanged(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try SpeechSynthesisImpl.set_onvoiceschanged(instance, value);
    }

    pub fn call_resume(instance: *runtime.Instance) anyerror!void {
        return try SpeechSynthesisImpl.call_resume(instance);
    }

    pub fn call_getVoices(instance: *runtime.Instance) anyerror!anyopaque {
        return try SpeechSynthesisImpl.call_getVoices(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try SpeechSynthesisImpl.call_when(instance, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try SpeechSynthesisImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_speak(instance: *runtime.Instance, utterance: SpeechSynthesisUtterance) anyerror!void {
        
        return try SpeechSynthesisImpl.call_speak(instance, utterance);
    }

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try SpeechSynthesisImpl.call_pause(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
        return try SpeechSynthesisImpl.call_cancel(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SpeechSynthesisImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try SpeechSynthesisImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

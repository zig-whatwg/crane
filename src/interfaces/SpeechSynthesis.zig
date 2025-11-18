//! Generated from: speech-api.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SpeechSynthesisImpl = @import("../impls/SpeechSynthesis.zig");
const EventTarget = @import("EventTarget.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        SpeechSynthesisImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SpeechSynthesisImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_pending(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.get_pending(state);
    }

    pub fn get_speaking(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.get_speaking(state);
    }

    pub fn get_paused(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.get_paused(state);
    }

    pub fn get_onvoiceschanged(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.get_onvoiceschanged(state);
    }

    pub fn set_onvoiceschanged(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        SpeechSynthesisImpl.set_onvoiceschanged(state, value);
    }

    pub fn call_resume(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.call_resume(state);
    }

    pub fn call_getVoices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.call_getVoices(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisImpl.call_when(state, type_, options);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return SpeechSynthesisImpl.call_dispatchEvent(state, event);
    }

    pub fn call_speak(instance: *runtime.Instance, utterance: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisImpl.call_speak(state, utterance);
    }

    pub fn call_pause(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.call_pause(state);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SpeechSynthesisImpl.call_cancel(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SpeechSynthesisImpl.call_removeEventListener(state, type_, callback, options);
    }

};

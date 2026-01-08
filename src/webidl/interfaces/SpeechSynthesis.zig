//! Generated from: speech-api.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SpeechSynthesisImpl = @import("impls").SpeechSynthesis;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("Event.zig").Event;
const SpeechSynthesisVoice = @import("SpeechSynthesisVoice.zig").SpeechSynthesisVoice;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const SpeechSynthesisUtterance = @import("SpeechSynthesisUtterance.zig").SpeechSynthesisUtterance;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("Observable.zig").Observable;

pub const SpeechSynthesis = struct {
    pub const Meta = struct {
        pub const name = "SpeechSynthesis";
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
            .{ "pending", "get_pending", null },
            .{ "speaking", "get_speaking", null },
            .{ "paused", "get_paused", null },
            .{ "onvoiceschanged", "get_onvoiceschanged", "set_onvoiceschanged" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "speak", "call_speak", 1 },
            .{ "cancel", "call_cancel", 0 },
            .{ "pause", "call_pause", 0 },
            .{ "resume", "call_resume", 0 },
            .{ "getVoices", "call_getVoices", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "speak",
            "cancel",
            "pause",
            "resume",
            "getVoices",
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
            .{ "pending", "get_pending", null },
            .{ "speaking", "get_speaking", null },
            .{ "paused", "get_paused", null },
            .{ "onvoiceschanged", "get_onvoiceschanged", "set_onvoiceschanged" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            pending: bool = undefined,
            speaking: bool = undefined,
            paused: bool = undefined,
            onvoiceschanged: typedefs.EventHandler = undefined,
            _internal: ?*SpeechSynthesisImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onvoiceschanged = &get_onvoiceschanged,
        .get_paused = &get_paused,
        .get_pending = &get_pending,
        .get_speaking = &get_speaking,

        .set_onvoiceschanged = &set_onvoiceschanged,

        .call_cancel = &call_cancel,
        .call_getVoices = &call_getVoices,
        .call_pause = &call_pause,
        .call_resume = &call_resume,
        .call_speak = &call_speak,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SpeechSynthesisImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return SpeechSynthesisImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SpeechSynthesisImpl.deinit(instance);
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

    pub fn call_pause(instance: *runtime.Instance) anyerror!void {
        return try SpeechSynthesisImpl.call_pause(instance);
    }

    pub fn call_speak(instance: *runtime.Instance, utterance: *runtime.Instance) anyerror!void {
        
        return try SpeechSynthesisImpl.call_speak(instance, utterance);
    }

    pub fn call_getVoices(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try SpeechSynthesisImpl.call_getVoices(instance);
    }

    pub fn call_cancel(instance: *runtime.Instance) anyerror!void {
        return try SpeechSynthesisImpl.call_cancel(instance);
    }

};

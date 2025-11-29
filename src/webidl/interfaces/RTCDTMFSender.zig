//! Generated from: webrtc.idl
//! Generated at: 2025-11-29T05:01:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCDTMFSenderImpl = @import("impls").RTCDTMFSender;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const EventHandler = @import("typedefs").EventHandler;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const Observable = @import("interfaces").Observable;

pub const RTCDTMFSender = struct {
    pub const Meta = struct {
        pub const name = "RTCDTMFSender";
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
            .{ "ontonechange", "get_ontonechange", "set_ontonechange" },
            .{ "canInsertDTMF", "get_canInsertDTMF", null },
            .{ "toneBuffer", "get_toneBuffer", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "insertDTMF", "call_insertDTMF", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "insertDTMF",
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
            .{ "ontonechange", "get_ontonechange", "set_ontonechange" },
            .{ "canInsertDTMF", "get_canInsertDTMF", null },
            .{ "toneBuffer", "get_toneBuffer", null },
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
            ontonechange: EventHandler = undefined,
            canInsertDTMF: bool = undefined,
            toneBuffer: runtime.DOMString = undefined,
            _internal: ?*RTCDTMFSenderImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_canInsertDTMF = &get_canInsertDTMF,
        .get_ontonechange = &get_ontonechange,
        .get_toneBuffer = &get_toneBuffer,

        .set_ontonechange = &set_ontonechange,

        .call_insertDTMF = &call_insertDTMF,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCDTMFSenderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCDTMFSenderImpl.deinit(instance);
    }

    pub fn get_ontonechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try RTCDTMFSenderImpl.get_ontonechange(instance);
    }

    pub fn set_ontonechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try RTCDTMFSenderImpl.set_ontonechange(instance, value);
    }

    pub fn get_canInsertDTMF(instance: *runtime.Instance) anyerror!bool {
        return try RTCDTMFSenderImpl.get_canInsertDTMF(instance);
    }

    pub fn get_toneBuffer(instance: *runtime.Instance) anyerror!DOMString {
        return try RTCDTMFSenderImpl.get_toneBuffer(instance);
    }

    pub fn call_insertDTMF(instance: *runtime.Instance, tones: DOMString, duration: webidl.Opt(u32), interToneGap: webidl.Opt(u32)) anyerror!void {
        
        return try RTCDTMFSenderImpl.call_insertDTMF(instance, tones, duration, interToneGap);
    }

};

//! Generated from: html.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const AudioTrackListImpl = @import("impls").AudioTrackList;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const AudioTrack = @import("interfaces").AudioTrack;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const AudioTrackList = struct {
    pub const Meta = struct {
        pub const name = "AudioTrackList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "length", "get_length", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getTrackById", "call_getTrackById", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getTrackById",
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
            .{ "length", "get_length", null },
            .{ "onchange", "get_onchange", "set_onchange" },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
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
            length: u32 = undefined,
            onchange: EventHandler = undefined,
            onaddtrack: EventHandler = undefined,
            onremovetrack: EventHandler = undefined,
            _internal: ?*AudioTrackListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_onaddtrack = &get_onaddtrack,
        .get_onchange = &get_onchange,
        .get_onremovetrack = &get_onremovetrack,

        .set_onaddtrack = &set_onaddtrack,
        .set_onchange = &set_onchange,
        .set_onremovetrack = &set_onremovetrack,

        .call_getTrackById = &call_getTrackById,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioTrackListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioTrackListImpl.deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try AudioTrackListImpl.get_length(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioTrackListImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioTrackListImpl.set_onchange(instance, value);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioTrackListImpl.get_onaddtrack(instance);
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioTrackListImpl.set_onaddtrack(instance, value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try AudioTrackListImpl.get_onremovetrack(instance);
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try AudioTrackListImpl.set_onremovetrack(instance, value);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, id: DOMString) anyerror!?*runtime.Instance {
        
        return try AudioTrackListImpl.call_getTrackById(instance, id);
    }

};

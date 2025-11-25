//! Generated from: html.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextTrackCueImpl = @import("impls").TextTrackCue;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const TextTrack = @import("interfaces").TextTrack;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const TextTrackCue = struct {
    pub const Meta = struct {
        pub const name = "TextTrackCue";
        pub const is_mixin = false;
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
            .{ "track", "get_track", null },
            .{ "id", "get_id", "set_id" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "endTime", "get_endTime", "set_endTime" },
            .{ "pauseOnExit", "get_pauseOnExit", "set_pauseOnExit" },
            .{ "onenter", "get_onenter", "set_onenter" },
            .{ "onexit", "get_onexit", "set_onexit" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "track", "get_track", null },
            .{ "id", "get_id", "set_id" },
            .{ "startTime", "get_startTime", "set_startTime" },
            .{ "endTime", "get_endTime", "set_endTime" },
            .{ "pauseOnExit", "get_pauseOnExit", "set_pauseOnExit" },
            .{ "onenter", "get_onenter", "set_onenter" },
            .{ "onexit", "get_onexit", "set_onexit" },
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
            track: ?*runtime.Instance = null,
            id: runtime.DOMString = undefined,
            startTime: f64 = undefined,
            endTime: f64 = undefined,
            pauseOnExit: bool = undefined,
            onenter: EventHandler = undefined,
            onexit: EventHandler = undefined,
            _internal: ?*TextTrackCueImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_endTime = &get_endTime,
        .get_id = &get_id,
        .get_onenter = &get_onenter,
        .get_onexit = &get_onexit,
        .get_pauseOnExit = &get_pauseOnExit,
        .get_startTime = &get_startTime,
        .get_track = &get_track,

        .set_endTime = &set_endTime,
        .set_id = &set_id,
        .set_onenter = &set_onenter,
        .set_onexit = &set_onexit,
        .set_pauseOnExit = &set_pauseOnExit,
        .set_startTime = &set_startTime,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextTrackCueImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextTrackCueImpl.deinit(instance);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackCueImpl.get_track(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try TextTrackCueImpl.get_id(instance);
    }

    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try TextTrackCueImpl.set_id(instance, value);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try TextTrackCueImpl.get_startTime(instance);
    }

    pub fn set_startTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try TextTrackCueImpl.set_startTime(instance, value);
    }

    pub fn get_endTime(instance: *runtime.Instance) anyerror!f64 {
        return try TextTrackCueImpl.get_endTime(instance);
    }

    pub fn set_endTime(instance: *runtime.Instance, value: f64) anyerror!void {
        try TextTrackCueImpl.set_endTime(instance, value);
    }

    pub fn get_pauseOnExit(instance: *runtime.Instance) anyerror!bool {
        return try TextTrackCueImpl.get_pauseOnExit(instance);
    }

    pub fn set_pauseOnExit(instance: *runtime.Instance, value: bool) anyerror!void {
        try TextTrackCueImpl.set_pauseOnExit(instance, value);
    }

    pub fn get_onenter(instance: *runtime.Instance) anyerror!EventHandler {
        return try TextTrackCueImpl.get_onenter(instance);
    }

    pub fn set_onenter(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TextTrackCueImpl.set_onenter(instance, value);
    }

    pub fn get_onexit(instance: *runtime.Instance) anyerror!EventHandler {
        return try TextTrackCueImpl.get_onexit(instance);
    }

    pub fn set_onexit(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TextTrackCueImpl.set_onexit(instance, value);
    }

};

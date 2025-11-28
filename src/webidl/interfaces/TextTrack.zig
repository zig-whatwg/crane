//! Generated from: html.idl
//! Generated at: 2025-11-28T22:33:22Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextTrackImpl = @import("impls").TextTrack;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const TextTrackKind = @import("enums").TextTrackKind;
const Observable = @import("interfaces").Observable;
const TextTrackMode = @import("enums").TextTrackMode;
const Event = @import("interfaces").Event;
const TextTrackCueList = @import("interfaces").TextTrackCueList;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const SourceBuffer = @import("interfaces").SourceBuffer;
const EventListener = @import("interfaces").EventListener;
const TextTrackCue = @import("interfaces").TextTrackCue;
const EventHandler = @import("typedefs").EventHandler;

pub const TextTrack = struct {
    pub const Meta = struct {
        pub const name = "TextTrack";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "id", "get_id", null },
            .{ "inBandMetadataTrackDispatchType", "get_inBandMetadataTrackDispatchType", null },
            .{ "mode", "get_mode", "set_mode" },
            .{ "cues", "get_cues", null },
            .{ "activeCues", "get_activeCues", null },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "addCue", "call_addCue", 1 },
            .{ "removeCue", "call_removeCue", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "addCue",
            "removeCue",
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
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "id", "get_id", null },
            .{ "inBandMetadataTrackDispatchType", "get_inBandMetadataTrackDispatchType", null },
            .{ "mode", "get_mode", "set_mode" },
            .{ "cues", "get_cues", null },
            .{ "activeCues", "get_activeCues", null },
            .{ "oncuechange", "get_oncuechange", "set_oncuechange" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
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
            kind: TextTrackKind = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            inBandMetadataTrackDispatchType: runtime.DOMString = undefined,
            mode: TextTrackMode = undefined,
            cues: ?*runtime.Instance = null,
            activeCues: ?*runtime.Instance = null,
            oncuechange: EventHandler = undefined,
            sourceBuffer: ?*runtime.Instance = null,
            _internal: ?*TextTrackImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activeCues = &get_activeCues,
        .get_cues = &get_cues,
        .get_id = &get_id,
        .get_inBandMetadataTrackDispatchType = &get_inBandMetadataTrackDispatchType,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_mode = &get_mode,
        .get_oncuechange = &get_oncuechange,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_mode = &set_mode,
        .set_oncuechange = &set_oncuechange,

        .call_addCue = &call_addCue,
        .call_removeCue = &call_removeCue,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextTrackImpl.deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!TextTrackKind {
        return try TextTrackImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try TextTrackImpl.get_label(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try TextTrackImpl.get_language(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try TextTrackImpl.get_id(instance);
    }

    pub fn get_inBandMetadataTrackDispatchType(instance: *runtime.Instance) anyerror!DOMString {
        return try TextTrackImpl.get_inBandMetadataTrackDispatchType(instance);
    }

    pub fn get_mode(instance: *runtime.Instance) anyerror!TextTrackMode {
        return try TextTrackImpl.get_mode(instance);
    }

    pub fn set_mode(instance: *runtime.Instance, value: TextTrackMode) anyerror!void {
        try TextTrackImpl.set_mode(instance, value);
    }

    pub fn get_cues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackImpl.get_cues(instance);
    }

    pub fn get_activeCues(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackImpl.get_activeCues(instance);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try TextTrackImpl.get_oncuechange(instance);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TextTrackImpl.set_oncuechange(instance, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextTrackImpl.get_sourceBuffer(instance);
    }

    pub fn call_addCue(instance: *runtime.Instance, cue: *runtime.Instance) anyerror!void {
        
        return try TextTrackImpl.call_addCue(instance, cue);
    }

    pub fn call_removeCue(instance: *runtime.Instance, cue: *runtime.Instance) anyerror!void {
        
        return try TextTrackImpl.call_removeCue(instance, cue);
    }

};

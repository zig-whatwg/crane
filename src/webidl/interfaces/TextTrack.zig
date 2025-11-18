//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextTrackImpl = @import("impls").TextTrack;
const EventTarget = @import("interfaces").EventTarget;
const TextTrackMode = @import("enums").TextTrackMode;
const TextTrackCueList = @import("interfaces").TextTrackCueList;
const TextTrackKind = @import("enums").TextTrackKind;
const SourceBuffer = @import("interfaces").SourceBuffer;
const TextTrackCue = @import("interfaces").TextTrackCue;
const EventHandler = @import("typedefs").EventHandler;

pub const TextTrack = struct {
    pub const Meta = struct {
        pub const name = "TextTrack";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            kind: TextTrackKind = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            inBandMetadataTrackDispatchType: runtime.DOMString = undefined,
            mode: TextTrackMode = undefined,
            cues: ?TextTrackCueList = null,
            activeCues: ?TextTrackCueList = null,
            oncuechange: EventHandler = undefined,
            sourceBuffer: ?SourceBuffer = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(TextTrack, .{
        .deinit_fn = &deinit_wrapper,

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
        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_removeCue = &call_removeCue,
        .call_removeEventListener = &call_removeEventListener,
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
        TextTrackImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextTrackImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
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

    pub fn get_cues(instance: *runtime.Instance) anyerror!anyopaque {
        return try TextTrackImpl.get_cues(instance);
    }

    pub fn get_activeCues(instance: *runtime.Instance) anyerror!anyopaque {
        return try TextTrackImpl.get_activeCues(instance);
    }

    pub fn get_oncuechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try TextTrackImpl.get_oncuechange(instance);
    }

    pub fn set_oncuechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try TextTrackImpl.set_oncuechange(instance, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!anyopaque {
        return try TextTrackImpl.get_sourceBuffer(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try TextTrackImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try TextTrackImpl.call_when(instance, type_, options);
    }

    pub fn call_addCue(instance: *runtime.Instance, cue: TextTrackCue) anyerror!void {
        
        return try TextTrackImpl.call_addCue(instance, cue);
    }

    pub fn call_removeCue(instance: *runtime.Instance, cue: TextTrackCue) anyerror!void {
        
        return try TextTrackImpl.call_removeCue(instance, cue);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try TextTrackImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try TextTrackImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

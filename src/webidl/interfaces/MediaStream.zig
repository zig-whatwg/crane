//! Generated from: mediacapture-streams.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaStreamImpl = @import("impls").MediaStream;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const Observable = @import("interfaces").Observable;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const MediaStream = struct {
    pub const Meta = struct {
        pub const name = "MediaStream";
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
            .{ "id", "get_id", null },
            .{ "active", "get_active", null },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getAudioTracks", "call_getAudioTracks", 0 },
            .{ "getVideoTracks", "call_getVideoTracks", 0 },
            .{ "getTracks", "call_getTracks", 0 },
            .{ "getTrackById", "call_getTrackById", 1 },
            .{ "addTrack", "call_addTrack", 1 },
            .{ "removeTrack", "call_removeTrack", 1 },
            .{ "clone", "call_clone", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getAudioTracks",
            "getVideoTracks",
            "getTracks",
            "getTrackById",
            "addTrack",
            "removeTrack",
            "clone",
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
            .{ "id", "get_id", null },
            .{ "active", "get_active", null },
            .{ "onaddtrack", "get_onaddtrack", "set_onaddtrack" },
            .{ "onremovetrack", "get_onremovetrack", "set_onremovetrack" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            id: typedefs.DOMString = undefined,
            active: bool = undefined,
            onaddtrack: typedefs.EventHandler = undefined,
            onremovetrack: typedefs.EventHandler = undefined,
            _internal: ?*MediaStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_active = &get_active,
        .get_id = &get_id,
        .get_onaddtrack = &get_onaddtrack,
        .get_onremovetrack = &get_onremovetrack,

        .set_onaddtrack = &set_onaddtrack,
        .set_onremovetrack = &set_onremovetrack,

        .call_addTrack = &call_addTrack,
        .call_clone = &call_clone,
        .call_getAudioTracks = &call_getAudioTracks,
        .call_getTrackById = &call_getTrackById,
        .call_getTracks = &call_getTracks,
        .call_getVideoTracks = &call_getVideoTracks,
        .call_removeTrack = &call_removeTrack,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaStreamImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaStreamImpl.deinit(instance);
    }

    /// Arguments for constructor (WebIDL overloading)
    pub const ConstructorArgs = union(enum) {
        /// constructor()
        no_params: void,
        /// constructor(stream)
        MediaStream: MediaStream,
    };

    /// WebIDL constructor (overloaded)
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, args: ConstructorArgs) !*runtime.Instance {
        // Pass args union directly to impl
        return try MediaStreamImpl.call_constructor(ctx, args);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try MediaStreamImpl.get_id(instance);
    }

    pub fn get_active(instance: *runtime.Instance) anyerror!bool {
        return try MediaStreamImpl.get_active(instance);
    }

    pub fn get_onaddtrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaStreamImpl.get_onaddtrack(instance);
    }

    pub fn set_onaddtrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaStreamImpl.set_onaddtrack(instance, value);
    }

    pub fn get_onremovetrack(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaStreamImpl.get_onremovetrack(instance);
    }

    pub fn set_onremovetrack(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaStreamImpl.set_onremovetrack(instance, value);
    }

    pub fn call_getTracks(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamImpl.call_getTracks(instance);
    }

    pub fn call_getVideoTracks(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamImpl.call_getVideoTracks(instance);
    }

    pub fn call_addTrack(instance: *runtime.Instance, track: *runtime.Instance) anyerror!void {
        
        return try MediaStreamImpl.call_addTrack(instance, track);
    }

    pub fn call_removeTrack(instance: *runtime.Instance, track: *runtime.Instance) anyerror!void {
        
        return try MediaStreamImpl.call_removeTrack(instance, track);
    }

    pub fn call_getTrackById(instance: *runtime.Instance, trackId: DOMString) anyerror!?*runtime.Instance {
        
        return try MediaStreamImpl.call_getTrackById(instance, trackId);
    }

    pub fn call_getAudioTracks(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try MediaStreamImpl.call_getAudioTracks(instance);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try MediaStreamImpl.call_clone(instance);
    }

};

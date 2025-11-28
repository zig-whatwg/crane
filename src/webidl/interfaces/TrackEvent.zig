//! Generated from: html.idl
//! Generated at: 2025-11-28T18:57:55Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TrackEventImpl = @import("impls").TrackEvent;
const mixins = @import("mixins");
const Event = @import("interfaces").Event;
const TrackEventInit = @import("dictionaries").TrackEventInit;
const EventTarget = @import("interfaces").EventTarget;
const TextTrack = @import("interfaces").TextTrack;
const VideoTrack = @import("interfaces").VideoTrack;
const AudioTrack = @import("interfaces").AudioTrack;
const DOMHighResTimeStamp = @import("typedefs").DOMHighResTimeStamp;
const EventInit = @import("dictionaries").EventInit;
const DOMString = @import("typedefs").DOMString;

pub const TrackEvent = struct {
    pub const Meta = struct {
        pub const name = "TrackEvent";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Event;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "track", "get_track", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "composedPath",
            "stopPropagation",
            "stopImmediatePropagation",
            "preventDefault",
            "initEvent",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "track", "get_track", null },
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
            track: ?union(enum) {
                VideoTrack: VideoTrack,
                AudioTrack: AudioTrack,
                TextTrack: TextTrack,
            } = null,
            _internal: ?*TrackEventImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_track = &get_track,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TrackEventImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TrackEventImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": DOMString, eventInitDict: webidl.Opt(TrackEventInit)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TrackEventImpl.call_constructor(allocator, ctx, @"type", eventInitDict);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try TrackEventImpl.get_track(instance);
    }

};

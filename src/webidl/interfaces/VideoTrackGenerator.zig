//! Generated from: mediacapture-transform.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VideoTrackGeneratorImpl = @import("impls").VideoTrackGenerator;
const mixins = @import("mixins");
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const WritableStream = @import("interfaces").WritableStream;

pub const VideoTrackGenerator = struct {
    pub const Meta = struct {
        pub const name = "VideoTrackGenerator";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "writable", "get_writable", null },
            .{ "muted", "get_muted", "set_muted" },
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "writable", "get_writable", null },
            .{ "muted", "get_muted", "set_muted" },
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
            writable: *runtime.Instance = undefined,
            muted: bool = undefined,
            track: *runtime.Instance = undefined,
            _internal: ?*VideoTrackGeneratorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_muted = &get_muted,
        .get_track = &get_track,
        .get_writable = &get_writable,

        .set_muted = &set_muted,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VideoTrackGeneratorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoTrackGeneratorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try VideoTrackGeneratorImpl.call_constructor(allocator, ctx);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoTrackGeneratorImpl.get_writable(instance);
    }

    pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
        return try VideoTrackGeneratorImpl.get_muted(instance);
    }

    pub fn set_muted(instance: *runtime.Instance, value: bool) anyerror!void {
        try VideoTrackGeneratorImpl.set_muted(instance, value);
    }

    pub fn get_track(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try VideoTrackGeneratorImpl.get_track(instance);
    }

};

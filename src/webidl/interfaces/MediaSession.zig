//! Generated from: mediasession.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MediaSessionImpl = @import("impls").MediaSession;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaSessionPlaybackState = @import("enums").MediaSessionPlaybackState;
const MediaPositionState = @import("dictionaries").MediaPositionState;
const MediaSessionActionHandler = @import("callbacks").MediaSessionActionHandler;
const MediaSessionAction = @import("enums").MediaSessionAction;
const MediaMetadata = @import("MediaMetadata.zig").MediaMetadata;

pub const MediaSession = struct {
    pub const Meta = struct {
        pub const name = "MediaSession";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "metadata", "get_metadata", "set_metadata" },
            .{ "playbackState", "get_playbackState", "set_playbackState" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "setActionHandler", "call_setActionHandler", 2 },
            .{ "setPositionState", "call_setPositionState", 0 },
            .{ "setMicrophoneActive", "call_setMicrophoneActive", 1 },
            .{ "setCameraActive", "call_setCameraActive", 1 },
            .{ "setScreenshareActive", "call_setScreenshareActive", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "setActionHandler",
            "setPositionState",
            "setMicrophoneActive",
            "setCameraActive",
            "setScreenshareActive",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "metadata", "get_metadata", "set_metadata" },
            .{ "playbackState", "get_playbackState", "set_playbackState" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            metadata: ?*runtime.Instance = null,
            playbackState: enums.MediaSessionPlaybackState = undefined,
            _internal: ?*MediaSessionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_metadata = &get_metadata,
        .get_playbackState = &get_playbackState,

        .set_metadata = &set_metadata,
        .set_playbackState = &set_playbackState,

        .call_setActionHandler = &call_setActionHandler,
        .call_setCameraActive = &call_setCameraActive,
        .call_setMicrophoneActive = &call_setMicrophoneActive,
        .call_setPositionState = &call_setPositionState,
        .call_setScreenshareActive = &call_setScreenshareActive,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaSessionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return MediaSessionImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaSessionImpl.deinit(instance);
    }

    pub fn get_metadata(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try MediaSessionImpl.get_metadata(instance);
    }

    pub fn set_metadata(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        try MediaSessionImpl.set_metadata(instance, value);
    }

    pub fn get_playbackState(instance: *runtime.Instance) anyerror!MediaSessionPlaybackState {
        return try MediaSessionImpl.get_playbackState(instance);
    }

    pub fn set_playbackState(instance: *runtime.Instance, value: MediaSessionPlaybackState) anyerror!void {
        try MediaSessionImpl.set_playbackState(instance, value);
    }

    pub fn call_setMicrophoneActive(instance: *runtime.Instance, active: bool) anyerror!runtime.JSValue {
        
        return try MediaSessionImpl.call_setMicrophoneActive(instance, active);
    }

    pub fn call_setCameraActive(instance: *runtime.Instance, active: bool) anyerror!runtime.JSValue {
        
        return try MediaSessionImpl.call_setCameraActive(instance, active);
    }

    pub fn call_setScreenshareActive(instance: *runtime.Instance, active: bool) anyerror!runtime.JSValue {
        
        return try MediaSessionImpl.call_setScreenshareActive(instance, active);
    }

    pub fn call_setActionHandler(instance: *runtime.Instance, action: MediaSessionAction, handler: ?MediaSessionActionHandler) anyerror!void {
        
        return try MediaSessionImpl.call_setActionHandler(instance, action, handler);
    }

    pub fn call_setPositionState(instance: *runtime.Instance, state: webidl.Opt(MediaPositionState)) anyerror!void {
        
        return try MediaSessionImpl.call_setPositionState(instance, state);
    }

};

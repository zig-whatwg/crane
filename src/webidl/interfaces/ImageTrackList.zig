//! Generated from: webcodecs.idl
//! Generated at: 2025-11-25T19:42:23Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrackListImpl = @import("impls").ImageTrackList;
const ImageTrack = @import("interfaces").ImageTrack;

pub const ImageTrackList = struct {
    pub const Meta = struct {
        pub const name = "ImageTrackList";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ready", "get_ready", null },
            .{ "length", "get_length", null },
            .{ "selectedIndex", "get_selectedIndex", null },
            .{ "selectedTrack", "get_selectedTrack", null },
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
            .{ "ready", "get_ready", null },
            .{ "length", "get_length", null },
            .{ "selectedIndex", "get_selectedIndex", null },
            .{ "selectedTrack", "get_selectedTrack", null },
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
            ready: runtime.Promise(void) = undefined,
            length: u32 = undefined,
            selectedIndex: i32 = undefined,
            selectedTrack: ?*runtime.Instance = null,
            _internal: ?*ImageTrackListImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_length = &get_length,
        .get_ready = &get_ready,
        .get_selectedIndex = &get_selectedIndex,
        .get_selectedTrack = &get_selectedTrack,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageTrackListImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageTrackListImpl.deinit(instance);
    }

    pub fn get_ready(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try ImageTrackListImpl.get_ready(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try ImageTrackListImpl.get_length(instance);
    }

    pub fn get_selectedIndex(instance: *runtime.Instance) anyerror!i32 {
        return try ImageTrackListImpl.get_selectedIndex(instance);
    }

    pub fn get_selectedTrack(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ImageTrackListImpl.get_selectedTrack(instance);
    }

};

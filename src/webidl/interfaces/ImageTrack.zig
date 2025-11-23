//! Generated from: webcodecs.idl
//! Generated at: 2025-11-23T01:22:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ImageTrackImpl = @import("impls").ImageTrack;

pub const ImageTrack = struct {
    pub const Meta = struct {
        pub const name = "ImageTrack";
        pub const is_mixin = false;
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
            .{ "animated", "get_animated", null },
            .{ "frameCount", "get_frameCount", null },
            .{ "repetitionCount", "get_repetitionCount", null },
            .{ "selected", "get_selected", "set_selected" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "animated", "get_animated", null },
            .{ "frameCount", "get_frameCount", null },
            .{ "repetitionCount", "get_repetitionCount", null },
            .{ "selected", "get_selected", "set_selected" },
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
            animated: bool = undefined,
            frameCount: u32 = undefined,
            repetitionCount: f32 = undefined,
            selected: bool = undefined,
        },
    );

    const delegates = .{

        .get_animated = &get_animated,
        .get_frameCount = &get_frameCount,
        .get_repetitionCount = &get_repetitionCount,
        .get_selected = &get_selected,

        .set_selected = &set_selected,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ImageTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ImageTrackImpl.deinit(instance);
    }

    pub fn get_animated(instance: *runtime.Instance) anyerror!bool {
        return try ImageTrackImpl.get_animated(instance);
    }

    pub fn get_frameCount(instance: *runtime.Instance) anyerror!u32 {
        return try ImageTrackImpl.get_frameCount(instance);
    }

    pub fn get_repetitionCount(instance: *runtime.Instance) anyerror!f32 {
        return try ImageTrackImpl.get_repetitionCount(instance);
    }

    pub fn get_selected(instance: *runtime.Instance) anyerror!bool {
        return try ImageTrackImpl.get_selected(instance);
    }

    pub fn set_selected(instance: *runtime.Instance, value: bool) anyerror!void {
        try ImageTrackImpl.set_selected(instance, value);
    }

};

//! Generated from: mediasession.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ChapterInformationImpl = @import("impls").ChapterInformation;
const DOMString = @import("typedefs").DOMString;
const MediaImage = @import("dictionaries").MediaImage;

pub const ChapterInformation = struct {
    pub const Meta = struct {
        pub const name = "ChapterInformation";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "title", "get_title", null },
            .{ "startTime", "get_startTime", null },
            .{ "artwork", "get_artwork", null },
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
            .{ "title", "get_title", null },
            .{ "startTime", "get_startTime", null },
            .{ "artwork", "get_artwork", null },
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
            title: runtime.DOMString = undefined,
            startTime: f64 = undefined,
            artwork: runtime.FrozenArray(MediaImage) = undefined,
            cached_artwork: ?runtime.FrozenArray(MediaImage) = null,
            _internal: ?*ChapterInformationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_artwork = &get_artwork,
        .get_startTime = &get_startTime,
        .get_title = &get_title,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ChapterInformationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ChapterInformationImpl.deinit(instance);
    }

    pub fn get_title(instance: *runtime.Instance) anyerror!DOMString {
        return try ChapterInformationImpl.get_title(instance);
    }

    pub fn get_startTime(instance: *runtime.Instance) anyerror!f64 {
        return try ChapterInformationImpl.get_startTime(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_artwork(instance: *runtime.Instance) anyerror!*const anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_artwork) |cached| {
            return cached;
        }
        const value = try ChapterInformationImpl.get_artwork(instance);
        state.own.cached_artwork = value;
        return value;
    }

};

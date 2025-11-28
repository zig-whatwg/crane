//! Generated from: html.idl
//! Generated at: 2025-11-28T19:11:20Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const VideoTrackImpl = @import("impls").VideoTrack;
const mixins = @import("mixins");
const SourceBuffer = @import("interfaces").SourceBuffer;
const DOMString = @import("typedefs").DOMString;

pub const VideoTrack = struct {
    pub const Meta = struct {
        pub const name = "VideoTrack";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
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
            .{ "id", "get_id", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "selected", "get_selected", "set_selected" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
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
            .{ "id", "get_id", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "selected", "get_selected", "set_selected" },
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
            id: runtime.DOMString = undefined,
            kind: runtime.DOMString = undefined,
            label: runtime.DOMString = undefined,
            language: runtime.DOMString = undefined,
            selected: bool = undefined,
            sourceBuffer: ?*runtime.Instance = null,
            _internal: ?*VideoTrackImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_id = &get_id,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_selected = &get_selected,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_selected = &set_selected,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return VideoTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        VideoTrackImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try VideoTrackImpl.get_id(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!DOMString {
        return try VideoTrackImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try VideoTrackImpl.get_label(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try VideoTrackImpl.get_language(instance);
    }

    pub fn get_selected(instance: *runtime.Instance) anyerror!bool {
        return try VideoTrackImpl.get_selected(instance);
    }

    pub fn set_selected(instance: *runtime.Instance, value: bool) anyerror!void {
        try VideoTrackImpl.set_selected(instance, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try VideoTrackImpl.get_sourceBuffer(instance);
    }

};

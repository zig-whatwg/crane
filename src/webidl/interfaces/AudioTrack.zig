//! Generated from: html.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioTrackImpl = @import("impls").AudioTrack;
const SourceBuffer = @import("interfaces").SourceBuffer;
const DOMString = @import("typedefs").DOMString;

pub const AudioTrack = struct {
    pub const Meta = struct {
        pub const name = "AudioTrack";
        pub const is_mixin = false;
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
            .{ "enabled", "get_enabled", "set_enabled" },
            .{ "sourceBuffer", "get_sourceBuffer", null },
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
            .{ "id", "get_id", null },
            .{ "kind", "get_kind", null },
            .{ "label", "get_label", null },
            .{ "language", "get_language", null },
            .{ "enabled", "get_enabled", "set_enabled" },
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
            enabled: bool = undefined,
            sourceBuffer: ?SourceBuffer = null,
        },
    );

    const delegates = .{

        .get_enabled = &get_enabled,
        .get_id = &get_id,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_language = &get_language,
        .get_sourceBuffer = &get_sourceBuffer,

        .set_enabled = &set_enabled,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioTrackImpl.deinit(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_id(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_kind(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_label(instance);
    }

    pub fn get_language(instance: *runtime.Instance) anyerror!DOMString {
        return try AudioTrackImpl.get_language(instance);
    }

    pub fn get_enabled(instance: *runtime.Instance) anyerror!bool {
        return try AudioTrackImpl.get_enabled(instance);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try AudioTrackImpl.set_enabled(instance, value);
    }

    pub fn get_sourceBuffer(instance: *runtime.Instance) anyerror!SourceBuffer {
        return try AudioTrackImpl.get_sourceBuffer(instance);
    }

};

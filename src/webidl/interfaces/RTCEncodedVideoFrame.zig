//! Generated from: webrtc-encoded-transform.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCEncodedVideoFrameImpl = @import("impls").RTCEncodedVideoFrame;
const mixins = @import("mixins");
const RTCEncodedVideoFrameOptions = @import("dictionaries").RTCEncodedVideoFrameOptions;
const RTCEncodedVideoFrameMetadata = @import("dictionaries").RTCEncodedVideoFrameMetadata;
const RTCEncodedVideoFrameType = @import("enums").RTCEncodedVideoFrameType;

pub const RTCEncodedVideoFrame = struct {
    pub const Meta = struct {
        pub const name = "RTCEncodedVideoFrame";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
        };

        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };

        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "data", "get_data", "set_data" },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getMetadata", "call_getMetadata", 0 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getMetadata",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "data", "get_data", "set_data" },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: RTCEncodedVideoFrameType = undefined,
            data: runtime.ArrayBuffer = undefined,
            _internal: ?*RTCEncodedVideoFrameImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_data = &get_data,
        .get_type = &get_type,

        .set_data = &set_data,

        .call_getMetadata = &call_getMetadata,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCEncodedVideoFrameImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCEncodedVideoFrameImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, originalFrame: *runtime.Instance, options: webidl.Opt(RTCEncodedVideoFrameOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCEncodedVideoFrameImpl.call_constructor(allocator, ctx, originalFrame, options);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!RTCEncodedVideoFrameType {
        return try RTCEncodedVideoFrameImpl.get_type(instance);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCEncodedVideoFrameImpl.get_data(instance);
    }

    pub fn set_data(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try RTCEncodedVideoFrameImpl.set_data(instance, value);
    }

    pub fn call_getMetadata(instance: *runtime.Instance) anyerror!RTCEncodedVideoFrameMetadata {
        return try RTCEncodedVideoFrameImpl.call_getMetadata(instance);
    }
};

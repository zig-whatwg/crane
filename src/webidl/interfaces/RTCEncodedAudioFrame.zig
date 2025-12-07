//! Generated from: webrtc-encoded-transform.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const RTCEncodedAudioFrameImpl = @import("impls").RTCEncodedAudioFrame;
const mixins = @import("mixins");
const RTCEncodedAudioFrameOptions = @import("dictionaries").RTCEncodedAudioFrameOptions;
const RTCEncodedAudioFrameMetadata = @import("dictionaries").RTCEncodedAudioFrameMetadata;

pub const RTCEncodedAudioFrame = struct {
    pub const Meta = struct {
        pub const name = "RTCEncodedAudioFrame";
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
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "data", "get_data", "set_data" },
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
            data: runtime.ArrayBuffer = undefined,
            _internal: ?*RTCEncodedAudioFrameImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,

        .set_data = &set_data,

        .call_getMetadata = &call_getMetadata,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return RTCEncodedAudioFrameImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        RTCEncodedAudioFrameImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, originalFrame: *runtime.Instance, options: webidl.Opt(RTCEncodedAudioFrameOptions)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try RTCEncodedAudioFrameImpl.call_constructor(allocator, ctx, originalFrame, options);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try RTCEncodedAudioFrameImpl.get_data(instance);
    }

    pub fn set_data(instance: *runtime.Instance, value: *const anyopaque) anyerror!void {
        try RTCEncodedAudioFrameImpl.set_data(instance, value);
    }

    pub fn call_getMetadata(instance: *runtime.Instance) anyerror!RTCEncodedAudioFrameMetadata {
        return try RTCEncodedAudioFrameImpl.call_getMetadata(instance);
    }

};

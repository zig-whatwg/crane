//! Generated from: webcodecs.idl
//! Generated at: 2025-12-05T20:30:45Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EncodedAudioChunkImpl = @import("impls").EncodedAudioChunk;
const mixins = @import("mixins");
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const EncodedAudioChunkType = @import("enums").EncodedAudioChunkType;
const EncodedAudioChunkInit = @import("dictionaries").EncodedAudioChunkInit;

pub const EncodedAudioChunk = struct {
    pub const Meta = struct {
        pub const name = "EncodedAudioChunk";
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
            .{ "timestamp", "get_timestamp", null },
            .{ "duration", "get_duration", null },
            .{ "byteLength", "get_byteLength", null },
        };

        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "copyTo", "call_copyTo", 1 },
        };

        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "copyTo",
        };

        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{};

        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "duration", "get_duration", null },
            .{ "byteLength", "get_byteLength", null },
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            type: EncodedAudioChunkType = undefined,
            timestamp: i64 = undefined,
            duration: ?u64 = null,
            byteLength: u32 = undefined,
            _internal: ?*EncodedAudioChunkImpl.InternalState = null,
        },
    );

    const delegates = .{
        .get_byteLength = &get_byteLength,
        .get_duration = &get_duration,
        .get_timestamp = &get_timestamp,
        .get_type = &get_type,

        .call_copyTo = &call_copyTo,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EncodedAudioChunkImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EncodedAudioChunkImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: EncodedAudioChunkInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EncodedAudioChunkImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!EncodedAudioChunkType {
        return try EncodedAudioChunkImpl.get_type(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try EncodedAudioChunkImpl.get_timestamp(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!?u64 {
        return try EncodedAudioChunkImpl.get_duration(instance);
    }

    pub fn get_byteLength(instance: *runtime.Instance) anyerror!u32 {
        return try EncodedAudioChunkImpl.get_byteLength(instance);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource) anyerror!void {
        return try EncodedAudioChunkImpl.call_copyTo(instance, destination);
    }
};

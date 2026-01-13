//! Generated from: webcodecs.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const EncodedVideoChunkImpl = @import("impls").EncodedVideoChunk;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EncodedVideoChunkType = @import("enums").EncodedVideoChunkType;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const EncodedVideoChunkInit = @import("dictionaries").EncodedVideoChunkInit;

pub const EncodedVideoChunk = struct {
    pub const Meta = struct {
        pub const name = "EncodedVideoChunk";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = null;
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
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "timestamp", "get_timestamp", null },
            .{ "duration", "get_duration", null },
            .{ "byteLength", "get_byteLength", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"type": enums.EncodedVideoChunkType = undefined,
            timestamp: i64 = undefined,
            duration: ?u64 = null,
            byteLength: u32 = undefined,
            _internal: ?*EncodedVideoChunkImpl.InternalState = null,
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
        return EncodedVideoChunkImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return EncodedVideoChunkImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EncodedVideoChunkImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, init_data: EncodedVideoChunkInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try EncodedVideoChunkImpl.call_constructor(ctx, init_data);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!EncodedVideoChunkType {
        return try EncodedVideoChunkImpl.get_type(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try EncodedVideoChunkImpl.get_timestamp(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!?u64 {
        return try EncodedVideoChunkImpl.get_duration(instance);
    }

    pub fn get_byteLength(instance: *runtime.Instance) anyerror!u32 {
        return try EncodedVideoChunkImpl.get_byteLength(instance);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource) anyerror!void {
        
        return try EncodedVideoChunkImpl.call_copyTo(instance, destination);
    }

};

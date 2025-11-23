//! Generated from: webcodecs.idl
//! Generated at: 2025-11-23T14:26:30Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioDataImpl = @import("impls").AudioData;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const AudioDataInit = @import("dictionaries").AudioDataInit;
const AudioDataCopyToOptions = @import("dictionaries").AudioDataCopyToOptions;
const AudioSampleFormat = @import("enums").AudioSampleFormat;

pub const AudioData = struct {
    pub const Meta = struct {
        pub const name = "AudioData";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
            .{ .name = "Serializable" },
            .{ .name = "Transferable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "format", "get_format", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "numberOfFrames", "get_numberOfFrames", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "allocationSize", "call_allocationSize", 1 },
            .{ "copyTo", "call_copyTo", 2 },
            .{ "clone", "call_clone", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "allocationSize",
            "copyTo",
            "clone",
            "close",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "format", "get_format", null },
            .{ "sampleRate", "get_sampleRate", null },
            .{ "numberOfFrames", "get_numberOfFrames", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
            .{ "duration", "get_duration", null },
            .{ "timestamp", "get_timestamp", null },
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
            format: ?AudioSampleFormat = null,
            sampleRate: f32 = undefined,
            numberOfFrames: u32 = undefined,
            numberOfChannels: u32 = undefined,
            duration: u64 = undefined,
            timestamp: i64 = undefined,
            _internal: ?*AudioDataImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_duration = &get_duration,
        .get_format = &get_format,
        .get_numberOfChannels = &get_numberOfChannels,
        .get_numberOfFrames = &get_numberOfFrames,
        .get_sampleRate = &get_sampleRate,
        .get_timestamp = &get_timestamp,

        .call_allocationSize = &call_allocationSize,
        .call_clone = &call_clone,
        .call_close = &call_close,
        .call_copyTo = &call_copyTo,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioDataImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioDataImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: AudioDataInit) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioDataImpl.call_constructor(allocator, ctx, init_data);
    }

    pub fn get_format(instance: *runtime.Instance) anyerror!AudioSampleFormat {
        return try AudioDataImpl.get_format(instance);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioDataImpl.get_sampleRate(instance);
    }

    pub fn get_numberOfFrames(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDataImpl.get_numberOfFrames(instance);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) anyerror!u32 {
        return try AudioDataImpl.get_numberOfChannels(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!u64 {
        return try AudioDataImpl.get_duration(instance);
    }

    pub fn get_timestamp(instance: *runtime.Instance) anyerror!i64 {
        return try AudioDataImpl.get_timestamp(instance);
    }

    pub fn call_allocationSize(instance: *runtime.Instance, options: AudioDataCopyToOptions) anyerror!u32 {
        
        return try AudioDataImpl.call_allocationSize(instance, options);
    }

    pub fn call_copyTo(instance: *runtime.Instance, destination: AllowSharedBufferSource, options: AudioDataCopyToOptions) anyerror!void {
        
        return try AudioDataImpl.call_copyTo(instance, destination, options);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!AudioData {
        return try AudioDataImpl.call_clone(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try AudioDataImpl.call_close(instance);
    }

};

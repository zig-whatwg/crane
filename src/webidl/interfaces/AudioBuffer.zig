//! Generated from: webaudio.idl
//! Generated at: 2025-11-28T18:02:26Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const AudioBufferImpl = @import("impls").AudioBuffer;
const AudioBufferOptions = @import("dictionaries").AudioBufferOptions;

pub const AudioBuffer = struct {
    pub const Meta = struct {
        pub const name = "AudioBuffer";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
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
            .{ "sampleRate", "get_sampleRate", null },
            .{ "length", "get_length", null },
            .{ "duration", "get_duration", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "getChannelData", "call_getChannelData", 1 },
            .{ "copyFromChannel", "call_copyFromChannel", 2 },
            .{ "copyToChannel", "call_copyToChannel", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "getChannelData",
            "copyFromChannel",
            "copyToChannel",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "sampleRate", "get_sampleRate", null },
            .{ "length", "get_length", null },
            .{ "duration", "get_duration", null },
            .{ "numberOfChannels", "get_numberOfChannels", null },
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
            sampleRate: f32 = undefined,
            length: u32 = undefined,
            duration: f64 = undefined,
            numberOfChannels: u32 = undefined,
            _internal: ?*AudioBufferImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_duration = &get_duration,
        .get_length = &get_length,
        .get_numberOfChannels = &get_numberOfChannels,
        .get_sampleRate = &get_sampleRate,

        .call_copyFromChannel = &call_copyFromChannel,
        .call_copyToChannel = &call_copyToChannel,
        .call_getChannelData = &call_getChannelData,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return AudioBufferImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        AudioBufferImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, options: AudioBufferOptions) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try AudioBufferImpl.call_constructor(allocator, ctx, options);
    }

    pub fn get_sampleRate(instance: *runtime.Instance) anyerror!f32 {
        return try AudioBufferImpl.get_sampleRate(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferImpl.get_length(instance);
    }

    pub fn get_duration(instance: *runtime.Instance) anyerror!f64 {
        return try AudioBufferImpl.get_duration(instance);
    }

    pub fn get_numberOfChannels(instance: *runtime.Instance) anyerror!u32 {
        return try AudioBufferImpl.get_numberOfChannels(instance);
    }

    pub fn call_getChannelData(instance: *runtime.Instance, channel: u32) anyerror!*const anyopaque {
        
        return try AudioBufferImpl.call_getChannelData(instance, channel);
    }

    pub fn call_copyFromChannel(instance: *runtime.Instance, destination: *const anyopaque, channelNumber: u32, bufferOffset: u32) anyerror!void {
        
        return try AudioBufferImpl.call_copyFromChannel(instance, destination, channelNumber, bufferOffset);
    }

    pub fn call_copyToChannel(instance: *runtime.Instance, source: *const anyopaque, channelNumber: u32, bufferOffset: u32) anyerror!void {
        
        return try AudioBufferImpl.call_copyToChannel(instance, source, channelNumber, bufferOffset);
    }

};

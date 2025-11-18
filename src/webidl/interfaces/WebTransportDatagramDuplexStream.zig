//! Generated from: webtransport.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportDatagramDuplexStreamImpl = @import("impls").WebTransportDatagramDuplexStream;
const unrestricted double = @import("interfaces").unrestricted double;
const WebTransportSendOptions = @import("dictionaries").WebTransportSendOptions;
const WebTransportDatagramsWritable = @import("interfaces").WebTransportDatagramsWritable;
const ReadableStream = @import("interfaces").ReadableStream;

pub const WebTransportDatagramDuplexStream = struct {
    pub const Meta = struct {
        pub const name = "WebTransportDatagramDuplexStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            readable: ReadableStream = undefined,
            maxDatagramSize: u32 = undefined,
            incomingMaxAge: ?f64 = null,
            outgoingMaxAge: ?f64 = null,
            incomingHighWaterMark: f64 = undefined,
            outgoingHighWaterMark: f64 = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(WebTransportDatagramDuplexStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_incomingHighWaterMark = &get_incomingHighWaterMark,
        .get_incomingMaxAge = &get_incomingMaxAge,
        .get_maxDatagramSize = &get_maxDatagramSize,
        .get_outgoingHighWaterMark = &get_outgoingHighWaterMark,
        .get_outgoingMaxAge = &get_outgoingMaxAge,
        .get_readable = &get_readable,

        .set_incomingHighWaterMark = &set_incomingHighWaterMark,
        .set_incomingMaxAge = &set_incomingMaxAge,
        .set_outgoingHighWaterMark = &set_outgoingHighWaterMark,
        .set_outgoingMaxAge = &set_outgoingMaxAge,

        .call_createWritable = &call_createWritable,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WebTransportDatagramDuplexStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebTransportDatagramDuplexStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!ReadableStream {
        return try WebTransportDatagramDuplexStreamImpl.get_readable(instance);
    }

    pub fn get_maxDatagramSize(instance: *runtime.Instance) anyerror!u32 {
        return try WebTransportDatagramDuplexStreamImpl.get_maxDatagramSize(instance);
    }

    pub fn get_incomingMaxAge(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportDatagramDuplexStreamImpl.get_incomingMaxAge(instance);
    }

    pub fn set_incomingMaxAge(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_incomingMaxAge(instance, value);
    }

    pub fn get_outgoingMaxAge(instance: *runtime.Instance) anyerror!anyopaque {
        return try WebTransportDatagramDuplexStreamImpl.get_outgoingMaxAge(instance);
    }

    pub fn set_outgoingMaxAge(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_outgoingMaxAge(instance, value);
    }

    pub fn get_incomingHighWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try WebTransportDatagramDuplexStreamImpl.get_incomingHighWaterMark(instance);
    }

    pub fn set_incomingHighWaterMark(instance: *runtime.Instance, value: f64) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_incomingHighWaterMark(instance, value);
    }

    pub fn get_outgoingHighWaterMark(instance: *runtime.Instance) anyerror!f64 {
        return try WebTransportDatagramDuplexStreamImpl.get_outgoingHighWaterMark(instance);
    }

    pub fn set_outgoingHighWaterMark(instance: *runtime.Instance, value: f64) anyerror!void {
        try WebTransportDatagramDuplexStreamImpl.set_outgoingHighWaterMark(instance, value);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: WebTransportSendOptions) anyerror!WebTransportDatagramsWritable {
        
        return try WebTransportDatagramDuplexStreamImpl.call_createWritable(instance, options);
    }

};

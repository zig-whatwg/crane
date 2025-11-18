//! Generated from: webtransport.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebTransportDatagramDuplexStreamImpl = @import("../impls/WebTransportDatagramDuplexStream.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        WebTransportDatagramDuplexStreamImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WebTransportDatagramDuplexStreamImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportDatagramDuplexStreamImpl.get_readable(state);
    }

    pub fn get_maxDatagramSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return WebTransportDatagramDuplexStreamImpl.get_maxDatagramSize(state);
    }

    pub fn get_incomingMaxAge(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportDatagramDuplexStreamImpl.get_incomingMaxAge(state);
    }

    pub fn set_incomingMaxAge(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebTransportDatagramDuplexStreamImpl.set_incomingMaxAge(state, value);
    }

    pub fn get_outgoingMaxAge(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return WebTransportDatagramDuplexStreamImpl.get_outgoingMaxAge(state);
    }

    pub fn set_outgoingMaxAge(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        WebTransportDatagramDuplexStreamImpl.set_outgoingMaxAge(state, value);
    }

    pub fn get_incomingHighWaterMark(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WebTransportDatagramDuplexStreamImpl.get_incomingHighWaterMark(state);
    }

    pub fn set_incomingHighWaterMark(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        WebTransportDatagramDuplexStreamImpl.set_incomingHighWaterMark(state, value);
    }

    pub fn get_outgoingHighWaterMark(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return WebTransportDatagramDuplexStreamImpl.get_outgoingHighWaterMark(state);
    }

    pub fn set_outgoingHighWaterMark(instance: *runtime.Instance, value: f64) void {
        const state = instance.getState(State);
        WebTransportDatagramDuplexStreamImpl.set_outgoingHighWaterMark(state, value);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return WebTransportDatagramDuplexStreamImpl.call_createWritable(state, options);
    }

};

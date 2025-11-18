//! Generated from: web-smart-card.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardConnectionImpl = @import("../impls/SmartCardConnection.zig");

pub const SmartCardConnection = struct {
    pub const Meta = struct {
        pub const name = "SmartCardConnection";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SmartCardConnection, .{
        .deinit_fn = &deinit_wrapper,

        .call_control = &call_control,
        .call_disconnect = &call_disconnect,
        .call_getAttribute = &call_getAttribute,
        .call_setAttribute = &call_setAttribute,
        .call_startTransaction = &call_startTransaction,
        .call_status = &call_status,
        .call_transmit = &call_transmit,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SmartCardConnectionImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SmartCardConnectionImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_startTransaction(instance: *runtime.Instance, transaction: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SmartCardConnectionImpl.call_startTransaction(state, transaction, options);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, tag: u32) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on tag
        if (tag > std.math.maxInt(u53)) return error.TypeError;
        
        return SmartCardConnectionImpl.call_getAttribute(state, tag);
    }

    pub fn call_transmit(instance: *runtime.Instance, sendBuffer: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SmartCardConnectionImpl.call_transmit(state, sendBuffer, options);
    }

    pub fn call_status(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SmartCardConnectionImpl.call_status(state);
    }

    pub fn call_disconnect(instance: *runtime.Instance, disposition: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SmartCardConnectionImpl.call_disconnect(state, disposition);
    }

    pub fn call_setAttribute(instance: *runtime.Instance, tag: u32, value: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on tag
        if (tag > std.math.maxInt(u53)) return error.TypeError;
        
        return SmartCardConnectionImpl.call_setAttribute(state, tag, value);
    }

    pub fn call_control(instance: *runtime.Instance, controlCode: u32, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on controlCode
        if (controlCode > std.math.maxInt(u53)) return error.TypeError;
        
        return SmartCardConnectionImpl.call_control(state, controlCode, data);
    }

};

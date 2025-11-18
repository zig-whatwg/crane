//! Generated from: web-smart-card.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardConnectionImpl = @import("impls").SmartCardConnection;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const Promise<SmartCardConnectionStatus> = @import("interfaces").Promise<SmartCardConnectionStatus>;
const SmartCardTransactionOptions = @import("dictionaries").SmartCardTransactionOptions;
const SmartCardTransactionCallback = @import("callbacks").SmartCardTransactionCallback;
const BufferSource = @import("typedefs").BufferSource;
const SmartCardDisposition = @import("enums").SmartCardDisposition;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const SmartCardTransmitOptions = @import("dictionaries").SmartCardTransmitOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        SmartCardConnectionImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SmartCardConnectionImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_startTransaction(instance: *runtime.Instance, transaction: SmartCardTransactionCallback, options: SmartCardTransactionOptions) anyerror!anyopaque {
        
        return try SmartCardConnectionImpl.call_startTransaction(instance, transaction, options);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, tag: u32) anyerror!anyopaque {
        // [EnforceRange] on tag
        if (!runtime.isInRange(tag)) return error.TypeError;
        
        return try SmartCardConnectionImpl.call_getAttribute(instance, tag);
    }

    pub fn call_transmit(instance: *runtime.Instance, sendBuffer: BufferSource, options: SmartCardTransmitOptions) anyerror!anyopaque {
        
        return try SmartCardConnectionImpl.call_transmit(instance, sendBuffer, options);
    }

    pub fn call_status(instance: *runtime.Instance) anyerror!anyopaque {
        return try SmartCardConnectionImpl.call_status(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance, disposition: SmartCardDisposition) anyerror!anyopaque {
        
        return try SmartCardConnectionImpl.call_disconnect(instance, disposition);
    }

    pub fn call_setAttribute(instance: *runtime.Instance, tag: u32, value: BufferSource) anyerror!anyopaque {
        // [EnforceRange] on tag
        if (!runtime.isInRange(tag)) return error.TypeError;
        
        return try SmartCardConnectionImpl.call_setAttribute(instance, tag, value);
    }

    pub fn call_control(instance: *runtime.Instance, controlCode: u32, data: BufferSource) anyerror!anyopaque {
        // [EnforceRange] on controlCode
        if (!runtime.isInRange(controlCode)) return error.TypeError;
        
        return try SmartCardConnectionImpl.call_control(instance, controlCode, data);
    }

};

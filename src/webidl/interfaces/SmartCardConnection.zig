//! Generated from: web-smart-card.idl
//! Generated at: 2025-11-28T18:57:54Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const SmartCardConnectionImpl = @import("impls").SmartCardConnection;
const mixins = @import("mixins");
const SmartCardTransactionOptions = @import("dictionaries").SmartCardTransactionOptions;
const SmartCardTransactionCallback = @import("callbacks").SmartCardTransactionCallback;
const SmartCardDisposition = @import("enums").SmartCardDisposition;
const BufferSource = @import("typedefs").BufferSource;
const SmartCardConnectionStatus = @import("dictionaries").SmartCardConnectionStatus;
const SmartCardTransmitOptions = @import("dictionaries").SmartCardTransmitOptions;

pub const SmartCardConnection = struct {
    pub const Meta = struct {
        pub const name = "SmartCardConnection";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "DedicatedWorker", "SharedWorker", "Window" } } },
            .{ .name = "SecureContext" },
            .{ .name = "IsolatedContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .DedicatedWorker = true,
            .SharedWorker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "disconnect", "call_disconnect", 0 },
            .{ "transmit", "call_transmit", 1 },
            .{ "startTransaction", "call_startTransaction", 1 },
            .{ "status", "call_status", 0 },
            .{ "control", "call_control", 2 },
            .{ "getAttribute", "call_getAttribute", 1 },
            .{ "setAttribute", "call_setAttribute", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "disconnect",
            "transmit",
            "startTransaction",
            "status",
            "control",
            "getAttribute",
            "setAttribute",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*SmartCardConnectionImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_control = &call_control,
        .call_disconnect = &call_disconnect,
        .call_getAttribute = &call_getAttribute,
        .call_setAttribute = &call_setAttribute,
        .call_startTransaction = &call_startTransaction,
        .call_status = &call_status,
        .call_transmit = &call_transmit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return SmartCardConnectionImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        SmartCardConnectionImpl.deinit(instance);
    }

    pub fn call_startTransaction(instance: *runtime.Instance, transaction: SmartCardTransactionCallback, options: webidl.Opt(SmartCardTransactionOptions)) anyerror!*const anyopaque {
        
        return try SmartCardConnectionImpl.call_startTransaction(instance, transaction, options);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, tag: u32) anyerror!*const anyopaque {
        // [EnforceRange] on tag
        if (!runtime.isInRange(u32, tag)) return error.TypeError;
        
        return try SmartCardConnectionImpl.call_getAttribute(instance, tag);
    }

    pub fn call_transmit(instance: *runtime.Instance, sendBuffer: BufferSource, options: webidl.Opt(SmartCardTransmitOptions)) anyerror!*const anyopaque {
        
        return try SmartCardConnectionImpl.call_transmit(instance, sendBuffer, options);
    }

    pub fn call_status(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try SmartCardConnectionImpl.call_status(instance);
    }

    pub fn call_disconnect(instance: *runtime.Instance, disposition: webidl.Opt(SmartCardDisposition)) anyerror!*const anyopaque {
        
        return try SmartCardConnectionImpl.call_disconnect(instance, disposition);
    }

    pub fn call_setAttribute(instance: *runtime.Instance, tag: u32, value: BufferSource) anyerror!*const anyopaque {
        // [EnforceRange] on tag
        if (!runtime.isInRange(u32, tag)) return error.TypeError;
        
        return try SmartCardConnectionImpl.call_setAttribute(instance, tag, value);
    }

    pub fn call_control(instance: *runtime.Instance, controlCode: u32, data: BufferSource) anyerror!*const anyopaque {
        // [EnforceRange] on controlCode
        if (!runtime.isInRange(u32, controlCode)) return error.TypeError;
        
        return try SmartCardConnectionImpl.call_control(instance, controlCode, data);
    }

};

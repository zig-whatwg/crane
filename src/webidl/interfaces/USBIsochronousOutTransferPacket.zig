//! Generated from: webusb.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBIsochronousOutTransferPacketImpl = @import("impls").USBIsochronousOutTransferPacket;
const mixins = @import("mixins");
const USBTransferStatus = @import("enums").USBTransferStatus;

pub const USBIsochronousOutTransferPacket = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousOutTransferPacket";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "bytesWritten", "get_bytesWritten", null },
            .{ "status", "get_status", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "bytesWritten", "get_bytesWritten", null },
            .{ "status", "get_status", null },
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
            bytesWritten: u32 = undefined,
            status: USBTransferStatus = undefined,
            _internal: ?*USBIsochronousOutTransferPacketImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_bytesWritten = &get_bytesWritten,
        .get_status = &get_status,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBIsochronousOutTransferPacketImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBIsochronousOutTransferPacketImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, status: USBTransferStatus, bytesWritten: webidl.Opt(u32)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBIsochronousOutTransferPacketImpl.call_constructor(allocator, ctx, status, bytesWritten);
    }

    pub fn get_bytesWritten(instance: *runtime.Instance) anyerror!u32 {
        return try USBIsochronousOutTransferPacketImpl.get_bytesWritten(instance);
    }

    pub fn get_status(instance: *runtime.Instance) anyerror!USBTransferStatus {
        return try USBIsochronousOutTransferPacketImpl.get_status(instance);
    }

};

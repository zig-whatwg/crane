//! Generated from: webusb.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const USBIsochronousInTransferResultImpl = @import("impls").USBIsochronousInTransferResult;
const mixins = @import("mixins");
const USBIsochronousInTransferPacket = @import("interfaces").USBIsochronousInTransferPacket;

pub const USBIsochronousInTransferResult = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousInTransferResult";
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
            .{ "data", "get_data", null },
            .{ "packets", "get_packets", null },
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
            .{ "data", "get_data", null },
            .{ "packets", "get_packets", null },
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
            data: ?runtime.DataView = null,
            packets: runtime.FrozenArray(USBIsochronousInTransferPacket) = undefined,
            _internal: ?*USBIsochronousInTransferResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_data = &get_data,
        .get_packets = &get_packets,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBIsochronousInTransferResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBIsochronousInTransferResultImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, packets: *const anyopaque, data: webidl.Opt(?*const anyopaque)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBIsochronousInTransferResultImpl.call_constructor(allocator, ctx, packets, data);
    }

    pub fn get_data(instance: *runtime.Instance) anyerror!?*const anyopaque {
        return try USBIsochronousInTransferResultImpl.get_data(instance);
    }

    pub fn get_packets(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try USBIsochronousInTransferResultImpl.get_packets(instance);
    }

};

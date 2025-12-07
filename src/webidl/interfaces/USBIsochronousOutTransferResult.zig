//! Generated from: webusb.idl
//! Generated at: 2025-12-07T20:02:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const USBIsochronousOutTransferResultImpl = @import("impls").USBIsochronousOutTransferResult;
const mixins = @import("mixins");
const USBIsochronousOutTransferPacket = @import("interfaces").USBIsochronousOutTransferPacket;

pub const USBIsochronousOutTransferResult = struct {
    pub const Meta = struct {
        pub const name = "USBIsochronousOutTransferResult";
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
            packets: runtime.FrozenArray(USBIsochronousOutTransferPacket) = undefined,
            _internal: ?*USBIsochronousOutTransferResultImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_packets = &get_packets,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return USBIsochronousOutTransferResultImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBIsochronousOutTransferResultImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, packets: *const anyopaque) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try USBIsochronousOutTransferResultImpl.call_constructor(allocator, ctx, packets);
    }

    pub fn get_packets(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try USBIsochronousOutTransferResultImpl.get_packets(instance);
    }

};

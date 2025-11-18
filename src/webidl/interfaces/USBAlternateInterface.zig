//! Generated from: webusb.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBAlternateInterfaceImpl = @import("impls").USBAlternateInterface;
const USBInterface = @import("interfaces").USBInterface;
const DOMString = @import("typedefs").DOMString;
const FrozenArray<USBEndpoint> = @import("interfaces").FrozenArray<USBEndpoint>;

pub const USBAlternateInterface = struct {
    pub const Meta = struct {
        pub const name = "USBAlternateInterface";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Worker", "Window" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Worker = true,
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            alternateSetting: u8 = undefined,
            interfaceClass: u8 = undefined,
            interfaceSubclass: u8 = undefined,
            interfaceProtocol: u8 = undefined,
            interfaceName: ?runtime.DOMString = null,
            endpoints: FrozenArray<USBEndpoint> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBAlternateInterface, .{
        .deinit_fn = &deinit_wrapper,

        .get_alternateSetting = &get_alternateSetting,
        .get_endpoints = &get_endpoints,
        .get_interfaceClass = &get_interfaceClass,
        .get_interfaceName = &get_interfaceName,
        .get_interfaceProtocol = &get_interfaceProtocol,
        .get_interfaceSubclass = &get_interfaceSubclass,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        USBAlternateInterfaceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        USBAlternateInterfaceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, deviceInterface: USBInterface, alternateSetting: u8) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        try USBAlternateInterfaceImpl.constructor(instance, deviceInterface, alternateSetting);
        
        return instance;
    }

    pub fn get_alternateSetting(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_alternateSetting(instance);
    }

    pub fn get_interfaceClass(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceClass(instance);
    }

    pub fn get_interfaceSubclass(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceSubclass(instance);
    }

    pub fn get_interfaceProtocol(instance: *runtime.Instance) anyerror!u8 {
        return try USBAlternateInterfaceImpl.get_interfaceProtocol(instance);
    }

    pub fn get_interfaceName(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBAlternateInterfaceImpl.get_interfaceName(instance);
    }

    pub fn get_endpoints(instance: *runtime.Instance) anyerror!anyopaque {
        return try USBAlternateInterfaceImpl.get_endpoints(instance);
    }

};

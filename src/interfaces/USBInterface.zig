//! Generated from: webusb.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const USBInterfaceImpl = @import("../impls/USBInterface.zig");

pub const USBInterface = struct {
    pub const Meta = struct {
        pub const name = "USBInterface";
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
            interfaceNumber: u8 = undefined,
            alternate: USBAlternateInterface = undefined,
            alternates: FrozenArray<USBAlternateInterface> = undefined,
            claimed: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(USBInterface, .{
        .deinit_fn = &deinit_wrapper,

        .get_alternate = &get_alternate,
        .get_alternates = &get_alternates,
        .get_claimed = &get_claimed,
        .get_interfaceNumber = &get_interfaceNumber,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        USBInterfaceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        USBInterfaceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, configuration: anyopaque, interfaceNumber: u8) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try USBInterfaceImpl.constructor(state, configuration, interfaceNumber);
        
        return instance;
    }

    pub fn get_interfaceNumber(instance: *runtime.Instance) u8 {
        const state = instance.getState(State);
        return USBInterfaceImpl.get_interfaceNumber(state);
    }

    pub fn get_alternate(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBInterfaceImpl.get_alternate(state);
    }

    pub fn get_alternates(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return USBInterfaceImpl.get_alternates(state);
    }

    pub fn get_claimed(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return USBInterfaceImpl.get_claimed(state);
    }

};

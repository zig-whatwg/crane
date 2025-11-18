//! Generated from: web-smart-card.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SmartCardContextImpl = @import("../impls/SmartCardContext.zig");

pub const SmartCardContext = struct {
    pub const Meta = struct {
        pub const name = "SmartCardContext";
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

    pub const vtable = runtime.buildVTable(SmartCardContext, .{
        .deinit_fn = &deinit_wrapper,

        .call_connect = &call_connect,
        .call_getStatusChange = &call_getStatusChange,
        .call_listReaders = &call_listReaders,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SmartCardContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SmartCardContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_listReaders(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return SmartCardContextImpl.call_listReaders(state);
    }

    pub fn call_getStatusChange(instance: *runtime.Instance, readerStates: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SmartCardContextImpl.call_getStatusChange(state, readerStates, options);
    }

    pub fn call_connect(instance: *runtime.Instance, readerName: runtime.DOMString, accessMode: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SmartCardContextImpl.call_connect(state, readerName, accessMode, options);
    }

};

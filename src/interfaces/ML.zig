//! Generated from: webnn.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLImpl = @import("../impls/ML.zig");

pub const ML = struct {
    pub const Meta = struct {
        pub const name = "ML";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ML, .{
        .deinit_fn = &deinit_wrapper,

        .call_createContext = &call_createContext,
        .call_createContext = &call_createContext,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MLImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MLImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for createContext (WebIDL overloading)
    pub const CreateContextArgs = union(enum) {
        /// createContext(options)
        MLContextOptions: anyopaque,
        /// createContext(gpuDevice)
        GPUDevice: anyopaque,
    };

    pub fn call_createContext(instance: *runtime.Instance, args: CreateContextArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .MLContextOptions => |arg| return MLImpl.MLContextOptions(state, arg),
            .GPUDevice => |arg| return MLImpl.GPUDevice(state, arg),
        }
    }

};

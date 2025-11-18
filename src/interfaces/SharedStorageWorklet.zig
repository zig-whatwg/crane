//! Generated from: shared-storage.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const SharedStorageWorkletImpl = @import("../impls/SharedStorageWorklet.zig");
const Worklet = @import("Worklet.zig");

pub const SharedStorageWorklet = struct {
    pub const Meta = struct {
        pub const name = "SharedStorageWorklet";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Worklet;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(SharedStorageWorklet, .{
        .deinit_fn = &deinit_wrapper,

        .call_addModule = &call_addModule,
        .call_run = &call_run,
        .call_selectURL = &call_selectURL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        SharedStorageWorkletImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        SharedStorageWorkletImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_run(instance: *runtime.Instance, name: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageWorkletImpl.call_run(state, name, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_addModule(instance: *runtime.Instance, moduleURL: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        // [NewObject] - Caller owns the returned object
        
        return SharedStorageWorkletImpl.call_addModule(state, moduleURL, options);
    }

    pub fn call_selectURL(instance: *runtime.Instance, name: runtime.DOMString, urls: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return SharedStorageWorkletImpl.call_selectURL(state, name, urls, options);
    }

};

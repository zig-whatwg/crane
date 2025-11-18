//! Generated from: fenced-frame.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FencedFrameConfigImpl = @import("../impls/FencedFrameConfig.zig");

pub const FencedFrameConfig = struct {
    pub const Meta = struct {
        pub const name = "FencedFrameConfig";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FencedFrameConfig, .{
        .deinit_fn = &deinit_wrapper,

        .call_setSharedStorageContext = &call_setSharedStorageContext,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FencedFrameConfigImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FencedFrameConfigImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, url: runtime.USVString) !*runtime.Instance {
        const instance = try init(allocator);
        errdefer deinit(instance);
        
        const state = instance.getState(State);
        try FencedFrameConfigImpl.constructor(state, url);
        
        return instance;
    }

    pub fn call_setSharedStorageContext(instance: *runtime.Instance, contextString: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return FencedFrameConfigImpl.call_setSharedStorageContext(state, contextString);
    }

};

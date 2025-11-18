//! Generated from: periodic-background-sync.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PeriodicSyncManagerImpl = @import("impls").PeriodicSyncManager;
const BackgroundSyncOptions = @import("dictionaries").BackgroundSyncOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<sequence<DOMString>> = @import("interfaces").Promise<sequence<DOMString>>;

pub const PeriodicSyncManager = struct {
    pub const Meta = struct {
        pub const name = "PeriodicSyncManager";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
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

    pub const vtable = runtime.buildVTable(PeriodicSyncManager, .{
        .deinit_fn = &deinit_wrapper,

        .call_getTags = &call_getTags,
        .call_register = &call_register,
        .call_unregister = &call_unregister,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PeriodicSyncManagerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PeriodicSyncManagerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getTags(instance: *runtime.Instance) anyerror!anyopaque {
        return try PeriodicSyncManagerImpl.call_getTags(instance);
    }

    pub fn call_unregister(instance: *runtime.Instance, tag: DOMString) anyerror!anyopaque {
        
        return try PeriodicSyncManagerImpl.call_unregister(instance, tag);
    }

    pub fn call_register(instance: *runtime.Instance, tag: DOMString, options: BackgroundSyncOptions) anyerror!anyopaque {
        
        return try PeriodicSyncManagerImpl.call_register(instance, tag, options);
    }

};

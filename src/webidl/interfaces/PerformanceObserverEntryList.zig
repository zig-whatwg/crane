//! Generated from: performance-timeline.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const PerformanceObserverEntryListImpl = @import("impls").PerformanceObserverEntryList;
const PerformanceEntryList = @import("typedefs").PerformanceEntryList;

pub const PerformanceObserverEntryList = struct {
    pub const Meta = struct {
        pub const name = "PerformanceObserverEntryList";
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

    pub const vtable = runtime.buildVTable(PerformanceObserverEntryList, .{
        .deinit_fn = &deinit_wrapper,

        .call_getEntries = &call_getEntries,
        .call_getEntriesByName = &call_getEntriesByName,
        .call_getEntriesByType = &call_getEntriesByType,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        PerformanceObserverEntryListImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        PerformanceObserverEntryListImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getEntries(instance: *runtime.Instance) anyerror!PerformanceEntryList {
        return try PerformanceObserverEntryListImpl.call_getEntries(instance);
    }

    pub fn call_getEntriesByType(instance: *runtime.Instance, type_: DOMString) anyerror!PerformanceEntryList {
        
        return try PerformanceObserverEntryListImpl.call_getEntriesByType(instance, type_);
    }

    pub fn call_getEntriesByName(instance: *runtime.Instance, name: DOMString, type_: DOMString) anyerror!PerformanceEntryList {
        
        return try PerformanceObserverEntryListImpl.call_getEntriesByName(instance, name, type_);
    }

};

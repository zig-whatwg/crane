//! Generated from: console.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const consoleImpl = @import("impls").console;
const object = @import("interfaces").object;

pub const console = struct {
    pub const Meta = struct {
        pub const name = "console";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(console, .{
        .deinit_fn = &deinit_wrapper,

        .call_assert = &call_assert,
        .call_clear = &call_clear,
        .call_count = &call_count,
        .call_countReset = &call_countReset,
        .call_debug = &call_debug,
        .call_dir = &call_dir,
        .call_dirxml = &call_dirxml,
        .call_error = &call_error,
        .call_group = &call_group,
        .call_groupCollapsed = &call_groupCollapsed,
        .call_groupEnd = &call_groupEnd,
        .call_info = &call_info,
        .call_log = &call_log,
        .call_table = &call_table,
        .call_time = &call_time,
        .call_timeEnd = &call_timeEnd,
        .call_timeLog = &call_timeLog,
        .call_trace = &call_trace,
        .call_warn = &call_warn,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        consoleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        consoleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_info(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_info(instance, data);
    }

    pub fn call_group(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_group(instance, data);
    }

    pub fn call_groupCollapsed(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_groupCollapsed(instance, data);
    }

    pub fn call_groupEnd(instance: *runtime.Instance) anyerror!void {
        return try consoleImpl.call_groupEnd(instance);
    }

    pub fn call_timeLog(instance: *runtime.Instance, label: DOMString, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_timeLog(instance, label, data);
    }

    pub fn call_trace(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_trace(instance, data);
    }

    pub fn call_timeEnd(instance: *runtime.Instance, label: DOMString) anyerror!void {
        
        return try consoleImpl.call_timeEnd(instance, label);
    }

    pub fn call_count(instance: *runtime.Instance, label: DOMString) anyerror!void {
        
        return try consoleImpl.call_count(instance, label);
    }

    pub fn call_time(instance: *runtime.Instance, label: DOMString) anyerror!void {
        
        return try consoleImpl.call_time(instance, label);
    }

    pub fn call_warn(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_warn(instance, data);
    }

    pub fn call_clear(instance: *runtime.Instance) anyerror!void {
        return try consoleImpl.call_clear(instance);
    }

    pub fn call_log(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_log(instance, data);
    }

    pub fn call_error(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_error(instance, data);
    }

    pub fn call_assert(instance: *runtime.Instance, condition: bool, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_assert(instance, condition, data);
    }

    pub fn call_table(instance: *runtime.Instance, tabularData: anyopaque, properties: anyopaque) anyerror!void {
        
        return try consoleImpl.call_table(instance, tabularData, properties);
    }

    pub fn call_debug(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_debug(instance, data);
    }

    pub fn call_dir(instance: *runtime.Instance, item: anyopaque, options: anyopaque) anyerror!void {
        
        return try consoleImpl.call_dir(instance, item, options);
    }

    pub fn call_dirxml(instance: *runtime.Instance, data: anyopaque) anyerror!void {
        
        return try consoleImpl.call_dirxml(instance, data);
    }

    pub fn call_countReset(instance: *runtime.Instance, label: DOMString) anyerror!void {
        
        return try consoleImpl.call_countReset(instance, label);
    }

};

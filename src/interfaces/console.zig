//! Generated from: console.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const consoleImpl = @import("../impls/console.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        consoleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        consoleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_info(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_info(state, data);
    }

    pub fn call_group(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_group(state, data);
    }

    pub fn call_groupCollapsed(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_groupCollapsed(state, data);
    }

    pub fn call_groupEnd(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return consoleImpl.call_groupEnd(state);
    }

    pub fn call_timeLog(instance: *runtime.Instance, label: runtime.DOMString, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_timeLog(state, label, data);
    }

    pub fn call_trace(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_trace(state, data);
    }

    pub fn call_timeEnd(instance: *runtime.Instance, label: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_timeEnd(state, label);
    }

    pub fn call_count(instance: *runtime.Instance, label: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_count(state, label);
    }

    pub fn call_time(instance: *runtime.Instance, label: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_time(state, label);
    }

    pub fn call_warn(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_warn(state, data);
    }

    pub fn call_clear(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return consoleImpl.call_clear(state);
    }

    pub fn call_log(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_log(state, data);
    }

    pub fn call_error(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_error(state, data);
    }

    pub fn call_assert(instance: *runtime.Instance, condition: bool, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_assert(state, condition, data);
    }

    pub fn call_table(instance: *runtime.Instance, tabularData: anyopaque, properties: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_table(state, tabularData, properties);
    }

    pub fn call_debug(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_debug(state, data);
    }

    pub fn call_dir(instance: *runtime.Instance, item: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_dir(state, item, options);
    }

    pub fn call_dirxml(instance: *runtime.Instance, data: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_dirxml(state, data);
    }

    pub fn call_countReset(instance: *runtime.Instance, label: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return consoleImpl.call_countReset(state, label);
    }

};

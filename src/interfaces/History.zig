//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HistoryImpl = @import("../impls/History.zig");

pub const History = struct {
    pub const Meta = struct {
        pub const name = "History";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            length: u32 = undefined,
            scrollRestoration: ScrollRestoration = undefined,
            state: anyopaque = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(History, .{
        .deinit_fn = &deinit_wrapper,

        .get_length = &get_length,
        .get_scrollRestoration = &get_scrollRestoration,
        .get_state = &get_state,

        .set_scrollRestoration = &set_scrollRestoration,

        .call_back = &call_back,
        .call_forward = &call_forward,
        .call_go = &call_go,
        .call_pushState = &call_pushState,
        .call_replaceState = &call_replaceState,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        HistoryImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        HistoryImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return HistoryImpl.get_length(state);
    }

    pub fn get_scrollRestoration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HistoryImpl.get_scrollRestoration(state);
    }

    pub fn set_scrollRestoration(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        HistoryImpl.set_scrollRestoration(state, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HistoryImpl.get_state(state);
    }

    pub fn call_forward(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HistoryImpl.call_forward(state);
    }

    pub fn call_pushState(instance: *runtime.Instance, data: anyopaque, unused: runtime.DOMString, url: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HistoryImpl.call_pushState(state, data, unused, url);
    }

    pub fn call_go(instance: *runtime.Instance, delta: i32) anyopaque {
        const state = instance.getState(State);
        
        return HistoryImpl.call_go(state, delta);
    }

    pub fn call_back(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return HistoryImpl.call_back(state);
    }

    pub fn call_replaceState(instance: *runtime.Instance, data: anyopaque, unused: runtime.DOMString, url: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return HistoryImpl.call_replaceState(state, data, unused, url);
    }

};

//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const HistoryImpl = @import("impls").History;
const ScrollRestoration = @import("enums").ScrollRestoration;
const USVString = @import("interfaces").USVString;

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
        
        // Initialize the instance (Impl receives full instance)
        HistoryImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HistoryImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
        return try HistoryImpl.get_length(instance);
    }

    pub fn get_scrollRestoration(instance: *runtime.Instance) anyerror!ScrollRestoration {
        return try HistoryImpl.get_scrollRestoration(instance);
    }

    pub fn set_scrollRestoration(instance: *runtime.Instance, value: ScrollRestoration) anyerror!void {
        try HistoryImpl.set_scrollRestoration(instance, value);
    }

    pub fn get_state(instance: *runtime.Instance) anyerror!anyopaque {
        return try HistoryImpl.get_state(instance);
    }

    pub fn call_forward(instance: *runtime.Instance) anyerror!void {
        return try HistoryImpl.call_forward(instance);
    }

    pub fn call_pushState(instance: *runtime.Instance, data: anyopaque, unused: DOMString, url: anyopaque) anyerror!void {
        
        return try HistoryImpl.call_pushState(instance, data, unused, url);
    }

    pub fn call_go(instance: *runtime.Instance, delta: i32) anyerror!void {
        
        return try HistoryImpl.call_go(instance, delta);
    }

    pub fn call_back(instance: *runtime.Instance) anyerror!void {
        return try HistoryImpl.call_back(instance);
    }

    pub fn call_replaceState(instance: *runtime.Instance, data: anyopaque, unused: DOMString, url: anyopaque) anyerror!void {
        
        return try HistoryImpl.call_replaceState(instance, data, unused, url);
    }

};

//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasTextImpl = @import("../impls/CanvasText.zig");

pub const CanvasText = struct {
    pub const Meta = struct {
        pub const name = "CanvasText";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasText, .{
        .deinit_fn = &deinit_wrapper,

        .call_fillText = &call_fillText,
        .call_measureText = &call_measureText,
        .call_strokeText = &call_strokeText,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasTextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasTextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_strokeText(instance: *runtime.Instance, text: runtime.DOMString, x: f64, y: f64, maxWidth: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTextImpl.call_strokeText(state, text, x, y, maxWidth);
    }

    pub fn call_fillText(instance: *runtime.Instance, text: runtime.DOMString, x: f64, y: f64, maxWidth: f64) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTextImpl.call_fillText(state, text, x, y, maxWidth);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return CanvasTextImpl.call_measureText(state, text);
    }

};

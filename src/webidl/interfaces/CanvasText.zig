//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasTextImpl = @import("impls").CanvasText;
const TextMetrics = @import("interfaces").TextMetrics;

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
        
        // Initialize the instance (Impl receives full instance)
        CanvasTextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasTextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_strokeText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: f64) anyerror!void {
        
        return try CanvasTextImpl.call_strokeText(instance, text, x, y, maxWidth);
    }

    pub fn call_fillText(instance: *runtime.Instance, text: DOMString, x: f64, y: f64, maxWidth: f64) anyerror!void {
        
        return try CanvasTextImpl.call_fillText(instance, text, x, y, maxWidth);
    }

    pub fn call_measureText(instance: *runtime.Instance, text: DOMString) anyerror!TextMetrics {
        
        return try CanvasTextImpl.call_measureText(instance, text);
    }

};

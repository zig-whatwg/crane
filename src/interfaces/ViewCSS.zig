//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewCSSImpl = @import("../impls/ViewCSS.zig");
const AbstractView = @import("AbstractView.zig");

pub const ViewCSS = struct {
    pub const Meta = struct {
        pub const name = "ViewCSS";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *AbstractView;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(ViewCSS, .{
        .deinit_fn = &deinit_wrapper,

        .call_getComputedStyle = &call_getComputedStyle,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        ViewCSSImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        ViewCSSImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getComputedStyle(instance: *runtime.Instance, elt: anyopaque, pseudoElt: runtime.DOMString) anyopaque {
        const state = instance.getState(State);
        
        return ViewCSSImpl.call_getComputedStyle(state, elt, pseudoElt);
    }

};

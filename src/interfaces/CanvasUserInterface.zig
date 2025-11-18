//! Generated from: html.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasUserInterfaceImpl = @import("../impls/CanvasUserInterface.zig");

pub const CanvasUserInterface = struct {
    pub const Meta = struct {
        pub const name = "CanvasUserInterface";
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

    pub const vtable = runtime.buildVTable(CanvasUserInterface, .{
        .deinit_fn = &deinit_wrapper,

        .call_drawFocusIfNeeded = &call_drawFocusIfNeeded,
        .call_drawFocusIfNeeded = &call_drawFocusIfNeeded,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        CanvasUserInterfaceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasUserInterfaceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for drawFocusIfNeeded (WebIDL overloading)
    pub const DrawFocusIfNeededArgs = union(enum) {
        /// drawFocusIfNeeded(element)
        Element: anyopaque,
        /// drawFocusIfNeeded(path, element)
        Path2D_Element: struct {
            path: anyopaque,
            element: anyopaque,
        },
    };

    pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, args: DrawFocusIfNeededArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .Element => |arg| return CanvasUserInterfaceImpl.Element(state, arg),
            .Path2D_Element => |a| return CanvasUserInterfaceImpl.Path2D_Element(state, a.path, a.element),
        }
    }

};

//! Generated from: html.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasUserInterfaceImpl = @import("impls").CanvasUserInterface;
const Element = @import("interfaces").Element;
const Path2D = @import("interfaces").Path2D;

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CanvasUserInterfaceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasUserInterfaceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Arguments for drawFocusIfNeeded (WebIDL overloading)
    pub const DrawFocusIfNeededArgs = union(enum) {
        /// drawFocusIfNeeded(element)
        Element: Element,
        /// drawFocusIfNeeded(path, element)
        Path2D_Element: struct {
            path: Path2D,
            element: Element,
        },
    };

    pub fn call_drawFocusIfNeeded(instance: *runtime.Instance, args: DrawFocusIfNeededArgs) anyerror!void {
        switch (args) {
            .Element => |arg| return try CanvasUserInterfaceImpl.Element(instance, arg),
            .Path2D_Element => |a| return try CanvasUserInterfaceImpl.Path2D_Element(instance, a.path, a.element),
        }
    }

};

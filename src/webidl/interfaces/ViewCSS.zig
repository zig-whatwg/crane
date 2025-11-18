//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewCSSImpl = @import("impls").ViewCSS;
const AbstractView = @import("interfaces").AbstractView;
const Element = @import("interfaces").Element;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;

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
        
        // Initialize the instance (Impl receives full instance)
        ViewCSSImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ViewCSSImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getComputedStyle(instance: *runtime.Instance, elt: Element, pseudoElt: DOMString) anyerror!CSSStyleDeclaration {
        
        return try ViewCSSImpl.call_getComputedStyle(instance, elt, pseudoElt);
    }

};

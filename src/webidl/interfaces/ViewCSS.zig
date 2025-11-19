//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-19T20:02:02Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ViewCSSImpl = @import("impls").ViewCSS;
const AbstractView = @import("interfaces").AbstractView;
const Element = @import("interfaces").Element;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const DOMString = @import("typedefs").DOMString;

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
        return ViewCSSImpl.init(allocator, State, &vtable);
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

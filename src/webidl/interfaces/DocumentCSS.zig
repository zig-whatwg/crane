//! Generated from: DOM-Style.idl
//! Generated at: 2025-11-19T20:02:01Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const DocumentCSSImpl = @import("impls").DocumentCSS;
const DocumentStyle = @import("interfaces").DocumentStyle;
const Element = @import("interfaces").Element;
const StyleSheetList = @import("interfaces").StyleSheetList;
const CSSStyleDeclaration = @import("interfaces").CSSStyleDeclaration;
const DOMString = @import("typedefs").DOMString;

pub const DocumentCSS = struct {
    pub const Meta = struct {
        pub const name = "DocumentCSS";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *DocumentStyle;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(DocumentCSS, .{
        .deinit_fn = &deinit_wrapper,

        .get_styleSheets = &get_styleSheets,

        .call_getOverrideStyle = &call_getOverrideStyle,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        return DocumentCSSImpl.init(allocator, State, &vtable);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DocumentCSSImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_styleSheets(instance: *runtime.Instance) anyerror!StyleSheetList {
        return try DocumentCSSImpl.get_styleSheets(instance);
    }

    pub fn call_getOverrideStyle(instance: *runtime.Instance, elt: Element, pseudoElt: DOMString) anyerror!CSSStyleDeclaration {
        
        return try DocumentCSSImpl.call_getOverrideStyle(instance, elt, pseudoElt);
    }

};

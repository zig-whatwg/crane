//! Generated from: css-pseudo.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPseudoElementImpl = @import("impls").CSSPseudoElement;
const EventTarget = @import("interfaces").EventTarget;
const GeometryUtils = @import("interfaces").GeometryUtils;
const CSSOMString = @import("interfaces").CSSOMString;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const DOMPoint = @import("interfaces").DOMPoint;
const Element = @import("interfaces").Element;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const (Element or CSSPseudoElement) = @import("interfaces").(Element or CSSPseudoElement);
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;

pub const CSSPseudoElement = struct {
    pub const Meta = struct {
        pub const name = "CSSPseudoElement";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{
            GeometryUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            type: CSSOMString = undefined,
            element: Element = undefined,
            parent: (Element or CSSPseudoElement) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CSSPseudoElement, .{
        .deinit_fn = &deinit_wrapper,

        .get_element = &get_element,
        .get_parent = &get_parent,
        .get_type = &get_type,

        .call_addEventListener = &call_addEventListener,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_pseudo = &call_pseudo,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        CSSPseudoElementImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPseudoElementImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPseudoElementImpl.get_type(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!Element {
        return try CSSPseudoElementImpl.get_element(instance);
    }

    pub fn get_parent(instance: *runtime.Instance) anyerror!anyopaque {
        return try CSSPseudoElementImpl.get_parent(instance);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: DOMRectReadOnly, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try CSSPseudoElementImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try CSSPseudoElementImpl.call_when(instance, type_, options);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: BoxQuadOptions) anyerror!anyopaque {
        
        return try CSSPseudoElementImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_pseudo(instance: *runtime.Instance, type_: anyopaque) anyerror!anyopaque {
        
        return try CSSPseudoElementImpl.call_pseudo(instance, type_);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try CSSPseudoElementImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try CSSPseudoElementImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMPoint {
        
        return try CSSPseudoElementImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CSSPseudoElementImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try CSSPseudoElementImpl.call_removeEventListener(instance, type_, callback, options);
    }

};

//! Generated from: css-pseudo.idl
//! Generated at: 2025-11-25T14:21:39Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CSSPseudoElementImpl = @import("impls").CSSPseudoElement;
const EventTarget = @import("interfaces").EventTarget;
const GeometryUtils = @import("interfaces").GeometryUtils;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const CSSOMString = @import("typedefs").CSSOMString;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const Element = @import("interfaces").Element;
const Event = @import("interfaces").Event;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;

pub const CSSPseudoElement = struct {
    pub const Meta = struct {
        pub const name = "CSSPseudoElement";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{
            GeometryUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "element", "get_element", null },
            .{ "parent", "get_parent", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "pseudo", "call_pseudo", 1 },
            .{ "getBoxQuads", "call_getBoxQuads", 0 },
            .{ "convertQuadFromNode", "call_convertQuadFromNode", 2 },
            .{ "convertRectFromNode", "call_convertRectFromNode", 2 },
            .{ "convertPointFromNode", "call_convertPointFromNode", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "pseudo",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "type", "get_type", null },
            .{ "element", "get_element", null },
            .{ "parent", "get_parent", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            @"type": CSSOMString = undefined,
            element: *runtime.Instance = undefined,
            parent: union(enum) {
                Element: Element,
                CSSPseudoElement: CSSPseudoElement,
            } = undefined,
            _internal: ?*CSSPseudoElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_element = &get_element,
        .get_parent = &get_parent,
        .get_type = &get_type,

        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_pseudo = &call_pseudo,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CSSPseudoElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CSSPseudoElementImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!CSSOMString {
        return try CSSPseudoElementImpl.get_type(instance);
    }

    pub fn get_element(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CSSPseudoElementImpl.get_element(instance);
    }

    pub fn get_parent(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try CSSPseudoElementImpl.get_parent(instance);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!*runtime.Instance {
        
        return try CSSPseudoElementImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!*runtime.Instance {
        
        return try CSSPseudoElementImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_pseudo(instance: *runtime.Instance, @"type": CSSOMString) anyerror!?*runtime.Instance {
        
        return try CSSPseudoElementImpl.call_pseudo(instance, @"type");
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: BoxQuadOptions) anyerror!*const anyopaque {
        
        return try CSSPseudoElementImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!*runtime.Instance {
        
        return try CSSPseudoElementImpl.call_convertRectFromNode(instance, rect, from, options);
    }

};

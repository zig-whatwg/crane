//! Generated from: dom.idl
//! Generated at: 2025-11-28T22:33:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextImpl = @import("impls").Text;
const mixins = @import("mixins");
const CharacterData = @import("interfaces").CharacterData;
const Slottable = @import("interfaces").Slottable;
const GeometryUtils = @import("interfaces").GeometryUtils;
const Document = @import("interfaces").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const USVString = @import("interfaces").USVString;
const Element = @import("interfaces").Element;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const Node = @import("interfaces").Node;
const NodeList = @import("interfaces").NodeList;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const Event = @import("interfaces").Event;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const Text = struct {
    pub const Meta = struct {
        pub const name = "Text";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *CharacterData;
        pub const MixinTypes = &.{
            Slottable,
            GeometryUtils,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "wholeText", "get_wholeText", null },
            .{ "assignedSlot", "get_assignedSlot", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "splitText", "call_splitText", 1 },
            .{ "getBoxQuads", "call_getBoxQuads", 0 },
            .{ "convertQuadFromNode", "call_convertQuadFromNode", 2 },
            .{ "convertRectFromNode", "call_convertRectFromNode", 2 },
            .{ "convertPointFromNode", "call_convertPointFromNode", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "splitText",
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
            "getRootNode",
            "hasChildNodes",
            "normalize",
            "cloneNode",
            "isEqualNode",
            "isSameNode",
            "compareDocumentPosition",
            "contains",
            "lookupPrefix",
            "lookupNamespaceURI",
            "isDefaultNamespace",
            "insertBefore",
            "appendChild",
            "replaceChild",
            "removeChild",
            "substringData",
            "appendData",
            "insertData",
            "deleteData",
            "replaceData",
            "before",
            "after",
            "replaceWith",
            "remove",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "wholeText", "get_wholeText", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
            .{ "assignedSlot", "get_assignedSlot", null },
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            wholeText: runtime.DOMString = undefined,
            assignedSlot: ?*runtime.Instance = null,
            _internal: ?*TextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_assignedSlot = &get_assignedSlot,
        .get_wholeText = &get_wholeText,

        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_splitText = &call_splitText,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, data: webidl.Opt(DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextImpl.call_constructor(allocator, ctx, data);
    }

    pub fn get_wholeText(instance: *runtime.Instance) anyerror!DOMString {
        return try TextImpl.get_wholeText(instance);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextImpl.get_assignedSlot(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_splitText(instance: *runtime.Instance, offset: u32) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try TextImpl.call_splitText(instance, offset);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try TextImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try TextImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(BoxQuadOptions)) anyerror!*const anyopaque {
        
        return try TextImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try TextImpl.call_convertRectFromNode(instance, rect, from, options);
    }

};

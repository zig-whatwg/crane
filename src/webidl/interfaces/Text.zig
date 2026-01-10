//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const TextImpl = @import("impls").Text;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const CharacterData = @import("CharacterData.zig").CharacterData;
const Slottable = @import("mixins").Slottable;
const GeometryUtils = @import("mixins").GeometryUtils;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const USVString = @import("typedefs").USVString;
const Element = @import("Element.zig").Element;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const Node = @import("Node.zig").Node;
const NodeList = @import("NodeList.zig").NodeList;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const Event = @import("Event.zig").Event;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const DOMString = @import("typedefs").DOMString;

pub const Text = struct {
    pub const Meta = struct {
        pub const name = "Text";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = CharacterData.State;
        pub const ParentInterface = CharacterData;
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
            .{ "assignedSlot", "get_assignedSlot", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            wholeText: typedefs.DOMString = undefined,
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

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return TextImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context, data: webidl.Opt(DOMString)) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextImpl.call_constructor(ctx, data);
    }

    pub fn get_wholeText(instance: *runtime.Instance) anyerror!DOMString {
        return try TextImpl.get_wholeText(instance);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try TextImpl.get_assignedSlot(instance);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try TextImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try TextImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_splitText(instance: *runtime.Instance, offset: u32) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try TextImpl.call_splitText(instance, offset);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(BoxQuadOptions)) anyerror!runtime.JSValue {
        
        return try TextImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try TextImpl.call_convertPointFromNode(instance, point, from, options);
    }

};

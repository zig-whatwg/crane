//! Generated from: html.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const HTMLSlotElementImpl = @import("impls").HTMLSlotElement;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const HTMLElement = @import("HTMLElement.zig").HTMLElement;
const AssignedNodesOptions = @import("dictionaries").AssignedNodesOptions;
const DOMStringMap = @import("DOMStringMap.zig").DOMStringMap;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const TogglePopoverOptions = @import("dictionaries").TogglePopoverOptions;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Text = @import("Text.zig").Text;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("NamedNodeMap.zig").NamedNodeMap;
const CSSStyleDeclaration = @import("CSSStyleDeclaration.zig").CSSStyleDeclaration;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const Element = @import("Element.zig").Element;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListener = @import("EventListener.zig").EventListener;
const CSSStyleProperties = @import("CSSStyleProperties.zig").CSSStyleProperties;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const ShowPopoverOptions = @import("dictionaries").ShowPopoverOptions;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const FocusOptions = @import("dictionaries").FocusOptions;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const Document = @import("Document.zig").Document;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const EditContext = @import("EditContext.zig").EditContext;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ElementInternals = @import("ElementInternals.zig").ElementInternals;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const StylePropertyMap = @import("StylePropertyMap.zig").StylePropertyMap;
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("NodeList.zig").NodeList;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const HTMLSlotElement = struct {
    pub const Meta = struct {
        pub const name = "HTMLSlotElement";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = HTMLElement.State;
        pub const ParentInterface = HTMLElement;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "name", "get_name", "set_name" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "assignedNodes", "call_assignedNodes", 0 },
            .{ "assignedElements", "call_assignedElements", 0 },
            .{ "assign", "call_assign", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "assignedNodes",
            "assignedElements",
            "assign",
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
            "hasAttributes",
            "getAttributeNames",
            "getAttribute",
            "getAttributeNS",
            "setAttribute",
            "setAttributeNS",
            "removeAttribute",
            "removeAttributeNS",
            "toggleAttribute",
            "hasAttribute",
            "hasAttributeNS",
            "getAttributeNode",
            "getAttributeNodeNS",
            "setAttributeNode",
            "setAttributeNodeNS",
            "removeAttributeNode",
            "attachShadow",
            "closest",
            "matches",
            "webkitMatchesSelector",
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "insertAdjacentElement",
            "insertAdjacentText",
            "getSpatialNavigationContainer",
            "focusableAreas",
            "spatialNavigationSearch",
            "requestFullscreen",
            "requestPointerLock",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "computedStyleMap",
            "pseudo",
            "startViewTransition",
            "setHTMLUnsafe",
            "getHTML",
            "insertAdjacentHTML",
            "getClientRects",
            "getBoundingClientRect",
            "checkVisibility",
            "scrollIntoView",
            "scroll",
            "scroll",
            "scrollTo",
            "scrollTo",
            "scrollBy",
            "scrollBy",
            "animate",
            "getAnimations",
            "getRegionFlowRanges",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "before",
            "after",
            "replaceWith",
            "remove",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "click",
            "attachInternals",
            "showPopover",
            "hidePopover",
            "togglePopover",
            "focus",
            "blur",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "name", "get_name", "set_name" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            name: typedefs.DOMString = undefined,
            _internal: ?*HTMLSlotElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_name = &get_name,

        .set_name = &set_name,

        .call_assign = &call_assign,
        .call_assignedElements = &call_assignedElements,
        .call_assignedNodes = &call_assignedNodes,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return HTMLSlotElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return HTMLSlotElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        HTMLSlotElementImpl.deinit(instance);
    }

    /// WebIDL constructor
    /// Note: Uses ctx.allocator internally for all allocations to ensure
    /// consistency with deinit which uses instance.ctx.allocator
    pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try HTMLSlotElementImpl.call_constructor(ctx);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try HTMLSlotElementImpl.get_name(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_name(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try HTMLSlotElementImpl.set_name(instance, value);
    }

    pub fn call_assign(instance: *runtime.Instance, nodes: []const runtime.JSValue) anyerror!void {
        
        return try HTMLSlotElementImpl.call_assign(instance, nodes);
    }

    pub fn call_assignedElements(instance: *runtime.Instance, options: webidl.Opt(AssignedNodesOptions)) anyerror!runtime.JSValue {
        
        return try HTMLSlotElementImpl.call_assignedElements(instance, options);
    }

    pub fn call_assignedNodes(instance: *runtime.Instance, options: webidl.Opt(AssignedNodesOptions)) anyerror!runtime.JSValue {
        
        return try HTMLSlotElementImpl.call_assignedNodes(instance, options);
    }

};

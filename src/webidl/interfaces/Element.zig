//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ElementImpl = @import("impls").Element;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Node = @import("Node.zig").Node;
const ARIAMixin = @import("mixins").ARIAMixin;
const Animatable = @import("mixins").Animatable;
const Region = @import("mixins").Region;
const ParentNode = @import("mixins").ParentNode;
const NonDocumentTypeChildNode = @import("mixins").NonDocumentTypeChildNode;
const ChildNode = @import("mixins").ChildNode;
const Slottable = @import("mixins").Slottable;
const GeometryUtils = @import("mixins").GeometryUtils;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("NamedNodeMap.zig").NamedNodeMap;
const USVString = @import("typedefs").USVString;
const TrustedType = @import("typedefs").TrustedType;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const ScrollIntoViewOptions = @import("dictionaries").ScrollIntoViewOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const CSSPseudoElement = @import("CSSPseudoElement.zig").CSSPseudoElement;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Animation = @import("Animation.zig").Animation;
const Range = @import("Range.zig").Range;
const Event = @import("Event.zig").Event;
const DOMRectList = @import("DOMRectList.zig").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const KeyframeAnimationOptions = @import("dictionaries").KeyframeAnimationOptions;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const Document = @import("Document.zig").Document;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("HTMLSlotElement.zig").HTMLSlotElement;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const DOMTokenList = @import("DOMTokenList.zig").DOMTokenList;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const DOMRect = @import("DOMRect.zig").DOMRect;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const ShadowRoot = @import("ShadowRoot.zig").ShadowRoot;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const NodeList = @import("NodeList.zig").NodeList;
const Observable = @import("Observable.zig").Observable;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const Element = struct {
    pub const Meta = struct {
        pub const name = "Element";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
            ARIAMixin,
            Animatable,
            Region,
            ParentNode,
            NonDocumentTypeChildNode,
            ChildNode,
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
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
            .{ "localName", "get_localName", null },
            .{ "tagName", "get_tagName", null },
            .{ "id", "get_id", "set_id" },
            .{ "className", "get_className", "set_className" },
            .{ "classList", "get_classList", "set_classList" },
            .{ "slot", "get_slot", "set_slot" },
            .{ "attributes", "get_attributes", null },
            .{ "shadowRoot", "get_shadowRoot", null },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "onfullscreenchange", "get_onfullscreenchange", "set_onfullscreenchange" },
            .{ "onfullscreenerror", "get_onfullscreenerror", "set_onfullscreenerror" },
            .{ "elementTiming", "get_elementTiming", "set_elementTiming" },
            .{ "part", "get_part", "set_part" },
            .{ "activeViewTransition", "get_activeViewTransition", null },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "outerHTML", "get_outerHTML", "set_outerHTML" },
            .{ "scrollTop", "get_scrollTop", "set_scrollTop" },
            .{ "scrollLeft", "get_scrollLeft", "set_scrollLeft" },
            .{ "scrollWidth", "get_scrollWidth", null },
            .{ "scrollHeight", "get_scrollHeight", null },
            .{ "clientTop", "get_clientTop", null },
            .{ "clientLeft", "get_clientLeft", null },
            .{ "clientWidth", "get_clientWidth", null },
            .{ "clientHeight", "get_clientHeight", null },
            .{ "currentCSSZoom", "get_currentCSSZoom", null },
            .{ "role", "get_role", "set_role" },
            .{ "ariaActiveDescendantElement", "get_ariaActiveDescendantElement", "set_ariaActiveDescendantElement" },
            .{ "ariaAtomic", "get_ariaAtomic", "set_ariaAtomic" },
            .{ "ariaAutoComplete", "get_ariaAutoComplete", "set_ariaAutoComplete" },
            .{ "ariaBrailleLabel", "get_ariaBrailleLabel", "set_ariaBrailleLabel" },
            .{ "ariaBrailleRoleDescription", "get_ariaBrailleRoleDescription", "set_ariaBrailleRoleDescription" },
            .{ "ariaBusy", "get_ariaBusy", "set_ariaBusy" },
            .{ "ariaChecked", "get_ariaChecked", "set_ariaChecked" },
            .{ "ariaColCount", "get_ariaColCount", "set_ariaColCount" },
            .{ "ariaColIndex", "get_ariaColIndex", "set_ariaColIndex" },
            .{ "ariaColIndexText", "get_ariaColIndexText", "set_ariaColIndexText" },
            .{ "ariaColSpan", "get_ariaColSpan", "set_ariaColSpan" },
            .{ "ariaControlsElements", "get_ariaControlsElements", "set_ariaControlsElements" },
            .{ "ariaCurrent", "get_ariaCurrent", "set_ariaCurrent" },
            .{ "ariaDescribedByElements", "get_ariaDescribedByElements", "set_ariaDescribedByElements" },
            .{ "ariaDescription", "get_ariaDescription", "set_ariaDescription" },
            .{ "ariaDetailsElements", "get_ariaDetailsElements", "set_ariaDetailsElements" },
            .{ "ariaDisabled", "get_ariaDisabled", "set_ariaDisabled" },
            .{ "ariaErrorMessageElements", "get_ariaErrorMessageElements", "set_ariaErrorMessageElements" },
            .{ "ariaExpanded", "get_ariaExpanded", "set_ariaExpanded" },
            .{ "ariaFlowToElements", "get_ariaFlowToElements", "set_ariaFlowToElements" },
            .{ "ariaHasPopup", "get_ariaHasPopup", "set_ariaHasPopup" },
            .{ "ariaHidden", "get_ariaHidden", "set_ariaHidden" },
            .{ "ariaInvalid", "get_ariaInvalid", "set_ariaInvalid" },
            .{ "ariaKeyShortcuts", "get_ariaKeyShortcuts", "set_ariaKeyShortcuts" },
            .{ "ariaLabel", "get_ariaLabel", "set_ariaLabel" },
            .{ "ariaLabelledByElements", "get_ariaLabelledByElements", "set_ariaLabelledByElements" },
            .{ "ariaLevel", "get_ariaLevel", "set_ariaLevel" },
            .{ "ariaLive", "get_ariaLive", "set_ariaLive" },
            .{ "ariaModal", "get_ariaModal", "set_ariaModal" },
            .{ "ariaMultiLine", "get_ariaMultiLine", "set_ariaMultiLine" },
            .{ "ariaMultiSelectable", "get_ariaMultiSelectable", "set_ariaMultiSelectable" },
            .{ "ariaOrientation", "get_ariaOrientation", "set_ariaOrientation" },
            .{ "ariaOwnsElements", "get_ariaOwnsElements", "set_ariaOwnsElements" },
            .{ "ariaPlaceholder", "get_ariaPlaceholder", "set_ariaPlaceholder" },
            .{ "ariaPosInSet", "get_ariaPosInSet", "set_ariaPosInSet" },
            .{ "ariaPressed", "get_ariaPressed", "set_ariaPressed" },
            .{ "ariaReadOnly", "get_ariaReadOnly", "set_ariaReadOnly" },
            .{ "ariaRelevant", "get_ariaRelevant", "set_ariaRelevant" },
            .{ "ariaRequired", "get_ariaRequired", "set_ariaRequired" },
            .{ "ariaRoleDescription", "get_ariaRoleDescription", "set_ariaRoleDescription" },
            .{ "ariaRowCount", "get_ariaRowCount", "set_ariaRowCount" },
            .{ "ariaRowIndex", "get_ariaRowIndex", "set_ariaRowIndex" },
            .{ "ariaRowIndexText", "get_ariaRowIndexText", "set_ariaRowIndexText" },
            .{ "ariaRowSpan", "get_ariaRowSpan", "set_ariaRowSpan" },
            .{ "ariaSelected", "get_ariaSelected", "set_ariaSelected" },
            .{ "ariaSetSize", "get_ariaSetSize", "set_ariaSetSize" },
            .{ "ariaSort", "get_ariaSort", "set_ariaSort" },
            .{ "ariaValueMax", "get_ariaValueMax", "set_ariaValueMax" },
            .{ "ariaValueMin", "get_ariaValueMin", "set_ariaValueMin" },
            .{ "ariaValueNow", "get_ariaValueNow", "set_ariaValueNow" },
            .{ "ariaValueText", "get_ariaValueText", "set_ariaValueText" },
            .{ "regionOverset", "get_regionOverset", null },
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
            .{ "assignedSlot", "get_assignedSlot", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "hasAttributes", "call_hasAttributes", 0 },
            .{ "getAttributeNames", "call_getAttributeNames", 0 },
            .{ "getAttribute", "call_getAttribute", 1 },
            .{ "getAttributeNS", "call_getAttributeNS", 2 },
            .{ "setAttribute", "call_setAttribute", 2 },
            .{ "setAttributeNS", "call_setAttributeNS", 3 },
            .{ "removeAttribute", "call_removeAttribute", 1 },
            .{ "removeAttributeNS", "call_removeAttributeNS", 2 },
            .{ "toggleAttribute", "call_toggleAttribute", 1 },
            .{ "hasAttribute", "call_hasAttribute", 1 },
            .{ "hasAttributeNS", "call_hasAttributeNS", 2 },
            .{ "getAttributeNode", "call_getAttributeNode", 1 },
            .{ "getAttributeNodeNS", "call_getAttributeNodeNS", 2 },
            .{ "setAttributeNode", "call_setAttributeNode", 1 },
            .{ "setAttributeNodeNS", "call_setAttributeNodeNS", 1 },
            .{ "removeAttributeNode", "call_removeAttributeNode", 1 },
            .{ "attachShadow", "call_attachShadow", 1 },
            .{ "closest", "call_closest", 1 },
            .{ "matches", "call_matches", 1 },
            .{ "webkitMatchesSelector", "call_webkitMatchesSelector", 1 },
            .{ "getElementsByTagName", "call_getElementsByTagName", 1 },
            .{ "getElementsByTagNameNS", "call_getElementsByTagNameNS", 2 },
            .{ "getElementsByClassName", "call_getElementsByClassName", 1 },
            .{ "insertAdjacentElement", "call_insertAdjacentElement", 2 },
            .{ "insertAdjacentText", "call_insertAdjacentText", 2 },
            .{ "getSpatialNavigationContainer", "call_getSpatialNavigationContainer", 0 },
            .{ "focusableAreas", "call_focusableAreas", 0 },
            .{ "spatialNavigationSearch", "call_spatialNavigationSearch", 1 },
            .{ "requestFullscreen", "call_requestFullscreen", 0 },
            .{ "requestPointerLock", "call_requestPointerLock", 0 },
            .{ "setPointerCapture", "call_setPointerCapture", 1 },
            .{ "releasePointerCapture", "call_releasePointerCapture", 1 },
            .{ "hasPointerCapture", "call_hasPointerCapture", 1 },
            .{ "computedStyleMap", "call_computedStyleMap", 0 },
            .{ "pseudo", "call_pseudo", 1 },
            .{ "startViewTransition", "call_startViewTransition", 0 },
            .{ "setHTMLUnsafe", "call_setHTMLUnsafe", 1 },
            .{ "getHTML", "call_getHTML", 0 },
            .{ "insertAdjacentHTML", "call_insertAdjacentHTML", 2 },
            .{ "getClientRects", "call_getClientRects", 0 },
            .{ "getBoundingClientRect", "call_getBoundingClientRect", 0 },
            .{ "checkVisibility", "call_checkVisibility", 0 },
            .{ "scrollIntoView", "call_scrollIntoView", 0 },
            .{ "scroll", "call_scroll", 0 },
            .{ "scrollTo", "call_scrollTo", 0 },
            .{ "scrollBy", "call_scrollBy", 0 },
            .{ "animate", "call_animate", 1 },
            .{ "getAnimations", "call_getAnimations", 0 },
            .{ "getRegionFlowRanges", "call_getRegionFlowRanges", 0 },
            .{ "prepend", "call_prepend", 0 },
            .{ "append", "call_append", 0 },
            .{ "replaceChildren", "call_replaceChildren", 0 },
            .{ "moveBefore", "call_moveBefore", 2 },
            .{ "querySelector", "call_querySelector", 1 },
            .{ "querySelectorAll", "call_querySelectorAll", 1 },
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replaceWith", "call_replaceWith", 0 },
            .{ "remove", "call_remove", 0 },
            .{ "getBoxQuads", "call_getBoxQuads", 0 },
            .{ "convertQuadFromNode", "call_convertQuadFromNode", 2 },
            .{ "convertRectFromNode", "call_convertRectFromNode", 2 },
            .{ "convertPointFromNode", "call_convertPointFromNode", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            "scrollTo",
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
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "namespaceURI", "get_namespaceURI", null },
            .{ "prefix", "get_prefix", null },
            .{ "localName", "get_localName", null },
            .{ "tagName", "get_tagName", null },
            .{ "id", "get_id", "set_id" },
            .{ "className", "get_className", "set_className" },
            .{ "classList", "get_classList", "set_classList" },
            .{ "slot", "get_slot", "set_slot" },
            .{ "attributes", "get_attributes", null },
            .{ "shadowRoot", "get_shadowRoot", null },
            .{ "customElementRegistry", "get_customElementRegistry", null },
            .{ "onfullscreenchange", "get_onfullscreenchange", "set_onfullscreenchange" },
            .{ "onfullscreenerror", "get_onfullscreenerror", "set_onfullscreenerror" },
            .{ "elementTiming", "get_elementTiming", "set_elementTiming" },
            .{ "part", "get_part", "set_part" },
            .{ "activeViewTransition", "get_activeViewTransition", null },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "outerHTML", "get_outerHTML", "set_outerHTML" },
            .{ "scrollTop", "get_scrollTop", "set_scrollTop" },
            .{ "scrollLeft", "get_scrollLeft", "set_scrollLeft" },
            .{ "scrollWidth", "get_scrollWidth", null },
            .{ "scrollHeight", "get_scrollHeight", null },
            .{ "clientTop", "get_clientTop", null },
            .{ "clientLeft", "get_clientLeft", null },
            .{ "clientWidth", "get_clientWidth", null },
            .{ "clientHeight", "get_clientHeight", null },
            .{ "currentCSSZoom", "get_currentCSSZoom", null },
            .{ "role", "get_role", "set_role" },
            .{ "ariaActiveDescendantElement", "get_ariaActiveDescendantElement", "set_ariaActiveDescendantElement" },
            .{ "ariaAtomic", "get_ariaAtomic", "set_ariaAtomic" },
            .{ "ariaAutoComplete", "get_ariaAutoComplete", "set_ariaAutoComplete" },
            .{ "ariaBrailleLabel", "get_ariaBrailleLabel", "set_ariaBrailleLabel" },
            .{ "ariaBrailleRoleDescription", "get_ariaBrailleRoleDescription", "set_ariaBrailleRoleDescription" },
            .{ "ariaBusy", "get_ariaBusy", "set_ariaBusy" },
            .{ "ariaChecked", "get_ariaChecked", "set_ariaChecked" },
            .{ "ariaColCount", "get_ariaColCount", "set_ariaColCount" },
            .{ "ariaColIndex", "get_ariaColIndex", "set_ariaColIndex" },
            .{ "ariaColIndexText", "get_ariaColIndexText", "set_ariaColIndexText" },
            .{ "ariaColSpan", "get_ariaColSpan", "set_ariaColSpan" },
            .{ "ariaControlsElements", "get_ariaControlsElements", "set_ariaControlsElements" },
            .{ "ariaCurrent", "get_ariaCurrent", "set_ariaCurrent" },
            .{ "ariaDescribedByElements", "get_ariaDescribedByElements", "set_ariaDescribedByElements" },
            .{ "ariaDescription", "get_ariaDescription", "set_ariaDescription" },
            .{ "ariaDetailsElements", "get_ariaDetailsElements", "set_ariaDetailsElements" },
            .{ "ariaDisabled", "get_ariaDisabled", "set_ariaDisabled" },
            .{ "ariaErrorMessageElements", "get_ariaErrorMessageElements", "set_ariaErrorMessageElements" },
            .{ "ariaExpanded", "get_ariaExpanded", "set_ariaExpanded" },
            .{ "ariaFlowToElements", "get_ariaFlowToElements", "set_ariaFlowToElements" },
            .{ "ariaHasPopup", "get_ariaHasPopup", "set_ariaHasPopup" },
            .{ "ariaHidden", "get_ariaHidden", "set_ariaHidden" },
            .{ "ariaInvalid", "get_ariaInvalid", "set_ariaInvalid" },
            .{ "ariaKeyShortcuts", "get_ariaKeyShortcuts", "set_ariaKeyShortcuts" },
            .{ "ariaLabel", "get_ariaLabel", "set_ariaLabel" },
            .{ "ariaLabelledByElements", "get_ariaLabelledByElements", "set_ariaLabelledByElements" },
            .{ "ariaLevel", "get_ariaLevel", "set_ariaLevel" },
            .{ "ariaLive", "get_ariaLive", "set_ariaLive" },
            .{ "ariaModal", "get_ariaModal", "set_ariaModal" },
            .{ "ariaMultiLine", "get_ariaMultiLine", "set_ariaMultiLine" },
            .{ "ariaMultiSelectable", "get_ariaMultiSelectable", "set_ariaMultiSelectable" },
            .{ "ariaOrientation", "get_ariaOrientation", "set_ariaOrientation" },
            .{ "ariaOwnsElements", "get_ariaOwnsElements", "set_ariaOwnsElements" },
            .{ "ariaPlaceholder", "get_ariaPlaceholder", "set_ariaPlaceholder" },
            .{ "ariaPosInSet", "get_ariaPosInSet", "set_ariaPosInSet" },
            .{ "ariaPressed", "get_ariaPressed", "set_ariaPressed" },
            .{ "ariaReadOnly", "get_ariaReadOnly", "set_ariaReadOnly" },
            .{ "ariaRelevant", "get_ariaRelevant", "set_ariaRelevant" },
            .{ "ariaRequired", "get_ariaRequired", "set_ariaRequired" },
            .{ "ariaRoleDescription", "get_ariaRoleDescription", "set_ariaRoleDescription" },
            .{ "ariaRowCount", "get_ariaRowCount", "set_ariaRowCount" },
            .{ "ariaRowIndex", "get_ariaRowIndex", "set_ariaRowIndex" },
            .{ "ariaRowIndexText", "get_ariaRowIndexText", "set_ariaRowIndexText" },
            .{ "ariaRowSpan", "get_ariaRowSpan", "set_ariaRowSpan" },
            .{ "ariaSelected", "get_ariaSelected", "set_ariaSelected" },
            .{ "ariaSetSize", "get_ariaSetSize", "set_ariaSetSize" },
            .{ "ariaSort", "get_ariaSort", "set_ariaSort" },
            .{ "ariaValueMax", "get_ariaValueMax", "set_ariaValueMax" },
            .{ "ariaValueMin", "get_ariaValueMin", "set_ariaValueMin" },
            .{ "ariaValueNow", "get_ariaValueNow", "set_ariaValueNow" },
            .{ "ariaValueText", "get_ariaValueText", "set_ariaValueText" },
            .{ "regionOverset", "get_regionOverset", null },
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
            .{ "assignedSlot", "get_assignedSlot", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            namespaceURI: ?typedefs.DOMString = null,
            prefix: ?typedefs.DOMString = null,
            localName: typedefs.DOMString = undefined,
            tagName: typedefs.DOMString = undefined,
            id: typedefs.DOMString = undefined,
            className: typedefs.DOMString = undefined,
            classList: *runtime.Instance = undefined,
            slot: typedefs.DOMString = undefined,
            attributes: *runtime.Instance = undefined,
            shadowRoot: ?*runtime.Instance = null,
            customElementRegistry: ?*runtime.Instance = null,
            onfullscreenchange: typedefs.EventHandler = undefined,
            onfullscreenerror: typedefs.EventHandler = undefined,
            elementTiming: typedefs.DOMString = undefined,
            part: *runtime.Instance = undefined,
            activeViewTransition: ?*runtime.Instance = null,
            innerHTML: union(enum) {
                TrustedHTML: TrustedHTML,
                DOMString: runtime.DOMString,
            } = undefined,
            outerHTML: union(enum) {
                TrustedHTML: TrustedHTML,
                DOMString: runtime.DOMString,
            } = undefined,
            scrollTop: f64 = undefined,
            scrollLeft: f64 = undefined,
            scrollWidth: i32 = undefined,
            scrollHeight: i32 = undefined,
            clientTop: i32 = undefined,
            clientLeft: i32 = undefined,
            clientWidth: i32 = undefined,
            clientHeight: i32 = undefined,
            currentCSSZoom: f64 = undefined,
            role: ?typedefs.DOMString = null,
            ariaActiveDescendantElement: ?*runtime.Instance = null,
            ariaAtomic: ?typedefs.DOMString = null,
            ariaAutoComplete: ?typedefs.DOMString = null,
            ariaBrailleLabel: ?typedefs.DOMString = null,
            ariaBrailleRoleDescription: ?typedefs.DOMString = null,
            ariaBusy: ?typedefs.DOMString = null,
            ariaChecked: ?typedefs.DOMString = null,
            ariaColCount: ?typedefs.DOMString = null,
            ariaColIndex: ?typedefs.DOMString = null,
            ariaColIndexText: ?typedefs.DOMString = null,
            ariaColSpan: ?typedefs.DOMString = null,
            ariaControlsElements: ?runtime.JSValue = null,
            ariaCurrent: ?typedefs.DOMString = null,
            ariaDescribedByElements: ?runtime.JSValue = null,
            ariaDescription: ?typedefs.DOMString = null,
            ariaDetailsElements: ?runtime.JSValue = null,
            ariaDisabled: ?typedefs.DOMString = null,
            ariaErrorMessageElements: ?runtime.JSValue = null,
            ariaExpanded: ?typedefs.DOMString = null,
            ariaFlowToElements: ?runtime.JSValue = null,
            ariaHasPopup: ?typedefs.DOMString = null,
            ariaHidden: ?typedefs.DOMString = null,
            ariaInvalid: ?typedefs.DOMString = null,
            ariaKeyShortcuts: ?typedefs.DOMString = null,
            ariaLabel: ?typedefs.DOMString = null,
            ariaLabelledByElements: ?runtime.JSValue = null,
            ariaLevel: ?typedefs.DOMString = null,
            ariaLive: ?typedefs.DOMString = null,
            ariaModal: ?typedefs.DOMString = null,
            ariaMultiLine: ?typedefs.DOMString = null,
            ariaMultiSelectable: ?typedefs.DOMString = null,
            ariaOrientation: ?typedefs.DOMString = null,
            ariaOwnsElements: ?runtime.JSValue = null,
            ariaPlaceholder: ?typedefs.DOMString = null,
            ariaPosInSet: ?typedefs.DOMString = null,
            ariaPressed: ?typedefs.DOMString = null,
            ariaReadOnly: ?typedefs.DOMString = null,
            ariaRelevant: ?typedefs.DOMString = null,
            ariaRequired: ?typedefs.DOMString = null,
            ariaRoleDescription: ?typedefs.DOMString = null,
            ariaRowCount: ?typedefs.DOMString = null,
            ariaRowIndex: ?typedefs.DOMString = null,
            ariaRowIndexText: ?typedefs.DOMString = null,
            ariaRowSpan: ?typedefs.DOMString = null,
            ariaSelected: ?typedefs.DOMString = null,
            ariaSetSize: ?typedefs.DOMString = null,
            ariaSort: ?typedefs.DOMString = null,
            ariaValueMax: ?typedefs.DOMString = null,
            ariaValueMin: ?typedefs.DOMString = null,
            ariaValueNow: ?typedefs.DOMString = null,
            ariaValueText: ?typedefs.DOMString = null,
            regionOverset: typedefs.CSSOMString = undefined,
            children: *runtime.Instance = undefined,
            firstElementChild: ?*runtime.Instance = null,
            lastElementChild: ?*runtime.Instance = null,
            childElementCount: u32 = undefined,
            previousElementSibling: ?*runtime.Instance = null,
            nextElementSibling: ?*runtime.Instance = null,
            assignedSlot: ?*runtime.Instance = null,
            cached_classList: ?*runtime.Instance = null,
            cached_attributes: ?*runtime.Instance = null,
            cached_part: ?*runtime.Instance = null,
            cached_children: ?*runtime.Instance = null,
            _internal: ?*ElementImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_activeViewTransition = &get_activeViewTransition,
        .get_ariaActiveDescendantElement = &get_ariaActiveDescendantElement,
        .get_ariaAtomic = &get_ariaAtomic,
        .get_ariaAutoComplete = &get_ariaAutoComplete,
        .get_ariaBrailleLabel = &get_ariaBrailleLabel,
        .get_ariaBrailleRoleDescription = &get_ariaBrailleRoleDescription,
        .get_ariaBusy = &get_ariaBusy,
        .get_ariaChecked = &get_ariaChecked,
        .get_ariaColCount = &get_ariaColCount,
        .get_ariaColIndex = &get_ariaColIndex,
        .get_ariaColIndexText = &get_ariaColIndexText,
        .get_ariaColSpan = &get_ariaColSpan,
        .get_ariaControlsElements = &get_ariaControlsElements,
        .get_ariaCurrent = &get_ariaCurrent,
        .get_ariaDescribedByElements = &get_ariaDescribedByElements,
        .get_ariaDescription = &get_ariaDescription,
        .get_ariaDetailsElements = &get_ariaDetailsElements,
        .get_ariaDisabled = &get_ariaDisabled,
        .get_ariaErrorMessageElements = &get_ariaErrorMessageElements,
        .get_ariaExpanded = &get_ariaExpanded,
        .get_ariaFlowToElements = &get_ariaFlowToElements,
        .get_ariaHasPopup = &get_ariaHasPopup,
        .get_ariaHidden = &get_ariaHidden,
        .get_ariaInvalid = &get_ariaInvalid,
        .get_ariaKeyShortcuts = &get_ariaKeyShortcuts,
        .get_ariaLabel = &get_ariaLabel,
        .get_ariaLabelledByElements = &get_ariaLabelledByElements,
        .get_ariaLevel = &get_ariaLevel,
        .get_ariaLive = &get_ariaLive,
        .get_ariaModal = &get_ariaModal,
        .get_ariaMultiLine = &get_ariaMultiLine,
        .get_ariaMultiSelectable = &get_ariaMultiSelectable,
        .get_ariaOrientation = &get_ariaOrientation,
        .get_ariaOwnsElements = &get_ariaOwnsElements,
        .get_ariaPlaceholder = &get_ariaPlaceholder,
        .get_ariaPosInSet = &get_ariaPosInSet,
        .get_ariaPressed = &get_ariaPressed,
        .get_ariaReadOnly = &get_ariaReadOnly,
        .get_ariaRelevant = &get_ariaRelevant,
        .get_ariaRequired = &get_ariaRequired,
        .get_ariaRoleDescription = &get_ariaRoleDescription,
        .get_ariaRowCount = &get_ariaRowCount,
        .get_ariaRowIndex = &get_ariaRowIndex,
        .get_ariaRowIndexText = &get_ariaRowIndexText,
        .get_ariaRowSpan = &get_ariaRowSpan,
        .get_ariaSelected = &get_ariaSelected,
        .get_ariaSetSize = &get_ariaSetSize,
        .get_ariaSort = &get_ariaSort,
        .get_ariaValueMax = &get_ariaValueMax,
        .get_ariaValueMin = &get_ariaValueMin,
        .get_ariaValueNow = &get_ariaValueNow,
        .get_ariaValueText = &get_ariaValueText,
        .get_assignedSlot = &get_assignedSlot,
        .get_attributes = &get_attributes,
        .get_childElementCount = &get_childElementCount,
        .get_children = &get_children,
        .get_classList = &get_classList,
        .get_className = &get_className,
        .get_clientHeight = &get_clientHeight,
        .get_clientLeft = &get_clientLeft,
        .get_clientTop = &get_clientTop,
        .get_clientWidth = &get_clientWidth,
        .get_currentCSSZoom = &get_currentCSSZoom,
        .get_customElementRegistry = &get_customElementRegistry,
        .get_elementTiming = &get_elementTiming,
        .get_firstElementChild = &get_firstElementChild,
        .get_id = &get_id,
        .get_innerHTML = &get_innerHTML,
        .get_lastElementChild = &get_lastElementChild,
        .get_localName = &get_localName,
        .get_namespaceURI = &get_namespaceURI,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_onfullscreenchange = &get_onfullscreenchange,
        .get_onfullscreenerror = &get_onfullscreenerror,
        .get_outerHTML = &get_outerHTML,
        .get_part = &get_part,
        .get_prefix = &get_prefix,
        .get_previousElementSibling = &get_previousElementSibling,
        .get_regionOverset = &get_regionOverset,
        .get_role = &get_role,
        .get_scrollHeight = &get_scrollHeight,
        .get_scrollLeft = &get_scrollLeft,
        .get_scrollTop = &get_scrollTop,
        .get_scrollWidth = &get_scrollWidth,
        .get_shadowRoot = &get_shadowRoot,
        .get_slot = &get_slot,
        .get_tagName = &get_tagName,

        .set_ariaActiveDescendantElement = &set_ariaActiveDescendantElement,
        .set_ariaAtomic = &set_ariaAtomic,
        .set_ariaAutoComplete = &set_ariaAutoComplete,
        .set_ariaBrailleLabel = &set_ariaBrailleLabel,
        .set_ariaBrailleRoleDescription = &set_ariaBrailleRoleDescription,
        .set_ariaBusy = &set_ariaBusy,
        .set_ariaChecked = &set_ariaChecked,
        .set_ariaColCount = &set_ariaColCount,
        .set_ariaColIndex = &set_ariaColIndex,
        .set_ariaColIndexText = &set_ariaColIndexText,
        .set_ariaColSpan = &set_ariaColSpan,
        .set_ariaControlsElements = &set_ariaControlsElements,
        .set_ariaCurrent = &set_ariaCurrent,
        .set_ariaDescribedByElements = &set_ariaDescribedByElements,
        .set_ariaDescription = &set_ariaDescription,
        .set_ariaDetailsElements = &set_ariaDetailsElements,
        .set_ariaDisabled = &set_ariaDisabled,
        .set_ariaErrorMessageElements = &set_ariaErrorMessageElements,
        .set_ariaExpanded = &set_ariaExpanded,
        .set_ariaFlowToElements = &set_ariaFlowToElements,
        .set_ariaHasPopup = &set_ariaHasPopup,
        .set_ariaHidden = &set_ariaHidden,
        .set_ariaInvalid = &set_ariaInvalid,
        .set_ariaKeyShortcuts = &set_ariaKeyShortcuts,
        .set_ariaLabel = &set_ariaLabel,
        .set_ariaLabelledByElements = &set_ariaLabelledByElements,
        .set_ariaLevel = &set_ariaLevel,
        .set_ariaLive = &set_ariaLive,
        .set_ariaModal = &set_ariaModal,
        .set_ariaMultiLine = &set_ariaMultiLine,
        .set_ariaMultiSelectable = &set_ariaMultiSelectable,
        .set_ariaOrientation = &set_ariaOrientation,
        .set_ariaOwnsElements = &set_ariaOwnsElements,
        .set_ariaPlaceholder = &set_ariaPlaceholder,
        .set_ariaPosInSet = &set_ariaPosInSet,
        .set_ariaPressed = &set_ariaPressed,
        .set_ariaReadOnly = &set_ariaReadOnly,
        .set_ariaRelevant = &set_ariaRelevant,
        .set_ariaRequired = &set_ariaRequired,
        .set_ariaRoleDescription = &set_ariaRoleDescription,
        .set_ariaRowCount = &set_ariaRowCount,
        .set_ariaRowIndex = &set_ariaRowIndex,
        .set_ariaRowIndexText = &set_ariaRowIndexText,
        .set_ariaRowSpan = &set_ariaRowSpan,
        .set_ariaSelected = &set_ariaSelected,
        .set_ariaSetSize = &set_ariaSetSize,
        .set_ariaSort = &set_ariaSort,
        .set_ariaValueMax = &set_ariaValueMax,
        .set_ariaValueMin = &set_ariaValueMin,
        .set_ariaValueNow = &set_ariaValueNow,
        .set_ariaValueText = &set_ariaValueText,
        .set_classList = &set_classList,
        .set_className = &set_className,
        .set_elementTiming = &set_elementTiming,
        .set_id = &set_id,
        .set_innerHTML = &set_innerHTML,
        .set_onfullscreenchange = &set_onfullscreenchange,
        .set_onfullscreenerror = &set_onfullscreenerror,
        .set_outerHTML = &set_outerHTML,
        .set_part = &set_part,
        .set_role = &set_role,
        .set_scrollLeft = &set_scrollLeft,
        .set_scrollTop = &set_scrollTop,
        .set_slot = &set_slot,

        .call_after = &call_after,
        .call_animate = &call_animate,
        .call_append = &call_append,
        .call_attachShadow = &call_attachShadow,
        .call_before = &call_before,
        .call_checkVisibility = &call_checkVisibility,
        .call_closest = &call_closest,
        .call_computedStyleMap = &call_computedStyleMap,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_focusableAreas = &call_focusableAreas,
        .call_getAnimations = &call_getAnimations,
        .call_getAttribute = &call_getAttribute,
        .call_getAttributeNS = &call_getAttributeNS,
        .call_getAttributeNames = &call_getAttributeNames,
        .call_getAttributeNode = &call_getAttributeNode,
        .call_getAttributeNodeNS = &call_getAttributeNodeNS,
        .call_getBoundingClientRect = &call_getBoundingClientRect,
        .call_getBoxQuads = &call_getBoxQuads,
        .call_getClientRects = &call_getClientRects,
        .call_getElementsByClassName = &call_getElementsByClassName,
        .call_getElementsByTagName = &call_getElementsByTagName,
        .call_getElementsByTagNameNS = &call_getElementsByTagNameNS,
        .call_getHTML = &call_getHTML,
        .call_getRegionFlowRanges = &call_getRegionFlowRanges,
        .call_getSpatialNavigationContainer = &call_getSpatialNavigationContainer,
        .call_hasAttribute = &call_hasAttribute,
        .call_hasAttributeNS = &call_hasAttributeNS,
        .call_hasAttributes = &call_hasAttributes,
        .call_hasPointerCapture = &call_hasPointerCapture,
        .call_insertAdjacentElement = &call_insertAdjacentElement,
        .call_insertAdjacentHTML = &call_insertAdjacentHTML,
        .call_insertAdjacentText = &call_insertAdjacentText,
        .call_matches = &call_matches,
        .call_moveBefore = &call_moveBefore,
        .call_prepend = &call_prepend,
        .call_pseudo = &call_pseudo,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_releasePointerCapture = &call_releasePointerCapture,
        .call_remove = &call_remove,
        .call_removeAttribute = &call_removeAttribute,
        .call_removeAttributeNS = &call_removeAttributeNS,
        .call_removeAttributeNode = &call_removeAttributeNode,
        .call_replaceChildren = &call_replaceChildren,
        .call_replaceWith = &call_replaceWith,
        .call_requestFullscreen = &call_requestFullscreen,
        .call_requestPointerLock = &call_requestPointerLock,
        .call_scroll = &call_scroll,
        .call_scrollBy = &call_scrollBy,
        .call_scrollIntoView = &call_scrollIntoView,
        .call_scrollTo = &call_scrollTo,
        .call_setAttribute = &call_setAttribute,
        .call_setAttributeNS = &call_setAttributeNS,
        .call_setAttributeNode = &call_setAttributeNode,
        .call_setAttributeNodeNS = &call_setAttributeNodeNS,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,
        .call_setPointerCapture = &call_setPointerCapture,
        .call_spatialNavigationSearch = &call_spatialNavigationSearch,
        .call_startViewTransition = &call_startViewTransition,
        .call_toggleAttribute = &call_toggleAttribute,
        .call_webkitMatchesSelector = &call_webkitMatchesSelector,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ElementImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ElementImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ElementImpl.deinit(instance);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_prefix(instance);
    }

    pub fn get_localName(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_localName(instance);
    }

    pub fn get_tagName(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_tagName(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_id(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_id(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_id(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_className(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_className(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_className(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_className(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_classList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_classList) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_classList(instance);
        state.own.cached_classList = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn set_classList(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'classList' forwards to 'value' on the attribute's value
        const target = try get_classList(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        // Note: target is a *Instance, use setPropertyOnInstance
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn get_slot(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_slot(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn set_slot(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_slot(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_attributes) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_attributes(instance);
        state.own.cached_attributes = value;
        return value;
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_shadowRoot(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_customElementRegistry(instance);
    }

    pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ElementImpl.get_onfullscreenchange(instance);
    }

    pub fn set_onfullscreenchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ElementImpl.set_onfullscreenchange(instance, value);
    }

    pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!EventHandler {
        return try ElementImpl.get_onfullscreenerror(instance);
    }

    pub fn set_onfullscreenerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ElementImpl.set_onfullscreenerror(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_elementTiming(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_elementTiming(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_elementTiming(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_elementTiming(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_part(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_part) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_part(instance);
        state.own.cached_part = value;
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn set_part(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'part' forwards to 'value' on the attribute's value
        const target = try get_part(instance);
        
        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        // Note: target is a *Instance, use setPropertyOnInstance
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_activeViewTransition(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_innerHTML(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_outerHTML(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_outerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_outerHTML(instance: *runtime.Instance, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_outerHTML(instance, value);
    }

    pub fn get_scrollTop(instance: *runtime.Instance) anyerror!f64 {
        return try ElementImpl.get_scrollTop(instance);
    }

    pub fn set_scrollTop(instance: *runtime.Instance, value: f64) anyerror!void {
        try ElementImpl.set_scrollTop(instance, value);
    }

    pub fn get_scrollLeft(instance: *runtime.Instance) anyerror!f64 {
        return try ElementImpl.get_scrollLeft(instance);
    }

    pub fn set_scrollLeft(instance: *runtime.Instance, value: f64) anyerror!void {
        try ElementImpl.set_scrollLeft(instance, value);
    }

    pub fn get_scrollWidth(instance: *runtime.Instance) anyerror!i32 {
        return try ElementImpl.get_scrollWidth(instance);
    }

    pub fn get_scrollHeight(instance: *runtime.Instance) anyerror!i32 {
        return try ElementImpl.get_scrollHeight(instance);
    }

    pub fn get_clientTop(instance: *runtime.Instance) anyerror!i32 {
        return try ElementImpl.get_clientTop(instance);
    }

    pub fn get_clientLeft(instance: *runtime.Instance) anyerror!i32 {
        return try ElementImpl.get_clientLeft(instance);
    }

    pub fn get_clientWidth(instance: *runtime.Instance) anyerror!i32 {
        return try ElementImpl.get_clientWidth(instance);
    }

    pub fn get_clientHeight(instance: *runtime.Instance) anyerror!i32 {
        return try ElementImpl.get_clientHeight(instance);
    }

    pub fn get_currentCSSZoom(instance: *runtime.Instance) anyerror!f64 {
        return try ElementImpl.get_currentCSSZoom(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_role(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_role(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_role(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_role(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_ariaActiveDescendantElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: ?*runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaActiveDescendantElement(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaAtomic(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn set_ariaAtomic(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaAtomic(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaAutoComplete(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaAutoComplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaBrailleLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaBrailleLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaBrailleRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaBrailleRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaBusy(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn set_ariaBusy(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaBusy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaChecked(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn set_ariaChecked(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaChecked(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaColCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn set_ariaColCount(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaColIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn set_ariaColIndex(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaColIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn set_ariaColIndexText(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaColSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn set_ariaColSpan(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaControlsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn set_ariaControlsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaControlsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaCurrent(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn set_ariaCurrent(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaCurrent(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaDescribedByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDescribedByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn set_ariaDescription(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaDetailsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDetailsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaDisabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn set_ariaDisabled(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDisabled(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaErrorMessageElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaErrorMessageElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaExpanded(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn set_ariaExpanded(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaExpanded(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaFlowToElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaFlowToElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaHasPopup(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn set_ariaHasPopup(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaHasPopup(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaHidden(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn set_ariaHidden(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaHidden(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaInvalid(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn set_ariaInvalid(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaInvalid(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaKeyShortcuts(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaKeyShortcuts(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn set_ariaLabel(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaLabelledByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLabelledByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaLevel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn set_ariaLevel(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLevel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn get_ariaLive(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaLive(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn set_ariaLive(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLive(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn get_ariaModal(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaModal(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn set_ariaModal(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaModal(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaMultiLine(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn set_ariaMultiLine(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaMultiLine(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaMultiSelectable(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaMultiSelectable(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaOrientation(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn set_ariaOrientation(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaOrientation(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.get_ariaOwnsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: ?runtime.JSValue) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaOwnsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaPlaceholder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaPlaceholder(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaPosInSet(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn set_ariaPosInSet(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaPosInSet(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaPressed(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn set_ariaPressed(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaPressed(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaReadOnly(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn set_ariaReadOnly(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaReadOnly(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRelevant(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn set_ariaRelevant(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRelevant(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRequired(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn set_ariaRequired(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRequired(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRowCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn set_ariaRowCount(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRowIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn set_ariaRowIndex(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRowIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaRowSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn set_ariaRowSpan(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaSelected(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn set_ariaSelected(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaSelected(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaSetSize(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn set_ariaSetSize(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaSetSize(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn get_ariaSort(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaSort(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn set_ariaSort(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaSort(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaValueMax(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn set_ariaValueMax(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueMax(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaValueMin(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn set_ariaValueMin(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueMin(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaValueNow(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn set_ariaValueNow(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueNow(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!?DOMString {
        return try ElementImpl.get_ariaValueText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn set_ariaValueText(instance: *runtime.Instance, value: ?DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueText(instance, value);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyerror!CSSOMString {
        return try ElementImpl.get_regionOverset(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_children) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_children(instance);
        state.own.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_firstElementChild(instance);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_lastElementChild(instance);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
        return try ElementImpl.get_childElementCount(instance);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_previousElementSibling(instance);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_nextElementSibling(instance);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_assignedSlot(instance);
    }

    pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.call_getSpatialNavigationContainer(instance);
    }

    pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
        return try ElementImpl.call_hasAttributes(instance);
    }

    pub fn call_insertAdjacentText(instance: *runtime.Instance, where: DOMString, data: DOMString) anyerror!void {
        
        return try ElementImpl.call_insertAdjacentText(instance, where, data);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: *runtime.Instance, child: ?*runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_moveBefore(instance, node, child);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: DOMString, element: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_insertAdjacentElement(instance, where, element);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_append(instance, nodes);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: webidl.Opt(BoxQuadOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        
        return try ElementImpl.call_setPointerCapture(instance, pointerId);
    }

    pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!bool {
        
        return try ElementImpl.call_hasAttributeNS(instance, namespace, localName);
    }

    pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
        
        return try ElementImpl.call_hasPointerCapture(instance, pointerId);
    }

    pub fn call_focusableAreas(instance: *runtime.Instance, option: webidl.Opt(FocusableAreasOption)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_focusableAreas(instance, option);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_before(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: ?DOMString, qualifiedName: DOMString, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttributeNS(instance, namespace, qualifiedName, value);
    }

    pub fn call_closest(instance: *runtime.Instance, selectors: DOMString) anyerror!?*runtime.Instance {
        
        return try ElementImpl.call_closest(instance, selectors);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try ElementImpl.call_getBoundingClientRect(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_after(instance, nodes);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: DOMString) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_getElementsByClassName(instance, classNames);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttributeNode(instance, attr);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try ElementImpl.call_remove(instance);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    pub fn call_requestPointerLock(instance: *runtime.Instance, options: webidl.Opt(PointerLockOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_requestPointerLock(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttributeNodeNS(instance, attr);
    }

    pub fn call_animate(instance: *runtime.Instance, keyframes: ?runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_animate(instance, keyframes, options);
    }

    pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!?DOMString {
        
        return try ElementImpl.call_getAttributeNS(instance, namespace, localName);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(runtime.JSValue)) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_startViewTransition(instance, callbackOptions);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!?DOMString {
        
        return try ElementImpl.call_getAttribute(instance, qualifiedName);
    }

    pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!?*runtime.Instance {
        
        return try ElementImpl.call_getAttributeNodeNS(instance, namespace, localName);
    }

    pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_scroll(instance, options);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_getElementsByTagName(instance, qualifiedName);
    }

    pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: SpatialNavigationDirection, options: webidl.Opt(SpatialNavigationSearchOptions)) anyerror!?*runtime.Instance {
        
        return try ElementImpl.call_spatialNavigationSearch(instance, dir, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: DOMString, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttribute(instance, qualifiedName, value);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!?*runtime.Instance {
        
        return try ElementImpl.call_querySelector(instance, selectors);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: DOMString, force: webidl.Opt(bool)) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_toggleAttribute(instance, qualifiedName, force);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        
        return try ElementImpl.call_querySelectorAll(instance, selectors);
    }

    /// Extended attributes: [SameObject]
    pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.call_computedStyleMap(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setHTMLUnsafe(instance, html);
    }

    pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!?*runtime.Instance {
        
        return try ElementImpl.call_getAttributeNode(instance, qualifiedName);
    }

    pub fn call_matches(instance: *runtime.Instance, selectors: DOMString) anyerror!bool {
        
        return try ElementImpl.call_matches(instance, selectors);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(GetHTMLOptions)) anyerror!DOMString {
        
        return try ElementImpl.call_getHTML(instance, options);
    }

    pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_scrollBy(instance, options);
    }

    pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ElementImpl.call_getAttributeNames(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_replaceWith(instance, nodes);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_getElementsByTagNameNS(instance, namespace, localName);
    }

    pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: DOMString) anyerror!bool {
        
        return try ElementImpl.call_webkitMatchesSelector(instance, selectors);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: *runtime.Instance, from: GeometryNode, options: webidl.Opt(ConvertCoordinateOptions)) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_scrollTo(instance, options);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_replaceChildren(instance, nodes);
    }

    pub fn call_requestFullscreen(instance: *runtime.Instance, options: webidl.Opt(FullscreenOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_requestFullscreen(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeAttribute(instance, qualifiedName);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!?runtime.JSValue {
        return try ElementImpl.call_getRegionFlowRanges(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: []const mixins.ParentNode.NodeOrString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_prepend(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeAttributeNode(instance, attr);
    }

    pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!bool {
        
        return try ElementImpl.call_hasAttribute(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: DOMString, string: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_insertAdjacentHTML(instance, position, string);
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.call_getClientRects(instance);
    }

    pub fn call_scrollIntoView(instance: *runtime.Instance, arg: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_scrollIntoView(instance, arg);
    }

    pub fn call_getAnimations(instance: *runtime.Instance, options: webidl.Opt(GetAnimationsOptions)) anyerror!runtime.JSValue {
        
        return try ElementImpl.call_getAnimations(instance, options);
    }

    pub fn call_attachShadow(instance: *runtime.Instance, init_data: ShadowRootInit) anyerror!*runtime.Instance {
        
        return try ElementImpl.call_attachShadow(instance, init_data);
    }

    pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        
        return try ElementImpl.call_releasePointerCapture(instance, pointerId);
    }

    pub fn call_pseudo(instance: *runtime.Instance, @"type": CSSOMString) anyerror!?*runtime.Instance {
        
        return try ElementImpl.call_pseudo(instance, @"type");
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: ?DOMString, localName: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeAttributeNS(instance, namespace, localName);
    }

    pub fn call_checkVisibility(instance: *runtime.Instance, options: webidl.Opt(CheckVisibilityOptions)) anyerror!bool {
        
        return try ElementImpl.call_checkVisibility(instance, options);
    }

};

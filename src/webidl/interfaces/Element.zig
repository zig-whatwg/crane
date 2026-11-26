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
const Node = @import("interfaces").Node;
const Region = @import("mixins").Region;
const GeometryUtils = @import("mixins").GeometryUtils;
const ParentNode = @import("mixins").ParentNode;
const NonDocumentTypeChildNode = @import("mixins").NonDocumentTypeChildNode;
const ChildNode = @import("mixins").ChildNode;
const Slottable = @import("mixins").Slottable;
const ARIAMixin = @import("mixins").ARIAMixin;
const ARIANotifyMixin = @import("mixins").ARIANotifyMixin;
const Animatable = @import("mixins").Animatable;
const CSSOMString = @import("typedefs").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const ViewTransitionUpdateCallbackOrStartViewTransitionOptions = @import("typedefs").ViewTransitionUpdateCallbackOrStartViewTransitionOptions;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const USVString = @import("typedefs").USVString;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const TrustedHTMLOrDOMString = @import("typedefs").TrustedHTMLOrDOMString;
const EventListenerOptionsOrBoolean = @import("typedefs").EventListenerOptionsOrBoolean;
const EventListener = @import("interfaces").EventListener;
const WritableStream = @import("interfaces").WritableStream;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const SetHTMLOptions = @import("dictionaries").SetHTMLOptions;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Range = @import("interfaces").Range;
const Animation = @import("interfaces").Animation;
const Event = @import("interfaces").Event;
const TrustedTypeOrDOMString = @import("typedefs").TrustedTypeOrDOMString;
const DOMString = @import("typedefs").DOMString;
const DOMRectList = @import("interfaces").DOMRectList;
const Document = @import("interfaces").Document;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const DOMQuad = @import("interfaces").DOMQuad;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions = @import("typedefs").SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const UnrestrictedDoubleOrKeyframeAnimationOptions = @import("typedefs").UnrestrictedDoubleOrKeyframeAnimationOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const NodeList = @import("interfaces").NodeList;
const AriaNotificationOptions = @import("dictionaries").AriaNotificationOptions;
const Observable = @import("interfaces").Observable;
const DOMPoint = @import("interfaces").DOMPoint;
const BooleanOrScrollIntoViewOptions = @import("typedefs").BooleanOrScrollIntoViewOptions;
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;
const AddEventListenerOptionsOrBoolean = @import("typedefs").AddEventListenerOptionsOrBoolean;

pub const Element = struct {
    pub const Meta = struct {
        pub const name = "Element";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Node.State;
        pub const ParentInterface = Node;
        pub const MixinTypes = &.{
            Region,
            GeometryUtils,
            ParentNode,
            NonDocumentTypeChildNode,
            ChildNode,
            Slottable,
            ARIAMixin,
            ARIANotifyMixin,
            Animatable,
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
            .{ "part", "get_part", "set_part" },
            .{ "activeViewTransition", "get_activeViewTransition", null },
            .{ "scrollTop", "get_scrollTop", "set_scrollTop" },
            .{ "scrollLeft", "get_scrollLeft", "set_scrollLeft" },
            .{ "scrollWidth", "get_scrollWidth", null },
            .{ "scrollHeight", "get_scrollHeight", null },
            .{ "clientTop", "get_clientTop", null },
            .{ "clientLeft", "get_clientLeft", null },
            .{ "clientWidth", "get_clientWidth", null },
            .{ "clientHeight", "get_clientHeight", null },
            .{ "currentCSSZoom", "get_currentCSSZoom", null },
            .{ "elementTiming", "get_elementTiming", "set_elementTiming" },
            .{ "onfullscreenchange", "get_onfullscreenchange", "set_onfullscreenchange" },
            .{ "onfullscreenerror", "get_onfullscreenerror", "set_onfullscreenerror" },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "outerHTML", "get_outerHTML", "set_outerHTML" },
            .{ "regionOverset", "get_regionOverset", null },
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
            .{ "assignedSlot", "get_assignedSlot", null },
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
        };

        /// [SameObject] attributes whose child the owner keeps (in its State, its rare
        /// data or its impl): the binding ties the child's wrapper to the owner's.
        pub const same_object_attributes = .{
            "classList",
            "attributes",
            "part",
            "children",
        };

        /// FrozenArray<T> attributes: their getters return the array as a JSValue, and
        /// the binding gives each isolated world a frozen array of its own.
        pub const frozen_array_attributes = .{
            "ariaControlsElements",
            "ariaDescribedByElements",
            "ariaDetailsElements",
            "ariaErrorMessageElements",
            "ariaFlowToElements",
            "ariaLabelledByElements",
            "ariaOwnsElements",
        };

        /// [PutForwards] attributes: setting the attribute forwards to a property on the value
        /// Format: { "attrName", "forwardedProperty" }
        pub const put_forwards_attributes = .{
            .{ "classList", "value" },
            .{ "part", "value" },
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
            .{ "pseudo", "call_pseudo", 1 },
            .{ "computedStyleMap", "call_computedStyleMap", 0 },
            .{ "startViewTransition", "call_startViewTransition", 0 },
            .{ "getClientRects", "call_getClientRects", 0 },
            .{ "getBoundingClientRect", "call_getBoundingClientRect", 0 },
            .{ "checkVisibility", "call_checkVisibility", 0 },
            .{ "scrollIntoView", "call_scrollIntoView", 0 },
            .{ "scroll", "call_scroll", 0 },
            .{ "scrollTo", "call_scrollTo", 0 },
            .{ "scrollBy", "call_scrollBy", 0 },
            .{ "requestFullscreen", "call_requestFullscreen", 0 },
            .{ "appendHTML", "call_appendHTML", 1 },
            .{ "prependHTML", "call_prependHTML", 1 },
            .{ "streamHTML", "call_streamHTML", 0 },
            .{ "streamAppendHTML", "call_streamAppendHTML", 0 },
            .{ "streamPrependHTML", "call_streamPrependHTML", 0 },
            .{ "setHTMLUnsafe", "call_setHTMLUnsafe", 1 },
            .{ "appendHTMLUnsafe", "call_appendHTMLUnsafe", 1 },
            .{ "prependHTMLUnsafe", "call_prependHTMLUnsafe", 1 },
            .{ "streamHTMLUnsafe", "call_streamHTMLUnsafe", 0 },
            .{ "streamAppendHTMLUnsafe", "call_streamAppendHTMLUnsafe", 0 },
            .{ "streamPrependHTMLUnsafe", "call_streamPrependHTMLUnsafe", 0 },
            .{ "setHTML", "call_setHTML", 1 },
            .{ "getHTML", "call_getHTML", 0 },
            .{ "insertAdjacentHTML", "call_insertAdjacentHTML", 2 },
            .{ "setPointerCapture", "call_setPointerCapture", 1 },
            .{ "releasePointerCapture", "call_releasePointerCapture", 1 },
            .{ "hasPointerCapture", "call_hasPointerCapture", 1 },
            .{ "requestPointerLock", "call_requestPointerLock", 0 },
            .{ "getRegionFlowRanges", "call_getRegionFlowRanges", 0 },
            .{ "getBoxQuads", "call_getBoxQuads", 0 },
            .{ "convertQuadFromNode", "call_convertQuadFromNode", 2 },
            .{ "convertRectFromNode", "call_convertRectFromNode", 2 },
            .{ "convertPointFromNode", "call_convertPointFromNode", 2 },
            .{ "prepend", "call_prepend", 0 },
            .{ "append", "call_append", 0 },
            .{ "replaceChildren", "call_replaceChildren", 0 },
            .{ "moveBefore", "call_moveBefore", 2 },
            .{ "querySelector", "call_querySelector", 1 },
            .{ "querySelectorAll", "call_querySelectorAll", 1 },
            .{ "beforeHTML", "call_beforeHTML", 1 },
            .{ "afterHTML", "call_afterHTML", 1 },
            .{ "replaceWithHTML", "call_replaceWithHTML", 1 },
            .{ "streamBeforeHTML", "call_streamBeforeHTML", 0 },
            .{ "streamAfterHTML", "call_streamAfterHTML", 0 },
            .{ "streamReplaceWithHTML", "call_streamReplaceWithHTML", 0 },
            .{ "beforeHTMLUnsafe", "call_beforeHTMLUnsafe", 1 },
            .{ "afterHTMLUnsafe", "call_afterHTMLUnsafe", 1 },
            .{ "replaceWithHTMLUnsafe", "call_replaceWithHTMLUnsafe", 1 },
            .{ "streamBeforeHTMLUnsafe", "call_streamBeforeHTMLUnsafe", 0 },
            .{ "streamAfterHTMLUnsafe", "call_streamAfterHTMLUnsafe", 0 },
            .{ "streamReplaceWithHTMLUnsafe", "call_streamReplaceWithHTMLUnsafe", 0 },
            .{ "before", "call_before", 0 },
            .{ "after", "call_after", 0 },
            .{ "replaceWith", "call_replaceWith", 0 },
            .{ "remove", "call_remove", 0 },
            .{ "ariaNotify", "call_ariaNotify", 1 },
            .{ "animate", "call_animate", 1 },
            .{ "getAnimations", "call_getAnimations", 0 },
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
            "pseudo",
            "computedStyleMap",
            "startViewTransition",
            "getClientRects",
            "getBoundingClientRect",
            "checkVisibility",
            "scrollIntoView",
            "scroll",
            "scrollTo",
            "scrollBy",
            "requestFullscreen",
            "appendHTML",
            "prependHTML",
            "streamHTML",
            "streamAppendHTML",
            "streamPrependHTML",
            "setHTMLUnsafe",
            "appendHTMLUnsafe",
            "prependHTMLUnsafe",
            "streamHTMLUnsafe",
            "streamAppendHTMLUnsafe",
            "streamPrependHTMLUnsafe",
            "setHTML",
            "getHTML",
            "insertAdjacentHTML",
            "setPointerCapture",
            "releasePointerCapture",
            "hasPointerCapture",
            "requestPointerLock",
            "getRegionFlowRanges",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "beforeHTML",
            "afterHTML",
            "replaceWithHTML",
            "streamBeforeHTML",
            "streamAfterHTML",
            "streamReplaceWithHTML",
            "beforeHTMLUnsafe",
            "afterHTMLUnsafe",
            "replaceWithHTMLUnsafe",
            "streamBeforeHTMLUnsafe",
            "streamAfterHTMLUnsafe",
            "streamReplaceWithHTMLUnsafe",
            "before",
            "after",
            "replaceWith",
            "remove",
            "ariaNotify",
            "animate",
            "getAnimations",
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
            .{ "part", "get_part", "set_part" },
            .{ "activeViewTransition", "get_activeViewTransition", null },
            .{ "scrollTop", "get_scrollTop", "set_scrollTop" },
            .{ "scrollLeft", "get_scrollLeft", "set_scrollLeft" },
            .{ "scrollWidth", "get_scrollWidth", null },
            .{ "scrollHeight", "get_scrollHeight", null },
            .{ "clientTop", "get_clientTop", null },
            .{ "clientLeft", "get_clientLeft", null },
            .{ "clientWidth", "get_clientWidth", null },
            .{ "clientHeight", "get_clientHeight", null },
            .{ "currentCSSZoom", "get_currentCSSZoom", null },
            .{ "elementTiming", "get_elementTiming", "set_elementTiming" },
            .{ "onfullscreenchange", "get_onfullscreenchange", "set_onfullscreenchange" },
            .{ "onfullscreenerror", "get_onfullscreenerror", "set_onfullscreenerror" },
            .{ "innerHTML", "get_innerHTML", "set_innerHTML" },
            .{ "outerHTML", "get_outerHTML", "set_outerHTML" },
            .{ "regionOverset", "get_regionOverset", null },
            .{ "children", "get_children", null },
            .{ "firstElementChild", "get_firstElementChild", null },
            .{ "lastElementChild", "get_lastElementChild", null },
            .{ "childElementCount", "get_childElementCount", null },
            .{ "previousElementSibling", "get_previousElementSibling", null },
            .{ "nextElementSibling", "get_nextElementSibling", null },
            .{ "assignedSlot", "get_assignedSlot", null },
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
        };

        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{};

        pub const has_constructor = false;

        /// Members marked with [Unscopable] extended attribute
        pub const unscopables = .{
            "slot",
            "prepend",
            "append",
            "replaceChildren",
            "before",
            "after",
            "replaceWith",
            "remove",
        };
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
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
        .call_afterHTML = &call_afterHTML,
        .call_afterHTMLUnsafe = &call_afterHTMLUnsafe,
        .call_animate = &call_animate,
        .call_append = &call_append,
        .call_appendHTML = &call_appendHTML,
        .call_appendHTMLUnsafe = &call_appendHTMLUnsafe,
        .call_ariaNotify = &call_ariaNotify,
        .call_attachShadow = &call_attachShadow,
        .call_before = &call_before,
        .call_beforeHTML = &call_beforeHTML,
        .call_beforeHTMLUnsafe = &call_beforeHTMLUnsafe,
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
        .call_prependHTML = &call_prependHTML,
        .call_prependHTMLUnsafe = &call_prependHTMLUnsafe,
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
        .call_replaceWithHTML = &call_replaceWithHTML,
        .call_replaceWithHTMLUnsafe = &call_replaceWithHTMLUnsafe,
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
        .call_setHTML = &call_setHTML,
        .call_setHTMLUnsafe = &call_setHTMLUnsafe,
        .call_setPointerCapture = &call_setPointerCapture,
        .call_spatialNavigationSearch = &call_spatialNavigationSearch,
        .call_startViewTransition = &call_startViewTransition,
        .call_streamAfterHTML = &call_streamAfterHTML,
        .call_streamAfterHTMLUnsafe = &call_streamAfterHTMLUnsafe,
        .call_streamAppendHTML = &call_streamAppendHTML,
        .call_streamAppendHTMLUnsafe = &call_streamAppendHTMLUnsafe,
        .call_streamBeforeHTML = &call_streamBeforeHTML,
        .call_streamBeforeHTMLUnsafe = &call_streamBeforeHTMLUnsafe,
        .call_streamHTML = &call_streamHTML,
        .call_streamHTMLUnsafe = &call_streamHTMLUnsafe,
        .call_streamPrependHTML = &call_streamPrependHTML,
        .call_streamPrependHTMLUnsafe = &call_streamPrependHTMLUnsafe,
        .call_streamReplaceWithHTML = &call_streamReplaceWithHTML,
        .call_streamReplaceWithHTMLUnsafe = &call_streamReplaceWithHTMLUnsafe,
        .call_toggleAttribute = &call_toggleAttribute,
        .call_webkitMatchesSelector = &call_webkitMatchesSelector,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates, Meta.name, State);

    /// Make a new instance: the construction chain, this interface's State
    /// and vtable.
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return initChain(allocator, State, &vtable, ctx, .{});
    }

    /// Make a new instance with construction arguments: facts given at
    /// construction, as a C++ constructor's parameters. Each field of `args`
    /// must be taken by an impl on the chain (its `construction_args`).
    pub fn initWith(allocator: std.mem.Allocator, ctx: runtime.Context, args: anytype) !*runtime.Instance {
        inline for (@typeInfo(@TypeOf(args)).@"struct".field_names) |field_name| {
            if (comptime !takesConstructionArg(field_name)) @compileError("Element has no construction argument '" ++ field_name ++ "'");
        }
        return initChain(allocator, State, &vtable, ctx, args);
    }

    /// The construction chain for a descendant's State and vtable, for an
    /// impl that still chains by hand.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return initChain(allocator, StateType, vtable_ptr, ctx, .{});
    }

    /// The construction chain: the parent interface's, then the impl's own
    /// steps (`initOwn`), whose failure unwinds the parent's part and frees
    /// the slot. An impl that still defines `init` chains by hand.
    pub inline fn initChain(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
        args: anytype,
    ) !*runtime.Instance {
        if (comptime @hasDecl(ElementImpl, "init") and @hasDecl(ElementImpl, "initOwn")) @compileError("ElementImpl defines both init and initOwn");
        if (comptime @hasDecl(ElementImpl, "init")) return ElementImpl.init(allocator, StateType, vtable_ptr, ctx);
        const instance = try Meta.ParentInterface.initChain(allocator, StateType, vtable_ptr, ctx, args);
        if (comptime @hasDecl(ElementImpl, "initOwn")) {
            errdefer {
                Meta.ParentInterface.deinitChain(instance);
                runtime.gc.releaseStorage(instance);
            }
            try ElementImpl.initOwn(instance, allocator, StateType, args);
        }
        return instance;
    }

    /// Whether an impl on the construction chain takes the construction
    /// argument `name`. A level that chains by hand passes nothing on.
    pub fn takesConstructionArg(comptime name: []const u8) bool {
        if (comptime @hasDecl(ElementImpl, "init")) return false;
        if (comptime @hasDecl(ElementImpl, "construction_args")) {
            inline for (ElementImpl.construction_args) |arg| {
                if (comptime std.mem.eql(u8, arg, name)) return true;
            }
        }
        return Meta.ParentInterface.takesConstructionArg(name);
    }

    /// The vtable's destructor: the destruction chain.
    pub fn deinit(instance: *runtime.Instance) void {
        deinitChain(instance);
    }

    /// The destruction chain: the impl's own part (`deinitOwn`), then the
    /// parent interface's - construction in reverse. An impl that still
    /// defines `deinit` chains by hand.
    pub inline fn deinitChain(instance: *runtime.Instance) void {
        if (comptime @hasDecl(ElementImpl, "deinit") and @hasDecl(ElementImpl, "deinitOwn")) @compileError("ElementImpl defines both deinit and deinitOwn");
        @import("dom").same_object_cache.endElement(instance, &.{ .{ .field = .class_list, .attribute = "classList" }, .{ .field = .part, .attribute = "part" }, .{ .field = .children, .attribute = "children" } });
        if (comptime @hasDecl(ElementImpl, "deinit")) return ElementImpl.deinit(instance);
        if (comptime @hasDecl(ElementImpl, "deinitOwn")) ElementImpl.deinitOwn(instance);
        Meta.ParentInterface.deinitChain(instance);
    }

    /// The impl's process-wide hooks, installed once at process start
    /// (crane.Process, through the root's process_hooks).
    pub fn installHooks() void {
        const impls = @import("impls");
        if (comptime @hasDecl(impls, "Element")) {
            if (comptime @hasDecl(impls.Element, "installHooks")) impls.Element.installHooks();
        }
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try ElementImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!?runtime.DOMString {
        return try ElementImpl.get_prefix(instance);
    }

    pub fn get_localName(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ElementImpl.get_localName(instance);
    }

    pub fn get_tagName(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ElementImpl.get_tagName(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ElementImpl.get_id(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_id(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try ElementImpl.set_id(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_className(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ElementImpl.get_className(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_className(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try ElementImpl.set_className(instance, value);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_classList(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [SameObject] - Return the instance the element's rare data keeps
        if (@import("dom").same_object_cache.elementGet(instance, .class_list)) |cached| {
            return cached;
        }
        try @import("dom").same_object_cache.elementReserve(instance, .class_list);
        const value = try ElementImpl.get_classList(instance);
        @import("dom").same_object_cache.elementMade(instance, .class_list, value, "classList");
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn set_classList(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'classList' forwards to 'value' on the attribute's value
        const target = try get_classList(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn get_slot(instance: *runtime.Instance) anyerror!runtime.DOMString {
        return try ElementImpl.get_slot(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn set_slot(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try ElementImpl.set_slot(instance, value);
    }

    /// Extended attributes: [SameObject]
    pub fn get_attributes(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.get_attributes(instance);
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_shadowRoot(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_customElementRegistry(instance);
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn get_part(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [SameObject] - Return the instance the element's rare data keeps
        if (@import("dom").same_object_cache.elementGet(instance, .part)) |cached| {
            return cached;
        }
        try @import("dom").same_object_cache.elementReserve(instance, .part);
        const value = try ElementImpl.get_part(instance);
        @import("dom").same_object_cache.elementMade(instance, .part, value, "part");
        return value;
    }

    /// Extended attributes: [SameObject], [PutForwards=value]
    pub fn set_part(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [PutForwards] - Get target object and set the forwarded property
        // Per WebIDL spec: setting 'part' forwards to 'value' on the attribute's value
        const target = try get_part(instance);

        // Use JavaScript [[Set]] semantics to set the forwarded property
        // This respects prototype chain and user-defined setters
        try runtime.setPropertyOnInstance(target, "value", value);
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try ElementImpl.get_activeViewTransition(instance);
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

    const reflection = @import("dom").reflection;

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn get_elementTiming(instance: *runtime.Instance) anyerror!runtime.DOMString {
        if (comptime @hasDecl(ElementImpl, "get_elementTiming")) return try ElementImpl.get_elementTiming(instance);
        return try reflection.get(runtime.DOMString, instance, .{ .name = "elementtiming" });
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_elementTiming(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        if (comptime @hasDecl(ElementImpl, "set_elementTiming")) return try ElementImpl.set_elementTiming(instance, value);
        try reflection.set(runtime.DOMString, instance, .{ .name = "elementtiming" }, value);
    }

    const event_handlers = @import("dom").event_handlers;

    pub fn get_onfullscreenchange(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ElementImpl, "get_onfullscreenchange")) return try ElementImpl.get_onfullscreenchange(instance);
        return event_handlers.value(EventHandler, instance, "onfullscreenchange");
    }

    pub fn set_onfullscreenchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ElementImpl, "set_onfullscreenchange")) return try ElementImpl.set_onfullscreenchange(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onfullscreenchange", value);
    }

    pub fn get_onfullscreenerror(instance: *runtime.Instance) anyerror!EventHandler {
        if (comptime @hasDecl(ElementImpl, "get_onfullscreenerror")) return try ElementImpl.get_onfullscreenerror(instance);
        return event_handlers.value(EventHandler, instance, "onfullscreenerror");
    }

    pub fn set_onfullscreenerror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        if (comptime @hasDecl(ElementImpl, "set_onfullscreenerror")) return try ElementImpl.set_onfullscreenerror(instance, value);
        try event_handlers.setValue(EventHandler, instance, "onfullscreenerror", value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try ElementImpl.set_innerHTML(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_outerHTML(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_outerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_outerHTML(instance: *runtime.Instance, value: typedefs.TrustedHTMLOrDOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        try ElementImpl.set_outerHTML(instance, value);
    }

    pub const get_regionOverset = mixins.Region.get_regionOverset;

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [SameObject] - Return the instance the element's rare data keeps
        if (@import("dom").same_object_cache.elementGet(instance, .children)) |cached| {
            return cached;
        }
        try @import("dom").same_object_cache.elementReserve(instance, .children);
        const value = try mixins.ParentNode.get_children(instance);
        @import("dom").same_object_cache.elementMade(instance, .children, value, "children");
        return value;
    }

    pub const get_firstElementChild = mixins.ParentNode.get_firstElementChild;

    pub const get_lastElementChild = mixins.ParentNode.get_lastElementChild;

    pub const get_childElementCount = mixins.ParentNode.get_childElementCount;

    pub const get_previousElementSibling = mixins.NonDocumentTypeChildNode.get_previousElementSibling;

    pub const get_nextElementSibling = mixins.NonDocumentTypeChildNode.get_nextElementSibling;

    pub const get_assignedSlot = mixins.Slottable.get_assignedSlot;

    /// Extended attributes: [CEReactions], [Reflect]
    pub const get_role = mixins.ARIAMixin.get_role;
    pub const set_role = mixins.ARIAMixin.set_role;

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub const get_ariaActiveDescendantElement = mixins.ARIAMixin.get_ariaActiveDescendantElement;
    pub const set_ariaActiveDescendantElement = mixins.ARIAMixin.set_ariaActiveDescendantElement;

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub const get_ariaAtomic = mixins.ARIAMixin.get_ariaAtomic;
    pub const set_ariaAtomic = mixins.ARIAMixin.set_ariaAtomic;

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub const get_ariaAutoComplete = mixins.ARIAMixin.get_ariaAutoComplete;
    pub const set_ariaAutoComplete = mixins.ARIAMixin.set_ariaAutoComplete;

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub const get_ariaBrailleLabel = mixins.ARIAMixin.get_ariaBrailleLabel;
    pub const set_ariaBrailleLabel = mixins.ARIAMixin.set_ariaBrailleLabel;

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub const get_ariaBrailleRoleDescription = mixins.ARIAMixin.get_ariaBrailleRoleDescription;
    pub const set_ariaBrailleRoleDescription = mixins.ARIAMixin.set_ariaBrailleRoleDescription;

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub const get_ariaBusy = mixins.ARIAMixin.get_ariaBusy;
    pub const set_ariaBusy = mixins.ARIAMixin.set_ariaBusy;

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub const get_ariaChecked = mixins.ARIAMixin.get_ariaChecked;
    pub const set_ariaChecked = mixins.ARIAMixin.set_ariaChecked;

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub const get_ariaColCount = mixins.ARIAMixin.get_ariaColCount;
    pub const set_ariaColCount = mixins.ARIAMixin.set_ariaColCount;

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub const get_ariaColIndex = mixins.ARIAMixin.get_ariaColIndex;
    pub const set_ariaColIndex = mixins.ARIAMixin.set_ariaColIndex;

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub const get_ariaColIndexText = mixins.ARIAMixin.get_ariaColIndexText;
    pub const set_ariaColIndexText = mixins.ARIAMixin.set_ariaColIndexText;

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub const get_ariaColSpan = mixins.ARIAMixin.get_ariaColSpan;
    pub const set_ariaColSpan = mixins.ARIAMixin.set_ariaColSpan;

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub const get_ariaControlsElements = mixins.ARIAMixin.get_ariaControlsElements;
    pub const set_ariaControlsElements = mixins.ARIAMixin.set_ariaControlsElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub const get_ariaCurrent = mixins.ARIAMixin.get_ariaCurrent;
    pub const set_ariaCurrent = mixins.ARIAMixin.set_ariaCurrent;

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub const get_ariaDescribedByElements = mixins.ARIAMixin.get_ariaDescribedByElements;
    pub const set_ariaDescribedByElements = mixins.ARIAMixin.set_ariaDescribedByElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub const get_ariaDescription = mixins.ARIAMixin.get_ariaDescription;
    pub const set_ariaDescription = mixins.ARIAMixin.set_ariaDescription;

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub const get_ariaDetailsElements = mixins.ARIAMixin.get_ariaDetailsElements;
    pub const set_ariaDetailsElements = mixins.ARIAMixin.set_ariaDetailsElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub const get_ariaDisabled = mixins.ARIAMixin.get_ariaDisabled;
    pub const set_ariaDisabled = mixins.ARIAMixin.set_ariaDisabled;

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub const get_ariaErrorMessageElements = mixins.ARIAMixin.get_ariaErrorMessageElements;
    pub const set_ariaErrorMessageElements = mixins.ARIAMixin.set_ariaErrorMessageElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub const get_ariaExpanded = mixins.ARIAMixin.get_ariaExpanded;
    pub const set_ariaExpanded = mixins.ARIAMixin.set_ariaExpanded;

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub const get_ariaFlowToElements = mixins.ARIAMixin.get_ariaFlowToElements;
    pub const set_ariaFlowToElements = mixins.ARIAMixin.set_ariaFlowToElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub const get_ariaHasPopup = mixins.ARIAMixin.get_ariaHasPopup;
    pub const set_ariaHasPopup = mixins.ARIAMixin.set_ariaHasPopup;

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub const get_ariaHidden = mixins.ARIAMixin.get_ariaHidden;
    pub const set_ariaHidden = mixins.ARIAMixin.set_ariaHidden;

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub const get_ariaInvalid = mixins.ARIAMixin.get_ariaInvalid;
    pub const set_ariaInvalid = mixins.ARIAMixin.set_ariaInvalid;

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub const get_ariaKeyShortcuts = mixins.ARIAMixin.get_ariaKeyShortcuts;
    pub const set_ariaKeyShortcuts = mixins.ARIAMixin.set_ariaKeyShortcuts;

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub const get_ariaLabel = mixins.ARIAMixin.get_ariaLabel;
    pub const set_ariaLabel = mixins.ARIAMixin.set_ariaLabel;

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub const get_ariaLabelledByElements = mixins.ARIAMixin.get_ariaLabelledByElements;
    pub const set_ariaLabelledByElements = mixins.ARIAMixin.set_ariaLabelledByElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub const get_ariaLevel = mixins.ARIAMixin.get_ariaLevel;
    pub const set_ariaLevel = mixins.ARIAMixin.set_ariaLevel;

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub const get_ariaLive = mixins.ARIAMixin.get_ariaLive;
    pub const set_ariaLive = mixins.ARIAMixin.set_ariaLive;

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub const get_ariaModal = mixins.ARIAMixin.get_ariaModal;
    pub const set_ariaModal = mixins.ARIAMixin.set_ariaModal;

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub const get_ariaMultiLine = mixins.ARIAMixin.get_ariaMultiLine;
    pub const set_ariaMultiLine = mixins.ARIAMixin.set_ariaMultiLine;

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub const get_ariaMultiSelectable = mixins.ARIAMixin.get_ariaMultiSelectable;
    pub const set_ariaMultiSelectable = mixins.ARIAMixin.set_ariaMultiSelectable;

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub const get_ariaOrientation = mixins.ARIAMixin.get_ariaOrientation;
    pub const set_ariaOrientation = mixins.ARIAMixin.set_ariaOrientation;

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub const get_ariaOwnsElements = mixins.ARIAMixin.get_ariaOwnsElements;
    pub const set_ariaOwnsElements = mixins.ARIAMixin.set_ariaOwnsElements;

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub const get_ariaPlaceholder = mixins.ARIAMixin.get_ariaPlaceholder;
    pub const set_ariaPlaceholder = mixins.ARIAMixin.set_ariaPlaceholder;

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub const get_ariaPosInSet = mixins.ARIAMixin.get_ariaPosInSet;
    pub const set_ariaPosInSet = mixins.ARIAMixin.set_ariaPosInSet;

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub const get_ariaPressed = mixins.ARIAMixin.get_ariaPressed;
    pub const set_ariaPressed = mixins.ARIAMixin.set_ariaPressed;

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub const get_ariaReadOnly = mixins.ARIAMixin.get_ariaReadOnly;
    pub const set_ariaReadOnly = mixins.ARIAMixin.set_ariaReadOnly;

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub const get_ariaRelevant = mixins.ARIAMixin.get_ariaRelevant;
    pub const set_ariaRelevant = mixins.ARIAMixin.set_ariaRelevant;

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub const get_ariaRequired = mixins.ARIAMixin.get_ariaRequired;
    pub const set_ariaRequired = mixins.ARIAMixin.set_ariaRequired;

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub const get_ariaRoleDescription = mixins.ARIAMixin.get_ariaRoleDescription;
    pub const set_ariaRoleDescription = mixins.ARIAMixin.set_ariaRoleDescription;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub const get_ariaRowCount = mixins.ARIAMixin.get_ariaRowCount;
    pub const set_ariaRowCount = mixins.ARIAMixin.set_ariaRowCount;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub const get_ariaRowIndex = mixins.ARIAMixin.get_ariaRowIndex;
    pub const set_ariaRowIndex = mixins.ARIAMixin.set_ariaRowIndex;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub const get_ariaRowIndexText = mixins.ARIAMixin.get_ariaRowIndexText;
    pub const set_ariaRowIndexText = mixins.ARIAMixin.set_ariaRowIndexText;

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub const get_ariaRowSpan = mixins.ARIAMixin.get_ariaRowSpan;
    pub const set_ariaRowSpan = mixins.ARIAMixin.set_ariaRowSpan;

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub const get_ariaSelected = mixins.ARIAMixin.get_ariaSelected;
    pub const set_ariaSelected = mixins.ARIAMixin.set_ariaSelected;

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub const get_ariaSetSize = mixins.ARIAMixin.get_ariaSetSize;
    pub const set_ariaSetSize = mixins.ARIAMixin.set_ariaSetSize;

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub const get_ariaSort = mixins.ARIAMixin.get_ariaSort;
    pub const set_ariaSort = mixins.ARIAMixin.set_ariaSort;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub const get_ariaValueMax = mixins.ARIAMixin.get_ariaValueMax;
    pub const set_ariaValueMax = mixins.ARIAMixin.set_ariaValueMax;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub const get_ariaValueMin = mixins.ARIAMixin.get_ariaValueMin;
    pub const set_ariaValueMin = mixins.ARIAMixin.set_ariaValueMin;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub const get_ariaValueNow = mixins.ARIAMixin.get_ariaValueNow;
    pub const set_ariaValueNow = mixins.ARIAMixin.set_ariaValueNow;

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub const get_ariaValueText = mixins.ARIAMixin.get_ariaValueText;
    pub const set_ariaValueText = mixins.ARIAMixin.set_ariaValueText;

    pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.call_getSpatialNavigationContainer(instance);
    }

    pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
        return try ElementImpl.call_hasAttributes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamPrependHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ElementImpl.call_streamPrependHTML(instance, options);
    }

    pub fn call_insertAdjacentText(instance: *runtime.Instance, where: runtime.DOMString, data: runtime.DOMString) anyerror!void {
        return try ElementImpl.call_insertAdjacentText(instance, where, data);
    }

    pub const call_moveBefore = mixins.ParentNode.call_moveBefore;

    pub const call_streamBeforeHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_streamBeforeHTMLUnsafe;

    pub const call_beforeHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_beforeHTMLUnsafe;

    pub const call_streamAfterHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_streamAfterHTMLUnsafe;

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: runtime.DOMString, element: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = ElementImpl.call_insertAdjacentElement(instance, where, element) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = if (result) |r| runtime.SlabAllocator.generationOf(r) else 0;
        runtime.CEReactions.end(ce_scope);
        if (result) |r| if (runtime.SlabAllocator.generationOf(r) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub const call_append = mixins.ParentNode.call_append;

    pub const call_getBoxQuads = mixins.GeometryUtils.call_getBoxQuads;

    /// Extended attributes: [CEReactions]
    pub fn call_appendHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_appendHTMLUnsafe(instance, html, options);
    }

    pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        return try ElementImpl.call_setPointerCapture(instance, pointerId);
    }

    pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!bool {
        return try ElementImpl.call_hasAttributeNS(instance, namespace, localName);
    }

    pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
        return try ElementImpl.call_hasPointerCapture(instance, pointerId);
    }

    pub fn call_focusableAreas(instance: *runtime.Instance, option: webidl.Opt(FocusableAreasOption)) anyerror!runtime.JSValue {
        return try ElementImpl.call_focusableAreas(instance, option);
    }

    pub const call_before = mixins.ChildNode.call_before;

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, qualifiedName: runtime.DOMString, value: TrustedTypeOrDOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_setAttributeNS(instance, namespace, qualifiedName, value);
    }

    pub fn call_closest(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!?*runtime.Instance {
        return try ElementImpl.call_closest(instance, selectors);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object
        return try ElementImpl.call_getBoundingClientRect(instance);
    }

    pub const call_streamReplaceWithHTML = mixins.NonDocumentTypeChildNode.call_streamReplaceWithHTML;

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: runtime.DOMString) anyerror!*runtime.Instance {
        return try ElementImpl.call_getElementsByClassName(instance, classNames);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = ElementImpl.call_setAttributeNode(instance, attr) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = if (result) |r| runtime.SlabAllocator.generationOf(r) else 0;
        runtime.CEReactions.end(ce_scope);
        if (result) |r| if (runtime.SlabAllocator.generationOf(r) != result_generation) return error.InvalidStateError;
        return result;
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_streamHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        // [NewObject] - Caller owns the returned object

        const result = ElementImpl.call_streamHTMLUnsafe(instance, options) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub const call_convertQuadFromNode = mixins.GeometryUtils.call_convertQuadFromNode;

    pub const call_beforeHTML = mixins.NonDocumentTypeChildNode.call_beforeHTML;

    pub fn call_requestPointerLock(instance: *runtime.Instance, options: webidl.Opt(PointerLockOptions)) anyerror!runtime.JSValue {
        return try ElementImpl.call_requestPointerLock(instance, options);
    }

    pub const call_after = mixins.ChildNode.call_after;

    pub const call_remove = mixins.ChildNode.call_remove;

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!?*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = ElementImpl.call_setAttributeNodeNS(instance, attr) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = if (result) |r| runtime.SlabAllocator.generationOf(r) else 0;
        runtime.CEReactions.end(ce_scope);
        if (result) |r| if (runtime.SlabAllocator.generationOf(r) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub const call_replaceWithHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_replaceWithHTMLUnsafe;

    pub const call_streamBeforeHTML = mixins.NonDocumentTypeChildNode.call_streamBeforeHTML;

    pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?runtime.DOMString {
        return try ElementImpl.call_getAttributeNS(instance, namespace, localName);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: webidl.Opt(ViewTransitionUpdateCallbackOrStartViewTransitionOptions)) anyerror!*runtime.Instance {
        return try ElementImpl.call_startViewTransition(instance, callbackOptions);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?runtime.DOMString {
        return try ElementImpl.call_getAttribute(instance, qualifiedName);
    }

    pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!?*runtime.Instance {
        return try ElementImpl.call_getAttributeNodeNS(instance, namespace, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_appendHTML(instance, html, options);
    }

    pub fn call_scroll(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        return try ElementImpl.call_scroll(instance, options);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!*runtime.Instance {
        return try ElementImpl.call_getElementsByTagName(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_prependHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_prependHTML(instance, html, options);
    }

    pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: SpatialNavigationDirection, options: webidl.Opt(SpatialNavigationSearchOptions)) anyerror!?*runtime.Instance {
        return try ElementImpl.call_spatialNavigationSearch(instance, dir, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, value: TrustedTypeOrDOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_setAttribute(instance, qualifiedName, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString, force: webidl.Opt(bool)) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_toggleAttribute(instance, qualifiedName, force);
    }

    pub const call_querySelector = mixins.ParentNode.call_querySelector;

    pub const call_querySelectorAll = mixins.ParentNode.call_querySelectorAll;

    pub const call_afterHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_afterHTMLUnsafe;

    /// Extended attributes: [SameObject]
    pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.call_computedStyleMap(instance);
    }

    pub const call_streamReplaceWithHTMLUnsafe = mixins.NonDocumentTypeChildNode.call_streamReplaceWithHTMLUnsafe;

    pub const call_afterHTML = mixins.NonDocumentTypeChildNode.call_afterHTML;

    pub const call_animate = mixins.Animatable.call_animate;

    /// Extended attributes: [CEReactions]
    pub fn call_prependHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_prependHTMLUnsafe(instance, html, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamAppendHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ElementImpl.call_streamAppendHTML(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: TrustedHTMLOrDOMString, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_setHTMLUnsafe(instance, html, options);
    }

    pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!?*runtime.Instance {
        return try ElementImpl.call_getAttributeNode(instance, qualifiedName);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_streamHTML(instance: *runtime.Instance, options: webidl.Opt(SetHTMLOptions)) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        // [NewObject] - Caller owns the returned object

        const result = ElementImpl.call_streamHTML(instance, options) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub fn call_matches(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
        return try ElementImpl.call_matches(instance, selectors);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: webidl.Opt(GetHTMLOptions)) anyerror!runtime.DOMString {
        return try ElementImpl.call_getHTML(instance, options);
    }

    pub fn call_scrollBy(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        return try ElementImpl.call_scrollBy(instance, options);
    }

    pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ElementImpl.call_getAttributeNames(instance);
    }

    pub const call_convertPointFromNode = mixins.GeometryUtils.call_convertPointFromNode;

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!*runtime.Instance {
        return try ElementImpl.call_getElementsByTagNameNS(instance, namespace, localName);
    }

    pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: runtime.DOMString) anyerror!bool {
        return try ElementImpl.call_webkitMatchesSelector(instance, selectors);
    }

    pub const call_replaceWith = mixins.ChildNode.call_replaceWith;

    pub const call_replaceWithHTML = mixins.NonDocumentTypeChildNode.call_replaceWithHTML;

    /// Extended attributes: [NewObject]
    pub fn call_streamAppendHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ElementImpl.call_streamAppendHTMLUnsafe(instance, options);
    }

    pub const call_convertRectFromNode = mixins.GeometryUtils.call_convertRectFromNode;

    pub const call_ariaNotify = mixins.ARIANotifyMixin.call_ariaNotify;

    pub fn call_scrollTo(instance: *runtime.Instance, options: webidl.Opt(ScrollToOptions)) anyerror!runtime.JSValue {
        return try ElementImpl.call_scrollTo(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTML(instance: *runtime.Instance, html: runtime.DOMString, options: webidl.Opt(SetHTMLOptions)) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_setHTML(instance, html, options);
    }

    pub const call_replaceChildren = mixins.ParentNode.call_replaceChildren;

    pub fn call_requestFullscreen(instance: *runtime.Instance, options: webidl.Opt(FullscreenOptions)) anyerror!runtime.JSValue {
        return try ElementImpl.call_requestFullscreen(instance, options);
    }

    /// Extended attributes: [NewObject]
    pub fn call_streamPrependHTMLUnsafe(instance: *runtime.Instance, options: webidl.Opt(SetHTMLUnsafeOptionsOrTrustedHTMLParserOptions)) anyerror!*runtime.Instance {
        // [NewObject] - Caller owns the returned object

        return try ElementImpl.call_streamPrependHTMLUnsafe(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_removeAttribute(instance, qualifiedName);
    }

    pub const call_getRegionFlowRanges = mixins.Region.call_getRegionFlowRanges;

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: *runtime.Instance) anyerror!*runtime.Instance {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);

        const result = ElementImpl.call_removeAttributeNode(instance, attr) catch |err| {
            runtime.CEReactions.end(ce_scope);
            return err;
        };
        // A result the reactions freed (its realm ended) is not returned.
        const result_generation = runtime.SlabAllocator.generationOf(result);
        runtime.CEReactions.end(ce_scope);
        if (runtime.SlabAllocator.generationOf(result) != result_generation) return error.InvalidStateError;
        return result;
    }

    pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: runtime.DOMString) anyerror!bool {
        return try ElementImpl.call_hasAttribute(instance, qualifiedName);
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ElementImpl.call_getClientRects(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: runtime.DOMString, string: TrustedHTMLOrDOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_insertAdjacentHTML(instance, position, string);
    }

    pub const call_prepend = mixins.ParentNode.call_prepend;

    pub fn call_scrollIntoView(instance: *runtime.Instance, arg: webidl.Opt(BooleanOrScrollIntoViewOptions)) anyerror!runtime.JSValue {
        return try ElementImpl.call_scrollIntoView(instance, arg);
    }

    pub const call_streamAfterHTML = mixins.NonDocumentTypeChildNode.call_streamAfterHTML;

    pub fn call_attachShadow(instance: *runtime.Instance, init_data: ShadowRootInit) anyerror!*runtime.Instance {
        return try ElementImpl.call_attachShadow(instance, init_data);
    }

    pub const call_getAnimations = mixins.Animatable.call_getAnimations;

    pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        return try ElementImpl.call_releasePointerCapture(instance, pointerId);
    }

    pub fn call_pseudo(instance: *runtime.Instance, @"type": CSSOMString) anyerror!?*runtime.Instance {
        return try ElementImpl.call_pseudo(instance, @"type");
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: ?runtime.DOMString, localName: runtime.DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        const ce_scope = runtime.CEReactions.begin(instance);
        defer runtime.CEReactions.end(ce_scope);

        return try ElementImpl.call_removeAttributeNS(instance, namespace, localName);
    }

    pub fn call_checkVisibility(instance: *runtime.Instance, options: webidl.Opt(CheckVisibilityOptions)) anyerror!bool {
        return try ElementImpl.call_checkVisibility(instance, options);
    }

    pub fn call_scroll__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        if (comptime @hasDecl(ElementImpl, "call_scroll__1")) {
            return try ElementImpl.call_scroll__1(instance, x, y);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_scrollBy__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        if (comptime @hasDecl(ElementImpl, "call_scrollBy__1")) {
            return try ElementImpl.call_scrollBy__1(instance, x, y);
        } else {
            return error.NotImplemented;
        }
    }

    pub fn call_scrollTo__1(instance: *runtime.Instance, x: f64, y: f64) anyerror!runtime.JSValue {
        if (comptime @hasDecl(ElementImpl, "call_scrollTo__1")) {
            return try ElementImpl.call_scrollTo__1(instance, x, y);
        } else {
            return error.NotImplemented;
        }
    }

    /// WebIDL overload sets: every overload of each overloaded operation,
    /// in IDL order, for the overload resolution algorithm
    /// (webidl.overload_resolution). The binding is installed for the first
    /// overload and forwards to the one the arguments select.
    pub const overloads = .{
        .{ "scroll", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_scroll", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_scroll__1", .implemented = @hasDecl(ElementImpl, "call_scroll__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "scrollBy", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_scrollBy", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_scrollBy__1", .implemented = @hasDecl(ElementImpl, "call_scrollBy__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
        .{ "scrollTo", &[_]webidl.overload_resolution.Overload{
            .{ .function = "call_scrollTo", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
            .{ .function = "call_scrollTo__1", .implemented = @hasDecl(ElementImpl, "call_scrollTo__1"), .args = &.{ .{ .kinds = &.{.numeric} }, .{ .kinds = &.{.numeric} } } },
        } },
    };

    /// WebIDL [LegacyNullToEmptyString]: the values null converts to "" for
    /// (bit i = argument i; an attribute setter's value is bit 0).
    pub const legacy_null_to_empty = .{
        .{ "set_innerHTML", 0b1 },
        .{ "set_outerHTML", 0b1 },
    };

    /// Nullable callback attributes with [LegacyTreatNonObjectAsNull].
    pub const legacy_treat_non_object_as_null = .{ "set_onfullscreenchange", "set_onfullscreenerror" };

    /// WebIDL `object` arguments (or sequences of `object`): a value that is
    /// not an Object throws a TypeError (bit i = argument i).
    pub const object_arguments = .{
        .{ "call_animate", 0b1 },
    };

    /// WebIDL interface types: the interface each interface-typed argument
    /// and attribute value converts to - a TypeError unless the value implements
    /// it (function, argument index - an attribute setter's value is 0 -,
    /// interface; a nullable, sequence or record value by its elements').
    pub const interface_arguments = .{
        .{ "set_ariaActiveDescendantElement", 0, "Element" },
        .{ "set_ariaControlsElements", 0, "Element" },
        .{ "set_ariaDescribedByElements", 0, "Element" },
        .{ "set_ariaDetailsElements", 0, "Element" },
        .{ "set_ariaErrorMessageElements", 0, "Element" },
        .{ "set_ariaFlowToElements", 0, "Element" },
        .{ "set_ariaLabelledByElements", 0, "Element" },
        .{ "set_ariaOwnsElements", 0, "Element" },
        .{ "call_moveBefore", 0, "Node" },
        .{ "call_moveBefore", 1, "Node" },
        .{ "call_insertAdjacentElement", 1, "Element" },
        .{ "call_setAttributeNode", 0, "Attr" },
        .{ "call_setAttributeNodeNS", 0, "Attr" },
        .{ "call_convertRectFromNode", 0, "DOMRectReadOnly" },
        .{ "call_removeAttributeNode", 0, "Attr" },
    };

    /// WebIDL: operations whose return type is a promise - an exception in
    /// their steps becomes a rejected promise.
    pub const promise_returning = .{
        "call_requestPointerLock",
        "call_scroll",
        "call_scroll__1",
        "call_scrollBy",
        "call_scrollBy__1",
        "call_scrollTo",
        "call_scrollTo__1",
        "call_requestFullscreen",
        "call_scrollIntoView",
    };

    /// HTML [CEReactions]: the functions that run a custom element reactions
    /// bracket - the binding dispatches each in a catch scope, where
    /// engine.withPendingExceptionSetAside sets aside what the member leaves
    /// pending.
    pub const ce_reactions = .{
        "set_id",
        "set_className",
        "set_slot",
        "set_elementTiming",
        "set_innerHTML",
        "set_outerHTML",
        "set_role",
        "set_ariaActiveDescendantElement",
        "set_ariaAtomic",
        "set_ariaAutoComplete",
        "set_ariaBrailleLabel",
        "set_ariaBrailleRoleDescription",
        "set_ariaBusy",
        "set_ariaChecked",
        "set_ariaColCount",
        "set_ariaColIndex",
        "set_ariaColIndexText",
        "set_ariaColSpan",
        "set_ariaControlsElements",
        "set_ariaCurrent",
        "set_ariaDescribedByElements",
        "set_ariaDescription",
        "set_ariaDetailsElements",
        "set_ariaDisabled",
        "set_ariaErrorMessageElements",
        "set_ariaExpanded",
        "set_ariaFlowToElements",
        "set_ariaHasPopup",
        "set_ariaHidden",
        "set_ariaInvalid",
        "set_ariaKeyShortcuts",
        "set_ariaLabel",
        "set_ariaLabelledByElements",
        "set_ariaLevel",
        "set_ariaLive",
        "set_ariaModal",
        "set_ariaMultiLine",
        "set_ariaMultiSelectable",
        "set_ariaOrientation",
        "set_ariaOwnsElements",
        "set_ariaPlaceholder",
        "set_ariaPosInSet",
        "set_ariaPressed",
        "set_ariaReadOnly",
        "set_ariaRelevant",
        "set_ariaRequired",
        "set_ariaRoleDescription",
        "set_ariaRowCount",
        "set_ariaRowIndex",
        "set_ariaRowIndexText",
        "set_ariaRowSpan",
        "set_ariaSelected",
        "set_ariaSetSize",
        "set_ariaSort",
        "set_ariaValueMax",
        "set_ariaValueMin",
        "set_ariaValueNow",
        "set_ariaValueText",
        "call_moveBefore",
        "call_beforeHTMLUnsafe",
        "call_insertAdjacentElement",
        "call_append",
        "call_appendHTMLUnsafe",
        "call_before",
        "call_setAttributeNS",
        "call_streamReplaceWithHTML",
        "call_setAttributeNode",
        "call_streamHTMLUnsafe",
        "call_beforeHTML",
        "call_after",
        "call_remove",
        "call_setAttributeNodeNS",
        "call_replaceWithHTMLUnsafe",
        "call_appendHTML",
        "call_prependHTML",
        "call_setAttribute",
        "call_toggleAttribute",
        "call_afterHTMLUnsafe",
        "call_streamReplaceWithHTMLUnsafe",
        "call_afterHTML",
        "call_prependHTMLUnsafe",
        "call_setHTMLUnsafe",
        "call_streamHTML",
        "call_replaceWith",
        "call_replaceWithHTML",
        "call_setHTML",
        "call_replaceChildren",
        "call_removeAttribute",
        "call_removeAttributeNode",
        "call_insertAdjacentHTML",
        "call_prepend",
        "call_removeAttributeNS",
    };
};

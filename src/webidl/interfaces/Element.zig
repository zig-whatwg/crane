//! Generated from: dom.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const ElementImpl = @import("impls").Element;
const Node = @import("interfaces").Node;
const ARIAMixin = @import("interfaces").ARIAMixin;
const Animatable = @import("interfaces").Animatable;
const Region = @import("interfaces").Region;
const ParentNode = @import("interfaces").ParentNode;
const NonDocumentTypeChildNode = @import("interfaces").NonDocumentTypeChildNode;
const ChildNode = @import("interfaces").ChildNode;
const Slottable = @import("interfaces").Slottable;
const GeometryUtils = @import("interfaces").GeometryUtils;
const CSSOMString = @import("interfaces").CSSOMString;
const HTMLCollection = @import("interfaces").HTMLCollection;
const object = @import("interfaces").object;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const GeometryNode = @import("typedefs").GeometryNode;
const NamedNodeMap = @import("interfaces").NamedNodeMap;
const (unrestricted double or KeyframeAnimationOptions) = @import("interfaces").(unrestricted double or KeyframeAnimationOptions);
const FrozenArray<Element> = @import("interfaces").FrozenArray<Element>;
const CheckVisibilityOptions = @import("dictionaries").CheckVisibilityOptions;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const FocusableAreasOption = @import("dictionaries").FocusableAreasOption;
const CSSPseudoElement = @import("interfaces").CSSPseudoElement;
const (ViewTransitionUpdateCallback or StartViewTransitionOptions) = @import("interfaces").(ViewTransitionUpdateCallback or StartViewTransitionOptions);
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Animation = @import("interfaces").Animation;
const sequence = @import("interfaces").sequence;
const (TrustedHTML or DOMString) = @import("interfaces").(TrustedHTML or DOMString);
const DOMRectList = @import("interfaces").DOMRectList;
const DOMString = @import("typedefs").DOMString;
const GetHTMLOptions = @import("dictionaries").GetHTMLOptions;
const ScrollToOptions = @import("dictionaries").ScrollToOptions;
const HTMLSlotElement = @import("interfaces").HTMLSlotElement;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const DOMTokenList = @import("interfaces").DOMTokenList;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const DOMRect = @import("interfaces").DOMRect;
const ViewTransition = @import("interfaces").ViewTransition;
const SpatialNavigationSearchOptions = @import("dictionaries").SpatialNavigationSearchOptions;
const GetAnimationsOptions = @import("dictionaries").GetAnimationsOptions;
const EventHandler = @import("typedefs").EventHandler;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const SpatialNavigationDirection = @import("enums").SpatialNavigationDirection;
const ShadowRoot = @import("interfaces").ShadowRoot;
const Attr = @import("interfaces").Attr;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const FullscreenOptions = @import("dictionaries").FullscreenOptions;
const NodeList = @import("interfaces").NodeList;
const (Node or DOMString) = @import("interfaces").(Node or DOMString);
const DOMPoint = @import("interfaces").DOMPoint;
const (boolean or ScrollIntoViewOptions) = @import("interfaces").(boolean or ScrollIntoViewOptions);
const PointerLockOptions = @import("dictionaries").PointerLockOptions;
const ShadowRootInit = @import("dictionaries").ShadowRootInit;

pub const Element = struct {
    pub const Meta = struct {
        pub const name = "Element";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *Node;
        pub const MixinTypes = .{
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
    };

    pub const State = runtime.FlattenedState(
        struct {
            namespaceURI: ?runtime.DOMString = null,
            prefix: ?runtime.DOMString = null,
            localName: runtime.DOMString = undefined,
            tagName: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            className: runtime.DOMString = undefined,
            classList: DOMTokenList = undefined,
            slot: runtime.DOMString = undefined,
            attributes: NamedNodeMap = undefined,
            shadowRoot: ?ShadowRoot = null,
            customElementRegistry: ?CustomElementRegistry = null,
            onfullscreenchange: EventHandler = undefined,
            onfullscreenerror: EventHandler = undefined,
            elementTiming: runtime.DOMString = undefined,
            part: DOMTokenList = undefined,
            activeViewTransition: ?ViewTransition = null,
            innerHTML: (TrustedHTML or DOMString) = undefined,
            outerHTML: (TrustedHTML or DOMString) = undefined,
            scrollTop: f64 = undefined,
            scrollLeft: f64 = undefined,
            scrollWidth: i32 = undefined,
            scrollHeight: i32 = undefined,
            clientTop: i32 = undefined,
            clientLeft: i32 = undefined,
            clientWidth: i32 = undefined,
            clientHeight: i32 = undefined,
            currentCSSZoom: f64 = undefined,
            role: ?runtime.DOMString = null,
            ariaActiveDescendantElement: ?Element = null,
            ariaAtomic: ?runtime.DOMString = null,
            ariaAutoComplete: ?runtime.DOMString = null,
            ariaBrailleLabel: ?runtime.DOMString = null,
            ariaBrailleRoleDescription: ?runtime.DOMString = null,
            ariaBusy: ?runtime.DOMString = null,
            ariaChecked: ?runtime.DOMString = null,
            ariaColCount: ?runtime.DOMString = null,
            ariaColIndex: ?runtime.DOMString = null,
            ariaColIndexText: ?runtime.DOMString = null,
            ariaColSpan: ?runtime.DOMString = null,
            ariaControlsElements: ?FrozenArray<Element> = null,
            ariaCurrent: ?runtime.DOMString = null,
            ariaDescribedByElements: ?FrozenArray<Element> = null,
            ariaDescription: ?runtime.DOMString = null,
            ariaDetailsElements: ?FrozenArray<Element> = null,
            ariaDisabled: ?runtime.DOMString = null,
            ariaErrorMessageElements: ?FrozenArray<Element> = null,
            ariaExpanded: ?runtime.DOMString = null,
            ariaFlowToElements: ?FrozenArray<Element> = null,
            ariaHasPopup: ?runtime.DOMString = null,
            ariaHidden: ?runtime.DOMString = null,
            ariaInvalid: ?runtime.DOMString = null,
            ariaKeyShortcuts: ?runtime.DOMString = null,
            ariaLabel: ?runtime.DOMString = null,
            ariaLabelledByElements: ?FrozenArray<Element> = null,
            ariaLevel: ?runtime.DOMString = null,
            ariaLive: ?runtime.DOMString = null,
            ariaModal: ?runtime.DOMString = null,
            ariaMultiLine: ?runtime.DOMString = null,
            ariaMultiSelectable: ?runtime.DOMString = null,
            ariaOrientation: ?runtime.DOMString = null,
            ariaOwnsElements: ?FrozenArray<Element> = null,
            ariaPlaceholder: ?runtime.DOMString = null,
            ariaPosInSet: ?runtime.DOMString = null,
            ariaPressed: ?runtime.DOMString = null,
            ariaReadOnly: ?runtime.DOMString = null,
            ariaRelevant: ?runtime.DOMString = null,
            ariaRequired: ?runtime.DOMString = null,
            ariaRoleDescription: ?runtime.DOMString = null,
            ariaRowCount: ?runtime.DOMString = null,
            ariaRowIndex: ?runtime.DOMString = null,
            ariaRowIndexText: ?runtime.DOMString = null,
            ariaRowSpan: ?runtime.DOMString = null,
            ariaSelected: ?runtime.DOMString = null,
            ariaSetSize: ?runtime.DOMString = null,
            ariaSort: ?runtime.DOMString = null,
            ariaValueMax: ?runtime.DOMString = null,
            ariaValueMin: ?runtime.DOMString = null,
            ariaValueNow: ?runtime.DOMString = null,
            ariaValueText: ?runtime.DOMString = null,
            regionOverset: CSSOMString = undefined,
            children: HTMLCollection = undefined,
            firstElementChild: ?Element = null,
            lastElementChild: ?Element = null,
            childElementCount: u32 = undefined,
            previousElementSibling: ?Element = null,
            nextElementSibling: ?Element = null,
            assignedSlot: ?HTMLSlotElement = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(Element, .{
        .deinit_fn = &deinit_wrapper,

        .get_ATTRIBUTE_NODE = &Node.get_ATTRIBUTE_NODE,
        .get_CDATA_SECTION_NODE = &Node.get_CDATA_SECTION_NODE,
        .get_COMMENT_NODE = &Node.get_COMMENT_NODE,
        .get_DOCUMENT_FRAGMENT_NODE = &Node.get_DOCUMENT_FRAGMENT_NODE,
        .get_DOCUMENT_NODE = &Node.get_DOCUMENT_NODE,
        .get_DOCUMENT_POSITION_CONTAINED_BY = &Node.get_DOCUMENT_POSITION_CONTAINED_BY,
        .get_DOCUMENT_POSITION_CONTAINS = &Node.get_DOCUMENT_POSITION_CONTAINS,
        .get_DOCUMENT_POSITION_DISCONNECTED = &Node.get_DOCUMENT_POSITION_DISCONNECTED,
        .get_DOCUMENT_POSITION_FOLLOWING = &Node.get_DOCUMENT_POSITION_FOLLOWING,
        .get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC = &Node.get_DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC,
        .get_DOCUMENT_POSITION_PRECEDING = &Node.get_DOCUMENT_POSITION_PRECEDING,
        .get_DOCUMENT_TYPE_NODE = &Node.get_DOCUMENT_TYPE_NODE,
        .get_ELEMENT_NODE = &Node.get_ELEMENT_NODE,
        .get_ENTITY_NODE = &Node.get_ENTITY_NODE,
        .get_ENTITY_REFERENCE_NODE = &Node.get_ENTITY_REFERENCE_NODE,
        .get_NOTATION_NODE = &Node.get_NOTATION_NODE,
        .get_PROCESSING_INSTRUCTION_NODE = &Node.get_PROCESSING_INSTRUCTION_NODE,
        .get_TEXT_NODE = &Node.get_TEXT_NODE,
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
        .get_baseURI = &get_baseURI,
        .get_childElementCount = &get_childElementCount,
        .get_childNodes = &get_childNodes,
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
        .get_firstChild = &get_firstChild,
        .get_firstElementChild = &get_firstElementChild,
        .get_id = &get_id,
        .get_innerHTML = &get_innerHTML,
        .get_isConnected = &get_isConnected,
        .get_lastChild = &get_lastChild,
        .get_lastElementChild = &get_lastElementChild,
        .get_localName = &get_localName,
        .get_namespaceURI = &get_namespaceURI,
        .get_nextElementSibling = &get_nextElementSibling,
        .get_nextSibling = &get_nextSibling,
        .get_nodeName = &get_nodeName,
        .get_nodeType = &get_nodeType,
        .get_nodeValue = &get_nodeValue,
        .get_onfullscreenchange = &get_onfullscreenchange,
        .get_onfullscreenerror = &get_onfullscreenerror,
        .get_outerHTML = &get_outerHTML,
        .get_ownerDocument = &get_ownerDocument,
        .get_parentElement = &get_parentElement,
        .get_parentNode = &get_parentNode,
        .get_part = &get_part,
        .get_prefix = &get_prefix,
        .get_previousElementSibling = &get_previousElementSibling,
        .get_previousSibling = &get_previousSibling,
        .get_regionOverset = &get_regionOverset,
        .get_role = &get_role,
        .get_scrollHeight = &get_scrollHeight,
        .get_scrollLeft = &get_scrollLeft,
        .get_scrollTop = &get_scrollTop,
        .get_scrollWidth = &get_scrollWidth,
        .get_shadowRoot = &get_shadowRoot,
        .get_slot = &get_slot,
        .get_tagName = &get_tagName,
        .get_textContent = &get_textContent,

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
        .set_className = &set_className,
        .set_elementTiming = &set_elementTiming,
        .set_id = &set_id,
        .set_innerHTML = &set_innerHTML,
        .set_nodeValue = &set_nodeValue,
        .set_onfullscreenchange = &set_onfullscreenchange,
        .set_onfullscreenerror = &set_onfullscreenerror,
        .set_outerHTML = &set_outerHTML,
        .set_role = &set_role,
        .set_scrollLeft = &set_scrollLeft,
        .set_scrollTop = &set_scrollTop,
        .set_slot = &set_slot,
        .set_textContent = &set_textContent,

        .call_addEventListener = &call_addEventListener,
        .call_after = &call_after,
        .call_animate = &call_animate,
        .call_append = &call_append,
        .call_appendChild = &call_appendChild,
        .call_attachShadow = &call_attachShadow,
        .call_before = &call_before,
        .call_checkVisibility = &call_checkVisibility,
        .call_cloneNode = &call_cloneNode,
        .call_closest = &call_closest,
        .call_compareDocumentPosition = &call_compareDocumentPosition,
        .call_computedStyleMap = &call_computedStyleMap,
        .call_contains = &call_contains,
        .call_convertPointFromNode = &call_convertPointFromNode,
        .call_convertQuadFromNode = &call_convertQuadFromNode,
        .call_convertRectFromNode = &call_convertRectFromNode,
        .call_dispatchEvent = &call_dispatchEvent,
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
        .call_getRootNode = &call_getRootNode,
        .call_getSpatialNavigationContainer = &call_getSpatialNavigationContainer,
        .call_hasAttribute = &call_hasAttribute,
        .call_hasAttributeNS = &call_hasAttributeNS,
        .call_hasAttributes = &call_hasAttributes,
        .call_hasChildNodes = &call_hasChildNodes,
        .call_hasPointerCapture = &call_hasPointerCapture,
        .call_insertAdjacentElement = &call_insertAdjacentElement,
        .call_insertAdjacentHTML = &call_insertAdjacentHTML,
        .call_insertAdjacentText = &call_insertAdjacentText,
        .call_insertBefore = &call_insertBefore,
        .call_isDefaultNamespace = &call_isDefaultNamespace,
        .call_isEqualNode = &call_isEqualNode,
        .call_isSameNode = &call_isSameNode,
        .call_lookupNamespaceURI = &call_lookupNamespaceURI,
        .call_lookupPrefix = &call_lookupPrefix,
        .call_matches = &call_matches,
        .call_moveBefore = &call_moveBefore,
        .call_normalize = &call_normalize,
        .call_prepend = &call_prepend,
        .call_pseudo = &call_pseudo,
        .call_querySelector = &call_querySelector,
        .call_querySelectorAll = &call_querySelectorAll,
        .call_releasePointerCapture = &call_releasePointerCapture,
        .call_remove = &call_remove,
        .call_removeAttribute = &call_removeAttribute,
        .call_removeAttributeNS = &call_removeAttributeNS,
        .call_removeAttributeNode = &call_removeAttributeNode,
        .call_removeChild = &call_removeChild,
        .call_removeEventListener = &call_removeEventListener,
        .call_replaceChild = &call_replaceChild,
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
        ElementImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ElementImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_nodeType(instance: *runtime.Instance) anyerror!u16 {
        return try ElementImpl.get_nodeType(instance);
    }

    pub fn get_nodeName(instance: *runtime.Instance) anyerror!DOMString {
        return try ElementImpl.get_nodeName(instance);
    }

    pub fn get_baseURI(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try ElementImpl.get_baseURI(instance);
    }

    pub fn get_isConnected(instance: *runtime.Instance) anyerror!bool {
        return try ElementImpl.get_isConnected(instance);
    }

    pub fn get_ownerDocument(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ownerDocument(instance);
    }

    pub fn get_parentNode(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_parentNode(instance);
    }

    pub fn get_parentElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_parentElement(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_childNodes(instance: *runtime.Instance) anyerror!NodeList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_childNodes) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_childNodes(instance);
        state.cached_childNodes = value;
        return value;
    }

    pub fn get_firstChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_firstChild(instance);
    }

    pub fn get_lastChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_lastChild(instance);
    }

    pub fn get_previousSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_previousSibling(instance);
    }

    pub fn get_nextSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_nextSibling(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_nodeValue(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_nodeValue(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_nodeValue(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_nodeValue(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_textContent(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_textContent(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_textContent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_textContent(instance, value);
    }

    pub fn get_namespaceURI(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_namespaceURI(instance);
    }

    pub fn get_prefix(instance: *runtime.Instance) anyerror!anyopaque {
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
    pub fn get_classList(instance: *runtime.Instance) anyerror!DOMTokenList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_classList) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_classList(instance);
        state.cached_classList = value;
        return value;
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
    pub fn get_attributes(instance: *runtime.Instance) anyerror!NamedNodeMap {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_attributes) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_attributes(instance);
        state.cached_attributes = value;
        return value;
    }

    pub fn get_shadowRoot(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_shadowRoot(instance);
    }

    pub fn get_customElementRegistry(instance: *runtime.Instance) anyerror!anyopaque {
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
    pub fn get_part(instance: *runtime.Instance) anyerror!DOMTokenList {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_part) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_part(instance);
        state.cached_part = value;
        return value;
    }

    pub fn get_activeViewTransition(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_activeViewTransition(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_innerHTML(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_innerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_innerHTML(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_innerHTML(instance, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn get_outerHTML(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_outerHTML(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn set_outerHTML(instance: *runtime.Instance, value: anyopaque) anyerror!void {
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
    pub fn get_role(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_role(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect]
    pub fn set_role(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_role(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn get_ariaActiveDescendantElement(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaActiveDescendantElement(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-activedescendant"]
    pub fn set_ariaActiveDescendantElement(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaActiveDescendantElement(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn get_ariaAtomic(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaAtomic(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-atomic"]
    pub fn set_ariaAtomic(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaAtomic(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn get_ariaAutoComplete(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaAutoComplete(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-autocomplete"]
    pub fn set_ariaAutoComplete(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaAutoComplete(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn get_ariaBrailleLabel(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaBrailleLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-braillelabel"]
    pub fn set_ariaBrailleLabel(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaBrailleLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn get_ariaBrailleRoleDescription(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaBrailleRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-brailleroledescription"]
    pub fn set_ariaBrailleRoleDescription(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaBrailleRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn get_ariaBusy(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaBusy(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-busy"]
    pub fn set_ariaBusy(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaBusy(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn get_ariaChecked(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaChecked(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-checked"]
    pub fn set_ariaChecked(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaChecked(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn get_ariaColCount(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaColCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colcount"]
    pub fn set_ariaColCount(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn get_ariaColIndex(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaColIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindex"]
    pub fn set_ariaColIndex(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn get_ariaColIndexText(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaColIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colindextext"]
    pub fn set_ariaColIndexText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn get_ariaColSpan(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaColSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-colspan"]
    pub fn set_ariaColSpan(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaColSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn get_ariaControlsElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaControlsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-controls"]
    pub fn set_ariaControlsElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaControlsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn get_ariaCurrent(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaCurrent(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-current"]
    pub fn set_ariaCurrent(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaCurrent(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn get_ariaDescribedByElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaDescribedByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-describedby"]
    pub fn set_ariaDescribedByElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDescribedByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn get_ariaDescription(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-description"]
    pub fn set_ariaDescription(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn get_ariaDetailsElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaDetailsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-details"]
    pub fn set_ariaDetailsElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDetailsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn get_ariaDisabled(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaDisabled(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-disabled"]
    pub fn set_ariaDisabled(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaDisabled(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn get_ariaErrorMessageElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaErrorMessageElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-errormessage"]
    pub fn set_ariaErrorMessageElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaErrorMessageElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn get_ariaExpanded(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaExpanded(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-expanded"]
    pub fn set_ariaExpanded(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaExpanded(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn get_ariaFlowToElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaFlowToElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-flowto"]
    pub fn set_ariaFlowToElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaFlowToElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn get_ariaHasPopup(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaHasPopup(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-haspopup"]
    pub fn set_ariaHasPopup(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaHasPopup(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn get_ariaHidden(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaHidden(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-hidden"]
    pub fn set_ariaHidden(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaHidden(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn get_ariaInvalid(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaInvalid(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-invalid"]
    pub fn set_ariaInvalid(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaInvalid(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn get_ariaKeyShortcuts(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaKeyShortcuts(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-keyshortcuts"]
    pub fn set_ariaKeyShortcuts(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaKeyShortcuts(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn get_ariaLabel(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaLabel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-label"]
    pub fn set_ariaLabel(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLabel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn get_ariaLabelledByElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaLabelledByElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-labelledby"]
    pub fn set_ariaLabelledByElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLabelledByElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn get_ariaLevel(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaLevel(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-level"]
    pub fn set_ariaLevel(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLevel(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn get_ariaLive(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaLive(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-live"]
    pub fn set_ariaLive(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaLive(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn get_ariaModal(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaModal(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-modal"]
    pub fn set_ariaModal(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaModal(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn get_ariaMultiLine(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaMultiLine(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiline"]
    pub fn set_ariaMultiLine(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaMultiLine(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn get_ariaMultiSelectable(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaMultiSelectable(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-multiselectable"]
    pub fn set_ariaMultiSelectable(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaMultiSelectable(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn get_ariaOrientation(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaOrientation(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-orientation"]
    pub fn set_ariaOrientation(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaOrientation(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn get_ariaOwnsElements(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaOwnsElements(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-owns"]
    pub fn set_ariaOwnsElements(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaOwnsElements(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn get_ariaPlaceholder(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaPlaceholder(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-placeholder"]
    pub fn set_ariaPlaceholder(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaPlaceholder(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn get_ariaPosInSet(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaPosInSet(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-posinset"]
    pub fn set_ariaPosInSet(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaPosInSet(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn get_ariaPressed(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaPressed(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-pressed"]
    pub fn set_ariaPressed(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaPressed(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn get_ariaReadOnly(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaReadOnly(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-readonly"]
    pub fn set_ariaReadOnly(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaReadOnly(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn get_ariaRelevant(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRelevant(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-relevant"]
    pub fn set_ariaRelevant(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRelevant(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn get_ariaRequired(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRequired(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-required"]
    pub fn set_ariaRequired(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRequired(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn get_ariaRoleDescription(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRoleDescription(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-roledescription"]
    pub fn set_ariaRoleDescription(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRoleDescription(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn get_ariaRowCount(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRowCount(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowcount"]
    pub fn set_ariaRowCount(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowCount(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn get_ariaRowIndex(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRowIndex(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindex"]
    pub fn set_ariaRowIndex(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowIndex(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn get_ariaRowIndexText(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRowIndexText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowindextext"]
    pub fn set_ariaRowIndexText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowIndexText(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn get_ariaRowSpan(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaRowSpan(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-rowspan"]
    pub fn set_ariaRowSpan(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaRowSpan(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn get_ariaSelected(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaSelected(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-selected"]
    pub fn set_ariaSelected(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaSelected(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn get_ariaSetSize(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaSetSize(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-setsize"]
    pub fn set_ariaSetSize(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaSetSize(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn get_ariaSort(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaSort(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-sort"]
    pub fn set_ariaSort(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaSort(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn get_ariaValueMax(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaValueMax(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemax"]
    pub fn set_ariaValueMax(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueMax(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn get_ariaValueMin(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaValueMin(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuemin"]
    pub fn set_ariaValueMin(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueMin(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn get_ariaValueNow(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaValueNow(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuenow"]
    pub fn set_ariaValueNow(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueNow(instance, value);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn get_ariaValueText(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_ariaValueText(instance);
    }

    /// Extended attributes: [CEReactions], [Reflect="aria-valuetext"]
    pub fn set_ariaValueText(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        try ElementImpl.set_ariaValueText(instance, value);
    }

    pub fn get_regionOverset(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_regionOverset(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_children(instance: *runtime.Instance) anyerror!HTMLCollection {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_children) |cached| {
            return cached;
        }
        const value = try ElementImpl.get_children(instance);
        state.cached_children = value;
        return value;
    }

    pub fn get_firstElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_firstElementChild(instance);
    }

    pub fn get_lastElementChild(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_lastElementChild(instance);
    }

    pub fn get_childElementCount(instance: *runtime.Instance) anyerror!u32 {
        return try ElementImpl.get_childElementCount(instance);
    }

    pub fn get_previousElementSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_previousElementSibling(instance);
    }

    pub fn get_nextElementSibling(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_nextElementSibling(instance);
    }

    pub fn get_assignedSlot(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.get_assignedSlot(instance);
    }

    pub fn call_isDefaultNamespace(instance: *runtime.Instance, namespace: anyopaque) anyerror!bool {
        
        return try ElementImpl.call_isDefaultNamespace(instance, namespace);
    }

    pub fn call_getAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!anyopaque {
        
        return try ElementImpl.call_getAttributeNS(instance, namespace, localName);
    }

    pub fn call_getAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!anyopaque {
        
        return try ElementImpl.call_getAttribute(instance, qualifiedName);
    }

    pub fn call_hasAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!bool {
        
        return try ElementImpl.call_hasAttribute(instance, qualifiedName);
    }

    pub fn call_contains(instance: *runtime.Instance, other: anyopaque) anyerror!bool {
        
        return try ElementImpl.call_contains(instance, other);
    }

    pub fn call_matches(instance: *runtime.Instance, selectors: DOMString) anyerror!bool {
        
        return try ElementImpl.call_matches(instance, selectors);
    }

    pub fn call_releasePointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        
        return try ElementImpl.call_releasePointerCapture(instance, pointerId);
    }

    /// Extended attributes: [SameObject]
    pub fn call_computedStyleMap(instance: *runtime.Instance) anyerror!StylePropertyMapReadOnly {
        return try ElementImpl.call_computedStyleMap(instance);
    }

    /// Arguments for scroll (WebIDL overloading)
    pub const ScrollArgs = union(enum) {
        /// scroll(options)
        ScrollToOptions: ScrollToOptions,
        /// scroll(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scroll(instance: *runtime.Instance, args: ScrollArgs) anyerror!anyopaque {
        switch (args) {
            .ScrollToOptions => |arg| return try ElementImpl.ScrollToOptions(instance, arg),
            .unrestricted double_unrestricted double => |a| return try ElementImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
        }
    }

    pub fn call_getClientRects(instance: *runtime.Instance) anyerror!DOMRectList {
        return try ElementImpl.call_getClientRects(instance);
    }

    pub fn call_getRootNode(instance: *runtime.Instance, options: GetRootNodeOptions) anyerror!Node {
        
        return try ElementImpl.call_getRootNode(instance, options);
    }

    /// Arguments for scrollBy (WebIDL overloading)
    pub const ScrollByArgs = union(enum) {
        /// scrollBy(options)
        ScrollToOptions: ScrollToOptions,
        /// scrollBy(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scrollBy(instance: *runtime.Instance, args: ScrollByArgs) anyerror!anyopaque {
        switch (args) {
            .ScrollToOptions => |arg| return try ElementImpl.ScrollToOptions(instance, arg),
            .unrestricted double_unrestricted double => |a| return try ElementImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
        }
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_prepend(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_prepend(instance, nodes);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try ElementImpl.call_dispatchEvent(instance, event);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceWith(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_replaceWith(instance, nodes);
    }

    pub fn call_convertQuadFromNode(instance: *runtime.Instance, quad: DOMQuadInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try ElementImpl.call_convertQuadFromNode(instance, quad, from, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNodeNS(instance: *runtime.Instance, attr: Attr) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttributeNodeNS(instance, attr);
    }

    pub fn call_getAttributeNodeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!anyopaque {
        
        return try ElementImpl.call_getAttributeNodeNS(instance, namespace, localName);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNS(instance: *runtime.Instance, namespace: anyopaque, qualifiedName: DOMString, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttributeNS(instance, namespace, qualifiedName, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttributeNode(instance: *runtime.Instance, attr: Attr) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttributeNode(instance, attr);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try ElementImpl.call_when(instance, type_, options);
    }

    /// Arguments for scrollTo (WebIDL overloading)
    pub const ScrollToArgs = union(enum) {
        /// scrollTo(options)
        ScrollToOptions: ScrollToOptions,
        /// scrollTo(x, y)
        unrestricted double_unrestricted double: struct {
            x: f64,
            y: f64,
        },
    };

    pub fn call_scrollTo(instance: *runtime.Instance, args: ScrollToArgs) anyerror!anyopaque {
        switch (args) {
            .ScrollToOptions => |arg| return try ElementImpl.ScrollToOptions(instance, arg),
            .unrestricted double_unrestricted double => |a| return try ElementImpl.unrestricted double_unrestricted double(instance, a.x, a.y),
        }
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_insertBefore(instance, node, child);
    }

    pub fn call_lookupNamespaceURI(instance: *runtime.Instance, prefix: anyopaque) anyerror!anyopaque {
        
        return try ElementImpl.call_lookupNamespaceURI(instance, prefix);
    }

    pub fn call_getElementsByTagNameNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!HTMLCollection {
        
        return try ElementImpl.call_getElementsByTagNameNS(instance, namespace, localName);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_replaceChildren(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_replaceChildren(instance, nodes);
    }

    pub fn call_getRegionFlowRanges(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.call_getRegionFlowRanges(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeChild(instance: *runtime.Instance, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeChild(instance, child);
    }

    pub fn call_focusableAreas(instance: *runtime.Instance, option: FocusableAreasOption) anyerror!anyopaque {
        
        return try ElementImpl.call_focusableAreas(instance, option);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_normalize(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try ElementImpl.call_normalize(instance);
    }

    pub fn call_isEqualNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try ElementImpl.call_isEqualNode(instance, otherNode);
    }

    pub fn call_getBoxQuads(instance: *runtime.Instance, options: BoxQuadOptions) anyerror!anyopaque {
        
        return try ElementImpl.call_getBoxQuads(instance, options);
    }

    pub fn call_convertPointFromNode(instance: *runtime.Instance, point: DOMPointInit, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMPoint {
        
        return try ElementImpl.call_convertPointFromNode(instance, point, from, options);
    }

    pub fn call_getAnimations(instance: *runtime.Instance, options: GetAnimationsOptions) anyerror!anyopaque {
        
        return try ElementImpl.call_getAnimations(instance, options);
    }

    pub fn call_getElementsByClassName(instance: *runtime.Instance, classNames: DOMString) anyerror!HTMLCollection {
        
        return try ElementImpl.call_getElementsByClassName(instance, classNames);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentElement(instance: *runtime.Instance, where: DOMString, element: Element) anyerror!anyopaque {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_insertAdjacentElement(instance, where, element);
    }

    pub fn call_webkitMatchesSelector(instance: *runtime.Instance, selectors: DOMString) anyerror!bool {
        
        return try ElementImpl.call_webkitMatchesSelector(instance, selectors);
    }

    pub fn call_spatialNavigationSearch(instance: *runtime.Instance, dir: SpatialNavigationDirection, options: SpatialNavigationSearchOptions) anyerror!anyopaque {
        
        return try ElementImpl.call_spatialNavigationSearch(instance, dir, options);
    }

    pub fn call_getElementsByTagName(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!HTMLCollection {
        
        return try ElementImpl.call_getElementsByTagName(instance, qualifiedName);
    }

    pub fn call_querySelector(instance: *runtime.Instance, selectors: DOMString) anyerror!anyopaque {
        
        return try ElementImpl.call_querySelector(instance, selectors);
    }

    pub fn call_compareDocumentPosition(instance: *runtime.Instance, other: Node) anyerror!u16 {
        
        return try ElementImpl.call_compareDocumentPosition(instance, other);
    }

    pub fn call_closest(instance: *runtime.Instance, selectors: DOMString) anyerror!anyopaque {
        
        return try ElementImpl.call_closest(instance, selectors);
    }

    pub fn call_getSpatialNavigationContainer(instance: *runtime.Instance) anyerror!Node {
        return try ElementImpl.call_getSpatialNavigationContainer(instance);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_remove(instance: *runtime.Instance) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        return try ElementImpl.call_remove(instance);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttribute(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeAttribute(instance, qualifiedName);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ElementImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_convertRectFromNode(instance: *runtime.Instance, rect: DOMRectReadOnly, from: GeometryNode, options: ConvertCoordinateOptions) anyerror!DOMQuad {
        
        return try ElementImpl.call_convertRectFromNode(instance, rect, from, options);
    }

    /// Extended attributes: [CEReactions], [NewObject]
    pub fn call_cloneNode(instance: *runtime.Instance, subtree: bool) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        // [NewObject] - Caller owns the returned object
        
        return try ElementImpl.call_cloneNode(instance, subtree);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNode(instance: *runtime.Instance, attr: Attr) anyerror!Attr {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeAttributeNode(instance, attr);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_removeAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_removeAttributeNS(instance, namespace, localName);
    }

    pub fn call_insertAdjacentText(instance: *runtime.Instance, where: DOMString, data: DOMString) anyerror!void {
        
        return try ElementImpl.call_insertAdjacentText(instance, where, data);
    }

    pub fn call_requestFullscreen(instance: *runtime.Instance, options: FullscreenOptions) anyerror!anyopaque {
        
        return try ElementImpl.call_requestFullscreen(instance, options);
    }

    pub fn call_animate(instance: *runtime.Instance, keyframes: anyopaque, options: anyopaque) anyerror!Animation {
        
        return try ElementImpl.call_animate(instance, keyframes, options);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_append(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_append(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_moveBefore(instance: *runtime.Instance, node: Node, child: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_moveBefore(instance, node, child);
    }

    pub fn call_getHTML(instance: *runtime.Instance, options: GetHTMLOptions) anyerror!DOMString {
        
        return try ElementImpl.call_getHTML(instance, options);
    }

    pub fn call_getAttributeNode(instance: *runtime.Instance, qualifiedName: DOMString) anyerror!anyopaque {
        
        return try ElementImpl.call_getAttributeNode(instance, qualifiedName);
    }

    pub fn call_isSameNode(instance: *runtime.Instance, otherNode: anyopaque) anyerror!bool {
        
        return try ElementImpl.call_isSameNode(instance, otherNode);
    }

    pub fn call_startViewTransition(instance: *runtime.Instance, callbackOptions: anyopaque) anyerror!ViewTransition {
        
        return try ElementImpl.call_startViewTransition(instance, callbackOptions);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setHTMLUnsafe(instance: *runtime.Instance, html: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setHTMLUnsafe(instance, html);
    }

    pub fn call_lookupPrefix(instance: *runtime.Instance, namespace: anyopaque) anyerror!anyopaque {
        
        return try ElementImpl.call_lookupPrefix(instance, namespace);
    }

    pub fn call_scrollIntoView(instance: *runtime.Instance, arg: anyopaque) anyerror!anyopaque {
        
        return try ElementImpl.call_scrollIntoView(instance, arg);
    }

    pub fn call_hasAttributes(instance: *runtime.Instance) anyerror!bool {
        return try ElementImpl.call_hasAttributes(instance);
    }

    pub fn call_hasPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!bool {
        
        return try ElementImpl.call_hasPointerCapture(instance, pointerId);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_toggleAttribute(instance: *runtime.Instance, qualifiedName: DOMString, force: bool) anyerror!bool {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_toggleAttribute(instance, qualifiedName, force);
    }

    pub fn call_pseudo(instance: *runtime.Instance, type_: anyopaque) anyerror!anyopaque {
        
        return try ElementImpl.call_pseudo(instance, type_);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_before(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_before(instance, nodes);
    }

    /// Extended attributes: [CEReactions], [Unscopable]
    pub fn call_after(instance: *runtime.Instance, nodes: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_after(instance, nodes);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_setAttribute(instance: *runtime.Instance, qualifiedName: DOMString, value: DOMString) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_setAttribute(instance, qualifiedName, value);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_appendChild(instance: *runtime.Instance, node: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_appendChild(instance, node);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try ElementImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_getAttributeNames(instance: *runtime.Instance) anyerror!anyopaque {
        return try ElementImpl.call_getAttributeNames(instance);
    }

    pub fn call_hasChildNodes(instance: *runtime.Instance) anyerror!bool {
        return try ElementImpl.call_hasChildNodes(instance);
    }

    pub fn call_attachShadow(instance: *runtime.Instance, init: ShadowRootInit) anyerror!ShadowRoot {
        
        return try ElementImpl.call_attachShadow(instance, init);
    }

    pub fn call_requestPointerLock(instance: *runtime.Instance, options: PointerLockOptions) anyerror!anyopaque {
        
        return try ElementImpl.call_requestPointerLock(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_insertAdjacentHTML(instance: *runtime.Instance, position: DOMString, string: anyopaque) anyerror!void {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_insertAdjacentHTML(instance, position, string);
    }

    pub fn call_hasAttributeNS(instance: *runtime.Instance, namespace: anyopaque, localName: DOMString) anyerror!bool {
        
        return try ElementImpl.call_hasAttributeNS(instance, namespace, localName);
    }

    pub fn call_checkVisibility(instance: *runtime.Instance, options: CheckVisibilityOptions) anyerror!bool {
        
        return try ElementImpl.call_checkVisibility(instance, options);
    }

    /// Extended attributes: [CEReactions]
    pub fn call_replaceChild(instance: *runtime.Instance, node: Node, child: Node) anyerror!Node {
        // [CEReactions] - Trigger Custom Element lifecycle callbacks
        runtime.CEReactions.begin();
        defer runtime.CEReactions.end();
        
        
        return try ElementImpl.call_replaceChild(instance, node, child);
    }

    /// Extended attributes: [NewObject]
    pub fn call_getBoundingClientRect(instance: *runtime.Instance) anyerror!DOMRect {
        // [NewObject] - Caller owns the returned object
        return try ElementImpl.call_getBoundingClientRect(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_querySelectorAll(instance: *runtime.Instance, selectors: DOMString) anyerror!NodeList {
        // [NewObject] - Caller owns the returned object
        
        return try ElementImpl.call_querySelectorAll(instance, selectors);
    }

    pub fn call_setPointerCapture(instance: *runtime.Instance, pointerId: i32) anyerror!void {
        
        return try ElementImpl.call_setPointerCapture(instance, pointerId);
    }

};

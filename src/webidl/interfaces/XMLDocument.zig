//! Generated from: dom.idl
//! Generated at: 2025-12-07T20:02:43Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const XMLDocumentImpl = @import("impls").XMLDocument;
const mixins = @import("mixins");
const Document = @import("interfaces").Document;
const HTMLOrSVGScriptElement = @import("typedefs").HTMLOrSVGScriptElement;
const HTMLCollection = @import("interfaces").HTMLCollection;
const HTMLHeadElement = @import("interfaces").HTMLHeadElement;
const FontMetrics = @import("interfaces").FontMetrics;
const NodeIterator = @import("interfaces").NodeIterator;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Text = @import("interfaces").Text;
const GeometryNode = @import("typedefs").GeometryNode;
const USVString = @import("interfaces").USVString;
const Element = @import("interfaces").Element;
const XPathExpression = @import("interfaces").XPathExpression;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const XPathResult = @import("interfaces").XPathResult;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const Location = @import("interfaces").Location;
const EventListener = @import("interfaces").EventListener;
const StyleSheetList = @import("interfaces").StyleSheetList;
const FragmentDirective = @import("interfaces").FragmentDirective;
const Comment = @import("interfaces").Comment;
const NamedFlowMap = @import("interfaces").NamedFlowMap;
const CSSStyleSheet = @import("interfaces").CSSStyleSheet;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const StorageAccessHandle = @import("interfaces").StorageAccessHandle;
const ImportNodeOptions = @import("dictionaries").ImportNodeOptions;
const DOMImplementation = @import("interfaces").DOMImplementation;
const Node = @import("interfaces").Node;
const CustomElementRegistry = @import("interfaces").CustomElementRegistry;
const Range = @import("interfaces").Range;
const Animation = @import("interfaces").Animation;
const Event = @import("interfaces").Event;
const PermissionsPolicy = @import("interfaces").PermissionsPolicy;
const XPathNSResolver = @import("interfaces").XPathNSResolver;
const DocumentType = @import("interfaces").DocumentType;
const DOMString = @import("typedefs").DOMString;
const HTMLAllCollection = @import("interfaces").HTMLAllCollection;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DocumentFragment = @import("interfaces").DocumentFragment;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const FontFaceSet = @import("interfaces").FontFaceSet;
const BrowsingTopicsOptions = @import("dictionaries").BrowsingTopicsOptions;
const DOMQuad = @import("interfaces").DOMQuad;
const DOMRectReadOnly = @import("interfaces").DOMRectReadOnly;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const StylePropertyMapReadOnly = @import("interfaces").StylePropertyMapReadOnly;
const CDATASection = @import("interfaces").CDATASection;
const DocumentTimeline = @import("interfaces").DocumentTimeline;
const ViewTransition = @import("interfaces").ViewTransition;
const TreeWalker = @import("interfaces").TreeWalker;
const EventHandler = @import("typedefs").EventHandler;
const DocumentReadyState = @import("enums").DocumentReadyState;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const HTMLElement = @import("interfaces").HTMLElement;
const StorageAccessTypes = @import("dictionaries").StorageAccessTypes;
const WindowProxy = @import("typedefs").WindowProxy;
const Attr = @import("interfaces").Attr;
const TrustedHTML = @import("interfaces").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("interfaces").NodeList;
const Observable = @import("interfaces").Observable;
const ElementCreationOptions = @import("dictionaries").ElementCreationOptions;
const DOMPoint = @import("interfaces").DOMPoint;
const CaretPosition = @import("interfaces").CaretPosition;
const CaretPositionFromPointOptions = @import("dictionaries").CaretPositionFromPointOptions;
const ProcessingInstruction = @import("interfaces").ProcessingInstruction;
const SVGSVGElement = @import("interfaces").SVGSVGElement;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const Selection = @import("interfaces").Selection;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;
const NodeFilter = @import("interfaces").NodeFilter;

pub const XMLDocument = struct {
    pub const Meta = struct {
        pub const name = "XMLDocument";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = Document.State;
        pub const ParentInterface = Document;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            "getElementsByTagName",
            "getElementsByTagNameNS",
            "getElementsByClassName",
            "createElement",
            "createElementNS",
            "createDocumentFragment",
            "createTextNode",
            "createCDATASection",
            "createComment",
            "createProcessingInstruction",
            "importNode",
            "adoptNode",
            "createAttribute",
            "createAttributeNS",
            "createEvent",
            "createRange",
            "createNodeIterator",
            "createTreeWalker",
            "exitFullscreen",
            "getSelection",
            "exitPictureInPicture",
            "browsingTopics",
            "exitPointerLock",
            "requestStorageAccessFor",
            "hasStorageAccess",
            "requestStorageAccess",
            "startViewTransition",
            "measureElement",
            "measureText",
            "hasUnpartitionedCookieAccess",
            "requestStorageAccess",
            "parseHTMLUnsafe",
            "getElementsByName",
            "open",
            "open",
            "close",
            "write",
            "writeln",
            "hasFocus",
            "execCommand",
            "queryCommandEnabled",
            "queryCommandIndeterm",
            "queryCommandState",
            "queryCommandSupported",
            "queryCommandValue",
            "clear",
            "captureEvents",
            "releaseEvents",
            "hasPrivateToken",
            "hasRedemptionRecord",
            "elementFromPoint",
            "elementsFromPoint",
            "caretPositionFromPoint",
            "getElementById",
            "getAnimations",
            "prepend",
            "append",
            "replaceChildren",
            "moveBefore",
            "querySelector",
            "querySelectorAll",
            "createExpression",
            "createNSResolver",
            "evaluate",
            "getBoxQuads",
            "convertQuadFromNode",
            "convertRectFromNode",
            "convertPointFromNode",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
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
            _internal: ?*XMLDocumentImpl.InternalState = null,
        },
    );

    const delegates = .{

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return XMLDocumentImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLDocumentImpl.deinit(instance);
    }

};

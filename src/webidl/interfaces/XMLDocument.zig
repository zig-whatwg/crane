//! Generated from: dom.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const XMLDocumentImpl = @import("impls").XMLDocument;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const Document = @import("Document.zig").Document;
const HTMLOrSVGScriptElement = @import("typedefs").HTMLOrSVGScriptElement;
const HTMLCollection = @import("HTMLCollection.zig").HTMLCollection;
const HTMLHeadElement = @import("HTMLHeadElement.zig").HTMLHeadElement;
const FontMetrics = @import("FontMetrics.zig").FontMetrics;
const NodeIterator = @import("NodeIterator.zig").NodeIterator;
const DOMPointInit = @import("dictionaries").DOMPointInit;
const Text = @import("Text.zig").Text;
const GeometryNode = @import("typedefs").GeometryNode;
const USVString = @import("typedefs").USVString;
const Element = @import("Element.zig").Element;
const XPathExpression = @import("XPathExpression.zig").XPathExpression;
const BoxQuadOptions = @import("dictionaries").BoxQuadOptions;
const XPathResult = @import("XPathResult.zig").XPathResult;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const Location = @import("Location.zig").Location;
const EventListener = @import("EventListener.zig").EventListener;
const StyleSheetList = @import("StyleSheetList.zig").StyleSheetList;
const FragmentDirective = @import("FragmentDirective.zig").FragmentDirective;
const Comment = @import("Comment.zig").Comment;
const NamedFlowMap = @import("NamedFlowMap.zig").NamedFlowMap;
const CSSStyleSheet = @import("CSSStyleSheet.zig").CSSStyleSheet;
const ViewTransitionUpdateCallback = @import("callbacks").ViewTransitionUpdateCallback;
const StorageAccessHandle = @import("StorageAccessHandle.zig").StorageAccessHandle;
const ImportNodeOptions = @import("dictionaries").ImportNodeOptions;
const DOMImplementation = @import("DOMImplementation.zig").DOMImplementation;
const Node = @import("Node.zig").Node;
const CustomElementRegistry = @import("CustomElementRegistry.zig").CustomElementRegistry;
const Range = @import("Range.zig").Range;
const Animation = @import("Animation.zig").Animation;
const Event = @import("Event.zig").Event;
const PermissionsPolicy = @import("PermissionsPolicy.zig").PermissionsPolicy;
const XPathNSResolver = @import("XPathNSResolver.zig").XPathNSResolver;
const DocumentType = @import("DocumentType.zig").DocumentType;
const DOMString = @import("typedefs").DOMString;
const HTMLAllCollection = @import("HTMLAllCollection.zig").HTMLAllCollection;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DocumentFragment = @import("DocumentFragment.zig").DocumentFragment;
const OnErrorEventHandler = @import("typedefs").OnErrorEventHandler;
const FontFaceSet = @import("FontFaceSet.zig").FontFaceSet;
const BrowsingTopicsOptions = @import("dictionaries").BrowsingTopicsOptions;
const DOMQuad = @import("DOMQuad.zig").DOMQuad;
const DOMRectReadOnly = @import("DOMRectReadOnly.zig").DOMRectReadOnly;
const StartViewTransitionOptions = @import("dictionaries").StartViewTransitionOptions;
const StylePropertyMapReadOnly = @import("StylePropertyMapReadOnly.zig").StylePropertyMapReadOnly;
const CDATASection = @import("CDATASection.zig").CDATASection;
const DocumentTimeline = @import("DocumentTimeline.zig").DocumentTimeline;
const ViewTransition = @import("ViewTransition.zig").ViewTransition;
const TreeWalker = @import("TreeWalker.zig").TreeWalker;
const EventHandler = @import("typedefs").EventHandler;
const DocumentReadyState = @import("enums").DocumentReadyState;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ConvertCoordinateOptions = @import("dictionaries").ConvertCoordinateOptions;
const HTMLElement = @import("HTMLElement.zig").HTMLElement;
const StorageAccessTypes = @import("dictionaries").StorageAccessTypes;
const WindowProxy = @import("typedefs").WindowProxy;
const Attr = @import("Attr.zig").Attr;
const TrustedHTML = @import("TrustedHTML.zig").TrustedHTML;
const DOMQuadInit = @import("dictionaries").DOMQuadInit;
const NodeList = @import("NodeList.zig").NodeList;
const Observable = @import("Observable.zig").Observable;
const ElementCreationOptions = @import("dictionaries").ElementCreationOptions;
const DOMPoint = @import("DOMPoint.zig").DOMPoint;
const CaretPosition = @import("CaretPosition.zig").CaretPosition;
const CaretPositionFromPointOptions = @import("dictionaries").CaretPositionFromPointOptions;
const ProcessingInstruction = @import("ProcessingInstruction.zig").ProcessingInstruction;
const SVGSVGElement = @import("SVGSVGElement.zig").SVGSVGElement;
const GetRootNodeOptions = @import("dictionaries").GetRootNodeOptions;
const Selection = @import("Selection.zig").Selection;
const DocumentVisibilityState = @import("enums").DocumentVisibilityState;
const NodeFilter = @import("NodeFilter.zig").NodeFilter;

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

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return XMLDocumentImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XMLDocumentImpl.deinit(instance);
    }

};

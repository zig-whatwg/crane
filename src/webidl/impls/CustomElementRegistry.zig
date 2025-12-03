//! Implementation for CustomElementRegistry interface
//!
//! Implements the CustomElementRegistry per HTML Standard §4.13.3
//! Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#customelementregistry
//!
//! ## Overview
//!
//! CustomElementRegistry stores custom element definitions and provides methods
//! to define(), get(), getName(), whenDefined(), upgrade(), and initialize() custom elements.
//!
//! ## Key Concepts
//!
//! - **Custom element definition**: Associates a name with a constructor and lifecycle callbacks
//! - **Autonomous custom element**: A custom element with a hyphenated name (e.g., my-element)
//! - **Customized built-in element**: Extends a built-in element (e.g., button is="my-button")
//! - **Upgrade**: Converting an undefined element to a custom element when its definition is registered

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const CustomElementRegistry = interfaces.CustomElementRegistry;

pub const State = CustomElementRegistry.State;

pub const ImplError = error{
    NotImplemented,
    SyntaxError,
    NotSupportedError,
    TypeError,
    InvalidStateError,
    OutOfMemory,
};

/// Custom element definition per HTML spec
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#custom-element-definition
pub const CustomElementDefinition = struct {
    /// The custom element's name (valid custom element name)
    name: []const u8,

    /// The local name (equals name for autonomous, equals extends for customized built-in)
    local_name: []const u8,

    /// The constructor callback
    constructor: callbacks.CustomElementConstructor,

    /// Observed attributes list (for attributeChangedCallback)
    observed_attributes: []const []const u8,

    /// Lifecycle callbacks
    lifecycle_callbacks: LifecycleCallbacks,

    /// Whether this is a form-associated custom element
    form_associated: bool,

    /// Whether attachInternals() is disabled
    disable_internals: bool,

    /// Whether attachShadow() is disabled
    disable_shadow: bool,

    /// The construction stack (for upgrade algorithm)
    /// Each entry is either an element or the already-constructed marker
    construction_stack: std.ArrayListUnmanaged(ConstructionStackEntry) = .{},

    allocator: Allocator,

    pub const ConstructionStackEntry = union(enum) {
        element: *runtime.Instance,
        already_constructed: void,
    };

    /// Lifecycle callback names and values
    pub const LifecycleCallbacks = struct {
        connectedCallback: ?*anyopaque = null,
        disconnectedCallback: ?*anyopaque = null,
        adoptedCallback: ?*anyopaque = null,
        connectedMoveCallback: ?*anyopaque = null,
        attributeChangedCallback: ?*anyopaque = null,
        formAssociatedCallback: ?*anyopaque = null,
        formResetCallback: ?*anyopaque = null,
        formDisabledCallback: ?*anyopaque = null,
        formStateRestoreCallback: ?*anyopaque = null,
    };

    pub fn init(allocator: Allocator, name: []const u8, local_name: []const u8, constructor: callbacks.CustomElementConstructor) !*CustomElementDefinition {
        const def = try allocator.create(CustomElementDefinition);
        errdefer allocator.destroy(def);

        def.* = .{
            .name = try allocator.dupe(u8, name),
            .local_name = try allocator.dupe(u8, local_name),
            .constructor = constructor,
            .observed_attributes = &.{},
            .lifecycle_callbacks = .{},
            .form_associated = false,
            .disable_internals = false,
            .disable_shadow = false,
            .allocator = allocator,
        };

        return def;
    }

    pub fn deinit(self: *CustomElementDefinition) void {
        self.allocator.free(self.name);
        self.allocator.free(self.local_name);
        for (self.observed_attributes) |attr| {
            self.allocator.free(attr);
        }
        if (self.observed_attributes.len > 0) {
            self.allocator.free(self.observed_attributes);
        }
        self.construction_stack.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

/// Internal state for CustomElementRegistry implementation
pub const InternalState = struct {
    allocator: Allocator,

    /// Whether this is a scoped registry (created via new CustomElementRegistry())
    is_scoped: bool = false,

    /// Set of documents using this scoped registry
    scoped_document_set: std.ArrayListUnmanaged(*runtime.Instance) = .{},

    /// Custom element definitions (name -> definition)
    definitions: std.StringHashMapUnmanaged(*CustomElementDefinition) = .{},

    /// Map of constructors to definitions (for getName())
    constructor_to_definition: std.AutoHashMapUnmanaged(usize, *CustomElementDefinition) = .{},

    /// Whether element definition is currently running (prevents reentrant invocation)
    element_definition_is_running: bool = false,

    /// when-defined promise map (name -> promise resolver)
    /// For now we store a simple flag indicating if whenDefined was called
    /// TODO: Integrate with proper Promise implementation
    when_defined_waiters: std.StringHashMapUnmanaged(WhenDefinedWaiter) = .{},

    pub const WhenDefinedWaiter = struct {
        /// Callback to invoke when definition is registered
        /// In a real implementation, this would resolve a Promise
        resolved: bool = false,
        constructor: ?callbacks.CustomElementConstructor = null,
    };

    pub fn init(allocator: Allocator) !*InternalState {
        const state = try allocator.create(InternalState);
        state.* = .{
            .allocator = allocator,
        };
        return state;
    }

    pub fn deinit(self: *InternalState) void {
        // Clean up definitions
        var it = self.definitions.valueIterator();
        while (it.next()) |def| {
            def.*.deinit();
        }
        self.definitions.deinit(self.allocator);
        self.constructor_to_definition.deinit(self.allocator);
        self.scoped_document_set.deinit(self.allocator);
        self.when_defined_waiters.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Look up a definition by name
    pub fn getDefinitionByName(self: *InternalState, name: []const u8) ?*CustomElementDefinition {
        return self.definitions.get(name);
    }

    /// Look up a definition by constructor
    pub fn getDefinitionByConstructor(self: *InternalState, constructor: callbacks.CustomElementConstructor) ?*CustomElementDefinition {
        const key = @intFromPtr(constructor);
        return self.constructor_to_definition.get(key);
    }

    /// Check if a name is already defined
    pub fn hasDefinition(self: *InternalState, name: []const u8) bool {
        return self.definitions.contains(name);
    }

    /// Check if a constructor is already registered
    pub fn hasConstructor(self: *InternalState, constructor: callbacks.CustomElementConstructor) bool {
        const key = @intFromPtr(constructor);
        return self.constructor_to_definition.contains(key);
    }

    /// Add a new definition
    pub fn addDefinition(self: *InternalState, def: *CustomElementDefinition) !void {
        try self.definitions.put(self.allocator, def.name, def);
        const key = @intFromPtr(def.constructor);
        try self.constructor_to_definition.put(self.allocator, key, def);

        // Resolve any waiters for this name
        if (self.when_defined_waiters.getPtr(def.name)) |waiter| {
            waiter.resolved = true;
            waiter.constructor = def.constructor;
        }
    }
};

/// Get the internal state from an instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Validate a custom element name per spec
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#valid-custom-element-name
pub fn isValidCustomElementName(name: []const u8) bool {
    if (name.len == 0) return false;

    // Must start with ASCII lower alpha
    if (name[0] < 'a' or name[0] > 'z') return false;

    // Must contain a hyphen
    var has_hyphen = false;
    for (name) |c| {
        if (c == '-') {
            has_hyphen = true;
        }
        // Must not contain ASCII upper alpha
        if (c >= 'A' and c <= 'Z') return false;
    }
    if (!has_hyphen) return false;

    // Must not be one of the reserved names
    const reserved_names = [_][]const u8{
        "annotation-xml",
        "color-profile",
        "font-face",
        "font-face-src",
        "font-face-uri",
        "font-face-format",
        "font-face-name",
        "missing-glyph",
    };
    for (reserved_names) |reserved| {
        if (std.mem.eql(u8, name, reserved)) return false;
    }

    return true;
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);

    // Initialize internal state
    const state = instance.getState(StateType);
    state.own._internal = try InternalState.init(allocator);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry
///
/// new CustomElementRegistry() creates a scoped registry
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &CustomElementRegistry.vtable, ctx);
    errdefer deinit(instance);

    // Mark as scoped registry per spec
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.is_scoped = true;

    return instance;
}

/// Operation: define(name, constructor, options)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-define
///
/// Defines a new custom element, mapping the given name to the given constructor.
pub fn call_define(instance: *runtime.Instance, name: runtime.DOMString, constructor_data: callbacks.CustomElementConstructor, options: webidl.Opt(dictionaries.ElementDefinitionOptions)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;

    const name_str = name.asSlice();

    // Step 1: If IsConstructor(constructor) is false, throw TypeError
    // (Handled by the callback type)

    // Step 2: If name is not a valid custom element name, throw SyntaxError
    if (!isValidCustomElementName(name_str)) {
        return error.SyntaxError;
    }

    // Step 3: If registry already has a definition with this name, throw NotSupportedError
    if (internal.hasDefinition(name_str)) {
        return error.NotSupportedError;
    }

    // Step 4: If registry already has a definition with this constructor, throw NotSupportedError
    if (internal.hasConstructor(constructor_data)) {
        return error.NotSupportedError;
    }

    // Step 5: Let localName be name
    var local_name = name_str;

    // Step 6-7: Handle extends option
    if (options.was_passed) {
        const opts = options.value;
        if (opts.extends) |extends| {
            const extends_str = extends.asSlice();

            // Step 7.1: If this is a scoped registry, throw NotSupportedError
            // (customized built-in elements not supported in scoped registries)
            if (internal.is_scoped) {
                return error.NotSupportedError;
            }

            // Step 7.2: If extends is a valid custom element name, throw NotSupportedError
            if (isValidCustomElementName(extends_str)) {
                return error.NotSupportedError;
            }

            // Step 7.3: Check if extends is a valid HTML element
            // For now, we accept common HTML element names
            // TODO: Full validation against HTML element list
            if (!isKnownHTMLElement(extends_str)) {
                return error.NotSupportedError;
            }

            // Step 7.4: Set localName to extends
            local_name = extends_str;
        }
    }

    // Step 8: If element definition is running, throw NotSupportedError
    if (internal.element_definition_is_running) {
        return error.NotSupportedError;
    }

    // Step 9: Set element definition is running to true
    internal.element_definition_is_running = true;
    defer internal.element_definition_is_running = false;

    // Steps 10-14: Initialize form-associated, disable flags, observed attributes
    // These would be extracted from the constructor's static properties
    // For now, use defaults

    // Step 15: Create the definition
    const def = try CustomElementDefinition.init(allocator, name_str, local_name, constructor_data);
    errdefer def.deinit();

    // Step 16: Add to custom element definition set
    try internal.addDefinition(def);

    // Steps 17-18: Upgrade existing elements
    // TODO: Implement upgrade logic - iterate shadow-including descendants
    // For now, this is a no-op

    // Step 19: Resolve whenDefined promise if any waiters
    // (Handled in addDefinition)
}

/// Check if a name is a known HTML element
fn isKnownHTMLElement(name: []const u8) bool {
    const known_elements = [_][]const u8{
        "a",        "abbr",     "address", "area",     "article",    "aside",    "audio",
        "b",        "base",     "bdi",     "bdo",      "blockquote", "body",     "br",
        "button",   "canvas",   "caption", "cite",     "code",       "col",      "colgroup",
        "data",     "datalist", "dd",      "del",      "details",    "dfn",      "dialog",
        "div",      "dl",       "dt",      "em",       "embed",      "fieldset", "figcaption",
        "figure",   "footer",   "form",    "h1",       "h2",         "h3",       "h4",
        "h5",       "h6",       "head",    "header",   "hgroup",     "hr",       "html",
        "i",        "iframe",   "img",     "input",    "ins",        "kbd",      "label",
        "legend",   "li",       "link",    "main",     "map",        "mark",     "menu",
        "meta",     "meter",    "nav",     "noscript", "object",     "ol",       "optgroup",
        "option",   "output",   "p",       "picture",  "pre",        "progress", "q",
        "rp",       "rt",       "ruby",    "s",        "samp",       "script",   "search",
        "section",  "select",   "slot",    "small",    "source",     "span",     "strong",
        "style",    "sub",      "summary", "sup",      "table",      "tbody",    "td",
        "template", "textarea", "tfoot",   "th",       "thead",      "time",     "title",
        "tr",       "track",    "u",       "ul",       "var",        "video",    "wbr",
    };

    for (known_elements) |elem| {
        if (std.mem.eql(u8, name, elem)) return true;
    }
    return false;
}

/// Operation: get(name)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-get
///
/// Returns the constructor for the given name, or undefined if not defined.
/// Note: Returns the constructor cast to anyopaque pointer to match interface signature.
pub fn call_get(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const name_str = name.asSlice();

    // Step 1: If definition set contains an item with name, return that item's constructor
    if (internal.getDefinitionByName(name_str)) |def| {
        // Cast the function pointer to anyopaque pointer
        return @ptrCast(def.constructor);
    }

    // Step 2: Return undefined - represented as error since return type is non-nullable
    // In JS, this returns undefined. The runtime layer should handle this error as undefined.
    return error.NotImplemented;
}

/// Operation: getName(constructor)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-getname
///
/// Returns the name for the given constructor, or null if not defined.
pub fn call_getName(instance: *runtime.Instance, constructor_data: callbacks.CustomElementConstructor) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: If definition set contains an item with this constructor, return its name
    if (internal.getDefinitionByConstructor(constructor_data)) |def| {
        return runtime.DOMString.initInterned(def.name);
    }

    // Step 2: Return null
    return null;
}

/// Operation: upgrade(root)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-upgrade
///
/// Tries to upgrade all shadow-including inclusive descendant elements of root.
pub fn call_upgrade(instance: *runtime.Instance, root: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = root;
    _ = internal;

    // Step 1: Let candidates be a list of all of root's shadow-including inclusive
    //         descendant elements, in shadow-including tree order.
    // Step 2: For each candidate of candidates, try to upgrade candidate.

    // TODO: Implement full tree traversal and upgrade logic
    // This requires:
    // 1. Walking the DOM tree including shadow roots
    // 2. For each element, calling tryToUpgrade()
    // 3. tryToUpgrade() looks up definition and enqueues upgrade reaction

    // For now, this is a no-op placeholder
}

/// Operation: initialize(root)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-initialize
///
/// Associates this registry with elements in the subtree.
pub fn call_initialize(instance: *runtime.Instance, root: *runtime.Instance) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    _ = root;

    // Step 1: If this is not scoped and either root is Document or root's document's
    //         registry is not this, throw NotSupportedError
    if (!internal.is_scoped) {
        // TODO: Check if root is Document or if root's node document's registry != this
        return error.NotSupportedError;
    }

    // Steps 2-4: Set custom element registry for elements in subtree
    // TODO: Implement proper initialization logic

    // For now, this is a no-op placeholder
}

/// Operation: whenDefined(name)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-whendefined
///
/// Returns a promise that resolves when the named element is defined.
/// TODO: This should return a Promise<CustomElementConstructor> - for now returns the constructor directly if defined
/// Note: Returns pointer to match interface signature. Caller should treat as Promise object.
pub fn call_whenDefined(instance: *runtime.Instance, name: runtime.DOMString) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const name_str = name.asSlice();

    // Step 1: If name is not a valid custom element name, return rejected promise with SyntaxError
    if (!isValidCustomElementName(name_str)) {
        return error.SyntaxError;
    }

    // Step 2: If already defined, return resolved promise with constructor
    if (internal.getDefinitionByName(name_str)) |def| {
        // Cast the function pointer to anyopaque pointer
        return @ptrCast(def.constructor);
    }

    // Step 3: Create/return pending promise
    // For now, we store a waiter and return a placeholder
    // TODO: Integrate with proper Promise implementation
    const waiter = InternalState.WhenDefinedWaiter{};
    try internal.when_defined_waiters.put(internal.allocator, try internal.allocator.dupe(u8, name_str), waiter);

    // Return placeholder - in reality this would be a Promise object
    // For now, throw error to indicate async pending state
    return error.NotImplemented;
}

// ============================================================================
// Helper Functions for Custom Element Reactions
// ============================================================================

/// Look up a custom element definition given registry, namespace, localName, and is value
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#look-up-a-custom-element-definition
pub fn lookUpCustomElementDefinition(
    registry: ?*runtime.Instance,
    namespace: ?[]const u8,
    local_name: []const u8,
    is_value: ?[]const u8,
) ?*CustomElementDefinition {
    // Step 1: If registry is null, return null
    if (registry == null) return null;

    // Step 2: If namespace is not HTML namespace, return null
    const html_namespace = "http://www.w3.org/1999/xhtml";
    if (namespace) |ns| {
        if (!std.mem.eql(u8, ns, html_namespace)) return null;
    } else {
        return null;
    }

    const internal = getInternal(registry.?) orelse return null;

    // Step 3: If definition set contains item with name and local name both equal to localName, return it
    if (internal.getDefinitionByName(local_name)) |def| {
        if (std.mem.eql(u8, def.local_name, local_name)) {
            return def;
        }
    }

    // Step 4: If definition set contains item with name equal to is and local name equal to localName, return it
    if (is_value) |is_val| {
        if (internal.getDefinitionByName(is_val)) |def| {
            if (std.mem.eql(u8, def.local_name, local_name)) {
                return def;
            }
        }
    }

    // Step 5: Return null
    return null;
}

// ============================================================================
// Tests
// ============================================================================

test "isValidCustomElementName" {
    // Valid names
    try std.testing.expect(isValidCustomElementName("my-element"));
    try std.testing.expect(isValidCustomElementName("x-foo"));
    try std.testing.expect(isValidCustomElementName("my-custom-element"));
    try std.testing.expect(isValidCustomElementName("a-b"));

    // Invalid names - no hyphen
    try std.testing.expect(!isValidCustomElementName("myelement"));
    try std.testing.expect(!isValidCustomElementName("div"));

    // Invalid names - doesn't start with lowercase
    try std.testing.expect(!isValidCustomElementName("My-element"));
    try std.testing.expect(!isValidCustomElementName("1-element"));
    try std.testing.expect(!isValidCustomElementName("-element"));

    // Invalid names - contains uppercase
    try std.testing.expect(!isValidCustomElementName("my-Element"));

    // Invalid names - reserved names
    try std.testing.expect(!isValidCustomElementName("annotation-xml"));
    try std.testing.expect(!isValidCustomElementName("color-profile"));
    try std.testing.expect(!isValidCustomElementName("font-face"));

    // Invalid names - empty
    try std.testing.expect(!isValidCustomElementName(""));
}

test "isKnownHTMLElement" {
    try std.testing.expect(isKnownHTMLElement("div"));
    try std.testing.expect(isKnownHTMLElement("button"));
    try std.testing.expect(isKnownHTMLElement("span"));
    try std.testing.expect(isKnownHTMLElement("input"));
    try std.testing.expect(!isKnownHTMLElement("my-element"));
    try std.testing.expect(!isKnownHTMLElement("unknown"));
}

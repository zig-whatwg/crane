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
const dom_names = @import("dom").names;
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
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

pub const CustomElementDefinition = @import("html_core").custom_element_definition.Definition(runtime, engine);

/// Free a list of strings and the list.
fn freeStrings(allocator: Allocator, strings: []const []const u8) void {
    for (strings) |string| allocator.free(string);
    if (strings.len > 0) allocator.free(strings);
}

/// Internal state for CustomElementRegistry implementation
pub const InternalState = struct {
    allocator: Allocator,

    /// Whether this is a scoped registry (created via new CustomElementRegistry())
    is_scoped: bool = false,

    /// Set of documents using this scoped registry
    scoped_document_set: std.ArrayListUnmanaged(*runtime.Instance) = .empty,

    /// Custom element definitions (name -> definition)
    definitions: std.StringHashMapUnmanaged(*CustomElementDefinition) = .empty,

    /// Whether element definition is currently running (prevents reentrant invocation)
    element_definition_is_running: bool = false,

    /// "when-defined promise map": a name (OWNED key) to the promise
    /// whenDefined() handed out for it (OWNED capability).
    when_defined: std.StringHashMapUnmanaged(engine.PromiseCapability) = .empty,

    pub fn init(allocator: Allocator) !*InternalState {
        const state = try allocator.create(InternalState);
        state.* = .{
            .allocator = allocator,
        };
        return state;
    }

    pub fn deinit(self: *InternalState) void {
        var it = self.definitions.valueIterator();
        while (it.next()) |def| {
            def.*.deinit();
        }
        self.definitions.deinit(self.allocator);
        self.scoped_document_set.deinit(self.allocator);
        var promises = self.when_defined.iterator();
        while (promises.next()) |entry| {
            engine.releasePromiseCapability(entry.value_ptr);
            self.allocator.free(entry.key_ptr.*);
        }
        self.when_defined.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Look up a definition by name
    pub fn getDefinitionByName(self: *InternalState, name: []const u8) ?*CustomElementDefinition {
        return self.definitions.get(name);
    }

    /// The definition whose constructor is `constructor` (SameValue), or
    /// null.
    pub fn getDefinitionByConstructor(self: *InternalState, realm: runtime.Context, constructor: runtime.JSValue) ?*CustomElementDefinition {
        var it = self.definitions.valueIterator();
        while (it.next()) |def| {
            if (engine.sameValue(realm, def.*.constructor.function.value, constructor)) return def.*;
        }
        return null;
    }

    /// Check if a name is already defined
    pub fn hasDefinition(self: *InternalState, name: []const u8) bool {
        return self.definitions.contains(name);
    }

    /// Add a new definition
    pub fn addDefinition(self: *InternalState, def: *CustomElementDefinition) !void {
        try self.definitions.put(self.allocator, def.name, def);
    }
};

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
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
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &CustomElementRegistry.vtable, ctx);
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
    // The binding hands the constructor over: take it before anything can
    // fail. The definition keeps it; every other way out releases it.
    const constructor = engine.takeCallbackFunction(@ptrCast(constructor_data));
    var kept = false;
    defer if (!kept) constructor.release();

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;
    const realm = instance.ctx;
    const constructor_value = constructor.function.value;

    const name_str = name.asSlice();

    // Step 1: "If IsConstructor(constructor) is false, then throw a
    // TypeError." The binding checked only that it is callable.
    if (!engine.isConstructor(realm, constructor_value)) return error.TypeError;

    // Step 2: If name is not a valid custom element name, throw SyntaxError
    if (!dom_names.isValidCustomElementName(name_str)) {
        return error.SyntaxError;
    }

    // Step 3: If registry already has a definition with this name, throw NotSupportedError
    if (internal.hasDefinition(name_str)) {
        return error.NotSupportedError;
    }

    // Step 4: "If this's custom element definition set contains an item with
    // constructor constructor, then throw a "NotSupportedError"
    // DOMException." SameValue: each call converts the argument afresh.
    if (internal.getDefinitionByConstructor(realm, constructor_value) != null) {
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
            if (dom_names.isValidCustomElementName(extends_str)) {
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

    // Steps 10-13: formAssociated, disableInternals and disableShadow false,
    // observedAttributes empty.
    var collected: Collected = .{};

    // Step 14: "Run the following steps while catching any exceptions" ...
    const read = readDefinitionSteps(realm, allocator, constructor_value, &collected);
    // "Then, regardless of whether the above steps threw an exception or
    // not: set this's element definition is running to false."
    internal.element_definition_is_running = false;
    // "Finally, if the steps threw an exception, rethrow that exception."
    read catch |err| {
        collected.deinit(allocator);
        return err;
    };

    // Step 15: "Let definition be a new custom element definition with name
    // name, local name localName, constructor constructor, observed
    // attributes observedAttributes, lifecycle callbacks lifecycleCallbacks,
    // form-associated formAssociated, disable internals disableInternals,
    // and disable shadow disableShadow."
    const def = CustomElementDefinition.init(allocator, name_str, local_name, constructor) catch |err| {
        collected.deinit(allocator);
        return err;
    };
    kept = true;
    def.observed_attributes = collected.observed_attributes;
    def.lifecycle_callbacks = collected.lifecycle_callbacks;
    def.form_associated = collected.form_associated;
    def.disable_internals = collected.disable_internals;
    def.disable_shadow = collected.disable_shadow;
    errdefer def.deinit();

    // Step 16: "Append definition to this's custom element definition set."
    try internal.addDefinition(def);
    def.registry = instance;
    if (@import("html").custom_elements.stateForRealm(instance.ctx)) |agent_state| {
        def.agent_definition_count = &agent_state.definition_count;
        agent_state.definition_count += 1;
    }

    // Steps 17-18: "upgrade particular elements within a document". Upgrade
    // constructs each candidate through the definition's constructor, which
    // Crane cannot do yet: [HTMLConstructor] and the construction stack are
    // the custom-elements construction work (tmp/plans/lane-domcore-handoff.md).
    // TODO(custom-elements): enqueue a custom element upgrade reaction for
    // each candidate once upgrades construct.

    // Step 19: "If this's when-defined promise map[name] exists: resolve it
    // with constructor, and remove it."
    if (internal.when_defined.fetchRemove(name_str)) |entry| {
        var capability = entry.value;
        engine.resolvePromise(&capability, constructor_value) catch {};
        engine.releasePromiseCapability(&capability);
        allocator.free(entry.key);
    }
}

/// What define()'s step 14 reads off the constructor and its prototype.
const Collected = struct {
    lifecycle_callbacks: CustomElementDefinition.LifecycleCallbacks = .{},
    observed_attributes: []const []const u8 = &.{},
    form_associated: bool = false,
    disable_internals: bool = false,
    disable_shadow: bool = false,

    fn deinit(self: *Collected, allocator: Allocator) void {
        self.lifecycle_callbacks.deinit(allocator);
        freeStrings(allocator, self.observed_attributes);
        self.observed_attributes = &.{};
    }
};

/// define() step 14's steps, in order: every Get is script-visible (a
/// getter or a Proxy trap runs), and what one throws ends the steps and is
/// rethrown by define() (error.ExceptionPending), as is the TypeError of a
/// non-object prototype or a non-callable callback (error.TypeError).
fn readDefinitionSteps(realm: runtime.Context, allocator: Allocator, constructor: runtime.JSValue, out: *Collected) anyerror!void {
    // Step 14.1: "Let prototype be ? Get(constructor, "prototype")."
    const prototype = try engine.getProperty(realm, constructor, "prototype");
    defer prototype.release();

    // Step 14.2: "If prototype is not an Object, then throw a TypeError."
    if (engine.typeOf(realm, prototype.value) != .object) return error.TypeError;

    // Steps 14.3-14.4: for each name of lifecycleCallbacks, in the map's
    // order, "Let callbackValue be ? Get(prototype, callbackName)" and, if
    // it is not undefined, convert it to a Function. The order is the
    // living standard's - connectedMoveCallback third, as WPT checks; an
    // older text listed it after adoptedCallback.
    inline for (.{ "connectedCallback", "disconnectedCallback", "connectedMoveCallback", "adoptedCallback", "attributeChangedCallback" }) |callback_name| {
        @field(out.lifecycle_callbacks, callback_name) = try functionProperty(realm, prototype.value, callback_name);
    }

    // Step 14.5: "If lifecycleCallbacks["attributeChangedCallback"] is not
    // null": observedAttributes from ? Get(constructor,
    // "observedAttributes"), converted to a sequence<DOMString>.
    if (out.lifecycle_callbacks.attributeChangedCallback != null) {
        out.observed_attributes = try stringSequenceProperty(realm, allocator, constructor, "observedAttributes");
    }

    // Steps 14.6-14.10: disabledFeatures, the same way; "internals" and
    // "shadow" in it set disableInternals and disableShadow.
    const disabled_features = try stringSequenceProperty(realm, allocator, constructor, "disabledFeatures");
    defer freeStrings(allocator, disabled_features);
    for (disabled_features) |feature| {
        if (std.mem.eql(u8, feature, "internals")) out.disable_internals = true;
        if (std.mem.eql(u8, feature, "shadow")) out.disable_shadow = true;
    }

    // Steps 14.11-14.12: "Let formAssociatedValue be ? Get(constructor,
    // "formAssociated"). Set formAssociated to the result of converting
    // formAssociatedValue to a boolean."
    const form_associated = try engine.getProperty(realm, constructor, "formAssociated");
    defer form_associated.release();
    out.form_associated = engine.toBoolean(realm, form_associated.value);

    // Step 14.13: a form-associated element's four callbacks, likewise.
    if (out.form_associated) {
        inline for (.{ "formAssociatedCallback", "formResetCallback", "formDisabledCallback", "formStateRestoreCallback" }) |callback_name| {
            @field(out.lifecycle_callbacks, callback_name) = try functionProperty(realm, prototype.value, callback_name);
        }
    }
}

/// "Let callbackValue be ? Get(prototype, callbackName). If callbackValue is
/// not undefined, then set lifecycleCallbacks[callbackName] to the result of
/// converting callbackValue to the Web IDL Function callback type" - which
/// throws a TypeError for a value that is not callable. OWNED, or null.
fn functionProperty(realm: runtime.Context, object: runtime.JSValue, property: []const u8) anyerror!?engine.CallbackFunction {
    const value = try engine.getProperty(realm, object, property);
    if (engine.typeOf(realm, value.value) == .undefined) {
        value.release();
        return null;
    }
    if (!engine.isCallable(realm, value.value)) {
        value.release();
        return error.TypeError;
    }
    return .{ .function = value, .context = engine.incumbentRealm() };
}

/// "Let iterable be ? Get(constructor, property). If iterable is not
/// undefined, then set result to the result of converting iterable to a
/// sequence<DOMString>. Rethrow any exceptions from the conversion." OWNED;
/// empty when the property is undefined.
fn stringSequenceProperty(realm: runtime.Context, allocator: Allocator, constructor: runtime.JSValue, property: []const u8) anyerror![]const []const u8 {
    const iterable = try engine.getProperty(realm, constructor, property);
    defer iterable.release();
    if (engine.typeOf(realm, iterable.value) == .undefined) return &.{};
    // WebIDL sequence<T> conversion: a value with no @@iterator method is a
    // TypeError.
    const strings = (try engine.convertToSequenceOfDOMStrings(realm, iterable.value, allocator)) orelse return error.TypeError;
    return strings;
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
pub fn call_get(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    const name_str = name.asSlice();

    // Step 1: If definition set contains an item with name, return that item's constructor
    if (internal.getDefinitionByName(name_str)) |def| {
        return constructorValue(instance.ctx, def);
    }

    // Step 2: no definition matches, so return undefined.
    //
    // This returned `error.NotImplemented` before, which V8 turns into a THROWN
    // exception - so `customElements.get('nope')` threw where the spec requires
    // it to hand back undefined, and feature detection of the form
    // `if (customElements.get(name))` blew up instead of taking the false branch.
    return runtime.JSValue.jsUndefined;
}

/// `def`'s constructor as a result: a hold of the caller's own (the
/// binding takes it).
fn constructorValue(realm: runtime.Context, def: *const CustomElementDefinition) !runtime.JSValue {
    return (try engine.retainValue(realm, def.constructor.function.value)).take();
}

/// Operation: getName(constructor)
/// Spec: https://html.spec.whatwg.org/multipage/custom-elements.html#dom-customelementregistry-getname
///
/// Returns the name for the given constructor, or null if not defined.
pub fn call_getName(instance: *runtime.Instance, constructor_data: callbacks.CustomElementConstructor) anyerror!?runtime.DOMString {
    // The binding hands the argument over; it is only compared.
    const constructor = engine.takeCallbackFunction(@ptrCast(constructor_data));
    defer constructor.release();
    const internal = getInternal(instance) orelse return error.InvalidStateError;

    // Step 1: "If this's custom element definition set contains an item with
    // constructor constructor, then return that item's name."
    if (internal.getDefinitionByConstructor(instance.ctx, constructor.function.value)) |def| {
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
/// A promise, in this's relevant realm, fulfilled with the constructor once
/// `name` is defined. The result is OWNED: the binding takes it.
pub fn call_whenDefined(instance: *runtime.Instance, name: runtime.DOMString) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const realm = instance.ctx;
    const name_str = name.asSlice();

    // Step 1: "If name is not a valid custom element name, then return a
    // promise rejected with a "SyntaxError" DOMException."
    if (!dom_names.isValidCustomElementName(name_str)) {
        const exception = try engine.createDOMException(realm, "SyntaxError", "The name is not a valid custom element name.");
        defer exception.release();
        return (try engine.createRejectedPromise(realm, exception.value)).take();
    }

    // Step 2: "If this's custom element definition set contains an item with
    // name name, then return a promise resolved with that item's
    // constructor."
    if (internal.getDefinitionByName(name_str)) |def| {
        return (try engine.createResolvedPromise(realm, def.constructor.function.value)).take();
    }

    // Step 3: "If this's when-defined promise map[name] does not exist, then
    // set this's when-defined promise map[name] to a new promise."
    const entry = try internal.when_defined.getOrPut(internal.allocator, name_str);
    if (!entry.found_existing) {
        entry.key_ptr.* = internal.allocator.dupe(u8, name_str) catch |err| {
            internal.when_defined.removeByPtr(entry.key_ptr);
            return err;
        };
        entry.value_ptr.* = engine.createPromise(realm) catch |err| {
            internal.allocator.free(entry.key_ptr.*);
            internal.when_defined.removeByPtr(entry.key_ptr);
            return err;
        };
    }

    // Step 4: "Return this's when-defined promise map[name]" - the same
    // promise every time; the binding gets a hold of its own.
    return (try engine.retainValue(realm, entry.value_ptr.promise)).take();
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

test "isKnownHTMLElement" {
    try std.testing.expect(isKnownHTMLElement("div"));
    try std.testing.expect(isKnownHTMLElement("button"));
    try std.testing.expect(isKnownHTMLElement("span"));
    try std.testing.expect(isKnownHTMLElement("input"));
    try std.testing.expect(!isKnownHTMLElement("my-element"));
    try std.testing.expect(!isKnownHTMLElement("unknown"));
}

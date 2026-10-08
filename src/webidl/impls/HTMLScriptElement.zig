//! Implementation for HTMLScriptElement interface
//!
//! Spec: https://html.spec.whatwg.org/multipage/scripting.html#the-script-element
//! HTML Standard §4.12.1
//!
//! The script element allows authors to include dynamic script and data blocks
//! in their documents. This implementation handles the internal state required
//! for script preparation and execution per the HTML specification.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const HTMLScriptElement = interfaces.HTMLScriptElement;

// Parent class implementation
const HTMLElementImpl = @import("HTMLElement.zig");
const NodeImpl = @import("Node.zig");

// DOM mutation seam, for the post-connection steps below.
const dom_module = @import("dom");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

const log = std.log.scoped(.html_script_element);

// Use shared InstanceRegistry utility for internal state management
const utils = webidl.utils;
const Registry = utils.InstanceRegistry(InternalState);

pub const State = HTMLScriptElement.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

// The script element's processing-model state - its type and result, and
// the flags "prepare the script element" reads and sets - is defined in
// html/script_element.zig, where html's processing model can see it too.
// This impl keeps one per element (in its registry block, for the element's
// life) and installs the hook that reaches it.
const script_element_state = @import("html").script_element;

/// Internal state for HTMLScriptElement: the script element's state.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
pub const InternalState = script_element_state.State;

/// Get the internal state from an instance - also what `script_element.of`
/// answers, for html's script processing model.
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Registry.get(instance);
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A script element that becomes connected must run "prepare the script
    // element", and one whose children change may too.
    dom_module.mutation.registerPostConnectionStepsCallback(&scriptPostConnectionStepsCallback) catch |err| {
        log.warn("script post-connection steps not registered: {}", .{err});
    };
    dom_module.mutation.registerChildrenChangedCallback(&scriptChildrenChangedCallback) catch |err| {
        log.warn("script children changed steps not registered: {}", .{err});
    };
    // html's script processing model reaches its state.
    script_element_state.install(.{ .state = &getInternal });
    @import("html").script_execution.installFetchHooks();
    // And a clone of one must not run again: the cloning steps copy "already
    // started" (HTML § 4.12.1.1).
    dom_module.cloning_steps.install(&cloningSteps);
    // And a connected one whose src is set prepares itself again.
    dom_module.attribute_change_steps.install("script", &attributeChangeSteps);
    // The parsers set its parser document, force async and already started.
    dom_module.script_elements.install(.{
        .mark_parser_inserted = &markParserInsertedStep,
        .mark_already_started = &markAlreadyStartedStep,
        .script_text = &scriptTextStep,
        .delays_load_event = &scriptsDelayLoadEvent,
    });
}

/// HTML script processing model: a true delaying flag delays the
/// preparation-time document, even after the element is moved or removed.
fn scriptsDelayLoadEvent(document: *runtime.Instance) bool {
    const generation = runtime.SlabAllocator.generationOf(document);
    var entries = Registry.iterator() orelse return false;
    while (entries.next()) |entry| {
        const internal = entry.internal;
        if (internal.delaying_the_load_event and internal.preparation_time_document == document and
            internal.preparation_time_document_generation == generation) return true;
    }
    return false;
}

/// dom.script_elements: the element's script text (Trusted Types 4.1.2.1).
fn scriptTextStep(element: *runtime.Instance) ?*dom_module.script_elements.ScriptText {
    const internal = getInternal(element) orelse return null;
    return &internal.script_text;
}

/// Initialize instance (creates the instance)
/// Chains to parent class: HTMLElement → Element → Node → EventTarget
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    // Chain to parent class (HTMLElement) which chains to Element → Node → EventTarget
    const instance = try HTMLElementImpl.init(allocator, StateType, vtable, ctx);
    errdefer HTMLElementImpl.deinit(instance);

    // Set node type to ELEMENT_NODE (already set by Element.init)
    // Set local name to "script"
    try NodeImpl.setLocalName(instance, runtime.DOMString.initInterned("script"));

    // Initialize HTMLScriptElement's internal state in registry
    const ArenaAllocator = @import("runtime").ArenaAllocator;
    // The registry owns this block, so `Registry.remove` returns it to the
    // arena. With `set` it was dropped from the map and held to process
    // exit - 904 bytes per discarded element, measured.
    const internal = try Registry.createIn(instance, ArenaAllocator.get());
    internal.* = InternalState.init(allocator);

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    // Clean up internal state from registry
    if (Registry.get(instance)) |internal| {
        internal.deinit();
    }
    Registry.remove(instance);

    // Chain to parent deinit
    HTMLElementImpl.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &HTMLScriptElement.vtable, ctx);
    errdefer deinit(instance);

    return instance;
}

// =============================================================================
// Script element state, as this impl's own steps read it
// =============================================================================

/// Whether the script is parser-inserted: its parser document is not null.
fn isParserInserted(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.parser_document != null;
}

/// The script's already started flag.
fn hasAlreadyStarted(instance: *runtime.Instance) bool {
    const internal = getInternal(instance) orelse return false;
    return internal.already_started;
}

// =============================================================================
// Content Attribute Reflection Helpers
// Spec: https://html.spec.whatwg.org/multipage/dom.html#reflecting-content-attributes-in-idl-attributes
// =============================================================================

const ElementImpl = @import("Element.zig");

/// Get a content attribute value from this element
fn getContentAttribute(instance: *runtime.Instance, name: []const u8) ?runtime.DOMString {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return null;

    // Search attributes for matching name using findAttribute
    if (elem_internal.findAttribute(null, name)) |attr| {
        return runtime.DOMString.initInterned(attr.value);
    }
    return null;
}

/// Set content attribute `name` - DOM "set an attribute value", the setter
/// steps of a reflected attribute - so the change is observed like any other.
fn setContentAttribute(instance: *runtime.Instance, name: []const u8, value: runtime.DOMString) !void {
    try ElementImpl.setAttributeValue(instance, name, value.asSlice(), null, null);
}

/// Check if a boolean content attribute exists (presence = true)
fn hasBooleanAttribute(instance: *runtime.Instance, name: []const u8) bool {
    const elem_internal = ElementImpl.getInternalState(instance) orelse return false;
    return elem_internal.findAttribute(null, name) != null;
}

/// Set or remove a boolean attribute (presence = true, absence = false)
fn setBooleanAttribute(instance: *runtime.Instance, name: []const u8, value: bool) !void {
    if (value) {
        // Set the attribute with empty value (presence means true)
        try setContentAttribute(instance, name, runtime.DOMString.initEmpty());
    } else {
        ElementImpl.removeAttributeByNamespaceAndLocalName(instance, null, name);
    }
}

// =============================================================================
// IDL Attribute Implementations - Content Attribute Reflection
// =============================================================================

/// Getter for type
/// Spec: [CEReactions, Reflect] attribute DOMString type;
/// Reflects the type content attribute.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "type") orelse runtime.DOMString.initEmpty();
}

/// Getter for src
/// Spec: [CEReactions, ReflectURL] attribute USVString src;
/// Reflects the src content attribute (URL-valued).
pub fn get_src(instance: *runtime.Instance) anyerror!runtime.USVString {
    // For ReflectURL, we should return the resolved URL, but for now return raw value
    // IMPORTANT: Clone the value - the interface layer will free the returned slice
    if (getContentAttribute(instance, "src")) |attr| {
        return try instance.ctx.allocator.dupe(u8, attr.asSlice());
    }
    return "";
}

/// Getter for noModule
/// Spec: [CEReactions, Reflect] attribute boolean noModule;
/// True if the nomodule attribute is present.
pub fn get_noModule(instance: *runtime.Instance) anyerror!bool {
    return hasBooleanAttribute(instance, "nomodule");
}

/// Getter for async
/// Spec: [CEReactions] attribute boolean async;
/// Special behavior: returns the "force async" flag OR the async attribute.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-async
pub fn get_async(instance: *runtime.Instance) anyerror!bool {
    // Per spec: The async IDL attribute controls whether the element will execute
    // asynchronously or not. If the element's "force async" flag is set, then,
    // on getting, the async IDL attribute must return true, and on setting,
    // the "force async" flag must first be unset...
    if (getInternal(instance)) |internal| {
        if (internal.force_async) {
            return true;
        }
    }
    return hasBooleanAttribute(instance, "async");
}

/// Getter for defer
/// Spec: [CEReactions, Reflect] attribute boolean defer;
/// True if the defer attribute is present.
pub fn get_defer(instance: *runtime.Instance) anyerror!bool {
    return hasBooleanAttribute(instance, "defer");
}

/// Getter for blocking
/// Spec: [SameObject, PutForwards=value, Reflect] readonly attribute DOMTokenList blocking;
/// Returns the DOMTokenList for the blocking attribute.
/// TODO: Implement DOMTokenList support
pub fn get_blocking(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = instance;
    return error.NotImplemented; // Requires DOMTokenList implementation
}

/// Getter for crossOrigin
/// Spec: [CEReactions] attribute DOMString? crossOrigin;
/// Reflects the crossorigin content attribute (limited to known values).
pub fn get_crossOrigin(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    // Per spec, crossOrigin returns null if attribute is absent
    return getContentAttribute(instance, "crossorigin");
}

/// Getter for referrerPolicy
/// Spec: [CEReactions] attribute DOMString referrerPolicy;
/// Reflects the referrerpolicy content attribute.
pub fn get_referrerPolicy(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "referrerpolicy") orelse runtime.DOMString.initEmpty();
}

/// Getter for integrity
/// Spec: [CEReactions, Reflect] attribute DOMString integrity;
/// Reflects the integrity content attribute.
pub fn get_integrity(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "integrity") orelse runtime.DOMString.initEmpty();
}

/// Getter for fetchPriority
/// Spec: [CEReactions] attribute DOMString fetchPriority;
/// Reflects the fetchpriority content attribute.
pub fn get_fetchPriority(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "fetchpriority") orelse runtime.DOMString.initEmpty();
}

/// Getter for text
/// Spec: [CEReactions] attribute DOMString text;
/// Returns the child text content (concatenation of all Text node descendants).
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-text
pub fn get_text(instance: *runtime.Instance) anyerror!runtime.DOMString {
    // "On getting, it must return this element's child text content": the
    // data of its Text children, in tree order - not its descendants', and
    // not the source it was last prepared with, which the children may have
    // changed since (script-text.html's "Getter").
    //
    // Spec: https://dom.spec.whatwg.org/#concept-child-text-content
    // The binding frees the returned string with the context's allocator.
    const allocator = instance.ctx.allocator;
    var result = std.ArrayListUnmanaged(u8).empty;
    errdefer result.deinit(allocator);

    var child = NodeImpl.getFirstChild(instance);
    while (child) |c| : (child = NodeImpl.getNextSibling(c)) {
        const node_type = NodeImpl.getNodeType(c) orelse continue;
        // A CDATASection is a Text node.
        if (node_type != NodeImpl.NodeType.TEXT_NODE and node_type != NodeImpl.NodeType.CDATA_SECTION_NODE) continue;
        var data = try interfaces.CharacterData.get_data(c);
        defer data.deinit(allocator);
        try result.appendSlice(allocator, data.asSlice());
    }

    if (result.items.len == 0) return runtime.DOMString.initEmpty();
    return runtime.DOMString.initOwned(try result.toOwnedSlice(allocator));
}

/// Getter for charset (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString charset;
/// Reflects the charset content attribute.
pub fn get_charset(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "charset") orelse runtime.DOMString.initEmpty();
}

/// Getter for event (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString event;
/// Reflects the event content attribute.
pub fn get_event(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "event") orelse runtime.DOMString.initEmpty();
}

/// Getter for htmlFor (obsolete)
/// Spec: [CEReactions, Reflect=for] attribute DOMString htmlFor;
/// Reflects the "for" content attribute.
pub fn get_htmlFor(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return getContentAttribute(instance, "for") orelse runtime.DOMString.initEmpty();
}

/// Getter for attributionSrc
/// Spec: [CEReactions, Reflect] attribute USVString attributionSrc;
/// Reflects the attributionsrc content attribute.
pub fn get_attributionSrc(instance: *runtime.Instance) anyerror!runtime.USVString {
    // IMPORTANT: Clone the value - the interface layer will free the returned slice
    if (getContentAttribute(instance, "attributionsrc")) |attr| {
        return try instance.ctx.allocator.dupe(u8, attr.asSlice());
    }
    return "";
}

/// Setter for type
/// Spec: [CEReactions, Reflect] attribute DOMString type;
pub fn set_type(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "type", value);
}

/// Setter for src - Trusted Types 4.1.2.5:
/// [CEReactions] attribute (TrustedScriptURL or USVString) src;
pub fn set_src(instance: *runtime.Instance, value: typedefs.TrustedScriptURLOrUSVString) anyerror!void {
    const allocator = instance.ctx.allocator;
    // 1. "Let value be the result of calling get trusted type compliant
    // string with TrustedScriptURL, this's relevant global object, the given
    // value, HTMLScriptElement src, and script."
    const compliant = try dom_module.trusted_types.compliantStringFor(allocator, .script_url, instance, value, "HTMLScriptElement src");
    defer allocator.free(compliant);
    // 2. "Set this's src content attribute to value."
    try setContentAttribute(instance, "src", runtime.DOMString.initInterned(compliant));
}

/// Setter for noModule
/// Spec: [CEReactions, Reflect] attribute boolean noModule;
pub fn set_noModule(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBooleanAttribute(instance, "nomodule", value);
}

/// Setter for async
/// Spec: [CEReactions] attribute boolean async;
/// Special behavior: first unsets the "force async" flag.
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-async
pub fn set_async(instance: *runtime.Instance, value: bool) anyerror!void {
    // Per spec: On setting, the "force async" flag must first be unset...
    if (getInternal(instance)) |internal| {
        internal.force_async = false;
    }
    try setBooleanAttribute(instance, "async", value);
}

/// Setter for defer
/// Spec: [CEReactions, Reflect] attribute boolean defer;
pub fn set_defer(instance: *runtime.Instance, value: bool) anyerror!void {
    try setBooleanAttribute(instance, "defer", value);
}

/// Setter for crossOrigin
/// Spec: [CEReactions] attribute DOMString? crossOrigin;
pub fn set_crossOrigin(instance: *runtime.Instance, value: ?runtime.DOMString) anyerror!void {
    if (value) |v| {
        try setContentAttribute(instance, "crossorigin", v);
    } else {
        // Setting to null removes the attribute
        ElementImpl.removeAttributeByNamespaceAndLocalName(instance, null, "crossorigin");
    }
}

/// Setter for referrerPolicy
/// Spec: [CEReactions] attribute DOMString referrerPolicy;
pub fn set_referrerPolicy(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "referrerpolicy", value);
}

/// Setter for integrity
/// Spec: [CEReactions, Reflect] attribute DOMString integrity;
pub fn set_integrity(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "integrity", value);
}

/// Setter for fetchPriority
/// Spec: [CEReactions] attribute DOMString fetchPriority;
pub fn set_fetchPriority(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "fetchpriority", value);
}

/// Setter for text - Trusted Types 4.1.2.4:
/// [CEReactions] attribute (TrustedScript or DOMString) text;
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-text
pub fn set_text(instance: *runtime.Instance, value: typedefs.TrustedScriptOrDOMString) anyerror!void {
    const allocator = instance.ctx.allocator;
    // 1. "Let value be the result of calling get trusted type compliant
    // string with TrustedScript, this's relevant global object, the given
    // value, HTMLScriptElement text, and script."
    const compliant = try dom_module.trusted_types.compliantStringFor(allocator, .script, instance, value, "HTMLScriptElement text");
    defer allocator.free(compliant);
    // 2. "Set this's script text value to the given value" - before the
    // children change, whose steps may prepare the script.
    try setScriptText(instance, compliant);
    // 3. "String replace all with the given value within this."
    //
    // Caching alone is not enough. "Prepare the script element" step 5 takes
    // its source from the element's CHILD TEXT CONTENT, and step 6 returns
    // early when that is empty and there is no src - so `s.text = "..."`
    // followed by an insert produced a script the preparation algorithm
    // considered blank and refused to run. "String replace all" is what puts a
    // Text child there, and `Node.set_textContent` is that algorithm.
    try interfaces.Node.set_textContent(instance, runtime.DOMString.initInterned(compliant));

    // Still cached, because `get_text` reads the cache and `runClassicScript`
    // takes its source from it rather than re-walking the children.
    if (getInternal(instance)) |internal| try internal.cacheSourceText(compliant);
}

/// Trusted Types 4.1.2.1: set the script text slot to a copy of `text`.
fn setScriptText(instance: *runtime.Instance, text: []const u8) !void {
    const internal = getInternal(instance) orelse return;
    try internal.script_text.set(instance.ctx.allocator, text);
}

/// Getter for innerText - Trusted Types 4.1.2.2: "Return the result of
/// running get the text steps with this" - HTMLElement's.
pub fn get_innerText(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return interfaces.HTMLElement.get_innerText(instance);
}

/// Setter for innerText - Trusted Types 4.1.2.2:
/// [CEReactions] attribute (TrustedScript or [LegacyNullToEmptyString] DOMString) innerText;
pub fn set_innerText(instance: *runtime.Instance, value: typedefs.TrustedScriptOrDOMString) anyerror!void {
    const allocator = instance.ctx.allocator;
    // 1. Get trusted type compliant string with TrustedScript, this's
    // relevant global object, the given value, "HTMLScriptElement
    // innerText", and "script".
    const compliant = try dom_module.trusted_types.compliantStringFor(allocator, .script, instance, value, "HTMLScriptElement innerText");
    defer allocator.free(compliant);
    // 2. "Set this's script text value to value."
    try setScriptText(instance, compliant);
    // 3. "Run set the inner text steps with this and value" - HTMLElement's.
    try interfaces.HTMLElement.set_innerText(instance, runtime.DOMString.initInterned(compliant));
}

/// Getter for textContent - Trusted Types 4.1.2.3: "Return the result of
/// running get text content with this" - Node's.
pub fn get_textContent(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    return interfaces.Node.get_textContent(instance);
}

/// Setter for textContent - Trusted Types 4.1.2.3:
/// [CEReactions] attribute (TrustedScript or DOMString)? textContent;
pub fn set_textContent(instance: *runtime.Instance, value: ?typedefs.TrustedScriptOrDOMString) anyerror!void {
    const allocator = instance.ctx.allocator;
    // "If the given value is null, act as if it was the empty string."
    const given: typedefs.TrustedScriptOrDOMString = value orelse .{ .domstring = runtime.DOMString.initEmpty() };
    // 1. Get trusted type compliant string with TrustedScript, this's
    // relevant global object, the given value, "HTMLScriptElement
    // textContent", and "script".
    const compliant = try dom_module.trusted_types.compliantStringFor(allocator, .script, instance, given, "HTMLScriptElement textContent");
    defer allocator.free(compliant);
    // 2. "Set this's script text value to value."
    try setScriptText(instance, compliant);
    // 3. "Run set text content with this and value" - Node's.
    try interfaces.Node.set_textContent(instance, runtime.DOMString.initInterned(compliant));
}

/// Setter for charset (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString charset;
pub fn set_charset(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "charset", value);
}

/// Setter for event (obsolete)
/// Spec: [CEReactions, Reflect] attribute DOMString event;
pub fn set_event(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "event", value);
}

/// Setter for htmlFor (obsolete)
/// Spec: [CEReactions, Reflect=for] attribute DOMString htmlFor;
pub fn set_htmlFor(instance: *runtime.Instance, value: runtime.DOMString) anyerror!void {
    try setContentAttribute(instance, "for", value);
}

/// Setter for attributionSrc
/// Setter for attributionSrc
/// Spec: [CEReactions, Reflect] attribute USVString attributionSrc;
pub fn set_attributionSrc(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
    try setContentAttribute(instance, "attributionsrc", runtime.DOMString.initInterned(value));
}

/// Operation: supports (static method)
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#dom-script-supports
///
/// The static supports(type) method steps are:
/// 1. If type is "classic", then return true.
/// 2. If type is "module", then return true.
/// 3. If type is "importmap", then return true.
/// 4. If type is "speculationrules", then return true.
/// 5. Return false.
///
/// Note: The type argument has to exactly match these values; we do not perform
/// an ASCII case-insensitive match.
pub fn call_static_supports(instance: *runtime.Instance, @"type": runtime.DOMString) anyerror!bool {
    _ = instance; // Static method - instance not used

    const type_str = @"type".asSlice();

    // Step 1: If type is "classic", return true
    if (std.mem.eql(u8, type_str, "classic")) {
        return true;
    }

    // Step 2: If type is "module", return true
    if (std.mem.eql(u8, type_str, "module")) {
        return true;
    }

    // Step 3: If type is "importmap", return true
    if (std.mem.eql(u8, type_str, "importmap")) {
        return true;
    }

    // Step 4: If type is "speculationrules", return true
    if (std.mem.eql(u8, type_str, "speculationrules")) {
        return true;
    }

    // Step 5: Return false
    return false;
}

// =============================================================================
// Script Preparation and Execution Algorithms
// HTML Standard §4.12.1.1
// =============================================================================

// =============================================================================
// Post-connection steps
// =============================================================================

/// The script element's HTML element post-connection steps.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
/// Step 1 returns for a parser-inserted script. Step 2 prepares the element.
/// This phase follows the parent's children changed steps and the whole
/// insertion batch, as WebKit ScriptElement::postConnectionSteps does:
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/ScriptElement.cpp
///
/// The parser is excluded exactly as the spec excludes it: both tree-building
/// paths set the parser document on the element *before* appending it
/// (`dom_tree_adapter.createElementNode` and `HTMLParser.createDomNodeFromTreeNode`),
/// so `isParserInserted` is already true by the time this runs for them. That
/// matters: the parser appends the script element while it is still empty,
/// then prepares it at the end tag after adding its text children.
fn scriptPostConnectionStepsCallback(node: *NodeBase) void {
    // ELEMENT_NODE only.
    if (node.node_type != 1) return;
    if (!std.ascii.eqlIgnoreCase(node.node_name, "script")) return;

    // HTML element post-connection steps run only while the element is still
    // connected. An earlier script in the atomically inserted batch may have
    // removed this one before its turn.
    if (!node.is_connected) return;

    const instance_ptr = instance_bridge.getInstance(node) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    // Only an HTML script element: an SVG script's steps are
    // SVGScriptElement's.
    if (getInternal(instance) == null) return;

    // Prepare step 1 short-circuits on already started, and the parser owns its
    // own elements. Checking both here keeps a re-insertion from paying for a
    // full prepare that would return immediately anyway.
    if (hasAlreadyStarted(instance)) return;
    if (isParserInserted(instance)) return;

    const allocator = instance.ctx.allocator;
    _ = prepareScriptElement(allocator, instance) catch |err| {
        // A script that fails to prepare is not a document that fails to load.
        log.debug("post-connection steps: prepare failed: {}", .{err});
    };
}

/// The script element's children changed steps.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
/// "script children changed steps given changedNode are:
///  1. If the script element is not connected, then return.
///  2. Run the script HTML element post-connection steps, given changedNode."
/// and those steps are "1. If insertedNode is parser-inserted, then return.
/// 2. Prepare the script element given insertedNode."
///
/// This is how a script that was connected while EMPTY - so preparing it
/// returned at step 6 without setting already started - runs once text is put
/// in it: `s.append("code")`, `s.textContent = "code"`, or a Text child's data
/// changing (DOM "replace data" runs the parent's children changed steps).
fn scriptChildrenChangedCallback(parent: *NodeBase) void {
    if (parent.node_type != 1) return;
    if (!std.ascii.eqlIgnoreCase(parent.node_name, "script")) return;
    // Step 1.
    if (!parent.is_connected) return;

    const instance_ptr = instance_bridge.getInstance(parent) orelse return;
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_ptr));
    // Only an HTML script element: an SVG script's steps are
    // SVGScriptElement's.
    if (getInternal(instance) == null) return;

    // Prepare step 1 returns for an already-started script; checking it here
    // keeps every text edit of a script that has run from paying for a call.
    if (hasAlreadyStarted(instance)) return;
    // Post-connection step 1.
    if (isParserInserted(instance)) return;

    _ = prepareScriptElement(instance.ctx.allocator, instance) catch |err| {
        log.debug("children changed steps: prepare failed: {}", .{err});
    };
}

/// HTML § 4.12.1.1: "The cloning steps for script elements given node, copy,
/// and subtree are to set copy's already started to node's already started."
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
///
/// Without them a clone of a script that has run is a script that has not, and
/// inserting it runs the source again: `document.cloneNode(true)` from a page's
/// own script re-ran that script, which cloned the document again, forever.
fn cloningSteps(node: *runtime.Instance, copy: *runtime.Instance, subtree: bool) anyerror!void {
    _ = subtree;
    // Every clone runs every installed set; this one is for scripts only.
    if (node.stateAs(State) == null) return;
    const source = getInternal(node) orelse return;
    const target = getInternal(copy) orelse return;
    target.already_started = source.already_started;
}

/// dom.script_elements: "Set the element's parser document to the Document,
/// and set the element's force async to false."
fn markParserInsertedStep(element: *runtime.Instance, parser_document: *runtime.Instance) void {
    if (element.stateAs(State) == null) return;
    const internal = getInternal(element) orelse return;
    internal.parser_document = parser_document;
    internal.force_async = false;
}

/// dom.script_elements: "set the script element's already started to true"
/// (the HTML fragment parsing algorithm's scripts).
fn markAlreadyStartedStep(element: *runtime.Instance) void {
    if (element.stateAs(State) == null) return;
    const internal = getInternal(element) orelse return;
    internal.already_started = true;
}

/// The attribute change steps HTML defines for script elements, and the
/// force-async rule that rides on the same event.
///
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#script-processing-model
/// "1. If namespace is not null, then return.
///  2. If localName is src and element is connected, then run the script HTML
///     element post-connection steps, given element."
/// "When an async attribute is added to a script element el, the user agent
///  must set el's force async to false."
///
/// Only when src is SET: removing it prepares nothing. The spec text reads
/// "src" with no condition on the value, but the review of whatwg/html PR
/// 10188 that wrote these steps settled on "set or changed", which is what
/// browsers do and what remove-src-attr-prepare-a-script.html asserts:
/// preparing on a removal would run a connected, unstarted script's inline
/// text.
///
/// A script inserted with an invalid type, or with no src and no text, is
/// connected and not yet started; setting its src afterwards is what runs it
/// (change-src-attr-prepare-a-script.html, execution-timing/023.html).
fn attributeChangeSteps(
    element: *runtime.Instance,
    local_name: []const u8,
    old_value: ?[]const u8,
    value: ?[]const u8,
    namespace: ?[]const u8,
) void {
    // Installed for the local name "script", which an SVG script shares; the
    // steps are the HTML script element's.
    if (element.stateAs(State) == null) return;
    const internal = getInternal(element) orelse return;

    // Step 1.
    if (namespace != null) return;

    if (std.mem.eql(u8, local_name, "async") and old_value == null and value != null) {
        internal.force_async = false;
    }

    // Step 2, for a src that is set.
    if (!std.mem.eql(u8, local_name, "src") or value == null) return;
    if (!(NodeImpl.get_isConnected(element) catch false)) return;
    // The post-connection steps: step 1 returns for a parser-inserted script,
    // and prepare step 1 for one that has started.
    if (internal.parser_document != null) return;
    if (internal.already_started) return;
    _ = prepareScriptElement(element.ctx.allocator, element) catch |err| {
        log.debug("attribute change steps: prepare failed: {}", .{err});
    };
}

/// Prepare the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#prepare-the-script-element
///
/// This is the main entry point for script preparation. It determines the script type,
/// validates preconditions, and either immediately executes (for inline classic scripts)
/// or queues the script for later execution.
///
/// Returns true if the script was prepared successfully and may need execution,
/// false if preparation was aborted.
pub fn prepareScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!bool {
    // Import the script_execution module from html module
    const html = @import("html");
    return html.script_execution.prepareScriptElement(allocator, script_element);
}

/// Execute the script element
/// Spec: https://html.spec.whatwg.org/multipage/scripting.html#execute-the-script-element
///
/// Executes the prepared script using V8.
pub fn executeScriptElement(
    allocator: std.mem.Allocator,
    script_element: *runtime.Instance,
) ScriptExecutionError!void {
    // Import the script_execution module from html module
    const html = @import("html");
    return html.script_execution.executeScriptElement(allocator, script_element);
}

/// Script execution error type
pub const ScriptExecutionError = error{
    InvalidScriptElement,
    ScriptingDisabled,
    DocumentMismatch,
    ParseError,
    NetworkError,
    SecurityError,
    AlreadyStarted,
    NotConnected,
    OutOfMemory,
};

/// Clean up ALL remaining internal states.
pub fn cleanupAllRemainingInternal() void {
    Registry.deinitAllAndClear();
}

//! Implementation for HTMLMetaElement interface
//!
//! HTMLMetaElement represents a <meta> element in the DOM.
//! All attributes are reflected content attributes per HTML spec.
//! Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLMetaElement = interfaces.HTMLMetaElement;
const Element = interfaces.Element;
const dom_module = @import("dom");
const fetch = @import("fetch");
const instance_bridge = dom_module.instance_bridge;
const NodeBase = dom_module.NodeBase;

pub const State = HTMLMetaElement.State;

const log = std.log.scoped(.html_meta);

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    // A meta element's pragma runs when it is inserted into a document.
    dom_module.mutation.registerInsertionStepsCallback(&insertionSteps) catch {};
    // The "referrer" metadata name runs again when name or content changes.
    dom_module.attribute_change_steps.install("meta", &attributeChangeSteps);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLMetaElement.init(ctx.allocator, ctx);
    errdefer HTMLMetaElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

// =============================================================================
// Reflected Content Attributes
// =============================================================================
// All HTMLMetaElement attributes are reflected content attributes.
// Spec: https://html.spec.whatwg.org/multipage/semantics.html#the-meta-element

// =============================================================================
// Pragma directives (HTML §4.2.5.3)
// =============================================================================

/// "When a meta element is inserted into the document, if its http-equiv
/// attribute is present and represents one of the above states, then the
/// user agent must run the algorithm appropriate for that state."
///
/// Content Language, Refresh and Content Security Policy are modelled; the
/// other states (encoding declaration, default style,
/// set-cookie, X-UA-Compatible) do nothing here.
fn insertionSteps(node: *NodeBase) void {
    if (node.node_type != 1) return;
    // Brand-checked by the instance's state, not by `node.node_name`: an
    // element's NodeBase name is set only where its own init sets it (an
    // iframe's, a script's), and is empty for a meta element.
    const instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(node) orelse return));
    if (instance.stateAs(State) == null) return;
    // "Inserted into a document": the insertion steps ran for it and it is
    // now in a document tree - not a shadow tree
    // (attr-meta-http-equiv-refresh/not-in-shadow-tree).
    if (!inDocumentTree(node)) return;
    // The "referrer" metadata name runs for a meta element inserted into the
    // document.
    referrerMetadataName(instance);
    // An http-equiv that cannot be read names no state we can rule out: it
    // may be the Content Security Policy state, so the document's CSP list
    // fails closed (`pragmaUnreadable`). It used to `catch return`, and the
    // pragma - a policy among them - was dropped without a word.
    const http_equiv = (interfaces.Element.call_getAttribute(instance, runtime.DOMString.initInterned("http-equiv")) catch |err| {
        pragmaUnreadable(instance, err);
        return;
    }) orelse return;
    // The attribute is an enumerated attribute: its keywords match ASCII
    // case-insensitively.
    if (std.ascii.eqlIgnoreCase(http_equiv.asSlice(), "refresh")) refreshState(instance);
    if (std.ascii.eqlIgnoreCase(http_equiv.asSlice(), "content-security-policy")) contentSecurityPolicyState(instance, node);
    if (std.ascii.eqlIgnoreCase(http_equiv.asSlice(), "content-language")) contentLanguageState(instance);
}

/// HTML 4.2.5.3, content language state: step 1 requires a content attribute;
/// step 9 stores a Document default that survives removal of the meta.
/// Browser-majority deviation in steps 2-8: Blink HttpEquiv::Process and
/// WebKit Document::processMetaHttpEquiv store the raw content. HTML's token
/// extraction predates whatwg/html@53bc3803433e (2021-07-30), so this is not
/// newer-spec lag. wpt.fyi, aligned stable 23b0b89b1a, confirms Chrome and
/// Safari reject the whitespace-start/-end expectations; Firefox trims.
/// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/loader/http_equiv.cc
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Document.cpp
fn contentLanguageState(meta: *runtime.Instance) void {
    var content = (interfaces.Element.call_getAttribute(meta, runtime.DOMString.initInterned("content")) catch return) orelse return;
    defer content.deinit(meta.ctx.allocator);
    const document = (interfaces.Node.get_ownerDocument(meta) catch null) orelse return;
    dom_module.document_language.set(document, content.asSlice()) catch |err| {
        log.warn("content-language pragma could not be recorded ({s})", .{@errorName(err)});
    };
}

/// The insertion steps could not read `meta`'s http-equiv attribute (`err`):
/// the pragma it names is unknown. A Content Security Policy pragma fails
/// CLOSED - the node document's CSP list becomes unenforceable
/// (csp.CSPList.unenforceable), as for a policy that cannot be recorded -
/// and every other pragma fails visibly: logged, never silently skipped.
/// The read allocates nothing for "http-equiv" (Element.getAttribute
/// lowercases it in a buffer), so this is an element with no attribute
/// state; the path is kept closed for whatever else can fail there.
fn pragmaUnreadable(meta: *runtime.Instance, err: anyerror) void {
    log.warn("a meta element's http-equiv could not be read ({s}): its pragma is not run, and the document's CSP list fails closed", .{@errorName(err)});
    const document = (interfaces.Node.get_ownerDocument(meta) catch null) orelse return;
    const container = dom_module.policy_containers.of(document) orelse return;
    container.csp_list.markUnenforceable();
}

/// The Content Security Policy state (`http-equiv="content-security-policy"`):
/// it "enforces a Content Security Policy on a Document".
///
/// Fails CLOSED: a policy that cannot be read, parsed or recorded - out of
/// memory in any of its steps - leaves the document's CSP list
/// unenforceable (csp.CSPList.unenforceable), and every CSP decision against
/// it is "Blocked" (csp.integration.enforceMetaPolicy). The policy used to be
/// dropped (`csp_list.append(policy) catch policy.deinit()`, the parse
/// `catch return`), and the document ran as if its `<meta>` CSP were not
/// there (lane leaks2).
///
/// Spec: https://html.spec.whatwg.org/multipage/semantics.html#attr-meta-http-equiv-content-security-policy
fn contentSecurityPolicyState(meta: *runtime.Instance, node: *NodeBase) void {
    const document = (interfaces.Node.get_ownerDocument(meta) catch return) orelse return;
    const container = dom_module.policy_containers.of(document) orelse return;
    // Steps 1-2: whether the element has a policy to enforce. Not knowing
    // (out of memory reading its parent or its content) fails closed too.
    const content = metaPolicyContent(node, meta) catch {
        container.csp_list.markUnenforceable();
        return;
    } orelse return;
    // Steps 3-5, with the document's origin for a list that came from no
    // response and the document's URL for its reports.
    const self_origin = if (container.csp_list.self_origin == null) documentSelfOrigin(document, container.allocator) else null;
    const delivery_url: ?[]const u8 = interfaces.Document.get_URL(document) catch null;
    defer if (delivery_url) |url| document.ctx.allocator.free(url);
    @import("csp").integration.enforceMetaPolicy(&container.csp_list, content, self_origin, delivery_url);
}

/// Steps 1-2 of the Content Security Policy state: the meta element's
/// content attribute's value, when it is a child of a head element and the
/// value is not empty; null when there is nothing to enforce. BORROWED.
fn metaPolicyContent(node: *NodeBase, meta: *runtime.Instance) anyerror!?[]const u8 {
    // 1. "If the meta element is not a child of a head element, return."
    const parent = node.parent_node orelse return null;
    if (parent.node_type != 1) return null;
    const parent_instance: *runtime.Instance = @ptrCast(@alignCast(instance_bridge.getInstance(parent) orelse return null));
    var parent_name = try interfaces.Element.get_localName(parent_instance);
    defer parent_name.deinit(parent_instance.ctx.allocator);
    if (!std.mem.eql(u8, parent_name.asSlice(), "head")) return null;
    // 2. "If the meta element has no content attribute, or if that
    // attribute's value is the empty string, then return."
    const content = (try interfaces.Element.call_getAttribute(meta, runtime.DOMString.initInterned("content"))) orelse return null;
    if (content.asSlice().len == 0) return null;
    return content.asSlice();
}

/// `document`'s origin as a CSP self-origin, through its window's settings
/// object; null for an opaque one or a document with no window.
fn documentSelfOrigin(document: *runtime.Instance, allocator: std.mem.Allocator) ?@import("csp").Origin {
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return null;
    const settings = dom_module.global_settings.of(window) orelse return null;
    const origin = settings.origin(window) catch return null;
    defer window.ctx.allocator.free(origin);
    return fetch.internal.policy_container.selfOriginOf(allocator, origin) catch null;
}

/// The meta element's attribute change steps: HTML's "referrer" metadata
/// name runs when a meta element "has its name or content attributes
/// changed".
fn attributeChangeSteps(element: *runtime.Instance, local_name: []const u8, old_value: ?[]const u8, value: ?[]const u8, namespace: ?[]const u8) void {
    _ = old_value;
    _ = value;
    if (namespace != null) return;
    if (std.mem.eql(u8, local_name, "name") or std.mem.eql(u8, local_name, "content")) referrerMetadataName(element);
    if (!std.mem.eql(u8, local_name, "content") and !std.mem.eql(u8, local_name, "http-equiv")) return;
    if (element.stateAs(State) == null) return;
    const node = instance_bridge.getNodeBase(element) orelse return;
    if (!inDocumentTree(node)) return;
    // HTML's long-standing pragma trigger names only insertion. Blink's
    // HTMLMetaElement::ParseAttribute and WebKit's attributeChanged also
    // process connected content/http-equiv changes; Gecko's AfterSetAttr
    // does not. Follow that majority, without rerunning Refresh or CSP.
    // https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_meta_element.cc
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLMetaElement.cpp
    var http_equiv = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("http-equiv")) catch return) orelse return;
    defer http_equiv.deinit(element.ctx.allocator);
    if (std.ascii.eqlIgnoreCase(http_equiv.asSlice(), "content-language")) contentLanguageState(element);
}

/// HTML 4.2.5.1, the "referrer" metadata name: "If any meta element element
/// is inserted into the document, or has its name or content attributes
/// changed, user agents must run the following algorithm." Removing one
/// changes nothing, and the last inserted or changed one wins - there is no
/// tree order.
fn referrerMetadataName(element: *runtime.Instance) void {
    const node = instance_bridge.getNodeBase(element) orelse return;
    // 1. "If element is not in a document tree, then return."
    if (!inDocumentTree(node)) return;
    // 2. "If element does not have a name attribute whose value is an ASCII
    // case-insensitive match for "referrer", then return."
    const name = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("name")) catch |err| {
        log.warn("a meta element's name could not be read ({s}): the referrer metadata name is not run", .{@errorName(err)});
        return;
    }) orelse return;
    if (!std.ascii.eqlIgnoreCase(name.asSlice(), "referrer")) return;
    // 3. "If element does not have a content attribute, or that attribute's
    // value is the empty string, then return."
    const content = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned("content")) catch |err| {
        log.warn("a referrer meta element's content could not be read ({s}): its referrer policy is not set", .{@errorName(err)});
        return;
    }) orelse return;
    // 4-5. The value, ASCII lowercased, with the legacy values mapped.
    const policy = fetch.internal.policy_container.referrerPolicyFromMeta(content.asSlice()) orelse return;
    // 6. "If value is a referrer policy, then set element's node document's
    // policy container's referrer policy to policy."
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    const container = dom_module.policy_containers.of(document) orelse return;
    container.referrer_policy = policy;
}

/// Whether `node`'s root is a document: it is in a document tree.
fn inDocumentTree(node: *NodeBase) bool {
    var root = node;
    var depth: usize = 0;
    while (root.parent_node) |parent| : (depth += 1) {
        if (depth > 4096) return false;
        root = parent;
    }
    return root.node_type == 9;
}

/// The Refresh state (`http-equiv="refresh"`): a timed redirect.
fn refreshState(meta: *runtime.Instance) void {
    // Step 1: "If the meta element has no content attribute, or if that
    // attribute's value is the empty string, then return."
    const content = (interfaces.Element.call_getAttribute(meta, runtime.DOMString.initInterned("content")) catch |err| {
        log.warn("a refresh meta element's content could not be read ({s}): the refresh is not scheduled", .{@errorName(err)});
        return;
    }) orelse return;
    // Step 2: "Let input be the value of the element's content attribute."
    const input = content.asSlice();
    if (input.len == 0) return;
    // Step 3: "Run the shared declarative refresh steps with the meta
    // element's node document, input, and the meta element."
    const document = (interfaces.Node.get_ownerDocument(meta) catch null) orelse return;
    dom_module.document_lifecycle.declarativeRefresh(document, input, meta);
}

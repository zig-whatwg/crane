//! Implementation for HTMLBaseElement interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const HTMLBaseElement = interfaces.HTMLBaseElement;
const dom = @import("dom");

pub const State = HTMLBaseElement.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for implementation-specific data
/// Implementations can replace this with a real struct containing:
/// - Private data not exposed via WebIDL attributes
/// - Cached computations, buffers, etc.
pub const InternalState = struct {};

/// Installed at process start through this type's generated interface.
pub fn installHooks() void {
    dom.mutation.registerInsertionStepsCallback(inserted) catch @panic("base insertion hook allocation");
    dom.mutation.registerRemovingStepsCallback(removed) catch @panic("base removing hook allocation");
    dom.attribute_change_steps.install("base", attributeChanged);
}

fn baseInstance(node: *dom.NodeBase) ?*runtime.Instance {
    if (node.node_type != 1) return null;
    const instance = dom.instance_bridge.getInstanceTyped(runtime.Instance, node) orelse return null;
    return if (instance.stateAs(State) != null) instance else null;
}

/// A light-tree root: a base in a shadow tree never supplies the document URL.
fn documentRoot(node: *dom.NodeBase) ?*runtime.Instance {
    var root = node;
    while (root.parent_node) |parent| root = parent;
    if (root.node_type != 9) return null;
    return dom.instance_bridge.getInstanceTyped(runtime.Instance, root);
}

fn inserted(node: *dom.NodeBase) void {
    _ = baseInstance(node) orelse return;
    refreshBaseURL(documentRoot(node) orelse return);
}

fn removed(node: *dom.NodeBase, old_parent: ?*dom.NodeBase) void {
    _ = baseInstance(node) orelse return;
    // A removed host's shadow descendants receive that host's old parent
    // too. They remain rooted in a ShadowRoot and never supplied a base.
    var root = node;
    while (root.parent_node) |parent| root = parent;
    if (root.node_type == 11) return;
    // DOM removing steps run after unlinking; descendants receive the removed
    // subtree's original parent, which still identifies the old document.
    refreshBaseURL(documentRoot(old_parent orelse return) orelse return);
}

fn attributeChanged(instance: *runtime.Instance, name: []const u8, _: ?[]const u8, _: ?[]const u8, namespace: ?[]const u8) void {
    if (instance.stateAs(State) == null) return;
    if (namespace != null) return;
    if (!std.mem.eql(u8, name, "href") and !std.mem.eql(u8, name, "target")) return;
    const node = dom.instance_bridge.getNodeBase(instance) orelse return;
    refreshBaseURL(documentRoot(node) orelse return);
}

/// HTML 4.2.3 requires freezing on first-base selection/href changes.
/// Golden rule 2: Blink Document::ProcessBaseElement and WebKit
/// Document::processBaseElement reprocess on EVERY connected base insertion,
/// removal, href or target change. Gecko agrees on removal but restricts the
/// other triggers. This browser-majority rule also refreezes after pushState.
/// https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/core/html/html_base_element.cc
/// https://github.com/WebKit/WebKit/blob/main/Source/WebCore/html/HTMLBaseElement.cpp
fn refreshBaseURL(document: *runtime.Instance) void {
    setFrozenBaseURL(document) catch |err| {
        // A failed recomputation must not leave an obsolete base effective.
        dom.document_internals.setFrozenBaseURL(document, null) catch {};
        std.log.scoped(.html_base).warn("could not freeze a document base URL ({s}); using its fallback", .{@errorName(err)});
    };
}

/// HTML "set the frozen base URL", for the first base[href] in document order.
fn setFrozenBaseURL(document: *runtime.Instance) !void {
    // Step 1's node document is supplied by the mutation's document tree.
    const href = (try firstBaseHref(document)) orelse {
        try dom.document_internals.setFrozenBaseURL(document, null);
        respondToBaseUrlChanges(document);
        return;
    };
    var owned_href = href;
    defer owned_href.deinit(document.ctx.allocator);

    // Step 2 uses the FALLBACK, not the existing frozen URL, and the document
    // encoding. Thus a relative base is affected by neither itself nor another.
    const url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(url);
    const fallback = dom.document_lifecycle.aboutFallbackBaseUrl(document) orelse url;
    var encoding_name = try interfaces.Document.get_characterSet(document);
    defer encoding_name.deinit(document.ctx.allocator);
    const sniffing = @import("html_core").parser.encoding_sniffing;
    const encoding = sniffing.lookup(encoding_name.asSlice()) orelse sniffing.utf_8;
    const parsed = try @import("api_parser").encodingParseAndSerialize(document.ctx.allocator, owned_href.asSlice(), fallback, encoding);
    defer if (parsed) |value| document.ctx.allocator.free(value);

    // Step 3 forbids failed/data/javascript/CSP-blocked URLs. The older spec
    // says to freeze the fallback; WebKit processBaseElement clears its URL
    // and Gecko SetBaseURIUsingFirstBaseWithHref calls SetBaseURI(nullptr),
    // leaving a LIVE fallback. Blink freezes forbidden URLs but clears failed
    // parses. Golden rule 2 chooses the WebKit/Gecko majority. HTML's newer
    // f44b31b621 (2023-08-31) added only the scheme bans, which all three ship.
    // https://github.com/WebKit/WebKit/blob/main/Source/WebCore/dom/Document.cpp
    // https://github.com/mozilla-firefox/firefox/blob/main/dom/html/HTMLSharedElement.cpp
    const allowed = if (parsed) |value|
        !std.ascii.startsWithIgnoreCase(value, "data:") and
            !std.ascii.startsWithIgnoreCase(value, "javascript:") and
            isBaseAllowedForDocument(document, value)
    else
        false;
    if (!allowed) {
        try dom.document_internals.setFrozenBaseURL(document, null);
        return;
    }
    // Step 4: owned serialization, never a borrowed node or URL handle.
    try dom.document_internals.setFrozenBaseURL(document, parsed);
    // Step 5.
    respondToBaseUrlChanges(document);
}

/// HTML set-frozen step 3 invokes CSP 6.3.1.1; selection/lifecycle stay here.
/// The document adapter queues each violated policy's report during freezing.
fn isBaseAllowedForDocument(document: *runtime.Instance, serialized_url: []const u8) bool {
    return dom.csp_violations.isBaseAllowedForDocument(document, serialized_url);
}

fn respondToBaseUrlChanges(_: *runtime.Instance) void {
    // HTML 2.4.3 step 1: updating displayed URLs belongs to the host UI.
    // Step 2: Crane's :link/:visited match live attribute state, with no
    // resolved-URL cache to invalidate.
    // Steps 3-4 TODO(speculation rules owner): retain script parse results,
    // "update speculation rules", and "consider speculative loads".
}

fn firstBaseHref(document: *runtime.Instance) !?runtime.DOMString {
    const root = dom.instance_bridge.getNodeBase(document) orelse return error.InvalidStateError;
    var next = root.first_child;
    while (next) |node| {
        if (baseInstance(node)) |base| {
            if (try interfaces.Element.call_getAttribute(base, .initInterned("href"))) |href| return href;
        }
        if (node.first_child) |child| {
            next = child;
            continue;
        }
        var cursor = node;
        next = while (true) {
            if (cursor.next_sibling) |sibling| break sibling;
            const parent = cursor.parent_node orelse break null;
            if (parent == root) break null;
            cursor = parent;
        };
    }
    return null;
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    // Create instance through init()
    const instance = try HTMLBaseElement.init(ctx.allocator, ctx);
    errdefer HTMLBaseElement.deinit(instance);

    // TODO: Implement constructor logic with parameters

    return instance;
}

/// HTML 4.2.3, href getter steps 1-5. Unlike ordinary URL reflection this
/// uses the fallback base URL, ignoring every base element (including self).
pub fn get_href(instance: *runtime.Instance) anyerror!runtime.USVString {
    const sniffing = @import("html_core").parser.encoding_sniffing;
    const allocator = instance.ctx.allocator;
    // Steps 1-2: the node document and href, or the empty string. The IDL
    // result is a USVString even when parsing fails (step 4).
    const document = (try interfaces.Node.get_ownerDocument(instance)) orelse return error.InvalidStateError;
    const input = try dom.reflection.get(runtime.USVString, instance, .{ .name = "href" });
    errdefer if (input.len != 0) allocator.free(input);
    // Step 3: fallback URL and character encoding, never Node.baseURI.
    const url = try interfaces.Document.get_URL(document);
    defer document.ctx.allocator.free(url);
    const fallback = dom.document_lifecycle.aboutFallbackBaseUrl(document) orelse url;
    var encoding_name = try interfaces.Document.get_characterSet(document);
    defer encoding_name.deinit(document.ctx.allocator);
    const encoding = sniffing.lookup(encoding_name.asSlice()) orelse sniffing.utf_8;
    const serialized = try @import("api_parser").encodingParseAndSerialize(allocator, input, fallback, encoding);
    // Step 4 transfers the original string; step 5 transfers the serialization.
    if (serialized) |result| {
        if (input.len != 0) allocator.free(input);
        return result;
    }
    return input;
}

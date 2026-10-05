//! Navigables of navigable containers, and navigating by target name.
//!
//! HTML's navigable containers - iframe, object, embed (frame is HTML's too)
//! - each have a content navigable, which this module's steps create,
//! destroy and walk for any of them: "create a new child navigable",
//! "destroy a child navigable", a document's document-tree child navigables
//! and the inclusive descendant navigables of a document (7.3.1). An
//! element's content navigable is an html_core IFrameIntegration, which the
//! element's own impl holds and hands to these steps; no step names an impl.
//! The navigation machinery behind a navigable - "navigate", its fetch and
//! commit, the realm and Window a navigable's documents live in - is the
//! navigable containers' (HTMLIFrameElement's, which window.open() reaches
//! through `auxiliary_navigables.zig`), so it installs this hook: the realm
//! step of "create a new child navigable" (`create_browsing_context_and_document`)
//! and HTML "the rules for choosing a navigable" (7.3.1.7) followed by
//! "navigate", and "follow the hyperlink" (4.6.4) on top of them - what a
//! hyperlink's activation behaviour and a form's planned navigation do. The
//! elements that navigate - `a`, `area`, `form` - and the containers ask it
//! without importing it. The shape of `navigable_container.zig`.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#create-a-new-child-navigable
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#destroy-a-child-navigable
//! Spec: https://html.spec.whatwg.org/multipage/document-sequences.html#the-rules-for-choosing-a-navigable
//! Spec: https://html.spec.whatwg.org/multipage/links.html#following-hyperlinks-2
//!
//! lint-impls: hook for HTMLIFrameElement

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const html_core = @import("html_core");
const joint_history = html_core.navigation.joint_history;
const navigation_api = @import("navigation_api.zig");
const document_lifecycle = @import("document_lifecycle.zig");
const document_fetches = @import("document_fetches.zig");
const window_documents = @import("window_documents.zig");
const instance_bridge = @import("instance_bridge.zig");
const fire_event = @import("fire_event.zig");
const webidl = @import("webidl");
const dictionaries = @import("dictionaries");
const NodeBase = @import("node_base.zig").NodeBase;

const BrowsingContext = html_core.BrowsingContext;
const IFrameIntegration = html_core.IFrameIntegration;
const Origin = html_core.Origin;

/// `NavigationHistoryBehavior`.
pub const HistoryBehavior = enum { auto, push, replace };

/// A navigation by target name.
pub const Request = struct {
    /// The target: "", "_self", "_parent", "_top", "_blank", or a name.
    target: []const u8,
    /// The document whose node navigable "the rules for choosing a
    /// navigable" start from, when it is not the source document's: the
    /// window open steps choose from `this`'s navigable while the entry
    /// global's document navigates (`frame.contentWindow.open(url, "_self")`
    /// called by the page navigates the frame).
    current_document: ?*runtime.Instance = null,
    /// The URL, parsed and serialized.
    url: []const u8,
    noopener: bool = false,
    history_behavior: HistoryBehavior = .auto,
    /// Form submission step 22: the form document had not completely loaded
    /// when the form was submitted - decided then, not when the planned
    /// navigation runs, by which time an onload handler's submission has
    /// seen the load finish. The navigation replaces if the form document
    /// is the chosen navigable's active document.
    source_not_completely_loaded: bool = false,
    /// The element that navigates: a hyperlink, or a form's submitter.
    source_element: ?*runtime.Instance = null,
    user_involvement: navigation_api.UserInvolvement = .none,
    /// navigate()'s navigation API state. BORROWED.
    navigation_api_state: ?joint_history.SerializedState = null,
    /// A form's submission "as entity body": the navigation's document
    /// resource. BORROWED for the call.
    post_resource: ?PostResource = null,
    /// With it, the form's entry list as a FormData, for the navigate event.
    /// BORROWED for the call.
    form_data: ?*runtime.Instance = null,
};

/// HTML "POST resource": a request body and its request content-type.
pub const PostResource = struct {
    body: []const u8,
    content_type: []const u8,
};

/// What the navigable container supplies.
pub const Implementation = struct {
    navigate_by_target: *const fn (source_document: *runtime.Instance, request: Request) void,
    follow_hyperlink: *const fn (subject: *runtime.Instance, user_involvement: navigation_api.UserInvolvement) void,
    download_hyperlink: *const fn (subject: *runtime.Instance, user_involvement: navigation_api.UserInvolvement) void,
    traverse_navigable: *const fn (browsing_context: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8, from_entry_id: u64) void,
    find_by_name: *const fn (source_document: *runtime.Instance, name: []const u8) ?*runtime.Instance,
    /// "Create a new child navigable" step 3 for `container`, whose content
    /// navigable is `integration`'s: "create a new browsing context and
    /// document" - a browsing context in `container`'s node document's
    /// navigable, a realm whose global is a new Window, and the initial
    /// about:blank document - with `container` as the navigable's
    /// container. False when the node document has no navigable to be the
    /// parent (createHTMLDocument(), DOMParser) or creation failed.
    create_browsing_context_and_document: *const fn (container: *runtime.Instance, integration: *IFrameIntegration) bool,
};

var implementation: ?Implementation = null;

/// Called by the container's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// Whether the owner has installed its implementation: from process start on,
/// unless a test cleared it.
pub fn isInstalled() bool {
    return implementation != null;
}

/// Choose a navigable for `request.target` from `source_document`'s node
/// navigable and navigate it to `request.url`, using `source_document`.
pub fn navigateByTarget(source_document: *runtime.Instance, request: Request) void {
    const impl = implementation orelse return;
    impl.navigate_by_target(source_document, request);
}

/// HTML "follow the hyperlink created by" `subject` - an `a` or `area`
/// element - with no hyperlink suffix, with `user_involvement` (the
/// activating event's "user navigation involvement").
pub fn followHyperlink(subject: *runtime.Instance, user_involvement: navigation_api.UserInvolvement) void {
    const impl = implementation orelse return;
    impl.follow_hyperlink(subject, user_involvement);
}

/// HTML "download the hyperlink created by" `subject` - an `a` or `area`
/// element with a download attribute - with no hyperlink suffix, with
/// `user_involvement`.
pub fn downloadHyperlink(subject: *runtime.Instance, user_involvement: navigation_api.UserInvolvement) void {
    const impl = implementation orelse return;
    impl.download_hyperlink(subject, user_involvement);
}

/// A history traversal changes `browsing_context`'s document (an
/// `html_core` BrowsingContext): navigate it to its session history entry
/// `entry_id`, whose URL is `url`, without adding an entry - the entry takes
/// the document the navigation makes. `resource` is the entry's document
/// state's resource when it is a string (a srcdoc document's markup).
/// `from_entry_id` is the entry the navigable is on before the traversal -
/// the entry itself, for a reload - which the new document's
/// navigation.activation names (HTML "apply the history step" 12.1's
/// previousEntry).
pub fn traverseNavigable(browsing_context: *anyopaque, entry_id: u64, url: []const u8, resource: ?[]const u8, from_entry_id: u64) void {
    const impl = implementation orelse return;
    impl.traverse_navigable(browsing_context, entry_id, url, resource, from_entry_id);
}

/// HTML "find a navigable by target name" among the frames of
/// `current_document`'s page: the active window of the first whose target
/// name is `name`, or null. (The page's popups are the window open steps'
/// own to find.)
pub fn findByName(current_document: *runtime.Instance, name: []const u8) ?*runtime.Instance {
    const impl = implementation orelse return null;
    return impl.find_by_name(current_document, name);
}

// ============================================================================
// Child navigables of navigable containers (HTML 7.3.1)
// ============================================================================

/// The navigable containers: elements in the HTML namespace that can have a
/// content navigable. Only these are walked for a document's child
/// navigables.
const container_names = [_][]const u8{ "iframe", "frame", "object", "embed" };

fn isContainerName(name: []const u8) bool {
    for (container_names) |container| {
        if (std.ascii.eqlIgnoreCase(name, container)) return true;
    }
    return false;
}

/// HTML "create a new child navigable" for `container`, whose content
/// navigable `integration` will be: steps 1-3 and 7-9 are the navigation
/// machinery's (`create_browsing_context_and_document`: the browsing
/// context in the node document's navigable, its realm, Window and initial
/// about:blank document, `container` the navigable's container); step 12
/// here - the navigable's initial session history entry, at its
/// traversable's current step. Steps 4-5, the target name, are the
/// container's to set (an iframe's from its name attribute or `name`
/// setter). False when the node document has no navigable to be the parent
/// or creation failed.
///
/// A container whose earlier navigable was destroyed (`state` discarded)
/// retires that one's realm first (IFrameIntegration.retireRealmContext).
pub fn createChildNavigable(container: *runtime.Instance, integration: *IFrameIntegration) bool {
    const impl = implementation orelse return false;
    if (!impl.create_browsing_context_and_document(container, integration)) return false;
    if (integration.browsing_context) |bc| {
        placeInTreeOrder(bc, container);
        // Step 12: "Append the following session history traversal steps to
        // traversable: ... Insert historyEntry into the navigable's session
        // history entries".
        _ = bc.ensureHistoryEntries(&historyDocumentInfo) catch {};
    }
    return true;
}

/// A document's document-tree child navigables are in its containers' tree
/// order ("the document-tree child navigables": its navigable containers'
/// content navigables, in tree order), which window.length and window[i]
/// read through the parent's child list. A navigable is made when its
/// container asks - an iframe at its insertion, an object or embed once its
/// fetch is done - so a new child is moved from the end of the list to its
/// container's place among its siblings' containers. In place: the list
/// keeps its length.
fn placeInTreeOrder(child: *BrowsingContext, container: *runtime.Instance) void {
    const parent = child.parent orelse return;
    const items = parent.children.items;
    const from = std.mem.indexOfScalar(*BrowsingContext, items, child) orelse return;
    var to: usize = from;
    for (items, 0..) |sibling, i| {
        if (i >= from) break;
        const other: *runtime.Instance = @ptrCast(@alignCast(sibling.container orelse continue));
        const position = interfaces.Node.call_compareDocumentPosition(container, other) catch continue;
        // `other` follows `container` in tree order: `child` goes before it.
        if (position & interfaces.Node.get_DOCUMENT_POSITION_FOLLOWING() != 0) {
            to = i;
            break;
        }
    }
    if (to == from) return;
    std.mem.copyBackwards(*BrowsingContext, items[to + 1 .. from + 1], items[to..from]);
    items[to] = child;
}

/// BrowsingContext.ensureHistoryEntries's `info_of`: a document's URL and
/// origin, serialized, owned by `allocator` - "about:blank" for a document
/// with no URL, "null" for one with no window.
fn historyDocumentInfo(document: *anyopaque, allocator: std.mem.Allocator) anyerror!joint_history.DocumentInfo {
    const doc: *runtime.Instance = @ptrCast(@alignCast(document));
    const url: []u8 = blk: {
        const raw = interfaces.Document.get_URL(doc) catch break :blk try allocator.dupe(u8, "about:blank");
        defer doc.ctx.allocator.free(raw);
        break :blk try allocator.dupe(u8, if (raw.len == 0) "about:blank" else raw);
    };
    errdefer allocator.free(url);
    const origin: []u8 = blk: {
        const window = (interfaces.Document.get_defaultView(doc) catch null) orelse break :blk try allocator.dupe(u8, "null");
        const serialized = interfaces.Window.get_origin(window) catch break :blk try allocator.dupe(u8, "null");
        defer window.ctx.allocator.free(serialized);
        break :blk try allocator.dupe(u8, serialized);
    };
    return .{ .url = url, .origin = origin };
}

/// HTML "destroy a child navigable" given `container`, whose content
/// navigable is `integration`'s: its documents and their descendants'
/// unloaded and destroyed, its session history entries gone, its browsing
/// context discarded - it leaves its parent, `window.length` reflects that
/// at once - and its realm ended from a task. Run when the container is
/// removed from its document, and when an object or embed element stops
/// representing its navigable.
///
/// Deviation, stated: before "destroy a child navigable" runs, the frame's
/// document and its descendants are unloaded - pagehide and unload fire at
/// each, children first - as Chrome, Firefox and Safari all do when an
/// iframe is removed. HTML's "destroy a child navigable" does not unload,
/// and WPT's dom/nodes/insertion-removing-steps/insertion-removing-steps-iframe
/// removal subtests, which assert it, fail in all three browsers; pages
/// rely on the browsers' order (fetch/api/cors/cors-keepalive's "in unload"
/// posts to its parent from the frame's unload handler).
pub fn destroyChildNavigable(container: *runtime.Instance, integration: *IFrameIntegration) void {
    if (integration.state != .discarded) {
        if (activeDocumentOf(integration)) |active| {
            var documents = inclusiveDescendantDocuments(active, integration.allocator);
            defer documents.deinit(integration.allocator);
            var i = documents.items.len;
            while (i > 0) {
                i -= 1;
                const entry = documents.items[i];
                if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
                document_lifecycle.unload(entry.document);
            }
        }
    }
    // Step 4: "Inform the navigation API about child navigable destruction
    // given navigable."
    if (integration.state != .discarded) {
        if (integration.browsing_context) |bc| {
            if (bc.getActiveWindow()) |window| navigation_api.informAboutChildNavigableDestruction(@ptrCast(@alignCast(window)));
        }
    }
    // The documents of the frame and of every frame in it are destroyed:
    // their windows' timers and animation frames end here, though the
    // contexts live on while script holds the windows.
    if (integration.state != .discarded) {
        if (integration.browsing_context) |bc| destroyWindowDocuments(bc);
    }
    // Its entries, and its descendants', leave the traversable's history.
    if (integration.browsing_context) |bc| {
        if (bc.getTop().joint_history) |history| {
            var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
            defer tree.deinit(std.heap.page_allocator);
            bc.collectDescendants(std.heap.page_allocator, &tree) catch {};
            for (tree.items) |gone| history.removeNavigable(gone.id);
        }
    }
    // Step 5: "destroy a document and its descendants" given its active
    // document - children first.
    if (activeDocumentOf(integration)) |active| {
        var documents = inclusiveDescendantDocuments(active, integration.allocator);
        defer documents.deinit(integration.allocator);
        var i = documents.items.len;
        while (i > 0) {
            i -= 1;
            const entry = documents.items[i];
            if (runtime.SlabAllocator.generationOf(entry.document) != entry.generation) continue;
            document_lifecycle.destroy(entry.document);
        }
    }
    const was_delaying = integration.delaying_load;
    // Its realm ends at a task of its own.
    if (integration.state != .discarded) queueRemovedFrameRealmEnd(container, integration);
    integration.onRemovedFromDocument();
    // The node document may have been waiting on this navigable's
    // navigation to fire its load event. It has no content navigable now.
    if (was_delaying) {
        if (interfaces.Node.get_ownerDocument(container) catch null) |document| document_lifecycle.loadDelayMayHaveEnded(document);
    }
}

/// HTML "destroy a child navigable", for the documents: the active
/// documents of `bc`'s navigable and of every navigable inside it are
/// destroyed, so their windows' timers and animation frames end
/// (dom.window_documents) - though their realms live on for as long as
/// script holds the windows.
pub fn destroyWindowDocuments(bc: *BrowsingContext) void {
    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(std.heap.page_allocator);
    tree.append(std.heap.page_allocator, bc) catch return;
    bc.collectDescendants(std.heap.page_allocator, &tree) catch {};
    for (tree.items) |navigable| {
        const window: *runtime.Instance = @ptrCast(@alignCast(navigable.getActiveWindow() orelse continue));
        // "Destroy a document" step 2, "abort a document" step 2: the
        // fetches its script started are canceled, firing nothing.
        document_fetches.abortAll(window.ctx);
        window_documents.destroyed(window.ctx);
    }
}

/// HTML "destroy a child navigable", for the realm: a navigable whose
/// container goes takes its realm with it, and the realm ends at a task
/// queued here - never with the frame's own script on the stack (a frame
/// can remove its own container), and never at whatever point the collector
/// frees the removed element, which is when it used to end:
/// html/browsers/the-window-object/self-et-al.window.js read anything from 0
/// to 7 of 8 by when that happened. Blink ends it in
/// LocalWindowProxy::DisposeContext(kFrameIsDetached), which leaves the
/// global attached (engine.WindowRealmEnd.navigable_destroyed).
///
/// The container hands the realm over (`context_cleanup_data`), so neither
/// its collection nor an insertion that makes a new navigable ends or
/// retires it again. A task its loop drops needs nothing: the loop goes as
/// its page ends, and the page's realm ends its frames' realms first.
///
/// The realm does not end with this task (engine.WindowRealmEnd
/// .navigable_destroyed): its script activity stops, and its Window lives on
/// for as long as script holds its WindowProxy - `closed` reads true (its
/// browsing context is discarded), `document` answers - as the spec says and
/// Chrome, Edge and Firefox do (crane/fl-removed-frame-window-survives-gc.html).
/// The engine ends it once the collector takes it, or with its page.
///
/// The navigable's RETIRED realms - Windows its earlier navigations replaced
/// (IFrameIntegration.retired_realms) - end from tasks queued here too: the
/// whole navigable is destroyed. Left to the integration, they ended with the
/// element, which a removed element meets when the collector frees it - inside
/// V8's first-pass weak callback, where no engine call may be made: a wrapper
/// of the retired realm that died in the same collection had been zapped,
/// and the realm's end read it (fetch/origin/assorted.window.js, SIGSEGV in
/// v8::Value::IsProxy; crane/c4-removed-frame-retired-realm-gc.html).
fn queueRemovedFrameRealmEnd(container: *runtime.Instance, integration: *IFrameIntegration) void {
    const loop = container.ctx.getOptionalEventLoop() orelse return;
    // Every retired realm here was retired with the navigation machinery's
    // `retired_realm_destroy`, whose only input is the realm.
    for (integration.retired_realms.items) |retired| {
        loop.queueTask(.{ .callback = endRetiredRealm, .context = retired.data, .drop = null });
    }
    integration.retired_realms.clearRetainingCapacity();
    const data = integration.context_cleanup_data orelse return;
    integration.context_cleanup_data = null;
    loop.queueTask(.{ .callback = endRemovedFrameRealm, .context = data, .drop = null });
}

fn endRemovedFrameRealm(data: ?*anyopaque) void {
    engine.destroyWindowRealm(@ptrCast(@alignCast(data.?)), .navigable_destroyed);
}

/// A retired realm of a destroyed navigable: its WindowProxy went on to a
/// later realm, so nothing reaches its Window through it any more - it ends
/// as a navigation's old realm does.
fn endRetiredRealm(data: ?*anyopaque) void {
    engine.destroyWindowRealm(@ptrCast(@alignCast(data.?)), .global_detached);
}

/// The navigable's active document, as its browsing context records it.
fn activeDocumentOf(integration: *IFrameIntegration) ?*runtime.Instance {
    const browsing_context = integration.browsing_context orelse return null;
    const document = browsing_context.getActiveDocument() orelse return null;
    return @ptrCast(@alignCast(document));
}

/// One of a document's document-tree child navigables: a navigable
/// container in the document and its content navigable's browsing context.
pub const ChildNavigable = struct {
    container: *runtime.Instance,
    browsing_context: *BrowsingContext,
};

/// `document`'s document-tree child navigables, in its containers' tree
/// order: each navigable container element in `document` (iframe, frame,
/// object, embed) whose content navigable is a child of `document`'s
/// navigable - matched by the navigable's container. None when `document`
/// has no navigable (no window, or one a navigation replaced).
pub fn childNavigablesOf(document: *runtime.Instance, allocator: std.mem.Allocator) std.ArrayListUnmanaged(ChildNavigable) {
    var out: std.ArrayListUnmanaged(ChildNavigable) = .empty;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return out;
    const navigable = BrowsingContext.ofWindow(@ptrCast(window)) orelse return out;
    if (navigable.children.items.len == 0) return out;
    const root = instance_bridge.getNodeBase(document) orelse return out;
    collectContainers(navigable, root, &out, allocator, 0);
    return out;
}

fn collectContainers(navigable: *BrowsingContext, node: *NodeBase, out: *std.ArrayListUnmanaged(ChildNavigable), allocator: std.mem.Allocator, depth: usize) void {
    if (depth > 512) return;
    for (node.child_nodes.items()) |child| {
        if (child.node_type == 1 and isContainerName(child.node_name)) {
            if (instance_bridge.getInstance(child)) |ptr| {
                for (navigable.children.items) |bc| {
                    if (bc.container == ptr) {
                        out.append(allocator, .{ .container = @ptrCast(@alignCast(ptr)), .browsing_context = bc }) catch return;
                        break;
                    }
                }
            }
        }
        collectContainers(navigable, child, out, allocator, depth + 1);
    }
}

/// A document of `inclusiveDescendantDocuments`.
pub const DocumentEntry = struct {
    document: *runtime.Instance,
    generation: u64,
    /// The navigable whose active document this is; null for the root.
    browsing_context: ?*BrowsingContext,
};

/// `document` and the active documents of its descendant navigables, parents
/// first - HTML "inclusive descendant navigables" by their active documents.
/// Each is held with its slab generation, since script runs between the
/// collection and the use.
pub fn inclusiveDescendantDocuments(document: *runtime.Instance, allocator: std.mem.Allocator) std.ArrayListUnmanaged(DocumentEntry) {
    var out: std.ArrayListUnmanaged(DocumentEntry) = .empty;
    out.append(allocator, .{ .document = document, .generation = runtime.SlabAllocator.generationOf(document), .browsing_context = null }) catch return out;
    var index: usize = 0;
    while (index < out.items.len and out.items.len < 256) : (index += 1) {
        const parent = out.items[index].document;
        var children = childNavigablesOf(parent, allocator);
        defer children.deinit(allocator);
        for (children.items) |child| {
            const child_document: *runtime.Instance = @ptrCast(@alignCast(child.browsing_context.getActiveDocument() orelse continue));
            out.append(allocator, .{
                .document = child_document,
                .generation = runtime.SlabAllocator.generationOf(child_document),
                .browsing_context = child.browsing_context,
            }) catch break;
        }
    }
    return out;
}

/// The container's named access on its node document's window:
/// `window[name]` is the content navigable's WindowProxy, set on the parent's
/// global in the parent's realm. V8's named property interceptors do not
/// survive snapshot restore, so the property is set directly.
pub fn registerNamedProperty(integration: *IFrameIntegration, name: []const u8) void {
    const child_bc = integration.browsing_context orelse return;
    const parent_bc = child_bc.parent orelse return;
    const parent_window: *runtime.Instance = @ptrCast(@alignCast(parent_bc.active_window orelse return));
    const child_window: *runtime.Instance = @ptrCast(@alignCast(child_bc.active_window orelse return));
    // A Window converts to its WindowProxy.
    engine.setProperty(parent_window.ctx, .{ .instance = parent_window }, name, .{ .instance = child_window }) catch {};
}

/// HTML "content window": the content navigable's active WindowProxy - the
/// Window of its realm - or null when the container has none.
pub fn contentWindow(integration: *IFrameIntegration) ?*runtime.Instance {
    if (integration.state == .discarded) return null;
    if (!integration.hasRealmContext()) return null;
    const realm: runtime.Context = @ptrCast(@alignCast(integration.runtime_context orelse return null));
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// HTML "content document": the content navigable's active document if
/// its origin is same origin-domain with `accessor_origin` (the container
/// document's, the incumbent's in every case this engine reaches);
/// otherwise null.
pub fn contentDocument(integration: *IFrameIntegration, accessor_origin: Origin) ?*runtime.Instance {
    if (integration.state == .discarded) return null;
    const document = activeDocumentOf(integration) orelse return null;
    if (!integration.isContentDocumentAccessible(accessor_origin)) return null;
    return document;
}

/// A navigable container's kind - its local name, which "create navigation
/// params by fetching" step 10 makes the navigation request's destination
/// and, for a navigation its container document started, its initiator
/// type.
pub const ContainerKind = enum { iframe, frame, object, embed };

/// The kind of navigable container `container` is; null for an element that
/// is none.
pub fn containerKind(container: *runtime.Instance) ?ContainerKind {
    if (container.stateAs(interfaces.HTMLIFrameElement.State) != null) return .iframe;
    if (container.stateAs(interfaces.HTMLObjectElement.State) != null) return .object;
    if (container.stateAs(interfaces.HTMLEmbedElement.State) != null) return .embed;
    if (container.stateAs(interfaces.HTMLFrameElement.State) != null) return .frame;
    return null;
}

/// HTML "completely finish loading" step 5 for a navigable container that is
/// not an iframe - an object or embed element: "queue an element task on the
/// DOM manipulation task source given container to fire an event named load
/// at container" (the caller is that task) - and with that its navigable's
/// navigation no longer delays its node document's load event. As for an
/// iframe's load event steps, the delay ends before the event and the
/// document hears of it after: a load handler that navigates the navigable
/// again delays the document further.
pub fn containerLoadEventSteps(container: *runtime.Instance, integration: *IFrameIntegration) void {
    const was_delaying = integration.delaying_load;
    integration.delaying_load = false;
    const generation = runtime.SlabAllocator.generationOf(container);
    fireSimpleEvent(container, "load");
    // The handlers may have taken the element away.
    if (!was_delaying or runtime.SlabAllocator.generationOf(container) != generation) return;
    const document = (interfaces.Node.get_ownerDocument(container) catch null) orelse return;
    document_lifecycle.loadDelayMayHaveEnded(document);
}

/// DOM "fire an event" named `event_type` at `target`: an Event made in its
/// relevant realm, not bubbling, not cancelable, trusted.
pub fn fireSimpleEvent(target: *runtime.Instance, event_type: []const u8) void {
    const event = interfaces.Event.call_constructor(
        target.ctx,
        runtime.DOMString.initInterned(event_type),
        webidl.Opt(dictionaries.EventInit).passed(.{ .bubbles = false, .cancelable = false, .composed = false }),
    ) catch return;
    // Not `defer deinit`: a listener can keep the event, and its wrapper
    // then owns it.
    const generation = runtime.SlabAllocator.generationOf(event);
    defer event.releaseIfUnwrapped(generation);
    _ = fire_event.dispatchTrusted(target, event) catch {};
}

/// Parse a serialized origin ("http://host:port", "null") into an Origin:
/// an opaque one for "null" or anything that is not http(s).
pub fn parseOriginFromString(origin_str: []const u8) Origin {
    if (std.mem.eql(u8, origin_str, "null")) return Origin.createOpaque();
    const schemes = [_]struct { prefix: []const u8, scheme: []const u8, port: u16 }{
        .{ .prefix = "http://", .scheme = "http", .port = 80 },
        .{ .prefix = "https://", .scheme = "https", .port = 443 },
    };
    for (schemes) |s| {
        if (!std.mem.startsWith(u8, origin_str, s.prefix)) continue;
        const rest = origin_str[s.prefix.len..];
        const host_port_end = std.mem.indexOf(u8, rest, "/") orelse rest.len;
        const host_port = rest[0..host_port_end];
        if (std.mem.lastIndexOf(u8, host_port, ":")) |colon_idx| {
            const port = std.fmt.parseInt(u16, host_port[colon_idx + 1 ..], 10) catch s.port;
            return Origin.init(s.scheme, host_port[0..colon_idx], port);
        }
        return Origin.init(s.scheme, host_port, s.port);
    }
    return Origin.createOpaque();
}

/// A container's content navigable is going with its element: deinit it and
/// return its block to the arena it came from - unless a navigation step is
/// running script with it in hand (`busy`), which then does it when done
/// (`deinit_pending`, see `destroyContentNavigable`).
pub fn releaseContentNavigable(integration: *IFrameIntegration) void {
    if (integration.busy > 0) {
        integration.deinit_pending = true;
    } else {
        destroyContentNavigable(integration);
    }
}

/// Deinit `integration` and return its block to the arena it came from
/// (`runtime.ArenaAllocator`, where every container allocates its content
/// navigable).
pub fn destroyContentNavigable(integration: *IFrameIntegration) void {
    integration.deinit();
    const Arena = runtime.ArenaAllocator;
    if (Arena.tryGet() catch null) |arena| arena.destroy(IFrameIntegration, integration);
}

test "without an installed implementation nothing navigates" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var element: runtime.Instance = undefined;
    navigateByTarget(&element, .{ .target = "", .url = "about:blank" });
    followHyperlink(&element, .activation);
    downloadHyperlink(&element, .activation);
    traverseNavigable(@ptrCast(&element), 1, "about:blank", null, 1);
    try std.testing.expect(findByName(&element, "name") == null);
}

test "a serialized origin parses back to the origin it names; anything else is opaque" {
    const http = parseOriginFromString("http://web-platform.test:8000");
    try std.testing.expect(!http.is_opaque);
    try std.testing.expectEqualStrings("http", http.scheme);
    try std.testing.expectEqualStrings("web-platform.test", http.host);
    try std.testing.expectEqual(@as(?u16, 8000), http.port);
    const https = parseOriginFromString("https://www1.web-platform.test");
    try std.testing.expectEqualStrings("https", https.scheme);
    try std.testing.expectEqual(@as(?u16, 443), https.port);
    try std.testing.expect(parseOriginFromString("null").is_opaque);
    try std.testing.expect(parseOriginFromString("blob:whatever").is_opaque);
}

test "navigable containers are iframe, frame, object and embed" {
    for ([_][]const u8{ "iframe", "IFRAME", "frame", "object", "embed" }) |name| try std.testing.expect(isContainerName(name));
    for ([_][]const u8{ "img", "video", "frameset", "objects" }) |name| try std.testing.expect(!isContainerName(name));
}

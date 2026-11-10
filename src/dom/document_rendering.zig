//! HTML 3.1.6: the Document's render-blocking element set.
//! Document installs its state and eligibility answers; script preparation,
//! removal and the browser's rendering opportunity reach only this seam.
//! Elements are borrowed: their tree or prepared-script queue owns them.
//! Removing/discarding/destruction erases membership before that ownership ends.
//!
//! The `expect` link type (HTML 4.6.8.6) blocks rendering through the same
//! set; the elements that joined it through "process internal resource
//! link" are also kept in a subset, `expect_links`, which "process internal
//! resource links" iterates. That algorithm is the link element's: it
//! installs it here (`installInternalResourceLinks`), and the parser's pop
//! of its current node, the HTML insertion steps, id and name changes and
//! the end of parsing reach it through `processInternalResourceLinks`.
//! Spec: https://html.spec.whatwg.org/multipage/dom.html#render-blocking-mechanism
//! Spec: https://html.spec.whatwg.org/multipage/links.html#link-type-expect
//! lint-impls: hook for Document, HTMLLinkElement
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const document_lifecycle = @import("document_lifecycle.zig");
const element_data = @import("element_data.zig");
const Hook = @import("hook.zig").Hook;

/// Implementation policy: render blocking expires 30 seconds after the
/// relevant global's time origin. It never changes membership or execution.
pub const timeout_ms: f64 = 30_000;

pub const ElementSet = struct {
    allocator: std.mem.Allocator,
    elements: std.ArrayList(*runtime.Instance) = .empty,
    /// The members that joined through "process internal resource link"
    /// (expect links), in the order they joined: a subset of `elements`,
    /// kept in step by every removal.
    expect_links: std.ArrayList(*runtime.Instance) = .empty,

    pub fn init(allocator: std.mem.Allocator) ElementSet {
        return .{ .allocator = allocator };
    }
    pub fn deinit(self: *ElementSet) void {
        self.elements.deinit(self.allocator);
        self.expect_links.deinit(self.allocator);
        // Document's other owners may release elements during teardown while
        // its registry entry still exists. They see an empty, usable set.
        self.elements = .empty;
        self.expect_links = .empty;
    }
    pub fn contains(self: *const ElementSet, element: *runtime.Instance) bool {
        return std.mem.indexOfScalar(*runtime.Instance, self.elements.items, element) != null;
    }
    pub fn add(self: *ElementSet, element: *runtime.Instance) error{OutOfMemory}!void {
        if (!self.contains(element)) try self.elements.append(self.allocator, element);
    }
    /// Append `element` to the set as an expect link. Both lists grow first,
    /// so a failed allocation changes no membership.
    pub fn addExpect(self: *ElementSet, element: *runtime.Instance) error{OutOfMemory}!void {
        const member = self.contains(element);
        const expect = std.mem.indexOfScalar(*runtime.Instance, self.expect_links.items, element) != null;
        if (!member) try self.elements.ensureUnusedCapacity(self.allocator, 1);
        if (!expect) try self.expect_links.ensureUnusedCapacity(self.allocator, 1);
        if (!member) self.elements.appendAssumeCapacity(element);
        if (!expect) self.expect_links.appendAssumeCapacity(element);
    }
    pub fn hasExpectLinks(self: *const ElementSet) bool {
        return self.expect_links.items.len != 0;
    }
    pub fn remove(self: *ElementSet, element: *runtime.Instance) void {
        if (std.mem.indexOfScalar(*runtime.Instance, self.elements.items, element)) |index| {
            _ = self.elements.orderedRemove(index);
        }
        if (std.mem.indexOfScalar(*runtime.Instance, self.expect_links.items, element)) |index| {
            _ = self.expect_links.orderedRemove(index);
        }
    }
    pub fn clear(self: *ElementSet) void {
        self.elements.clearRetainingCapacity();
        self.expect_links.clearRetainingCapacity();
    }
    pub fn isBlocked(self: *const ElementSet, allows_adding: bool, now_ms: f64) bool {
        return (self.elements.items.len != 0 or allows_adding) and now_ms <= timeout_ms;
    }
};

/// HTML 2.5.8, blocking tokens set steps 1–4.
pub fn hasRenderToken(value: []const u8) bool {
    var tokens = std.mem.tokenizeAny(u8, value, " \t\n\r\x0c");
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(token, "render")) return true;
    }
    return false;
}

pub fn allowsAdding(content_type: []const u8, has_body: bool) bool {
    return std.mem.eql(u8, content_type, "text/html") and !has_body;
}

pub const Implementation = struct {
    of: *const fn (*runtime.Instance) ?*ElementSet,
    allows_adding: *const fn (*runtime.Instance) bool,
    current_time_ms: *const fn (*runtime.Instance) f64,
    /// Whether `element` is on the stack of open elements of the HTML parser
    /// whose associated Document is `document` (its active parser) - or is
    /// the element that parser is inserting, which it pushes next.
    on_parser_stack: *const fn (document: *runtime.Instance, element: *runtime.Instance) bool,
};

/// What the link element installs: HTML "process internal resource link"
/// for `link`, an element of the set's expect links. `candidate` is the
/// element whose change caused the processing (the parser popped it, it was
/// inserted, its id or name changed), or null for a full processing; a link
/// whose fragment `candidate` cannot indicate keeps its result.
pub const InternalResourceLinks = struct {
    process: *const fn (link: *runtime.Instance, candidate: ?*runtime.Instance) void,
};

// process-wide: a hook table the link element (HTMLLinkElement.installHooks) writes once while crane.Process starts (process_start.zig) and only reads after; the algorithm is the same for every Browser and thread, and all its state is the processed link's and its Document's
var internal_resource_links: Hook(?InternalResourceLinks) = .init(null);

/// Called by HTMLLinkElement's installHooks, once, at process start.
pub fn installInternalResourceLinks(links: InternalResourceLinks) void {
    internal_resource_links.install(links);
}

pub fn contains(document: *runtime.Instance, element: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    const set = impl.of(document) orelse return false;
    return set.contains(element);
}

/// Block rendering steps 1–2. Repeated requests append once.
pub fn block(element: *runtime.Instance) error{OutOfMemory}!void {
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    const impl = document_lifecycle.renderingImplementation() orelse return;
    if (!impl.allows_adding(document)) return;
    const set = impl.of(document) orelse return;
    try set.add(element);
}

/// Unblock rendering steps 1–2. Removal runs before adoption changes this
/// node document; abandoned queues additionally name their original document.
pub fn unblock(element: *runtime.Instance) void {
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    remove(document, element);
}

pub fn remove(document: *runtime.Instance, element: *runtime.Instance) void {
    const impl = document_lifecycle.renderingImplementation() orelse return;
    const set = impl.of(document) orelse return;
    set.remove(element);
}

/// HTML 3.1.6 "render-blocked": the set is non-empty, or `document` allows
/// adding render-blocking elements - here only while it is still loading -
/// and the timeout has not passed.
///
/// The spec reads "allows adding" (text/html, no body element) with no
/// regard to readiness, so a loaded document whose script removed its body
/// or its root - or replaced the root with another element - is
/// render-blocked until the timeout: no animation frames for 30 s here.
/// No browser does that: Chrome 157, Firefox 159 and Safari 27.2 pass all 28
/// WPT crashtests that wait for a frame after such a removal (wpt.fyi stable,
/// run fea36e49dd; lane crash1 b2, tmp/crash1/b2/ct-timeouts-wptfyi.txt).
/// While the document loads, a missing body does block - observably in
/// Chrome and Firefox: a parser waiting 1.5 s on a script in <head> gave no
/// animation frame before <body> in either, its first frame right after
/// (crash1 b2's probe, tmp/crash1/probe/rafbody.html; Safari's background
/// window gave no frames at all, so it does not decide).
///
/// Mechanism by mechanism: Gecko's Document::IsRenderBlocked is this one -
/// "a missing body blocks rendering only while parsing, so that a document
/// renders when script removes the body or the root element":
/// `!mRenderBlockingElementSet.IsEmpty() ||
/// (AllowsAddingRenderBlockingElements() && mReadyState ==
/// READYSTATE_LOADING)`. Blink blocks on the set alone
/// (RenderBlockingResourceManager; `body()` only stops resources joining)
/// but makes no frames for an HTML document until Document::WillInsertBody
/// or Document::FinishedParsing calls BeginLifecycleUpdatesIfRenderingReady
/// - observably the same: none before the body while parsing, frames after
/// parsing whatever the body. WebKit blocks on the set alone
/// (Document::blockRenderingOn); its ReadyState visual-update reason applies
/// only with suppressesIncrementalRendering. So no rendering before the body
/// while loading is the majority (Chrome, Firefox) and rendering after it
/// all three's: golden rule 2, no newer spec involved - this condition.
/// html/dom/render-blocking/ (62 worklist files, wpt.fyi): Chrome passes
/// all, Safari all but two optional ones, Firefox 159 none of 21 and part of
/// 7 (Gecko main has `dom.element.blocking.enabled` on); the one that
/// replaces the root, render-blocking-during-update-the-rendering-crash, is
/// a crashtest that waits for a frame: PASS in all three.
/// Adding to the set still follows "allows adding" alone (`block`).
pub fn isBlocked(document: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    const set = impl.of(document) orelse return false;
    const loading = (interfaces.Document.get_readyState(document) catch ._loading_) == ._loading_;
    return set.isBlocked(loading and impl.allows_adding(document), impl.current_time_ms(document));
}

pub fn isRenderBlocking(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch return false) orelse return false;
    return contains(document, element) and isBlocked(document);
}

/// Block rendering steps 1-2 for an expect link: `element` joins the set,
/// and its expect links, while its node document allows adding.
pub fn blockExpectLink(element: *runtime.Instance) error{OutOfMemory}!void {
    const document = (interfaces.Node.get_ownerDocument(element) catch return) orelse return;
    const impl = document_lifecycle.renderingImplementation() orelse return;
    if (!impl.allows_adding(document)) return;
    const set = impl.of(document) orelse return;
    try set.addExpect(element);
}

/// Whether `element` is one of `document`'s render-blocking expect links.
pub fn isExpectLink(document: *runtime.Instance, element: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    const set = impl.of(document) orelse return false;
    return std.mem.indexOfScalar(*runtime.Instance, set.expect_links.items, element) != null;
}

/// Whether any expect link blocks `document`'s rendering: what every
/// trigger of "process internal resource links" asks first.
pub fn hasExpectLinks(document: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    const set = impl.of(document) orelse return false;
    return set.hasExpectLinks();
}

/// "Is on a stack of open elements of an HTML parser whose associated
/// Document is `document`" (Document's active parser answers).
pub fn onParserStack(document: *runtime.Instance, element: *runtime.Instance) bool {
    const impl = document_lifecycle.renderingImplementation() orelse return false;
    return impl.on_parser_stack(document, element);
}

/// HTML "process internal resource links" given `document`: "For each
/// expect link element link in doc's render-blocking element set, process
/// link". Processing changes the set, so it runs over a snapshot, skipping
/// links an earlier one's processing took out.
///
/// `candidate` is the element whose change caused this (null: none). An
/// element with no ID that is not an `a` element with a name can be no
/// link's indicated element, so its pop, insertion or attribute change
/// changes no link's result and processes nothing - WebKit's
/// Element::finishParsingChildren path hands the element to each link
/// (HTMLLinkElement::processInternalResourceLink), Blink keys its pending
/// links by ID (RenderBlockingResourceManager::RemovePendingParsingElement).
pub fn processInternalResourceLinks(document: *runtime.Instance, candidate: ?*runtime.Instance) void {
    const links = internal_resource_links.get() orelse return;
    const impl = document_lifecycle.renderingImplementation() orelse return;
    const set = impl.of(document) orelse return;
    if (!set.hasExpectLinks()) return;
    if (candidate) |element| if (!canBeIndicated(element)) return;
    var inline_buffer: [8]*runtime.Instance = undefined;
    const count = set.expect_links.items.len;
    const snapshot: []*runtime.Instance = if (count <= inline_buffer.len)
        inline_buffer[0..count]
    else
        set.allocator.alloc(*runtime.Instance, count) catch return;
    defer if (count > inline_buffer.len) set.allocator.free(snapshot);
    @memcpy(snapshot, set.expect_links.items);
    for (snapshot) |link| {
        // An earlier link's processing can run no script, but re-read the
        // set: a processed link may leave it, and only members are visited.
        const current = impl.of(document) orelse return;
        if (std.mem.indexOfScalar(*runtime.Instance, current.expect_links.items, link) == null) continue;
        links.process(link, candidate);
    }
}

/// Whether `element` is connected and has an ID, or is an HTML `a` element
/// with a name attribute: the elements "find a potential indicated element"
/// returns.
pub fn canBeIndicated(element: *runtime.Instance) bool {
    // Only an element in the document tree is indicated.
    if (!(interfaces.Node.get_isConnected(element) catch false)) return false;
    const data = element_data.of(element) orelse return false;
    if (data.idValue().len != 0) return true;
    if (!std.mem.eql(u8, data.localName(), "a")) return false;
    const namespace = data.namespaceSlice() orelse return false;
    if (!std.mem.eql(u8, namespace, "http://www.w3.org/1999/xhtml")) return false;
    return data.findAttribute(null, "name") != null;
}

//! What an object or embed element represents, and how it comes to: HTML
//! 4.8.7 "(re)determine what the object element represents" and 4.8.6 "the
//! embed element setup steps".
//!
//! Shared by the two elements - their impls may not call each other - the
//! shape of `style_sheet_loading.zig`. Each element's impl holds a `Content`
//! for its life and calls in here: when the parser creates it and pops it
//! (dom.finish_parsing_children), when it is inserted or removed, when an
//! attribute it reads changes, and for contentWindow and contentDocument.
//!
//! The processing runs as element tasks on the element's event loop: the
//! object's (re)determination (a DOM manipulation task) or the embed's setup
//! steps (an embed task), the fetch of the data or src URL (destination and
//! initiator type "object" or "embed"), and the networking task that
//! continues with the response: an error event and the fallback content for
//! a failed load; a child navigable navigated to the response's URL for a
//! document (dom.navigables - the iframe's steps); the image for an image
//! type, which fires load; the fallback content for anything else. A
//! navigable's load event fires at the element when its document has
//! completely loaded (dom.navigables.containerLoadEventSteps).
//!
//! While a task is queued or running, or the fetch is in flight, the element
//! delays its node document's load event (dom.document_lifecycle
//! .delayLoadEvent) and has pending activity (engine.keepPlatformObjectAlive):
//! a script-made object nobody holds still fires its events. Both end with
//! the last of them, on every path - done, superseded by a newer
//! processing, the element removed or gone, its document destroyed (the
//! fetch is not `alive` any more, and its task fires nothing).
//!
//! Deviations, stated:
//! - Crane has no plugins. An embed element's "type of the content" takes
//!   the object element's resource type rules (navigation/object_resource_type.zig):
//!   a document type is shown in a child navigable, an image in one as a
//!   media document, anything else is "no plugin" - as Blink, Gecko and
//!   WebKit show documents and images in an embed (Blink's
//!   HTMLPlugInElement::GetObjectContentType gives kFrame for a supported
//!   non-image type, kImage for an image).
//! - The object element's step 2 "is not being rendered": Crane has no
//!   layout, so every connected element counts as rendered (WPT's
//!   indexed-browsing-contexts files put their objects in a display:none
//!   div and still count their navigables, as browsers do).
//! - An ancestor object element is "not showing its fallback content" when
//!   it has a content navigable; an ancestor object showing an image counts
//!   as showing its fallback content.
//! - An image is not decoded: a response with an image type that loaded is
//!   an image that "can be rendered".
//! - Removing the element destroys its child navigable at once, as Blink
//!   does (HTMLFrameOwnerElement::DisconnectContentFrame from RemovedFrom),
//!   and ends its fetch; the spec queues the (re)determination, which would
//!   destroy it from a task.
//! - The navigation fetches the response's URL again (the object element's
//!   "navigate ... to response's URL"; the embed element's would pass the
//!   response, which Crane's navigate cannot take).
//! - The initial about:blank document a navigable for about:blank keeps
//!   fires the element's load event from a task: the document was
//!   completely loaded as it was made ("completely finish loading" step 5).
//!
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-object-element
//! Spec: https://html.spec.whatwg.org/multipage/iframe-embed-object.html#the-embed-element

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const fetch = @import("fetch");
const dom = @import("dom");
const html_core = @import("html_core");
const encoding_parse = @import("encoding_parse.zig");
const csp = @import("csp");
const css = @import("css");

const object_resource_type = html_core.navigation.object_resource_type;
const navigate_steps = html_core.navigation.navigate_steps;
const IFrameIntegration = html_core.IFrameIntegration;
const AsyncFetch = fetch.algorithms.AsyncFetch;

const log = std.log.scoped(.embedded_content);

/// Which element.
pub const Kind = enum { object, embed };

/// What the element represents.
pub const Represents = enum {
    /// Nothing yet, or (embed) no plugin.
    nothing,
    /// (object) its children: its fallback content.
    fallback,
    /// The image its resource is.
    image,
    /// Its content navigable.
    navigable,
};

/// One object or embed element's processing. Made by the element's impl
/// (`create`) and handed back when the element goes (`elementGone`).
/// Counted: the element holds one reference, and every queued task and the
/// fetch in flight one each, so whatever outlives the element finds
/// `element_gone` and does nothing.
pub const Content = struct {
    allocator: std.mem.Allocator,
    kind: Kind,
    element: *runtime.Instance,
    element_generation: u64,
    references: u32 = 1,
    element_gone: bool = false,
    /// The element's content navigable (an html_core IFrameIntegration from
    /// the runtime arena, as every container's is), made the first time one
    /// is needed and released with the element.
    integration: ?*IFrameIntegration = null,
    /// (object) The HTML parser created the element and has not popped it:
    /// "the element is still in the stack of open elements of an HTML parser".
    parser_open: bool = false,
    represents: Represents = .nothing,
    /// The current processing: every (re)queue takes the next number, and a
    /// task or fetch of an older one is superseded ("if another task has
    /// since been queued").
    current: u64 = 0,
    /// The fetch in flight, for `current`.
    fetch: ?*Fetch = null,
    /// How many tasks and fetches are pending. While any is, the element
    /// delays `delayed_document`'s load event and is kept alive.
    pending: u32 = 0,
    delayed_document: ?*runtime.Instance = null,
    delayed_document_generation: u64 = 0,
    kept_alive: bool = false,

    fn ref(self: *Content) void {
        self.references += 1;
    }

    fn unref(self: *Content) void {
        self.references -= 1;
        if (self.references == 0) runtime.ArenaAllocator.get().destroy(Content, self);
    }

    fn elementIsLive(self: *const Content) bool {
        return !self.element_gone and runtime.SlabAllocator.generationOf(self.element) == self.element_generation;
    }
};

/// A new record for `element`, an object or embed element just made. From
/// the runtime arena, as the iframe's state is: an element torn down with
/// its page may never run its deinit, and the arena goes with the page.
pub fn create(allocator: std.mem.Allocator, element: *runtime.Instance, kind: Kind) error{OutOfMemory}!*Content {
    const content = try runtime.ArenaAllocator.get().create(Content);
    content.* = .{
        .allocator = allocator,
        .kind = kind,
        .element = element,
        .element_generation = runtime.SlabAllocator.generationOf(element),
    };
    return content;
}

/// The element is being deinited: its processing ends - fetch terminated,
/// delay ended, navigable released - and the record goes once nothing else
/// holds it.
pub fn elementGone(content: *Content) void {
    content.element_gone = true;
    content.current += 1;
    terminateFetch(content);
    // The element is going: nothing to keep alive, and its document - if
    // it is still there - is not waiting for it any more.
    content.kept_alive = false;
    if (content.pending > 0) {
        content.pending = 0;
        endDelay(content);
    }
    if (content.integration) |integration| {
        content.integration = null;
        dom.navigables.releaseContentNavigable(integration);
    }
    content.unref();
}

/// (object) The HTML parser created the element (dom.finish_parsing_children).
pub fn createdByParser(content: *Content) void {
    content.parser_open = true;
}

/// (object) The HTML parser popped the element off its stack of open
/// elements: (re)determine what it represents.
pub fn finishedParsingChildren(content: *Content) void {
    if (!content.parser_open) return;
    content.parser_open = false;
    queueProcessing(content);
}

/// The element's post-connection steps: it is in a document now.
pub fn inserted(content: *Content) void {
    if (content.parser_open) return;
    switch (content.kind) {
        .object => queueProcessing(content),
        // "Whenever an embed element that was not potentially active becomes
        // potentially active": with src or type set.
        .embed => if (hasAttribute(content.element, "src") or hasAttribute(content.element, "type")) queueProcessing(content),
    }
}

/// The element's removing steps: it left its document. Its fetch ends and
/// its child navigable is destroyed now (stated deviation: the spec's
/// queued (re)determination would destroy it).
pub fn removed(content: *Content) void {
    content.current += 1;
    terminateFetch(content);
    destroyNavigable(content);
    content.represents = if (content.kind == .object) .fallback else .nothing;
}

/// The element's attribute change steps for `local_name` (no namespace).
pub fn attributeChanged(content: *Content, local_name: []const u8) void {
    if (content.parser_open) return;
    if (!isConnected(content.element)) return;
    switch (content.kind) {
        // "the element's classid attribute is not present, and its data
        // attribute is set, changed, or removed"; "neither ... classid nor
        // data ... are present, and its type attribute is set, changed, or
        // removed" (classid is obsolete and never read here).
        .object => {
            if (std.mem.eql(u8, local_name, "data")) return queueProcessing(content);
            if (std.mem.eql(u8, local_name, "type") and !hasAttribute(content.element, "data")) return queueProcessing(content);
        },
        // "a potentially active embed element that is remaining potentially
        // active has its src attribute set, changed, or removed or its type
        // attribute set, changed, or removed". One that stops being
        // potentially active - neither left - represents nothing.
        .embed => if (std.mem.eql(u8, local_name, "src") or std.mem.eql(u8, local_name, "type")) {
            if (hasAttribute(content.element, "src") or hasAttribute(content.element, "type")) {
                queueProcessing(content);
            } else {
                content.current += 1;
                terminateFetch(content);
                displayNoPlugin(content);
            }
        },
    }
}

/// HTML "content window": the element's content navigable's WindowProxy.
pub fn contentWindow(content: *Content) ?*runtime.Instance {
    const integration = content.integration orelse return null;
    if (integration.browsing_context == null) return null;
    return dom.navigables.contentWindow(integration);
}

/// HTML "content document": its content navigable's active document, if
/// same origin-domain with the element's node document.
pub fn contentDocument(content: *Content) ?*runtime.Instance {
    const integration = content.integration orelse return null;
    if (integration.browsing_context == null) return null;
    return dom.navigables.contentDocument(integration, integration.container_origin);
}

/// getSVGDocument(): "1. Let document be this's content document. 2. If
/// document is non-null and was created by the page load processing model
/// for XML files section because the computed type of the resource in the
/// navigate algorithm was image/svg+xml, then return document. 3. Return
/// null."
pub fn svgDocument(content: *Content) ?*runtime.Instance {
    const document = contentDocument(content) orelse return null;
    var content_type = interfaces.Document.get_contentType(document) catch return null;
    defer content_type.deinit(document.ctx.allocator);
    return if (std.mem.eql(u8, content_type.asSlice(), "image/svg+xml")) document else null;
}

// ============================================================================
// Tasks
// ============================================================================

const Step = enum {
    /// (object) "(re)determine what the object element represents"; (embed)
    /// "the embed element setup steps".
    process,
    /// The networking task: the fetch's response, for `process`'s id.
    response,
    /// Fire load / error at the element.
    fire_load,
    fire_error,
};

/// What the response task reads of the fetch's response.
const ResponseSummary = struct {
    network_error: bool,
    ok: bool,
    /// The Content-Type metadata (an essence), or null. Owned.
    content_type: ?[]u8 = null,
    /// The body's first bytes, for mimesniff. Owned.
    head: []u8 = &.{},
    /// The response's URL, after redirects. Owned.
    url: []u8 = &.{},

    fn deinit(self: *ResponseSummary, allocator: std.mem.Allocator) void {
        if (self.content_type) |t| allocator.free(t);
        allocator.free(self.head);
        allocator.free(self.url);
    }
};

const Task = struct {
    content: *Content,
    step: Step,
    /// The processing this task belongs to.
    id: u64,
    response: ?ResponseSummary = null,

    fn destroy(self: *Task) void {
        const content = self.content;
        if (self.response) |*r| r.deinit(content.allocator);
        content.allocator.destroy(self);
        endPending(content);
        content.unref();
    }
};

/// Queue `step` for processing `id` as an element task of the element's
/// event loop - pending, so delaying the load event and keeping the element.
fn queueTask(content: *Content, step: Step, id: u64, response: ?ResponseSummary) void {
    var summary = response;
    const loop = content.element.ctx.getOptionalEventLoop() orelse {
        if (summary) |*r| r.deinit(content.allocator);
        return;
    };
    const task = content.allocator.create(Task) catch {
        if (summary) |*r| r.deinit(content.allocator);
        return;
    };
    task.* = .{ .content = content, .step = step, .id = id, .response = summary };
    content.ref();
    beginPending(content);
    loop.queueTask(.{ .callback = &runTask, .context = task, .drop = &dropTask });
}

/// Queue the element's processing: a newer one supersedes whatever is
/// queued or fetching.
fn queueProcessing(content: *Content) void {
    content.current += 1;
    terminateFetch(content);
    queueTask(content, .process, content.current, null);
}

fn dropTask(data: ?*anyopaque) void {
    const task: *Task = @ptrCast(@alignCast(data orelse return));
    task.destroy();
}

fn runTask(data: ?*anyopaque) void {
    const task: *Task = @ptrCast(@alignCast(data orelse return));
    defer task.destroy();
    const content = task.content;
    if (!content.elementIsLive()) return;
    // A realm retired by a navigation runs none of its tasks, and the task
    // of a document that is no longer fully active does not run.
    if (content.element.ctx.engine_ctx == null) return;
    if (!documentIsFullyActive(content.element)) return;
    engine.runTaskInRealm(content.element.ctx, taskSteps, task) catch |err| {
        log.debug("{s} task not run: {}", .{ @tagName(content.kind), err });
    };
}

fn taskSteps(data: ?*anyopaque) void {
    const task: *Task = @ptrCast(@alignCast(data.?));
    const content = task.content;
    switch (task.step) {
        .fire_load => dom.navigables.fireSimpleEvent(content.element, "load"),
        .fire_error => dom.navigables.fireSimpleEvent(content.element, "error"),
        .process => {
            if (task.id != content.current) return;
            switch (content.kind) {
                .object => processObject(content, task.id),
                .embed => setupEmbed(content, task.id),
            }
        },
        .response => {
            if (task.id != content.current) return;
            if (task.response) |*response| switch (content.kind) {
                .object => objectResponse(content, response),
                .embed => embedResponse(content, response),
            };
        },
    }
}

// ============================================================================
// The object element (4.8.7)
// ============================================================================

/// "(Re)determine what the object element represents", steps 1-6.
fn processObject(content: *Content, id: u64) void {
    const element = content.element;
    // Step 1: no preference for the fallback content. Step 2: "If the
    // element has an ancestor media element, or has an ancestor object
    // element that is not showing its fallback content, or if the element is
    // not in a document whose browsing context is non-null, or if the
    // element's node document is not fully active, or if the element is
    // still in the stack of open elements of an HTML parser or XML parser,
    // or if the element is not being rendered, then jump to the step below
    // labeled fallback."
    if (content.parser_open or !isConnected(element) or !documentHasBrowsingContext(element) or hasInactiveAncestor(element) or !isBeingRendered(element)) {
        return fallback(content);
    }
    // Step 3: "If the data attribute is present and its value is not the
    // empty string".
    const data = attributeValue(element, "data") orelse "";
    if (data.len == 0) {
        // No URL: a type alone would load a plugin, which CSP's object-src
        // 'none' blocks and reports (CSP 6.1.9). Crane has no plugins, so
        // either way the element shows its fallback content.
        pluginWithoutUrlCheck(element);
        return fallback(content);
    }
    // 3.1: the user agent fetches whatever the type attribute says.
    // 3.2-3.3: "Let url be the result of encoding-parsing a URL given the
    // data attribute's value, relative to the element's node document. If
    // url is failure, then fire an event named error at the element and jump
    // to the step below labeled fallback."
    const url = (encoding_parse.encodingParseAndSerialize(element, data) catch null) orelse {
        dom.navigables.fireSimpleEvent(element, "error");
        return fallback(content);
    };
    defer element.ctx.allocator.free(url);
    // 3.4-3.5: the request, fetched.
    startFetch(content, id, url) catch |err| {
        log.debug("object fetch of {s} not started: {}", .{ url, err });
        dom.navigables.fireSimpleEvent(element, "error");
        return fallback(content);
    };
    // 3.6: "If the resource is not yet available ... jump to the step below
    // labeled fallback. The task that is queued by the networking task
    // source once the resource is available must restart this algorithm
    // from this step."
    fallback(content);
}

/// Steps 7-11, in the networking task the fetch's response queued.
fn objectResponse(content: *Content, response: *const ResponseSummary) void {
    const element = content.element;
    // Step 7: "If the load failed (e.g. there was an HTTP 404 error, there
    // was a DNS error), fire an event named error at the element, then jump
    // to the step below labeled fallback."
    if (response.network_error or !response.ok) {
        dom.navigables.fireSimpleEvent(element, "error");
        return fallback(content);
    }
    // Step 8: the resource type.
    const type_attribute = attributeValue(element, "type");
    const resource_type = object_resource_type.resourceType(content.allocator, .{
        .content_type = response.content_type,
        .type_attribute = type_attribute,
        .body = response.head,
    }) catch null;
    defer if (resource_type) |t| content.allocator.free(t);
    // Step 9: the handler.
    switch (object_resource_type.handlerFor(resource_type)) {
        .navigable => showNavigable(content, response.url, true),
        .image => {
            // "Destroy a child navigable given the object element. Apply the
            // image sniffing rules to determine the type of the image. The
            // object element represents the specified image."
            destroyNavigable(content);
            content.represents = .image;
            // Step 11: "If the object element does not represent its content
            // navigable, then once the resource is completely loaded, queue
            // an element task on the DOM manipulation task source given the
            // object element to fire an event named load at the element."
            queueTask(content, .fire_load, content.current, null);
        },
        .fallback => fallback(content),
    }
}

/// Step 4, "Fallback": "The object element represents the element's
/// children. This is the element's fallback content. Destroy a child
/// navigable given the element."
fn fallback(content: *Content) void {
    content.represents = .fallback;
    destroyNavigable(content);
}

// ============================================================================
// The embed element (4.8.6)
// ============================================================================

/// "The embed element setup steps", steps 2-3.
fn setupEmbed(content: *Content, id: u64) void {
    const element = content.element;
    // "Potentially active": in a document that is fully active, with no
    // ancestor media element or object element not showing its fallback.
    if (!isConnected(element) or !documentHasBrowsingContext(element) or hasInactiveAncestor(element) or !isBeingRendered(element)) return displayNoPlugin(content);
    // Step 2: "If element has a src attribute set".
    const src = attributeValue(element, "src") orelse {
        // Step 3, with a type alone: CSP 6.1.9 first, then no plugin.
        pluginWithoutUrlCheck(element);
        return displayNoPlugin(content);
    };
    // 2.1-2.2: "Let url be the result of encoding-parsing a URL given
    // element's src attribute's value, relative to element's node document.
    // If url is failure, then return."
    const url = (encoding_parse.encodingParseAndSerialize(element, src) catch null) orelse return;
    defer element.ctx.allocator.free(url);
    // 2.3-2.4: the request, fetched.
    startFetch(content, id, url) catch |err| {
        log.debug("embed fetch of {s} not started: {}", .{ url, err });
    };
}

/// Step 2.4's processResponse.
fn embedResponse(content: *Content, response: *const ResponseSummary) void {
    // 2: "If response is a network error, then fire an event named load at
    // element, and return."
    if (response.network_error) return dom.navigables.fireSimpleEvent(content.element, "load");
    // 3: "Let type be the result of determining the type of content given
    // element and response" - the object element's rules (stated).
    const type_attribute = attributeValue(content.element, "type");
    const resource_type = object_resource_type.resourceType(content.allocator, .{
        .content_type = response.content_type,
        .type_attribute = type_attribute,
        .body = response.head,
    }) catch null;
    defer if (resource_type) |t| content.allocator.free(t);
    // 4: "null: display no plugin"; otherwise the child navigable,
    // navigated to the response's URL. (An image is shown in it as a media
    // document.)
    if (object_resource_type.handlerFor(resource_type) == .fallback) return displayNoPlugin(content);
    showNavigable(content, response.url, false);
}

/// HTML "display no plugin": "Destroy a child navigable given element.
/// ... element now represents nothing."
fn displayNoPlugin(content: *Content) void {
    destroyNavigable(content);
    content.represents = .nothing;
}

/// CSP 6.1.9: "If plugin content is loaded without an associated URL
/// (perhaps an object element lacks a data attribute, but loads some default
/// plugin based on the specified type), it MUST be blocked if object-src's
/// value is 'none'" - and reported (csp.plugin_check). An element whose type
/// attribute names a type is one that would load such content; Crane loads
/// none either way (no plugins), so only the violation is observable.
fn pluginWithoutUrlCheck(element: *runtime.Instance) void {
    const type_attribute = attributeValue(element, "type") orelse return;
    if (std.mem.trim(u8, type_attribute, " \t\n\r\x0c").len == 0) return;
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    const container = dom.policy_containers.of(document) orelse return;
    if (container.csp_list.policies.items.len == 0) return;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    _ = csp.plugin_check.shouldPluginContentWithoutUrlBeBlocked(&container.csp_list, dom.csp_violations.reporterFor(window), element);
}

// ============================================================================
// The child navigable
// ============================================================================

/// The navigable case of both elements: "If element's content navigable is
/// null, then create a new child navigable for element", then navigate it
/// to `url` using the element's node document, with historyHandling
/// "replace". An object does not navigate to a URL that matches
/// about:blank (its navigable keeps the initial about:blank document, whose
/// load event fires from a task, stated); an embed always navigates.
fn showNavigable(content: *Content, url: []const u8, about_blank_stays: bool) void {
    const element = content.element;
    if (!ensureNavigable(content)) {
        log.debug("{s}: no child navigable for {s}", .{ @tagName(content.kind), url });
        return fallback(content);
    }
    content.represents = .navigable;
    const integration = content.integration.?;
    if (about_blank_stays and navigate_steps.matchesAboutBlank(url)) {
        queueTask(content, .fire_load, content.current, null);
        return;
    }
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return;
    integration.navigate(url, .{ .history_behavior = .replace, .source_document = @ptrCast(document) });
}

/// The element's content navigable, made now if it has none: HTML "create a
/// new child navigable" (dom.navigables), its target name the element's
/// name attribute "if present when the element's content navigable is
/// created".
fn ensureNavigable(content: *Content) bool {
    const element = content.element;
    const integration = content.integration orelse blk: {
        // From the runtime arena, as every container's content navigable
        // is: dom.navigables.releaseContentNavigable returns it there.
        const made = runtime.ArenaAllocator.get().create(IFrameIntegration) catch return false;
        made.* = IFrameIntegration.init(content.allocator);
        content.integration = made;
        break :blk made;
    };
    if (integration.state != .discarded and integration.hasRealmContext() and integration.browsing_context != null) return true;
    // A navigable destroyed earlier: its realm is retired, and a new one made.
    if (integration.state == .discarded or integration.hasRealmContext()) {
        integration.retireRealmContext() catch return false;
    }
    if (!dom.navigables.createChildNavigable(element, integration)) return false;
    if (attributeValue(element, "name")) |name| {
        if (name.len > 0) {
            integration.setName(name) catch {};
            dom.navigables.registerNamedProperty(integration, name);
        }
    }
    return true;
}

/// HTML "destroy a child navigable" given the element, if it has one.
fn destroyNavigable(content: *Content) void {
    const integration = content.integration orelse return;
    if (integration.state == .discarded or integration.browsing_context == null) return;
    dom.navigables.destroyChildNavigable(content.element, integration);
}

// ============================================================================
// The fetch
// ============================================================================

/// One fetch of the element's data (object) or src (embed) URL.
const Fetch = struct {
    content: *Content,
    id: u64,
    /// The fetch, until it answers or is terminated.
    async_fetch: ?*AsyncFetch = null,

    fn client(self: *Fetch) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone };
    }

    /// Whether the fetch is still wanted: the element is there, its realm
    /// runs, its document is fully active, and no newer processing has
    /// superseded this one.
    fn alive(context: *anyopaque) bool {
        const self: *Fetch = @ptrCast(@alignCast(context));
        const content = self.content;
        if (!content.elementIsLive() or self.id != content.current) return false;
        if (content.element.ctx.engine_ctx == null) return false;
        return documentIsFullyActive(content.element);
    }

    /// The fetch was terminated: nothing more comes of it.
    fn gone(context: *anyopaque) void {
        const self: *Fetch = @ptrCast(@alignCast(context));
        self.async_fetch = null;
        finish(self);
    }

    /// The response, body and all: the networking task continues.
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Fetch = @ptrCast(@alignCast(context));
        self.async_fetch = null;
        defer finish(self);
        const content = self.content;
        var result = outcome catch null;
        defer if (result) |*r| r.deinit();
        if (!content.elementIsLive() or self.id != content.current) return;
        var summary = summarize(content.allocator, if (result) |*r| r else null) catch return;
        queueTask(content, .response, self.id, summary);
        summary = undefined;
    }

    fn finish(self: *Fetch) void {
        const content = self.content;
        if (content.fetch == self) content.fetch = null;
        content.allocator.destroy(self);
        endPending(content);
        content.unref();
    }
};

/// The request: "a new request whose URL is url, client is the element's
/// node document's relevant settings object, destination is "object"
/// ("embed"), credentials mode is "include", mode is "navigate", initiator
/// type is "object" ("embed"), and whose use-URL-credentials flag is set" -
/// fetched in parallel.
fn startFetch(content: *Content, id: u64, url: []const u8) !void {
    const element = content.element;
    const allocator = content.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, url);
    var request_owned = true;
    defer if (request_owned) request.deinit();
    request.destination = if (content.kind == .object) .object else .embed;
    request.initiator_type = if (content.kind == .object) .object else .embed;
    request.mode = .navigate;
    request.credentials_mode = .include;
    request.use_url_credentials = true;
    // The client: the element's node document's relevant settings object -
    // its realm's global's - whose CSP list checks the request (object-src)
    // and whose timeline gets its resource timing entry.
    if (globalOf(element.ctx)) |global| {
        var client = try dom.global_settings.requestClient(global);
        defer client.deinit();
        try fetch.internal.populateRequestFromClient(request, client.request);
    }

    const record = try allocator.create(Fetch);
    record.* = .{ .content = content, .id = id };
    content.ref();
    beginPending(content);
    content.fetch = record;
    // The fetch owns the request from here, even when it fails to start.
    request_owned = false;
    record.async_fetch = AsyncFetch.start(allocator, request, .{}, fetch.network.scheduler.threadScheduler(), record.client()) catch |err| {
        content.fetch = null;
        allocator.destroy(record);
        endPending(content);
        content.unref();
        return err;
    };
}

/// End the fetch in flight, if any: it is terminated, and its client hears
/// nothing more.
fn terminateFetch(content: *Content) void {
    const record = content.fetch orelse return;
    content.fetch = null;
    if (record.async_fetch) |f| {
        record.async_fetch = null;
        // Terminating a fetch runs neither `done` nor `gone`.
        f.terminate();
    }
    content.allocator.destroy(record);
    endPending(content);
    content.unref();
}

/// What the response task needs of a fetch's result: null is a network
/// error.
fn summarize(allocator: std.mem.Allocator, result: ?*fetch.algorithms.FetchResult) !ResponseSummary {
    const r = result orelse return .{ .network_error = true, .ok = false };
    const response = r.response;
    if (response.response_type == .@"error") return .{ .network_error = true, .ok = false };
    var summary: ResponseSummary = .{ .network_error = false, .ok = fetch.internal.isOkStatus(response.status) };
    errdefer summary.deinit(allocator);
    summary.content_type = fetch.internal.mime.extractMimeEssence(allocator, &response.header_list) catch null;
    const body: []const u8 = if (response.body) |b| b.getBytes() else "";
    summary.head = try allocator.dupe(u8, body[0..@min(body.len, 1445)]);
    summary.url = try allocator.dupe(u8, response.url() orelse "");
    return summary;
}

// ============================================================================
// Pending activity and the load event delay
// ============================================================================

/// One more task or fetch pending. The first delays the element's node
/// document's load event and keeps the element alive.
fn beginPending(content: *Content) void {
    content.pending += 1;
    if (content.pending > 1) return;
    if (interfaces.Node.get_ownerDocument(content.element) catch null) |document| {
        content.delayed_document = document;
        content.delayed_document_generation = runtime.SlabAllocator.generationOf(document);
        dom.document_lifecycle.delayLoadEvent(document);
    }
    if (content.element.ctx.engine_ctx != null) {
        engine.keepPlatformObjectAlive(content.element);
        content.kept_alive = true;
    }
}

/// One task or fetch ended. With the last, the delay and the hold end.
fn endPending(content: *Content) void {
    if (content.pending == 0) return;
    content.pending -= 1;
    if (content.pending > 0) return;
    if (content.kept_alive and content.elementIsLive()) engine.releasePlatformObject(content.element);
    content.kept_alive = false;
    endDelay(content);
}

fn endDelay(content: *Content) void {
    const document = content.delayed_document orelse return;
    content.delayed_document = null;
    if (runtime.SlabAllocator.generationOf(document) != content.delayed_document_generation) return;
    dom.document_lifecycle.undelayLoadEvent(document);
}

// ============================================================================
// Helpers
// ============================================================================

fn attributeValue(element: *runtime.Instance, name: []const u8) ?[]const u8 {
    const value = (interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(name)) catch return null) orelse return null;
    return value.asSlice();
}

fn hasAttribute(element: *runtime.Instance, name: []const u8) bool {
    return interfaces.Element.call_hasAttribute(element, runtime.DOMString.initInterned(name)) catch false;
}

fn isConnected(element: *runtime.Instance) bool {
    return interfaces.Node.get_isConnected(element) catch false;
}

/// "In a document whose browsing context is non-null": the element's node
/// document has a window.
fn documentHasBrowsingContext(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    return (interfaces.Document.get_defaultView(document) catch null) != null;
}

/// Whether the element's node document is fully active: the active document
/// of its window's navigable. Asked of the browsing context, not of the
/// Window's `document` getter, which is script's and refuses an accessor of
/// another origin - this runs from the event loop and the network sweep,
/// where whatever realm is current is no accessor (an object in a data:
/// frame, of an opaque origin, never processed).
fn documentIsFullyActive(element: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(element) catch null) orelse return false;
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return false;
    const navigable = html_core.BrowsingContext.ofWindow(@ptrCast(window)) orelse return false;
    return navigable.getActiveDocument() == @as(*anyopaque, @ptrCast(document));
}

/// Whether the element has an ancestor media element, or an ancestor object
/// element that is not showing its fallback content (one with a content
/// navigable, stated).
fn hasInactiveAncestor(element: *runtime.Instance) bool {
    var node = interfaces.Node.get_parentNode(element) catch return false;
    var depth: usize = 0;
    while (node) |current| : (depth += 1) {
        if (depth > 512) return false;
        if (current.stateAs(interfaces.HTMLMediaElement.State) != null) return true;
        if (current.stateAs(interfaces.HTMLObjectElement.State) != null and showsNavigable(current)) return true;
        node = interfaces.Node.get_parentNode(current) catch return false;
    }
    return false;
}

/// HTML "being rendered", as far as Crane can tell without a style cascade:
/// the element and its ancestors are not hidden by the UA style sheet's
/// rules Crane can apply - a `head` ancestor, a `hidden` attribute (but
/// hidden=until-found, which keeps its box) - nor by an inline style
/// attribute whose display is `none`. An author style sheet's
/// `display: none` is not seen (stated: no cascade). Blink loads no plugin
/// and no frame for an object or embed without a layout box.
fn isBeingRendered(element: *runtime.Instance) bool {
    var node: ?*runtime.Instance = element;
    var depth: usize = 0;
    while (node) |current| : (depth += 1) {
        if (depth > 512) return true;
        if (current.stateAs(interfaces.Element.State) != null) {
            if (current.stateAs(interfaces.HTMLHeadElement.State) != null) return false;
            if (attributeValue(current, "hidden")) |hidden| {
                if (!std.ascii.eqlIgnoreCase(hidden, "until-found")) return false;
            }
            if (attributeValue(current, "style")) |style| {
                if (inlineDisplayIsNone(style)) return false;
            }
        }
        node = interfaces.Node.get_parentNode(current) catch return true;
    }
    return true;
}

/// Whether the declarations of an inline style attribute `style` make
/// `display` `none` - the last `display` declaration, an `!important` one
/// over any that is not (CSS Cascade's order within one declaration block).
fn inlineDisplayIsNone(style: []const u8) bool {
    if (std.ascii.indexOfIgnoreCase(style, "display") == null) return false;
    const allocator = std.heap.page_allocator;
    const text = std.mem.concat(allocator, u8, &.{ "x{", style, "}" }) catch return false;
    defer allocator.free(text);
    var parsed = css.rules.parseStyleSheetContents(allocator, text) catch return false;
    defer parsed.deinit();
    var value: ?[]const u8 = null;
    var important = false;
    for (parsed.items) |rule| {
        for (rule.declarations) |declaration| {
            if (!std.mem.eql(u8, declaration.name, "display")) continue;
            if (important and !declaration.important) continue;
            value = declaration.value;
            important = declaration.important;
        }
    }
    const v = value orelse return false;
    return std.ascii.eqlIgnoreCase(std.mem.trim(u8, v, " \t\n\r\x0c"), "none");
}

/// Whether `object` has a content navigable: one of its node document's
/// child navigables has it as its container.
fn showsNavigable(object: *runtime.Instance) bool {
    const document = (interfaces.Node.get_ownerDocument(object) catch null) orelse return false;
    var children = dom.navigables.childNavigablesOf(document, std.heap.page_allocator);
    defer children.deinit(std.heap.page_allocator);
    for (children.items) |child| {
        if (child.container == object) return true;
    }
    return false;
}

fn globalOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

test "an inline style's display is none: the last declaration, an important one over the rest" {
    const testing = std.testing;
    try testing.expect(inlineDisplayIsNone("display: none"));
    try testing.expect(inlineDisplayIsNone("color: red; DISPLAY:NONE;"));
    try testing.expect(!inlineDisplayIsNone("display: none; display: block"));
    try testing.expect(inlineDisplayIsNone("display: none !important; display: block"));
    try testing.expect(!inlineDisplayIsNone("width: 0px; height: 0px"));
    try testing.expect(!inlineDisplayIsNone("display: inline"));
    try testing.expect(!inlineDisplayIsNone(""));
}

//! HTML "hyperlink auditing" (4.6.6): following a hyperlink that an `a` or
//! `area` element with a `ping` attribute creates sends a POST to each URL
//! the attribute lists, independent of the navigation it accompanies.
//!
//! Called by HTMLAnchorElement and HTMLAreaElement: their activation
//! behaviour calls `audit` as it follows the hyperlink, before the
//! navigation starts, as Blink does (HTMLAnchorElement::NavigateToHyperlink
//! sends the pings, then navigates). The pings are fire-and-forget fetches
//! (dom.keepalive_fetch) and their responses ignored: "User agents must
//! ignore any entity bodies returned in the responses."
//!
//! Step 2, "Optionally, return", is not taken: every ping is sent.
//!
//! Spec: https://html.spec.whatwg.org/multipage/links.html#hyperlink-auditing

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const fetch = @import("fetch");
const dom = @import("dom");
const global_settings = dom.global_settings;
const html_core = @import("html_core");
const LivePings = @FieldType(html_core.agent_host.AgentHost, "hyperlink_pings");

const log = std.log.scoped(.hyperlink_auditing);

/// The shared owner for a and area requests, installed with the anchor's
/// process hooks.
pub fn installDocumentAbort() void {
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareDocumentAbort, .abort = abortDocument });
}

fn livePings(realm: runtime.Context) ?*LivePings {
    const agent = realm.agent orelse return null;
    const host: *html_core.agent_host.AgentHost = @ptrCast(@alignCast(@import("engine").agentHost(agent) orelse return null));
    return &host.hyperlink_pings;
}

fn prepareDocumentAbort(document: *runtime.Instance) bool {
    const registry = livePings(document.ctx) orelse return false;
    const generation = runtime.SlabAllocator.generationOf(document);
    var canceled = false;
    for (registry.entries.toSlice()) |entry| {
        const ping: *Audit = @ptrCast(@alignCast(entry.instance));
        if (ping.document != document or ping.document_generation != generation) continue;
        ping.document_abort_pending = true;
        canceled = true;
    }
    return canceled;
}

fn abortDocument(document: *runtime.Instance) void {
    const registry = livePings(document.ctx) orelse return;
    while (true) {
        const ping = for (registry.entries.toSlice()) |entry| {
            const candidate: *Audit = @ptrCast(@alignCast(entry.instance));
            if (candidate.document == document and candidate.document_abort_pending) break candidate;
        } else return;
        ping.cancel();
    }
}

fn discardRealm(realm: runtime.Context) void {
    const registry = livePings(realm) orelse return;
    while (true) {
        const ping = for (registry.entries.toSlice()) |entry| {
            if (entry.realm == @as(*anyopaque, @ptrCast(realm))) break @as(*Audit, @ptrCast(@alignCast(entry.instance)));
        } else return;
        ping.cancel();
    }
}

/// Audit the following of the hyperlink `subject` (an `a` or `area`
/// element) creates: "If a hyperlink created by an a or area element has a
/// ping attribute, and the user follows the hyperlink, and the value of the
/// element's href attribute can be parsed, relative to the element's node
/// document, without failure, then the user agent must take the ping
/// attribute's value, split that string on ASCII whitespace, parse each
/// resulting token, relative to the element's node document, and then run
/// these steps for each resulting URL ping URL, ignoring when parsing
/// returns failure."
///
/// The caller follows the hyperlink; a subject that cannot navigate (its
/// node document has no Window, or it is a disconnected `area`) follows
/// nothing, and is not audited either.
pub fn audit(subject: *runtime.Instance) void {
    const ping_attr = (interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("ping")) catch null) orelse return;
    const href = (interfaces.Element.call_getAttribute(subject, runtime.DOMString.initInterned("href")) catch null) orelse return;
    const document = (interfaces.Node.get_ownerDocument(subject) catch null) orelse return;
    // "Cannot navigate": the node document is not fully active, or the
    // subject is not an a element and is not connected.
    const window = (interfaces.Document.get_defaultView(document) catch null) orelse return;
    const is_anchor = subject.stateAs(interfaces.HTMLAnchorElement.State) != null;
    if (!is_anchor and !(interfaces.Node.get_isConnected(subject) catch false)) return;

    // What parseRelative and the document's URL getter return is the
    // document's context's.
    const allocator = document.ctx.allocator;
    // Step 5's target URL: the href, encoding-parsed and serialized. If it
    // does not parse, the hyperlink is not audited at all.
    const target_url = parseRelative(document, href.asSlice()) orelse return;
    defer allocator.free(target_url);
    const document_url = interfaces.Document.get_URL(document) catch return;
    defer allocator.free(document_url);
    // The attribute's value is the element's; copy it before anything runs.
    const ping = allocator.dupe(u8, ping_attr.asSlice()) catch return;
    defer allocator.free(ping);

    var tokens = std.mem.tokenizeAny(u8, ping, " \t\n\x0C\r");
    while (tokens.next()) |token| {
        const ping_url = parseRelative(document, token) orelse continue;
        defer allocator.free(ping_url);
        sendPing(window, document, document_url, ping_url, target_url) catch |err| {
            log.warn("ping to {s} not sent: {}", .{ ping_url, err });
        };
    }
}

/// Steps 1-6 for one ping URL.
fn sendPing(window: *runtime.Instance, document: *runtime.Instance, document_url: []const u8, ping_url: []const u8, target_url: []const u8) !void {
    // 1. "If ping URL's scheme is not an HTTP(S) scheme, then return."
    const scheme_end = std.mem.indexOfScalar(u8, ping_url, ':') orelse return;
    if (!fetch.algorithms.isHttpScheme(ping_url[0..scheme_end])) return;

    const allocator = window.ctx.allocator;
    // 3. "Let settingsObject be the element's node document's relevant
    //    settings object" - its Window's.
    // 4. "Let request be a new request whose URL is ping URL, method is
    //    `POST`, header list is « (`Content-Type`, `text/ping`) », body is
    //    `PING`, client is settingsObject, destination is the empty string,
    //    credentials mode is "include", referrer is "no-referrer", and whose
    //    use-URL-credentials flag is set, and whose initiator type is "ping"."
    const request = try fetch.internal.InternalRequest.init(allocator, ping_url);
    var owned = true;
    defer if (owned) request.deinit();
    try request.setMethod("POST");
    try request.header_list.set("Content-Type", "text/ping");
    // A literal: it outlives the fetch.
    request.body = .{ .bytes = "PING" };
    request.destination = .empty;
    request.credentials_mode = .include;
    request.setReferrer(.no_referrer);
    request.use_url_credentials = true;
    request.initiator_type = .ping;
    var client = try global_settings.requestClient(window);
    defer client.deinit();
    try fetch.internal.populateRequestFromClient(request, client.request);

    // 5. "If the URL of the Document object containing the hyperlink being
    //    audited and ping URL have the same origin", or "if the origins are
    //    different, but the scheme of the URL of the Document containing the
    //    hyperlink being audited is not "https"": `Ping-From` with the
    //    document's URL and `Ping-To` with target URL. "Otherwise": `Ping-To`
    //    only.
    const same_origin = try fetch.internal.origins.sameOrigin(allocator, document_url, ping_url);
    if (same_origin or !std.mem.startsWith(u8, document_url, "https:")) {
        try request.header_list.set("Ping-From", document_url);
    }
    try request.header_list.set("Ping-To", target_url);

    // 6. "Fetch request." Its response is ignored. The document's abort
    //    cancels it (installDocumentAbort): an audit is no keepalive request.
    const record = try allocator.create(Audit);
    record.* = .{
        .allocator = allocator,
        .document = document,
        .document_generation = runtime.SlabAllocator.generationOf(document),
    };
    if (livePings(window.ctx)) |registry| {
        registry.add(record, window.ctx) catch |err| {
            allocator.destroy(record);
            return err;
        };
        record.registry = registry;
    }
    owned = false;
    // The dispatch takes the request on every path.
    const dispatch = dom.keepalive_fetch.start(window, request, .{ .observer = .{ .context = record, .ended = Audit.ended } }) catch |err| {
        record.destroy();
        return err;
    };
    record.dispatch = dispatch orelse {
        // Rejected: nothing was sent, and nothing will end it.
        record.destroy();
        return;
    };
}

/// A ping in flight, for its document's abort: the page that sent it and
/// the dispatch (dom.keepalive_fetch) that fetches it. Freed when the
/// dispatch ends, or when the document's abort cancels it.
const Audit = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    document_generation: u64,
    document_abort_pending: bool = false,
    registry: ?*LivePings = null,
    dispatch: ?*dom.keepalive_fetch.Dispatch = null,

    fn cancel(self: *Audit) void {
        const dispatch = self.dispatch;
        self.dispatch = null;
        // cancel does not call ended; this owner releases its native
        // registry entry and record itself.
        if (dispatch) |d| d.cancel();
        self.destroy();
    }

    fn destroy(self: *Audit) void {
        if (self.registry) |registry| registry.remove(self);
        self.allocator.destroy(self);
    }

    /// The dispatch finished, or was terminated with its realm.
    fn ended(context: *anyopaque) void {
        const self: *Audit = @ptrCast(@alignCast(context));
        self.dispatch = null;
        self.destroy();
    }
};

/// `url` parsed relative to `document`'s base URL and serialized, owned by
/// the document's context allocator; null when it does not parse.
fn parseRelative(document: *runtime.Instance, url: []const u8) ?[]const u8 {
    const base = interfaces.Node.get_baseURI(document) catch return null;
    defer document.ctx.allocator.free(base);
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const parsed = (interfaces.URL.call_static_parse(document, url, base_arg) catch null) orelse return null;
    defer runtime.Instance.deinit(parsed);
    return interfaces.URL.get_href(parsed) catch null;
}

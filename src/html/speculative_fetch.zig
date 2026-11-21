//! HTML 13.2.8 "Speculative HTML parsing": a parser's active speculative
//! HTML parser (`Speculation`) and its "speculative fetch" of what each
//! speculative mock element would fetch.
//!
//! "A speculative fetch for a speculative mock element element, given a
//! Document document, must follow these rules: ... Let url be the URL that
//! element would fetch if it was processed normally in document. If there is
//! no such URL or if it is the empty string, then do nothing. Otherwise, if
//! url is already in document's list of speculative fetch URLs, then do
//! nothing. Otherwise, fetch url as if the element was processed normally in
//! document, and add url to document's list of speculative fetch URLs."
//!
//! So each request here is the one the element's own algorithm builds -
//! "create a potential-CORS request" for an img and a classic script, "fetch
//! a single module script"'s for a module script, "create a link request" for
//! a link, CSS "fetch a style resource" for a style element's @import - with
//! the element's attributes as the scanner read them, the document's
//! settings object as its client, and its Resource Timing initiator type.
//! It is marked speculative (`speculative_preload`): Fetch step 11 puts its
//! response in the document's map of preloaded resources as a speculative
//! entry, and the element's own fetch, with the same preload key, consumes
//! it - one fetch, one Resource Timing entry (dom.document_resources). Blink
//! issues its scanner's requests as speculative preloads the element's
//! request matches the same way (PreloadRequest::Start ->
//! PreloadHelper::StartPreload, ResourceFetcher::MatchPreload; BSD and LGPL
//! files, read for behaviour only), and so does WebKit
//! (HTMLResourcePreloader -> CachedResourceLoader::preload).
//!
//! Stated choices:
//! - a speculative fetch reports no CSP violation: the element's own fetch
//!   reports what it violates (Blink suppresses reporting for speculative
//!   preloads); a meta Content-Security-Policy the scan met applies to the
//!   later speculative fetches ("act as if that element is processed for the
//!   purpose of its effect of subsequent speculative fetches"), as Firefox
//!   applies it (Chrome stops preloading at one; Safari ignores it -
//!   html/syntax/speculative-parsing meta-csp-img-src-none / -asterisk:
//!   Firefox 160 passes both);
//! - only http(s) URLs are fetched ahead (Fetch step 11 reaches no other
//!   scheme's preload);
//! - a key the document has already - a preload, a resource it loaded or is
//!   loading - is not fetched again (`beginSpeculativeFetch`).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const fetch = @import("fetch");
const csp = @import("csp");
const speculative_parser = @import("speculative_parser.zig");
const script_request = @import("script_request.zig");
const AsyncFetch = fetch.algorithms.AsyncFetch;
const Scanner = speculative_parser.Scanner;
const Found = speculative_parser.Found;

const log = std.log.scoped(.speculative_parser);

/// A parser's speculative HTML parser: its scanner, what of the parser's
/// input stream the scanner's copy starts at, and whether it is active - the
/// parser is waiting for a pending parsing-blocking script.
///
/// Spec: "To start the speculative HTML parser" starts a new one each time
/// the parser waits, "but user agents can implement a more efficient
/// strategy, so long as the end result is equivalent": a scanner the parser
/// has not passed, over a stream no document.write() changed, goes on where
/// it stopped (Blink and WebKit keep their preload scanner ahead of the
/// parser the same way), and starts again otherwise.
pub const Speculation = struct {
    allocator: std.mem.Allocator,
    document: *runtime.Instance,
    document_generation: u64,
    scanner: *Scanner,
    /// The parser's input stream offset the scanner's copy starts at, and the
    /// stream's insertion count then (InputStreamManager.insertions).
    origin: usize,
    insertions: u64,
    /// The parser waits for a pending parsing-blocking script: the scanner
    /// reads what arrives.
    active: bool = false,
    /// The meta Content-Security-Policy contents the scan met, in order,
    /// OWNED: each speculative fetch after one obeys it.
    policies: std.ArrayListUnmanaged([]u8) = .empty,
    /// An allocation failed: the speculation stops (no fetch is wrong for
    /// it; one is only late).
    failed: bool = false,

    pub fn create(allocator: std.mem.Allocator, document: *runtime.Instance, options: speculative_parser.Options, origin: usize, insertions: u64) !*Speculation {
        const self = try allocator.create(Speculation);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .document = document,
            .document_generation = runtime.SlabAllocator.generationOf(document),
            .scanner = try Scanner.create(allocator, options),
            .origin = origin,
            .insertions = insertions,
        };
        return self;
    }

    pub fn destroy(self: *Speculation) void {
        self.scanner.destroy();
        for (self.policies.items) |p| self.allocator.free(p);
        self.policies.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// Whether this scanner can go on for a parser whose next input character
    /// is at `position` of a stream with `insertions` insertions: no write
    /// changed the stream since it started, and the parser has not read past
    /// what it scanned.
    pub fn covers(self: *const Speculation, position: usize, insertions: u64) bool {
        if (self.failed or insertions != self.insertions or position < self.origin) return false;
        return position - self.origin <= self.scanner.tokenizer.nextInputPosition();
    }

    /// The parser's input stream got `chars` at its end.
    pub fn append(self: *Speculation, chars: []const u8) void {
        if (self.failed) return;
        self.scanner.append(chars) catch {
            self.failed = true;
        };
    }

    /// The parser's input is complete.
    pub fn complete(self: *Speculation) void {
        self.scanner.complete();
    }

    /// Run the scanner over what it has, fetching each speculative mock
    /// element's resource ("In parallel, run speculativeParser until it is
    /// stopped or until it reaches the end of its input stream" - here, on
    /// the parser's thread, as Blink's synchronous ScanAndPreload does).
    pub fn scan(self: *Speculation) void {
        if (self.failed or !self.active) return;
        if (!self.documentLive()) return;
        self.scanner.scan(.{ .context = self, .found = foundThrough }) catch {
            self.failed = true;
        };
    }

    fn documentLive(self: *const Speculation) bool {
        if (runtime.SlabAllocator.generationOf(self.document) != self.document_generation) return false;
        // "Elements created in an inert Document have no browsing context, so
        // no speculative fetch is started for them."
        return (interfaces.Document.get_defaultView(self.document) catch null) != null;
    }

    fn foundThrough(context: *anyopaque, found: *const Found) void {
        const self: *Speculation = @ptrCast(@alignCast(context));
        self.takePolicies() catch {
            self.failed = true;
            return;
        };
        self.fetchFound(found) catch |err| log.debug("speculative fetch of {s} not started: {}", .{ found.url, err });
    }

    fn takePolicies(self: *Speculation) !void {
        for (self.scanner.newPolicies()) |content| {
            const copy = try self.allocator.dupe(u8, content);
            errdefer self.allocator.free(copy);
            try self.policies.append(self.allocator, copy);
        }
    }

    /// "Let url be the URL that element would fetch if it was processed
    /// normally in document" - against the predicted base URL when the scan
    /// met a base element - "... fetch url as if the element was processed
    /// normally in document, and add url to document's list of speculative
    /// fetch URLs."
    fn fetchFound(self: *Speculation, found: *const Found) !void {
        const allocator = self.allocator;
        const document = self.document;
        const url = (try self.resolve(found)) orelse return;
        defer allocator.free(url);
        if (!std.ascii.startsWithIgnoreCase(url, "http:") and !std.ascii.startsWithIgnoreCase(url, "https:")) return;

        const request = try fetch.internal.InternalRequest.init(allocator, url);
        var request_owned = true;
        defer if (request_owned) request.deinit();
        try buildRequest(request, found);
        try script_request.populateRequestFromClient(request, document.ctx);
        // The element's own fetch reports what it violates.
        request.csp_violation_reporter = null;
        switch (request.policy_container) {
            .container => |*container| for (self.policies.items) |content| {
                csp.integration.enforceMetaPolicy(&container.csp_list, content, null, null);
            },
            .client => {},
        }
        const resources = dom.document_resources.ensure(document) orelse return;
        if (!resources.beginSpeculativeFetch(url, request)) return;
        request.speculative_preload = true;
        const client = try Detached.create(allocator, document.ctx);
        // The fetch owns the request from here, even when it fails to start.
        request_owned = false;
        _ = AsyncFetch.start(allocator, request, .{}, dom.agent_fetches.of(document.ctx), client.client()) catch |err| {
            client.destroy();
            return err;
        };
    }

    /// The URL `found` names: encoding-parsed with the document's encoding,
    /// against the predicted frozen base URL when the scan met a base
    /// element, else the document's base URL. OWNED; null when it does not
    /// parse.
    ///
    /// The predicted base is HTML's "set the frozen base URL" for that
    /// element: its href parsed against the document's fallback base URL -
    /// the document's URL, or an about:blank / srcdoc document's about base
    /// URL - as the base element computes it (HTMLBaseElement
    /// setFrozenBaseURL); a URL that fails to parse, or a data: or
    /// javascript: one, leaves the document's base URL (Blink
    /// TokenPreloadScanner::UpdatePredictedBaseURL rejects the same).
    fn resolve(self: *Speculation, found: *const Found) !?[]const u8 {
        const allocator = self.allocator;
        const document = self.document;
        const href = found.base orelse return dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, document, found.url);
        const document_url = try interfaces.Document.get_URL(document);
        defer document.ctx.allocator.free(document_url);
        const fallback = dom.document_lifecycle.aboutFallbackBaseUrl(document) orelse document_url;
        const base = (try dom.encoding_parse.encodingParseAndSerializeAgainst(allocator, document, href, fallback)) orelse
            return dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, document, found.url);
        defer allocator.free(base);
        if (std.ascii.startsWithIgnoreCase(base, "data:") or std.ascii.startsWithIgnoreCase(base, "javascript:"))
            return dom.encoding_parse.encodingParseAndSerializeWithAllocator(allocator, document, found.url);
        return dom.encoding_parse.encodingParseAndSerializeAgainst(allocator, document, found.url, base);
    }
};

/// The request the element's own algorithm builds, from the scanned
/// attributes (its URL already set).
fn buildRequest(request: *fetch.internal.InternalRequest, found: *const Found) !void {
    request.initiator_type = found.initiator_type;
    request.referrer_policy = found.referrer_policy;
    switch (found.kind) {
        // HTML "update the image data" step 23 / the image loading of an
        // input's Image Button state and SVG's image: "create a potential-
        // CORS request given urlString, "image", and the crossorigin state".
        .image => {
            script_request.createPotentialCorsRequest(request, .image, found.cors);
            if (found.imageset) request.initiator = .imageset;
        },
        // "Fetch a classic script": a potential-CORS request, destination
        // "script", set up with the script's fetch options (its nonce,
        // integrity, parser metadata "parser-inserted").
        .classic_script => {
            script_request.createPotentialCorsRequest(request, .script, found.cors);
            try setUpScriptRequest(request, found, true);
        },
        // "Fetch a single module script": mode "cors", the credentials mode
        // of the crossorigin state ("same-origin" by default).
        .module_script => {
            request.mode = .cors;
            request.credentials_mode = if (found.cors == .use_credentials) .include else .same_origin;
            request.destination = .script;
            try setUpScriptRequest(request, found, true);
        },
        // A modulepreload's single module script: not parser-inserted.
        .modulepreload => {
            request.mode = .cors;
            request.credentials_mode = if (found.cors == .use_credentials) .include else .same_origin;
            request.destination = found.destination;
            try setUpScriptRequest(request, found, false);
        },
        // "Create a link request": a potential-CORS request with the link's
        // destination, integrity, nonce and fetch priority.
        .style_sheet, .preload => {
            script_request.createPotentialCorsRequest(request, if (found.kind == .style_sheet) .style else found.destination, found.cors);
            try request.setIntegrityMetadata(found.integrity);
            if (found.nonce.len != 0) try request.setCryptographicNonceMetadata(found.nonce);
            request.priority = found.fetch_priority;
            request.render_blocking = found.render_blocking;
        },
        // CSS "fetch a style resource" for an @import: "no-cors",
        // credentials "include", destination "style".
        .import => {
            script_request.createPotentialCorsRequest(request, .style, .no_cors);
            request.render_blocking = found.render_blocking;
        },
    }
}

fn setUpScriptRequest(request: *fetch.internal.InternalRequest, found: *const Found, parser_inserted: bool) !void {
    if (found.nonce.len != 0) try request.setCryptographicNonceMetadata(found.nonce);
    try request.setIntegrityMetadata(found.integrity);
    request.parser_metadata = if (parser_inserted) .parser_inserted else .not_parser_inserted;
    request.render_blocking = found.render_blocking;
}

/// A speculative fetch's client: nobody reads its response but the document's
/// entry the fetch fills (FetchJob.keepForDocument). It ends with the fetch,
/// or with the document's realm.
const Detached = struct {
    allocator: std.mem.Allocator,
    realm: runtime.Context,

    fn create(allocator: std.mem.Allocator, realm: runtime.Context) !*Detached {
        const self = try allocator.create(Detached);
        self.* = .{ .allocator = allocator, .realm = realm };
        return self;
    }

    fn destroy(self: *Detached) void {
        self.allocator.destroy(self);
    }

    fn client(self: *Detached) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = ended, .finished = ended };
    }

    fn done(_: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        var result = outcome catch return;
        result.deinit();
    }

    fn alive(context: *anyopaque) bool {
        const self: *Detached = @ptrCast(@alignCast(context));
        return self.realm.engine_ctx != null;
    }

    fn ended(context: *anyopaque) void {
        const self: *Detached = @ptrCast(@alignCast(context));
        self.destroy();
    }
};

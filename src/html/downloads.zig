//! HTML "download the hyperlink" steps 8-9 and "handle as a download"
//! (4.6.6 Downloading resources).
//!
//! The request is made as step 8 says - destination the empty string,
//! initiator "download", the request's default mode ("no-cors") and
//! credentials mode - and fetched (step 9). Its response is handled as a
//! download: whether a download is kept is the embedder's call, through the
//! platform's `downloads` capability (the integrator, 2026-11-18). No platform
//! keeps one today, so each is "canceled by the user agent" (step 5.2) as
//! soon as its response arrives: the fetch ends there, its body unread.
//!
//! The request's mode and destination follow the spec, not one browser
//! (golden rule 2, mechanism by mechanism): for <a download> Chrome 157 sends
//! Sec-Fetch-Mode "navigate" and Sec-Fetch-Dest "empty", Firefox 160
//! "navigate" and "document", Safari 27.2 neither header
//! (fetch/metadata/generated/element-a.https.sub.html, wpt.fyi runs
//! 4786307730243584 / 4877168468033536 / 6479119966273536). The mode has a
//! majority (navigate) but the destination has none, so no one browser's
//! behaviour is the majorities' and the spec decides both: "no-cors" and "".
//!
//! WebDriver BiDi's download events (steps 1-4 and 5.2's "download end") are
//! not observed: Crane has no BiDi session, so "download behavior" is null.

const std = @import("std");
const runtime = @import("runtime");
const fetch = @import("fetch");
const dom = @import("dom");
const platform = @import("platform");

const AsyncFetch = fetch.algorithms.AsyncFetch;

const log = std.log.scoped(.downloads);

/// "Download the hyperlink" steps 8-9, after steps 1-7 (the caller's): fetch
/// `url` - urlString - for the download, its client `window`'s settings
/// object (the entry settings object: the document whose hyperlink was
/// activated). A request that cannot start is no download.
pub fn fetchHyperlink(window: *runtime.Instance, url: []const u8) void {
    start(window, url) catch |err| log.debug("download not started: {}", .{err});
}

fn start(window: *runtime.Instance, url: []const u8) !void {
    const allocator = window.ctx.allocator;
    // 8. "Let request be a new request whose URL is urlString, client is
    //    entry settings object, initiator is "download", destination is the
    //    empty string, and whose use-URL-credentials flag is set."
    const request = try fetch.internal.InternalRequest.init(allocator, url);
    var request_owned = true;
    errdefer if (request_owned) request.deinit();
    request.initiator = .download;
    request.destination = .empty;
    request.use_url_credentials = true;
    var client = try dom.global_settings.requestClient(window);
    defer client.deinit();
    try fetch.internal.populateRequestFromClient(request, client.request);

    // 9. "Fetch request, with processResponse set to the following steps
    //    given response response: handle as a download response with
    //    subject's node navigable and null."
    const download = try allocator.create(Download);
    errdefer allocator.destroy(download);
    download.* = .{ .allocator = allocator, .window = dom.same_object.Link.to(window) };
    // The fetch owns the request from here, failure included.
    request_owned = false;
    download.active = try AsyncFetch.startStreaming(allocator, request, .{}, dom.agent_fetches.of(window.ctx), download.client());
}

/// One download's fetch, until its response is handled or its client is
/// gone. Freed by `done` (after ending the fetch) or `gone`.
const Download = struct {
    allocator: std.mem.Allocator,
    /// The window whose document made the request: while it is the same
    /// object, the fetch has a client to hear it.
    window: dom.same_object.Link,
    active: ?*AsyncFetch = null,

    fn client(self: *Download) AsyncFetch.Client {
        return .{ .context = self, .done = done, .alive = alive, .gone = gone };
    }

    fn alive(context: *anyopaque) bool {
        const self: *Download = @ptrCast(@alignCast(context));
        return self.window.isLive();
    }

    /// processResponse: handle `outcome`'s response as a download. The
    /// fetch is ended first - its body is not read - and nothing is left of
    /// the download after this.
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Download = @ptrCast(@alignCast(context));
        // terminate() frees the fetch and calls nothing back.
        if (self.active) |active| {
            self.active = null;
            active.terminate();
        }
        if (outcome) |value| {
            var result = value;
            defer result.deinit();
            handleAsDownload(result.response);
        } else |_| {}
        self.allocator.destroy(self);
    }

    /// The fetch was ended because its window went: no download.
    fn gone(context: *anyopaque) void {
        const self: *Download = @ptrCast(@alignCast(context));
        self.active = null;
        self.allocator.destroy(self);
    }
};

/// "Handle as a download" `response`, for a platform that keeps no
/// downloads.
fn handleAsDownload(response: *fetch.internal.InternalResponse) void {
    _ = response;
    // 1. suggestedFilename: read only by WebDriver BiDi's events (2-4, 5.2),
    //    which no session observes here.
    // 2-4. WebDriver BiDi "download will begin": download behavior is null.
    // 5.1. "Run implementation-defined steps to save response for later
    //    use": the platform's. A platform that declares `downloads` must
    //    add the operation that saves it, and call it here.
    if (comptime platform.capabilities.downloads != .unsupported)
        @compileError("platform.capabilities.downloads is declared, but the platform protocol has no save-download operation yet: add it with the first platform that keeps downloads (docs/platform-protocol.md section 5)");
    // 5.2. "The download is canceled by the user agent": its response was
    //    received and nothing is kept (the caller ended the fetch).
}

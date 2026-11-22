//! Scheme fetch "file" (fetch/algorithms/file_fetch.zig): a file: document's
//! request for a file: URL gets the file with its extension's MIME type; a web
//! page's request for one is a network error; a request with no client gets
//! the file. What every browser does for a file: page's <script src>,
//! <link rel=stylesheet>, <img> (Vue's Puppeteer e2e pages load
//! ../../dist/vue.global.js that way), and refuses an http(s) page (Chrome's
//! "Not allowed to load local resource", Gecko's CheckLoadURI, WebKit's
//! canDisplay). Lane tpf.

const std = @import("std");
const testing = std.testing;
const fetch = @import("fetch");

const scheme_fetch = fetch.algorithms.scheme_fetch;
const InternalRequest = fetch.internal.InternalRequest;

const script = "window.loaded = 1;\n";

/// A file `name` holding `script` in a temporary directory, and its file: URL.
const Fixture = struct {
    tmp: std.testing.TmpDir,
    url: []u8,

    fn make(name: []const u8) !Fixture {
        var tmp = testing.tmpDir(.{});
        errdefer tmp.cleanup();
        try tmp.dir.writeFile(testing.io, .{ .sub_path = name, .data = script });
        const base = try tmp.dir.realPathFileAlloc(testing.io, ".", testing.allocator);
        defer testing.allocator.free(base);
        const url = try std.fmt.allocPrint(testing.allocator, "file://{s}/{s}", .{ base, name });
        return .{ .tmp = tmp, .url = url };
    }

    fn end(self: *Fixture) void {
        testing.allocator.free(self.url);
        self.tmp.cleanup();
    }
};

fn requestFor(url: []const u8) !*InternalRequest {
    return InternalRequest.init(testing.allocator, url);
}

test "a file: document's request for a file: URL gets the file, typed by its extension" {
    var fixture = try Fixture.make("app.js");
    defer fixture.end();
    const request = try requestFor(fixture.url);
    defer request.deinit();
    // Populated from a file: document's client (its document URL).
    try fetch.internal.request_client.populateRequestFromClient(request, .{ .origin = "null", .referrer_source = "file:///Users/x/page.html" });
    const result = try scheme_fetch.schemeFetchRequest(testing.allocator, request);
    const response = switch (result) {
        .response => |r| r,
        .network_error => |why| {
            std.debug.print("network error: {s}\n", .{why orelse ""});
            return error.TestUnexpectedNetworkError;
        },
    };
    defer response.deinit();
    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expectEqualStrings("text/javascript", response.header_list.getFirstValue("Content-Type") orelse "");
    try testing.expectEqualStrings(script, (response.body orelse return error.NoBody).getBytes());
}

test "a web page's request for a file: URL is a network error" {
    var fixture = try Fixture.make("secret.js");
    defer fixture.end();
    const request = try requestFor(fixture.url);
    defer request.deinit();
    try fetch.internal.request_client.populateRequestFromClient(request, .{ .origin = "https://example.com", .referrer_source = "https://example.com/" });
    switch (try scheme_fetch.schemeFetchRequest(testing.allocator, request)) {
        .response => |r| {
            r.deinit();
            return error.TestExpectedNetworkError;
        },
        .network_error => {},
    }
}

test "a request with no client gets the file; a missing file and another host are network errors" {
    var fixture = try Fixture.make("style.css");
    defer fixture.end();
    {
        const request = try requestFor(fixture.url);
        defer request.deinit();
        const response = switch (try scheme_fetch.schemeFetchRequest(testing.allocator, request)) {
            .response => |r| r,
            .network_error => return error.TestUnexpectedNetworkError,
        };
        defer response.deinit();
        try testing.expectEqualStrings("text/css", response.header_list.getFirstValue("Content-Type") orelse "");
    }
    for ([_][]const u8{ "file:///no/such/dir/missing.js", "file://fileserver/share/a.js" }) |url| {
        const request = try requestFor(url);
        defer request.deinit();
        switch (try scheme_fetch.schemeFetchRequest(testing.allocator, request)) {
            .response => |r| {
                r.deinit();
                return error.TestExpectedNetworkError;
            },
            .network_error => {},
        }
    }
}

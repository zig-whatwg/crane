//! Lane mcp1, batch 3: the tools that read and write the server's files, as
//! chrome-devtools-mcp v1.13.0 answers them (src/ToolHandler.ts
//! validateToolFiles over each tool's verifyFilesSchema, src/McpContext.ts
//! validatePath, saveFile and loadResource, src/tools/script.ts
//! resolveScriptSource, src/tools/input.ts upload_file over Puppeteer's
//! ElementHandle.uploadFile, src/McpResponse.ts and
//! src/formatters/NetworkFormatter.ts): every path checked against the roots
//! before the page is resolved - the configured ones (the OS temp directory
//! by default), the client's, and always the temp directory - and replaced
//! by its canonical form; a file written there owner-only with its
//! extension replaced; a script source read from a path or a file: URL.

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const Harness = @import("mcp1_harness.zig").Harness;
const Site = @import("cdpr_replay.zig").Site;

/// Two fresh directories, canonical: one under the OS temp directory (a root
/// by default), one under the checkout's tmp/ (none, unless the checkout is
/// itself under the temp directory: `outside_is_inside`).
const Dirs = struct {
    inside: []const u8,
    outside: []const u8,
    outside_is_inside: bool,

    fn make(a: std.mem.Allocator) !Dirs {
        var nonce: [8]u8 = undefined;
        platform.fillRandom(&nonce);
        const tag = std.mem.readInt(u64, &nonce, .little);
        const temp = try platform.realPath(a, platform.Str.from(try platform.tempDirectory(a)));
        const inside = try std.fmt.allocPrint(a, "{s}/mcp1-paths-{x}", .{ temp, tag });
        try platform.makeDirectoryPath(platform.Str.from(inside));
        const relative = try std.fmt.allocPrint(a, "tmp/mcp1-paths-{x}", .{tag});
        try platform.makeDirectoryPath(platform.Str.from(relative));
        const outside = try platform.realPath(a, platform.Str.from(relative));
        return .{
            .inside = try platform.realPath(a, platform.Str.from(inside)),
            .outside = outside,
            .outside_is_inside = std.mem.startsWith(u8, outside, try std.fmt.allocPrint(a, "{s}/", .{temp})),
        };
    }

    fn remove(self: Dirs) void {
        platform.deleteTree(platform.Str.from(self.inside)) catch {};
        platform.deleteTree(platform.Str.from(self.outside)) catch {};
    }
};

fn write(a: std.mem.Allocator, dir: []const u8, name: []const u8, bytes: []const u8) ![]const u8 {
    const path = try std.fmt.allocPrint(a, "{s}/{s}", .{ dir, name });
    try platform.writeFileAtomic(platform.Str.from(path), platform.Bytes.from(bytes));
    return path;
}

fn read(a: std.mem.Allocator, path: []const u8) ![]const u8 {
    return platform.readFile(a, platform.Str.from(path), 1 << 20);
}

/// The permission bits of `path` (std.c.Stat is void on glibc: std.Io's stat).
fn modeOf(path: []const u8) !u32 {
    const st = try std.Io.Dir.cwd().statFile(testing.io, path, .{});
    return @intCast(st.permissions.toMode() & 0o777);
}

fn expectResult(a: std.mem.Allocator, text: []const u8, json: []const u8) !void {
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Script ran on page and returned:\n```json\n{s}\n```", .{json}), text);
}

fn denied(a: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.fmt.allocPrint(a, "Error: Access denied: path \"{s}\" (canonical: \"{s}\") is not within any of the configured workspace roots.", .{ path, path });
}

/// The uid on the snapshot line that holds `needle`.
fn uidOf(text: []const u8, needle: []const u8) ![]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, needle) == null) continue;
        const at = std.mem.indexOf(u8, line, "uid=") orelse return error.NoUid;
        const rest = line[at + "uid=".len ..];
        return rest[0 .. std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len];
    }
    std.debug.print("no line with {s} in:\n{s}\n", .{ needle, text });
    return error.NoLine;
}

test "take_snapshot filePath: written under a root with its extension .txt, owner-only; outside every root, or a URL, refused" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const dirs = try Dirs.make(a);
    defer dirs.remove();

    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>T</title><h2>Head</h2>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("take_snapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":\"{s}/snap.md\"}}", .{dirs.inside}));
    try testing.expect(!r.is_error);
    const saved = try std.fmt.allocPrint(a, "{s}/snap.txt", .{dirs.inside});
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Saved snapshot to {s}.", .{saved}), r.text);
    try testing.expectEqual(@as(u32, 0o600), try modeOf(saved));
    // The file is the snapshot's text, as the inline answer gives it.
    const inline_answer = try h.tool("take_snapshot", "{\"pageId\":1}");
    const heading = "## Latest page snapshot\n";
    try testing.expect(std.mem.startsWith(u8, inline_answer.text, heading));
    try testing.expectEqualStrings(inline_answer.text[heading.len..], try read(a, saved));
    // An empty path is no path (validateAndResolvePathOrUrl: undefined).
    r = try h.tool("take_snapshot", "{\"pageId\":1,\"filePath\":\"  \"}");
    try testing.expect(std.mem.startsWith(u8, r.text, heading));

    r = try h.tool("take_snapshot", "{\"pageId\":1,\"filePath\":\"https://a.test/snap.txt\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: This parameter expects a file path, not a URL.", r.text);
    if (!dirs.outside_is_inside) {
        const outside = try std.fmt.allocPrint(a, "{s}/deeper/snap.txt", .{dirs.outside});
        r = try h.tool("take_snapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":\"{s}\"}}", .{outside}));
        try testing.expect(r.is_error);
        try testing.expectEqualStrings(try denied(a, outside), r.text);
        // Checked before the page is resolved: a missing page is not reached.
        r = try h.tool("take_snapshot", try std.fmt.allocPrint(a, "{{\"pageId\":9,\"filePath\":\"{s}\"}}", .{outside}));
        try testing.expectEqualStrings(try denied(a, outside), r.text);
    }
}

test "evaluate_script filePath: the result written as .json ('undefined' for none); sourcePath read from a path or a file: URL" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const dirs = try Dirs.make(a);
    defer dirs.remove();

    var r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":\"() => 6 * 7\",\"filePath\":\"{s}/out\"}}", .{dirs.inside}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Script ran on page. Output saved to {s}/out.json.", .{dirs.inside}), r.text);
    try testing.expectEqualStrings("42", try read(a, try std.fmt.allocPrint(a, "{s}/out.json", .{dirs.inside})));
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":\"() => undefined\",\"filePath\":\"{s}/none.txt\"}}", .{dirs.inside}));
    try testing.expectEqualStrings("undefined", try read(a, try std.fmt.allocPrint(a, "{s}/none.json", .{dirs.inside})));

    const source = try write(a, dirs.inside, "s.js", "() => 6 * 7\n");
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"sourcePath\":\"{s}\"}}", .{source}));
    try expectResult(a, r.text, "42");
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"sourcePath\":\"file://{s}\"}}", .{source}));
    try expectResult(a, r.text, "42");
    // fs.readFile(path, 'utf-8'): a byte that is not UTF-8 becomes U+FFFD.
    const odd = try write(a, dirs.inside, "odd.js", "() => '\xff'");
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"sourcePath\":\"{s}\"}}", .{odd}));
    try expectResult(a, r.text, "\"\u{FFFD}\"");

    const missing = try std.fmt.allocPrint(a, "{s}/missing.js", .{dirs.inside});
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"sourcePath\":\"{s}\"}}", .{missing}));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Error: Unable to read script source from {s}: ENOENT: no such file or directory, open '{s}'", .{ missing, missing }), r.text);
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":\"() => 1\",\"sourcePath\":\"{s}\"}}", .{source}));
    try testing.expectEqualStrings("Error: Specify exactly one of function or sourcePath.", r.text);
    // An empty sourcePath is none.
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => 1\",\"sourcePath\":\"\"}");
    try expectResult(a, r.text, "1");
}

test "evaluate_script sourcePath: an http(s) URL is never fetched - resolveScriptSource makes it a path under the working directory" {
    // chrome-devtools-mcp v1.13.0: validateToolFiles lets the URL through
    // (allowUrl), then resolveScriptSource turns anything not starting with
    // "file:" into pathToFileURL(value), and loadResource checks and reads
    // that file.
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const cwd = try platform.realPath(a, platform.Str.from("."));
    const temp = try platform.realPath(a, platform.Str.from(try platform.tempDirectory(a)));
    const as_path = try std.fmt.allocPrint(a, "{s}/https:/a.test/x.js", .{cwd});
    const r = try h.tool("evaluate_script", "{\"pageId\":1,\"sourcePath\":\"https://a.test/x.js\"}");
    try testing.expect(r.is_error);
    if (std.mem.startsWith(u8, cwd, try std.fmt.allocPrint(a, "{s}/", .{temp}))) {
        try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Error: Unable to read script source from https://a.test/x.js: ENOENT: no such file or directory, open '{s}'", .{as_path}), r.text);
    } else {
        try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Error: Unable to read script source from https://a.test/x.js: Access denied: path \"{s}\" (canonical: \"{s}\") is not within any of the configured workspace roots.", .{ as_path, as_path }), r.text);
    }
}

test "the roots: configured ones replace the default, the temp directory stays, the client's add theirs, --allow-unrestricted-paths lifts the check until the client lists any" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const dirs = try Dirs.make(a);
    defer dirs.remove();
    if (dirs.outside_is_inside) return error.SkipZigTest;
    const paths = &h.mcp_server.session.paths;
    const outside = try std.fmt.allocPrint(a, "{s}/o", .{dirs.outside});
    const call = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":\"() => 1\",\"filePath\":\"{s}\"}}", .{outside});
    const saved = try std.fmt.allocPrint(a, "Script ran on page. Output saved to {s}.json.", .{outside});

    var r = try h.tool("evaluate_script", call);
    try testing.expectEqualStrings(try denied(a, outside), r.text);

    // --allow-unrestricted-paths, no client roots: anywhere.
    paths.allow_unrestricted = true;
    r = try h.tool("evaluate_script", call);
    try testing.expectEqualStrings(saved, r.text);

    // The client lists a root: checked again, against the client's and the
    // temp directory (the configured ones are dropped by the flag).
    h.mcp_server.protocol.client_roots = true;
    const request = (try h.mcp_server.handle(a, "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/roots/list_changed\"}")).?;
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, a, request, .{});
    try testing.expectEqualStrings("roots/list", parsed.object.get("method").?.string);
    const id = parsed.object.get("id").?.integer;
    const other = try std.fmt.allocPrint(a, "{s}/sub", .{dirs.outside});
    try platform.makeDirectoryPath(platform.Str.from(other));
    _ = try h.mcp_server.handle(a, try std.fmt.allocPrint(a, "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"result\":{{\"roots\":[{{\"uri\":\"file://{s}\",\"name\":\"sub\"}}]}}}}", .{ id, other }));
    r = try h.tool("evaluate_script", call);
    try testing.expectEqualStrings(try denied(a, outside), r.text);
    const in_client = try std.fmt.allocPrint(a, "{s}/c", .{other});
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":\"() => 1\",\"filePath\":\"{s}\"}}", .{in_client}));
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Script ran on page. Output saved to {s}.json.", .{in_client}), r.text);

    // A configured root, without the flag: it and the temp directory.
    paths.allow_unrestricted = false;
    const configured = [_][]const u8{dirs.outside};
    paths.configured = &configured;
    defer paths.configured = null;
    r = try h.tool("evaluate_script", call);
    try testing.expectEqualStrings(saved, r.text);
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"function\":\"() => 1\",\"filePath\":\"{s}/t\"}}", .{dirs.inside}));
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Script ran on page. Output saved to {s}/t.json.", .{dirs.inside}), r.text);
}

test "get_network_request requestFilePath and responseFilePath: the bodies saved, each section saying where" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const site = try Site.start(h.gpa.allocator());
    defer site.stop();
    const a = h.arena.allocator();
    const dirs = try Dirs.make(a);
    defer dirs.remove();
    var buffer: [128]u8 = undefined;
    const root = try a.dupe(u8, try site.url(&buffer, "/"));

    var r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}\"}}", .{root}));
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"async () => (await fetch('/missing', {method: 'POST', body: 'abc'})).status\"}");
    try expectResult(a, r.text, "404");
    r = try h.tool("list_network_requests", "{\"pageId\":1,\"resourceTypes\":[\"fetch\"]}");
    const line = r.text[std.mem.lastIndexOfScalar(u8, r.text, '\n').? + 1 ..];
    try testing.expect(std.mem.startsWith(u8, line, "reqid="));
    const reqid = line["reqid=".len..std.mem.indexOfScalar(u8, line, ' ').?];

    r = try h.tool("get_network_request", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"reqid\":{s},\"requestFilePath\":\"{s}/req.txt\",\"responseFilePath\":\"{s}/resp\"}}", .{ reqid, dirs.inside, dirs.inside }));
    try testing.expect(!r.is_error);
    const request_file = try std.fmt.allocPrint(a, "{s}/req.network-request", .{dirs.inside});
    const response_file = try std.fmt.allocPrint(a, "{s}/resp.network-response", .{dirs.inside});
    if (std.mem.indexOf(u8, r.text, try std.fmt.allocPrint(a, "\n### Request Body\nSaved to {s}.\n", .{request_file})) == null or
        !std.mem.endsWith(u8, r.text, try std.fmt.allocPrint(a, "\n### Response Body\nSaved to {s}.", .{response_file})))
    {
        std.log.err("got: {s}", .{r.text});
        return error.TestUnexpectedResult;
    }
    try testing.expectEqualStrings("abc", try read(a, request_file));
    try testing.expectEqualStrings("not found", try read(a, response_file));
    try testing.expectEqual(@as(u32, 0o600), try modeOf(response_file));
}

const upload_page = "data:text/html,<input type=file aria-label=one><input type=file multiple aria-label=many><button>Go</button>" ++
    "<script>window.seen = []; for (const i of document.querySelectorAll('input')) for (const t of ['input', 'change']) i.addEventListener(t, (e) => seen.push(i.getAttribute('aria-label') %2B ':' %2B e.type));</script>";

test "upload_file: the files set on the input as Puppeteer's uploadFile sets them; several only with multiple; an element that is no file input" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const dirs = try Dirs.make(a);
    defer dirs.remove();
    const first = try write(a, dirs.inside, "a.txt", "hello");
    const second = try write(a, dirs.inside, "b.txt", "hi");

    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ upload_page ++ "\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("take_snapshot", "{\"pageId\":1}");
    const snapshot = try a.dupe(u8, r.text);
    // No file yet: "No file chosen".
    try testing.expect(std.mem.indexOf(u8, snapshot, "button \"many\" value=\"No file chosen\"") != null);
    const one = try uidOf(snapshot, "\"one\"");
    const many = try uidOf(snapshot, "\"many\"");
    const go = try uidOf(snapshot, "\"Go\"");

    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[\"{s}\"]}}", .{ one, first }));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "File uploaded from {s}.", .{first}), r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { const f = document.querySelector('input').files; return [f.length, f[0].name, f[0].size, seen.join()]; }\"}");
    try expectResult(a, r.text, "[1,\"a.txt\",5,\"one:input,one:change\"]");

    // Two files to an input without `multiple`: Puppeteer's assertion.
    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[\"{s}\",\"{s}\"]}}", .{ one, first, second }));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: Multiple file uploads only work with <input type=file multiple>", r.text);
    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[\"{s}\",\"{s}\"],\"includeSnapshot\":true}}", .{ many, first, second }));
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, try std.fmt.allocPrint(a, "File uploaded from {s}, {s}.\n## Latest page snapshot\n", .{ first, second })));
    // The inputs' values as Chrome reports them (Blink
    // FileInputType::FileStatusText): one file's name, then "<n> files".
    if (std.mem.indexOf(u8, r.text, "button \"one\" value=\"a.txt\"") == null or std.mem.indexOf(u8, r.text, "button \"many\" value=\"2 files\"") == null) {
        std.log.err("got: {s}", .{r.text});
        return error.TestUnexpectedResult;
    }
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [...document.querySelectorAll('input')[1].files].map(f => f.name).join()\"}");
    try expectResult(a, r.text, "\"a.txt,b.txt\"");

    // Only blank paths: none - the input's files emptied, input and change
    // fired by script (uploadFile's zero-length case).
    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[\" \"]}}", .{one}));
    try testing.expectEqualStrings("File uploaded from .", r.text);
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => [document.querySelector('input').files.length, seen.slice(-2).join()]\"}");
    try expectResult(a, r.text, "[0,\"one:input,one:change\"]");

    // Not a file input: chrome-devtools-mcp clicks it and waits for a file
    // chooser; element clicks come with batch 5, and the answer says no
    // click happened.
    r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[\"{s}\"]}}", .{ go, first }));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: Failed to upload file. The element could not accept the file directly, and Crane's MCP server does not click elements yet, so no file chooser was opened.", r.text);

    if (!dirs.outside_is_inside) {
        const outside = try write(a, dirs.outside, "c.txt", "x");
        r = try h.tool("upload_file", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":\"{s}\",\"filePaths\":[\"{s}\"]}}", .{ one, outside }));
        try testing.expectEqualStrings(try denied(a, outside), r.text);
    }
}

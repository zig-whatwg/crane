//! Lane mcp1, batch 2: take_snapshot, element uids and wait_for as
//! chrome-devtools-mcp v1.13.0 answers them (src/tools/snapshot.ts,
//! src/TextSnapshot.ts, src/formatters/SnapshotFormatter.ts, McpPage
//! getElementByUid and waitForTextOnPage): the page's accessibility tree,
//! its interesting nodes numbered "<snapshot>_<n>" and kept across
//! snapshots of one document; a uid handed to evaluate_script as its
//! element, gone after a navigation; wait_for answering when text or an
//! accessible name appears, with the snapshot, or timing out with its
//! advice.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;

fn expectResult(text: []const u8, json: []const u8) !void {
    var buffer: [512]u8 = undefined;
    const want = try std.fmt.bufPrint(&buffer, "Script ran on page and returned:\n```json\n{s}\n```", .{json});
    try testing.expectEqualStrings(want, text);
}

/// The uid of the StaticText whose name is `name` (a text line prints its
/// uid and its quoted name, no role).
fn uidOfText(text: []const u8, name: []const u8) ![]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " ");
        if (!std.mem.startsWith(u8, trimmed, "uid=")) continue;
        const space = std.mem.indexOfScalar(u8, trimmed, ' ') orelse continue;
        const rest = trimmed[space + 1 ..];
        if (rest.len == name.len + 2 and rest[0] == '"' and rest[rest.len - 1] == '"' and std.mem.eql(u8, rest[1 .. rest.len - 1], name)) return trimmed["uid=".len..space];
    }
    std.debug.print("no text line {s} in:\n{s}\n", .{ name, text });
    return error.NoLine;
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

const page_url = "data:text/html,<title>T</title><h2>Head</h2><button>Go</button><a href=%23x>Link</a>";

test "take_snapshot: the page's interesting nodes, numbered in pre-order, the same uids in a second snapshot" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ page_url ++ "\"}");
    try testing.expect(!r.is_error);

    r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "## Latest page snapshot\nuid=1_0 RootWebArea \"T\""));
    try testing.expect(std.mem.endsWith(u8, r.text, "\n"));
    const button = try uidOf(r.text, "button \"Go\"");
    try testing.expect(std.mem.startsWith(u8, button, "1_"));
    try testing.expect(std.mem.indexOf(u8, r.text, "heading \"Head\" level=\"2\"") != null);
    // The link's text spells its name: not printed under it.
    try testing.expect(std.mem.indexOf(u8, r.text, "link \"Link\"") != null);
    const first = try testing.allocator.dupe(u8, r.text);
    defer testing.allocator.free(first);

    // A second snapshot of the same document: the same uids.
    r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expectEqualStrings(first, r.text);

    // Verbose: every node, the texts under their elements.
    r = try h.tool("take_snapshot", "{\"pageId\":1,\"verbose\":true}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.indexOf(u8, r.text, "\"Go\"\n") != null);
    // filePath: tests/devtools/mcp1_paths_test.zig (batch 3).
}

test "uids: evaluate_script gets the elements; a text node stands for its element; gone after a navigation" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ page_url ++ "\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("take_snapshot", "{\"pageId\":1,\"verbose\":true}");
    const arena = h.arena.allocator();
    const button = try arena.dupe(u8, try uidOf(r.text, "button \"Go\""));
    const heading = try arena.dupe(u8, try uidOf(r.text, "heading \"Head\""));

    r = try h.tool("evaluate_script", try std.fmt.allocPrint(arena, "{{\"pageId\":1,\"function\":\"(b, h) => b.textContent + '/' + h.tagName\",\"args\":[\"{s}\",\"{s}\"]}}", .{ button, heading }));
    try expectResult(r.text, "\"Go/H2\"");

    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"(el) => el.id\",\"args\":[\"9_9\"]}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: Element uid \"9_9\" not found on page 1.", r.text);

    // A new document: the snapshot's uids name nothing there.
    r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ page_url ++ "\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(arena, "{{\"pageId\":1,\"function\":\"(el) => el.id\",\"args\":[\"{s}\"]}}", .{button}));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(arena, "Error: Element with uid {s} no longer exists on the page.", .{button}), r.text);
}

test "uids: a StaticText's uid is its parent element (StaticText prints no role)" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"" ++ page_url ++ "\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("take_snapshot", "{\"pageId\":1,\"verbose\":true}");
    const arena = h.arena.allocator();
    const link_text = try arena.dupe(u8, try uidOfText(r.text, "Link"));
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(arena, "{{\"pageId\":1,\"function\":\"(el) => el.tagName\",\"args\":[\"{s}\"]}}", .{link_text}));
    try expectResult(r.text, "\"A\"");
}

test "uids: elements from two frames are refused together" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>F</title><button>Out</button><iframe srcdoc='<button>In</button>'></iframe>\"}");
    try testing.expect(!r.is_error);
    try h.settle(200);
    r = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!r.is_error);
    const arena = h.arena.allocator();
    const outer = try arena.dupe(u8, try uidOf(r.text, "button \"Out\""));
    const inner = try arena.dupe(u8, try uidOf(r.text, "button \"In\""));
    // The iframe's document sits under its Iframe node.
    try testing.expect(std.mem.indexOf(u8, r.text, "Iframe") != null);
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(arena, "{{\"pageId\":1,\"function\":\"(el) => el.textContent\",\"args\":[\"{s}\"]}}", .{inner}));
    try expectResult(r.text, "\"In\"");
    r = try h.tool("evaluate_script", try std.fmt.allocPrint(arena, "{{\"pageId\":1,\"function\":\"(a, b) => 1\",\"args\":[\"{s}\",\"{s}\"]}}", .{ outer, inner }));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: Elements from different frames can't be evaluated together.", r.text);
}

test "wait_for: text that appears later, an accessible name, a timeout with its advice" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    var r = try h.tool("navigate_page", "{\"pageId\":1,\"url\":\"data:text/html,<title>W</title><button aria-label=Close>x</button><script>setTimeout(() => { const p = document.createElement('p'); p.textContent = 'Order confirmed'; document.body.append(p); }, 300)</script>\"}");
    try testing.expect(!r.is_error);

    r = try h.tool("wait_for", "{\"pageId\":1,\"text\":[\"Nope\",\"confirmed\"],\"timeout\":5000}");
    try testing.expect(!r.is_error);
    try testing.expect(std.mem.startsWith(u8, r.text, "Element matching one of [\"Nope\",\"confirmed\"] found.\n## Latest page snapshot\nuid="));

    // An accessible name, matched whole.
    r = try h.tool("wait_for", "{\"pageId\":1,\"text\":[\"Close\"]}");
    try testing.expect(std.mem.startsWith(u8, r.text, "Element matching one of [\"Close\"] found.\n"));

    r = try h.tool("wait_for", "{\"pageId\":1,\"text\":[\"Never there\"],\"timeout\":300}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: Timed out after waiting 300ms. Text matching is case-sensitive. DOM text must preserve spaces and newlines, whereas snapshot text may normalize whitespace. Try a shorter distinctive substring.", r.text);

    // Text in the head (the title) is not DOM text Puppeteer matches.
    r = try h.tool("wait_for", "{\"pageId\":1,\"text\":[\"<script\"],\"timeout\":200}");
    try testing.expect(r.is_error);

    r = try h.tool("wait_for", "{\"pageId\":1,\"text\":[\"Close\"],\"visible\":true}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: visible is not supported by Crane's MCP server: Crane has no layout to tell whether text is visible.", r.text);
}

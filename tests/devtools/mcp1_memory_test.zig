//! Lane mcp1, batch 4b item 4: take_heapsnapshot - chrome-devtools-mcp
//! v1.13.0's src/tools/memory.ts (takeHeapSnapshot) over Puppeteer's
//! page.captureHeapSnapshot (HeapProfiler.takeHeapSnapshot +
//! HeapProfiler.addHeapSnapshotChunk) and Crane's path policy (paths.zig).

const std = @import("std");
const testing = std.testing;
const platform = @import("platform");
const Harness = @import("mcp1_harness.zig").Harness;

const Dirs = struct {
    inside: []const u8,
    outside: []const u8,
    outside_is_inside: bool,

    fn make(a: std.mem.Allocator) !Dirs {
        var nonce: [8]u8 = undefined;
        platform.fillRandom(&nonce);
        const tag = std.mem.readInt(u64, &nonce, .little);
        const temp = try platform.realPath(a, platform.Str.from(try platform.tempDirectory(a)));
        const inside = try std.fmt.allocPrint(a, "{s}/mcp1-heap-{x}", .{ temp, tag });
        try platform.makeDirectoryPath(platform.Str.from(inside));
        const relative = try std.fmt.allocPrint(a, "tmp/mcp1-heap-{x}", .{tag});
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

fn modeOf(path: []const u8) !u32 {
    const st = try std.Io.Dir.cwd().statFile(testing.io, path, .{});
    return @intCast(st.permissions.toMode() & 0o777);
}

fn validateHeapSnapshot(a: std.mem.Allocator, path: []const u8, expected_strings: []const []const u8) !void {
    const bytes = try platform.readFile(a, platform.Str.from(path), 64 << 20);
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, a, bytes, .{});
    try testing.expect(parsed == .object);
    const root = parsed.object;

    const snap = root.get("snapshot").?;
    try testing.expect(snap == .object);
    const meta = snap.object.get("meta").?;
    try testing.expect(meta == .object);
    const node_fields = meta.object.get("node_fields").?.array.items;
    const edge_fields = meta.object.get("edge_fields").?.array.items;
    try testing.expect(node_fields.len > 0);
    try testing.expect(edge_fields.len > 0);

    const node_count: usize = @intCast(snap.object.get("node_count").?.integer);
    const edge_count: usize = @intCast(snap.object.get("edge_count").?.integer);
    try testing.expect(node_count > 0);
    try testing.expect(edge_count > 0);

    const nodes = root.get("nodes").?.array.items;
    const edges = root.get("edges").?.array.items;
    const strings = root.get("strings").?.array.items;
    try testing.expectEqual(node_count * node_fields.len, nodes.len);
    try testing.expectEqual(edge_count * edge_fields.len, edges.len);
    try testing.expect(strings.len > 0);

    for (expected_strings) |needle| {
        var found = false;
        for (strings) |item| {
            if (item == .string and std.mem.eql(u8, item.string, needle)) {
                found = true;
                break;
            }
        }
        try testing.expect(found);
    }
}

test "take_heapsnapshot: saves valid V8 snapshot, normalizes extension, enforces roots and dialog block" {
    var h: Harness = .{};
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    const dirs = try Dirs.make(a);
    defer dirs.remove();

    // Listed in tools/list with chrome-devtools-mcp's schema.
    const listed = try h.send("tools/list", "{}");
    var found_tool = false;
    for (listed.object.get("result").?.object.get("tools").?.array.items) |tool| {
        if (std.mem.eql(u8, tool.object.get("name").?.string, "take_heapsnapshot")) {
            found_tool = true;
            break;
        }
    }
    try testing.expect(found_tool);

    const page_url = "data:text/html,<title>Heap</title><script>class CraneHeapMarkerObject{constructor(t){this.t=t}}window.__m=new CraneHeapMarkerObject('CRANE_HEAP_MARKER_7F3A');</script>";
    var r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":{f}}}", .{std.json.fmt(page_url, .{})}));
    try testing.expect(!r.is_error);

    // 1. Direct .heapsnapshot path.
    const direct_path = try std.fmt.allocPrint(a, "{s}/snap.heapsnapshot", .{dirs.inside});
    r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":{f}}}", .{std.json.fmt(direct_path, .{})}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Heap snapshot saved to {s}", .{direct_path}), r.text);
    try testing.expectEqual(@as(u32, 0o600), try modeOf(direct_path));
    try validateHeapSnapshot(a, direct_path, &.{ "CraneHeapMarkerObject", "CRANE_HEAP_MARKER_7F3A" });

    // 2. Non-.heapsnapshot extension replaced (.json -> .heapsnapshot).
    const json_req = try std.fmt.allocPrint(a, "{s}/renamed.json", .{dirs.inside});
    const json_saved = try std.fmt.allocPrint(a, "{s}/renamed.heapsnapshot", .{dirs.inside});
    r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":{f}}}", .{std.json.fmt(json_req, .{})}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Heap snapshot saved to {s}", .{json_saved}), r.text);
    try testing.expectEqual(@as(u32, 0o600), try modeOf(json_saved));
    try validateHeapSnapshot(a, json_saved, &.{"CRANE_HEAP_MARKER_7F3A"});

    // 3. Extension appended and nested parent directory created.
    const nested_req = try std.fmt.allocPrint(a, "{s}/sub/noext", .{dirs.inside});
    const nested_saved = try std.fmt.allocPrint(a, "{s}/sub/noext.heapsnapshot", .{dirs.inside});
    r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":{f}}}", .{std.json.fmt(nested_req, .{})}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Heap snapshot saved to {s}", .{nested_saved}), r.text);
    try validateHeapSnapshot(a, nested_saved, &.{"CraneHeapMarkerObject"});

    // 4. URL refused.
    r = try h.tool("take_heapsnapshot", "{\"pageId\":1,\"filePath\":\"https://example.com/a.heapsnapshot\"}");
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: This parameter expects a file path, not a URL.", r.text);

    // 5. Outside workspace roots refused before page resolution.
    if (!dirs.outside_is_inside) {
        const outside = try std.fmt.allocPrint(a, "{s}/escape.heapsnapshot", .{dirs.outside});
        const denied = try std.fmt.allocPrint(a, "Error: Access denied: path \"{s}\" (canonical: \"{s}\") is not within any of the configured workspace roots.", .{ outside, outside });
        r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":{f}}}", .{std.json.fmt(outside, .{})}));
        try testing.expect(r.is_error);
        try testing.expectEqualStrings(denied, r.text);
        r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":9,\"filePath\":{f}}}", .{std.json.fmt(outside, .{})}));
        try testing.expect(r.is_error);
        try testing.expectEqualStrings(denied, r.text);
    }

    // 6. Missing page refused.
    r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":9,\"filePath\":{f}}}", .{std.json.fmt(direct_path, .{})}));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings("Error: No page found", r.text);

    // 7. Empty path refused cleanly.
    r = try h.tool("take_heapsnapshot", "{\"pageId\":1,\"filePath\":\"   \"}");
    try testing.expect(r.is_error);

    // 8. Blocked by an open dialog, then succeeds once dismissed (an alert
    // firing after evaluate_script's wait window stays open).
    r = try h.tool("evaluate_script", "{\"pageId\":1,\"function\":\"() => { setTimeout(() => alert('hold'), 400); return 1; }\"}");
    try testing.expect(!r.is_error);
    var tries: u32 = 0;
    while (tries < 100) : (tries += 1) {
        try h.settle(50);
        const lp = try h.tool("list_pages", "{}");
        if (std.mem.startsWith(u8, lp.text, "# Open dialog")) break;
    }
    r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":{f}}}", .{std.json.fmt(direct_path, .{})}));
    try testing.expect(r.is_error);
    try testing.expectEqualStrings(
        "# Open dialog\nalert: hold.\nCall handle_dialog to handle it before continuing.\nError: A dialog is open (alert: hold).",
        r.text,
    );
    r = try h.tool("handle_dialog", "{\"pageId\":1,\"action\":\"accept\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("take_heapsnapshot", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"filePath\":{f}}}", .{std.json.fmt(direct_path, .{})}));
    try testing.expect(!r.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(a, "Heap snapshot saved to {s}", .{direct_path}), r.text);
}

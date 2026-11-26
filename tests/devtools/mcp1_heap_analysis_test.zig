//! Lane mcp1, batch 4b item 10a: pure-Zig V8 heap snapshot analysis engine and
//! the 8 core memory-debugging MCP tools (`get_heapsnapshot_summary`,
//! `get_heapsnapshot_details`, `get_heapsnapshot_class_nodes`,
//! `get_heapsnapshot_object_details`, `get_heapsnapshot_edges`,
//! `get_heapsnapshot_retainers`, `get_heapsnapshot_dominators`,
//! `close_heapsnapshot`) gated behind `--memoryDebugging`.

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const devtools = @import("devtools");
const browser_mod = @import("browser");
const replay = @import("cdpr_replay.zig");

const sample_snapshot = @embedFile("../../tools/mcp_diff/fixtures/sample.heapsnapshot");

fn callRpc(server: *devtools.mcp.McpServer, arena: std.mem.Allocator, method: []const u8, params: []const u8) !std.json.Parsed(std.json.Value) {
    const req = try std.fmt.allocPrint(arena, "{{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":{f},\"params\":{s}}}", .{ std.json.fmt(method, .{}), params });
    const raw = (try server.handle(arena, req)) orelse return error.NoResponse;
    return std.json.parseFromSlice(std.json.Value, arena, raw, .{});
}

fn callTool(server: *devtools.mcp.McpServer, arena: std.mem.Allocator, name: []const u8, args: []const u8) !struct { text: []const u8, is_error: bool } {
    const params = try std.fmt.allocPrint(arena, "{{\"name\":{f},\"arguments\":{s}}}", .{ std.json.fmt(name, .{}), args });
    const parsed = try callRpc(server, arena, "tools/call", params);
    const res = parsed.value.object.get("result") orelse return error.RpcError;
    const is_err = if (res.object.get("isError")) |v| v == .bool and v.bool else false;
    const text = res.object.get("content").?.array.items[0].object.get("text").?.string;
    return .{ .text = text, .is_error = is_err };
}

test "heap analysis tools are disabled without memory_debugging and enabled with memory_debugging" {
    var gpa = replay.LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const dt = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer dt.stop();

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // Default server: get_heapsnapshot_summary is disabled.
    const default_srv = try devtools.mcp.McpServer.createWith(allocator, dt, .{});
    defer default_srv.destroy();
    const disabled_resp = try callRpc(default_srv, arena, "tools/call", "{\"name\":\"get_heapsnapshot_summary\",\"arguments\":{\"filePath\":\"/tmp/a.heapsnapshot\"}}");
    const err_msg = disabled_resp.value.object.get("error").?.object.get("message").?.string;
    try testing.expect(std.mem.indexOf(u8, err_msg, "Tool get_heapsnapshot_summary disabled") != null);

    // memory_debugging = true: all 8 Item 10a tools appear in tools/list.
    const mem_srv = try devtools.mcp.McpServer.createWith(allocator, dt, .{ .memory_debugging = true });
    defer mem_srv.destroy();
    const list_resp = try callRpc(mem_srv, arena, "tools/list", "{}");
    const tools_arr = list_resp.value.object.get("result").?.object.get("tools").?.array.items;
    const expected = [_][]const u8{
        "get_heapsnapshot_summary",
        "get_heapsnapshot_details",
        "get_heapsnapshot_class_nodes",
        "get_heapsnapshot_object_details",
        "get_heapsnapshot_edges",
        "get_heapsnapshot_retainers",
        "get_heapsnapshot_dominators",
        "close_heapsnapshot",
    };
    for (expected) |want| {
        var found = false;
        for (tools_arr) |t| {
            if (std.mem.eql(u8, t.object.get("name").?.string, want)) found = true;
        }
        try testing.expect(found);
    }
}

test "heap snapshot analysis tools: summary, details, class nodes, object details, edges, retainers, dominators, close" {
    var gpa = replay.LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "sample.heapsnapshot", .data = sample_snapshot });
    const dir_path = try tmp.dir.realPathFileAlloc(testing.io, ".", allocator);
    defer allocator.free(dir_path);
    const snap_path = try std.fmt.allocPrint(allocator, "{s}/sample.heapsnapshot", .{dir_path});
    defer allocator.free(snap_path);

    var host = try browser_mod.BrowserHost.start(allocator, .{});
    defer host.stop();
    const dt = try devtools.Server.start(allocator, .{ .port = 0, .default_host = host });
    defer dt.stop();

    const roots = [_][]const u8{dir_path};
    const srv = try devtools.mcp.McpServer.createWith(allocator, dt, .{
        .filesystem_roots = &roots,
        .memory_debugging = true,
    });
    defer srv.destroy();

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // 1. Summary: stats, static data, native contexts, retained by context summary.
    const summary = try callTool(srv, arena, "get_heapsnapshot_summary", try std.fmt.allocPrint(arena, "{{\"filePath\":{f}}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!summary.is_error);
    try testing.expect(std.mem.indexOf(u8, summary.text, "## Heap Snapshot Data") != null);
    try testing.expect(std.mem.indexOf(u8, summary.text, "\"nodeCount\": 23") != null);
    try testing.expect(std.mem.indexOf(u8, summary.text, "\"typedArrays\": 2048") != null);
    try testing.expect(std.mem.indexOf(u8, summary.text, "### Native Contexts") != null);
    try testing.expect(std.mem.indexOf(u8, summary.text, "system / NativeContext / http://example.test") != null);
    try testing.expect(std.mem.indexOf(u8, summary.text, "### Retained by Context Summary") != null);
    try testing.expect(std.mem.indexOf(u8, summary.text, "Context count: 1") != null);

    // 2. Details (all objects + detached DOM filter).
    const details = try callTool(srv, arena, "get_heapsnapshot_details", try std.fmt.allocPrint(arena, "{{\"filePath\":{f}}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!details.is_error);
    try testing.expect(std.mem.indexOf(u8, details.text, "id,className,count,selfSize,retainedSize") != null);
    try testing.expect(std.mem.indexOf(u8, details.text, ",LeakyWidget,2,") != null);
    try testing.expect(std.mem.indexOf(u8, details.text, ",Detached HTMLSpanElement,1,") != null);
    try testing.expect(std.mem.indexOf(u8, details.text, ",Detached Text,1,") != null);

    const detached_only = try callTool(srv, arena, "get_heapsnapshot_details", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"filterName\":\"objectsRetainedByDetachedDomNodes\"}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!detached_only.is_error);
    try testing.expect(std.mem.indexOf(u8, detached_only.text, "Detached HTMLSpanElement") != null);
    try testing.expect(std.mem.indexOf(u8, detached_only.text, "LeakyWidget") == null);

    // 3. Find LeakyWidget's class ID from details CSV and fetch class nodes.
    var widget_class_id: ?u32 = null;
    var lines = std.mem.splitScalar(u8, details.text, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, ",LeakyWidget,")) |comma| {
            widget_class_id = std.fmt.parseInt(u32, line[0..comma], 10) catch null;
        }
    }
    try testing.expect(widget_class_id != null);
    const class_nodes = try callTool(srv, arena, "get_heapsnapshot_class_nodes", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"id\":{d}}}", .{ std.json.fmt(snap_path, .{}), widget_class_id.? }));
    try testing.expect(!class_nodes.is_error);
    try testing.expect(std.mem.indexOf(u8, class_nodes.text, "nodeId,nodeName,type,distance,selfSize,retainedSize") != null);
    try testing.expect(std.mem.indexOf(u8, class_nodes.text, "13,LeakyWidget,object,") != null);
    try testing.expect(std.mem.indexOf(u8, class_nodes.text, "15,LeakyWidget,object,") != null);

    // 4. Object details for Detached HTMLSpanElement (@25) and cons string (@33) and plain object (@31).
    const span_info = try callTool(srv, arena, "get_heapsnapshot_object_details", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":25}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!span_info.is_error);
    try testing.expect(std.mem.indexOf(u8, span_info.text, "id: @25\nname: Detached HTMLSpanElement\ntype: native\ndetachedness: detached\n") != null);

    const cons_info = try callTool(srv, arena, "get_heapsnapshot_object_details", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":33}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!cons_info.is_error);
    try testing.expect(std.mem.indexOf(u8, cons_info.text, "name: hello world\n") != null);

    const plain_info = try callTool(srv, arena, "get_heapsnapshot_object_details", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":31}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!plain_info.is_error);
    try testing.expect(std.mem.indexOf(u8, plain_info.text, "name: {a, b}\n") != null);

    // 5. Outgoing edges of LeakyWidget #1 (@13): default excludes primitive @29 (number "42").
    const edges_default = try callTool(srv, arena, "get_heapsnapshot_edges", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":13}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!edges_default.is_error);
    try testing.expect(std.mem.indexOf(u8, edges_default.text, "detachedNode,property,25,Detached HTMLSpanElement,") != null);
    try testing.expect(std.mem.indexOf(u8, edges_default.text, "count,property,29,") == null);

    const edges_all = try callTool(srv, arena, "get_heapsnapshot_edges", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":13,\"excludePrimitives\":false,\"sortBy\":\"name\"}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!edges_all.is_error);
    try testing.expect(std.mem.indexOf(u8, edges_all.text, "count,property,29,42,") != null);

    // 6. Retainers of Detached HTMLSpanElement (@25): retained by LeakyWidget (@13) via detachedNode.
    const retainers = try callTool(srv, arena, "get_heapsnapshot_retainers", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":25}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!retainers.is_error);
    try testing.expect(std.mem.indexOf(u8, retainers.text, "detachedNode,property,13,LeakyWidget,") != null);

    // 7. Dominators of Detached Text (@39): @39 -> @25 (Detached HTMLSpanElement) -> @13 (LeakyWidget) -> @5 (Window) -> @1 (root).
    const doms = try callTool(srv, arena, "get_heapsnapshot_dominators", try std.fmt.allocPrint(arena, "{{\"filePath\":{f},\"nodeId\":39}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!doms.is_error);
    try testing.expect(std.mem.indexOf(u8, doms.text, "### Dominator Chain\nnodeId,nodeName,selfSize,retainedSize\n39,Detached Text,") != null);
    try testing.expect(std.mem.indexOf(u8, doms.text, "\n25,Detached HTMLSpanElement,") != null);
    try testing.expect(std.mem.indexOf(u8, doms.text, "\n13,LeakyWidget,") != null);
    try testing.expect(std.mem.indexOf(u8, doms.text, "\n5,Window,") != null);

    // 8. Close snapshot, and closing again fails with Chrome's message.
    const closed1 = try callTool(srv, arena, "close_heapsnapshot", try std.fmt.allocPrint(arena, "{{\"filePath\":{f}}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(!closed1.is_error);
    try testing.expectEqualStrings(try std.fmt.allocPrint(arena, "Closed heap snapshot: {s}", .{snap_path}), closed1.text);

    const closed2 = try callTool(srv, arena, "close_heapsnapshot", try std.fmt.allocPrint(arena, "{{\"filePath\":{f}}}", .{std.json.fmt(snap_path, .{})}));
    try testing.expect(closed2.is_error);
    try testing.expect(std.mem.indexOf(u8, closed2.text, "was not loaded.") != null);

    // Invalid extension refusal.
    const bad_ext = try callTool(srv, arena, "get_heapsnapshot_summary", try std.fmt.allocPrint(arena, "{{\"filePath\":\"{s}/bad.txt\"}}", .{dir_path}));
    try testing.expect(bad_ext.is_error);
    try testing.expect(std.mem.indexOf(u8, bad_ext.text, "must have a .heapsnapshot or .heaptimeline extension.") != null);
}

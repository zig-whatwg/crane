//! Lane mcp3, batch B (audit report C, M2): chrome-devtools-mcp v1.13.0's
//! server flags that change what the tools offer and do
//! (src/config/mcp-options.ts), each as the reference applies it:
//! - --no-javascript-evaluation: evaluate_script and set_logpoints are
//!   conditioned on it (src/tools/script.ts, logpoints.ts `conditions:
//!   ['javascriptEvaluation']`), navigate_page loses initScript
//!   (src/tools/pages.ts), and validateUrl refuses javascript:, data: and
//!   vbscript: (src/utils/url.ts);
//! - --no-file-navigations: validateUrl refuses file:, view-source: of one
//!   included;
//! - --no-page-id-routing: page tools take no pageId and act on the selected
//!   page (src/tools/ToolDefinition.ts definePageTool, src/ToolHandler.ts
//!   routedPageId);
//! - --maxNavigationSaved: the collectors' retention and the text of the two
//!   includePreserved* parameters (src/tools/console.ts, network.ts);
//! - --redactNetworkHeaders: get_network_request's header values not on
//!   devtools-frontend's allowlist read <redacted>
//!   (src/formatters/NetworkFormatter.ts, devtools-frontend
//!   NetworkRequestFormatter.sanitizeHeaders).

const std = @import("std");
const testing = std.testing;
const Harness = @import("mcp1_harness.zig").Harness;
const Site = @import("cdpr_replay.zig").Site;

fn hasProperty(definition: std.json.Value, name: []const u8) bool {
    const schema = definition.object.get("inputSchema").?.object;
    return schema.get("properties").?.object.get(name) != null;
}

fn requires(definition: std.json.Value, name: []const u8) bool {
    const schema = definition.object.get("inputSchema").?.object;
    const required = schema.get("required") orelse return false;
    for (required.array.items) |r| if (std.mem.eql(u8, r.string, name)) return true;
    return false;
}

test "--no-javascript-evaluation: evaluate_script and set_logpoints disabled, no initScript, javascript:/data:/vbscript: navigations refused" {
    var h: Harness = .{ .options = .{ .javascript_evaluation = false } };
    try h.start();
    defer h.stop();
    try testing.expect(try h.definition("evaluate_script") == null);
    try testing.expect(try h.definition("set_logpoints") == null);
    try testing.expect(!hasProperty((try h.definition("navigate_page")).?, "initScript"));
    try testing.expectEqualStrings("Tool evaluate_script disabled", (try h.callError("evaluate_script", "{\"pageId\":1,\"function\":\"() => 1\"}")).?);
    try testing.expectEqualStrings("Tool set_logpoints disabled", (try h.callError("set_logpoints", "{\"pageId\":1,\"logpoints\":[]}")).?);

    for ([_][]const u8{ "javascript", "data", "vbscript" }) |scheme| {
        const a = h.arena.allocator();
        const url = if (std.mem.eql(u8, scheme, "data")) "data:text/html,hi" else try std.fmt.allocPrint(a, "{s}:1", .{scheme});
        const r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}\"}}", .{url}));
        const expected = try std.fmt.allocPrint(a, "Navigating to {s}: URLs is not allowed when JavaScript evaluation is disabled.", .{scheme});
        if (std.mem.indexOf(u8, r.text, expected) == null) {
            std.log.err("navigate_page {s}: {s}", .{ url, r.text });
            return error.TestUnexpectedResult;
        }
    }
    const r = try h.tool("new_page", "{\"url\":\"data:text/html,hi\"}");
    try testing.expect(std.mem.indexOf(u8, r.text, "Navigating to data: URLs is not allowed when JavaScript evaluation is disabled.") != null);

    // On (the default), the same tools are there.
    var on: Harness = .{};
    try on.start();
    defer on.stop();
    try testing.expect(try on.definition("evaluate_script") != null);
    try testing.expect(hasProperty((try on.definition("navigate_page")).?, "initScript"));
}

test "--no-file-navigations: file: and view-source:file: navigations refused" {
    var h: Harness = .{ .options = .{ .file_navigations = false } };
    try h.start();
    defer h.stop();
    for ([_][]const u8{ "file:///tmp/", "view-source:file:///tmp/" }) |url| {
        const r = try h.tool("navigate_page", try std.fmt.allocPrint(h.arena.allocator(), "{{\"pageId\":1,\"url\":\"{s}\"}}", .{url}));
        if (std.mem.indexOf(u8, r.text, "Navigating to file: URLs is not allowed when --file-navigations is disabled.") == null) {
            std.log.err("navigate_page {s}: {s}", .{ url, r.text });
            return error.TestUnexpectedResult;
        }
    }
}

test "--no-page-id-routing: page tools take no pageId and act on the selected page" {
    var h: Harness = .{ .options = .{ .page_id_routing = false } };
    try h.start();
    defer h.stop();
    for ([_][]const u8{ "click", "take_snapshot", "list_console_messages", "navigate_page", "evaluate_script" }) |name| {
        const d = (try h.definition(name)).?;
        try testing.expect(!hasProperty(d, "pageId"));
        try testing.expect(!requires(d, "pageId"));
    }
    var r = try h.tool("navigate_page", "{\"url\":\"data:text/html,<script>console.log('routed')</script>\"}");
    try testing.expect(!r.is_error);
    r = try h.tool("list_console_messages", "{}");
    try testing.expect(std.mem.indexOf(u8, r.text, "[log] routed") != null);
    r = try h.tool("evaluate_script", "{\"function\":\"() => 6 * 7\"}");
    try testing.expect(std.mem.indexOf(u8, r.text, "42") != null);
    // pageId is not a parameter any more: the strict schema refuses it.
    r = try h.tool("list_console_messages", "{\"pageId\":1}");
    try testing.expect(r.is_error);
}

test "--maxNavigationSaved=5: the preserved parameters say 5, and five navigations are kept" {
    var h: Harness = .{ .options = .{ .max_navigation_saved = 5 } };
    try h.start();
    defer h.stop();
    const console_def = (try h.definition("list_console_messages")).?;
    const network_def = (try h.definition("list_network_requests")).?;
    const preserved_messages = console_def.object.get("inputSchema").?.object.get("properties").?.object.get("includePreservedMessages").?.object.get("description").?.string;
    const preserved_requests = network_def.object.get("inputSchema").?.object.get("properties").?.object.get("includePreservedRequests").?.object.get("description").?.string;
    try testing.expectEqualStrings("Set to true to return the preserved messages over the last 5 navigations.", preserved_messages);
    try testing.expectEqualStrings("Set to true to return the preserved requests over the last 5 navigations.", preserved_requests);

    const a = h.arena.allocator();
    for (0..7) |i| {
        const r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"data:text/html,<script>console.log('nav{d}')</script>\"}}", .{i}));
        try testing.expect(!r.is_error);
    }
    const r = try h.tool("list_console_messages", "{\"pageId\":1,\"includePreservedMessages\":true}");
    for (2..7) |i| try testing.expect(std.mem.indexOf(u8, r.text, try std.fmt.allocPrint(a, "[log] nav{d} ", .{i})) != null);
    for (0..2) |i| try testing.expect(std.mem.indexOf(u8, r.text, try std.fmt.allocPrint(a, "[log] nav{d} ", .{i})) == null);
}

test "--redactNetworkHeaders: header values off devtools-frontend's allowlist read <redacted>" {
    var h: Harness = .{ .options = .{ .redact_network_headers = true } };
    try h.start();
    defer h.stop();
    const site = try Site.start(h.gpa.allocator());
    defer site.stop();
    const a = h.arena.allocator();
    var buffer: [128]u8 = undefined;
    const root = try a.dupe(u8, try site.url(&buffer, "/"));
    var r = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":\"{s}\"}}", .{root}));
    try testing.expect(!r.is_error);
    r = try h.tool("get_network_request", "{\"pageId\":1,\"reqid\":1}");
    try testing.expect(!r.is_error);
    // cache-control, connection and content-type are on the allowlist;
    // content-length is not.
    const expected = "\n### Response Headers\n- cache-control:no-store\n- connection:close\n- content-length:<redacted>\n- content-type:text/html\n";
    if (std.mem.indexOf(u8, r.text, expected) == null) {
        std.log.err("got: {s}", .{r.text});
        return error.TestUnexpectedResult;
    }
}

test "--no-source-maps: a console stack trace keeps the generated locations (McpPage.syncSourceMaps turns DevTools' source maps off)" {
    var h: Harness = .{ .options = .{ .source_maps = false } };
    try h.start();
    defer h.stop();
    const a = h.arena.allocator();
    // The page of mcp_tools_complete_test's source-mapped stack trace: its
    // map sends generated line 2 to src/app.ts:42:5.
    const map_json =
        \\{"version":3,"sources":["vendor.js","src/app.ts"],"ignoreList":[0],"names":[],"mappings":"AASA;ACgCI;AA0DJ"}
    ;
    const b64 = try a.alloc(u8, std.base64.standard.Encoder.calcSize(map_json.len));
    _ = std.base64.standard.Encoder.encode(b64, map_json);
    const js = try std.fmt.allocPrint(a, "function lib(){{ console.error('mapped-err'); }}%0Afunction app(){{ lib(); }}%0Aapp();%0A//%23 sourceURL=http://example.test/bundle.js%0A//%23 sourceMappingURL=data:application/json;base64,{s}%0A", .{b64});
    const nav_url = try std.fmt.allocPrint(a, "data:text/html,<script>{s}</script>", .{js});
    const nav = try h.tool("navigate_page", try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":{f}}}", .{std.json.fmt(nav_url, .{})}));
    try testing.expect(!nav.is_error);
    const detail = try h.tool("get_console_message", "{\"pageId\":1,\"msgid\":1}");
    try testing.expect(!detail.is_error);
    try testing.expect(std.mem.indexOf(u8, detail.text, "app.ts") == null);
    try testing.expect(std.mem.indexOf(u8, detail.text, "bundle.js:2:") != null);
}

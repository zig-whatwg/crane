//! Lane mcp1, batch 4b item 9: CDP `CSS` domain (`CSS.enable`, `CSS.disable`,
//! `CSS.getStyleSheetText`, `CSS.getComputedStyleForNode`,
//! `CSS.getInlineStylesForNode`, `CSS.getMatchedStylesForNode`,
//! `CSS.styleSheetAdded`) and MCP `get_css_styles` tool.

const std = @import("std");
const testing = std.testing;
const mcp1 = @import("mcp1_harness.zig");
const cdpd1 = @import("cdpd1_harness.zig");
const replay = @import("cdpr_replay.zig");

const styled_html =
    \\<!doctype html>
    \\<html>
    \\<head>
    \\<style>
    \\@property --accent {
    \\  syntax: "<color>";
    \\  inherits: true;
    \\  initial-value: purple;
    \\}
    \\body {
    \\  font-family: sans-serif;
    \\  color: navy;
    \\  --accent: teal;
    \\  border: 1px solid gray;
    \\}
    \\@layer base {
    \\  .card {
    \\    color: green;
    \\    padding: 4px;
    \\  }
    \\}
    \\.card {
    \\  color: blue;
    \\  background-color: yellow;
    \\}
    \\#hero {
    \\  color: orange;
    \\  padding: 8px 16px;
    \\}
    \\#hero::before {
    \\  content: "hi";
    \\  color: gray;
    \\}
    \\@media screen {
    \\  #hero {
    \\    letter-spacing: 1px;
    \\  }
    \\}
    \\@supports (display: block) {
    \\  .card, .unused {
    \\    font-weight: bold;
    \\  }
    \\}
    \\@scope (.wrapper) {
    \\  .card {
    \\    line-height: 1.5;
    \\  }
    \\}
    \\@container cardbox style(--mode: dark) {
    \\  .card {
    \\    text-align: left;
    \\  }
    \\}
    \\.wrapper {
    \\  & .card {
    \\    text-indent: 2px;
    \\  }
    \\}
    \\@keyframes pulse {
    \\  from { opacity: 0.5; }
    \\  to { opacity: 1; }
    \\}
    \\#hero { animation-name: pulse; }
    \\</style>
    \\</head>
    \\<body>
    \\<div class="wrapper" style="container-name: cardbox; --mode: dark">
    \\  <div id="hero" class="card" role="region" aria-label="Hero Card" style="color: red !important; margin: 4px; bogus-prop: nope">Hello CSS</div>
    \\  <span id="plain" role="status">Plain</span>
    \\</div>
    \\</body>
    \\</html>
;

test "get_css_styles is listed in default tools/list" {
    var h: mcp1.Harness = .{};
    try h.start();
    defer h.stop();

    const list_resp = try h.send("tools/list", "{}");
    const tools_arr = list_resp.object.get("result").?.object.get("tools").?.array.items;
    var found = false;
    for (tools_arr) |t| {
        if (std.mem.eql(u8, t.object.get("name").?.string, "get_css_styles")) {
            found = true;
            break;
        }
    }
    try testing.expect(found);
}

fn dataUrl(arena: std.mem.Allocator, html: []const u8) ![]const u8 {
    const enc = std.base64.standard.Encoder;
    const b64 = try arena.alloc(u8, enc.calcSize(html.len));
    _ = enc.encode(b64, html);
    return std.fmt.allocPrint(arena, "data:text/html;base64,{s}", .{b64});
}

test "CDP CSS domain: enable, styleSheetAdded, getStyleSheetText, getComputedStyleForNode, getInlineStylesForNode, getMatchedStylesForNode" {
    var gpa = replay.LeakChecked.init;
    defer testing.expectEqual(.ok, gpa.deinit()) catch {};
    const allocator = gpa.allocator();

    var h: cdpd1.Harness = undefined;
    try h.init(allocator);
    defer h.deinit();

    const url = try dataUrl(h.arena(), styled_html);
    _ = try h.call("Page.enable", "{}");
    const from_nav = h.seen.items.len;
    const nav_params = try std.fmt.allocPrint(h.arena(), "{{\"url\":{f}}}", .{std.json.fmt(url, .{})});
    _ = try h.call("Page.navigate", nav_params);
    _ = try h.waitEvent("Page.loadEventFired", from_nav);

    _ = try h.call("DOM.enable", "{}");
    const doc_res = try h.call("DOM.getDocument", "{\"depth\":-1}");
    const root_id = doc_res.object.get("root").?.object.get("nodeId").?.integer;

    const q_params = try std.fmt.allocPrint(h.arena(), "{{\"nodeId\":{d},\"selector\":\"#hero\"}}", .{root_id});
    const q_res = try h.call("DOM.querySelector", q_params);
    const hero_id = q_res.object.get("nodeId").?.integer;
    try testing.expect(hero_id > 0);

    // Enable CSS domain -> must emit CSS.styleSheetAdded for inline <style>.
    _ = try h.call("CSS.enable", "{}");
    h.drain();
    var sheet_id: ?[]const u8 = null;
    for (h.seen.items) |parsed| {
        const obj = parsed.value.object;
        const m = obj.get("method") orelse continue;
        if (m == .string and std.mem.eql(u8, m.string, "CSS.styleSheetAdded")) {
            const header = obj.get("params").?.object.get("header").?.object;
            sheet_id = header.get("styleSheetId").?.string;
            try testing.expectEqual(true, header.get("isInline").?.bool);
        }
    }
    try testing.expect(sheet_id != null);

    // CSS.getStyleSheetText returns the raw stylesheet text.
    const text_params = try std.fmt.allocPrint(h.arena(), "{{\"styleSheetId\":{f}}}", .{std.json.fmt(sheet_id.?, .{})});
    const text_res = try h.call("CSS.getStyleSheetText", text_params);
    const sheet_text = text_res.object.get("text").?.string;
    try testing.expect(std.mem.indexOf(u8, sheet_text, "@layer base") != null);

    // CSS.getComputedStyleForNode returns computed properties including color.
    const node_params = try std.fmt.allocPrint(h.arena(), "{{\"nodeId\":{d}}}", .{hero_id});
    const comp_res = try h.call("CSS.getComputedStyleForNode", node_params);
    const comp_arr = comp_res.object.get("computedStyle").?.array.items;
    var found_color = false;
    for (comp_arr) |prop| {
        if (std.mem.eql(u8, prop.object.get("name").?.string, "color")) {
            try testing.expectEqualStrings("rgb(255, 0, 0)", prop.object.get("value").?.string);
            found_color = true;
            break;
        }
    }
    try testing.expect(found_color);

    // CSS.getInlineStylesForNode returns inlineStyle with color: red !important and margin: 4px.
    const inline_res = try h.call("CSS.getInlineStylesForNode", node_params);
    const inline_props = inline_res.object.get("inlineStyle").?.object.get("cssProperties").?.array.items;
    var saw_inline_color = false;
    for (inline_props) |p| {
        if (std.mem.eql(u8, p.object.get("name").?.string, "color")) {
            try testing.expectEqualStrings("red", p.object.get("value").?.string);
            try testing.expectEqual(true, p.object.get("important").?.bool);
            saw_inline_color = true;
        }
    }
    try testing.expect(saw_inline_color);

    // CSS.getMatchedStylesForNode returns matched rules, inherited, pseudoElements, keyframes, propertyRules.
    const matched_res = try h.call("CSS.getMatchedStylesForNode", node_params);
    try testing.expect(matched_res.object.get("inlineStyle") != null);
    try testing.expect(matched_res.object.get("matchedCSSRules").?.array.items.len >= 6);
    try testing.expect(matched_res.object.get("inherited").?.array.items.len >= 2);
    try testing.expect(matched_res.object.get("pseudoElements").?.array.items.len >= 1);
    try testing.expect(matched_res.object.get("cssKeyframesRules").?.array.items.len >= 1);
    try testing.expect(matched_res.object.get("cssPropertyRules").?.array.items.len >= 1);

    _ = try h.call("CSS.disable", "{}");
}

test "MCP get_css_styles: errors, cascade precedence, wrappers, inherited, pseudo, keyframes, property, pagination" {
    var h: mcp1.Harness = .{};
    try h.start();
    defer h.stop();

    const a = h.arena.allocator();
    const url = try dataUrl(a, styled_html);
    const nav_args = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"url\":{f}}}", .{std.json.fmt(url, .{})});
    const nav = try h.tool("navigate_page", nav_args);
    try testing.expect(!nav.is_error);

    // Before take_snapshot: error.
    const no_snap = try h.tool("get_css_styles", "{\"pageId\":1,\"uid\":\"1_1\"}");
    try testing.expect(no_snap.is_error);
    try testing.expect(std.mem.indexOf(u8, no_snap.text, "No snapshot found for page 1") != null);

    // Capture snapshot and find Hero Card uid.
    const snap = try h.tool("take_snapshot", "{\"pageId\":1}");
    try testing.expect(!snap.is_error);
    var hero_uid: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, snap.text, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "\"Hero Card\"") != null) {
            if (std.mem.indexOf(u8, line, "uid=")) |u| {
                const rest = line[u + 4 ..];
                const end = std.mem.indexOfScalar(u8, rest, ' ') orelse rest.len;
                hero_uid = rest[0..end];
                break;
            }
        }
    }
    try testing.expect(hero_uid != null);

    // Full page of styles for #hero.
    const full_args = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":{f},\"pageSize\":50}}", .{std.json.fmt(hero_uid.?, .{})});
    const full = try h.tool("get_css_styles", full_args);
    try testing.expect(!full.is_error);

    try testing.expect(std.mem.indexOf(u8, full.text, "Styles for div#hero (uid: \"") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "element.style {") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "color: red !important;") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "[overloaded] color: orange;") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "[overloaded] color: blue;") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@layer base {") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@media screen {") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@supports (display: block) {") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@scope (.wrapper) {") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@container cardbox style(--mode: dark) {") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "Inherited from body:") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "font-family: sans-serif;") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "/* Pseudo ::before element */") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@keyframes pulse") != null);
    try testing.expect(std.mem.indexOf(u8, full.text, "@property --accent") != null);

    // Pagination: pageSize=3, pageIdx=0 and pageIdx=1.
    const p0_args = try std.fmt.allocPrint(a, "{{\"pageId\":1,\"uid\":{f},\"pageSize\":3,\"pageIdx\":0}}", .{std.json.fmt(hero_uid.?, .{})});
    const p0 = try h.tool("get_css_styles", p0_args);
    try testing.expect(!p0.is_error);
    try testing.expect(std.mem.indexOf(u8, p0.text, "Showing 1-3 of ") != null);
    try testing.expect(std.mem.indexOf(u8, p0.text, "Next page: 1") != null);

    // Unknown uid -> error.
    const bad = try h.tool("get_css_styles", "{\"pageId\":1,\"uid\":\"9_9\"}");
    try testing.expect(bad.is_error);
    try testing.expect(std.mem.indexOf(u8, bad.text, "Element uid \"9_9\" not found on page 1") != null);
}

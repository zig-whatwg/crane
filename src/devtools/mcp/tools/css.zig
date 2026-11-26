//! `get_css_styles` - chrome-devtools-mcp's `src/tools/css.ts`
//! (chrome-devtools-mcp-v1.13.0, Copyright 2026 Google LLC, Apache-2.0;
//! THIRD_PARTY_NOTICES.md).
//!
//! Pure CDP client over `DOM.enable`, `DOM.getDocument`,
//! `DOM.pushNodesByBackendIdsToFrontend`, `DOM.getContainerForNode`,
//! `CSS.enable`, and `CSS.getMatchedStylesForNode`.

const std = @import("std");
const Allocator = std.mem.Allocator;
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const str = session_mod.str;
const Response = @import("../response.zig").Response;
const elements = @import("../elements.zig");
const console_tools = @import("console.zig");
const css_styles = @import("../css_styles.zig");

pub const list = [_]Tool{
    .{
        .name = "get_css_styles",
        .page_tool = true,
        .blocked_by_dialog = true,
        .run = getCssStyles,
    },
};

const DomNodeEntry = struct {
    obj: std.json.ObjectMap,
    parent_id: ?i64 = null,
};

fn getCssStyles(ctx: *Context, args: std.json.ObjectMap, page_opt: ?*Page, response: *Response) anyerror!void {
    const page = page_opt.?;
    const arena = ctx.arena;
    const uid = registry.stringArg(args, "uid") orelse return ctx.fail("Missing required parameter: uid", .{});

    const page_size: usize = if (registry.numberArg(args, "pageSize")) |n| blk: {
        if (n <= 0) return ctx.fail("pageSize must be positive.", .{});
        break :blk @intFromFloat(n);
    } else 10;
    const page_idx: i64 = if (registry.numberArg(args, "pageIdx")) |n| @intFromFloat(n) else 0;

    // 1. Validate snapshot & uid.
    const snap = page.text_snapshot orelse return ctx.fail("No snapshot found for page {d}. Use take_snapshot to capture one.", .{page.id});
    const target = snap.targets.get(uid) orelse return ctx.fail("Element uid \"{s}\" not found on page {d}.", .{ uid, page.id });
    const backend_node_id = target.backend_node_id;
    const loader_id = try arena.dupe(u8, target.loader_id);
    const frame_id = try arena.dupe(u8, target.frame_id);

    // Check that the frame still holds the same document.
    var frame_live = false;
    for (try elements.frames(ctx, page)) |f| {
        if (std.mem.eql(u8, f.id, frame_id) and std.mem.eql(u8, f.loader_id, loader_id)) {
            frame_live = true;
            break;
        }
    }
    if (!frame_live) {
        return ctx.fail("Element with uid \"{s}\" was detached or no longer exists on the page. Please take a new snapshot with take_snapshot.", .{uid});
    }

    // 2. Enable DOM + CSS so stylesheet headers arrive before getMatchedStylesForNode.
    {
        var r_dom = try ctx.session.client.call("DOM.enable", "{}", page.session_id, session_mod.command_timeout_ms);
        defer r_dom.deinit();
    }
    {
        var r_css = try ctx.session.client.call("CSS.enable", "{}", page.session_id, session_mod.command_timeout_ms);
        defer r_css.deinit();
        page.css_enabled = true;
    }

    // 3. Get the full DOM tree (binds nodeIds + gives parent links + attributes for simpleSelector).
    var doc_resp = try ctx.session.client.call("DOM.getDocument", "{\"depth\":-1,\"pierce\":true}", page.session_id, session_mod.command_timeout_ms);
    defer doc_resp.deinit();

    var node_map: std.AutoArrayHashMapUnmanaged(i64, DomNodeEntry) = .empty;
    var backend_to_node_id: std.AutoArrayHashMapUnmanaged(i64, i64) = .empty;
    if (doc_resp.result()) |res| {
        if (res.object.get("root")) |root_val| {
            try indexDomTree(arena, root_val, null, &node_map, &backend_to_node_id);
        }
    }

    // 4. Push backendNodeId to frontend to get its live nodeId.
    const push_params = try std.fmt.allocPrint(arena, "{{\"backendNodeIds\":[{d}]}}", .{backend_node_id});
    var push_resp = try ctx.session.client.call("DOM.pushNodesByBackendIdsToFrontend", push_params, page.session_id, session_mod.command_timeout_ms);
    defer push_resp.deinit();
    var target_node_id: i64 = 0;
    if (push_resp.result()) |res| {
        if (res.object.get("nodeIds")) |arr| if (arr == .array and arr.array.items.len > 0) {
            if (arr.array.items[0] == .integer) target_node_id = arr.array.items[0].integer;
        };
    }
    if (target_node_id == 0) {
        if (backend_to_node_id.get(backend_node_id)) |nid| {
            target_node_id = nid;
        }
    }
    if (target_node_id == 0) {
        return ctx.fail("Element with uid \"{s}\" was detached or no longer exists on the page. Please take a new snapshot with take_snapshot.", .{uid});
    }

    // Walk up from target_node_id to enclosing element if it is a text node.
    var element_id = target_node_id;
    while (node_map.get(element_id)) |entry| {
        const ntype = intOf(entry.obj.get("nodeType")) orelse 0;
        if (ntype == 1) break;
        element_id = entry.parent_id orelse {
            return ctx.fail("Element with uid \"{s}\" is not an element node and has no parent element.", .{uid});
        };
    }
    const target_entry = node_map.get(element_id) orelse {
        return ctx.fail("Element with uid \"{s}\" was detached or no longer exists on the page. Please take a new snapshot with take_snapshot.", .{uid});
    };
    if ((intOf(target_entry.obj.get("nodeType")) orelse 0) != 1) {
        return ctx.fail("Element with uid \"{s}\" is not an element node and has no parent element.", .{uid});
    }

    const target_selector = try css_styles.simpleSelector(arena, target_entry.obj);
    const target_tag = blk: {
        const ln = str(target_entry.obj.get("localName"));
        if (ln.len > 0) break :blk ln;
        break :blk try std.ascii.allocLowerString(arena, str(target_entry.obj.get("nodeName")));
    };
    const target_info: css_styles.NodeInfo = .{
        .selector = target_selector,
        .uid = uid,
    };

    // Build ancestor NodeInfo list (matching CSS.getMatchedStylesForNode.inherited order).
    var ancestors_list: std.ArrayList(css_styles.NodeInfo) = .empty;
    var cur_parent = target_entry.parent_id;
    while (cur_parent) |pid| {
        const pentry = node_map.get(pid) orelse break;
        const ptype = intOf(pentry.obj.get("nodeType")) orelse 0;
        if (ptype == 1) {
            const psel = try css_styles.simpleSelector(arena, pentry.obj);
            const p_backend = intOf(pentry.obj.get("backendNodeId"));
            const p_uid = if (p_backend) |bid| resolveUid(page, bid) else null;
            try ancestors_list.append(arena, .{
                .selector = psel,
                .uid = p_uid,
            });
        }
        cur_parent = pentry.parent_id;
    }

    // 5. Call CSS.getMatchedStylesForNode.
    const matched_params = try std.fmt.allocPrint(arena, "{{\"nodeId\":{d}}}", .{element_id});
    var matched_resp = try ctx.session.client.call("CSS.getMatchedStylesForNode", matched_params, page.session_id, session_mod.command_timeout_ms);
    defer matched_resp.deinit();
    if (matched_resp.errorMessage() != null) {
        return ctx.fail("Could not retrieve matched styles for element with uid \"{s}\".", .{uid});
    }
    const matched_val = matched_resp.result() orelse {
        return ctx.fail("Could not retrieve matched styles for element with uid \"{s}\".", .{uid});
    };

    // 6. Resolve @container queries via DOM.getContainerForNode.
    var container_details: std.ArrayList(css_styles.ContainerDetail) = .empty;
    try resolveContainerQueries(ctx, page, element_id, matched_val.object, &node_map, &container_details);

    // 7. Collect all CascadeRules, paginate, and format.
    const collect_ctx: css_styles.CollectContext = .{
        .arena = arena,
        .sheets = &page.css_sheets,
        .container_details = container_details.items,
        .target_node = target_info,
        .ancestor_nodes = ancestors_list.items,
        .target_tag = target_tag,
    };
    const all_rules = try css_styles.collectRules(&collect_ctx, matched_val.object);

    var header_lines: std.ArrayList([]const u8) = .empty;
    const shown = try console_tools.paginate(arena, all_rules.len, page_size, page_idx, &header_lines);
    for (header_lines.items) |hl| {
        try response.line("{s}", .{hl});
    }
    const body = try css_styles.formatToString(arena, target_info, all_rules[shown.start..shown.end]);
    try response.line("{s}", .{body});
}

fn indexDomTree(
    arena: Allocator,
    node_val: std.json.Value,
    parent_id: ?i64,
    node_map: *std.AutoArrayHashMapUnmanaged(i64, DomNodeEntry),
    backend_to_node_id: *std.AutoArrayHashMapUnmanaged(i64, i64),
) Allocator.Error!void {
    if (node_val != .object) return;
    const obj = node_val.object;
    const nid = intOf(obj.get("nodeId")) orelse 0;
    const bid = intOf(obj.get("backendNodeId")) orelse 0;
    if (nid != 0) {
        try node_map.put(arena, nid, .{ .obj = obj, .parent_id = parent_id });
        if (bid != 0) try backend_to_node_id.put(arena, bid, nid);
    }
    const next_parent: ?i64 = if (nid != 0) nid else parent_id;
    if (obj.get("children")) |ch| if (ch == .array) {
        for (ch.array.items) |child| try indexDomTree(arena, child, next_parent, node_map, backend_to_node_id);
    };
    if (obj.get("shadowRoots")) |sr| if (sr == .array) {
        for (sr.array.items) |root| try indexDomTree(arena, root, next_parent, node_map, backend_to_node_id);
    };
    if (obj.get("contentDocument")) |cd| {
        try indexDomTree(arena, cd, next_parent, node_map, backend_to_node_id);
    }
}

fn resolveContainerQueries(
    ctx: *Context,
    page: *Page,
    element_id: i64,
    matched_obj: std.json.ObjectMap,
    node_map: *const std.AutoArrayHashMapUnmanaged(i64, DomNodeEntry),
    out: *std.ArrayList(css_styles.ContainerDetail),
) !void {
    try resolveContainerQueriesInRuleMatches(ctx, page, element_id, matched_obj.get("matchedCSSRules"), node_map, out);
    if (matched_obj.get("inherited")) |inh| if (inh == .array) {
        for (inh.array.items) |entry| {
            if (entry != .object) continue;
            try resolveContainerQueriesInRuleMatches(ctx, page, element_id, entry.object.get("matchedCSSRules"), node_map, out);
        }
    };
    if (matched_obj.get("pseudoElements")) |pe| if (pe == .array) {
        for (pe.array.items) |entry| {
            if (entry != .object) continue;
            try resolveContainerQueriesInRuleMatches(ctx, page, element_id, entry.object.get("matches"), node_map, out);
        }
    };
}

fn resolveContainerQueriesInRuleMatches(
    ctx: *Context,
    page: *Page,
    element_id: i64,
    matches_val: ?std.json.Value,
    node_map: *const std.AutoArrayHashMapUnmanaged(i64, DomNodeEntry),
    out: *std.ArrayList(css_styles.ContainerDetail),
) !void {
    const arr = matches_val orelse return;
    if (arr != .array) return;
    const arena = ctx.arena;
    for (arr.array.items) |rm| {
        if (rm != .object) continue;
        const rule = rm.object.get("rule") orelse continue;
        if (rule != .object) continue;
        const cqs = rule.object.get("containerQueries") orelse continue;
        if (cqs != .array) continue;
        for (cqs.array.items) |*cq_val| {
            if (cq_val.* != .object) continue;
            const cq = cq_val.object;
            var params_buf: std.Io.Writer.Allocating = .init(arena);
            const w = &params_buf.writer;
            try w.print("{{\"nodeId\":{d}", .{element_id});
            if (cq.get("name")) |n| if (n == .string and n.string.len > 0) {
                try w.print(",\"containerName\":{f}", .{std.json.fmt(n.string, .{})});
            };
            if (cq.get("physicalAxes")) |a| if (a == .string) {
                try w.print(",\"physicalAxes\":{f}", .{std.json.fmt(a.string, .{})});
            };
            if (cq.get("logicalAxes")) |a| if (a == .string) {
                try w.print(",\"logicalAxes\":{f}", .{std.json.fmt(a.string, .{})});
            };
            if (cq.get("queriesScrollState")) |b| if (b == .bool and b.bool) {
                try w.writeAll(",\"queriesScrollState\":true");
            };
            if (cq.get("queriesAnchored")) |b| if (b == .bool and b.bool) {
                try w.writeAll(",\"queriesAnchored\":true");
            };
            try w.writeAll("}");

            var r = ctx.session.client.call("DOM.getContainerForNode", params_buf.written(), page.session_id, session_mod.command_timeout_ms) catch continue;
            defer r.deinit();
            const res = r.result() orelse continue;
            const cid = intOf(res.object.get("nodeId")) orelse continue;
            if (cid == 0) continue;
            if (node_map.get(cid)) |centry| {
                const csel = try css_styles.simpleSelector(arena, centry.obj);
                const cbid = intOf(centry.obj.get("backendNodeId"));
                const cuid = if (cbid) |bid| resolveUid(page, bid) else null;
                try out.append(arena, .{
                    .query_ptr = @intFromPtr(cq_val),
                    .container = .{ .selector = csel, .uid = cuid },
                });
            }
        }
    }
}

fn resolveUid(page: *const Page, backend_node_id: i64) ?[]const u8 {
    const snap = page.text_snapshot orelse return null;
    var it = snap.targets.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.backend_node_id == backend_node_id) {
            return entry.key_ptr.*;
        }
    }
    return null;
}

fn intOf(val: ?std.json.Value) ?i64 {
    const v = val orelse return null;
    return switch (v) {
        .integer => v.integer,
        .float => @intFromFloat(v.float),
        else => null,
    };
}

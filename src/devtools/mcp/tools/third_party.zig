//! Third-party developer tools (`--categoryExperimentalThirdParty`,
//! chrome-devtools-mcp v1.13.0 `src/tools/thirdPartyDeveloper.ts`,
//! `src/McpPage.ts` `discoverThirdPartyDeveloperTools` /
//! `executeThirdPartyDeveloperTool`, `src/McpResponse.ts`; Copyright 2026
//! Google LLC, Apache-2.0; THIRD_PARTY_NOTICES.md):
//! `list_3p_developer_tools` and `execute_3p_developer_tool`.
//!
//! Uses Crane's CDP `DOMDebugger.getEventListeners`, `Runtime.evaluate`,
//! `Runtime.callFunctionOn`, `DOM.describeNode`, and `snapshot_tools.capture`.

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
const validate = @import("../validate.zig");
const snapshot_tools = @import("snapshot.zig");
const script_tools = @import("script.zig");

pub const list = [_]Tool{
    .{ .name = "execute_3p_developer_tool", .page_tool = true, .blocked_by_dialog = false, .category_experimental_third_party = true, .run = executeThirdPartyDeveloperTool },
    .{ .name = "list_3p_developer_tools", .page_tool = true, .blocked_by_dialog = false, .category_experimental_third_party = true, .run = listThirdPartyDeveloperTools },
};

const source_url_comment = "//# sourceURL=pptr:internal";

const DiscoveredTool = struct {
    name: []const u8,
    description: []const u8,
    input_schema: std.json.Value,
};

const DiscoveredGroup = struct {
    name: []const u8,
    description: ?[]const u8,
    tools: []const DiscoveredTool,
};

fn listThirdPartyDeveloperTools(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = args;
    const target = page.?;
    const groups = try discover(ctx, target);
    try response.line("## Third-party developer tools", .{});
    if (groups.len == 0) {
        try response.line("No third-party developer tools available.", .{});
        return;
    }
    for (groups) |group| {
        try response.line("{s}: {s}", .{ group.name, group.description orelse "undefined" });
        try response.line("Available tools:", .{});
        for (group.tools) |tool| {
            const schema_json = try std.json.Stringify.valueAlloc(ctx.arena, tool.input_schema, .{});
            try response.line("name=\"{s}\", description=\"{s}\", inputSchema={s}", .{ tool.name, tool.description, schema_json });
        }
    }
}

fn executeThirdPartyDeveloperTool(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const tool_name = registry.stringArg(args, "toolName") orelse return ctx.failPlain(
        "Input validation error: Invalid arguments for tool execute_3p_developer_tool: toolName: Invalid input: expected string, received undefined",
        .{},
    );

    // jsonObjectTransform: parse optional JSON-stringified object params.
    var params_val: std.json.Value = .{ .object = .empty };
    if (registry.stringArg(args, "params")) |raw_params| {
        const parsed = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, raw_params, .{}) catch {
            return ctx.failPlain("Input validation error: Invalid arguments for tool execute_3p_developer_tool: params: Invalid JSON", .{});
        };
        if (parsed != .object) {
            return ctx.failPlain("Input validation error: Invalid arguments for tool execute_3p_developer_tool: params: Expected a JSON object", .{});
        }
        params_val = parsed;
    }

    const groups = try discover(ctx, target);
    var found_tool: ?DiscoveredTool = null;
    outer: for (groups) |group| {
        for (group.tools) |t| {
            if (std.mem.eql(u8, t.name, tool_name)) {
                found_tool = t;
                break :outer;
            }
        }
    }
    const tool = found_tool orelse return ctx.fail("Tool {s} not found", .{tool_name});

    // Validate params against the tool's rewritten inputSchema.
    if (tool.input_schema == .object) {
        if (try validate.check(ctx.arena, tool_name, tool.input_schema.object, params_val)) |err_msg| {
            return ctx.fail("Invalid parameters for tool {s}: {s}", .{ tool_name, err_msg });
        }
    }

    // Resolve top-level `{ uid: "<string>" }` parameters to Element handles
    // in key iteration order (matching McpPage.executeThirdPartyDeveloperTool).
    var handles: std.ArrayList(elements.Element) = .empty;
    defer for (handles.items) |h| if (h.object_id) |id| elements.release(ctx, target, id);
    {
        var it = params_val.object.iterator();
        while (it.next()) |entry| {
            if (uidParam(entry.value_ptr.*)) |uid| {
                const el = try elements.byUid(ctx, target, uid);
                try handles.append(ctx.arena, el);
            }
        }
    }

    const context_id = try elements.mainWorld(ctx, target, target.mainFrameId());
    var call_args: std.Io.Writer.Allocating = .init(ctx.arena);
    try call_args.writer.print("{{\"value\":{f}}},{{\"value\":", .{std.json.fmt(tool_name, .{})});
    try std.json.Stringify.value(params_val, .{}, &call_args.writer);
    try call_args.writer.writeAll("}");
    for (handles.items) |h| {
        try call_args.writer.print(",{s}", .{h.argument});
    }

    const fn_decl = execute_tool_js ++ "\n" ++ source_url_comment ++ "\n";
    const call_params = try std.fmt.allocPrint(
        ctx.arena,
        "{{\"functionDeclaration\":{f},\"executionContextId\":{d},\"arguments\":[{s}],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}}",
        .{ std.json.fmt(fn_decl, .{}), context_id, call_args.written() },
    );
    var r = try ctx.session.client.call("Runtime.callFunctionOn", call_params, target.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |msg| return ctx.fail("Protocol error (Runtime.callFunctionOn): {s}", .{msg});
    const res = r.result() orelse return ctx.fail("Protocol error (Runtime.callFunctionOn): no result", .{});
    if (res.object.get("exceptionDetails")) |details| if (details == .object) {
        return ctx.fail("{s}", .{try script_tools.evaluationErrorMessage(ctx.arena, details.object)});
    };
    const remote = (res.object.get("result") orelse return ctx.fail("Protocol error (Runtime.callFunctionOn): no result", .{})).object;
    const raw_out = str(remote.get("value"));
    if (raw_out.len == 0) {
        try response.line("Tool returned no result.", .{});
        return;
    }
    const exec_out = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, raw_out, .{}) catch {
        try response.line("Tool returned no result.", .{});
        return;
    };
    if (exec_out != .object) {
        try response.line("Tool returned no result.", .{});
        return;
    }

    const stashed_count: usize = if (exec_out.object.get("stashed")) |sv| switch (sv) {
        .integer => |i| if (i > 0) @intCast(i) else 0,
        else => 0,
    } else 0;

    var uid_by_stashed: [][]const u8 = &.{};
    if (stashed_count > 0) {
        defer clearStashedElements(ctx, target, context_id);
        const backend_ids = try ctx.arena.alloc(?i64, stashed_count);
        for (0..stashed_count) |idx| {
            backend_ids[idx] = try stashedBackendNodeId(ctx, target, context_id, idx);
        }
        // Refresh the snapshot and attach it to the response (McpPage.ts).
        response.snapshot = try snapshot_tools.capture(ctx, target, false);
        uid_by_stashed = try ctx.arena.alloc([]const u8, stashed_count);
        for (backend_ids, 0..) |bid_opt, idx| {
            if (bid_opt) |bid| {
                if (resolveUidForBackendNodeId(target, bid)) |uid| {
                    uid_by_stashed[idx] = try ctx.arena.dupe(u8, uid);
                    continue;
                }
            }
            uid_by_stashed[idx] = try std.fmt.allocPrint(ctx.arena, "stashed-{d}", .{idx});
        }
    }

    const has_result = if (exec_out.object.get("hasResult")) |v| v == .bool and v.bool else false;
    if (!has_result) {
        try response.line("Tool returned no result.", .{});
        return;
    }
    const serialized = str(exec_out.object.get("result"));
    var parsed_result = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, serialized, .{}) catch {
        try response.line("{s}", .{serialized});
        return;
    };
    if (uid_by_stashed.len > 0) {
        parsed_result = try replaceStashedElements(ctx.arena, parsed_result, uid_by_stashed);
    }
    const pretty = try std.json.Stringify.valueAlloc(ctx.arena, parsed_result, .{ .whitespace = .indent_2 });
    try response.line("{s}", .{pretty});
}

/// Discover third-party developer tools via `DOMDebugger.getEventListeners` on
/// `window` for `devtoolstooldiscovery`, then dispatch `CustomEvent`.
fn discover(ctx: *Context, page: *Page) ![]const DiscoveredGroup {
    const context_id = try elements.mainWorld(ctx, page, page.mainFrameId());
    // 1. Obtain a RemoteObject handle to `window`.
    const win_params = try std.fmt.allocPrint(
        ctx.arena,
        "{{\"expression\":\"window\",\"contextId\":{d},\"returnByValue\":false}}",
        .{context_id},
    );
    var win_r = try ctx.session.client.call("Runtime.evaluate", win_params, page.session_id, session_mod.command_timeout_ms);
    defer win_r.deinit();
    if (win_r.errorMessage()) |msg| return ctx.fail("Protocol error (Runtime.evaluate): {s}", .{msg});
    const win_remote = (win_r.result() orelse return &.{}).object.get("result") orelse return &.{};
    if (win_remote != .object) return &.{};
    const win_obj_id = try ctx.arena.dupe(u8, str(win_remote.object.get("objectId")));
    if (win_obj_id.len == 0) return &.{};
    defer elements.release(ctx, page, win_obj_id);

    // 2. Check for a `devtoolstooldiscovery` listener via DOMDebugger.getEventListeners.
    const listener_params = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(win_obj_id, .{})});
    var lr = try ctx.session.client.call("DOMDebugger.getEventListeners", listener_params, page.session_id, session_mod.command_timeout_ms);
    defer lr.deinit();
    if (lr.errorMessage() != null) return &.{};
    const listeners_val = (lr.result() orelse return &.{}).object.get("listeners") orelse return &.{};
    if (listeners_val != .array) return &.{};
    var has_discovery = false;
    for (listeners_val.array.items) |item| {
        if (item == .object and std.mem.eql(u8, str(item.object.get("type")), "devtoolstooldiscovery")) {
            has_discovery = true;
            break;
        }
    }
    if (!has_discovery) return &.{};

    // 3. Dispatch `devtoolstooldiscovery` and collect validated tool groups.
    const expr = discover_js ++ "\n" ++ source_url_comment ++ "\n";
    const disc_params = try std.fmt.allocPrint(
        ctx.arena,
        "{{\"expression\":{f},\"contextId\":{d},\"returnByValue\":true,\"awaitPromise\":true}}",
        .{ std.json.fmt(expr, .{}), context_id },
    );
    var dr = try ctx.session.client.call("Runtime.evaluate", disc_params, page.session_id, session_mod.command_timeout_ms);
    defer dr.deinit();
    if (dr.errorMessage()) |msg| return ctx.fail("Protocol error (Runtime.evaluate): {s}", .{msg});
    const dres = dr.result() orelse return &.{};
    if (dres.object.get("exceptionDetails")) |details| if (details == .object) {
        return ctx.fail("{s}", .{try script_tools.evaluationErrorMessage(ctx.arena, details.object)});
    };
    const dremote = (dres.object.get("result") orelse return &.{}).object;
    const json_str = str(dremote.get("value"));
    if (json_str.len == 0) return &.{};

    const parsed = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, json_str, .{}) catch return &.{};
    if (parsed != .array) return &.{};

    var groups: std.ArrayList(DiscoveredGroup) = .empty;
    for (parsed.array.items) |g_val| {
        if (g_val != .object) continue;
        const g_name = str(g_val.object.get("name"));
        const g_desc: ?[]const u8 = if (g_val.object.get("description")) |d| (if (d == .string) d.string else null) else null;
        var tools_list: std.ArrayList(DiscoveredTool) = .empty;
        if (g_val.object.get("tools")) |tv| if (tv == .array) {
            for (tv.array.items) |t_val| {
                if (t_val != .object) continue;
                var schema = t_val.object.get("inputSchema") orelse std.json.Value{ .object = .empty };
                try replaceHtmlElementsWithUids(ctx.arena, &schema);
                try tools_list.append(ctx.arena, .{
                    .name = str(t_val.object.get("name")),
                    .description = str(t_val.object.get("description")),
                    .input_schema = schema,
                });
            }
        };
        try groups.append(ctx.arena, .{
            .name = g_name,
            .description = g_desc,
            .tools = tools_list.items,
        });
    }
    return groups.items;
}

/// `replaceHtmlElementsWithUids` (McpPage.ts): recursively rewrites any JSON
/// Schema node with `"x-mcp-type": "HTMLElement"` to `{ properties: { uid: { type: "string" } }, required: ["uid"] }`.
pub fn replaceHtmlElementsWithUids(arena: Allocator, schema: *std.json.Value) Allocator.Error!void {
    if (schema.* != .object) return;
    const obj = &schema.object;
    if (obj.get("x-mcp-type")) |t| {
        if (t == .string and std.mem.eql(u8, t.string, "HTMLElement")) {
            var uid_type: std.json.ObjectMap = .empty;
            try uid_type.put(arena, "type", .{ .string = "string" });
            var props: std.json.ObjectMap = .empty;
            try props.put(arena, "uid", .{ .object = uid_type });
            var req = std.json.Array.init(arena);
            try req.append(.{ .string = "uid" });
            try obj.put(arena, "properties", .{ .object = props });
            try obj.put(arena, "required", .{ .array = req });
            return;
        }
    }
    if (obj.getPtr("properties")) |pv| if (pv.* == .object) {
        var it = pv.object.iterator();
        while (it.next()) |entry| {
            try replaceHtmlElementsWithUids(arena, entry.value_ptr);
        }
    };
    if (obj.getPtr("items")) |iv| {
        if (iv.* == .array) {
            for (iv.array.items) |*item| try replaceHtmlElementsWithUids(arena, item);
        } else {
            try replaceHtmlElementsWithUids(arena, iv);
        }
    }
    for ([_][]const u8{ "anyOf", "oneOf", "allOf" }) |comb| {
        if (obj.getPtr(comb)) |cv| if (cv.* == .array) {
            for (cv.array.items) |*item| try replaceHtmlElementsWithUids(arena, item);
        };
    }
    if (obj.getPtr("additionalProperties")) |ap| {
        try replaceHtmlElementsWithUids(arena, ap);
    }
}

fn uidParam(val: std.json.Value) ?[]const u8 {
    if (val != .object or val.object.count() != 1) return null;
    const u = val.object.get("uid") orelse return null;
    return if (u == .string) u.string else null;
}

fn stashedBackendNodeId(ctx: *Context, page: *Page, context_id: i64, index: usize) !?i64 {
    const expr = try std.fmt.allocPrint(ctx.arena, "window.__dtmcp?.stashedElements?.[{d}]", .{index});
    const eval_params = try std.fmt.allocPrint(
        ctx.arena,
        "{{\"expression\":{f},\"contextId\":{d},\"returnByValue\":false}}",
        .{ std.json.fmt(expr, .{}), context_id },
    );
    var r = try ctx.session.client.call("Runtime.evaluate", eval_params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const res = r.result() orelse return null;
    const remote = res.object.get("result") orelse return null;
    if (remote != .object) return null;
    const obj_id = try ctx.arena.dupe(u8, str(remote.object.get("objectId")));
    if (obj_id.len == 0) return null;
    defer elements.release(ctx, page, obj_id);

    const desc_params = try std.fmt.allocPrint(ctx.arena, "{{\"objectId\":{f}}}", .{std.json.fmt(obj_id, .{})});
    var dr = try ctx.session.client.call("DOM.describeNode", desc_params, page.session_id, session_mod.command_timeout_ms);
    defer dr.deinit();
    const node = (dr.result() orelse return null).object.get("node") orelse return null;
    if (node != .object) return null;
    const bid = node.object.get("backendNodeId") orelse return null;
    return if (bid == .integer) bid.integer else null;
}

fn clearStashedElements(ctx: *Context, page: *Page, context_id: i64) void {
    const params = std.fmt.allocPrint(
        ctx.arena,
        "{{\"expression\":\"if (window.__dtmcp) window.__dtmcp.stashedElements = undefined;\",\"contextId\":{d}}}",
        .{context_id},
    ) catch return;
    if (ctx.session.client.call("Runtime.evaluate", params, page.session_id, session_mod.command_timeout_ms)) |r| {
        var owned = r;
        owned.deinit();
    } else |_| {}
}

fn resolveUidForBackendNodeId(page: *const Page, backend_node_id: i64) ?[]const u8 {
    const snap = page.text_snapshot orelse return null;
    var it = snap.targets.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.backend_node_id == backend_node_id) return entry.key_ptr.*;
    }
    return null;
}

fn replaceStashedElements(arena: Allocator, node: std.json.Value, uids: []const []const u8) Allocator.Error!std.json.Value {
    switch (node) {
        .array => |arr| {
            var out = std.json.Array.init(arena);
            for (arr.items) |item| {
                try out.append(try replaceStashedElements(arena, item, uids));
            }
            return .{ .array = out };
        },
        .object => |obj| {
            if (obj.count() == 1) {
                if (obj.get("stashedId")) |sv| if (sv == .string and std.mem.startsWith(u8, sv.string, "stashed-")) {
                    const idx = std.fmt.parseInt(usize, sv.string["stashed-".len..], 10) catch null;
                    if (idx) |i| if (i < uids.len) {
                        var replacement: std.json.ObjectMap = .empty;
                        try replacement.put(arena, "uid", .{ .string = uids[i] });
                        return .{ .object = replacement };
                    };
                };
            }
            var out: std.json.ObjectMap = .empty;
            var it = obj.iterator();
            while (it.next()) |entry| {
                try out.put(arena, entry.key_ptr.*, try replaceStashedElements(arena, entry.value_ptr.*, uids));
            }
            return .{ .object = out };
        },
        else => return node,
    }
}

const discover_js =
    \\(() => {
    \\  if (window.__dtmcp) {
    \\    window.__dtmcp.toolGroups = [];
    \\  }
    \\  return new Promise(resolve => {
    \\    const event = new CustomEvent('devtoolstooldiscovery');
    \\    const groups = [];
    \\    event.respondWith = toolGroup => {
    \\      if (!window.__dtmcp) window.__dtmcp = {};
    \\      if (!window.__dtmcp.toolGroups) window.__dtmcp.toolGroups = [];
    \\      if (typeof toolGroup.name !== 'string' ||
    \\          (toolGroup.description && typeof toolGroup.description !== 'string') ||
    \\          !Array.isArray(toolGroup.tools)) {
    \\        console.error('Invalid toolGroup:', toolGroup);
    \\        return;
    \\      }
    \\      for (const tool of toolGroup.tools) {
    \\        if (typeof tool.name !== 'string' ||
    \\            typeof tool.description !== 'string' ||
    \\            typeof tool.inputSchema !== 'object' ||
    \\            typeof tool.execute !== 'function') {
    \\          console.error('Invalid tool:', tool);
    \\          return;
    \\        }
    \\      }
    \\      window.__dtmcp.toolGroups.push(toolGroup);
    \\      if (!window.__dtmcp.executeTool) {
    \\        window.__dtmcp.executeTool = async (toolName, args) => {
    \\          if (!window.__dtmcp?.toolGroups || window.__dtmcp.toolGroups.length === 0) {
    \\            throw new Error('No tools found on the page');
    \\          }
    \\          for (const group of window.__dtmcp.toolGroups) {
    \\            const tool = group.tools?.find(t => t.name === toolName);
    \\            if (tool) return await tool.execute(args);
    \\          }
    \\          throw new Error(`Tool ${toolName} not found`);
    \\        };
    \\      }
    \\      groups.push({
    \\        name: toolGroup.name,
    \\        description: toolGroup.description,
    \\        tools: toolGroup.tools.map(t => ({
    \\          name: t.name,
    \\          description: t.description,
    \\          inputSchema: t.inputSchema,
    \\        })),
    \\      });
    \\    };
    \\    window.dispatchEvent(event);
    \\    if (groups.length > 0) {
    \\      resolve(JSON.stringify(groups));
    \\    } else {
    \\      setTimeout(() => resolve(JSON.stringify(groups)), 0);
    \\    }
    \\  });
    \\})()
;

const execute_tool_js =
    \\async (name, args, ...elements) => {
    \\  for (const [key, value] of Object.entries(args)) {
    \\    if (value instanceof Object &&
    \\        'uid' in value &&
    \\        typeof value.uid === 'string' &&
    \\        Object.keys(value).length === 1) {
    \\      args[key] = elements.shift();
    \\    }
    \\  }
    \\  if (!window.__dtmcp?.executeTool) {
    \\    throw new Error('No tools found on the page');
    \\  }
    \\  const toolResult = await window.__dtmcp.executeTool(name, args);
    \\  const stashedElements = [];
    \\  const stashDOMElement = (el) => {
    \\    stashedElements.push(el);
    \\    return { stashedId: `stashed-${stashedElements.length - 1}` };
    \\  };
    \\  const ancestors = new Set();
    \\  const processToolResult = (data) => {
    \\    if (data instanceof Element) return stashDOMElement(data);
    \\    if (Array.isArray(data)) {
    \\      if (ancestors.has(data)) return '<Circular reference>';
    \\      ancestors.add(data);
    \\      try { return data.map((item) => processToolResult(item)); }
    \\      finally { ancestors.delete(data); }
    \\    }
    \\    if (data !== null && typeof data === 'object') {
    \\      const proto = Object.getPrototypeOf(data);
    \\      if (proto !== null && proto !== Object.prototype) {
    \\        return `<${data.constructor?.name || 'Object'} instance>`;
    \\      }
    \\      if (ancestors.has(data)) return '<Circular reference>';
    \\      ancestors.add(data);
    \\      try {
    \\        const processedObj = {};
    \\        for (const [key, value] of Object.entries(data)) {
    \\          processedObj[key] = processToolResult(value);
    \\        }
    \\        return processedObj;
    \\      } finally { ancestors.delete(data); }
    \\    }
    \\    if (typeof data === 'function') return '<Function object>';
    \\    if (typeof data === 'symbol') return data.toString();
    \\    if (typeof data === 'bigint') return `${data.toString()}n`;
    \\    return data;
    \\  };
    \\  const processed = processToolResult(toolResult);
    \\  const hasResult = processed !== undefined;
    \\  const serialized = hasResult ? JSON.stringify(processed) : null;
    \\  if (stashedElements.length > 0) {
    \\    window.__dtmcp.stashedElements = stashedElements;
    \\  }
    \\  return JSON.stringify({ result: serialized, hasResult, stashed: stashedElements.length });
    \\}
;

test "replaceHtmlElementsWithUids rewrites x-mcp-type HTMLElement schemas recursively" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const input =
        \\{"type":"object","properties":{"el":{"type":"object","x-mcp-type":"HTMLElement"},"label":{"type":"string"}}}
    ;
    var parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, input, .{});
    try replaceHtmlElementsWithUids(arena, &parsed);
    const el = parsed.object.get("properties").?.object.get("el").?.object;
    const uid_prop = el.get("properties").?.object.get("uid").?.object;
    try std.testing.expectEqualStrings("string", uid_prop.get("type").?.string);
    try std.testing.expectEqualStrings("uid", el.get("required").?.array.items[0].string);
}

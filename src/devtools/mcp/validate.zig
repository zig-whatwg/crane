//! A tool call's arguments checked against its input schema before the tool
//! runs (design tmp/plans/mcp1-design.md 3: "tool inputs validated against
//! the schemas", a MUST), as chrome-devtools-mcp's ToolHandler does with
//! `zod.object(tool.schema).strict().safeParse(args)` and answers
//! formatValidationError's text (src/ToolHandler.ts at
//! chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC, Apache-2.0):
//! "Input validation error: Invalid arguments for tool <name>: " and each
//! issue as "<path>: <message>", joined by ", ", in zod 4's English messages.
//! The schemas are the copied JSON Schemas (schemas/tools.json), which carry
//! what zod checks: types, integers, bounds, lengths, enums, required
//! properties, and no unknown property (strict). The checks a schema's
//! transforms make (parseKey, timeout) are the tools' own.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// The error text for `args` against `schema`, or null when they are valid.
pub fn check(arena: Allocator, tool: []const u8, schema: std.json.ObjectMap, args: std.json.Value) !?[]const u8 {
    var issues: std.ArrayList([]const u8) = .empty;
    var path: std.ArrayList([]const u8) = .empty;
    try value(arena, schema, args, &path, &issues);
    if (issues.items.len == 0) return null;
    return try std.fmt.allocPrint(arena, "Input validation error: Invalid arguments for tool {s}: {s}", .{ tool, try std.mem.join(arena, ", ", issues.items) });
}

/// zod's name for what was received.
fn received(v: std.json.Value) []const u8 {
    return switch (v) {
        .null => "null",
        .bool => "boolean",
        .integer, .float, .number_string => "number",
        .string => "string",
        .array => "array",
        .object => "object",
    };
}

fn issue(arena: Allocator, path: []const []const u8, issues: *std.ArrayList([]const u8), comptime format: []const u8, args: anytype) !void {
    const message = try std.fmt.allocPrint(arena, format, args);
    if (path.len == 0) return issues.append(arena, message);
    try issues.append(arena, try std.fmt.allocPrint(arena, "{s}: {s}", .{ try std.mem.join(arena, ".", path), message }));
}

fn number(v: std.json.Value) ?f64 {
    return switch (v) {
        .integer => |i| @floatFromInt(i),
        .float => |f| f,
        .number_string => |s| std.fmt.parseFloat(f64, s) catch null,
        else => null,
    };
}

/// A bound as zod prints it (an integer without a fraction).
fn bound(arena: Allocator, b: std.json.Value) ![]const u8 {
    return switch (b) {
        .integer => |i| std.fmt.allocPrint(arena, "{d}", .{i}),
        .float => |f| std.fmt.allocPrint(arena, "{d}", .{f}),
        .number_string => |s| s,
        else => "?",
    };
}

fn str(v: ?std.json.Value) []const u8 {
    const x = v orelse return "";
    return if (x == .string) x.string else "";
}

fn value(arena: Allocator, schema: std.json.ObjectMap, v: std.json.Value, path: *std.ArrayList([]const u8), issues: *std.ArrayList([]const u8)) Allocator.Error!void {
    if (schema.get("enum")) |options| if (options == .array) {
        for (options.array.items) |o| if (o == .string and v == .string and std.mem.eql(u8, o.string, v.string)) return;
        var listed: std.ArrayList([]const u8) = .empty;
        for (options.array.items) |o| try listed.append(arena, try std.json.Stringify.valueAlloc(arena, o, .{}));
        return issue(arena, path.items, issues, "Invalid option: expected one of {s}", .{try std.mem.join(arena, "|", listed.items)});
    };
    const kind = str(schema.get("type"));
    if (kind.len == 0) return; // any
    if (std.mem.eql(u8, kind, "string")) {
        if (v != .string) return issue(arena, path.items, issues, "Invalid input: expected string, received {s}", .{received(v)});
        if (schema.get("minLength")) |min| if (number(min)) |m| {
            if (@as(f64, @floatFromInt(utf16Length(v.string))) < m) try issue(arena, path.items, issues, "Too small: expected string to have >={s} characters", .{try bound(arena, min)});
        };
        return;
    }
    if (std.mem.eql(u8, kind, "number") or std.mem.eql(u8, kind, "integer")) {
        const n = number(v) orelse return issue(arena, path.items, issues, "Invalid input: expected number, received {s}", .{received(v)});
        if (std.mem.eql(u8, kind, "integer") and n != @floor(n)) try issue(arena, path.items, issues, "Invalid input: expected int, received number", .{});
        if (schema.get("exclusiveMinimum")) |b| if (number(b)) |m| if (!(n > m)) try issue(arena, path.items, issues, "Too small: expected number to be >{s}", .{try bound(arena, b)});
        if (schema.get("minimum")) |b| if (number(b)) |m| if (!(n >= m)) try issue(arena, path.items, issues, "Too small: expected number to be >={s}", .{try bound(arena, b)});
        if (schema.get("exclusiveMaximum")) |b| if (number(b)) |m| if (!(n < m)) try issue(arena, path.items, issues, "Too big: expected number to be <{s}", .{try bound(arena, b)});
        if (schema.get("maximum")) |b| if (number(b)) |m| if (!(n <= m)) try issue(arena, path.items, issues, "Too big: expected number to be <={s}", .{try bound(arena, b)});
        return;
    }
    if (std.mem.eql(u8, kind, "boolean")) {
        if (v != .bool) try issue(arena, path.items, issues, "Invalid input: expected boolean, received {s}", .{received(v)});
        return;
    }
    if (std.mem.eql(u8, kind, "array")) {
        if (v != .array) return issue(arena, path.items, issues, "Invalid input: expected array, received {s}", .{received(v)});
        if (schema.get("items")) |items| if (items == .object) for (v.array.items, 0..) |item, i| {
            try path.append(arena, try std.fmt.allocPrint(arena, "{d}", .{i}));
            defer _ = path.pop();
            try value(arena, items.object, item, path, issues);
        };
        if (schema.get("minItems")) |min| if (number(min)) |m| {
            if (@as(f64, @floatFromInt(v.array.items.len)) < m) try issue(arena, path.items, issues, "Too small: expected array to have >={s} items", .{try bound(arena, min)});
        };
        return;
    }
    if (std.mem.eql(u8, kind, "object")) {
        if (v != .object) return issue(arena, path.items, issues, "Invalid input: expected object, received {s}", .{received(v)});
        const properties: ?std.json.ObjectMap = if (schema.get("properties")) |p| (if (p == .object) p.object else null) else null;
        if (properties) |props| {
            var it = props.iterator();
            while (it.next()) |entry| {
                const name = entry.key_ptr.*;
                const property = if (entry.value_ptr.* == .object) entry.value_ptr.object else continue;
                try path.append(arena, name);
                defer _ = path.pop();
                if (v.object.get(name)) |given| {
                    try value(arena, property, given, path, issues);
                } else if (isRequired(schema, name)) {
                    try issue(arena, path.items, issues, "Invalid input: expected {s}, received undefined", .{expected(property)});
                }
            }
        }
        // strict(): no other key.
        if (schema.get("additionalProperties")) |extra| if (extra == .bool and !extra.bool) {
            var unknown: std.ArrayList([]const u8) = .empty;
            var it = v.object.iterator();
            while (it.next()) |entry| {
                const known = if (properties) |props| props.contains(entry.key_ptr.*) else false;
                if (!known) try unknown.append(arena, try std.json.Stringify.valueAlloc(arena, entry.key_ptr.*, .{}));
            }
            if (unknown.items.len > 0) try issue(arena, path.items, issues, "Unrecognized key{s}: {s}", .{ if (unknown.items.len > 1) "s" else "", try std.mem.join(arena, ", ", unknown.items) });
        };
        return;
    }
}

/// What a missing property should have been, as zod names it.
fn expected(property: std.json.ObjectMap) []const u8 {
    if (property.get("enum") != null) return "string";
    const kind = str(property.get("type"));
    if (std.mem.eql(u8, kind, "integer")) return "number";
    return if (kind.len != 0) kind else "unknown";
}

fn isRequired(schema: std.json.ObjectMap, name: []const u8) bool {
    const required = schema.get("required") orelse return false;
    if (required != .array) return false;
    for (required.array.items) |r| if (r == .string and std.mem.eql(u8, r.string, name)) return true;
    return false;
}

fn utf16Length(text: []const u8) usize {
    const view = std.unicode.Utf8View.init(text) catch return text.len;
    var it = view.iterator();
    var n: usize = 0;
    while (it.nextCodepoint()) |cp| n += if (cp >= 0x10000) 2 else 1;
    return n;
}

test "zod's checks and messages: required, types, integers, bounds, enums, unknown keys" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const schema_text =
        \\{"type":"object","properties":{"pageId":{"type":"number"},"pageSize":{"type":"integer","exclusiveMinimum":0,"maximum":9007199254740991},"action":{"type":"string","enum":["accept","dismiss"]},"types":{"type":"array","items":{"type":"string","enum":["log","error"]}}},"required":["pageId","action"],"additionalProperties":false}
    ;
    const schema = try std.json.parseFromSliceLeaky(std.json.Value, arena, schema_text, .{});
    const ok = try std.json.parseFromSliceLeaky(std.json.Value, arena, "{\"pageId\":1,\"action\":\"accept\",\"pageSize\":2,\"types\":[\"log\"]}", .{});
    try std.testing.expect(try check(arena, "t", schema.object, ok) == null);
    const bad = try std.json.parseFromSliceLeaky(std.json.Value, arena, "{\"action\":\"maybe\",\"pageSize\":0.5,\"types\":[\"warn\"],\"extra\":true}", .{});
    try std.testing.expectEqualStrings(
        "Input validation error: Invalid arguments for tool t: pageId: Invalid input: expected number, received undefined, pageSize: Invalid input: expected int, received number, action: Invalid option: expected one of \"accept\"|\"dismiss\", types.0: Invalid option: expected one of \"log\"|\"error\", Unrecognized key: \"extra\"",
        (try check(arena, "t", schema.object, bad)).?,
    );
}

//! A page's console messages as chrome-devtools-mcp keeps and prints them
//! (chrome-devtools-mcp-v1.13.0: src/McpPage.ts's ConsoleCollector,
//! src/formatters/ConsoleFormatter.ts, src/formatters/RemoteObjectFormatter.ts,
//! src/devtools/DevtoolsUtils.ts SymbolizedError), with Puppeteer's
//! ConsoleMessage made from the CDP events it reads (puppeteer-core 25.17.0,
//! src/cdp/Page.ts #onConsoleAPI and #onLogEntryAdded, src/cdp/utils.ts
//! createConsoleMessage; Copyright 2017 Google Inc., Apache-2.0):
//!
//! - Runtime.consoleAPICalled in a frame's main world: the type (`warning`
//!   as `warn`), the text the arguments' String() values joined by spaces -
//!   an error's description's first line, another object's `[<subtype or
//!   type> <className>]` (createConsoleMessage, valueFromJSHandle) - and the
//!   arguments kept for the detailed view;
//! - Log.entryAdded, but a worker's: its level and text, no arguments;
//! - Runtime.exceptionThrown: an `error` whose text is SymbolizedError's
//!   message ("Uncaught" or "Uncaught (in promise)" and the exception's
//!   description's first part, else the details' text).
//!
//! Translated from chrome-devtools-mcp's TypeScript (Copyright 2025 Google
//! LLC, Apache-2.0; THIRD_PARTY_NOTICES.md). Stack traces are printed from
//! the protocol's call frames by DevTools' own rules (UISourceCode's display
//! name, 1-based line and column); DevTools' source-map translation and
//! ignore-listing are not here yet (lane mcp1's differential report lists
//! them).

const std = @import("std");
const Allocator = std.mem.Allocator;
const reflection = @import("dom").reflection;

/// ConsoleCollector.MAX_MESSAGES_PER_NAVIGATION.
pub const max_per_navigation: usize = 10_000;

pub const Message = struct {
    id: u32 = 0,
    /// Puppeteer's ConsoleMessage.type(), or "error" for an uncaught one.
    type: []u8,
    /// Puppeteer's ConsoleMessage.text(), or SymbolizedError's message.
    text: []u8,
    arg_count: u32,
    /// The Runtime.RemoteObject arguments as JSON text ("[]" for none), or
    /// an uncaught one's Runtime.ExceptionDetails.
    detail_json: []u8,
    /// The Runtime.StackTrace as JSON text, or "".
    stack_json: []u8,
    uncaught: bool,

    pub fn deinit(self: *Message, allocator: Allocator) void {
        allocator.free(self.type);
        allocator.free(self.text);
        allocator.free(self.detail_json);
        allocator.free(self.stack_json);
    }
};

fn str(value: ?std.json.Value) []const u8 {
    const v = value orelse return "";
    return if (v == .string) v.string else "";
}

/// convertConsoleMessageLevel.
fn level(kind: []const u8) []const u8 {
    return if (std.mem.eql(u8, kind, "warning")) "warn" else kind;
}

fn stringify(allocator: Allocator, value: ?std.json.Value) ![]u8 {
    const v = value orelse return allocator.dupe(u8, "");
    return std.json.Stringify.valueAlloc(allocator, v, .{});
}

/// A message from Runtime.consoleAPICalled, OWNED; null for one Puppeteer
/// drops (no execution context).
pub fn fromConsoleApi(allocator: Allocator, params: std.json.ObjectMap) !?*Message {
    if (params.get("executionContextId")) |id| if (id == .integer and id.integer == 0) return null;
    const args: []const std.json.Value = if (params.get("args")) |a| (if (a == .array) a.array.items else &.{}) else &.{};
    var text: std.Io.Writer.Allocating = .init(allocator);
    defer text.deinit();
    for (args, 0..) |arg, i| {
        if (i != 0) try text.writer.writeByte(' ');
        try token(&text.writer, arg);
    }
    const message = try allocator.create(Message);
    errdefer allocator.destroy(message);
    const kind = try allocator.dupe(u8, level(str(params.get("type"))));
    errdefer allocator.free(kind);
    const owned_text = try text.toOwnedSlice();
    errdefer allocator.free(owned_text);
    const detail = if (params.get("args")) |a| try stringify(allocator, a) else try allocator.dupe(u8, "[]");
    errdefer allocator.free(detail);
    const stack = try stringify(allocator, params.get("stackTrace"));
    message.* = .{ .type = kind, .text = owned_text, .arg_count = @intCast(args.len), .detail_json = detail, .stack_json = stack, .uncaught = false };
    return message;
}

/// A message from Log.entryAdded, OWNED; null for a worker's.
pub fn fromLogEntry(allocator: Allocator, params: std.json.ObjectMap) !?*Message {
    const entry = (params.get("entry") orelse return null);
    if (entry != .object) return null;
    if (std.mem.eql(u8, str(entry.object.get("source")), "worker")) return null;
    const message = try allocator.create(Message);
    errdefer allocator.destroy(message);
    const kind = try allocator.dupe(u8, level(str(entry.object.get("level"))));
    errdefer allocator.free(kind);
    const text = try allocator.dupe(u8, str(entry.object.get("text")));
    errdefer allocator.free(text);
    const detail = try allocator.dupe(u8, "[]");
    errdefer allocator.free(detail);
    const stack = try stringify(allocator, entry.object.get("stackTrace"));
    message.* = .{ .type = kind, .text = text, .arg_count = 0, .detail_json = detail, .stack_json = stack, .uncaught = false };
    return message;
}

/// A message from Runtime.exceptionThrown, OWNED.
pub fn fromException(allocator: Allocator, params: std.json.ObjectMap) !?*Message {
    const details = params.get("exceptionDetails") orelse return null;
    if (details != .object) return null;
    const message = try allocator.create(Message);
    errdefer allocator.destroy(message);
    const kind = try allocator.dupe(u8, "error");
    errdefer allocator.free(kind);
    const text = try exceptionMessage(allocator, details.object);
    errdefer allocator.free(text);
    const detail = try stringify(allocator, details);
    errdefer allocator.free(detail);
    const stack = try stringify(allocator, details.object.get("stackTrace"));
    message.* = .{ .type = kind, .text = text, .arg_count = 0, .detail_json = detail, .stack_json = stack, .uncaught = true };
    return message;
}

/// SymbolizedError #getMessage, OWNED.
pub fn exceptionMessage(allocator: Allocator, details: std.json.ObjectMap) ![]u8 {
    const text = str(details.get("text"));
    if (std.mem.eql(u8, text, "Uncaught") or std.mem.eql(u8, text, "Uncaught (in promise)")) {
        if (details.get("exception")) |exception| if (exception == .object) {
            var out: std.Io.Writer.Allocating = .init(allocator);
            errdefer out.deinit();
            try out.writer.print("{s} ", .{text});
            try messageFromException(&out.writer, exception.object);
            return out.toOwnedSlice();
        };
    }
    return allocator.dupe(u8, text);
}

/// SymbolizedError #getMessageFromException.
pub fn messageFromException(w: *std.Io.Writer, error_object: std.json.ObjectMap) !void {
    const description = error_object.get("description") orelse {
        if (error_object.get("unserializableValue")) |u| return w.writeAll(str(u));
        const value = error_object.get("value") orelse return;
        return jsString(w, value);
    };
    const text = str(description);
    const cut = std.mem.indexOf(u8, text, "\n    at ") orelse text.len;
    try w.writeAll(text[0..cut]);
}

/// One argument's token in Puppeteer's text (createConsoleMessage):
/// String(valueFromJSHandle(arg)) - an object's
/// valueFromRemoteObjectReference (an error's description's first line, else
/// `[<subtype or type> <className>]`), a primitive's value.
fn token(w: *std.Io.Writer, arg: std.json.Value) !void {
    if (arg != .object) return;
    const o = arg.object;
    if (o.get("objectId") != null) {
        const description = str(o.get("description"));
        if (std.mem.eql(u8, str(o.get("subtype")), "error") and description.len != 0) {
            const end = std.mem.indexOfScalar(u8, description, '\n') orelse description.len;
            return w.writeAll(description[0..end]);
        }
        const subtype = str(o.get("subtype"));
        const class_name = if (o.get("className")) |c| str(c) else "undefined";
        return w.print("[{s} {s}]", .{ if (subtype.len != 0) subtype else str(o.get("type")), class_name });
    }
    // valueFromPrimitiveRemoteObject.
    if (o.get("unserializableValue")) |u| {
        const text = str(u);
        if (std.mem.eql(u8, str(o.get("type")), "bigint")) {
            // BigInt(text.replace('n', '')).
            if (std.mem.indexOfScalar(u8, text, 'n')) |at| {
                try w.writeAll(text[0..at]);
                return w.writeAll(text[at + 1 ..]);
            }
            return w.writeAll(text);
        }
        if (std.mem.eql(u8, text, "-0")) return w.writeAll("0");
        return w.writeAll(text);
    }
    const value = o.get("value") orelse return w.writeAll("undefined");
    try jsString(w, value);
}

/// ECMAScript String(value) of a JSON value: null prints "null"; an array
/// joins its elements (null ones as nothing); an object prints
/// "[object Object]".
pub fn jsString(w: *std.Io.Writer, value: std.json.Value) !void {
    switch (value) {
        .null => try w.writeAll("null"),
        .bool => |b| try w.writeAll(if (b) "true" else "false"),
        .integer => |i| try w.print("{d}", .{i}),
        .float => |f| try jsNumber(w, f),
        .number_string => |s| try w.writeAll(s),
        .string => |s| try w.writeAll(s),
        .array => |a| for (a.items, 0..) |item, i| {
            if (i != 0) try w.writeByte(',');
            if (item != .null) try jsString(w, item);
        },
        .object => try w.writeAll("[object Object]"),
    }
}

/// Number::toString.
pub fn jsNumber(w: *std.Io.Writer, value: f64) !void {
    var buffer: [32]u8 = undefined;
    try w.writeAll(reflection.numberToString(&buffer, value));
}

/// JSON.stringify of a value Runtime returned by value (key order kept).
pub fn jsonStringify(w: *std.Io.Writer, value: std.json.Value) !void {
    switch (value) {
        .null => try w.writeAll("null"),
        .bool => |b| try w.writeAll(if (b) "true" else "false"),
        .integer => |i| try w.print("{d}", .{i}),
        .float => |f| if (std.math.isFinite(f)) try jsNumber(w, f) else try w.writeAll("null"),
        .number_string => |s| try w.writeAll(s),
        .string => |s| try std.json.Stringify.encodeJsonString(s, .{}, w),
        .array => |a| {
            try w.writeByte('[');
            for (a.items, 0..) |item, i| {
                if (i != 0) try w.writeByte(',');
                try jsonStringify(w, item);
            }
            try w.writeByte(']');
        },
        .object => |o| {
            try w.writeByte('{');
            var it = o.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try w.writeByte(',');
                first = false;
                try std.json.Stringify.encodeJsonString(entry.key_ptr.*, .{}, w);
                try w.writeByte(':');
                try jsonStringify(w, entry.value_ptr.*);
            }
            try w.writeByte('}');
        },
    }
}

// ----------------------------------------------------------------------
// The concise form (list_console_messages)
// ----------------------------------------------------------------------

/// convertConsoleMessageConciseToString, with groupConsecutive's count.
pub fn writeConcise(w: *std.Io.Writer, message: *const Message, count: u32, stack: ?[]const u8) !void {
    try w.print("msgid={d} [{s}] {s} ({d} args)", .{ message.id, message.type, message.text, message.arg_count });
    if (count > 1) try w.print(" [{d} times]", .{count});
    const trace = stack orelse return;
    if (trace.len == 0) return;
    var lines = std.mem.splitScalar(u8, trace, '\n');
    while (lines.next()) |line| try w.print("\n  {s}", .{line});
}

/// groupConsecutive's test: the same type, text and argument count.
pub fn sameGroup(a: *const Message, b: *const Message) bool {
    return std.mem.eql(u8, a.type, b.type) and std.mem.eql(u8, a.text, b.text) and a.arg_count == b.arg_count;
}

// ----------------------------------------------------------------------
// Stack traces
// ----------------------------------------------------------------------

/// STACK_TRACE_MAX_LINES.
const stack_trace_max_lines = 50;

/// formatStackTrace over a Runtime.StackTrace's JSON (`stack_json`), with
/// `cause_lines` (formatCause's) after it; "" when there is no trace.
pub fn formatStackTrace(arena: Allocator, stack_json: []const u8, cause_lines: []const []const u8, include_note: bool) ![]const u8 {
    var lines: std.ArrayList([]const u8) = .empty;
    try stackLines(arena, stack_json, &lines);
    try lines.appendSlice(arena, cause_lines);
    if (lines.items.len == 0 and stack_json.len == 0) return "";
    var out: std.ArrayList([]const u8) = .empty;
    const kept = @min(lines.items.len, stack_trace_max_lines);
    try out.appendSlice(arena, lines.items[0..kept]);
    if (lines.items.len > kept) try out.append(arena, try std.fmt.allocPrint(arena, "... and {d} more frames", .{lines.items.len - kept}));
    if (include_note) try out.append(arena, "Note: line and column numbers use 1-based indexing");
    return std.mem.join(arena, "\n", out.items);
}

/// formatStackTraceInner's frames: the synchronous fragment, then each
/// async parent under its separator.
pub fn stackLines(arena: Allocator, stack_json: []const u8, lines: *std.ArrayList([]const u8)) !void {
    if (stack_json.len == 0) return;
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, arena, stack_json, .{}) catch return;
    if (parsed != .object) return;
    var fragment: ?std.json.ObjectMap = parsed.object;
    var first = true;
    while (fragment) |f| {
        var frames: std.ArrayList([]const u8) = .empty;
        if (f.get("callFrames")) |cf| if (cf == .array) for (cf.array.items) |frame| {
            if (frame == .object) try frames.append(arena, try formatFrame(arena, frame.object));
        };
        if (!first and frames.items.len > 0) {
            const description = str(f.get("description"));
            const prefix = try std.fmt.allocPrint(arena, "--- {s} ", .{if (description.len != 0) description else "async"});
            const dashes = 40 -| prefix.len;
            const separator = try arena.alloc(u8, prefix.len + dashes);
            @memcpy(separator[0..prefix.len], prefix);
            @memset(separator[prefix.len..], '-');
            try lines.append(arena, separator);
        }
        try lines.appendSlice(arena, frames.items);
        first = false;
        fragment = if (f.get("parent")) |p| (if (p == .object) p.object else null) else null;
    }
}

/// formatFrame: `at <name> (<display name>:<line>:<column>)`, 1-based (the
/// UILocation's linkText with its column).
fn formatFrame(arena: Allocator, frame: std.json.ObjectMap) ![]const u8 {
    const name = str(frame.get("functionName"));
    const url = str(frame.get("url"));
    const line = number(frame.get("lineNumber")) + 1;
    const column = number(frame.get("columnNumber")) + 1;
    if (url.len == 0) {
        // DevTools' scripts without a URL: "VM<scriptId>".
        return std.fmt.allocPrint(arena, "at {s} (VM{s}:{d}:{d})", .{ name, str(frame.get("scriptId")), line, column });
    }
    return std.fmt.allocPrint(arena, "at {s} ({s}:{d}:{d})", .{ name, try displayName(arena, url), line, column });
}

fn number(value: ?std.json.Value) i64 {
    const v = value orelse return 0;
    return switch (v) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => 0,
    };
}

/// UISourceCode.displayName(): the URL's last path component (with its
/// query), "(index)" for none, trimmed at the end to 100 characters.
pub fn displayName(arena: Allocator, url: []const u8) ![]const u8 {
    var rest = url;
    if (std.mem.indexOfScalar(u8, rest, '#')) |hash| rest = rest[0..hash];
    var query: []const u8 = "";
    if (std.mem.indexOfScalar(u8, rest, '?')) |q| {
        query = rest[q + 1 ..];
        rest = rest[0..q];
    }
    // A URL with an authority: the path after it.
    if (std.mem.indexOf(u8, rest, "://")) |scheme_end| {
        const after = rest[scheme_end + 3 ..];
        rest = if (std.mem.indexOfScalar(u8, after, '/')) |slash| after[slash..] else "";
    }
    const last = if (std.mem.lastIndexOfScalar(u8, rest, '/')) |slash| rest[slash + 1 ..] else rest;
    var name: []const u8 = if (query.len != 0) try std.fmt.allocPrint(arena, "{s}?{s}", .{ last, query }) else last;
    if (name.len == 0) return "(index)";
    const view = std.unicode.Utf8View.init(name) catch return name;
    var it = view.iterator();
    var count: usize = 0;
    var cut: usize = 0;
    while (it.nextCodepointSlice()) |cp| {
        count += 1;
        if (count == 100) cut = it.i - cp.len;
    }
    if (count > 100) name = try std.fmt.allocPrint(arena, "{s}\u{2026}", .{name[0..cut]});
    return name;
}

// ----------------------------------------------------------------------
// RemoteObjectFormatter.formatRemoteObject
// ----------------------------------------------------------------------

const max_description_length = 400;

/// isJsonLike: JSON.stringify prints the value faithfully.
pub fn isJsonLike(remote: std.json.ObjectMap) bool {
    const kind = str(remote.get("type"));
    if (std.mem.eql(u8, kind, "object")) {
        const subtype = remote.get("subtype") orelse return true;
        const s = str(subtype);
        return std.mem.eql(u8, s, "array") or std.mem.eql(u8, s, "null");
    }
    return !std.mem.eql(u8, kind, "function") and !std.mem.eql(u8, kind, "symbol") and !std.mem.eql(u8, kind, "bigint");
}

pub fn formatRemoteObject(arena: Allocator, remote: std.json.ObjectMap) ![]const u8 {
    const kind = str(remote.get("type"));
    const subtype = str(remote.get("subtype"));
    if (remote.get("preview")) |preview| if (preview == .object and std.mem.eql(u8, kind, "object") and !std.mem.eql(u8, subtype, "node") and !std.mem.eql(u8, subtype, "trustedtype")) {
        return formatObjectPreview(arena, preview.object);
    };
    if (std.mem.eql(u8, kind, "string")) return str(remote.get("value"));
    if (remote.get("unserializableValue")) |u| return str(u);
    if (remote.get("description")) |d| return trimEnd(arena, str(d), max_description_length);
    var out: std.Io.Writer.Allocating = .init(arena);
    // String(value): undefined prints "undefined", null "null".
    if (remote.get("value")) |v| try jsString(&out.writer, v) else try out.writer.writeAll("undefined");
    return out.written();
}

/// StringUtilities.trimEndWithMaxLength.
fn trimEnd(arena: Allocator, text: []const u8, max: usize) ![]const u8 {
    const view = std.unicode.Utf8View.init(text) catch return text;
    var it = view.iterator();
    var count: usize = 0;
    var cut: usize = 0;
    while (it.nextCodepointSlice()) |cp| {
        count += 1;
        if (count == max) cut = it.i - cp.len;
    }
    if (count <= max) return text;
    return std.fmt.allocPrint(arena, "{s}\u{2026}", .{text[0..cut]});
}

const subtypes_without_value_preview = [_][]const u8{ "arraybuffer", "dataview", "date", "error", "internal#entry", "null", "node", "regexp", "trustedtype", "webassemblymemory" };

fn withoutValuePreview(subtype: []const u8) bool {
    for (subtypes_without_value_preview) |s| if (std.mem.eql(u8, s, subtype)) return true;
    return false;
}

fn sortValue(property: std.json.ObjectMap) u8 {
    const name = str(property.get("name"));
    if (std.mem.eql(u8, name, "[[PromiseState]]")) return 1;
    if (std.mem.eql(u8, name, "[[PromiseResult]]")) return 2;
    if (std.mem.eql(u8, name, "[[GeneratorState]]") or std.mem.eql(u8, name, "[[PrimitiveValue]]") or std.mem.eql(u8, name, "[[WeakRefTarget]]")) return 3;
    if (!std.mem.eql(u8, str(property.get("type")), "function") and !std.mem.startsWith(u8, name, "#")) return 4;
    return 5;
}

fn formatName(arena: Allocator, name: []const u8) ![]const u8 {
    const quote = name.len == 0 or std.ascii.isWhitespace(name[0]) or std.ascii.isWhitespace(name[name.len - 1]) or std.mem.indexOfScalar(u8, name, '\n') != null;
    if (!quote) return name;
    const replaced = try std.mem.replaceOwned(u8, arena, name, "\n", "\u{21b5}");
    return std.fmt.allocPrint(arena, "\"{s}\"", .{replaced});
}

/// StringUtilities.trimMiddle.
fn trimMiddle(arena: Allocator, text: []const u8, max: usize) ![]const u8 {
    if (text.len <= max) return text;
    var left = max / 2;
    var right = max - left - 1;
    // Keep surrogate pairs whole (ASCII class names in practice).
    if (left > text.len) left = text.len;
    if (right > text.len) right = text.len;
    return std.fmt.allocPrint(arena, "{s}\u{2026}{s}", .{ text[0..left], text[text.len - right ..] });
}

fn abbreviateClassName(arena: Allocator, description: []const u8) ![]const u8 {
    if (std.mem.eql(u8, description, "Object")) return "{\u{2026}}";
    var parts: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, description, '.');
    while (it.next()) |part| try parts.append(arena, part);
    for (parts.items[0 .. parts.items.len - 1]) |*part| part.* = try trimMiddle(arena, part.*, 3);
    return std.mem.join(arena, ".", parts.items);
}

fn formatPropertyValue(arena: Allocator, kind: []const u8, subtype: ?[]const u8, description: []const u8) ![]const u8 {
    if (std.mem.eql(u8, kind, "accessor")) return "(...)";
    if (std.mem.eql(u8, kind, "function")) return "\u{192}";
    if (std.mem.eql(u8, kind, "string")) return formatAsJsLiteral(arena, description);
    if (std.mem.eql(u8, kind, "object")) return if (subtype != null) description else abbreviateClassName(arena, description);
    return description;
}

/// StringUtilities.formatAsJSLiteral: quoted with ' unless the content has
/// one, then ", then ` (when it has no "${"), else ' with its own escaped;
/// backslashes, "<!--", "<script" and "</script" escaped, a control
/// character as its escape or \xHH.
fn formatAsJsLiteral(arena: Allocator, content: []const u8) ![]const u8 {
    const has = struct {
        fn f(haystack: []const u8, needle: []const u8) bool {
            return std.mem.indexOf(u8, haystack, needle) != null;
        }
    }.f;
    const quote: u8 = if (!has(content, "'")) '\'' else if (!has(content, "\"")) '"' else if (!has(content, "`") and !has(content, "${")) '`' else '\'';
    const escape_single = has(content, "'") and quote == '\'';
    var out: std.Io.Writer.Allocating = .init(arena);
    const w = &out.writer;
    try w.writeByte(quote);
    var i: usize = 0;
    while (i < content.len) {
        const c = content[i];
        const rest = content[i..];
        if (c == '<') {
            if (std.mem.startsWith(u8, rest, "<!--")) {
                try w.writeAll("<\\!--");
                i += 4;
                continue;
            }
            if (std.mem.startsWith(u8, rest, "<script")) {
                try w.writeAll("<\\script");
                i += 7;
                continue;
            }
            if (std.mem.startsWith(u8, rest, "</script")) {
                try w.writeAll("<\\/script");
                i += 8;
                continue;
            }
        }
        // C1 controls (U+0080..U+009F) are \p{Control} too.
        if (c == 0xc2 and i + 1 < content.len and content[i + 1] >= 0x80 and content[i + 1] <= 0x9f) {
            try w.print("\\x{X:0>2}", .{content[i + 1]});
            i += 2;
            continue;
        }
        switch (c) {
            '\\' => try w.writeAll("\\\\"),
            '\n' => try w.writeAll("\\n"),
            '\r' => try w.writeAll("\\r"),
            '\t' => try w.writeAll("\\t"),
            0x08 => try w.writeAll("\\b"),
            0x0c => try w.writeAll("\\f"),
            0x0b => try w.writeAll("\\v"),
            0x00...0x07, 0x0e...0x1f, 0x7f => try w.print("\\x{X:0>2}", .{c}),
            '\'' => if (escape_single) try w.writeAll("\\'") else try w.writeByte(c),
            else => try w.writeByte(c),
        }
        i += 1;
    }
    try w.writeByte(quote);
    return out.written();
}

/// The match of /[[(](\d+)[\])]$/ in a description: where the bracket
/// opens, and the length.
const LengthSuffix = struct { open: usize, length: usize };

fn lengthSuffix(description: []const u8) ?LengthSuffix {
    if (description.len < 3) return null;
    const close = description[description.len - 1];
    if (close != ']' and close != ')') return null;
    var start = description.len - 1;
    while (start > 0 and std.ascii.isDigit(description[start - 1])) start -= 1;
    if (start == description.len - 1 or start == 0) return null;
    const open = description[start - 1];
    if (open != '[' and open != '(') return null;
    const length = std.fmt.parseInt(usize, description[start .. description.len - 1], 10) catch return null;
    return .{ .open = start - 1, .length = length };
}

fn arrayLength(preview: std.json.ObjectMap) usize {
    const suffix = lengthSuffix(str(preview.get("description"))) orelse return 0;
    return suffix.length;
}

fn properties(preview: std.json.ObjectMap) []const std.json.Value {
    const p = preview.get("properties") orelse return &.{};
    return if (p == .array) p.array.items else &.{};
}

fn propertyValue(arena: Allocator, property: std.json.ObjectMap) ![]const u8 {
    const subtype: ?[]const u8 = if (property.get("subtype")) |s| str(s) else null;
    return formatPropertyValue(arena, str(property.get("type")), subtype, str(property.get("value")));
}

fn arrayIndex(name: []const u8, length: usize) ?usize {
    const index = std.fmt.parseInt(u32, name, 10) catch return null;
    var buffer: [16]u8 = undefined;
    const canonical = std.fmt.bufPrint(&buffer, "{d}", .{index}) catch return null;
    if (!std.mem.eql(u8, canonical, name) or index >= length) return null;
    return index;
}

fn formatArrayItems(arena: Allocator, preview: std.json.ObjectMap) !std.ArrayList([]const u8) {
    const length = arrayLength(preview);
    const Indexed = struct { index: usize, property: std.json.ObjectMap };
    var indexed: std.ArrayList(Indexed) = .empty;
    var others: std.ArrayList(std.json.ObjectMap) = .empty;
    for (properties(preview)) |p| {
        if (p != .object) continue;
        if (arrayIndex(str(p.object.get("name")), length)) |i| try indexed.append(arena, .{ .index = i, .property = p.object }) else try others.append(arena, p.object);
    }
    std.mem.sort(Indexed, indexed.items, {}, struct {
        fn less(_: void, a: Indexed, b: Indexed) bool {
            return a.index < b.index;
        }
    }.less);
    std.mem.sort(std.json.ObjectMap, others.items, {}, struct {
        fn less(_: void, a: std.json.ObjectMap, b: std.json.ObjectMap) bool {
            return sortValue(a) < sortValue(b);
        }
    }.less);
    const overflow = if (preview.get("overflow")) |o| (o == .bool and o.bool) else false;
    const can_show_gaps = !overflow;
    var items: std.ArrayList([]const u8) = .empty;
    var previous: i64 = -1;
    for (indexed.items) |entry| {
        const index: i64 = @intCast(entry.index);
        const value = try propertyValue(arena, entry.property);
        if (can_show_gaps) {
            if (index - previous > 1) try items.append(arena, try gap(arena, index - previous - 1));
            try items.append(arena, value);
        } else {
            if (entry.index == items.items.len) try items.append(arena, value) else try items.append(arena, try std.fmt.allocPrint(arena, "{s}: {s}", .{ str(entry.property.get("name")), value }));
        }
        previous = index;
    }
    if (can_show_gaps and @as(i64, @intCast(length)) - previous > 1) try items.append(arena, try gap(arena, @as(i64, @intCast(length)) - previous - 1));
    for (others.items) |p| try items.append(arena, try std.fmt.allocPrint(arena, "{s}: {s}", .{ try formatName(arena, str(p.get("name"))), try propertyValue(arena, p) }));
    return items;
}

fn gap(arena: Allocator, count: i64) ![]const u8 {
    if (count == 1) return "empty";
    return std.fmt.allocPrint(arena, "empty \u{d7} {d}", .{count});
}

fn formatObjectItems(arena: Allocator, preview: std.json.ObjectMap) !std.ArrayList([]const u8) {
    var props: std.ArrayList(std.json.ObjectMap) = .empty;
    for (properties(preview)) |p| {
        if (p == .object and !std.mem.eql(u8, str(p.object.get("type")), "accessor")) try props.append(arena, p.object);
    }
    std.mem.sort(std.json.ObjectMap, props.items, {}, struct {
        fn less(_: void, a: std.json.ObjectMap, b: std.json.ObjectMap) bool {
            return sortValue(a) < sortValue(b);
        }
    }.less);
    const preview_subtype = str(preview.get("subtype"));
    var items: std.ArrayList([]const u8) = .empty;
    var i: usize = 0;
    while (i < props.items.len) : (i += 1) {
        const property = props.items[i];
        const name = str(property.get("name"));
        const value = try propertyValue(arena, property);
        const state = str(property.get("value"));
        if (std.mem.eql(u8, preview_subtype, "promise") and std.mem.eql(u8, name, "[[PromiseState]]")) {
            const result: ?std.json.ObjectMap = if (i + 1 < props.items.len and std.mem.eql(u8, str(props.items[i + 1].get("name")), "[[PromiseResult]]")) props.items[i + 1] else null;
            if (result != null) i += 1;
            if (!std.mem.eql(u8, state, "pending") and result != null) {
                try items.append(arena, try std.fmt.allocPrint(arena, "<{s}>: {s}", .{ state, try propertyValue(arena, result.?) }));
            } else try items.append(arena, try std.fmt.allocPrint(arena, "<{s}>", .{state}));
        } else if (std.mem.eql(u8, preview_subtype, "generator") and std.mem.eql(u8, name, "[[GeneratorState]]")) {
            try items.append(arena, try std.fmt.allocPrint(arena, "<{s}>", .{state}));
        } else if (std.mem.eql(u8, name, "[[PrimitiveValue]]")) {
            try items.append(arena, value);
        } else if (std.mem.eql(u8, name, "[[WeakRefTarget]]")) {
            try items.append(arena, if (std.mem.eql(u8, str(property.get("type")), "undefined")) "<cleared>" else value);
        } else {
            try items.append(arena, try std.fmt.allocPrint(arena, "{s}: {s}", .{ try formatName(arena, name), value }));
        }
    }
    return items;
}

fn formatEntryItems(arena: Allocator, preview: std.json.ObjectMap) !std.ArrayList([]const u8) {
    var items: std.ArrayList([]const u8) = .empty;
    const entries = preview.get("entries") orelse return items;
    if (entries != .array) return items;
    for (entries.array.items) |entry| {
        if (entry != .object) continue;
        const value = (entry.object.get("value") orelse continue).object;
        const value_subtype: ?[]const u8 = if (value.get("subtype")) |s| str(s) else null;
        const formatted = try formatPropertyValue(arena, str(value.get("type")), value_subtype, str(value.get("description")));
        if (entry.object.get("key")) |key| if (key == .object) {
            const key_subtype: ?[]const u8 = if (key.object.get("subtype")) |s| str(s) else null;
            try items.append(arena, try std.fmt.allocPrint(arena, "{s} => {s}", .{ try formatPropertyValue(arena, str(key.object.get("type")), key_subtype, str(key.object.get("description"))), formatted }));
            continue;
        };
        try items.append(arena, formatted);
    }
    return items;
}

fn formatObjectPreview(arena: Allocator, preview: std.json.ObjectMap) ![]const u8 {
    const description = str(preview.get("description"));
    const kind = str(preview.get("type"));
    const subtype_value = preview.get("subtype");
    const subtype = str(subtype_value);
    if (!std.mem.eql(u8, kind, "object") or (subtype_value != null and withoutValuePreview(subtype))) {
        return formatPropertyValue(arena, kind, if (subtype_value != null) subtype else null, description);
    }
    const is_array = std.mem.eql(u8, subtype, "array") or std.mem.eql(u8, subtype, "typedarray");
    var prefix: []const u8 = "";
    if (is_array) {
        const length = arrayLength(preview);
        const length_text = if (length > 1) try std.fmt.allocPrint(arena, "({d})", .{length}) else "";
        const name = if (lengthSuffix(description)) |suffix| description[0..suffix.open] else description;
        prefix = if (std.mem.eql(u8, name, "Array")) length_text else try std.fmt.allocPrint(arena, "{s}{s}", .{ name, length_text });
    } else if (!std.mem.eql(u8, description, "Object")) {
        prefix = description;
    }
    var items = if (preview.get("entries") != null) try formatEntryItems(arena, preview) else if (is_array) try formatArrayItems(arena, preview) else try formatObjectItems(arena, preview);
    if (preview.get("overflow")) |o| if (o == .bool and o.bool) try items.append(arena, "\u{2026}");
    const joined = try std.mem.join(arena, ", ", items.items);
    const body = if (is_array) try std.fmt.allocPrint(arena, "[{s}]", .{joined}) else try std.fmt.allocPrint(arena, "{{{s}}}", .{joined});
    return if (prefix.len != 0) std.fmt.allocPrint(arena, "{s} {s}", .{ prefix, body }) else body;
}

test "Puppeteer's text: String() of each argument's value - an object as [type className], an error as its description's first line" {
    const allocator = std.testing.allocator;
    const source =
        \\{"type":"warning","executionContextId":1,"args":[{"type":"string","value":"a"},{"type":"number","value":1.5},{"type":"undefined"},{"type":"object","subtype":"null","value":null},{"type":"object","className":"Object","objectId":"1"},{"type":"bigint","unserializableValue":"12n"},{"type":"number","unserializableValue":"-0"}]}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, source, .{});
    defer parsed.deinit();
    const message = (try fromConsoleApi(allocator, parsed.value.object)).?;
    defer {
        message.deinit(allocator);
        allocator.destroy(message);
    }
    try std.testing.expectEqualStrings("warn", message.type);
    try std.testing.expectEqualStrings("a 1.5 undefined null [object Object] 12 0", message.text);
    try std.testing.expectEqual(@as(u32, 7), message.arg_count);
}

test "an uncaught exception's message: 'Uncaught' and the description's first part" {
    const allocator = std.testing.allocator;
    const source =
        \\{"exceptionDetails":{"text":"Uncaught","exception":{"type":"object","subtype":"error","description":"TypeError: x\n    at f (a.js:1:1)"}}}
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, source, .{});
    defer parsed.deinit();
    const message = (try fromException(allocator, parsed.value.object)).?;
    defer {
        message.deinit(allocator);
        allocator.destroy(message);
    }
    try std.testing.expectEqualStrings("Uncaught TypeError: x", message.text);
    const primitive =
        \\{"text":"Uncaught","exception":{"type":"undefined"}}
    ;
    const p2 = try std.json.parseFromSlice(std.json.Value, allocator, primitive, .{});
    defer p2.deinit();
    const text = try exceptionMessage(allocator, p2.value.object);
    defer allocator.free(text);
    try std.testing.expectEqualStrings("Uncaught ", text);
}

test "stack traces: DevTools' display names, 1-based positions, async separators padded to 40" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const stack =
        \\{"callFrames":[{"functionName":"foo","scriptId":"5","url":"http://h.test/dir/foo.js?v=1","lineNumber":9,"columnNumber":1},{"functionName":"","scriptId":"6","url":"about:blank","lineNumber":0,"columnNumber":16}],"parent":{"description":"setTimeout","callFrames":[{"functionName":"schedule","scriptId":"7","url":"http://h.test/","lineNumber":4,"columnNumber":1}]}}
    ;
    const text = try formatStackTrace(arena, stack, &.{}, true);
    try std.testing.expectEqualStrings(
        "at foo (foo.js?v=1:10:2)\nat  (about:blank:1:17)\n--- setTimeout -------------------------\nat schedule ((index):5:2)\nNote: line and column numbers use 1-based indexing",
        text,
    );
}

test "remote objects without JSON: previews as DevTools' console prints them" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const map =
        \\{"type":"object","subtype":"map","objectId":"1","preview":{"type":"object","subtype":"map","description":"Map(1)","overflow":false,"properties":[],"entries":[{"key":{"type":"string","description":"a"},"value":{"type":"number","description":"1"}}]}}
    ;
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, map, .{});
    try std.testing.expectEqualStrings("Map(1) {'a' => 1}", try formatRemoteObject(arena, parsed.object));
    const array =
        \\{"type":"object","subtype":"array","objectId":"2","preview":{"type":"object","subtype":"array","description":"Array(4)","overflow":false,"properties":[{"name":"0","type":"number","value":"1"},{"name":"3","type":"string","value":"x"}]}}
    ;
    const p2 = try std.json.parseFromSliceLeaky(std.json.Value, arena, array, .{});
    try std.testing.expectEqualStrings("(4) [1, empty \u{d7} 2, 'x']", try formatRemoteObject(arena, p2.object));
    const fun =
        \\{"type":"function","className":"Function","description":"function f() {}","objectId":"3"}
    ;
    const p3 = try std.json.parseFromSliceLeaky(std.json.Value, arena, fun, .{});
    try std.testing.expectEqualStrings("function f() {}", try formatRemoteObject(arena, p3.object));
}

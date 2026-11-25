//! evaluate_script - chrome-devtools-mcp's src/tools/script.ts
//! (chrome-devtools-mcp-v1.13.0), with the CDP Puppeteer sends for it
//! (puppeteer-core 25.17.0 src/cdp/ExecutionContext.ts #evaluate,
//! src/cdp/utils.ts createEvaluationError): the source made a function by
//! Runtime.evaluate in the main frame's main world, then called through
//! Runtime.callFunctionOn by chrome-devtools-mcp's wrapper, which returns
//! JSON.stringify of its awaited result and turns a non-Error throw into an
//! Error; format "script" evaluates the source and stringifies its value.
//! The action runs under WaitForHelper (wait.zig): dialogs are accepted
//! unless `dialogAction` says otherwise, and a navigation it causes is
//! reported. Translated from the TypeScript (Copyright 2025 Google LLC and
//! Copyright 2017 Google Inc., Apache-2.0; THIRD_PARTY_NOTICES.md).
//!
//! `sourcePath` and `filePath` (batch 3) go through the path policy
//! (paths.zig): checked before the page is resolved (verifyFilesSchema
//! {filePath: true, sourcePath: {allowUrl: true}}); the source read as
//! resolveScriptSource and loadResource read it - from a file: URL, or from
//! any other value as a path, an http(s) URL included (never fetched in
//! v1.13.0: Policy.loadScriptSource); the result written as .json with
//! "Script ran on page. Output saved to <file>." (performEvaluation).
//!
//! Not yet: the service worker target (extensions are a Chrome product).

const std = @import("std");
const Allocator = std.mem.Allocator;
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;
const wait = @import("../wait.zig");
const console = @import("../console.zig");
const elements = @import("../elements.zig");

pub const list = [_]Tool{
    // evaluate_script resolves its page itself (defineTool with
    // pageIdSchema): its response does not show the page's dialog.
    .{ .name = "evaluate_script", .page_tool = true, .set_page = false, .files = &.{ .{ .name = "filePath" }, .{ .name = "sourcePath", .allow_url = true } }, .run = evaluateScript },
};

/// PuppeteerURL.INTERNAL_URL's comment, which Puppeteer appends to what it
/// evaluates.
const source_url_comment = "//# sourceURL=pptr:internal";

/// chrome-devtools-mcp's performEvaluation callback (src/tools/script.ts).
const wrapper =
    \\async (fn, ...args) => {
    \\        try {
    \\          return JSON.stringify(await fn(...args));
    \\        } catch (err) {
    \\          if (
    \\            err instanceof Error ||
    \\            (typeof err === 'object' &&
    \\              err !== null &&
    \\              'message' in err &&
    \\              typeof err.message === 'string')
    \\          ) {
    \\            throw err;
    \\          }
    \\          let message;
    \\          try {
    \\            message =
    \\              typeof err === 'object' && err !== null
    \\                ? JSON.stringify(err)
    \\                : String(err);
    \\          } catch {
    \\            message = String(err);
    \\          }
    \\          throw new Error(message);
    \\        }
    \\      }
;

const stringify_value = "value => JSON.stringify(value)";

fn evaluateScript(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    const source = try resolveScriptSource(ctx, registry.stringArg(args, "function"), registry.stringArg(args, "sourcePath"));
    const file_path = registry.stringArg(args, "filePath");
    const format = registry.stringArg(args, "format") orelse "function";
    const uids: []const std.json.Value = if (args.get("args")) |a| (if (a == .array) a.array.items else &.{}) else &.{};
    if (std.mem.eql(u8, format, "script") and uids.len > 0) return ctx.fail("args cannot be used when format is \"script\".", .{});
    // throwIfDialogOpen: evaluate_script is not page-scoped in ToolHandler.
    if (target.dialog) |d| return ctx.fail("A dialog is open ({s}: {s}).", .{ d.type, d.message });
    // Element uids from the page's snapshot (McpPage.getElementByUid), all
    // in one frame (getPageOrFrame), released when the call is done.
    var handles: std.ArrayList(elements.Element) = .empty;
    defer for (handles.items) |h| if (h.object_id) |id| elements.release(ctx, target, id);
    var frame_id: ?[]const u8 = null;
    var different_frames = false;
    for (uids) |uid| {
        const element = try elements.byUid(ctx, target, session_mod.str(uid));
        try handles.append(ctx.arena, element);
        if (frame_id) |f| {
            if (!std.mem.eql(u8, f, element.frame_id)) different_frames = true;
        } else frame_id = element.frame_id;
    }
    if (different_frames) return ctx.fail("Elements from different frames can't be evaluated together.", .{});
    var arguments: std.Io.Writer.Allocating = .init(ctx.arena);
    for (handles.items) |h| try arguments.writer.print(",{s}", .{h.argument});
    // The frame's main world, or the page's (its main frame's).
    const context_id: ?i64 = if (frame_id) |f| try elements.mainWorld(ctx, target, f) else target.main_context_id;

    const dialog_action = registry.stringArg(args, "dialogAction") orelse "accept";
    const Evaluate = struct {
        page: *Page,
        context_id: ?i64,
        source: []const u8,
        script: bool,
        arguments: []const u8,
        file_path: ?[]const u8,
        response: *Response,

        pub fn run(self: @This(), c: *Context) !void {
            const where: Where = .{ .page = self.page, .context_id = self.context_id };
            const result = if (self.script) try evaluateAsScript(c, where, self.source) else try evaluateAsFunction(c, where, self.source, self.arguments);
            if (self.file_path) |path| {
                // `result ?? 'undefined'`: callWith already says "undefined".
                const saved = c.session.paths.saveFile(c.arena, result, path, ".json") catch |err| switch (err) {
                    error.Denied => return c.fail("{s}", .{c.session.paths.message}),
                    error.OutOfMemory => return error.OutOfMemory,
                };
                try self.response.line("Script ran on page. Output saved to {s}.", .{saved});
                return;
            }
            try self.response.line("Script ran on page and returned:", .{});
            try self.response.line("```json", .{});
            try self.response.line("{s}", .{result});
            try self.response.line("```", .{});
        }
    };
    const result = try wait.afterAction(ctx, target, .{
        .dialog_action = .{ .all = dialog_action },
        .wait_for_stable_dom = registry.boolArg(args, "waitForStableDom") orelse true,
    }, Evaluate{ .page = target, .context_id = context_id, .source = source, .script = std.mem.eql(u8, format, "script"), .arguments = arguments.written(), .file_path = file_path, .response = response });
    response.wait_result = result.forResponse();
}

/// resolveScriptSource (chrome-devtools-mcp v1.13.0 src/tools/script.ts):
/// exactly one of the inline source and the file; the file's text, or the
/// tool fails with why it could not be read.
fn resolveScriptSource(ctx: *Context, function: ?[]const u8, source_path: ?[]const u8) ![]const u8 {
    if (function) |inline_source| {
        if (source_path != null) return ctx.fail("Specify exactly one of function or sourcePath.", .{});
        return inline_source;
    }
    const path = source_path orelse return ctx.fail("Specify exactly one of function or sourcePath.", .{});
    return ctx.session.paths.loadScriptSource(ctx.arena, path) catch |err| switch (err) {
        error.Denied => ctx.fail("Unable to read script source from {s}: {s}", .{ path, ctx.session.paths.message }),
        error.OutOfMemory => error.OutOfMemory,
    };
}

/// Where an evaluation runs: the page's session, in a context (null: the
/// main frame's main world is not known yet).
const Where = struct {
    page: *Page,
    context_id: ?i64,
};

/// format "function": the result's text (`${result}`), the function
/// called with the element handles after it (`arguments`: each
/// CallArgument preceded by a comma).
fn evaluateAsFunction(ctx: *Context, where: Where, source: []const u8, arguments: []const u8) ![]const u8 {
    const trimmed = std.mem.trimEnd(u8, source, " \t\n\r\x0b\x0c");
    const function_source = if (std.mem.endsWith(u8, trimmed, ";")) trimmed[0 .. trimmed.len - 1] else trimmed;
    const expression = try std.fmt.allocPrint(ctx.arena, "(\n{s}\n)", .{function_source});
    const handle = try evaluateHandle(ctx, where, expression);
    defer if (handle.object_id) |id| elements.release(ctx, where.page, id);
    return callWith(ctx, where, wrapper, try std.fmt.allocPrint(ctx.arena, "{s}{s}", .{ handle.argument, arguments }), handle.object_id);
}

/// format "script".
fn evaluateAsScript(ctx: *Context, where: Where, source: []const u8) ![]const u8 {
    const handle = try evaluateHandle(ctx, where, source);
    defer if (handle.object_id) |id| elements.release(ctx, where.page, id);
    return callWith(ctx, where, stringify_value, handle.argument, handle.object_id);
}

const Handle = struct {
    /// Its CallArgument (convertArgument).
    argument: []const u8,
    /// Its remote object, released when done (`using`).
    object_id: ?[]const u8,
};

/// ExecutionContext.evaluateHandle(string): Runtime.evaluate in the
/// context, by reference.
fn evaluateHandle(ctx: *Context, where: Where, expression: []const u8) !Handle {
    const arena = ctx.arena;
    const with_url = if (hasSourceUrl(expression)) expression else try std.fmt.allocPrint(arena, "{s}\n{s}\n", .{ expression, source_url_comment });
    var params: std.Io.Writer.Allocating = .init(arena);
    try params.writer.print("{{\"expression\":{f}", .{std.json.fmt(with_url, .{})});
    if (where.context_id) |id| try params.writer.print(",\"contextId\":{d}", .{id});
    try params.writer.writeAll(",\"returnByValue\":false,\"awaitPromise\":true,\"userGesture\":true}");
    var r = try ctx.session.client.call("Runtime.evaluate", params.written(), where.page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = try answer(ctx, &r, "Runtime.evaluate");
    const remote = (result.object.get("result") orelse return ctx.fail("Protocol error (Runtime.evaluate): no result", .{})).object;
    var argument: std.Io.Writer.Allocating = .init(arena);
    var object_id: ?[]const u8 = null;
    if (remote.get("objectId")) |id| {
        object_id = try arena.dupe(u8, session_mod.str(id));
        try argument.writer.print("{{\"objectId\":{f}}}", .{std.json.fmt(id, .{})});
    } else if (remote.get("unserializableValue")) |u| {
        try argument.writer.print("{{\"unserializableValue\":{f}}}", .{std.json.fmt(u, .{})});
    } else if (remote.get("value")) |v| {
        try argument.writer.print("{{\"value\":{f}}}", .{std.json.fmt(v, .{})});
    } else try argument.writer.writeAll("{}");
    return .{ .argument = argument.written(), .object_id = object_id };
}

/// ExecutionContext.evaluate(fn, ...handles): Runtime.callFunctionOn by
/// value; the string it returns, or "undefined". `first_object` is the
/// first argument's remote object, which names the context when none is
/// known.
fn callWith(ctx: *Context, where: Where, declaration: []const u8, arguments: []const u8, first_object: ?[]const u8) ![]const u8 {
    const arena = ctx.arena;
    const with_url = try std.fmt.allocPrint(arena, "{s}\n{s}\n", .{ declaration, source_url_comment });
    var params: std.Io.Writer.Allocating = .init(arena);
    try params.writer.print("{{\"functionDeclaration\":{f}", .{std.json.fmt(with_url, .{})});
    if (where.context_id) |id| {
        try params.writer.print(",\"executionContextId\":{d}", .{id});
    } else if (first_object) |id| {
        // No context known yet: the argument's own.
        try params.writer.print(",\"objectId\":{f}", .{std.json.fmt(id, .{})});
    } else return ctx.fail("Execution context was destroyed, most likely because of a navigation.", .{});
    try params.writer.print(",\"arguments\":[{s}],\"returnByValue\":true,\"awaitPromise\":true,\"userGesture\":true}}", .{arguments});
    var r = try ctx.session.client.call("Runtime.callFunctionOn", params.written(), where.page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    const result = try answer(ctx, &r, "Runtime.callFunctionOn");
    const remote = (result.object.get("result") orelse return "undefined").object;
    const value = remote.get("value") orelse return "undefined";
    var out: std.Io.Writer.Allocating = .init(arena);
    try console.jsString(&out.writer, value);
    return out.written();
}

/// SOURCE_URL_REGEX: a line that is a sourceURL comment.
fn hasSourceUrl(expression: []const u8) bool {
    var lines = std.mem.splitScalar(u8, expression, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trimStart(u8, line, " \t");
        if (std.mem.startsWith(u8, trimmed, "//# sourceURL=") or std.mem.startsWith(u8, trimmed, "//@ sourceURL=")) return true;
    }
    return false;
}

/// The command's result, or the error Puppeteer throws: rewriteError for a
/// lost context, createEvaluationError for an exception.
fn answer(ctx: *Context, r: *const @import("../client.zig").Response, method: []const u8) !std.json.Value {
    if (r.errorMessage()) |message| {
        if (std.mem.endsWith(u8, message, "Cannot find context with specified id") or std.mem.endsWith(u8, message, "Inspected target navigated or closed")) {
            return ctx.fail("Execution context was destroyed, most likely because of a navigation.", .{});
        }
        return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
    }
    const result = r.result() orelse return ctx.fail("Protocol error ({s}): no result", .{method});
    if (result.object.get("exceptionDetails")) |details| if (details == .object) {
        return ctx.fail("{s}", .{try evaluationErrorMessage(ctx.arena, details.object)});
    };
    return result;
}

/// The message of createEvaluationError's error (what ToolHandler prints):
/// the details' text with no exception; a primitive's String(); else
/// getErrorDetails' message - the description without its stack lines and
/// without its "<className>: " prefix.
pub fn evaluationErrorMessage(arena: Allocator, details: std.json.ObjectMap) ![]const u8 {
    const exception_value = details.get("exception") orelse return session_mod.str(details.get("text"));
    if (exception_value != .object) return session_mod.str(details.get("text"));
    const exception = exception_value.object;
    const is_error = std.mem.eql(u8, session_mod.str(exception.get("type")), "object") and std.mem.eql(u8, session_mod.str(exception.get("subtype")), "error");
    if (!is_error and exception.get("objectId") == null) {
        // valueFromPrimitiveRemoteObject, then String().
        var out: std.Io.Writer.Allocating = .init(arena);
        if (exception.get("unserializableValue")) |u| {
            const text = session_mod.str(u);
            try out.writer.writeAll(if (std.mem.eql(u8, text, "-0")) "0" else if (std.mem.endsWith(u8, text, "n")) text[0 .. text.len - 1] else text);
        } else if (exception.get("value")) |v| try console.jsString(&out.writer, v) else try out.writer.writeAll("undefined");
        return out.written();
    }
    // getErrorDetails.
    var lines: std.ArrayList([]const u8) = .empty;
    if (exception.get("description")) |d| {
        var it = std.mem.splitSequence(u8, session_mod.str(d), "\n    at ");
        while (it.next()) |part| try lines.append(arena, part);
    }
    var frames: usize = 0;
    if (details.get("stackTrace")) |st| if (st == .object) if (st.object.get("callFrames")) |cf| if (cf == .array) {
        frames = cf.array.items.len;
    };
    const size = @min(frames, lines.items.len -| 1);
    lines.shrinkRetainingCapacity(lines.items.len - size);
    var message = try std.mem.join(arena, "\n", lines.items);
    const name = session_mod.str(exception.get("className"));
    if (name.len != 0 and message.len > name.len + 1 and std.mem.startsWith(u8, message, name) and std.mem.startsWith(u8, message[name.len..], ": ")) {
        message = message[name.len + 2 ..];
    }
    return message;
}

test "an evaluation error's message: the description without its stack and its class name" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const thrown =
        \\{"text":"Uncaught","exception":{"type":"object","subtype":"error","className":"TypeError","description":"TypeError: bad thing\n    at f (pptr:internal:2:7)\n    at g (pptr:internal:3:1)","objectId":"1"},"stackTrace":{"callFrames":[{},{}]}}
    ;
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena, thrown, .{});
    try std.testing.expectEqualStrings("bad thing", try evaluationErrorMessage(arena, parsed.object));
    const primitive =
        \\{"text":"Uncaught","exception":{"type":"string","value":"x"}}
    ;
    const p2 = try std.json.parseFromSliceLeaky(std.json.Value, arena, primitive, .{});
    try std.testing.expectEqualStrings("x", try evaluationErrorMessage(arena, p2.object));
}

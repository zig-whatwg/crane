//! Renderer-dependent MCP tools (design tmp/plans/mcp1-design.md §4 & §10
//! Batch 6): `take_screenshot`, `screencast_start`, `screencast_stop`,
//! `performance_start_trace`, `performance_stop_trace`, and
//! `performance_analyze_insight`.
//!
//! Listed in default `tools/list` with chrome-devtools-mcp v1.13.0's exact
//! schemas (`schemas/tools.json`) so clients discover the complete non-Chrome-
//! product tool surface (32 tools = 33 default minus Chrome-only
//! `lighthouse_audit`). Calling any of them returns a clear MCP tool error
//! naming the missing renderer rather than `"Tool <name> not found"`.
//! Crane never calls Google's CrUX API (design §4 & §11 Q4).

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const Page = @import("../session.zig").Page;
const Response = @import("../response.zig").Response;

pub const list = [_]Tool{
    .{ .name = "performance_analyze_insight", .page_tool = true, .blocked_by_dialog = false, .run = performanceAnalyzeInsight },
    .{ .name = "performance_start_trace", .page_tool = true, .blocked_by_dialog = true, .files = &.{.{ .name = "filePath" }}, .run = performanceStartTrace },
    .{ .name = "performance_stop_trace", .page_tool = true, .blocked_by_dialog = true, .files = &.{.{ .name = "filePath" }}, .run = performanceStopTrace },
    .{ .name = "screencast_start", .page_tool = true, .blocked_by_dialog = true, .files = &.{.{ .name = "filePath" }}, .run = screencastStart },
    .{ .name = "screencast_stop", .page_tool = true, .blocked_by_dialog = true, .run = screencastStop },
    .{ .name = "take_screenshot", .page_tool = true, .blocked_by_dialog = true, .files = &.{.{ .name = "filePath" }}, .run = takeScreenshot },
};

fn takeScreenshot(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("take_screenshot is not supported by Crane's MCP server: Crane is headless and has no renderer to capture screenshots.", .{});
}

fn screencastStart(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("screencast_start is not supported by Crane's MCP server: Crane is headless and has no renderer to record screencasts.", .{});
}

fn screencastStop(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("screencast_stop is not supported by Crane's MCP server: Crane is headless and has no renderer to record screencasts.", .{});
}

fn performanceStartTrace(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("performance_start_trace is not supported by Crane's MCP server: Crane is headless and has no renderer to record performance traces.", .{});
}

fn performanceStopTrace(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("performance_stop_trace is not supported by Crane's MCP server: Crane is headless and has no renderer to record performance traces.", .{});
}

fn performanceAnalyzeInsight(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    _ = .{ args, page, response };
    return ctx.fail("performance_analyze_insight is not supported by Crane's MCP server: Crane is headless and has no renderer to record or analyze performance traces.", .{});
}

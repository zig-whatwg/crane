//! emulate - chrome-devtools-mcp's src/tools/emulation.ts and
//! McpPage.emulate (chrome-devtools-mcp-v1.13.0, Copyright 2025 Google LLC,
//! Apache-2.0; THIRD_PARTY_NOTICES.md), with the CDP Puppeteer sends for each
//! setting (puppeteer-core 25.17.0 src/cdp/NetworkManager.ts
//! emulateNetworkConditions / setUserAgent / setExtraHTTPHeaders,
//! src/cdp/EmulationManager.ts emulateCPUThrottling / setGeolocation /
//! emulateMediaFeatures / emulateViewport; Copyright 2017 Google Inc.,
//! Apache-2.0). Every call applies every setting - "each call replaces all
//! emulation settings (except extraHttpHeaders)" - in McpPage's order:
//! network, CPU, geolocation, user agent, media features, extra headers,
//! viewport (a reload when mobile or touch changes, as Puppeteer's
//! setViewport reloads).
//!
//! Not yet (lane mcp1 batch 4b): geolocation (the Geolocation API, queued by
//! main) answers that Crane's MCP server does not support it yet; its "off"
//! value - what every call sends - is Crane's CDP answer.

const std = @import("std");
const registry = @import("../tools.zig");
const Context = registry.Context;
const Tool = registry.Tool;
const session_mod = @import("../session.zig");
const Page = session_mod.Page;
const Response = @import("../response.zig").Response;

pub const list = [_]Tool{
    .{ .name = "emulate", .page_tool = true, .blocked_by_dialog = true, .run = emulate },
};

/// VIEWPORT_FORMAT.
const viewport_format = "<width>x<height>x<devicePixelRatio>[,mobile][,touch][,landscape]";

/// A transform's failure (zodTransform): ToolHandler's validation error.
fn validationError(ctx: *Context, path: []const u8, message: []const u8) error{ToolFailed} {
    return ctx.failPlain("Input validation error: Invalid arguments for tool emulate: {s}: {s}", .{ path, message });
}

const Viewport = session_mod.Emulation.Viewport;

/// viewportTransform: '<width>x<height>x<devicePixelRatio>[,mobile][,touch][,landscape]'.
fn parseViewport(ctx: *Context, text: []const u8) !?Viewport {
    if (text.len == 0) return null;
    var parts = std.mem.splitScalar(u8, text, ',');
    const dimensions = parts.next().?;
    var viewport: Viewport = .{ .width = 0, .height = 0 };
    while (parts.next()) |tag| {
        if (std.mem.eql(u8, tag, "mobile")) {
            viewport.mobile = true;
        } else if (std.mem.eql(u8, tag, "touch")) {
            viewport.touch = true;
        } else if (std.mem.eql(u8, tag, "landscape")) {
            viewport.landscape = true;
        } else return validationError(ctx, "viewport", try std.fmt.allocPrint(ctx.arena, "Invalid viewport option \"{s}\". Expected \"mobile\", \"touch\", or \"landscape\" in '" ++ viewport_format ++ "'.", .{tag}));
    }
    var dims: [4][]const u8 = undefined;
    var count: usize = 0;
    var it = std.mem.splitScalar(u8, dimensions, 'x');
    while (it.next()) |d| : (count += 1) {
        if (count == dims.len) break;
        dims[count] = d;
    }
    if (count != 2 and count != 3) return validationError(ctx, "viewport", try std.fmt.allocPrint(ctx.arena, "Invalid viewport dimensions \"{s}\". Expected format '" ++ viewport_format ++ "'.", .{dimensions}));
    viewport.width = try integer(ctx, "viewport.width", dims[0]);
    viewport.height = try integer(ctx, "viewport.height", dims[1]);
    if (count == 3) {
        const scale = decimal(dims[2]) orelse return validationError(ctx, "viewport.deviceScaleFactor", "Expected a number");
        if (scale <= 0) return validationError(ctx, "viewport.deviceScaleFactor", "Too small: expected number to be >0");
        viewport.scale = scale;
    }
    return viewport;
}

/// integerStringSchema, then a positive integer.
fn integer(ctx: *Context, path: []const u8, text: []const u8) !i64 {
    const digits = if (text.len > 0 and (text[0] == '+' or text[0] == '-')) text[1..] else text;
    if (digits.len == 0) return validationError(ctx, path, "Expected an integer");
    for (digits) |c| if (!std.ascii.isDigit(c)) return validationError(ctx, path, "Expected an integer");
    const value = std.fmt.parseInt(i64, text, 10) catch return validationError(ctx, path, "Expected an integer");
    if (value <= 0) return validationError(ctx, path, "Too small: expected number to be >0");
    return value;
}

/// decimalStringSchema: /^[+-]?\d+(\.\d+)?$/.
fn decimal(text: []const u8) ?f64 {
    var rest = if (text.len > 0 and (text[0] == '+' or text[0] == '-')) text[1..] else text;
    const dot = std.mem.indexOfScalar(u8, rest, '.');
    const whole = if (dot) |d| rest[0..d] else rest;
    if (whole.len == 0) return null;
    for (whole) |c| if (!std.ascii.isDigit(c)) return null;
    if (dot) |d| {
        rest = rest[d + 1 ..];
        if (rest.len == 0) return null;
        for (rest) |c| if (!std.ascii.isDigit(c)) return null;
    }
    return std.fmt.parseFloat(f64, text) catch null;
}

const NetworkPreset = struct {
    offline: bool,
    latency: f64,
    download: f64,
    upload: f64,
};

/// Puppeteer's PredefinedNetworkConditions (puppeteer-core 25.17.0
/// src/cdp/PredefinedNetworkConditions.ts, Copyright 2021 Google Inc.,
/// Apache-2.0; THIRD_PARTY_NOTICES.md) plus McpPage's Offline preset.
fn predefinedNetworkCondition(name: []const u8) ?NetworkPreset {
    if (std.mem.eql(u8, name, "Offline")) return .{ .offline = true, .latency = 0, .download = 0, .upload = 0 };
    if (std.mem.eql(u8, name, "Slow 3G")) return .{ .offline = false, .latency = 400 * 5, .download = 500 * 1e3 / 8 * 0.8, .upload = 500 * 1e3 / 8 * 0.8 };
    if (std.mem.eql(u8, name, "Fast 3G")) return .{ .offline = false, .latency = 150 * 3.75, .download = 1.6 * 1e6 / 8 * 0.9, .upload = 750 * 1e3 / 8 * 0.9 };
    if (std.mem.eql(u8, name, "Slow 4G")) return .{ .offline = false, .latency = 150 * 3.75, .download = 1.6 * 1e6 / 8 * 0.9, .upload = 750 * 1e3 / 8 * 0.9 };
    if (std.mem.eql(u8, name, "Fast 4G")) return .{ .offline = false, .latency = 60 * 2.75, .download = 9 * 1e6 / 8 * 0.9, .upload = 1.5 * 1e6 / 8 * 0.9 };
    return null;
}

fn emulate(ctx: *Context, args: std.json.ObjectMap, page: ?*Page, response: *Response) anyerror!void {
    const target = page.?;
    // The transforms (zod's), before anything runs.
    const viewport = if (registry.stringArg(args, "viewport")) |v| try parseViewport(ctx, v) else null;
    var headers_json: ?[]const u8 = null;
    if (registry.stringArg(args, "extraHttpHeaders")) |text| headers_json = try extraHeaders(ctx, text);
    const network_conditions = registry.stringArg(args, "networkConditions");
    const network_preset: ?NetworkPreset = if (network_conditions) |nc|
        (if (nc.len == 0) null else predefinedNetworkCondition(nc) orelse return validationError(ctx, "networkConditions", "Invalid network condition"))
    else
        null;

    // Not yet: the settings whose CDP Crane cannot apply.
    if (registry.stringArg(args, "geolocation")) |g| if (g.len != 0) return ctx.fail("geolocation is not supported by Crane's MCP server yet.", .{});

    const cpu_rate: f64 = if (registry.numberArg(args, "cpuThrottlingRate")) |rate| (if (rate > 1) rate else 1) else 1;

    // emulateNetworkConditions: Puppeteer's NetworkManager sends
    // overrideNetworkState + emulateNetworkConditionsByRule.
    if (network_preset) |p| {
        const state_params = try std.fmt.allocPrint(
            ctx.arena,
            "{{\"offline\":{},\"latency\":{d},\"uploadThroughput\":{d},\"downloadThroughput\":{d}}}",
            .{ p.offline, p.latency, p.upload, p.download },
        );
        const rule_params = try std.fmt.allocPrint(
            ctx.arena,
            "{{\"matchedNetworkConditions\":[{{\"urlPattern\":\"\",\"offline\":{},\"latency\":{d},\"downloadThroughput\":{d},\"uploadThroughput\":{d}}}]}}",
            .{ p.offline, p.latency, p.download, p.upload },
        );
        try send(ctx, target, "Network.overrideNetworkState", state_params);
        try send(ctx, target, "Network.emulateNetworkConditionsByRule", rule_params);
    } else {
        try send(ctx, target, "Network.overrideNetworkState", "{\"offline\":false,\"latency\":0,\"uploadThroughput\":-1,\"downloadThroughput\":-1}");
        try send(ctx, target, "Network.emulateNetworkConditionsByRule", "{\"matchedNetworkConditions\":[{\"urlPattern\":\"\",\"offline\":false,\"latency\":0,\"downloadThroughput\":-1,\"uploadThroughput\":-1}]}");
    }
    // emulateCPUThrottling: McpPage sends Emulation.setCPUThrottlingRate on
    // the page session and, if open, the DevTools universe secondary session.
    const cpu_params = try std.fmt.allocPrint(ctx.arena, "{{\"rate\":{d}}}", .{cpu_rate});
    try send(ctx, target, "Emulation.setCPUThrottlingRate", cpu_params);
    if (target.debugger_session_id) |secondary| {
        var r = try ctx.session.client.call("Emulation.setCPUThrottlingRate", cpu_params, secondary, session_mod.command_timeout_ms);
        defer r.deinit();
        if (r.errorMessage()) |message| return ctx.fail("Protocol error (Emulation.setCPUThrottlingRate): {s}", .{message});
    }
    // setGeolocation(null).
    try send(ctx, target, "Emulation.clearGeolocationOverride", "{}");

    // setUserAgent: the override, or - to reset one applied - the
    // Browser's own user agent; nothing when none was ever applied.
    const user_agent = registry.stringArg(args, "userAgent") orelse "";
    if (user_agent.len != 0) {
        try send(ctx, target, "Network.setUserAgentOverride", try std.fmt.allocPrint(ctx.arena, "{{\"userAgent\":{f}}}", .{std.json.fmt(user_agent, .{})}));
        target.user_agent_emulated = true;
    } else if (target.user_agent_emulated) {
        const own = try browserUserAgent(ctx);
        try send(ctx, target, "Network.setUserAgentOverride", try std.fmt.allocPrint(ctx.arena, "{{\"userAgent\":{f}}}", .{std.json.fmt(own, .{})}));
        target.user_agent_emulated = false;
    }

    // #emulateMediaFeatures: every feature, "" for none ("auto" too).
    var media: std.Io.Writer.Allocating = .init(ctx.arena);
    try media.writer.writeAll("{\"features\":[");
    const features = [_][2][]const u8{ .{ "prefers-color-scheme", "colorScheme" }, .{ "forced-colors", "forcedColors" }, .{ "prefers-contrast", "prefersContrast" }, .{ "prefers-reduced-motion", "prefersReducedMotion" } };
    for (features, 0..) |f, i| {
        var value = registry.stringArg(args, f[1]) orelse "";
        if (std.mem.eql(u8, value, "auto")) value = "";
        if (i != 0) try media.writer.writeAll(",");
        try media.writer.print("{{\"name\":\"{s}\",\"value\":{f}}}", .{ f[0], std.json.fmt(value, .{}) });
    }
    try media.writer.writeAll("]}");
    try send(ctx, target, "Emulation.setEmulatedMedia", media.written());

    // setExtraHTTPHeaders, only when given.
    if (headers_json) |json| try send(ctx, target, "Network.setExtraHTTPHeaders", json);

    // McpPage's emulationSettings, set before setViewport; a viewport that
    // fails keeps the one before it.
    const recorded_nc: ?[]const u8 = if (network_preset != null) network_conditions else null;
    try recordSettings(ctx, target, args, user_agent, recorded_nc, cpu_rate);
    // setViewport: the override (or its clear), then a reload when mobile
    // or touch changed.
    try applyViewport(ctx, target, viewport);
    target.emulation.viewport = viewport;
    try response.line("Emulation configured successfully", .{});
}

/// McpPage.emulate's newSettings for what Crane applies: each setting the
/// call names, none for one it leaves out or sets to "auto".
fn recordSettings(ctx: *Context, page: *Page, args: std.json.ObjectMap, user_agent: []const u8, network_conditions: ?[]const u8, cpu_rate: f64) !void {
    const allocator = ctx.session.allocator;
    var next: session_mod.Emulation = .{ .viewport = page.emulation.viewport, .cpu_throttling_rate = cpu_rate };
    errdefer next.deinit(allocator);
    if (network_conditions) |nc| next.network_conditions = try allocator.dupe(u8, nc);
    if (user_agent.len != 0) next.user_agent = try allocator.dupe(u8, user_agent);
    const features = .{ .{ "color_scheme", "colorScheme" }, .{ "forced_colors", "forcedColors" }, .{ "prefers_contrast", "prefersContrast" }, .{ "prefers_reduced_motion", "prefersReducedMotion" } };
    inline for (features) |f| {
        const value = registry.stringArg(args, f[1]) orelse "";
        if (value.len != 0 and !std.mem.eql(u8, value, "auto")) @field(next, f[0]) = try allocator.dupe(u8, value);
    }
    page.emulation.deinit(allocator);
    page.emulation = next;
}

/// headerStringTransform, then Puppeteer's setExtraHTTPHeaders (each value
/// a string; names lowercased): the CDP params, or the tool's error.
fn extraHeaders(ctx: *Context, text: []const u8) ![]const u8 {
    if (text.len == 0) return "{\"headers\":{}}";
    const parsed = std.json.parseFromSliceLeaky(std.json.Value, ctx.arena, text, .{}) catch |err| {
        return validationError(ctx, "extraHttpHeaders", try std.fmt.allocPrint(ctx.arena, "Invalid JSON for headers: {t}", .{err}));
    };
    if (parsed != .object) return validationError(ctx, "extraHttpHeaders", "Invalid JSON for headers: Headers must be a JSON object");
    var out: std.Io.Writer.Allocating = .init(ctx.arena);
    try out.writer.writeAll("{\"headers\":{");
    var it = parsed.object.iterator();
    var first = true;
    while (it.next()) |e| {
        if (e.value_ptr.* != .string) return ctx.fail("Expected value of header \"{s}\" to be String, but \"{s}\" is found.", .{ e.key_ptr.*, jsTypeOf(e.value_ptr.*) });
        const lower = try std.ascii.allocLowerString(ctx.arena, e.key_ptr.*);
        if (!first) try out.writer.writeAll(",");
        first = false;
        try out.writer.print("{f}:{f}", .{ std.json.fmt(lower, .{}), std.json.fmt(e.value_ptr.string, .{}) });
    }
    try out.writer.writeAll("}}");
    return out.written();
}

/// JavaScript's typeof for a parsed JSON value.
fn jsTypeOf(value: std.json.Value) []const u8 {
    return switch (value) {
        .null, .object, .array => "object",
        .bool => "boolean",
        .integer, .float, .number_string => "number",
        .string => "string",
    };
}

fn applyViewport(ctx: *Context, page: *Page, viewport: ?Viewport) !void {
    const v = viewport orelse {
        // emulateViewport(null): nothing while none is active.
        if (!page.viewport_emulated) return;
        page.viewport_emulated = false;
        try send(ctx, page, "Emulation.clearDeviceMetricsOverride", "{}");
        try send(ctx, page, "Emulation.setTouchEmulationEnabled", "{\"enabled\":false}");
        const reload = page.emulating_mobile or page.emulating_touch;
        page.emulating_mobile = false;
        page.emulating_touch = false;
        if (reload) try reloadPage(ctx, page);
        return;
    };
    const orientation = if (v.landscape) "{\"angle\":90,\"type\":\"landscapePrimary\"}" else "{\"angle\":0,\"type\":\"portraitPrimary\"}";
    try send(ctx, page, "Emulation.setDeviceMetricsOverride", try std.fmt.allocPrint(ctx.arena, "{{\"mobile\":{},\"width\":{d},\"height\":{d},\"deviceScaleFactor\":{d},\"screenOrientation\":{s}}}", .{ v.mobile, v.width, v.height, v.scale orelse 1, orientation }));
    try send(ctx, page, "Emulation.setTouchEmulationEnabled", if (v.touch) "{\"enabled\":true}" else "{\"enabled\":false}");
    const reload = page.emulating_mobile != v.mobile or page.emulating_touch != v.touch;
    page.viewport_emulated = true;
    page.emulating_mobile = v.mobile;
    page.emulating_touch = v.touch;
    if (reload) try reloadPage(ctx, page);
}

/// Puppeteer's page.reload(): Page.reload, then the load.
fn reloadPage(ctx: *Context, page: *Page) !void {
    page.load_fired = false;
    try send(ctx, page, "Page.reload", "{}");
    const Loaded = struct {
        page: *Page,
        fn done(self: @This()) bool {
            return self.page.load_fired or self.page.closed;
        }
    };
    if (!try ctx.session.waitUntil(session_mod.command_timeout_ms, Loaded{ .page = page }, Loaded.done)) return ctx.fail("Navigation timeout of {d} ms exceeded", .{session_mod.command_timeout_ms});
}

/// The Browser's own user agent (Browser.getVersion, which Puppeteer's
/// browser.userAgent() reads).
fn browserUserAgent(ctx: *Context) ![]const u8 {
    var r = try ctx.session.client.call("Browser.getVersion", "{}", "", session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error (Browser.getVersion): {s}", .{message});
    const result = r.result() orelse return ctx.fail("Protocol error (Browser.getVersion): no result", .{});
    return ctx.arena.dupe(u8, session_mod.str(result.object.get("userAgent")));
}

fn send(ctx: *Context, page: *Page, method: []const u8, params: []const u8) !void {
    var r = try ctx.session.client.call(method, params, page.session_id, session_mod.command_timeout_ms);
    defer r.deinit();
    if (r.errorMessage()) |message| return ctx.fail("Protocol error ({s}): {s}", .{ method, message });
}

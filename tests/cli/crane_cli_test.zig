const std = @import("std");
const testing = std.testing;
const crane = @import("crane");
const browser_mod = @import("browser");
const devtools = @import("devtools");
const developer_console = browser_mod.Browser.developer_console;

test "crane CLI: default options enable both CDP (9222) and MCP (9223)" {
    var bad: []const u8 = "";
    const opts = try crane.parseOptions(&.{}, &bad);

    try testing.expectEqualStrings("about:blank", opts.url);
    try testing.expect(!opts.url_provided);
    try testing.expectEqual(@as(?u16, 9222), opts.remote_debugging_port);
    try testing.expectEqual(@as(?u16, 9223), opts.mcp_port);
    try testing.expectEqualStrings("127.0.0.1", opts.mcp_host);
    try testing.expect(!opts.mcp);
    try testing.expect(!opts.remote_debugging_pipe);
    try testing.expect(!opts.version);
    try testing.expect(!opts.help);
}

test "crane CLI: URL positional argument and port overrides (0, explicit, off, none)" {
    var bad: []const u8 = "";
    const opts1 = try crane.parseOptions(&.{
        "--remote-debugging-port=0",
        "--mcp-port=0",
        "https://example.com/page",
    }, &bad);
    try testing.expectEqual(@as(?u16, 0), opts1.remote_debugging_port);
    try testing.expectEqual(@as(?u16, 0), opts1.mcp_port);
    try testing.expectEqualStrings("https://example.com/page", opts1.url);
    try testing.expect(opts1.url_provided);

    const opts2 = try crane.parseOptions(&.{
        "--remote-debugging-port=off",
        "--mcp-port=none",
    }, &bad);
    try testing.expectEqual(@as(?u16, null), opts2.remote_debugging_port);
    try testing.expectEqual(@as(?u16, null), opts2.mcp_port);

    const opts3 = try crane.parseOptions(&.{
        "--remote-debugging-port",
        "9333",
        "--mcp-port",
        "9444",
    }, &bad);
    try testing.expectEqual(@as(?u16, 9333), opts3.remote_debugging_port);
    try testing.expectEqual(@as(?u16, 9444), opts3.mcp_port);
}

test "crane CLI: --mcp stdio mode disables default TCP ports unless explicitly requested" {
    var bad: []const u8 = "";
    const opts = try crane.parseOptions(&.{"--mcp"}, &bad);
    try testing.expect(opts.mcp);
    try testing.expectEqual(@as(?u16, null), opts.remote_debugging_port);
    try testing.expectEqual(@as(?u16, null), opts.mcp_port);
}

test "crane CLI: --remote-debugging-pipe disables default TCP ports unless explicitly requested" {
    var bad: []const u8 = "";
    const opts = try crane.parseOptions(&.{"--remote-debugging-pipe"}, &bad);
    try testing.expect(opts.remote_debugging_pipe);
    try testing.expectEqual(@as(?u16, null), opts.remote_debugging_port);
    try testing.expectEqual(@as(?u16, null), opts.mcp_port);
}

test "crane CLI: parses all MCP, CDP, and browser flags (kebab and camelCase)" {
    var bad: []const u8 = "";
    const opts = try crane.parseOptions(&.{
        "--remote-allow-origins=http://localhost:3000,*",
        "--mcp-host=0.0.0.0",
        "--mcp-tls",
        "--mcp-cert=/tmp/cert.pem",
        "--mcp-key=/tmp/key.pem",
        "--workspace=/tmp/w1",
        "--filesystem-root=/tmp/w2",
        "--filesystemRoot",
        "/tmp/w3",
        "--allow-unrestricted-paths",
        "--memory-debugging",
        "--category-network-mocks",
        "--slim",
        "--user-data-dir=/tmp/profile",
        "--isolated",
        "--viewport=1280x720",
        "--accept-insecure-certs",
        "--headless=new",
        "--user-agent=CraneTest/0.1",
        "--ca-bundle=/tmp/ca.pem",
        "--proxy=direct",
        "--no-startup-window",
        "--version",
        "--help",
        "--smoke-crash",
    }, &bad);

    try testing.expectEqualStrings("http://localhost:3000,*", opts.remote_allow_origins.?);
    try testing.expectEqualStrings("0.0.0.0", opts.mcp_host);
    try testing.expect(opts.mcp_tls);
    try testing.expectEqualStrings("/tmp/cert.pem", opts.mcp_cert.?);
    try testing.expectEqualStrings("/tmp/key.pem", opts.mcp_key.?);
    try testing.expectEqual(@as(usize, 3), opts.filesystem_root_count);
    try testing.expectEqualStrings("/tmp/w1", opts.filesystem_roots[0]);
    try testing.expectEqualStrings("/tmp/w2", opts.filesystem_roots[1]);
    try testing.expectEqualStrings("/tmp/w3", opts.filesystem_roots[2]);
    try testing.expect(opts.allow_unrestricted_paths);
    try testing.expect(opts.memory_debugging);
    try testing.expect(opts.category_network_mocks);
    try testing.expect(opts.slim);
    try testing.expectEqualStrings("/tmp/profile", opts.user_data_dir.?);
    try testing.expect(opts.isolated);
    try testing.expectEqual(@as(i32, 1280), opts.viewport.?.width);
    try testing.expectEqual(@as(i32, 720), opts.viewport.?.height);
    try testing.expect(opts.accept_insecure_certs);
    try testing.expect(opts.headless);
    try testing.expectEqualStrings("CraneTest/0.1", opts.user_agent.?);
    try testing.expectEqualStrings("/tmp/ca.pem", opts.ca_bundle.?);
    try testing.expect(opts.proxy == .direct);
    try testing.expect(opts.no_startup_window);
    try testing.expect(opts.version);
    try testing.expect(opts.help);
    try testing.expect(opts.smoke_crash);

    // CamelCase aliases
    const opts_camel = try crane.parseOptions(&.{
        "--allowUnrestrictedPaths",
        "--memoryDebugging",
        "--categoryNetworkMocks",
        "--userDataDir=/tmp/p2",
        "--acceptInsecureCerts",
        "--viewport",
        "800X600",
    }, &bad);
    try testing.expect(opts_camel.allow_unrestricted_paths);
    try testing.expect(opts_camel.memory_debugging);
    try testing.expect(opts_camel.category_network_mocks);
    try testing.expectEqualStrings("/tmp/p2", opts_camel.user_data_dir.?);
    try testing.expect(opts_camel.accept_insecure_certs);
    try testing.expectEqual(@as(i32, 800), opts_camel.viewport.?.width);
    try testing.expectEqual(@as(i32, 600), opts_camel.viewport.?.height);
}

test "crane CLI: rejects unknown flags, invalid ports, invalid viewports, extra URLs, and refused flags" {
    var bad: []const u8 = "";

    try testing.expectError(error.UnknownOption, crane.parseOptions(&.{"--not-a-flag"}, &bad));
    try testing.expectEqualStrings("--not-a-flag", bad);

    try testing.expectError(error.InvalidPort, crane.parseOptions(&.{"--remote-debugging-port=abc"}, &bad));
    try testing.expectError(error.InvalidPort, crane.parseOptions(&.{"--mcp-port=99999"}, &bad));
    try testing.expectError(error.InvalidViewport, crane.parseOptions(&.{"--viewport=wide"}, &bad));
    try testing.expectError(error.InvalidViewport, crane.parseOptions(&.{"--viewport=0x600"}, &bad));
    try testing.expectError(error.TooManyArguments, crane.parseOptions(&.{ "https://a.test", "https://b.test" }, &bad));

    const refused = [_][]const u8{
        "--executablePath=/usr/bin/chrome",
        "--browserUrl=http://127.0.0.1:9222",
        "--wsEndpoint=ws://127.0.0.1:9222/devtools/browser/1",
        "--autoConnect",
        "--channel=canary",
    };
    for (refused) |flag| {
        try testing.expectError(error.RefusedOption, crane.parseOptions(&.{flag}, &bad));
        try testing.expectEqualStrings(flag, bad);
    }
}

test "crane CLI: startup banner includes version, SHA, CDP URL, MCP URL, bearer token, and TLS fingerprint" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();

    try crane.writeStartupBanner(&out.writer, .{
        .version = "0.1.0",
        .git_sha = "8e14eb4dc",
        .cdp_url = "ws://127.0.0.1:9222/devtools/browser/abc",
        .mcp_scheme = "https",
        .mcp_host = "127.0.0.1",
        .mcp_port = 9223,
        .mcp_bearer_token = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        .mcp_cert_fingerprint = "AA:BB:CC:DD",
    });

    const text = out.written();
    try testing.expect(std.mem.indexOf(u8, text, "crane 0.1.0 (8e14eb4dc)") != null);
    try testing.expect(std.mem.indexOf(u8, text, "DevTools listening on ws://127.0.0.1:9222/devtools/browser/abc") != null);
    try testing.expect(std.mem.indexOf(u8, text, "MCP listening on https://127.0.0.1:9223/mcp") != null);
    try testing.expect(std.mem.indexOf(u8, text, "MCP bearer token: 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef") != null);
    try testing.expect(std.mem.indexOf(u8, text, "MCP TLS SHA-256 fingerprint: AA:BB:CC:DD") != null);
}

test "crane CLI: formats console, exception, rejection, and navigation events" {
    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();

    try crane.formatConsoleMessage(&out.writer, .console, .log, "", "ran 42", .{});
    try crane.formatConsoleMessage(&out.writer, .console, .warn, "[tab 2] ", "careful", .{});
    try crane.formatConsoleMessage(&out.writer, .exception, .@"error", "", "Uncaught Error: boom", .{ .url = "https://example.com/app.js", .line = 12, .column = 4 });
    try crane.formatConsoleMessage(&out.writer, .rejection, .@"error", "", "Uncaught (in promise) nope", .{});

    const started: browser_mod.host_events.Milestone = .{
        .navigable_id = 1,
        .navigation_id = 1,
        .event = .{ .started = .{ .url = "https://example.com/", .initiator = .browser_ui } },
    };
    try crane.formatNavigationEvent(&out.writer, "", &started, 0);

    var dummy_doc: u8 = 0;
    const committed: browser_mod.host_events.Milestone = .{
        .navigable_id = 1,
        .navigation_id = 1,
        .event = .{ .committed = .{
            .url = "https://example.com/",
            .document = .{ .document = &dummy_doc, .generation = 1 },
            .mime_type = "text/html",
            .kind = .regular,
        } },
    };
    try crane.formatNavigationEvent(&out.writer, "", &committed, 200);

    const text = out.written();
    try testing.expect(std.mem.indexOf(u8, text, "[console.log] ran 42\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "[tab 2] [console.warn] careful\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "[exception] Uncaught Error: boom\n    at https://example.com/app.js:12:4\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "[rejection] Uncaught (in promise) nope\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Navigating to https://example.com/\n") != null);
    try testing.expect(std.mem.indexOf(u8, text, "Navigated to https://example.com/ (200)\n") != null);
}

test "crane CLI: live Logger captures navigations and console.log from a real BrowserHost with 0 leaks" {
    const host = try browser_mod.BrowserHost.start(testing.allocator, .{});
    defer host.stop();

    var out: std.Io.Writer.Allocating = .init(testing.allocator);
    defer out.deinit();

    var logger = crane.Logger.init(testing.allocator, &out.writer);
    try logger.attach(host);
    defer logger.detach(host);

    const Nav = struct {
        url: []const u8,
        err: ?anyerror = null,
        fn run(ctx: ?*anyopaque, b: *browser_mod.Browser) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            const id = b.hostTraversableId() orelse return;
            b.navigateTraversable(id, self.url) catch |e| {
                self.err = e;
            };
        }
    };
    var nav: Nav = .{ .url = "data:text/html,<script>console.log('ran', 6*7);</script>" };
    try host.call(&nav, Nav.run);
    if (nav.err) |e| return e;

    // Wait briefly until the page finishes loading and console.log is logged.
    const deadline_ms: u64 = 5_000;
    const start_ns = @import("platform").monotonicNow().ns;
    while (true) {
        const has_log = blk: {
            std.Io.Threaded.mutexLockUncancelable(&logger.mutex);
            defer std.Io.Threaded.mutexUnlock(&logger.mutex);
            break :blk std.mem.indexOf(u8, out.written(), "[console.log] ran 42") != null and
                std.mem.indexOf(u8, out.written(), "Navigated to data:text/html,") != null;
        };
        if (has_log) break;
        const elapsed_ms = (@import("platform").monotonicNow().ns -| start_ns) / std.time.ns_per_ms;
        if (elapsed_ms >= deadline_ms) break;
        try testing.io.sleep(.fromMilliseconds(10), .awake);
    }

    std.Io.Threaded.mutexLockUncancelable(&logger.mutex);
    const logged = try testing.allocator.dupe(u8, out.written());
    std.Io.Threaded.mutexUnlock(&logger.mutex);
    defer testing.allocator.free(logged);

    try testing.expect(std.mem.indexOf(u8, logged, "Navigating to data:text/html,") != null);
    try testing.expect(std.mem.indexOf(u8, logged, "[console.log] ran 42") != null);
    try testing.expect(std.mem.indexOf(u8, logged, "Navigated to data:text/html,") != null);
}

test "crane CLI: CDP and HTTP MCP servers share one BrowserHost and devtools.Server cleanly with 0 leaks" {
    if (!devtools.enabled) return error.SkipZigTest;

    const host = try browser_mod.BrowserHost.start(testing.allocator, .{});
    defer host.stop();

    const dt_server = try devtools.Server.start(testing.allocator, .{
        .port = 0,
        .default_host = host,
    });
    defer dt_server.stop();

    const http_srv = try devtools.mcp.http.HttpServer.start(testing.allocator, dt_server, .{
        .host = "127.0.0.1",
        .port = 0,
    });
    defer http_srv.stop();

    try testing.expect(dt_server.port > 0);
    try testing.expect(http_srv.boundPort() > 0);
    try testing.expect(dt_server.port != http_srv.boundPort());
    try testing.expectEqual(@as(usize, 64), http_srv.bearerToken().len);
}

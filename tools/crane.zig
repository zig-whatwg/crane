//! Crane headless browser CLI (`crane`).
//!
//! Default behavior (`crane` or `crane [url]`):
//! - Runs as a headless browser daemon with a single shared `BrowserHost`.
//! - Starts BOTH Chrome DevTools Protocol (`127.0.0.1:9222`, overridable via
//!   `--remote-debugging-port=<n|0|off>`) AND Streamable HTTP MCP
//!   (`127.0.0.1:9223`, overridable via `--mcp-port=<n|0|off>`) sharing the
//!   same `Browser` and `devtools.Server`.
//! - Prints a structured startup banner (version, commit SHA, CDP WebSocket
//!   URL, MCP endpoint URL, 256-bit Bearer token, and TLS SHA-256 fingerprint
//!   when TLS is enabled).
//! - Opens `[url]` (default `about:blank`) and streams live structured logs of
//!   navigations, `console.*` messages, uncaught JS exceptions, unhandled
//!   promise rejections, and tab lifecycle events until `Ctrl-C` (`SIGINT` /
//!   `SIGTERM`) or `Browser.close` shuts everything down cleanly with 0 leaks.
//!
//! Alternate transport modes:
//! - `--mcp`: Chrome DevTools MCP over stdin/stdout (no banner/logs on stdout).
//! - `--remote-debugging-pipe`: CDP over inherited descriptors 3 (in) and 4 (out).

const std = @import("std");
const engine = @import("engine");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserConfig = browser_mod.BrowserConfig;
const BrowserHost = browser_mod.BrowserHost;
const developer_console = Browser.developer_console;
const host_events = browser_mod.host_events;
const devtools = @import("devtools");
const platform = @import("platform");
const crash_handler = @import("crash_handler");
const crane_options = @import("crane_options");

/// No debug log spam in user-facing output; no 256 KiB thread-local signal
/// stack (main attaches the platform alternate signal stack instead so every
/// thread stays within the thread-local size budget).
pub const std_options: std.Options = .{
    .log_level = .warn,
    .signal_stack_size = null,
};

pub const build_info: crash_handler.BuildInfo = .{
    .version = crane_options.version,
    .git_sha = crane_options.git_sha,
};

pub const panic = crash_handler.PanicHandler(build_info);

pub const debug = struct {
    pub const handleSegfault = crash_handler.handleSegfault;
};

// ============================================================================
// Command-line options
// ============================================================================

pub const default_cdp_port: u16 = 9222;
pub const default_mcp_port: u16 = 9223;
pub const max_filesystem_roots = 16;

pub const Options = struct {
    /// The initial URL to open (default `about:blank`).
    url: []const u8 = "about:blank",
    /// Whether the user supplied a positional URL argument.
    url_provided: bool = false,
    /// CDP TCP port (`9222` by default in daemon mode; `0` for ephemeral; `null` for off).
    remote_debugging_port: ?u16 = default_cdp_port,
    remote_debugging_port_explicit: bool = false,
    /// CDP over inherited FDs 3 (read) and 4 (write).
    remote_debugging_pipe: bool = false,
    /// Comma-separated origins allowed for CDP/MCP WebSocket/HTTP connections, or `*`.
    remote_allow_origins: ?[]const u8 = null,
    /// Serve MCP over stdin/stdout (no banner or logs on stdout).
    mcp: bool = false,
    /// Streamable HTTP MCP TCP port (`9223` by default in daemon mode; `0` for ephemeral; `null` for off).
    mcp_port: ?u16 = default_mcp_port,
    mcp_port_explicit: bool = false,
    /// Bind address for Streamable HTTP MCP (default `127.0.0.1`; non-loopback requires TLS).
    mcp_host: []const u8 = "127.0.0.1",
    /// Enable TLS on loopback too (ephemeral self-signed cert unless cert/key provided).
    mcp_tls: bool = false,
    /// Optional host-supplied TLS certificate PEM path.
    mcp_cert: ?[]const u8 = null,
    /// Optional host-supplied TLS private key PEM path.
    mcp_key: ?[]const u8 = null,
    /// Repeatable `--workspace` / `--filesystem-root` / `--filesystemRoot` directories.
    filesystem_roots: [max_filesystem_roots][]const u8 = undefined,
    filesystem_root_count: usize = 0,
    /// Allow unrestricted filesystem paths when the MCP client lists no roots.
    allow_unrestricted_paths: bool = false,
    /// Enable MCP heap snapshot / memory debugging tools.
    memory_debugging: bool = false,
    /// Enable MCP network mocking tools.
    category_network_mocks: bool = false,
    /// Expose only the slim MCP tool set.
    slim: bool = false,
    /// Persistent profile directory (`--user-data-dir` / `--userDataDir`).
    user_data_dir: ?[]const u8 = null,
    /// Force an in-memory profile-less Browser.
    isolated: bool = false,
    /// Initial top-level viewport size (`<width>x<height>`).
    viewport: ?Viewport = null,
    /// Disable TLS certificate verification.
    accept_insecure_certs: bool = false,
    /// Additional trusted CA bundle PEM path.
    ca_bundle: ?[]const u8 = null,
    /// Override User-Agent header and `navigator.userAgent`.
    user_agent: ?[]const u8 = null,
    /// Proxy setting (`system`, `direct`, or proxy URL).
    proxy: BrowserConfig.Proxy = .system,
    /// Chrome's `--proxy-server=<rules>`.
    proxy_server: ?[]const u8 = null,
    /// Chrome's `--proxy-bypass-list=<rules>`.
    proxy_bypass_list: ?[]const u8 = null,
    /// Start without opening a first window/page.
    no_startup_window: bool = false,
    /// Accepted for Chrome launcher compatibility (Crane is always headless).
    headless: bool = false,
    /// Use a leak-checking allocator and report leaks on exit.
    check_leaks: bool = false,
    /// Print version and exit.
    version: bool = false,
    /// Print usage help and exit.
    help: bool = false,
    /// Hidden test flag: trigger an intentional panic to verify the crash banner.
    smoke_crash: bool = false,

    pub const Viewport = struct { width: i32, height: i32 };
};

pub const usage =
    \\usage: crane [url] [options]
    \\
    \\Run Crane as a headless browser daemon with CDP and Streamable HTTP MCP
    \\enabled on a shared Browser instance. Streams live navigation, console, and
    \\error logs until Ctrl-C (SIGINT/SIGTERM) shuts down cleanly.
    \\
    \\Default servers:
    \\  --remote-debugging-port=<n|off>  CDP WebSocket/HTTP port (default: 9222;
    \\                                   0 = ephemeral port; off/none = disabled)
    \\  --mcp-port=<n|off>               Streamable HTTP MCP port (default: 9223;
    \\                                   0 = ephemeral port; off/none = disabled)
    \\  --mcp-host=<addr>                Bind host for HTTP MCP (default: 127.0.0.1;
    \\                                   non-loopback requires TLS)
    \\  --mcp-tls                        Require TLS on loopback too (ephemeral cert)
    \\  --mcp-cert=<pem>                 Host TLS certificate PEM for HTTP MCP
    \\  --mcp-key=<pem>                  Host TLS private key PEM for HTTP MCP
    \\  --remote-allow-origins=<list>    Comma-separated allowed origins, or *
    \\
    \\Alternate transport modes:
    \\  --mcp                            Serve MCP over stdin/stdout (no stdout logs)
    \\  --remote-debugging-pipe          Serve CDP over inherited FDs 3 (in) / 4 (out)
    \\
    \\MCP tool & filesystem options:
    \\  --workspace=<dir>                Allowed directory for MCP file tools
    \\                                   (repeatable; also --filesystem-root,
    \\                                   --filesystemRoot)
    \\  --allow-unrestricted-paths       Disable MCP path checks when no roots set
    \\  --memory-debugging               Enable MCP heap snapshot analysis tools
    \\  --category-network-mocks         Enable MCP network mocking tools
    \\  --slim                           Expose only the slim MCP tool set
    \\
    \\Browser & network options:
    \\  --user-data-dir=<dir>            Profile directory (also --userDataDir)
    \\  --isolated                       In-memory Browser without a profile dir
    \\  --viewport=<WxH>                 Initial viewport in CSS px (e.g. 1280x720)
    \\  --accept-insecure-certs          Skip TLS certificate verification
    \\  --ca-bundle=<pem>                Additional trusted CA bundle PEM
    \\  --user-agent=<s>                 Override User-Agent string
    \\  --proxy=system|direct|<url>      Proxy mode (default: system)
    \\  --proxy-server=<rules>           Chrome proxy rules
    \\  --proxy-bypass-list=<rules>      Chrome proxy bypass rules
    \\  --no-startup-window              Do not navigate the initial tab on startup
    \\  --headless[=new|old]             Accepted (Crane is always headless)
    \\  --check-leaks                    Use leak-checking allocator and report at exit
    \\  --version, -v                    Print version and commit SHA
    \\  --help, -h                       Show this help message
    \\
;

pub const OptionsError = error{
    UnknownOption,
    MissingValue,
    TooManyArguments,
    InvalidPort,
    InvalidViewport,
    RefusedOption,
};

const filesystem_root_flags = [_][]const u8{
    "--filesystem-root",
    "--filesystemRoot",
    "--workspace",
};

const refused_flags = [_][]const u8{
    "--executablePath",
    "--executable-path",
    "--browserUrl",
    "--browser-url",
    "--wsEndpoint",
    "--ws-endpoint",
    "--autoConnect",
    "--auto-connect",
    "--channel",
};

fn isRefusedFlag(arg: []const u8) bool {
    for (refused_flags) |flag| {
        if (std.mem.eql(u8, arg, flag) or valueOf(arg, flag) != null) return true;
    }
    return false;
}

fn valueOf(arg: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name)) return null;
    if (arg.len == name.len or arg[name.len] != '=') return null;
    return arg[name.len + 1 ..];
}

fn takeFlagValue(args: []const []const u8, index: *usize, flag: []const u8) OptionsError!?[]const u8 {
    const arg = args[index.*];
    if (valueOf(arg, flag)) |value| {
        if (value.len == 0) return error.MissingValue;
        return value;
    }
    if (std.mem.eql(u8, arg, flag)) {
        index.* += 1;
        if (index.* >= args.len) return error.MissingValue;
        if (args[index.*].len == 0) return error.MissingValue;
        return args[index.*];
    }
    return null;
}

fn parseOptionalPort(text: []const u8) OptionsError!?u16 {
    if (std.ascii.eqlIgnoreCase(text, "off") or std.ascii.eqlIgnoreCase(text, "none")) {
        return null;
    }
    return std.fmt.parseUnsigned(u16, text, 10) catch return error.InvalidPort;
}

fn parseViewport(text: []const u8) OptionsError!Options.Viewport {
    const sep = std.mem.indexOfAny(u8, text, "xX") orelse return error.InvalidViewport;
    const w = std.fmt.parseUnsigned(i32, text[0..sep], 10) catch return error.InvalidViewport;
    const h = std.fmt.parseUnsigned(i32, text[sep + 1 ..], 10) catch return error.InvalidViewport;
    if (w <= 0 or h <= 0) return error.InvalidViewport;
    return .{ .width = w, .height = h };
}

fn hasChromeLauncherSwitch(args: []const []const u8) bool {
    var has_cdp_launcher = false;
    var has_mcp_flag = false;
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--remote-debugging-pipe")) has_cdp_launcher = true;
        if (valueOf(arg, "--remote-debugging-port")) |v| {
            if (!std.ascii.eqlIgnoreCase(v, "off") and !std.ascii.eqlIgnoreCase(v, "none")) {
                has_cdp_launcher = true;
            }
        }
        if (std.mem.eql(u8, arg, "--mcp") or std.mem.eql(u8, arg, "--mcp-port") or valueOf(arg, "--mcp-port") != null) {
            has_mcp_flag = true;
        }
    }
    return has_cdp_launcher and !has_mcp_flag;
}

/// Parse CLI arguments (excluding argv[0]). All slices borrow from `args`.
pub fn parseOptions(args: []const []const u8, bad: *[]const u8) OptionsError!Options {
    var options: Options = .{};
    const chrome_mode = hasChromeLauncherSwitch(args);
    var index: usize = 0;
    while (index < args.len) : (index += 1) {
        const arg = args[index];
        bad.* = arg;

        if (isRefusedFlag(arg)) return error.RefusedOption;

        const root_dir: ?[]const u8 = for (filesystem_root_flags) |flag| {
            if (try takeFlagValue(args, &index, flag)) |value| break value;
        } else null;
        if (root_dir) |dir| {
            if (options.filesystem_root_count == max_filesystem_roots) return error.TooManyArguments;
            options.filesystem_roots[options.filesystem_root_count] = dir;
            options.filesystem_root_count += 1;
            continue;
        }

        if (try takeFlagValue(args, &index, "--remote-debugging-port")) |value| {
            options.remote_debugging_port = try parseOptionalPort(value);
            options.remote_debugging_port_explicit = true;
            continue;
        }
        if (try takeFlagValue(args, &index, "--mcp-port")) |value| {
            options.mcp_port = try parseOptionalPort(value);
            options.mcp_port_explicit = true;
            continue;
        }
        if (try takeFlagValue(args, &index, "--mcp-host")) |value| {
            options.mcp_host = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--mcp-cert")) |value| {
            options.mcp_cert = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--mcp-key")) |value| {
            options.mcp_key = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--remote-allow-origins")) |value| {
            options.remote_allow_origins = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--viewport")) |value| {
            options.viewport = try parseViewport(value);
            continue;
        }
        if (try takeFlagValue(args, &index, "--userDataDir") orelse try takeFlagValue(args, &index, "--user-data-dir")) |value| {
            options.user_data_dir = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--ca-bundle")) |value| {
            options.ca_bundle = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--user-agent")) |value| {
            options.user_agent = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--proxy")) |value| {
            options.proxy = if (std.mem.eql(u8, value, "system"))
                .system
            else if (std.mem.eql(u8, value, "direct"))
                .direct
            else
                .{ .manual = .{ .http = value, .https = value } };
            continue;
        }
        if (try takeFlagValue(args, &index, "--proxy-server")) |value| {
            options.proxy_server = value;
            continue;
        }
        if (try takeFlagValue(args, &index, "--proxy-bypass-list")) |value| {
            options.proxy_bypass_list = value;
            continue;
        }

        if (std.mem.eql(u8, arg, "--mcp")) {
            options.mcp = true;
        } else if (std.mem.eql(u8, arg, "--remote-debugging-pipe")) {
            options.remote_debugging_pipe = true;
        } else if (std.mem.eql(u8, arg, "--mcp-tls")) {
            options.mcp_tls = true;
        } else if (std.mem.eql(u8, arg, "--isolated")) {
            options.isolated = true;
        } else if (std.mem.eql(u8, arg, "--allow-unrestricted-paths") or std.mem.eql(u8, arg, "--allowUnrestrictedPaths")) {
            options.allow_unrestricted_paths = true;
        } else if (std.mem.eql(u8, arg, "--memory-debugging") or std.mem.eql(u8, arg, "--memoryDebugging")) {
            options.memory_debugging = true;
        } else if (std.mem.eql(u8, arg, "--category-network-mocks") or std.mem.eql(u8, arg, "--categoryNetworkMocks")) {
            options.category_network_mocks = true;
        } else if (std.mem.eql(u8, arg, "--slim")) {
            options.slim = true;
        } else if (std.mem.eql(u8, arg, "--accept-insecure-certs") or std.mem.eql(u8, arg, "--acceptInsecureCerts")) {
            options.accept_insecure_certs = true;
        } else if (valueOf(arg, "--acceptInsecureCerts")) |value| {
            options.accept_insecure_certs = !std.mem.eql(u8, value, "false") and !std.mem.eql(u8, value, "0");
        } else if (std.mem.eql(u8, arg, "--headless") or valueOf(arg, "--headless") != null) {
            options.headless = true;
        } else if (std.mem.eql(u8, arg, "--no-startup-window")) {
            options.no_startup_window = true;
        } else if (std.mem.eql(u8, arg, "--check-leaks")) {
            options.check_leaks = true;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "-V")) {
            options.version = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.help = true;
        } else if (std.mem.eql(u8, arg, "--smoke-crash")) {
            options.smoke_crash = true;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            if (chrome_mode) continue;
            return error.UnknownOption;
        } else {
            if (options.url_provided) return error.TooManyArguments;
            options.url_provided = true;
            options.url = arg;
        }
    }

    // Stdio MCP (`--mcp`) and CDP pipe (`--remote-debugging-pipe`) default to
    // no TCP listeners unless the caller explicitly requested a port.
    if (options.mcp or options.remote_debugging_pipe) {
        if (!options.remote_debugging_port_explicit) options.remote_debugging_port = null;
        if (!options.mcp_port_explicit) options.mcp_port = null;
    }

    return options;
}

// ============================================================================
// Startup banner & live structured event formatting
// ============================================================================

pub const BannerInfo = struct {
    version: []const u8,
    git_sha: []const u8,
    cdp_url: ?[]const u8 = null,
    mcp_scheme: []const u8 = "http",
    mcp_host: []const u8 = "127.0.0.1",
    mcp_port: ?u16 = null,
    mcp_bearer_token: ?[]const u8 = null,
    mcp_cert_fingerprint: ?[]const u8 = null,
};

pub fn writeStartupBanner(writer: *std.Io.Writer, info: BannerInfo) std.Io.Writer.Error!void {
    try writer.print("crane {s} ({s})\n", .{ info.version, info.git_sha });
    if (info.cdp_url) |url| {
        try writer.print("DevTools listening on {s}\n", .{url});
    }
    if (info.mcp_port) |port| {
        try writer.print("MCP listening on {s}://{s}:{d}/mcp\n", .{ info.mcp_scheme, info.mcp_host, port });
        if (info.mcp_bearer_token) |token| {
            try writer.print("MCP bearer token: {s}\n", .{token});
        }
        if (info.mcp_cert_fingerprint) |fp| {
            try writer.print("MCP TLS SHA-256 fingerprint: {s}\n", .{fp});
        }
    }
    try writer.writeAll("Press Ctrl-C to stop.\n");
}

pub fn formatConsoleMessage(
    writer: *std.Io.Writer,
    kind: developer_console.Kind,
    level: developer_console.Level,
    source_prefix: []const u8,
    text: []const u8,
    location: developer_console.Location,
) std.Io.Writer.Error!void {
    switch (kind) {
        .console => {
            try writer.print("{s}[console.{s}] {s}\n", .{ source_prefix, @tagName(level), text });
        },
        .exception => {
            try writer.print("{s}[exception] {s}\n", .{ source_prefix, text });
            if (location.url.len > 0) {
                try writer.print("    at {s}:{d}:{d}\n", .{ location.url, location.line, location.column });
            }
        },
        .rejection => {
            try writer.print("{s}[rejection] {s}\n", .{ source_prefix, text });
            if (location.url.len > 0) {
                try writer.print("    at {s}:{d}:{d}\n", .{ location.url, location.line, location.column });
            }
        },
    }
}

pub fn formatNavigationEvent(
    writer: *std.Io.Writer,
    tab_prefix: []const u8,
    milestone: *const host_events.Milestone,
    status: u16,
) std.Io.Writer.Error!void {
    switch (milestone.event) {
        .started => |s| {
            try writer.print("{s}Navigating to {s}\n", .{ tab_prefix, s.url });
        },
        .ready_to_commit => |r| {
            if (r.outcome == .network_error) {
                try writer.print("{s}Navigation failed for {s}: {s}\n", .{ tab_prefix, r.url, r.error_text });
            }
        },
        .committed => |c| {
            if (c.kind == .initialization) return;
            if (status != 0) {
                try writer.print("{s}Navigated to {s} ({d})\n", .{ tab_prefix, c.url, status });
            } else {
                try writer.print("{s}Navigated to {s}\n", .{ tab_prefix, c.url });
            }
        },
        .same_document => |sd| {
            try writer.print("{s}Navigated to {s} (same-document)\n", .{ tab_prefix, sd.url });
        },
        .aborted => |a| {
            if (a.reason != .superseded) {
                try writer.print("{s}Navigation aborted ({s})\n", .{ tab_prefix, @tagName(a.reason) });
            }
        },
        else => {},
    }
}

// ============================================================================
// Live Event Logger (thread-safe across main, browser, and worker threads)
// ============================================================================

pub const Logger = struct {
    allocator: std.mem.Allocator,
    out: *std.Io.Writer,
    mutex: std.Io.Mutex = .init,
    browser: ?*Browser = null,
    attached: bool = false,
    nav_statuses: [16]NavStatus = @splat(.{}),
    nav_status_next: usize = 0,

    const NavStatus = struct {
        navigation_id: u64 = 0,
        status: u16 = 0,
    };

    pub fn init(allocator: std.mem.Allocator, out: *std.Io.Writer) Logger {
        return .{ .allocator = allocator, .out = out };
    }

    pub fn attach(self: *Logger, host: *BrowserHost) !void {
        const AttachCtx = struct {
            logger: *Logger,
            err: ?anyerror = null,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                c.logger.browser = b;
                b.attachDeveloperConsole(.{ .context = c.logger, .report = reportConsole }) catch |e| {
                    c.err = e;
                    return;
                };
                b.addListener(.{ .context = c.logger, .on_event = onHostEvent }) catch |e| {
                    b.detachDeveloperConsole();
                    c.err = e;
                    return;
                };
                c.logger.attached = true;
            }
        };
        var ctx: AttachCtx = .{ .logger = self };
        try host.call(&ctx, AttachCtx.run);
        if (ctx.err) |e| return e;
    }

    pub fn detach(self: *Logger, host: *BrowserHost) void {
        if (!self.attached) return;
        const DetachCtx = struct {
            logger: *Logger,
            fn run(ctx: ?*anyopaque, b: *Browser) void {
                const c: *@This() = @ptrCast(@alignCast(ctx.?));
                b.removeListener(.{ .context = c.logger, .on_event = onHostEvent });
                b.detachDeveloperConsole();
                c.logger.browser = null;
                c.logger.attached = false;
            }
        };
        var ctx: DetachCtx = .{ .logger = self };
        host.call(&ctx, DetachCtx.run) catch {};
    }

    pub fn emit(self: *Logger, bytes: []const u8) void {
        if (bytes.len == 0) return;
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.out.writeAll(bytes) catch {};
        self.out.flush() catch {};
    }

    pub fn logLine(self: *Logger, comptime fmt: []const u8, args: anytype) void {
        const text = std.fmt.allocPrint(self.allocator, fmt, args) catch return;
        defer self.allocator.free(text);
        self.emit(text);
    }

    fn recordNavStatus(self: *Logger, navigation_id: u64, status: u16) void {
        if (navigation_id == 0) return;
        for (&self.nav_statuses) |*entry| {
            if (entry.navigation_id == navigation_id) {
                entry.status = status;
                return;
            }
        }
        self.nav_statuses[self.nav_status_next] = .{ .navigation_id = navigation_id, .status = status };
        self.nav_status_next = (self.nav_status_next + 1) % self.nav_statuses.len;
    }

    fn lookupNavStatus(self: *const Logger, navigation_id: u64) u16 {
        if (navigation_id == 0) return 0;
        for (self.nav_statuses) |entry| {
            if (entry.navigation_id == navigation_id) return entry.status;
        }
        return 0;
    }

    fn reportConsole(context: *anyopaque, message: *const developer_console.Message) void {
        const self: *Logger = @ptrCast(@alignCast(context));
        var prefix_buf: std.Io.Writer.Allocating = .init(self.allocator);
        defer prefix_buf.deinit();
        self.writeRealmPrefix(&prefix_buf.writer, message.realm) catch {};

        var line: std.Io.Writer.Allocating = .init(self.allocator);
        defer line.deinit();
        formatConsoleMessage(
            &line.writer,
            message.kind,
            message.level,
            prefix_buf.written(),
            message.text,
            message.location,
        ) catch return;
        self.emit(line.written());
    }

    fn writeRealmPrefix(self: *Logger, out: *std.Io.Writer, source_realm: engine.Context) !void {
        if (source_realm.isWindow()) {
            const b = self.browser orelse return;
            const source = b.realmSource(source_realm) orelse return;
            const several = b.traversableCount() > 1;
            if (!source.frame and !several) return;
            try out.writeByte('[');
            if (several) {
                const idx = b.traversableIndex(source.traversable) orelse 0;
                try out.print("tab {d}", .{idx + 1});
                if (source.frame) try out.writeByte(' ');
            }
            if (source.frame) try out.print("frame {s}", .{source_realm.documentUrl() orelse ""});
            try out.writeAll("] ");
            return;
        }
        const kind = if (source_realm.isWorker()) "worker" else "worklet";
        try out.print("[{s} {s}] ", .{ kind, source_realm.documentUrl() orelse "" });
    }

    fn onHostEvent(context: *anyopaque, event: *const host_events.Event) void {
        const self: *Logger = @ptrCast(@alignCast(context));
        var line: std.Io.Writer.Allocating = .init(self.allocator);
        defer line.deinit();

        switch (event.*) {
            .navigation => |milestone| {
                if (milestone.event == .ready_to_commit) {
                    self.recordNavStatus(milestone.navigation_id, milestone.event.ready_to_commit.status);
                }
                var tab_buf: [48]u8 = undefined;
                const tab_prefix = self.tabPrefix(milestone.navigable_id, &tab_buf);
                const status = self.lookupNavStatus(milestone.navigation_id);
                formatNavigationEvent(&line.writer, tab_prefix, milestone, status) catch return;
            },
            .tab_created => |created| {
                if (created.made_by == .page) {
                    line.writer.print("Opened tab {d} ({s})\n", .{ created.tab, created.url }) catch return;
                }
            },
            .tab_destroyed => |destroyed| {
                line.writer.print("Closed tab {d}\n", .{destroyed.tab}) catch return;
            },
            else => return,
        }
        self.emit(line.written());
    }

    fn tabPrefix(self: *Logger, navigable_id: u64, buf: []u8) []const u8 {
        const b = self.browser orelse return "";
        if (b.traversableCount() <= 1) return "";
        const idx = b.traversableIndex(navigable_id) orelse return "";
        return std.fmt.bufPrint(buf, "[tab {d}] ", .{idx + 1}) catch "";
    }
};

// ============================================================================
// Signal wake pipe (async-signal-safe SIGINT / SIGTERM shutdown)
// ============================================================================

var signal_wake_fd: std.atomic.Value(i32) = .init(-1);
var shutdown_signal: std.atomic.Value(i32) = .init(0);

fn daemonSignalHandler(sig: std.posix.SIG) callconv(.c) void {
    shutdown_signal.store(@intCast(@backingInt(sig)), .release);
    const fd = signal_wake_fd.load(.acquire);
    if (fd >= 0) {
        const byte = [1]u8{1};
        _ = std.c.write(fd, &byte, 1);
    }
}

fn requireProductionMemory(config: BrowserConfig) error{GeneralMemoryNotProduction}!void {
    if (config.general_memory != .crane) return error.GeneralMemoryNotProduction;
}

const ProxyRules = @typeInfo(@FieldType(BrowserConfig.Proxy, "rules")).pointer.child;

fn chromeProxyRules(allocator: std.mem.Allocator, options: Options) !?ProxyRules {
    const server = options.proxy_server orelse return null;
    return try ProxyRules.parse(allocator, server, options.proxy_bypass_list orelse "");
}

fn openFirstWindow(host: *BrowserHost, options: Options) !void {
    if (options.no_startup_window) return;
    const need_nav = options.url_provided or !std.mem.eql(u8, options.url, "about:blank");
    if (!need_nav and options.viewport == null) return;
    const FirstWindow = struct {
        url: []const u8,
        need_nav: bool,
        viewport: ?Options.Viewport,
        failed: bool = false,
        fn run(context: ?*anyopaque, b: *Browser) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            const id = b.hostTraversableId() orelse {
                self.failed = true;
                return;
            };
            if (self.viewport) |vp| {
                browser_mod.viewport.setWindowBounds(b.scope, id, .{ .width = vp.width, .height = vp.height }) catch {};
            }
            if (self.need_nav) {
                b.navigateTraversable(id, self.url) catch {
                    self.failed = true;
                };
            }
        }
    };
    var first: FirstWindow = .{ .url = options.url, .need_nav = need_nav, .viewport = options.viewport };
    host.call(&first, FirstWindow.run) catch return error.FirstWindow;
    if (first.failed) return error.FirstWindow;
}

fn parseAllowedOrigins(list_opt: ?[]const u8, out: *[32][]const u8) usize {
    const list = list_opt orelse return 0;
    var count: usize = 0;
    var it = std.mem.tokenizeScalar(u8, list, ',');
    while (it.next()) |origin| {
        if (count == out.len) break;
        out[count] = std.mem.trim(u8, origin, " ");
        count += 1;
    }
    return count;
}

/// `--mcp`: serve Chrome DevTools MCP over stdin/stdout with zero stray output
/// on stdout.
fn serveMcpStdio(allocator: std.mem.Allocator, options: Options, err_out: *std.Io.Writer) !u8 {
    if (comptime !devtools.enabled) {
        try err_out.print("crane: --mcp: {s}\n", .{devtools.unavailable_message});
        try err_out.flush();
        return 2;
    }

    var config: BrowserConfig = .{
        .ca_bundle_path = options.ca_bundle,
        .user_agent = options.user_agent,
        .proxy = options.proxy,
        .accept_insecure_certs = options.accept_insecure_certs,
    };
    var proxy_rules = try chromeProxyRules(allocator, options);
    defer if (proxy_rules) |*rules| rules.deinit();
    if (proxy_rules) |*rules| config.proxy = .{ .rules = rules };
    if (comptime @hasField(BrowserConfig, "profile_dir")) {
        config.profile_dir = if (options.isolated) null else options.user_data_dir;
    }
    try requireProductionMemory(config);

    const host = BrowserHost.start(allocator, config) catch |err| {
        try err_out.print("crane: the browser could not start: {t}\n", .{err});
        try err_out.flush();
        return 1;
    };
    defer host.stop();

    openFirstWindow(host, options) catch {
        try err_out.print("crane: the first page could not open\n", .{});
        try err_out.flush();
        return 1;
    };

    const pipe = platform.devtoolsOpenInheritedPipe(0, 1) catch |err| {
        try err_out.print("crane: --mcp: stdin and stdout: {t}\n", .{err});
        try err_out.flush();
        return 1;
    };
    const stdio = devtools.mcp.server.Stdio.start(allocator, pipe) catch |err| {
        try err_out.print("crane: --mcp: {t}\n", .{err});
        try err_out.flush();
        return 1;
    };
    defer stdio.deinit();

    var origins: [32][]const u8 = undefined;
    const origin_count = parseAllowedOrigins(options.remote_allow_origins, &origins);

    const dt_server = devtools.Server.start(allocator, .{
        .port = options.remote_debugging_port,
        .allowed_origins = origins[0..origin_count],
        .user_data_dir = options.user_data_dir,
        .user_agent = options.user_agent orelse "",
        .default_host = host,
        .context_config = config,
        .on_close = stdio.closeCallback(),
    }) catch |err| {
        try err_out.print("crane: the MCP server could not start: {t}\n", .{err});
        try err_out.flush();
        return 1;
    };
    defer dt_server.stop();

    devtools.mcp.server.serveStdio(allocator, dt_server, stdio, .{
        .filesystem_roots = if (options.filesystem_root_count > 0) options.filesystem_roots[0..options.filesystem_root_count] else null,
        .allow_unrestricted_paths = options.allow_unrestricted_paths,
        .memory_debugging = options.memory_debugging,
        .category_network_mocks = options.category_network_mocks,
        .slim = options.slim,
    }) catch |err| {
        try err_out.print("crane: --mcp: {t}\n", .{err});
        try err_out.flush();
        return 1;
    };
    return 0;
}

/// Default daemon mode: shared `BrowserHost` + optional CDP TCP/pipe + optional
/// Streamable HTTP MCP + live structured logs until `SIGINT`/`SIGTERM` or
/// `Browser.close`.
fn serveDaemon(allocator: std.mem.Allocator, options: Options, err_out: *std.Io.Writer) !u8 {
    if ((options.mcp_cert != null) != (options.mcp_key != null)) {
        try err_out.print("crane: --mcp-cert and --mcp-key must both be given\n", .{});
        try err_out.flush();
        return 2;
    }

    const cert_pem: []u8 = if (options.mcp_cert) |p| (platform.readFile(allocator, platform.Str.from(p), 1 << 20) catch |err| {
        try err_out.print("crane: --mcp-cert={s}: {t}\n", .{ p, err });
        try err_out.flush();
        return 1;
    }) else try allocator.alloc(u8, 0);
    defer allocator.free(cert_pem);

    const key_pem: []u8 = if (options.mcp_key) |p| (platform.readFile(allocator, platform.Str.from(p), 1 << 20) catch |err| {
        try err_out.print("crane: --mcp-key={s}: {t}\n", .{ p, err });
        try err_out.flush();
        return 1;
    }) else try allocator.alloc(u8, 0);
    defer allocator.free(key_pem);

    var config: BrowserConfig = .{
        .ca_bundle_path = options.ca_bundle,
        .user_agent = options.user_agent,
        .proxy = options.proxy,
        .accept_insecure_certs = options.accept_insecure_certs,
    };
    var proxy_rules = try chromeProxyRules(allocator, options);
    defer if (proxy_rules) |*rules| rules.deinit();
    if (proxy_rules) |*rules| config.proxy = .{ .rules = rules };
    if (comptime @hasField(BrowserConfig, "profile_dir")) {
        config.profile_dir = if (options.isolated) null else options.user_data_dir;
    }
    try requireProductionMemory(config);

    // Async-signal-safe wake pipe for SIGINT, SIGTERM, and Browser.close.
    var wake_pipe: [2]std.posix.fd_t = .{ -1, -1 };
    if (std.c.pipe(&wake_pipe) != 0) {
        try err_out.print("crane: could not create shutdown wake pipe\n", .{});
        try err_out.flush();
        return 1;
    }
    defer {
        for (wake_pipe) |fd| if (fd >= 0) {
            _ = std.c.close(fd);
        };
    }

    shutdown_signal.store(0, .release);
    signal_wake_fd.store(wake_pipe[1], .release);
    defer signal_wake_fd.store(-1, .release);

    var old_int: std.posix.Sigaction = undefined;
    var old_term: std.posix.Sigaction = undefined;
    const sig_act: std.posix.Sigaction = .{
        .handler = .{ .handler = daemonSignalHandler },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(.INT, &sig_act, &old_int);
    std.posix.sigaction(.TERM, &sig_act, &old_term);
    defer {
        std.posix.sigaction(.INT, &old_int, null);
        std.posix.sigaction(.TERM, &old_term, null);
    }

    const host = BrowserHost.start(allocator, config) catch |err| {
        try err_out.print("crane: the browser could not start: {t}\n", .{err});
        try err_out.flush();
        return 1;
    };
    defer host.stop();

    var logger = Logger.init(allocator, err_out);

    const CloseCtx = struct {
        write_fd: std.posix.fd_t,
        fn onClose(ctx: ?*anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            const byte = [1]u8{2};
            _ = std.c.write(self.write_fd, &byte, 1);
        }
    };
    var close_ctx: CloseCtx = .{ .write_fd = wake_pipe[1] };

    var origins: [32][]const u8 = undefined;
    const origin_count = parseAllowedOrigins(options.remote_allow_origins, &origins);

    var cdp_url_buf: [160]u8 = undefined;
    var banner: BannerInfo = .{
        .version = build_info.version,
        .git_sha = build_info.git_sha,
        .mcp_host = options.mcp_host,
    };

    var dt_server_opt: if (devtools.enabled) ?*devtools.Server else void = if (devtools.enabled) null else {};
    defer if (comptime devtools.enabled) {
        if (dt_server_opt) |s| s.stop();
    };

    var http_srv_opt: if (devtools.enabled) ?*devtools.mcp.http.HttpServer else void = if (devtools.enabled) null else {};
    defer if (comptime devtools.enabled) {
        if (http_srv_opt) |h| h.stop();
    };

    if (comptime devtools.enabled) {
        const need_devtools = options.remote_debugging_port != null or
            options.remote_debugging_pipe or
            options.mcp_port != null;
        if (need_devtools) {
            const dt_server = devtools.Server.start(allocator, .{
                .port = options.remote_debugging_port,
                .pipe = if (options.remote_debugging_pipe) .{} else null,
                .allowed_origins = origins[0..origin_count],
                .user_data_dir = options.user_data_dir,
                .user_agent = options.user_agent orelse "",
                .default_host = host,
                .context_config = config,
                .on_close = .{ .context = &close_ctx, .run = CloseCtx.onClose },
            }) catch |err| {
                try err_out.print("crane: remote debugging could not start: {t}\n", .{err});
                try err_out.flush();
                return 1;
            };
            dt_server_opt = dt_server;
            if (options.remote_debugging_port != null) {
                banner.cdp_url = dt_server.browserUrl(&cdp_url_buf);
            }

            if (options.mcp_port) |mcp_port| {
                const http_srv = devtools.mcp.http.HttpServer.start(allocator, dt_server, .{
                    .host = options.mcp_host,
                    .port = mcp_port,
                    .tls = if (options.mcp_tls) .required else .auto,
                    .cert_pem = cert_pem,
                    .key_pem = key_pem,
                    .allowed_origins = origins[0..origin_count],
                    .mcp = .{
                        .filesystem_roots = if (options.filesystem_root_count > 0) options.filesystem_roots[0..options.filesystem_root_count] else null,
                        .allow_unrestricted_paths = options.allow_unrestricted_paths,
                        .memory_debugging = options.memory_debugging,
                        .category_network_mocks = options.category_network_mocks,
                        .slim = options.slim,
                    },
                }) catch |err| {
                    try err_out.print("crane: MCP HTTP server could not start: {t}\n", .{err});
                    try err_out.flush();
                    return 1;
                };
                http_srv_opt = http_srv;
                banner.mcp_scheme = if (http_srv.isTls()) "https" else "http";
                banner.mcp_port = http_srv.boundPort();
                banner.mcp_bearer_token = http_srv.bearerToken();
                banner.mcp_cert_fingerprint = http_srv.certFingerprint();
            }
        }
    }

    // Print the startup banner cleanly before attaching live event logs and
    // opening the initial URL so callers reading stderr see endpoints first.
    if (!options.remote_debugging_pipe or banner.cdp_url != null or banner.mcp_port != null) {
        var banner_buf: std.Io.Writer.Allocating = .init(allocator);
        defer banner_buf.deinit();
        try writeStartupBanner(&banner_buf.writer, banner);
        logger.emit(banner_buf.written());
    }

    try logger.attach(host);
    defer logger.detach(host);

    openFirstWindow(host, options) catch {
        logger.logLine("crane: failed to open {s}\n", .{options.url});
        return 1;
    };

    // Block until SIGINT, SIGTERM, or Browser.close wakes the pipe.
    while (true) {
        if (shutdown_signal.load(.acquire) != 0) break;
        var byte: [1]u8 = undefined;
        const n = std.c.read(wake_pipe[0], &byte, 1);
        if (n > 0) break;
        if (n == 0) break;
        if (shutdown_signal.load(.acquire) != 0) break;
    }

    const sig_num = shutdown_signal.load(.acquire);
    if (sig_num == @backingInt(std.posix.SIG.INT)) {
        logger.emit("Received SIGINT, shutting down...\n");
    } else if (sig_num == @backingInt(std.posix.SIG.TERM)) {
        logger.emit("Received SIGTERM, shutting down...\n");
    } else {
        logger.emit("Browser closed, shutting down...\n");
    }

    if (comptime devtools.enabled) {
        if (http_srv_opt) |h| {
            h.stop();
            http_srv_opt = null;
            logger.emit("MCP server stopped\n");
        }
        if (dt_server_opt) |s| {
            s.stop();
            dt_server_opt = null;
            if (options.remote_debugging_port != null or options.remote_debugging_pipe) {
                logger.emit("CDP server stopped\n");
            }
        }
    }

    return 0;
}

/// Locate `whatwg_snapshot.bin` beside the executable (or in `../share/crane/`
/// for packaged installs). Returns owned path if present, null otherwise.
fn resolveSnapshotPath(io: std.Io, allocator: std.mem.Allocator) ?[]u8 {
    const exe_dir = std.process.executableDirPathAlloc(io, allocator) catch return null;
    defer allocator.free(exe_dir);

    const beside = std.fs.path.join(allocator, &.{ exe_dir, "whatwg_snapshot.bin" }) catch null;
    if (beside) |path| {
        if (std.Io.Dir.cwd().access(io, path, .{})) |_| {
            return path;
        } else |_| {
            allocator.free(path);
        }
    }

    const shared = std.fs.path.join(allocator, &.{ exe_dir, "..", "share", "crane", "whatwg_snapshot.bin" }) catch null;
    if (shared) |path| {
        if (std.Io.Dir.cwd().access(io, path, .{})) |_| {
            return path;
        } else |_| {
            allocator.free(path);
        }
    }

    return null;
}

pub fn main(init: std.process.Init) !u8 {
    _ = platform.attachSignalStack();
    crash_handler.installSignalHandlers(build_info);
    engine.initializeBeforeThreadCreation();

    const io = init.io;
    var stderr_buffer: [1024]u8 = undefined;
    var stderr = std.Io.File.stderr().writerStreaming(io, &stderr_buffer);
    const err_out = &stderr.interface;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &stdout_buffer);
    const std_out = &stdout.interface;

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const rest = try init.arena.allocator().alloc([]const u8, if (args.len > 0) args.len - 1 else 0);
    for (rest, 0..) |*arg, i| arg.* = args[i + 1];

    var bad: []const u8 = "";
    const options = parseOptions(rest, &bad) catch |err| {
        if (err == error.RefusedOption) {
            try err_out.print("crane: {s}: not supported (Crane's MCP server runs in-process; it does not launch or attach to an external browser)\n", .{bad});
            try err_out.flush();
            return 2;
        }
        try err_out.print("crane: {s}: {s}\n{s}", .{ bad, switch (err) {
            error.UnknownOption => "unknown option",
            error.MissingValue => "needs a value",
            error.TooManyArguments => "only one URL is opened",
            error.InvalidPort => "not a port number (expected 0-65535 or off/none)",
            error.InvalidViewport => "expected <width>x<height> with positive integers",
            error.RefusedOption => unreachable,
        }, usage });
        try err_out.flush();
        return 2;
    };

    if (options.smoke_crash) {
        @panic("crane --smoke-crash test panic");
    }

    if (options.version) {
        try std_out.print("crane {s} ({s})\n", .{ build_info.version, build_info.git_sha });
        try std_out.flush();
        return 0;
    }

    if (options.help) {
        try std_out.writeAll(usage);
        try std_out.flush();
        return 0;
    }

    if (!devtools.enabled) {
        if (options.mcp) {
            try err_out.print("crane: --mcp: {s}\n", .{devtools.unavailable_message});
            try err_out.flush();
            return 2;
        }
        if (options.remote_debugging_pipe) {
            try err_out.print("crane: --remote-debugging-pipe: {s}\n", .{devtools.unavailable_message});
            try err_out.flush();
            return 2;
        }
        if (options.remote_debugging_port_explicit and options.remote_debugging_port != null) {
            try err_out.print("crane: --remote-debugging-port: {s}\n", .{devtools.unavailable_message});
            try err_out.flush();
            return 2;
        }
        if (options.mcp_port_explicit and options.mcp_port != null) {
            try err_out.print("crane: --mcp-port: {s}\n", .{devtools.unavailable_message});
            try err_out.flush();
            return 2;
        }
    }

    var leak_check: std.heap.DebugAllocator(.{ .stack_trace_frames = 0, .safety = true }) = .init;
    var leak_trace: std.heap.DebugAllocator(.{ .stack_trace_frames = 6, .safety = true }) = .init;
    const traces = if (init.environ_map.get("CRANE_LEAK_TRACES")) |v| v.len != 0 and v[0] != '0' else false;
    const allocator: std.mem.Allocator = if (!options.check_leaks)
        std.heap.c_allocator
    else if (traces)
        leak_trace.allocator()
    else
        leak_check.allocator();
    defer if (options.check_leaks) {
        const leaked = if (traces) leak_trace.deinit() == .leak else leak_check.deinit() == .leak;
        err_out.print("crane: --check-leaks: {s}\n", .{if (leaked) "leaks reported above" else "no leaks"}) catch {};
        err_out.flush() catch {};
    };

    const snapshot_path = resolveSnapshotPath(io, allocator);
    defer if (snapshot_path) |p| allocator.free(p);

    var process = try browser_mod.Process.init(.{ .snapshot_path = snapshot_path });
    defer process.deinit();

    if (options.mcp) {
        return serveMcpStdio(allocator, options, err_out);
    }
    return serveDaemon(allocator, options, err_out);
}

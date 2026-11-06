//! The engines and how each is launched on a page: pinned binaries (a pin
//! file per engine, written by its setup script on the measuring host) and
//! the exact command line, which every journal row records.
//!
//! Launched as each is used headless, in the background, never taking focus
//! (the user's rule):
//!   crane       the console, `repl <url>`: Crane's headless browser
//!               (docs/console.md), its stdin a pipe held open so the page
//!               stays live until the runner closes it; crane_fast is the
//!               same console from the ReleaseFast release build;
//!   chrome      `--headless=new <url>` with a fresh --user-data-dir;
//!   firefox     `--headless --profile <dir> <url>`, the profile's user.js
//!               turning off first-run pages, telemetry and updates;
//!   lightpanda  `serve` (its CDP server), driven over CDP (cdp.zig);
//!   safari      safaridriver, driven over WebDriver (webdriver.zig): Safari
//!               has no headless mode, and its WebKit processes are launchd's
//!               children, so the process set names them.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const journal = @import("journal.zig");

pub const Name = journal.EngineName;

/// A pin file: `key=value` lines. Required: name, version, build, binary,
/// sha256. Crane's also: commit, optimize, v8. Safari's: webdriver.
pub const Pin = struct {
    name: Name,
    version: []const u8,
    build: []const u8,
    binary: []const u8,
    sha256: []const u8,
    commit: ?[]const u8 = null,
    optimize: ?[]const u8 = null,
    v8: ?[]const u8 = null,
    /// safaridriver (Safari).
    webdriver: ?[]const u8 = null,
    /// When the setup script installed or checked it.
    installed: ?[]const u8 = null,
};

pub const PinError = error{ PinMissingKey, PinUnknownEngine, PinBadSha256, PinMissingBuildIdentity, PinWrongBuild, PinMissingWebDriver };

pub fn parsePin(arena: Allocator, text: []const u8) (PinError || Allocator.Error)!Pin {
    var name: ?Name = null;
    var fields: struct { version: ?[]const u8 = null, build: ?[]const u8 = null, binary: ?[]const u8 = null, sha256: ?[]const u8 = null, commit: ?[]const u8 = null, optimize: ?[]const u8 = null, v8: ?[]const u8 = null, webdriver: ?[]const u8 = null, installed: ?[]const u8 = null } = .{};
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = line[0..eq];
        const value = try arena.dupe(u8, line[eq + 1 ..]);
        if (std.mem.eql(u8, key, "name")) {
            name = std.meta.stringToEnum(Name, value) orelse return error.PinUnknownEngine;
        } else inline for (@typeInfo(@TypeOf(fields)).@"struct".field_names) |field| {
            if (std.mem.eql(u8, key, field)) @field(fields, field) = value;
        }
    }
    const pin: Pin = .{
        .name = name orelse return error.PinMissingKey,
        .version = fields.version orelse return error.PinMissingKey,
        .build = fields.build orelse return error.PinMissingKey,
        .binary = fields.binary orelse return error.PinMissingKey,
        .sha256 = fields.sha256 orelse return error.PinMissingKey,
        .commit = fields.commit,
        .optimize = fields.optimize,
        .v8 = fields.v8,
        .webdriver = fields.webdriver,
        .installed = fields.installed,
    };
    if (!journal.isSha256(pin.sha256)) return error.PinBadSha256;
    if (pin.name.isCrane()) {
        if (pin.commit == null or pin.optimize == null or pin.v8 == null) return error.PinMissingBuildIdentity;
        // The comparison rule: Crane is timed in its release build, never the
        // correctness runner, and each Crane engine in its own mode - the
        // modes as build_mode.zig `describe` names them (zig-out/bin/
        // repl.modes), so a pin cannot put one build under the other's name.
        if (!std.mem.eql(u8, pin.optimize.?, craneModes(pin.name))) return error.PinWrongBuild;
    }
    if (pin.name == .safari and pin.webdriver == null) return error.PinMissingWebDriver;
    return pin;
}

/// The modes a Crane engine's build has, as build_mode.zig `describe`
/// writes them into zig-out/bin/repl.modes (`releaseRunner(.safe)` and
/// `releaseRunner(.fast)`; tests/wpt_runner/build_mode.zig pins both).
pub fn craneModes(name: Name) []const u8 {
    return switch (name) {
        .crane => "root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc",
        .crane_fast => "root ReleaseFast, Crane modules ReleaseFast, C libraries ReleaseFast, sanitize_c off, libc malloc",
        .chrome, .firefox, .safari, .lightpanda => unreachable,
    };
}

/// The SHA-256 of a file, as 64 lowercase hex digits.
pub fn sha256File(io: Io, path: []const u8, out: *[64]u8) !void {
    var file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buf: [64 * 1024]u8 = undefined;
    var reader = file.reader(io, &buf);
    while (true) {
        const chunk = reader.interface.peekGreedy(1) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        hasher.update(chunk);
        reader.interface.toss(chunk.len);
    }
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    out.* = std.fmt.bytesToHex(digest, .lower);
}

/// Firefox's user.js: no first-run pages, default-browser check, telemetry,
/// updates, Normandy, captive-portal probe or crash-restore prompt - the
/// prefs mozprofile and geckodriver set for automation (each one a network
/// request or a page the measured run would otherwise include).
pub const firefox_user_js =
    \\user_pref("browser.shell.checkDefaultBrowser", false);
    \\user_pref("browser.startup.homepage_override.mstone", "ignore");
    \\user_pref("browser.startup.page", 0);
    \\user_pref("browser.aboutwelcome.enabled", false);
    \\user_pref("browser.newtabpage.enabled", false);
    \\user_pref("browser.sessionstore.resume_from_crash", false);
    \\user_pref("browser.tabs.warnOnClose", false);
    \\user_pref("datareporting.policy.dataSubmissionEnabled", false);
    \\user_pref("datareporting.healthreport.uploadEnabled", false);
    \\user_pref("toolkit.telemetry.enabled", false);
    \\user_pref("toolkit.telemetry.unified", false);
    \\user_pref("toolkit.telemetry.server", "");
    \\user_pref("app.update.auto", false);
    \\user_pref("app.update.checkInstallTime", false);
    \\user_pref("app.update.disabledForTesting", true);
    \\user_pref("app.normandy.enabled", false);
    \\user_pref("extensions.update.enabled", false);
    \\user_pref("extensions.getAddons.cache.enabled", false);
    \\user_pref("network.captive-portal-service.enabled", false);
    \\user_pref("network.connectivity-service.enabled", false);
    \\user_pref("browser.safebrowsing.malware.enabled", false);
    \\user_pref("browser.safebrowsing.phishing.enabled", false);
    \\user_pref("browser.safebrowsing.downloads.enabled", false);
    \\user_pref("browser.safebrowsing.update.enabled", false);
    \\user_pref("services.settings.server", "");
    \\user_pref("browser.region.network.url", "");
    \\user_pref("dom.disable_open_during_load", false);
    \\
;

/// Chrome's flags beside --headless=new: puppeteer's defaults for a quiet
/// automated profile (no first run, no background networking, component
/// updates, sync, extensions or keychain prompts).
pub const chrome_flags = [_][]const u8{
    "--headless=new",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-background-networking",
    "--disable-component-update",
    "--disable-sync",
    "--disable-default-apps",
    "--disable-extensions",
    "--disable-features=Translate,MediaRouter,OptimizationHints",
    "--metrics-recording-only",
    "--mute-audio",
    "--password-store=basic",
    "--use-mock-keychain",
};

/// Crane's console: no proxy (the pages are on loopback), and evaluation and
/// load ceilings above any page's own timeout (the runner's decide).
pub const crane_flags = [_][]const u8{ "--proxy=direct", "--timeout=900000" };

pub const firefox_flags = [_][]const u8{ "--headless", "--no-remote" };

/// The process names Safari's set adds to safaridriver's tree: the browser
/// and the WebKit processes launchd starts for it.
pub const safari_process_names = [_][]const u8{
    "Safari",
    "com.apple.WebKit.WebContent",
    "com.apple.WebKit.Networking",
    "com.apple.WebKit.GPU",
};

/// How an engine reaches the page: on its command line, or by a protocol
/// after it starts.
pub const Drive = enum { argv, cdp, webdriver };

pub fn driveOf(name: Name) Drive {
    return switch (name) {
        .crane, .crane_fast, .chrome, .firefox => .argv,
        .lightpanda => .cdp,
        .safari => .webdriver,
    };
}

/// The command line that launches `pin`'s engine. `url` goes on it for the
/// engines that take one; `profile` is a fresh directory for this launch;
/// `port` the protocol port for those driven by one. The flags the journal
/// records are `argv[1..]` without the URL, with the profile directory
/// written as `<profile>`.
pub const Launch = struct {
    argv: []const []const u8,
    flags: []const []const u8,
    drive: Drive,
    /// Processes outside the launched tree that belong to the engine.
    names: []const []const u8 = &.{},
    // RED STUB
    app_names: []const []const u8 = &.{},
    /// Environment additions.
    env: []const [2][]const u8 = &.{},
    /// Its stdin a pipe the runner holds open: the console reads its input
    /// there and exits when it closes (as on Ctrl+D), so the page stays live
    /// until the launch ends. Every other engine's stdin is /dev/null.
    stdin_pipe: bool = false,
    /// The directory it runs in, when not the runner's: a Crane build's own
    /// (its binary's), where its frozen snapshot is. The console restores
    /// the whatwg_snapshot.bin beside its executable (tools/repl.zig, main),
    /// and only when there is none searches from its working directory
    /// (src/browser/process.zig DEFAULT_SNAPSHOT_PATHS, zig-out/bin/ first):
    /// run there, even that fallback is the build's own, never the
    /// runner's directory's last build.
    cwd: ?[]const u8 = null,
};

pub fn launch(arena: Allocator, pin: Pin, url: []const u8, profile: []const u8, port: u16) Allocator.Error!Launch {
    var argv: std.ArrayList([]const u8) = .empty;
    var flags: std.ArrayList([]const u8) = .empty;
    switch (pin.name) {
        .crane, .crane_fast => {
            try argv.append(arena, pin.binary);
            try argv.append(arena, url);
            for (crane_flags) |f| {
                try argv.append(arena, f);
                try flags.append(arena, f);
            }
            return .{ .argv = argv.items, .flags = flags.items, .drive = .argv, .stdin_pipe = true, .cwd = std.fs.path.dirname(pin.binary) };
        },
        .chrome => {
            try argv.append(arena, pin.binary);
            for (chrome_flags) |f| {
                try argv.append(arena, f);
                try flags.append(arena, f);
            }
            try argv.append(arena, try std.fmt.allocPrint(arena, "--user-data-dir={s}", .{profile}));
            try flags.append(arena, "--user-data-dir=<profile>");
            try argv.append(arena, url);
            return .{ .argv = argv.items, .flags = flags.items, .drive = .argv };
        },
        .firefox => {
            try argv.append(arena, pin.binary);
            for (firefox_flags) |f| {
                try argv.append(arena, f);
                try flags.append(arena, f);
            }
            try argv.appendSlice(arena, &.{ "--profile", profile });
            try flags.appendSlice(arena, &.{ "--profile", "<profile>" });
            try argv.append(arena, url);
            return .{
                .argv = argv.items,
                .flags = flags.items,
                .drive = .argv,
                .env = &.{.{ "MOZ_CRASHREPORTER_DISABLE", "1" }},
            };
        },
        .lightpanda => {
            const port_text = try std.fmt.allocPrint(arena, "{d}", .{port});
            try argv.appendSlice(arena, &.{ pin.binary, "serve", "--host", "127.0.0.1", "--port", port_text });
            try flags.appendSlice(arena, &.{ "serve", "--host", "127.0.0.1", "--port", "<port>" });
            return .{
                .argv = argv.items,
                .flags = flags.items,
                .drive = .cdp,
                .env = &.{.{ "LIGHTPANDA_DISABLE_TELEMETRY", "true" }},
            };
        },
        .safari => {
            const port_text = try std.fmt.allocPrint(arena, "{d}", .{port});
            try argv.appendSlice(arena, &.{ pin.webdriver.?, "-p", port_text });
            try flags.appendSlice(arena, &.{ "safaridriver", "-p", "<port>" });
            return .{ .argv = argv.items, .flags = flags.items, .drive = .webdriver, .names = &safari_process_names };
        },
    }
}

const testing = std.testing;

/// Two lists of strings, equal string by string (expectEqualSlices compares
/// a slice of slices by pointer).
fn expectStrings(want: []const []const u8, got: []const []const u8) !void {
    try testing.expectEqual(want.len, got.len);
    for (want, got) |w, g| try testing.expectEqualStrings(w, g);
}

const crane_pin_text =
    \\# written by the window script
    \\name=crane
    \\version=e7101e588f1
    \\build=release: ReleaseSafe everywhere, C .trap, libc malloc
    \\commit=e7101e588f1
    \\optimize=root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc
    \\v8=13.1.203 static
    \\binary=/x/repl
    \\sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
;

test "a pin file: keys, comments, and Crane's build identity" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const pin = try parsePin(a, crane_pin_text);
    try testing.expectEqual(Name.crane, pin.name);
    try testing.expectEqualStrings("13.1.203 static", pin.v8.?);
    try testing.expectEqualStrings("/x/repl", pin.binary);
    // Crane without its V8 is not a pin: the release build names its parts.
    const no_v8 = try std.mem.replaceOwned(u8, a, crane_pin_text, "v8=13.1.203 static\n", "");
    try testing.expectError(error.PinMissingBuildIdentity, parsePin(a, no_v8));
    try testing.expectError(error.PinUnknownEngine, parsePin(a, "name=netscape\n"));
    try testing.expectError(error.PinMissingKey, parsePin(a, "name=chrome\nversion=1\n"));
    const bad_sha = try std.mem.replaceOwned(u8, a, crane_pin_text, "sha256=0123", "sha256=XYZ");
    try testing.expectError(error.PinBadSha256, parsePin(a, bad_sha));
    try testing.expectError(error.PinMissingWebDriver, parsePin(a, "name=safari\nversion=26.1\nbuild=x\nbinary=/Applications/Safari.app\nsha256=" ++ "abababababababababababababababababababababababababababababababab" ++ "\n"));
}

test "Crane ReleaseFast's pin: Crane's build identity, in its own mode" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const safe_modes = "optimize=root ReleaseSafe, Crane modules ReleaseSafe, C libraries ReleaseSafe, sanitize_c trap, libc malloc";
    const fast_modes = "optimize=root ReleaseFast, Crane modules ReleaseFast, C libraries ReleaseFast, sanitize_c off, libc malloc";
    const named_fast = try std.mem.replaceOwned(u8, a, crane_pin_text, "name=crane\n", "name=crane_fast\n");
    const fast_text = try std.mem.replaceOwned(u8, a, named_fast, safe_modes, fast_modes);
    const pin = try parsePin(a, fast_text);
    try testing.expectEqual(Name.crane_fast, pin.name);
    try testing.expectEqualStrings(fast_modes["optimize=".len..], pin.optimize.?);
    // Its build identity is required as Crane's is.
    const no_v8 = try std.mem.replaceOwned(u8, a, fast_text, "v8=13.1.203 static\n", "");
    try testing.expectError(error.PinMissingBuildIdentity, parsePin(a, no_v8));
    // A pin whose modes are not its engine's is refused: the ReleaseSafe
    // build under Crane ReleaseFast's name, the ReleaseFast build under
    // Crane's, or the correctness runner under either.
    try testing.expectError(error.PinWrongBuild, parsePin(a, named_fast));
    try testing.expectError(error.PinWrongBuild, parsePin(a, try std.mem.replaceOwned(u8, a, crane_pin_text, safe_modes, fast_modes)));
    try testing.expectError(error.PinWrongBuild, parsePin(a, try std.mem.replaceOwned(u8, a, crane_pin_text, safe_modes, "optimize=root ReleaseSafe, Crane modules Debug, C libraries ReleaseSafe, sanitize_c full")));
}

test "Crane ReleaseFast launches as Crane does: the console, its stdin held open" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const url = "http://127.0.0.1:8000/workloads/dom.html?perf=t";
    const fast = try launch(a, .{ .name = .crane_fast, .version = "v", .build = "b", .binary = "/f/repl", .sha256 = sha, .commit = "c", .optimize = "o", .v8 = "v8" }, url, "/p", 0);
    try expectStrings(&.{ "/f/repl", url, "--proxy=direct", "--timeout=900000" }, fast.argv);
    try expectStrings(&crane_flags, fast.flags);
    try testing.expectEqual(Drive.argv, fast.drive);
    try testing.expectEqual(Drive.argv, driveOf(.crane_fast));
    try testing.expect(fast.stdin_pipe);
    const crane = try launch(a, .{ .name = .crane, .version = "v", .build = "b", .binary = "/b/repl", .sha256 = sha, .commit = "c", .optimize = "o", .v8 = "v8" }, url, "/p", 0);
    try testing.expect(crane.stdin_pipe);
    // The browsers' stdin is not the page's: nothing to hold open.
    const chrome = try launch(a, .{ .name = .chrome, .version = "157", .build = "b", .binary = "/c/chrome", .sha256 = sha }, url, "/p/1", 0);
    try testing.expect(!chrome.stdin_pipe);
}

test "each Crane build runs in its own directory, so it restores its own snapshot" {
    // The console restores the snapshot beside its executable (tools/repl.zig)
    // and, when there is none, the first of src/browser/process.zig
    // DEFAULT_SNAPSHOT_PATHS from its working directory (zig-out/bin/ first):
    // started from the runner's directory, that fallback would be whatever
    // snapshot the directory's last build left (docs/lessons/testing-a-runner-
    // finds-its-snapshot-from-its-working-directory.md). Each frozen build
    // keeps its snapshot beside its binary, and runs there.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const url = "http://127.0.0.1:8000/x.html";
    const safe = try launch(a, .{ .name = .crane, .version = "v", .build = "b", .binary = "/bins/crane-abc/repl", .sha256 = sha, .commit = "c", .optimize = "o", .v8 = "v8" }, url, "/p", 0);
    try testing.expectEqualStrings("/bins/crane-abc", safe.cwd.?);
    const fast = try launch(a, .{ .name = .crane_fast, .version = "v", .build = "b", .binary = "/bins/crane-fast-abc/repl", .sha256 = sha, .commit = "c", .optimize = "o", .v8 = "v8" }, url, "/p", 0);
    try testing.expectEqualStrings("/bins/crane-fast-abc", fast.cwd.?);
    // The flags the journal records are unchanged by it.
    try expectStrings(&crane_flags, fast.flags);
    // A browser keeps the runner's directory.
    const chrome = try launch(a, .{ .name = .chrome, .version = "157", .build = "b", .binary = "/c/chrome", .sha256 = sha }, url, "/p/1", 0);
    try testing.expectEqual(@as(?[]const u8, null), chrome.cwd);
}

test "each engine's command line, and the flags the journal records" {
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const url = "http://127.0.0.1:8000/workloads/dom.html?perf=t";

    const crane = try launch(a, .{ .name = .crane, .version = "v", .build = "b", .binary = "/b/repl", .sha256 = sha, .commit = "c", .optimize = "o", .v8 = "v8" }, url, "/p", 0);
    try testing.expectEqualStrings("/b/repl", crane.argv[0]);
    try testing.expectEqualStrings(url, crane.argv[1]);
    try expectStrings(&crane_flags, crane.flags);

    const chrome = try launch(a, .{ .name = .chrome, .version = "157", .build = "b", .binary = "/c/chrome", .sha256 = sha }, url, "/p/1", 0);
    try testing.expectEqualStrings("--headless=new", chrome.argv[1]);
    try testing.expectEqualStrings("--user-data-dir=/p/1", chrome.argv[chrome.argv.len - 2]);
    try testing.expectEqualStrings(url, chrome.argv[chrome.argv.len - 1]);
    try testing.expectEqualStrings("--user-data-dir=<profile>", chrome.flags[chrome.flags.len - 1]);

    const firefox = try launch(a, .{ .name = .firefox, .version = "146", .build = "b", .binary = "/f/firefox", .sha256 = sha }, url, "/p/2", 0);
    try expectStrings(&.{ "/f/firefox", "--headless", "--no-remote", "--profile", "/p/2", url }, firefox.argv);
    try testing.expectEqualStrings("MOZ_CRASHREPORTER_DISABLE", firefox.env[0][0]);

    const lp = try launch(a, .{ .name = .lightpanda, .version = "n", .build = "b", .binary = "/l/lightpanda", .sha256 = sha }, url, "/p", 9333);
    try expectStrings(&.{ "/l/lightpanda", "serve", "--host", "127.0.0.1", "--port", "9333" }, lp.argv);
    try testing.expectEqual(Drive.cdp, lp.drive);

    const safari = try launch(a, .{ .name = .safari, .version = "26", .build = "b", .binary = "/Applications/Safari.app/Contents/MacOS/Safari", .sha256 = sha, .webdriver = "/usr/bin/safaridriver" }, url, "/p", 4444);
    try expectStrings(&.{ "/usr/bin/safaridriver", "-p", "4444" }, safari.argv);
    try testing.expectEqual(@as(usize, 4), safari.names.len);
    try testing.expectEqual(Drive.webdriver, safari.drive);
}

test "Safari's app is its launch's own: none running before it, and ended after it" {
    // safaridriver starts Safari (--automation) for a session and, on
    // Safari 27.2, leaves it running after Delete Session: the next launch
    // reused it, and its app, Networking and GPU processes - started before
    // that launch - were not counted (perf round 0, 2026-11-06). Safari's
    // app is named so that the runner refuses a launch while one runs and
    // ends the one its launch started, by exact pid.
    var arena: std.heap.ArenaAllocator = .init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const sha = "abababababababababababababababababababababababababababababababab";
    const url = "http://127.0.0.1:8000/x.html";
    const safari = try launch(a, .{ .name = .safari, .version = "27.2", .build = "b", .binary = "/Applications/Safari.app/Contents/MacOS/Safari", .sha256 = sha, .webdriver = "/usr/bin/safaridriver" }, url, "/p", 4444);
    try expectStrings(&.{"Safari"}, safari.app_names);
    // The app is one of the set's names: counted while the launch runs.
    try testing.expect(for (safari.names) |n| {
        if (std.mem.eql(u8, n, "Safari")) break true;
    } else false);
    // Every other engine's processes are its launched tree.
    const chrome = try launch(a, .{ .name = .chrome, .version = "157", .build = "b", .binary = "/c/chrome", .sha256 = sha }, url, "/p/1", 0);
    try testing.expectEqual(@as(usize, 0), chrome.app_names.len);
    const crane = try launch(a, .{ .name = .crane, .version = "v", .build = "b", .binary = "/b/repl", .sha256 = sha, .commit = "c", .optimize = "o", .v8 = "v8" }, url, "/p", 0);
    try testing.expectEqual(@as(usize, 0), crane.app_names.len);
}

test "a file's SHA-256" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(testing.io, .{ .sub_path = "f", .data = "abc" });
    const path = try tmp.dir.realPathFileAlloc(testing.io, "f", testing.allocator);
    defer testing.allocator.free(path);
    var hex: [64]u8 = undefined;
    try sha256File(testing.io, path, &hex);
    try testing.expectEqualStrings("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", &hex);
}

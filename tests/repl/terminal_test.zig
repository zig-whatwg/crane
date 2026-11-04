//! The browser console's live page, through its real input path: the
//! terminal's own thread reads lines from a pipe, as it reads piped input,
//! and posts them to the Browser's event loop, which the main thread runs all
//! the while (tools/repl.zig, `Terminal`). What the page does while the
//! console waits for input - a timer that fires, the navigation it starts -
//! happens then, not at the next input. And the command line.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const repl = @import("repl");
const Console = repl.Console;
const Terminal = repl.Terminal;
const Site = @import("site.zig").Site;

/// A pipe the test writes the console's input into.
const Pipe = struct {
    read: std.posix.fd_t,
    write: std.posix.fd_t,

    fn open() !Pipe {
        var fds: [2]std.posix.fd_t = undefined;
        if (std.c.pipe(&fds) != 0) return error.PipeFailed;
        return .{ .read = fds[0], .write = fds[1] };
    }

    fn send(self: *Pipe, text: []const u8) !void {
        var rest = text;
        while (rest.len > 0) {
            const n = std.c.write(self.write, rest.ptr, rest.len);
            if (n <= 0) return error.WriteFailed;
            rest = rest[@intCast(n)..];
        }
    }

    fn closeWrite(self: *Pipe) void {
        if (self.write >= 0) _ = std.c.close(self.write);
        self.write = -1;
    }

    fn close(self: *Pipe) void {
        self.closeWrite();
        _ = std.c.close(self.read);
    }
};

/// Run the loop, as the console's main thread does while the terminal waits
/// for input, until the console has printed `text`.
fn runUntilPrinted(browser: *Browser, console: *Console, output: *std.Io.Writer.Allocating, text: []const u8) !void {
    const Goal = struct {
        console: *Console,
        output: *std.Io.Writer.Allocating,
        text: []const u8,
        fn met(context: *anyopaque) bool {
            const goal: *@This() = @ptrCast(@alignCast(context));
            goal.console.poll();
            std.Io.Threaded.mutexLockUncancelable(&goal.console.out_mutex);
            defer std.Io.Threaded.mutexUnlock(&goal.console.out_mutex);
            return std.mem.indexOf(u8, goal.output.written(), goal.text) != null;
        }
    };
    var goal: Goal = .{ .console = console, .output = output, .text = text };
    const outcome = try browser.spinEventLoopUntil(.{ .context = &goal, .met = Goal.met }, 20_000);
    if (outcome != .met) {
        std.debug.print("never printed {s}; printed:\n{s}\n", .{ text, output.written() });
        return error.TestNotPrinted;
    }
}

test "while the console waits for input the page lives: a timer fires and navigates, and the next line reads the new page" {
    const site = try Site.start(testing.allocator);
    defer site.stop();
    const later = try site.url(testing.allocator, "/later.html?50");
    defer testing.allocator.free(later);
    const b = try site.url(testing.allocator, "/b.html");
    defer testing.allocator.free(b);

    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var output: std.Io.Writer.Allocating = .init(testing.allocator);
    defer output.deinit();
    var console = Console.init(testing.allocator, browser, &output.writer);
    defer console.deinit();
    console.load_timeout_ms = 20_000;
    // The page arms its timer when it loads; the console then waits for
    // input, and none comes until the timer's navigation is printed.
    console.open(later);
    try console.runUntilReady();
    try testing.expectEqualStrings("'later'\n", blk: {
        output.clearRetainingCapacity();
        _ = try console.feedLine("document.title");
        break :blk output.written();
    });

    var pipe = try Pipe.open();
    defer pipe.close();
    var terminal = try Terminal.init(testing.allocator, testing.io, &console, browser, .{ .handle = pipe.read, .flags = .{ .nonblocking = false } }, &output.writer);
    defer terminal.deinit();
    try terminal.start();
    defer terminal.stop();
    console.begin();

    const navigated = try std.fmt.allocPrint(testing.allocator, "Navigated to {s} (200)\n", .{b});
    defer testing.allocator.free(navigated);
    try runUntilPrinted(browser, &console, &output, navigated);
    // Only now does input come: the line the terminal's thread reads.
    try pipe.send("document.title\n.exit\n");
    _ = try browser.spinEventLoopUntil(.{ .context = &console, .met = Console.exitGoal }, 20_000);
    terminal.stop();
    try testing.expect(console.exit_requested);
    const printed = output.written();
    const after = std.mem.indexOf(u8, printed, navigated).? + navigated.len;
    if (std.mem.indexOf(u8, printed[after..], "'B'\n") == null) {
        std.debug.print("printed:\n{s}\n", .{printed});
        return error.TestNewTitleNotRead;
    }
}

test "the end of piped input ends the console, after the input before it has run" {
    const browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    var output: std.Io.Writer.Allocating = .init(testing.allocator);
    defer output.deinit();
    var console = Console.init(testing.allocator, browser, &output.writer);
    defer console.deinit();

    var pipe = try Pipe.open();
    defer pipe.close();
    try pipe.send("await new Promise(r => setTimeout(() => r(6 * 7), 20))\n");
    pipe.closeWrite();
    var terminal = try Terminal.init(testing.allocator, testing.io, &console, browser, .{ .handle = pipe.read, .flags = .{ .nonblocking = false } }, &output.writer);
    defer terminal.deinit();
    try terminal.start();
    defer terminal.stop();
    console.begin();
    const outcome = try browser.spinEventLoopUntil(.{ .context = &console, .met = Console.exitGoal }, 20_000);
    terminal.stop();
    try testing.expectEqual(Browser.SpinOutcome.met, outcome);
    if (std.mem.indexOf(u8, output.written(), "42\n") == null) {
        std.debug.print("printed:\n{s}\n", .{output.written()});
        return error.TestResultNotPrinted;
    }
}

test "the command line: a URL, the Browser's options, and what is refused" {
    var bad: []const u8 = "";
    const defaults = try repl.parseOptions(&.{}, &bad);
    try testing.expectEqualStrings("about:blank", defaults.url);
    try testing.expect(!defaults.accept_insecure_certs);
    try testing.expect(!defaults.wait_for_navigation);
    try testing.expectEqual(Console.default_deadline_ms, defaults.timeout_ms);
    try testing.expect(defaults.proxy == .system);

    const options = try repl.parseOptions(&.{ "https://example.com/", "--user-agent=Agent/1", "--proxy=http://127.0.0.1:3128", "--accept-insecure-certs", "--timeout=500", "--wait-for-navigation" }, &bad);
    try testing.expectEqualStrings("https://example.com/", options.url);
    try testing.expectEqualStrings("Agent/1", options.user_agent.?);
    try testing.expectEqualStrings("http://127.0.0.1:3128", options.proxy.manual.http.?);
    try testing.expectEqualStrings("http://127.0.0.1:3128", options.proxy.manual.https.?);
    try testing.expect(options.accept_insecure_certs);
    try testing.expectEqual(@as(u64, 500), options.timeout_ms);
    try testing.expect(options.wait_for_navigation);
    try testing.expect((try repl.parseOptions(&.{"--proxy=direct"}, &bad)).proxy == .direct);

    try testing.expectError(error.UnknownOption, repl.parseOptions(&.{"--nope"}, &bad));
    try testing.expectEqualStrings("--nope", bad);
    try testing.expectError(error.InvalidTimeout, repl.parseOptions(&.{"--timeout=soon"}, &bad));
    try testing.expectError(error.TooManyArguments, repl.parseOptions(&.{ "a:", "b:" }, &bad));
    // A profile directory is taken, for the console to refuse it.
    try testing.expectEqualStrings("/tmp/p", (try repl.parseOptions(&.{"--profile=/tmp/p"}, &bad)).profile.?);
}

test "Ctrl+C at a prompt, as Node's REPL: the line goes; on an empty prompt the first says how to exit and a second exits; any other key between resets it" {
    const ExitGuard = repl.ExitGuard;
    var guard: ExitGuard = .{};
    try testing.expectEqual(ExitGuard.Answer.clear_line, guard.interrupt(false, false));
    try testing.expectEqual(ExitGuard.Answer.hint, guard.interrupt(true, false));
    try testing.expectEqual(ExitGuard.Answer.exit, guard.interrupt(true, false));

    guard = .{};
    try testing.expectEqual(ExitGuard.Answer.hint, guard.interrupt(true, false));
    guard.key();
    try testing.expectEqual(ExitGuard.Answer.hint, guard.interrupt(true, false));
    // An input continued over lines (`...`): the input goes, never an exit.
    try testing.expectEqual(ExitGuard.Answer.clear_line, guard.interrupt(true, true));
    try testing.expectEqual(ExitGuard.Answer.hint, guard.interrupt(true, false));
    try testing.expectEqualStrings("(To exit, press Ctrl+C again or Ctrl+D or type .exit)\n", ExitGuard.hint_text);
}

test "--check-leaks is an option of its own" {
    var bad: []const u8 = "";
    try testing.expect(!(try repl.parseOptions(&.{}, &bad)).check_leaks);
    try testing.expect((try repl.parseOptions(&.{"--check-leaks"}, &bad)).check_leaks);
}

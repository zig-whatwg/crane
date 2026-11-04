//! The browser console (tools/repl.zig, `Console`), driven in-process: lines
//! fed in, what it prints read back. What a console gets from the engine and
//! the Browser - REPL-mode evaluation (top-level await, `let` declared
//! again), the event loop running while it waits, the Console Standard's
//! printer - and what it must not do: put anything of its own on the page.
const std = @import("std");
const testing = std.testing;
const Browser = @import("browser").Browser;
const engine = @import("engine");
const printer = @import("console").printer;
const clock = @import("clock");
const Console = @import("repl").Console;
const LoopbackListener = @import("loopback_listener").LoopbackListener;

/// A Browser on about:blank and a console on it, printing into a buffer.
/// Not moved once made: the console writes into `output`.
const Fixture = struct {
    browser: *Browser,
    output: std.Io.Writer.Allocating,
    console: Console,

    fn init(self: *Fixture) !void {
        self.browser = try Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
        errdefer self.browser.deinit();
        try self.browser.navigate("about:blank", .window);
        self.output = .init(testing.allocator);
        self.console = Console.init(testing.allocator, self.browser, &self.output.writer);
    }

    fn deinit(self: *Fixture) void {
        self.console.deinit();
        self.output.deinit();
        self.browser.deinit();
    }

    /// Feed `line`: what the console printed for it.
    fn run(self: *Fixture, line: []const u8) ![]const u8 {
        self.output.clearRetainingCapacity();
        _ = try self.console.feedLine(line);
        return self.output.written();
    }

    /// Feed `line` and expect exactly `expected` printed.
    fn expect(self: *Fixture, line: []const u8, expected: []const u8) !void {
        try testing.expectEqualStrings(expected, try self.run(line));
    }

    /// The page's own answer to `script`, ToString'd (not the console's).
    fn page(self: *Fixture, script: []const u8) ![]u8 {
        return self.browser.current_context.?.evaluateScriptToString(script, testing.allocator);
    }
};

/// A loopback HTTP server answering every request with `body`, until stopped.
const Server = struct {
    listener: LoopbackListener,
    body: []const u8,
    thread: ?std.Thread = null,

    fn start(body: []const u8) !*Server {
        const self = try testing.allocator.create(Server);
        errdefer testing.allocator.destroy(self);
        self.* = .{ .listener = try LoopbackListener.open(.{}), .body = body };
        errdefer self.listener.close();
        self.thread = try std.Thread.spawn(.{}, serve, .{self});
        return self;
    }

    /// Stop accepting, join, then close - in that order (lane fixes1).
    fn stop(self: *Server) void {
        self.listener.stop();
        self.thread.?.join();
        self.listener.close();
        testing.allocator.destroy(self);
    }

    fn serve(self: *Server) void {
        while (self.listener.accept()) |stream| {
            defer stream.close(testing.io);
            self.reply(stream) catch {};
        }
    }

    fn reply(self: *Server, stream: std.Io.net.Stream) !void {
        var input: [8192]u8 = undefined;
        var reader = stream.reader(testing.io, &input);
        while (std.mem.indexOf(u8, reader.interface.buffered(), "\r\n\r\n") == null) try reader.interface.fillMore();
        var output: [512]u8 = undefined;
        var writer = stream.writer(testing.io, &output);
        try writer.interface.print("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {d}\r\nConnection: close\r\n\r\n{s}", .{ self.body.len, self.body });
        try writer.interface.flush();
    }

    fn url(self: *Server, buffer: []u8) ![]const u8 {
        return std.fmt.bufPrint(buffer, "http://127.0.0.1:{d}/", .{self.listener.port()});
    }
};

test "await fetch(..) shows the response: the event loop runs the network while the console waits" {
    const server = try Server.start("hello");
    defer server.stop();
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    var url_buffer: [64]u8 = undefined;
    const url = try server.url(&url_buffer);

    const status = try std.fmt.allocPrint(testing.allocator, "(await fetch('{s}')).status", .{url});
    defer testing.allocator.free(status);
    try f.expect(status, "200\n");
    const text = try std.fmt.allocPrint(testing.allocator, "await (await fetch('{s}')).text()", .{url});
    defer testing.allocator.free(text);
    try f.expect(text, "'hello'\n");
}

test "await of a timer's promise settles: the event loop runs timers while the console waits" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.expect("await new Promise(r => setTimeout(() => r('done'), 10))", "'done'\n");
}

test "let declared again replaces the earlier binding (REPL mode)" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.expect("let x = 1", "undefined\n");
    try f.expect("let x = 2", "undefined\n");
    try f.expect("x", "2\n");
}

test "a string literal that says await is a string" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.expect("'await'", "'await'\n");
}

test "a destructuring declaration of an awaited value binds its names" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.expect("const {a} = await Promise.resolve({a: 1})", "undefined\n");
    try f.expect("a", "1\n");
}

test "nothing of the console is put on the page's global, while it waits or after" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const before = try f.page("JSON.stringify(Object.keys(window))");
    defer testing.allocator.free(before);
    // The page's own lexical binding, which the page's timer below reads.
    const recorded = try f.page("const keysBefore = Object.keys(window); 'ok'");
    defer testing.allocator.free(recorded);

    // While the console waits for this input, the page's timer looks.
    try f.expect("await new Promise(r => setTimeout(() => r(Object.keys(window).filter(k => !keysBefore.includes(k))), 10))", "[]\n");
    _ = try f.run("1 + 1");
    _ = try f.run("let y = await 3");
    _ = try f.run("class K {}");
    _ = try f.run("throw new Error('x')");
    var completions = try f.console.complete(testing.allocator, "docu");
    completions.deinit(testing.allocator);

    const after = try f.page("JSON.stringify(Object.keys(window))");
    defer testing.allocator.free(after);
    try testing.expectEqualStrings(before, after);
    // Nor on the page's console: V8's inspector gives a context's console a
    // createTask, which the session takes off again.
    const create_task = try f.page("typeof console.createTask");
    defer testing.allocator.free(create_task);
    try testing.expectEqualStrings("undefined", create_task);
}

test "a thrown error and a rejected awaited promise print as an uncaught error" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try testing.expect(std.mem.startsWith(u8, try f.run("throw new Error('boom')"), "Uncaught Error: boom\n"));
    try testing.expect(std.mem.startsWith(u8, try f.run("await Promise.reject(new Error('nope'))"), "Uncaught Error: nope\n"));
    try f.expect("throw 1", "Uncaught 1\n");
    try testing.expect(std.mem.startsWith(u8, try f.run(")"), "Uncaught SyntaxError: Unexpected token ')'\n"));
}

/// What console.log prints for the page's value of `expression`.
fn loggedBy(f: *Fixture, expression: []const u8) ![]u8 {
    const value = try f.browser.evaluateScript(expression);
    defer value.release();
    var logged: std.Io.Writer.Allocating = .init(testing.allocator);
    defer logged.deinit();
    try printer.printLogged(testing.allocator, f.browser.getRealm().?, &.{value.value}, 0, &logged.writer);
    return testing.allocator.dupe(u8, logged.written());
}

test "1n, an Array, an Element, a Map and a Set print as console.log prints them" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    const cases = [_]struct { input: []const u8, printed: []const u8 }{
        .{ .input = "1n", .printed = "1n\n" },
        .{ .input = "[1, 'a', [2, [3, [4]]], , -0]", .printed = "[1, 'a', [2, [3, [Array]]], <1 empty item>, -0]\n" },
        .{ .input = "(() => { const d = document.createElement('div'); d.id = 'a'; d.textContent = 'hi'; return d; })()", .printed = "<div id=\"a\">hi</div>\n" },
        .{ .input = "new Map([['k', 1]])", .printed = "Map(1) {'k' => 1}\n" },
        .{ .input = "new Set([1, 2])", .printed = "Set(2) {1, 2}\n" },
        .{ .input = "({a: 1, 'b-c': {d: [true]}})", .printed = "{a: 1, 'b-c': {d: [true]}}\n" },
    };
    for (cases) |case| {
        try f.expect(case.input, case.printed);
        const logged = try loggedBy(&f, case.input);
        defer testing.allocator.free(logged);
        try testing.expectEqualStrings(case.printed, logged);
    }
}

test "a promise completion value is shown as the promise, never adopted" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    try f.expect("Promise.resolve(1)", "Promise {}\n");
    try f.expect("({then(resolve) { resolve(2); }})", "{then: [Function: then]}\n");
}

test "input that ends too soon asks for more, and the whole input runs once complete" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    f.output.clearRetainingCapacity();
    try testing.expectEqual(Console.Prompt.more, try f.console.feedLine("function f() {"));
    try testing.expectEqualStrings("", f.output.written());
    try testing.expectEqual(Console.Prompt.ready, try f.console.feedLine("return 41 + 1 }"));
    try testing.expectEqualStrings("undefined\n", f.output.written());
    try f.expect("f()", "42\n");

    f.output.clearRetainingCapacity();
    try testing.expectEqual(Console.Prompt.more, try f.console.feedLine("`a"));
    try testing.expectEqual(Console.Prompt.ready, try f.console.feedLine("b`"));
    try testing.expectEqualStrings("'a\\nb'\n", f.output.written());
}

test "an await that never settles returns after the console's deadline" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    f.console.deadline_ms = 300;
    const start = clock.monotonicMillis();
    const printed = try f.run("await new Promise(() => {})");
    const waited = clock.monotonicMillis() - start;
    try testing.expect(waited >= 300);
    try testing.expect(waited < 10_000);
    try testing.expect(std.mem.startsWith(u8, printed, "Promise {<pending>}"));
    // The console goes on: the abandoned evaluation is not waited for.
    try f.expect("2 + 2", "4\n");
}

test "tab completion lists the properties of a dotted path without running the input" {
    var f: Fixture = undefined;
    try f.init();
    defer f.deinit();
    var globals = try f.console.complete(testing.allocator, "docu");
    defer globals.deinit(testing.allocator);
    try testing.expect(globals.contains("document"));
    try testing.expectEqual(@as(usize, 4), globals.prefix_len);

    var members = try f.console.complete(testing.allocator, "x = document.bo");
    defer members.deinit(testing.allocator);
    try testing.expect(members.contains("body"));

    // A call is never made to complete what follows it.
    var after_call = try f.console.complete(testing.allocator, "alert('x').fo");
    defer after_call.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), after_call.names.len);
}

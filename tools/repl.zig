//! The browser console: a Browser showing a page, and the console that
//! evaluates in it - what Chrome DevTools' console is to a tab.
//!
//! Run it:
//!
//!     zig build repl-exe -j2 -Doptimize=ReleaseSafe --cache-dir ~/Library/Caches/crane-z16-cache
//!     ./zig-out/bin/repl
//!
//! (`zig build repl-exe` builds this binary and its snapshot, nothing else;
//! `zig build repl` builds it and runs it.) Type JavaScript; Enter evaluates
//! once the input is complete, Tab completes a name, the arrows walk the
//! history, Ctrl+D exits.
//!
//! What the console gets from the engine and the Browser, and nothing else:
//!
//! - REPL mode (engine.evaluateReplScript, [repl_mode]): input is evaluated
//!   as Chrome's console evaluates it - top-level `await`, and a `let`,
//!   `const` or `class` declared again replacing the earlier one. Input that
//!   ends too soon (an open block, argument list or template literal) asks
//!   for another line (`...`), as Node's and Chrome's consoles do: the
//!   engine says so, from its own parser.
//! - The page keeps running while an input waits: the console spins the
//!   Browser's event loop (Browser.spinEventLoopUntil, HTML "spin the event
//!   loop") - tasks, timers, the network - until the evaluation completes,
//!   or `deadline_ms` (30 s) passes, when it prints the input as still
//!   pending and stops waiting for it.
//! - Results print through the Console Standard's printer
//!   (src/console/printer.zig) - the one `console.log` uses - and what the
//!   input throws prints as an uncaught exception does ("Uncaught ...").
//! - Nothing of the console is put on the page: no globals, no wrapper
//!   source around the input. Tab completion reads properties along a dotted
//!   name (getters run) and never evaluates the input.
//!
//! On an engine without REPL mode (JavaScriptCore, QuickJS:
//! engine.capabilities.repl_mode is `.unsupported`) each input is evaluated
//! as a classic script of its own (engine.evaluateClassicScript): no
//! top-level await, a re-declaration is a SyntaxError, and every line is a
//! whole input. The console says so when it starts.

const std = @import("std");
const engine = @import("engine");
const Browser = @import("browser").Browser;
const printer = @import("console").printer;

/// No debug log lines in a Debug build of the console: the console's output
/// is what the user reads (tools/gc_bench.zig does the same).
pub const std_options: std.Options = .{ .log_level = .warn };

/// The console core: lines of input in, evaluation and printing out. The
/// terminal (`LineEditor`, `main`) is a thin shell around it; a test feeds it
/// lines and reads what it printed.
pub const Console = struct {
    allocator: std.mem.Allocator,
    browser: *Browser,
    /// Where results go (flushed after each).
    out: *std.Io.Writer,
    /// How long an evaluation is waited for, in milliseconds of real time.
    deadline_ms: u64 = default_deadline_ms,
    /// The lines of an input that is not complete yet.
    input: std.ArrayListUnmanaged(u8) = .empty,

    pub const default_deadline_ms: u64 = 30_000;

    /// Which prompt the next line answers.
    pub const Prompt = enum {
        /// A new input.
        ready,
        /// More of the input so far, which ended too soon.
        more,
    };

    pub fn init(allocator: std.mem.Allocator, browser: *Browser, out: *std.Io.Writer) Console {
        return .{ .allocator = allocator, .browser = browser, .out = out };
    }

    pub fn deinit(self: *Console) void {
        self.input.deinit(self.allocator);
    }

    /// What the console says when it starts.
    pub fn banner(self: *Console) !void {
        try self.out.print("Crane browser console ({s}). Tab completes, Ctrl+D exits.\n", .{engine.name});
        if (comptime engine.capabilities.repl_mode == .unsupported) {
            try self.out.print("{s} has no REPL mode: each input is a classic script of its own - no top-level await, no re-declaration.\n", .{engine.name});
        }
        try self.out.flush();
    }

    /// One line of input. Once the input is complete it is evaluated, and
    /// its result printed; input that ends too soon waits for more.
    pub fn feedLine(self: *Console, line: []const u8) !Prompt {
        if (self.input.items.len > 0) try self.input.append(self.allocator, '\n');
        try self.input.appendSlice(self.allocator, line);
        if (std.mem.trim(u8, self.input.items, &std.ascii.whitespace).len == 0) {
            self.input.clearRetainingCapacity();
            return .ready;
        }
        const evaluated = try self.evaluate(self.input.items);
        if (evaluated == .incomplete) return .more;
        self.input.clearRetainingCapacity();
        return .ready;
    }

    const Evaluated = enum { done, incomplete };

    /// Evaluate `source` in the page, wait for it, print what it came to.
    fn evaluate(self: *Console, source: []const u8) !Evaluated {
        defer self.out.flush() catch {};
        const realm = self.browser.getRealm() orelse {
            try self.out.writeAll("(no page to evaluate in)\n");
            return .done;
        };
        if (comptime engine.capabilities.repl_mode == .unsupported) return self.evaluateClassic(realm, source);

        const evaluation = try Evaluation.create(self.allocator, realm);
        const started = engine.evaluateReplScript(realm, source, &Evaluation.steps, evaluation) catch |err| {
            evaluation.destroy();
            try self.out.print("(the console could not evaluate: {s})\n", .{@errorName(err)});
            return .done;
        };
        if (started == .incomplete) {
            evaluation.destroy();
            return .incomplete;
        }
        const outcome = self.browser.spinEventLoopUntil(.{ .context = evaluation, .met = Evaluation.settled }, self.deadline_ms) catch |err| {
            evaluation.abandon();
            try self.out.print("(the console could not wait: {s})\n", .{@errorName(err)});
            return .done;
        };
        if (outcome == .timed_out) {
            evaluation.abandon();
            try self.out.print("Promise {{<pending>}} (still pending after {d} ms: the console stopped waiting)\n", .{self.deadline_ms});
            return .done;
        }
        defer evaluation.destroy();
        try evaluation.print(self.out);
        return .done;
    }

    /// The declared fallback without REPL mode: `source` as a classic script
    /// of its own, its completion value printed, or what it threw.
    fn evaluateClassic(self: *Console, realm: engine.Context, source: []const u8) !Evaluated {
        var thrown: Thrown = .{ .realm = realm };
        defer thrown.deinit();
        const value = engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, thrown.reporter()) catch |err| {
            if (err == error.ExceptionReported) {
                if (thrown.value) |v| {
                    try printer.printUncaught(self.allocator, realm, v.value, self.out);
                    return .done;
                }
            }
            try self.out.print("(the console could not evaluate: {s})\n", .{@errorName(err)});
            return .done;
        };
        defer value.release();
        try printer.printResult(self.allocator, realm, value.value, self.out);
        return .done;
    }

    /// What a classic script threw, kept from its report.
    const Thrown = struct {
        realm: engine.Context,
        value: ?engine.Owned = null,

        fn reporter(self: *Thrown) engine.Reporter {
            return .{ .report = report, .host = self };
        }

        fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
            const self: *Thrown = @ptrCast(@alignCast(host.?));
            if (self.value != null) return;
            self.value = engine.retainValue(self.realm, info.error_value) catch null;
        }

        fn deinit(self: *Thrown) void {
            if (self.value) |v| v.release();
        }
    };

    /// Tab completion's answer: the names that complete the input's last
    /// word, sorted, and that word's length.
    pub const Completions = struct {
        names: [][]u8,
        prefix_len: usize,

        pub fn deinit(self: *Completions, allocator: std.mem.Allocator) void {
            for (self.names) |name| allocator.free(name);
            allocator.free(self.names);
        }

        pub fn contains(self: *const Completions, name: []const u8) bool {
            for (self.names) |n| if (std.mem.eql(u8, n, name)) return true;
            return false;
        }
    };

    /// The names that complete `text`'s last word: the enumerable property
    /// names of the object its dotted name before the word reaches (the
    /// global object's, for a word with no dot), along its prototype chain -
    /// what `for (k in o)` lists. The input is never evaluated: only a chain
    /// of identifiers is followed, property by property (a getter on the way
    /// runs), and anything else completes nothing.
    pub fn complete(self: *Console, allocator: std.mem.Allocator, text: []const u8) !Completions {
        var names: std.ArrayListUnmanaged([]u8) = .empty;
        errdefer {
            for (names.items) |n| allocator.free(n);
            names.deinit(allocator);
        }
        // The trailing `a.b.c` of the input.
        var start = text.len;
        while (start > 0 and (isIdentifierChar(text[start - 1]) or text[start - 1] == '.')) start -= 1;
        const chain = text[start..];
        const dot = std.mem.lastIndexOfScalar(u8, chain, '.');
        const prefix = if (dot) |d| chain[d + 1 ..] else chain;
        const path = if (dot) |d| chain[0..d] else "";
        if (chain.len == 0) return nothing(allocator, 0);
        if (dot != null and !validPath(path)) return nothing(allocator, prefix.len);
        if (dot == null and std.ascii.isDigit(chain[0])) return nothing(allocator, prefix.len);

        const realm = self.browser.getRealm() orelse return nothing(allocator, prefix.len);
        const window = (self.browser.current_context orelse return nothing(allocator, prefix.len)).window_instance orelse return nothing(allocator, prefix.len);
        var object = engine.retainValue(realm, .{ .instance = window }) catch return nothing(allocator, prefix.len);
        defer object.release();
        if (path.len > 0) {
            var segments = std.mem.splitScalar(u8, path, '.');
            while (segments.next()) |segment| {
                const next = get(realm, object.value, segment) orelse return nothing(allocator, prefix.len);
                object.release();
                object = next;
                if (engine.typeOf(realm, object.value) != .object) return nothing(allocator, prefix.len);
            }
        }

        var seen: std.StringHashMapUnmanaged(void) = .empty;
        defer seen.deinit(allocator);
        var link = try engine.retainValue(realm, object.value);
        defer link.release();
        var levels: usize = 0;
        while (levels < 64 and engine.typeOf(realm, link.value) == .object) : (levels += 1) {
            const keys = keysOf(realm, link.value, allocator) orelse break;
            defer {
                for (keys) |k| allocator.free(k);
                allocator.free(keys);
            }
            for (keys) |key| {
                if (!std.mem.startsWith(u8, key, prefix) or seen.contains(key)) continue;
                const name = try allocator.dupe(u8, key);
                errdefer allocator.free(name);
                try names.append(allocator, name);
                try seen.put(allocator, name, {});
            }
            const parent = get(realm, link.value, "__proto__") orelse break;
            link.release();
            link = parent;
        }
        std.mem.sort([]u8, names.items, {}, struct {
            fn lessThan(_: void, a: []u8, b: []u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lessThan);
        return .{ .names = try names.toOwnedSlice(allocator), .prefix_len = prefix.len };
    }

    fn nothing(allocator: std.mem.Allocator, prefix_len: usize) !Completions {
        return .{ .names = try allocator.alloc([]u8, 0), .prefix_len = prefix_len };
    }

    /// Get(object, name), what it throws caught: null for a throw.
    fn get(realm: engine.Context, object: engine.JSValue, name: []const u8) ?engine.Owned {
        const Call = struct {
            realm: engine.Context,
            object: engine.JSValue,
            name: []const u8,
            result: ?engine.Owned = null,
            fn run(data: ?*anyopaque) engine.Error!void {
                const call: *@This() = @ptrCast(@alignCast(data.?));
                call.result = try engine.getProperty(call.realm, call.object, call.name);
            }
        };
        var call: Call = .{ .realm = realm, .object = object, .name = name };
        const thrown = engine.completionOf(realm, Call.run, &call) catch return null;
        if (thrown) |t| {
            t.release();
            if (call.result) |r| r.release();
            return null;
        }
        return call.result;
    }

    /// EnumerableOwnProperties(object, key), what it throws caught: null
    /// for a throw. OWNED by `allocator`.
    fn keysOf(realm: engine.Context, object: engine.JSValue, allocator: std.mem.Allocator) ?[][]u8 {
        const Call = struct {
            realm: engine.Context,
            object: engine.JSValue,
            allocator: std.mem.Allocator,
            result: ?[][]u8 = null,
            fn run(data: ?*anyopaque) engine.Error!void {
                const call: *@This() = @ptrCast(@alignCast(data.?));
                call.result = try engine.enumerableOwnPropertyKeys(call.realm, call.object, call.allocator);
            }
        };
        var call: Call = .{ .realm = realm, .object = object, .allocator = allocator };
        const thrown = engine.completionOf(realm, Call.run, &call) catch null;
        if (thrown) |t| {
            t.release();
            return null;
        }
        return call.result;
    }

    fn isIdentifierChar(c: u8) bool {
        return std.ascii.isAlphanumeric(c) or c == '_' or c == '$';
    }

    /// Whether `path` is identifiers joined by single dots.
    fn validPath(path: []const u8) bool {
        if (path.len == 0) return false;
        var segments = std.mem.splitScalar(u8, path, '.');
        while (segments.next()) |segment| {
            if (segment.len == 0 or std.ascii.isDigit(segment[0])) return false;
        }
        return true;
    }
};

/// One input's evaluation, until it completes and is printed - or, when the
/// console stops waiting for it, until the engine ends it (exactly one of
/// its steps runs: engine.evaluateReplScript).
const Evaluation = struct {
    allocator: std.mem.Allocator,
    realm: engine.Context,
    state: State = .waiting,
    /// The completion value, or what was thrown. OWNED.
    value: ?engine.Owned = null,
    /// The console stopped waiting: whichever step ends the evaluation frees
    /// it.
    abandoned: bool = false,

    const State = enum { waiting, completed, threw, dropped };

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = completed, .rejected = threw, .dropped = dropped };

    fn create(allocator: std.mem.Allocator, realm: engine.Context) !*Evaluation {
        const self = try allocator.create(Evaluation);
        self.* = .{ .allocator = allocator, .realm = realm };
        return self;
    }

    fn destroy(self: *Evaluation) void {
        if (self.value) |v| v.release();
        self.allocator.destroy(self);
    }

    /// The console stops waiting: free it now if it has ended, else when it
    /// does.
    fn abandon(self: *Evaluation) void {
        if (self.state == .waiting) self.abandoned = true else self.destroy();
    }

    fn settled(context: *anyopaque) bool {
        const self: *Evaluation = @ptrCast(@alignCast(context));
        return self.state != .waiting;
    }

    fn end(data: ?*anyopaque, state: State, value: ?engine.JSValue) void {
        const self: *Evaluation = @ptrCast(@alignCast(data.?));
        if (self.abandoned) return self.destroy();
        if (value) |v| self.value = engine.retainValue(self.realm, v) catch null;
        self.state = state;
    }

    fn completed(data: ?*anyopaque, value: engine.JSValue) void {
        end(data, .completed, value);
    }

    fn threw(data: ?*anyopaque, value: engine.JSValue) void {
        end(data, .threw, value);
    }

    fn dropped(data: ?*anyopaque) void {
        end(data, .dropped, null);
    }

    fn print(self: *Evaluation, out: *std.Io.Writer) !void {
        switch (self.state) {
            .waiting => unreachable,
            .completed => if (self.value) |v| try printer.printResult(self.allocator, self.realm, v.value, out) else try out.writeAll("(the result could not be kept)\n"),
            .threw => if (self.value) |v| try printer.printUncaught(self.allocator, self.realm, v.value, out) else try out.writeAll("Uncaught (the exception could not be kept)\n"),
            .dropped => try out.writeAll("(no result: the page went away)\n"),
        }
    }
};

/// The terminal's line editor: raw-mode input with cursor movement, history
/// and tab completion (the console's), echoing to stdout. Without a terminal
/// (input piped in) it reads lines as they come.
const LineEditor = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    console: *Console,
    stdin: std.Io.File,
    stdout: std.Io.File,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    history: std.ArrayListUnmanaged([]u8) = .empty,

    fn init(allocator: std.mem.Allocator, io: std.Io, console: *Console) LineEditor {
        return .{ .allocator = allocator, .io = io, .console = console, .stdin = std.Io.File.stdin(), .stdout = std.Io.File.stdout() };
    }

    fn deinit(self: *LineEditor) void {
        for (self.history.items) |item| self.allocator.free(item);
        self.history.deinit(self.allocator);
        self.buffer.deinit(self.allocator);
    }

    fn write(self: *LineEditor, bytes: []const u8) !void {
        try self.stdout.writeStreamingAll(self.io, bytes);
    }

    fn print(self: *LineEditor, comptime format: []const u8, args: anytype) !void {
        var buffer: [64]u8 = undefined;
        try self.write(try std.fmt.bufPrint(&buffer, format, args));
    }

    fn readByte(self: *LineEditor) !u8 {
        var byte: [1]u8 = undefined;
        const n = try self.stdin.readStreaming(self.io, &.{&byte});
        if (n == 0) return error.EndOfStream;
        return byte[0];
    }

    fn addHistory(self: *LineEditor, line: []const u8) !void {
        if (line.len == 0) return;
        if (self.history.items.len > 0 and std.mem.eql(u8, self.history.items[self.history.items.len - 1], line)) return;
        try self.history.append(self.allocator, try self.allocator.dupe(u8, line));
    }

    /// Replace the line being edited with `content`, the cursor at its end.
    fn replaceLine(self: *LineEditor, content: []const u8, cursor: *usize) !void {
        if (cursor.* > 0) try self.print("\x1b[{d}D", .{cursor.*});
        try self.write("\x1b[K");
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendSlice(self.allocator, content);
        try self.write(content);
        cursor.* = content.len;
    }

    /// Redraw from `cursor` to the end of the line, the cursor kept.
    fn redrawFrom(self: *LineEditor, cursor: usize) !void {
        const rest = self.buffer.items[cursor..];
        try self.write(rest);
        try self.write(" ");
        try self.print("\x1b[{d}D", .{rest.len + 1});
    }

    /// One line, after `prompt`: null at the end of input (Ctrl+D). OWNED.
    fn readLine(self: *LineEditor, prompt: []const u8) !?[]u8 {
        try self.write(prompt);
        const is_tty = try self.stdin.isTty(self.io);
        var original: std.posix.termios = undefined;
        if (is_tty) {
            original = try std.posix.tcgetattr(self.stdin.handle);
            var raw = original;
            raw.lflag.ICANON = false;
            raw.lflag.ECHO = false;
            raw.cc[@backingInt(std.posix.V.MIN)] = 1;
            raw.cc[@backingInt(std.posix.V.TIME)] = 0;
            try std.posix.tcsetattr(self.stdin.handle, .FLUSH, raw);
        }
        defer if (is_tty) std.posix.tcsetattr(self.stdin.handle, .FLUSH, original) catch {};

        self.buffer.clearRetainingCapacity();
        var cursor: usize = 0;
        var history_index = self.history.items.len;
        var saved: ?[]u8 = null;
        defer if (saved) |s| self.allocator.free(s);

        while (true) {
            const byte = self.readByte() catch |err| switch (err) {
                error.EndOfStream => return if (self.buffer.items.len > 0) try self.allocator.dupe(u8, self.buffer.items) else null,
                else => return err,
            };
            switch (byte) {
                '\n', '\r' => {
                    try self.write("\n");
                    const line = try self.allocator.dupe(u8, self.buffer.items);
                    try self.addHistory(line);
                    return line;
                },
                4 => if (self.buffer.items.len == 0) return null, // Ctrl+D on an empty line
                127, 8 => if (cursor > 0) { // Backspace
                    _ = self.buffer.orderedRemove(cursor - 1);
                    cursor -= 1;
                    try self.write("\x08");
                    try self.redrawFrom(cursor);
                },
                1 => if (cursor > 0) { // Ctrl+A
                    try self.print("\x1b[{d}D", .{cursor});
                    cursor = 0;
                },
                5 => if (cursor < self.buffer.items.len) { // Ctrl+E
                    try self.print("\x1b[{d}C", .{self.buffer.items.len - cursor});
                    cursor = self.buffer.items.len;
                },
                21 => try self.replaceLine("", &cursor), // Ctrl+U
                11 => if (cursor < self.buffer.items.len) { // Ctrl+K
                    self.buffer.shrinkRetainingCapacity(cursor);
                    try self.write("\x1b[K");
                },
                '\t' => try self.completeAt(prompt, &cursor),
                27 => try self.escape(&cursor, &history_index, &saved),
                else => if (byte >= 32 and byte != 127) {
                    try self.buffer.insert(self.allocator, cursor, byte);
                    try self.write(&.{byte});
                    cursor += 1;
                    if (cursor < self.buffer.items.len) try self.redrawFrom(cursor);
                },
            }
        }
    }

    /// Tab: one completion is filled in; several are listed.
    fn completeAt(self: *LineEditor, prompt: []const u8, cursor: *usize) !void {
        if (cursor.* != self.buffer.items.len) return;
        var completions = try self.console.complete(self.allocator, self.buffer.items);
        defer completions.deinit(self.allocator);
        if (completions.names.len == 1) {
            const suffix = completions.names[0][completions.prefix_len..];
            try self.buffer.appendSlice(self.allocator, suffix);
            try self.write(suffix);
            cursor.* = self.buffer.items.len;
        } else if (completions.names.len > 1) {
            try self.write("\n");
            for (completions.names) |name| {
                try self.write(name);
                try self.write("  ");
            }
            try self.write("\n");
            try self.write(prompt);
            try self.write(self.buffer.items);
            cursor.* = self.buffer.items.len;
        }
    }

    /// An escape sequence: the arrows, Home, End, Delete.
    fn escape(self: *LineEditor, cursor: *usize, history_index: *usize, saved: *?[]u8) !void {
        if ((self.readByte() catch return) != '[') return;
        switch (self.readByte() catch return) {
            'A' => if (history_index.* > 0) { // Up: the history's previous line
                if (history_index.* == self.history.items.len) {
                    if (saved.*) |s| self.allocator.free(s);
                    saved.* = try self.allocator.dupe(u8, self.buffer.items);
                }
                history_index.* -= 1;
                try self.replaceLine(self.history.items[history_index.*], cursor);
            },
            'B' => if (history_index.* < self.history.items.len) { // Down
                history_index.* += 1;
                const line = if (history_index.* == self.history.items.len) saved.* orelse "" else self.history.items[history_index.*];
                try self.replaceLine(line, cursor);
            },
            'C' => if (cursor.* < self.buffer.items.len) { // Right
                cursor.* += 1;
                try self.write("\x1b[C");
            },
            'D' => if (cursor.* > 0) { // Left
                cursor.* -= 1;
                try self.write("\x1b[D");
            },
            'H' => if (cursor.* > 0) { // Home
                try self.print("\x1b[{d}D", .{cursor.*});
                cursor.* = 0;
            },
            'F' => if (cursor.* < self.buffer.items.len) { // End
                try self.print("\x1b[{d}C", .{self.buffer.items.len - cursor.*});
                cursor.* = self.buffer.items.len;
            },
            '3' => if ((self.readByte() catch return) == '~' and cursor.* < self.buffer.items.len) { // Delete
                _ = self.buffer.orderedRemove(cursor.*);
                try self.redrawFrom(cursor.*);
            },
            else => {},
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const browser = try Browser.init(allocator, .{});
    defer browser.deinit();
    try browser.navigate("about:blank", .window);

    var out_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &out_buffer);
    var console = Console.init(allocator, browser, &stdout.interface);
    defer console.deinit();
    try console.banner();

    var editor = LineEditor.init(allocator, io, &console);
    defer editor.deinit();
    var prompt: Console.Prompt = .ready;
    while (try editor.readLine(if (prompt == .ready) "> " else "... ")) |line| {
        defer allocator.free(line);
        prompt = try console.feedLine(line);
    }
    try editor.write("\n");
}

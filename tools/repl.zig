//! The browser console: a headless browser - a Browser showing a page - and
//! the console that evaluates in it, what Chrome DevTools' console is to a
//! tab. Crane draws nothing (rendering and layout are its one exclusion), so
//! the console is how a person drives the page.
//!
//! Run it:
//!
//!     zig build repl-exe -j2 -Doptimize=ReleaseSafe --cache-dir ~/Library/Caches/crane-z16-cache
//!     ./zig-out/bin/repl [<url>] [--user-agent=<s>] [--proxy=system|direct|<url>]
//!                        [--accept-insecure-certs] [--ca-bundle=<pem>]
//!                        [--timeout=<ms>] [--wait-for-navigation]
//!
//! (`zig build repl-exe` builds this binary and its snapshot, nothing else;
//! `zig build repl -- <args>` builds it and runs it.) The first tab opens
//! `<url>` (about:blank by default) and the first prompt waits for its load
//! event - the active document's readiness "complete", which HTML's "the end"
//! sets in the task that fires load - at most `--timeout` ms (30,000). Type
//! JavaScript; Enter evaluates once the input is complete, Tab completes a
//! name, the arrows walk the history, Ctrl+C stops waiting (or stops a
//! script that runs too long) and at a prompt clears the line - twice at an
//! empty prompt it exits, as Node's REPL does - Ctrl+D exits. `.help` lists
//! the commands. Built ReleaseSafe by default (`-Drepl-optimize=Debug` for a
//! diagnosis), with libc malloc (`--check-leaks` for a leak-checking one).
//!
//! How it is built:
//!
//! - THE PAGE IS LIVE. The shape is Deno's REPL (the line editor on a thread
//!   of its own, each finished line sent to the runtime's event loop), not
//!   Node's (readline on the event loop): the main thread runs the Browser's
//!   event loop for the console's whole life (Browser.spinEventLoopUntil) -
//!   timers fire, fetches complete, workers post, navigations proceed - and
//!   the terminal's thread (`Terminal`) posts each line to the loop's
//!   cross-thread inbox (its TaskSink), where it runs as a task. The editor
//!   waits on the terminal and on a pipe the console writes to when it is
//!   ready for the next line (poll(2)), so there is no sleep-poll anywhere.
//! - REPL MODE (engine.evaluateReplScript, [repl_mode]): input is evaluated
//!   as Chrome's console evaluates it - top-level `await`, and a `let`,
//!   `const` or `class` declared again replacing the earlier one. Input that
//!   ends too soon asks for another line (`...`), as Node's and Chrome's
//!   consoles do: the engine says so, from its own parser. Its result is
//!   printed from its promise reaction, as it settles.
//! - THE PAGE'S OUTPUT: console.* of the page, its frames, its popups and
//!   its workers, and what no handler took - an uncaught exception, an
//!   unhandled rejection - is printed as it happens, above the prompt,
//!   through the Browser's developer console (Browser.attachDeveloperConsole),
//!   marked with where it came from (`[tab 2]`, `[frame <url>]`,
//!   `[worker <url>]`) whenever it is not the one tab's own document.
//! - NAVIGATION: the console evaluates in the selected tab's active document
//!   (Browser.traversableRealm), whichever navigation made it - a link, a
//!   form, `location.href = ..`, history.back() - and prints each navigation
//!   as it starts ("Navigating to <url>") and as its document commits
//!   ("Navigated to <url> (<status>)"), above the prompt. On a terminal the
//!   prompt comes back at once, as Chrome's console gives it back: a line
//!   typed before the commit reads the old page. With piped input - or
//!   `--wait-for-navigation` - an input that leaves the tab navigating holds
//!   the next line until that navigation has settled (its load event, at
//!   most `--timeout`), so a script's next line reads the new page. `.open`,
//!   `.reload`, `.back` and `.forward` are the browser's own UI
//!   (Browser.navigateTraversable, reloadTraversable, traverseHistoryByDelta:
//!   HTML "traverse the history by a delta"), never script put on the page,
//!   and always wait for the load.
//! - TABS: `.tabs` lists the Browser's top-level traversables - its own tab
//!   and every popup a page opened - and `.tab <n>` selects the one the
//!   console evaluates in.
//! - Nothing of the console is put on the page: no globals, no wrapper
//!   source around the input. Tab completion reads properties along a dotted
//!   name (getters run) and never evaluates the input.
//! - In memory: the Browser writes nothing to disk. `--profile=<dir>` is
//!   refused: no store persists yet (cookies, localStorage, IndexedDB, the
//!   Cache API and the HTTP cache are all in memory).
//!
//! On an engine without REPL mode (JavaScriptCore, QuickJS:
//! engine.capabilities.repl_mode is `.unsupported`) each input is evaluated
//! as a classic script of its own (engine.evaluateClassicScript): no
//! top-level await, a re-declaration is a SyntaxError, and every line is a
//! whole input. The console says so when it starts.

const std = @import("std");
const engine = @import("engine");
const browser_mod = @import("browser");
const Browser = browser_mod.Browser;
const BrowserConfig = browser_mod.BrowserConfig;
const printer = @import("console").printer;
const developer_console = Browser.developer_console;

/// No debug log lines in a Debug build of the console: the console's output
/// is what the user reads (tools/gc_bench.zig does the same).
/// No thread-local signal stack: Zig std's default (`signal_stack_size`,
/// 1 << 18) is a 256 KB thread-local array, which every thread that touches
/// any thread-local pays for - V8's worker threads included, which never use
/// it. The platform maps each thread's alternate stack instead
/// (platform.attachSignalStack, src/platform/kit/posix/signal_stack.zig);
/// build.zig's thread-local block check (tools/thread_local_size.zig) holds it.
pub const std_options: std.Options = .{ .log_level = .warn, .signal_stack_size = null };

// ============================================================================
// The command line
// ============================================================================

/// What the command line asks for.
pub const Options = struct {
    /// The first tab's URL.
    url: []const u8 = "about:blank",
    /// The Browser's user agent string (BrowserConfig.user_agent).
    user_agent: ?[]const u8 = null,
    /// Where requests go (BrowserConfig.proxy): system (the environment's
    /// http_proxy, https_proxy, no_proxy), direct, or one proxy for every
    /// scheme.
    proxy: BrowserConfig.Proxy = .system,
    /// TLS certificates are not verified (WebDriver's acceptInsecureCerts).
    accept_insecure_certs: bool = false,
    /// A PEM bundle of certificate authorities trusted besides the system's
    /// (BrowserConfig.ca_bundle_path): WPT's tools/certs/cacert.pem.
    ca_bundle: ?[]const u8 = null,
    /// How long a load or an evaluation is waited for, in ms.
    timeout_ms: u64 = Console.default_deadline_ms,
    /// On a terminal too, an input that leaves the tab navigating holds the
    /// next prompt until the navigation settles (piped input always does).
    wait_for_navigation: bool = false,
    /// `--profile=<dir>`, which the console refuses (`profile_refusal`).
    profile: ?[]const u8 = null,
    /// `--check-leaks`: a leak-checking allocator (std's DebugAllocator,
    /// no per-allocation stack traces unless CRANE_LEAK_TRACES=1) instead of
    /// libc malloc; what leaked is reported when the console exits.
    check_leaks: bool = false,
    /// `--help`.
    help: bool = false,
};

pub const usage =
    \\usage: repl [<url>] [--user-agent=<s>] [--proxy=system|direct|<url>]
    \\            [--accept-insecure-certs] [--ca-bundle=<pem>] [--timeout=<ms>]
    \\            [--wait-for-navigation]
    \\
    \\  <url>                    the first tab's page (default about:blank); the
    \\                           first prompt waits for its load event
    \\  --user-agent=<s>         the User-Agent header and navigator.userAgent
    \\  --proxy=system           the environment's http_proxy/https_proxy/no_proxy (default)
    \\  --proxy=direct           no proxy
    \\  --proxy=<url>            every request through this proxy
    \\  --accept-insecure-certs  do not verify TLS certificates
    \\  --ca-bundle=<pem>        trust these certificate authorities too
    \\  --timeout=<ms>           how long a load or an evaluation is waited for (30000)
    \\  --wait-for-navigation    hold the next prompt while an input's navigation loads
    \\                           (always, when input is piped)
    \\  --check-leaks            a leak-checking allocator; leaks reported at exit
    \\                           (CRANE_LEAK_TRACES=1 adds each one's stack trace)
    \\
;

/// Why `--profile` is refused.
pub const profile_refusal = "profiles are not supported yet: Crane's stores (cookies, localStorage, IndexedDB, the Cache API, the HTTP cache) are in memory only, so a profile directory would keep nothing";

pub const OptionsError = error{ UnknownOption, MissingValue, InvalidTimeout, TooManyArguments };

/// The options `args` (without the program name) ask for. Every slice is
/// borrowed from `args`. `bad` is set to the argument a failure is about.
pub fn parseOptions(args: []const []const u8, bad: *[]const u8) OptionsError!Options {
    var options: Options = .{};
    var url_seen = false;
    for (args) |arg| {
        bad.* = arg;
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.help = true;
        } else if (std.mem.eql(u8, arg, "--accept-insecure-certs")) {
            options.accept_insecure_certs = true;
        } else if (std.mem.eql(u8, arg, "--wait-for-navigation")) {
            options.wait_for_navigation = true;
        } else if (std.mem.eql(u8, arg, "--check-leaks")) {
            options.check_leaks = true;
        } else if (valueOf(arg, "--user-agent")) |value| {
            options.user_agent = value;
        } else if (valueOf(arg, "--proxy")) |value| {
            if (value.len == 0) return error.MissingValue;
            options.proxy = if (std.mem.eql(u8, value, "system"))
                .system
            else if (std.mem.eql(u8, value, "direct"))
                .direct
            else
                .{ .manual = .{ .http = value, .https = value } };
        } else if (valueOf(arg, "--ca-bundle")) |value| {
            if (value.len == 0) return error.MissingValue;
            options.ca_bundle = value;
        } else if (valueOf(arg, "--timeout")) |value| {
            options.timeout_ms = std.fmt.parseUnsigned(u64, value, 10) catch return error.InvalidTimeout;
        } else if (valueOf(arg, "--profile")) |value| {
            if (value.len == 0) return error.MissingValue;
            options.profile = value;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            return error.UnknownOption;
        } else {
            if (url_seen) return error.TooManyArguments;
            url_seen = true;
            options.url = arg;
        }
    }
    return options;
}

/// `arg`'s value when it is `<name>=<value>`.
fn valueOf(arg: []const u8, name: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, arg, name)) return null;
    if (arg.len == name.len or arg[name.len] != '=') return null;
    return arg[name.len + 1 ..];
}

// ============================================================================
// The console
// ============================================================================

/// The console core: lines of input in, evaluation and printing out. The
/// terminal (`Terminal`, `main`) is a thin shell around it; a test feeds it
/// lines (`feedLine`) and reads what it printed.
///
/// Every method but `interrupt` and `emit` runs on the Browser's window
/// thread - from a task of its loop, or between its turns.
pub const Console = struct {
    allocator: std.mem.Allocator,
    browser: *Browser,
    /// Where everything is printed, flushed after each write. Guarded by
    /// `out_mutex`: the page's workers print from their own threads.
    out: *std.Io.Writer,
    out_mutex: std.Io.Mutex = .init,
    /// The terminal showing a prompt, cleared and drawn again around every
    /// write (`emit`). Null: nothing to redraw (a test).
    display: ?Display = null,
    /// How long an evaluation is waited for, in milliseconds of real time.
    deadline_ms: u64 = default_deadline_ms,
    /// How long a load is waited for.
    load_timeout_ms: u64 = default_deadline_ms,
    /// An input that leaves the selected tab navigating holds the next line
    /// until that navigation settles: for piped or scripted input (and a test).
    /// A terminal gives the prompt back at once (`main`), as Chrome does.
    wait_for_navigation: bool = true,
    /// The lines of an input that is not complete yet.
    input: std.ArrayListUnmanaged(u8) = .empty,
    /// The top-level traversable the console evaluates in (Browser
    /// traversable id); the Browser's own tab until `.tab` selects another.
    selected: ?u64 = null,
    /// What the console waits for before it takes the next line.
    waiting: Waiting = .none,
    /// The prompt the next line answers, once nothing is waited for.
    prompt: Prompt = .ready,
    /// Told when the console is ready for the next line, and when it ends.
    on_ready: ?ReadyHook = null,
    /// `.exit`, or the end of input.
    exit_requested: bool = false,
    /// The document each top-level traversable showed when last looked at,
    /// for "Navigated to".
    seen: std.ArrayListUnmanaged(Seen) = .empty,
    /// Guards `in_script` and `abort_requested`, between the window thread and
    /// the terminal's (`interrupt`).
    script_mutex: std.Io.Mutex = .init,
    /// The console's input is running as script right now (inside
    /// evaluateReplScript), so an interrupt aborts it.
    in_script: bool = false,
    /// An interrupt aborted the input's script: the agent runs script again
    /// once it has unwound (engine.resumeScripts).
    abort_requested: bool = false,
    /// The console is the Browser's developer console (`attach`).
    attached: bool = false,

    pub const default_deadline_ms: u64 = 30_000;

    /// Which prompt the next line answers.
    pub const Prompt = enum {
        /// A new input.
        ready,
        /// More of the input so far, which ended too soon.
        more,
    };

    /// What the terminal is told by `on_ready`.
    pub const Ready = enum { ready, more, exit };

    pub const ReadyHook = struct {
        context: *anyopaque,
        ready: *const fn (context: *anyopaque, what: Ready) void,
    };

    /// A terminal that shows a prompt under the console's output.
    pub const Display = struct {
        context: *anyopaque,
        /// Clear the prompt line (`out_mutex` held).
        clear: *const fn (context: *anyopaque) void,
        /// Draw the prompt and the line being edited again (`out_mutex` held).
        redraw: *const fn (context: *anyopaque) void,
    };

    const Waiting = union(enum) {
        none,
        /// An evaluation, until it settles or `deadline_ns`.
        evaluation: struct { evaluation: *Evaluation, deadline_ns: u64 },
        /// A navigation, reload or traversal of tab `tab`, until its
        /// document has loaded and nothing more of it is under way.
        navigation: NavigationWait,
    };

    const NavigationWait = struct {
        tab: u64,
        /// The document shown when the wait began.
        from: Seen,
        /// Its URL then, OWNED: a navigation to a fragment of it changes the
        /// URL alone, at once.
        from_url: ?[]u8,
        /// A navigation of the tab was seen under way.
        saw_navigating: bool,
        deadline_ns: u64,
        /// The wait follows an input that may have started a navigation -
        /// or queued one: a form's submission "plans to navigate" in a task
        /// - rather than a command that did: with nothing under way after a
        /// turn of the loop, there is nothing to wait for.
        after_input: bool = false,
        /// Turns of the loop seen since the wait began.
        polls: u32 = 0,
    };

    /// A document a traversable showed: an identity, compared, never read.
    const Seen = struct {
        tab: u64,
        document: ?*anyopaque,
        generation: u64,
        /// "Navigating to" was printed for the navigation under way.
        announced: bool = false,

        fn sameDocument(self: Seen, other: Seen) bool {
            return self.document == other.document and self.generation == other.generation;
        }
    };

    /// A console on `browser`'s own tab, printing to `out`: the documents its
    /// tabs show now are not navigations.
    pub fn init(allocator: std.mem.Allocator, browser: *Browser, out: *std.Io.Writer) Console {
        var self: Console = .{ .allocator = allocator, .browser = browser, .out = out, .selected = browser.hostTraversableId() };
        self.noteDocuments(false);
        return self;
    }

    pub fn deinit(self: *Console) void {
        self.detach();
        switch (self.waiting) {
            .evaluation => |wait| wait.evaluation.abandon(),
            .navigation => self.endNavigationWait(),
            .none => {},
        }
        self.waiting = .none;
        self.input.deinit(self.allocator);
        self.seen.deinit(self.allocator);
    }

    /// The console shows the Browser's developer console from now on: the
    /// page's own console output and its uncaught errors print here, as they
    /// happen.
    pub fn attach(self: *Console) !void {
        try self.browser.attachDeveloperConsole(.{ .context = self, .report = reportMessage });
        self.attached = true;
    }

    /// Stop showing the developer console (deinit does): once this returns,
    /// no message reaches the console, a worker's under way included.
    pub fn detach(self: *Console) void {
        if (!self.attached) return;
        self.browser.detachDeveloperConsole();
        self.attached = false;
    }

    /// What the console says when it starts.
    pub fn banner(self: *Console) void {
        self.print("Crane browser console ({s}). .help lists the commands; Tab completes, Ctrl+D exits.\n", .{engine.name});
        if (comptime engine.capabilities.repl_mode == .unsupported) {
            self.print("{s} has no REPL mode: each input is a classic script of its own - no top-level await, no re-declaration.\n", .{engine.name});
        }
    }

    // ------------------------------------------------------------------------
    // Printing
    // ------------------------------------------------------------------------

    /// Write `text` - whole lines - to the console's output, above the
    /// prompt a terminal shows. Any thread; never runs script.
    pub fn emit(self: *Console, text: []const u8) void {
        std.Io.Threaded.mutexLockUncancelable(&self.out_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.out_mutex);
        if (self.display) |display| display.clear(display.context);
        self.out.writeAll(text) catch {};
        self.out.flush() catch {};
        if (self.display) |display| display.redraw(display.context);
    }

    fn print(self: *Console, comptime format: []const u8, args: anytype) void {
        const text = std.fmt.allocPrint(self.allocator, format, args) catch return;
        defer self.allocator.free(text);
        self.emit(text);
    }

    /// The developer console's host (Browser.attachDeveloperConsole): a
    /// message of the page, a frame, a popup or a worker, on its realm's
    /// thread, with the developer console's lock held. Runs no script: the
    /// text was formatted by whoever reported it.
    fn reportMessage(context: *anyopaque, message: *const developer_console.Message) void {
        const self: *Console = @ptrCast(@alignCast(context));
        var text: std.Io.Writer.Allocating = .init(self.allocator);
        defer text.deinit();
        self.writeLabel(&text.writer, message.realm) catch return;
        text.writer.writeAll(message.text) catch return;
        text.writer.writeByte('\n') catch return;
        // An exception's source, as DevTools shows it beside the message.
        if (message.kind != .console and message.location.url.len > 0) {
            text.writer.print("    at {s}:{d}:{d}\n", .{ message.location.url, message.location.line, message.location.column }) catch return;
        }
        self.emit(text.written());
    }

    /// Where a message of `realm` came from, when that is not the selected
    /// tab's own document while it is the only tab: `[tab 2] `,
    /// `[frame <url>] `, `[tab 2 frame <url>] `, `[worker <url>] `. On the
    /// realm's thread.
    fn writeLabel(self: *Console, out: *std.Io.Writer, source_realm: engine.Context) !void {
        if (source_realm.isWindow()) {
            // A Window's realm runs on the Browser's window thread: its
            // traversables may be read there.
            const source = self.browser.realmSource(source_realm) orelse return;
            const several = self.browser.traversableCount() > 1;
            const other_tab = self.selected != null and source.traversable != self.selected.?;
            if (!source.frame and !several and !other_tab) return;
            try out.writeByte('[');
            if (several or other_tab) {
                const index = self.browser.traversableIndex(source.traversable) orelse 0;
                try out.print("tab {d}", .{index + 1});
                if (source.frame) try out.writeByte(' ');
            }
            if (source.frame) try out.print("frame {s}", .{source_realm.documentUrl() orelse ""});
            try out.writeAll("] ");
            return;
        }
        // A worker's (or a worklet's) realm, on its own thread: its own URL.
        const kind = if (source_realm.isWorker()) "worker" else "worklet";
        try out.print("[{s} {s}] ", .{ kind, source_realm.documentUrl() orelse "" });
    }

    // ------------------------------------------------------------------------
    // Input
    // ------------------------------------------------------------------------

    /// Whether the console is ready for the next line: nothing is waited for.
    pub fn isReady(self: *const Console) bool {
        return self.waiting == .none;
    }

    /// One line of input, as a test or a pipe gives it: taken (`submitLine`),
    /// then the event loop runs until the console is ready for the next.
    /// The prompt the next line answers.
    pub fn feedLine(self: *Console, line: []const u8) !Prompt {
        self.submitLine(line);
        try self.runUntilReady();
        return self.prompt;
    }

    /// Run the Browser's event loop until the console is ready for the next
    /// line (or wants to exit) - what `feedLine` and the start-up load wait
    /// for. Not from inside a turn of the loop.
    pub fn runUntilReady(self: *Console) !void {
        _ = try self.browser.spinEventLoopUntil(.{ .context = self, .met = readyGoal }, std.math.maxInt(u64));
    }

    /// The goal of `runUntilReady`, asked between turns: the console looks at
    /// what it waits for first (`poll`).
    fn readyGoal(context: *anyopaque) bool {
        const self: *Console = @ptrCast(@alignCast(context));
        self.poll();
        return self.isReady() or self.exit_requested;
    }

    /// The goal of the console's whole life (`main`): it exits.
    pub fn exitGoal(context: *anyopaque) bool {
        const self: *Console = @ptrCast(@alignCast(context));
        self.poll();
        return self.exit_requested and self.isReady();
    }

    /// One line of input: a command (`.open`, `.tabs`, ...) or JavaScript.
    /// JavaScript is evaluated once the input is complete; input that ends
    /// too soon waits for more. Its outcome prints as it comes, and the
    /// console is ready again after it (`on_ready`).
    pub fn submitLine(self: *Console, line: []const u8) void {
        if (self.input.items.len == 0) {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (isCommand(trimmed)) return self.command(trimmed);
        }
        if (self.input.items.len > 0) self.input.append(self.allocator, '\n') catch {};
        self.input.appendSlice(self.allocator, line) catch {
            self.emit("(out of memory)\n");
            self.input.clearRetainingCapacity();
            return self.becomeReady(.ready);
        };
        if (std.mem.trim(u8, self.input.items, &std.ascii.whitespace).len == 0) {
            self.input.clearRetainingCapacity();
            return self.becomeReady(.ready);
        }
        self.evaluate();
    }

    /// The input ended (Ctrl+D, or the end of piped input): the console
    /// exits once it is ready.
    pub fn requestExit(self: *Console) void {
        self.exit_requested = true;
        if (self.isReady()) self.tell(.exit);
    }

    /// Ctrl+C, from the terminal's thread: stop what the console waits for.
    /// The input's script, if it is running right now, is aborted (HTML
    /// "abort a running script", engine.abortRunningScript, which may be
    /// called from any thread); then, on the window thread, an evaluation or
    /// a load still waited for is abandoned (`interrupted`).
    pub fn interrupt(self: *Console) void {
        std.Io.Threaded.mutexLockUncancelable(&self.script_mutex);
        if (self.in_script) {
            if (comptime engine.capabilities.script_abort != .unsupported) {
                if (self.browser.getAgent()) |agent| engine.abortRunningScript(agent);
            }
            self.abort_requested = true;
        }
        std.Io.Threaded.mutexUnlock(&self.script_mutex);
    }

    /// Where Ctrl+C was pressed: at a prompt, or while the console was busy.
    pub const InterruptAt = enum { prompt, busy };

    /// The window thread's half of an interrupt: stop waiting. At a prompt -
    /// as in Node's console - the unfinished input goes and a new one begins;
    /// one pressed while busy that finds the console ready (what it waited
    /// for ended meanwhile) does nothing.
    pub fn interrupted(self: *Console, at: InterruptAt) void {
        switch (self.waiting) {
            .none => if (at == .prompt) {
                self.input.clearRetainingCapacity();
                self.becomeReady(.ready);
            },
            .evaluation => |wait| {
                wait.evaluation.abandon();
                self.waiting = .none;
                self.input.clearRetainingCapacity();
                self.emit("(interrupted: the console stopped waiting)\n");
                self.becomeReady(.ready);
            },
            .navigation => {
                self.endNavigationWait();
                self.emit("(interrupted: the console stopped waiting for the page)\n");
                self.becomeReady(.ready);
            },
        }
    }

    /// The console takes its first line: the terminal shows the first prompt.
    pub fn begin(self: *Console) void {
        self.becomeReady(.ready);
    }

    fn becomeReady(self: *Console, prompt: Prompt) void {
        self.prompt = prompt;
        if (self.exit_requested) return self.tell(.exit);
        self.tell(if (prompt == .ready) .ready else .more);
    }

    fn tell(self: *Console, what: Ready) void {
        if (self.on_ready) |hook| hook.ready(hook.context, what);
    }

    /// Look at what the console waits for, between turns of the loop: a load
    /// finished, a deadline passed. Prints every navigation of a tab
    /// ("Navigating to", "Navigated to"). Runs no script.
    pub fn poll(self: *Console) void {
        self.noteDocuments(true);
        switch (self.waiting) {
            .none => {},
            .evaluation => |wait| if (nowNs() >= wait.deadline_ns) {
                wait.evaluation.abandon();
                self.waiting = .none;
                self.input.clearRetainingCapacity();
                self.print("Promise {{<pending>}} (still pending after {d} ms: the console stopped waiting)\n", .{self.deadline_ms});
                self.becomeReady(.ready);
            },
            .navigation => |*wait| self.pollNavigation(wait),
        }
    }

    fn pollNavigation(self: *Console, wait: *NavigationWait) void {
        const state = self.browser.traversableState(wait.tab) orelse {
            self.endNavigationWait();
            self.emit("(the tab closed)\n");
            return self.becomeReady(.ready);
        };
        if (state.navigating) wait.saw_navigating = true;
        wait.polls += 1;
        const now_seen: Seen = .{ .tab = wait.tab, .document = state.document, .generation = state.document_generation };
        const changed = !now_seen.sameDocument(wait.from);
        const settled = settled: {
            if (state.navigating) break :settled false;
            // A new document, or a navigation seen: once it has loaded.
            if (changed or wait.saw_navigating) break :settled state.loaded;
            // Two looks: the input's own task may end a turn, and what it
            // queued runs in the next.
            if (wait.after_input) break :settled wait.polls >= 2;
            // A command's navigation to a fragment: the URL alone changed.
            const before = wait.from_url orelse break :settled false;
            const url = self.browser.traversableUrl(self.allocator, wait.tab) catch break :settled false;
            defer self.allocator.free(url);
            break :settled !std.mem.eql(u8, url, before);
        };
        if (settled) {
            const after_input = wait.after_input;
            const tab = wait.tab;
            self.endNavigationWait();
            // A command's traversal or navigation that kept the document (a
            // same-document entry, a fragment): its URL, since no
            // "Navigated to" says it.
            if (!changed and !after_input) {
                const url = self.browser.traversableUrl(self.allocator, tab) catch null;
                defer if (url) |u| self.allocator.free(u);
                self.print("{s} (same document)\n", .{url orelse "?"});
            }
            return self.becomeReady(.ready);
        }
        if (nowNs() >= wait.deadline_ns) {
            self.endNavigationWait();
            self.print("(the page has not finished loading after {d} ms: the console stopped waiting)\n", .{self.load_timeout_ms});
            return self.becomeReady(.ready);
        }
    }

    /// For every tab: "Navigating to <url>" once a navigation of it is
    /// under way, and "Navigated to <url> (<status>)" once its document is
    /// not the one it showed when last looked at - printed when
    /// `print_changes`, and remembered. The initial about:blank document of
    /// a new tab is not a navigation. Allocates only to print.
    fn noteDocuments(self: *Console, print_changes: bool) void {
        var ids_buffer: [64]u64 = undefined;
        const count = self.browser.traversableIds(&ids_buffer);
        const ids = ids_buffer[0..@min(count, ids_buffer.len)];
        // Forget the tabs that closed, and select the Browser's own tab when
        // the selected one did.
        var i: usize = 0;
        while (i < self.seen.items.len) {
            if (std.mem.indexOfScalar(u64, ids, self.seen.items[i].tab) == null) {
                const closed = self.seen.swapRemove(i).tab;
                if (self.selected != null and self.selected.? == closed) {
                    self.selected = self.browser.hostTraversableId();
                    if (print_changes) self.emit("(the selected tab closed: the console evaluates in tab 1)\n");
                }
                continue;
            }
            i += 1;
        }
        for (ids) |id| {
            const state = self.browser.traversableState(id) orelse continue;
            const current: Seen = .{ .tab = id, .document = state.document, .generation = state.document_generation };
            const entry = self.seenEntry(id) orelse blk: {
                // A tab seen for the first time: a popup a page opened (its
                // document, unless it is still its initial about:blank one,
                // is printed below), or the console's first look.
                self.seen.append(self.allocator, .{ .tab = id, .document = null, .generation = 0 }) catch continue;
                const added = &self.seen.items[self.seen.items.len - 1];
                if (!print_changes) added.* = current;
                break :blk added;
            };
            if (state.navigating) {
                if (!entry.announced) if (state.navigating_to) |url| {
                    entry.announced = true;
                    if (print_changes) self.printNavigating(id, url);
                };
            } else entry.announced = false;
            if (entry.sameDocument(current)) continue;
            entry.document = current.document;
            entry.generation = current.generation;
            if (!print_changes or state.document == null or state.initial_about_blank) continue;
            self.printNavigated(id);
        }
    }

    fn seenEntry(self: *Console, id: u64) ?*Seen {
        for (self.seen.items) |*entry| if (entry.tab == id) return entry;
        return null;
    }

    fn printNavigating(self: *Console, id: u64, url: []const u8) void {
        var label_buffer: [32]u8 = undefined;
        self.print("{s}Navigating to {s}\n", .{ self.tabLabel(id, &label_buffer), url });
    }

    fn printNavigated(self: *Console, id: u64) void {
        const url = self.browser.traversableUrl(self.allocator, id) catch return;
        defer self.allocator.free(url);
        const status = self.browser.traversableStatus(id);
        var label_buffer: [32]u8 = undefined;
        const label = self.tabLabel(id, &label_buffer);
        if (status == 0) {
            self.print("{s}Navigated to {s}\n", .{ label, url });
        } else {
            self.print("{s}Navigated to {s} ({d})\n", .{ label, url, status });
        }
    }

    /// `[tab N] ` when the Browser has several tabs, else "".
    fn tabLabel(self: *Console, id: u64, buffer: []u8) []const u8 {
        if (self.browser.traversableCount() <= 1) return "";
        const index = self.browser.traversableIndex(id) orelse return "";
        return std.fmt.bufPrint(buffer, "[tab {d}] ", .{index + 1}) catch "";
    }

    // ------------------------------------------------------------------------
    // Navigation
    // ------------------------------------------------------------------------

    /// Navigate the selected tab to `url`, as an address bar does, and wait
    /// for its load (`load_timeout_ms`): what `.open` and the console's start
    /// do.
    pub fn open(self: *Console, url: []const u8) void {
        const tab = self.selected orelse return self.noTab();
        const wait = self.navigationWait(tab);
        self.browser.navigateTraversable(tab, url) catch |err| {
            if (wait.from_url) |u| self.allocator.free(u);
            self.print("(could not open {s}: {s})\n", .{ url, describe(err) });
            return self.becomeReady(.ready);
        };
        self.waiting = .{ .navigation = wait };
    }

    fn currentSeen(self: *Console, tab: u64) Seen {
        const state = self.browser.traversableState(tab) orelse return .{ .tab = tab, .document = null, .generation = 0 };
        return .{ .tab = tab, .document = state.document, .generation = state.document_generation };
    }

    /// A wait for a navigation of `tab` about to start: what it shows now.
    /// Its `from_url` is OWNED.
    fn navigationWait(self: *Console, tab: u64) NavigationWait {
        return .{
            .tab = tab,
            .from = self.currentSeen(tab),
            .from_url = self.browser.traversableUrl(self.allocator, tab) catch null,
            .saw_navigating = false,
            .deadline_ns = nowNs() +| self.load_timeout_ms *| std.time.ns_per_ms,
        };
    }

    /// The console waits for no navigation from now on.
    fn endNavigationWait(self: *Console) void {
        switch (self.waiting) {
            .navigation => |wait| if (wait.from_url) |url| self.allocator.free(url),
            else => return,
        }
        self.waiting = .none;
    }

    fn noTab(self: *Console) void {
        self.emit("(no tab to act on)\n");
        self.becomeReady(.ready);
    }

    // ------------------------------------------------------------------------
    // Commands
    // ------------------------------------------------------------------------

    /// A console command: a line that starts with a dot and a letter, as
    /// Node's REPL keywords do (`.5` is a number).
    fn isCommand(line: []const u8) bool {
        return line.len >= 2 and line[0] == '.' and std.ascii.isAlphabetic(line[1]);
    }

    pub const help =
        \\.open <url>      navigate the tab to <url>, as its address bar does, and wait for its load
        \\.reload          reload the tab
        \\.back            go back one entry in the tab's session history
        \\.forward         go forward one entry
        \\.url             the tab's URL
        \\.tabs            the Browser's tabs: its own and every popup a page opened
        \\.tab <n>         evaluate in tab <n> from now on
        \\.newtab [<url>]  open a new tab (not supported yet)
        \\.close [<n>]     close tab <n> (a popup), or the selected one
        \\.help            this list
        \\.exit            end the console (Ctrl+D, or Ctrl+C twice at an empty prompt)
        \\
        \\Ctrl+C stops what the console waits for (an evaluation, a page's load) or a script
        \\that runs too long; at a prompt it clears the line.
        \\
    ;

    fn command(self: *Console, line: []const u8) void {
        var words = std.mem.tokenizeAny(u8, line, " \t");
        const name = words.next() orelse return self.becomeReady(.ready);
        const argument = std.mem.trim(u8, words.rest(), " \t");
        if (std.mem.eql(u8, name, ".help")) {
            self.emit(help);
        } else if (std.mem.eql(u8, name, ".exit")) {
            self.exit_requested = true;
        } else if (std.mem.eql(u8, name, ".url")) {
            const tab = self.selected orelse return self.noTab();
            const url = self.browser.traversableUrl(self.allocator, tab) catch return self.noTab();
            defer self.allocator.free(url);
            self.print("{s}\n", .{url});
        } else if (std.mem.eql(u8, name, ".open")) {
            if (argument.len == 0) {
                self.emit("usage: .open <url>\n");
            } else return self.open(argument);
        } else if (std.mem.eql(u8, name, ".reload")) {
            const tab = self.selected orelse return self.noTab();
            var wait = self.navigationWait(tab);
            self.browser.reloadTraversable(tab) catch |err| {
                if (wait.from_url) |u| self.allocator.free(u);
                self.print("(could not reload: {s})\n", .{describe(err)});
                return self.becomeReady(.ready);
            };
            // A reload keeps the URL: it is the new document that ends it.
            if (wait.from_url) |u| self.allocator.free(u);
            wait.from_url = null;
            self.waiting = .{ .navigation = wait };
            return;
        } else if (std.mem.eql(u8, name, ".back") or std.mem.eql(u8, name, ".forward")) {
            const tab = self.selected orelse return self.noTab();
            const back = std.mem.eql(u8, name, ".back");
            const wait = self.navigationWait(tab);
            if (self.browser.traverseHistoryByDelta(tab, if (back) -1 else 1)) |queued| {
                if (queued) {
                    self.waiting = .{ .navigation = wait };
                    return;
                }
                self.print("(no {s} entry in the tab's session history)\n", .{if (back) "previous" else "next"});
            } else |err| self.print("(could not go {s}: {s})\n", .{ if (back) "back" else "forward", describe(err) });
            if (wait.from_url) |u| self.allocator.free(u);
        } else if (std.mem.eql(u8, name, ".tabs")) {
            self.listTabs();
        } else if (std.mem.eql(u8, name, ".tab")) {
            self.selectTab(argument);
        } else if (std.mem.eql(u8, name, ".newtab")) {
            self.emit("(.newtab is not supported yet: a tab the host opens needs a Window realm that is not entered for its life - its own batch, HOST-OPENED TABS; window.open() from a page opens a popup, which .tabs lists)\n");
        } else if (std.mem.eql(u8, name, ".close")) {
            self.closeTab(argument);
        } else {
            self.print("Invalid console command: {s} (.help lists them)\n", .{name});
        }
        self.becomeReady(.ready);
    }

    fn listTabs(self: *Console) void {
        const list = self.browser.traversables(self.allocator) catch return self.emit("(out of memory)\n");
        defer Browser.freeTraversables(self.allocator, list);
        var text: std.Io.Writer.Allocating = .init(self.allocator);
        defer text.deinit();
        for (list, 0..) |info, index| {
            const mark: u8 = if (self.selected != null and self.selected.? == info.id) '*' else ' ';
            text.writer.print("{c} {d}  {s}", .{ mark, index + 1, info.url }) catch return;
            if (info.title.len > 0) text.writer.print("  \"{s}\"", .{info.title}) catch return;
            if (info.made_by == .page) {
                if (info.opener) |opener| {
                    const opener_index = indexIn(list, opener);
                    if (opener_index) |n| text.writer.print("  (popup of tab {d})", .{n + 1}) catch return else text.writer.writeAll("  (popup)") catch return;
                } else text.writer.writeAll("  (popup, no opener)") catch return;
            }
            text.writer.writeByte('\n') catch return;
        }
        self.emit(text.written());
    }

    fn indexIn(list: []const Browser.TraversableInfo, id: u64) ?usize {
        for (list, 0..) |info, index| if (info.id == id) return index;
        return null;
    }

    /// The traversable `.tabs` numbers `n` (from 1).
    fn tabNumbered(self: *Console, argument: []const u8) ?u64 {
        const n = std.fmt.parseUnsigned(usize, argument, 10) catch return null;
        const list = self.browser.traversables(self.allocator) catch return null;
        defer Browser.freeTraversables(self.allocator, list);
        if (n == 0 or n > list.len) return null;
        return list[n - 1].id;
    }

    fn selectTab(self: *Console, argument: []const u8) void {
        const id = self.tabNumbered(argument) orelse return self.print("(no tab {s}: .tabs lists them)\n", .{argument});
        self.selected = id;
        const url = self.browser.traversableUrl(self.allocator, id) catch return;
        defer self.allocator.free(url);
        self.print("(the console evaluates in tab {s}: {s})\n", .{ argument, url });
    }

    fn closeTab(self: *Console, argument: []const u8) void {
        const chosen: ?u64 = if (argument.len == 0) self.selected else self.tabNumbered(argument);
        const id = chosen orelse return self.print("(no tab {s}: .tabs lists them)\n", .{argument});
        self.browser.closeTraversable(id) catch |err| switch (err) {
            error.HostTraversable => return self.emit("(the Browser's own tab closes with the console: .exit)\n"),
            else => return self.print("(could not close the tab: {s})\n", .{describe(err)}),
        };
        self.noteDocuments(true);
    }

    fn describe(err: anyerror) []const u8 {
        return switch (err) {
            error.InvalidUrl => "not a URL",
            error.NoSuchTraversable => "the tab has closed",
            else => @errorName(err),
        };
    }

    // ------------------------------------------------------------------------
    // Evaluation
    // ------------------------------------------------------------------------

    /// The realm the console evaluates in: the selected tab's active window's.
    fn realm(self: *Console) ?engine.Context {
        const tab = self.selected orelse return null;
        return self.browser.traversableRealm(tab);
    }

    /// Evaluate the input in the page; its outcome prints when it settles.
    fn evaluate(self: *Console) void {
        const target = self.realm() orelse {
            self.input.clearRetainingCapacity();
            self.emit("(no page to evaluate in)\n");
            return self.becomeReady(.ready);
        };
        if (comptime engine.capabilities.repl_mode == .unsupported) {
            self.evaluateClassic(target, self.input.items);
            self.input.clearRetainingCapacity();
            return self.becomeReady(.ready);
        }
        const evaluation = Evaluation.create(self.allocator, target, self) catch {
            self.input.clearRetainingCapacity();
            self.emit("(out of memory)\n");
            return self.becomeReady(.ready);
        };
        // Waited for from now: a step that runs before evaluateReplScript
        // returns (a SyntaxError) ends the wait at once.
        self.waiting = .{ .evaluation = .{ .evaluation = evaluation, .deadline_ns = nowNs() +| self.deadline_ms *| std.time.ns_per_ms } };
        self.setInScript(true);
        const started = engine.evaluateReplScript(target, self.input.items, &Evaluation.steps, evaluation);
        self.setInScript(false);
        const outcome = started catch |err| {
            // No step runs for a failed call.
            if (self.waiting == .evaluation) self.waiting = .none;
            evaluation.destroy();
            self.input.clearRetainingCapacity();
            self.print("(the console could not evaluate: {s})\n", .{@errorName(err)});
            return self.becomeReady(.ready);
        };
        if (outcome == .incomplete) {
            self.waiting = .none;
            evaluation.destroy();
            return self.becomeReady(.more);
        }
        self.input.clearRetainingCapacity();
    }

    fn setInScript(self: *Console, running: bool) void {
        std.Io.Threaded.mutexLockUncancelable(&self.script_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.script_mutex);
        self.in_script = running;
        if (!running and self.abort_requested) {
            self.abort_requested = false;
            if (comptime engine.capabilities.script_abort != .unsupported) {
                if (self.browser.getAgent()) |agent| engine.resumeScripts(agent);
            }
        }
    }

    /// An evaluation ended (its outcome is printed): take the next line -
    /// unless the input left the tab navigating (`location.href = ..`, a
    /// link's click, a form's submit, history.back()) and the console waits
    /// for navigations (`wait_for_navigation`), when the next line waits for
    /// that navigation to settle.
    fn evaluationEnded(self: *Console, evaluation: *Evaluation) void {
        switch (self.waiting) {
            .evaluation => |wait| if (wait.evaluation == evaluation) {
                self.waiting = .none;
            } else return,
            else => return,
        }
        if (self.wait_for_navigation) if (self.selected) |tab| {
            if (self.browser.traversableState(tab)) |state| {
                var wait = self.navigationWait(tab);
                wait.saw_navigating = state.navigating;
                wait.after_input = true;
                self.waiting = .{ .navigation = wait };
                return;
            }
        };
        self.becomeReady(.ready);
    }

    /// The declared fallback without REPL mode: `source` as a classic script
    /// of its own, its completion value printed, or what it threw.
    fn evaluateClassic(self: *Console, target: engine.Context, source: []const u8) void {
        var thrown: Thrown = .{ .realm = target };
        defer thrown.deinit();
        var text: std.Io.Writer.Allocating = .init(self.allocator);
        defer text.deinit();
        if (engine.evaluateClassicScript(target, .{ .utf8 = source }, "", null, thrown.reporter())) |value| {
            defer value.release();
            printer.printResult(self.allocator, target, value.value, &text.writer) catch {};
        } else |err| {
            if (err == error.ExceptionReported) {
                if (thrown.value) |v| printer.printUncaught(self.allocator, target, v.value, &text.writer) catch {};
            } else text.writer.print("(the console could not evaluate: {s})\n", .{@errorName(err)}) catch {};
        }
        self.emit(text.written());
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

    // ------------------------------------------------------------------------
    // Tab completion
    // ------------------------------------------------------------------------

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

        const tab = self.selected orelse return nothing(allocator, prefix.len);
        const window = self.browser.traversableWindow(tab) orelse return nothing(allocator, prefix.len);
        const target = window.ctx;
        var object = engine.retainValue(target, .{ .instance = window }) catch return nothing(allocator, prefix.len);
        defer object.release();
        if (path.len > 0) {
            var segments = std.mem.splitScalar(u8, path, '.');
            while (segments.next()) |segment| {
                const next = get(target, object.value, segment) orelse return nothing(allocator, prefix.len);
                object.release();
                object = next;
                if (engine.typeOf(target, object.value) != .object) return nothing(allocator, prefix.len);
            }
        }

        var seen_names: std.StringHashMapUnmanaged(void) = .empty;
        defer seen_names.deinit(allocator);
        var link = try engine.retainValue(target, object.value);
        defer link.release();
        var levels: usize = 0;
        while (levels < 64 and engine.typeOf(target, link.value) == .object) : (levels += 1) {
            const keys = keysOf(target, link.value, allocator) orelse break;
            defer {
                for (keys) |k| allocator.free(k);
                allocator.free(keys);
            }
            for (keys) |key| {
                if (!std.mem.startsWith(u8, key, prefix) or seen_names.contains(key)) continue;
                const name = try allocator.dupe(u8, key);
                errdefer allocator.free(name);
                try names.append(allocator, name);
                try seen_names.put(allocator, name, {});
            }
            const parent = get(target, link.value, "__proto__") orelse break;
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
    fn get(target: engine.Context, object: engine.JSValue, name: []const u8) ?engine.Owned {
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
        var call: Call = .{ .realm = target, .object = object, .name = name };
        const thrown = engine.completionOf(target, Call.run, &call) catch return null;
        if (thrown) |t| {
            t.release();
            if (call.result) |r| r.release();
            return null;
        }
        return call.result;
    }

    /// EnumerableOwnProperties(object, key), what it throws caught: null
    /// for a throw. OWNED by `allocator`.
    fn keysOf(target: engine.Context, object: engine.JSValue, allocator: std.mem.Allocator) ?[][]u8 {
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
        var call: Call = .{ .realm = target, .object = object, .allocator = allocator };
        const thrown = engine.completionOf(target, Call.run, &call) catch null;
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

/// Real time, in nanoseconds, for the console's deadlines (the Browser's
/// clock may be virtual: Browser.spinEventLoopUntil's deadlines are real
/// time too).
fn nowNs() u64 {
    return @import("platform").monotonicNow().ns;
}

/// One input's evaluation, until it completes and is printed - or, when the
/// console stops waiting for it, until the engine ends it (exactly one of
/// its steps runs: engine.evaluateReplScript).
const Evaluation = struct {
    allocator: std.mem.Allocator,
    realm: engine.Context,
    console: *Console,
    /// The console stopped waiting: whichever step ends the evaluation frees
    /// it, printing nothing.
    abandoned: bool = false,

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = completed, .rejected = threw, .dropped = dropped };

    fn create(allocator: std.mem.Allocator, realm: engine.Context, console: *Console) !*Evaluation {
        const self = try allocator.create(Evaluation);
        self.* = .{ .allocator = allocator, .realm = realm, .console = console };
        return self;
    }

    fn destroy(self: *Evaluation) void {
        self.allocator.destroy(self);
    }

    /// The console stops waiting: the step that ends the evaluation frees it.
    fn abandon(self: *Evaluation) void {
        self.abandoned = true;
    }

    /// The input completed with `value`, or threw it. Runs as a promise job
    /// (script may run: the printer reads the value), so the value is
    /// formatted first and printed after, never under the output's lock.
    fn end(self: *Evaluation, value: ?engine.JSValue, uncaught: bool) void {
        defer self.destroy();
        if (self.abandoned) return;
        var text: std.Io.Writer.Allocating = .init(self.allocator);
        defer text.deinit();
        if (value) |v| {
            if (uncaught)
                printer.printUncaught(self.allocator, self.realm, v, &text.writer) catch {}
            else
                printer.printResult(self.allocator, self.realm, v, &text.writer) catch {};
        } else text.writer.writeAll("(no result: the page went away)\n") catch {};
        self.console.emit(text.written());
        self.console.evaluationEnded(self);
    }

    fn completed(data: ?*anyopaque, value: engine.JSValue) void {
        const self: *Evaluation = @ptrCast(@alignCast(data.?));
        self.end(value, false);
    }

    fn threw(data: ?*anyopaque, value: engine.JSValue) void {
        const self: *Evaluation = @ptrCast(@alignCast(data.?));
        self.end(value, true);
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *Evaluation = @ptrCast(@alignCast(data.?));
        self.end(null, false);
    }
};

// ============================================================================
// The terminal
// ============================================================================

/// Ctrl+C at a prompt, as Node's REPL answers it: with text on the line (or
/// an input continued over lines) the line goes; on an empty prompt the
/// first one says how to exit and a second one, with no other key between,
/// exits.
pub const ExitGuard = struct {
    armed: bool = false,

    pub const Answer = enum { clear_line, hint, exit };

    pub const hint_text = "(To exit, press Ctrl+C again or Ctrl+D or type .exit)\n";

    pub fn interrupt(self: *ExitGuard, line_empty: bool, continuation: bool) Answer {
        if (!line_empty or continuation) {
            self.armed = false;
            return .clear_line;
        }
        if (self.armed) return .exit;
        self.armed = true;
        return .hint;
    }

    /// Any other key.
    pub fn key(self: *ExitGuard) void {
        self.armed = false;
    }
};

/// The line editor, fed one byte at a time: cursor movement, history and
/// tab completion (the console's), echoing through `write`. It never reads:
/// the terminal's thread feeds it what it read.
const LineEditor = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayListUnmanaged(u8) = .empty,
    cursor: usize = 0,
    history: std.ArrayListUnmanaged([]u8) = .empty,
    history_index: usize = 0,
    /// The line being edited when the history was entered (Up).
    saved: ?[]u8 = null,
    /// An escape sequence in progress: the bytes after ESC so far.
    escape: [4]u8 = undefined,
    escape_len: usize = 0,
    in_escape: bool = false,

    const Action = union(enum) {
        none,
        /// Enter: the line, OWNED.
        line: []u8,
        /// Ctrl+D on an empty line.
        end,
        /// Ctrl+C.
        interrupt,
        /// Tab: complete the line (the cursor is at its end).
        complete,
    };

    fn deinit(self: *LineEditor) void {
        for (self.history.items) |item| self.allocator.free(item);
        self.history.deinit(self.allocator);
        self.buffer.deinit(self.allocator);
        if (self.saved) |s| self.allocator.free(s);
    }

    /// A new line begins.
    fn begin(self: *LineEditor) void {
        self.buffer.clearRetainingCapacity();
        self.cursor = 0;
        self.history_index = self.history.items.len;
        if (self.saved) |s| self.allocator.free(s);
        self.saved = null;
        self.in_escape = false;
        self.escape_len = 0;
    }

    fn addHistory(self: *LineEditor, line: []const u8) !void {
        if (line.len == 0) return;
        if (self.history.items.len > 0 and std.mem.eql(u8, self.history.items[self.history.items.len - 1], line)) return;
        try self.history.append(self.allocator, try self.allocator.dupe(u8, line));
    }

    /// One byte typed; `out` gets the echo.
    fn feed(self: *LineEditor, byte: u8, out: *std.Io.Writer) !Action {
        if (self.in_escape) return self.feedEscape(byte, out);
        switch (byte) {
            '\n', '\r' => {
                try out.writeAll("\n");
                const line = try self.allocator.dupe(u8, self.buffer.items);
                try self.addHistory(line);
                return .{ .line = line };
            },
            3 => return .interrupt, // Ctrl+C
            4 => if (self.buffer.items.len == 0) return .end, // Ctrl+D on an empty line
            127, 8 => if (self.cursor > 0) { // Backspace
                _ = self.buffer.orderedRemove(self.cursor - 1);
                self.cursor -= 1;
                try out.writeAll("\x08");
                try self.redrawFrom(out);
            },
            1 => if (self.cursor > 0) { // Ctrl+A
                try out.print("\x1b[{d}D", .{self.cursor});
                self.cursor = 0;
            },
            5 => if (self.cursor < self.buffer.items.len) { // Ctrl+E
                try out.print("\x1b[{d}C", .{self.buffer.items.len - self.cursor});
                self.cursor = self.buffer.items.len;
            },
            21 => try self.replaceLine("", out), // Ctrl+U
            11 => if (self.cursor < self.buffer.items.len) { // Ctrl+K
                self.buffer.shrinkRetainingCapacity(self.cursor);
                try out.writeAll("\x1b[K");
            },
            '\t' => if (self.cursor == self.buffer.items.len) return .complete,
            27 => {
                self.in_escape = true;
                self.escape_len = 0;
            },
            else => if (byte >= 32) {
                try self.buffer.insert(self.allocator, self.cursor, byte);
                try out.writeAll(&.{byte});
                self.cursor += 1;
                if (self.cursor < self.buffer.items.len) try self.redrawFrom(out);
            },
        }
        return .none;
    }

    /// The bytes of an escape sequence: the arrows, Home, End, Delete.
    fn feedEscape(self: *LineEditor, byte: u8, out: *std.Io.Writer) !Action {
        if (self.escape_len == 0 and byte != '[') {
            self.in_escape = false;
            return .none;
        }
        self.escape[self.escape_len] = byte;
        self.escape_len += 1;
        if (self.escape_len == 1) return .none; // '['
        const code = self.escape[1];
        if (code == '3') {
            if (self.escape_len < 3) return .none;
            self.in_escape = false;
            if (self.escape[2] == '~' and self.cursor < self.buffer.items.len) { // Delete
                _ = self.buffer.orderedRemove(self.cursor);
                try self.redrawFrom(out);
            }
            return .none;
        }
        self.in_escape = false;
        switch (code) {
            'A' => if (self.history_index > 0) { // Up: the history's previous line
                if (self.history_index == self.history.items.len) {
                    if (self.saved) |s| self.allocator.free(s);
                    self.saved = try self.allocator.dupe(u8, self.buffer.items);
                }
                self.history_index -= 1;
                try self.replaceLine(self.history.items[self.history_index], out);
            },
            'B' => if (self.history_index < self.history.items.len) { // Down
                self.history_index += 1;
                const line = if (self.history_index == self.history.items.len) self.saved orelse "" else self.history.items[self.history_index];
                try self.replaceLine(line, out);
            },
            'C' => if (self.cursor < self.buffer.items.len) { // Right
                self.cursor += 1;
                try out.writeAll("\x1b[C");
            },
            'D' => if (self.cursor > 0) { // Left
                self.cursor -= 1;
                try out.writeAll("\x1b[D");
            },
            'H' => if (self.cursor > 0) { // Home
                try out.print("\x1b[{d}D", .{self.cursor});
                self.cursor = 0;
            },
            'F' => if (self.cursor < self.buffer.items.len) { // End
                try out.print("\x1b[{d}C", .{self.buffer.items.len - self.cursor});
                self.cursor = self.buffer.items.len;
            },
            else => {},
        }
        return .none;
    }

    /// Replace the line being edited with `content`, the cursor at its end.
    fn replaceLine(self: *LineEditor, content: []const u8, out: *std.Io.Writer) !void {
        // `content` may be the saved line, which the buffer must not alias.
        const copy = try self.allocator.dupe(u8, content);
        defer self.allocator.free(copy);
        if (self.cursor > 0) try out.print("\x1b[{d}D", .{self.cursor});
        try out.writeAll("\x1b[K");
        self.buffer.clearRetainingCapacity();
        try self.buffer.appendSlice(self.allocator, copy);
        try out.writeAll(copy);
        self.cursor = copy.len;
    }

    /// Redraw from the cursor to the end of the line, the cursor kept.
    fn redrawFrom(self: *LineEditor, out: *std.Io.Writer) !void {
        const rest = self.buffer.items[self.cursor..];
        try out.writeAll(rest);
        try out.writeAll(" ");
        try out.print("\x1b[{d}D", .{rest.len + 1});
    }

    /// Draw `prompt` and the line, the cursor where it was.
    fn draw(self: *LineEditor, prompt: []const u8, out: *std.Io.Writer) !void {
        try out.writeAll(prompt);
        try out.writeAll(self.buffer.items);
        const back = self.buffer.items.len - self.cursor;
        if (back > 0) try out.print("\x1b[{d}D", .{back});
    }
};

/// The terminal: its own thread reads the keyboard (or piped input), edits
/// the line and posts each finished line to the Browser's event loop, where
/// the console takes it; the console tells it, through a pipe the thread
/// waits on beside the input, when it is ready for the next. Output from the
/// console - and the page, from any thread - is written above the prompt
/// (`Console.Display`).
pub const Terminal = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    console: *Console,
    browser: *Browser,
    stdin: std.Io.File,
    stdout: std.Io.File,
    /// The writer `console.out` is: the terminal's echo goes through it too,
    /// under the console's `out_mutex`.
    out: *std.Io.Writer,
    is_tty: bool,
    original: std.posix.termios = undefined,
    editor: LineEditor,
    /// What the line being edited answers; null while no prompt is shown.
    prompt: ?Console.Ready = null,
    /// Ctrl+C twice at an empty prompt exits (`ExitGuard`).
    exit_guard: ExitGuard = .{},
    /// The console's word, set on the window thread and read by the
    /// terminal's: 0 nothing yet, else a Console.Ready + 1.
    word: std.atomic.Value(u32) = .init(0),
    /// The pipe the console writes a byte to after setting `word`.
    wake: [2]std.posix.fd_t = .{ -1, -1 },
    thread: ?std.Thread = null,

    /// A terminal reading `input` (stdin, or a test's pipe) for `console`,
    /// echoing through `out` - the writer the console prints to.
    pub fn init(allocator: std.mem.Allocator, io: std.Io, console: *Console, browser: *Browser, input: std.Io.File, out: *std.Io.Writer) !Terminal {
        var self: Terminal = .{
            .allocator = allocator,
            .io = io,
            .console = console,
            .browser = browser,
            .stdin = input,
            .stdout = std.Io.File.stdout(),
            .out = out,
            .is_tty = try input.isTty(io),
            .editor = .{ .allocator = allocator },
        };
        if (std.c.pipe(&self.wake) != 0) return error.PipeFailed;
        return self;
    }

    pub fn deinit(self: *Terminal) void {
        self.editor.deinit();
        for (self.wake) |fd| if (fd >= 0) {
            _ = std.c.close(fd);
        };
    }

    /// Start the terminal's thread, and raw mode on a terminal (no echo, no
    /// line buffering, Ctrl+C as a byte rather than a signal).
    pub fn start(self: *Terminal) !void {
        if (self.is_tty) {
            self.original = try std.posix.tcgetattr(self.stdin.handle);
            var raw = self.original;
            raw.lflag.ICANON = false;
            raw.lflag.ECHO = false;
            raw.lflag.ISIG = false;
            raw.cc[@backingInt(std.posix.V.MIN)] = 1;
            raw.cc[@backingInt(std.posix.V.TIME)] = 0;
            try std.posix.tcsetattr(self.stdin.handle, .FLUSH, raw);
        }
        self.console.display = .{ .context = self, .clear = clear, .redraw = redraw };
        self.console.on_ready = .{ .context = self, .ready = ready };
        self.thread = try std.Thread.spawn(.{}, run, .{self});
    }

    /// End the terminal: its thread is told to end - whatever it waits for -
    /// and joined, then the terminal is restored. Once; again is nothing.
    pub fn stop(self: *Terminal) void {
        const thread = self.thread orelse return;
        ready(self, .exit);
        thread.join();
        self.thread = null;
        self.console.display = null;
        self.console.on_ready = null;
        if (self.is_tty) std.posix.tcsetattr(self.stdin.handle, .FLUSH, self.original) catch {};
    }

    /// Console.ReadyHook: the console's word, on the window thread.
    fn ready(context: *anyopaque, what: Console.Ready) void {
        const self: *Terminal = @ptrCast(@alignCast(context));
        self.word.store(@backingInt(what) + 1, .release);
        const byte = [1]u8{1};
        _ = std.c.write(self.wake[1], &byte, 1);
    }

    /// Console.Display.clear (out_mutex held): the prompt line goes.
    fn clear(context: *anyopaque) void {
        const self: *Terminal = @ptrCast(@alignCast(context));
        if (self.prompt == null or !self.is_tty) return;
        self.out.writeAll("\r\x1b[K") catch {};
    }

    /// Console.Display.redraw (out_mutex held): the prompt and the line again.
    fn redraw(context: *anyopaque) void {
        const self: *Terminal = @ptrCast(@alignCast(context));
        const prompt = self.prompt orelse return;
        if (!self.is_tty) return;
        self.editor.draw(promptText(prompt), self.out) catch {};
        self.out.flush() catch {};
    }

    fn promptText(what: Console.Ready) []const u8 {
        return if (what == .more) "... " else "> ";
    }

    /// The terminal's thread.
    fn run(self: *Terminal) void {
        // This thread's alternate signal stack, for a stack overflow's report (platform 6.4).
        const signal_stack = @import("platform").attachSignalStack();
        defer @import("platform").detachSignalStack(signal_stack);
        self.loop() catch |err| {
            self.console.emit("(the terminal failed)\n");
            std.log.warn("terminal: {s}", .{@errorName(err)});
            self.post(.end, null);
        };
    }

    fn loop(self: *Terminal) !void {
        // Bytes read but not yet edited: typed (or piped) while the console
        // was busy.
        var pending: std.ArrayListUnmanaged(u8) = .empty;
        defer pending.deinit(self.allocator);
        var input_ended = false;
        while (true) {
            // The console's word: draw the prompt, or end.
            if (self.takeWord()) |what| {
                if (what == .exit) return;
                std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
                self.prompt = what;
                self.editor.begin();
                self.out.writeAll(promptText(what)) catch {};
                self.out.flush() catch {};
                std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
            }
            // Edit what was typed while a prompt is shown.
            while (self.prompt != null and pending.items.len > 0) {
                const byte = pending.orderedRemove(0);
                try self.edit(byte);
            }
            if (self.prompt != null and input_ended and pending.items.len == 0) {
                // The end of input at a prompt: a last line without its
                // newline is a line; then, as Ctrl+D, the end.
                std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
                const last: ?[]u8 = if (!self.is_tty and self.editor.buffer.items.len > 0) self.allocator.dupe(u8, self.editor.buffer.items) catch null else null;
                if (last != null) {
                    self.editor.buffer.clearRetainingCapacity();
                    self.prompt = null;
                }
                std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
                if (last) |line| self.post(.line, line) else self.endInput();
            }
            // Wait for the keyboard and for the console.
            var fds = [_]std.posix.pollfd{
                .{ .fd = self.wake[0], .events = std.posix.POLL.IN, .revents = 0 },
                .{ .fd = self.stdin.handle, .events = std.posix.POLL.IN, .revents = 0 },
            };
            const watched: usize = if (input_ended) 1 else 2;
            _ = try std.posix.poll(fds[0..watched], -1);
            if (fds[0].revents != 0) {
                var drain: [16]u8 = undefined;
                _ = std.posix.read(self.wake[0], &drain) catch 0;
            }
            if (watched == 2 and fds[1].revents != 0) {
                var chunk: [512]u8 = undefined;
                const n = std.posix.read(self.stdin.handle, &chunk) catch 0;
                if (n == 0) {
                    input_ended = true;
                    continue;
                }
                for (chunk[0..n]) |byte| {
                    // Ctrl+C while the console is busy: stop what it waits
                    // for (a terminal only: piped input has no Ctrl+C).
                    if (self.prompt == null and self.is_tty and byte == 3) {
                        self.console.interrupt();
                        self.post(.interrupt_busy, null);
                        continue;
                    }
                    try pending.append(self.allocator, byte);
                }
            }
        }
    }

    fn takeWord(self: *Terminal) ?Console.Ready {
        const word = self.word.swap(0, .acquire);
        if (word == 0) return null;
        return @fromBackingInt(@intCast(word - 1));
    }

    /// One byte at the prompt.
    fn edit(self: *Terminal, byte: u8) !void {
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        const action = blk: {
            defer std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
            if (!self.is_tty) {
                // Piped input: lines, no editing and no echo.
                if (byte == '\n') {
                    const line = try self.allocator.dupe(u8, self.editor.buffer.items);
                    break :blk LineEditor.Action{ .line = line };
                }
                if (byte != '\r') try self.editor.buffer.append(self.allocator, byte);
                break :blk LineEditor.Action.none;
            }
            const line_empty = self.editor.buffer.items.len == 0;
            const action = try self.editor.feed(byte, self.out);
            self.out.flush() catch {};
            if (action == .interrupt) {
                switch (self.exit_guard.interrupt(line_empty, self.prompt == .more)) {
                    .clear_line => {},
                    .hint => {
                        self.out.writeAll("\n" ++ ExitGuard.hint_text) catch {};
                        self.out.writeAll(promptText(self.prompt orelse .ready)) catch {};
                        self.out.flush() catch {};
                        break :blk LineEditor.Action.none;
                    },
                    .exit => break :blk LineEditor.Action.end,
                }
            } else self.exit_guard.key();
            break :blk action;
        };
        switch (action) {
            .none => {},
            .line => |line| {
                std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
                self.prompt = null;
                std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
                self.post(.line, line);
            },
            .end => self.endInput(),
            .interrupt => {
                // Ctrl+C at the prompt: the line goes, as in Node; the
                // console drops what it has of the input and gives a new
                // prompt.
                std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
                self.out.writeAll("^C\n") catch {};
                self.out.flush() catch {};
                self.prompt = null;
                std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
                self.post(.interrupt_prompt, null);
            },
            .complete => self.completeLine(),
        }
    }

    fn endInput(self: *Terminal) void {
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        if (self.is_tty) self.out.writeAll("\n") catch {};
        self.out.flush() catch {};
        self.prompt = null;
        std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
        self.post(.end, null);
    }

    /// Tab: ask the console, on the window thread, and wait for its answer.
    fn completeLine(self: *Terminal) void {
        const request = CompletionRequest.create(self.allocator, self.console, self.editor.buffer.items) catch return;
        defer request.destroy();
        const sink = (self.browser.event_loop orelse return).taskSink();
        // The request is the task's until it has run or been dropped: either
        // sets `done`. The terminal keeps its own reference until then.
        request.refs.store(2, .release);
        _ = sink.post(.{ .run = CompletionRequest.run, .drop = CompletionRequest.drop, .data = request });
        request.done.waitUncancelable(self.io);
        const completions = request.result orelse return;
        std.Io.Threaded.mutexLockUncancelable(&self.console.out_mutex);
        defer std.Io.Threaded.mutexUnlock(&self.console.out_mutex);
        if (completions.names.len == 1) {
            const suffix = completions.names[0][completions.prefix_len..];
            self.editor.buffer.appendSlice(self.allocator, suffix) catch return;
            self.editor.cursor = self.editor.buffer.items.len;
            self.out.writeAll(suffix) catch {};
        } else if (completions.names.len > 1) {
            self.out.writeAll("\n") catch {};
            for (completions.names) |name| {
                self.out.writeAll(name) catch {};
                self.out.writeAll("  ") catch {};
            }
            self.out.writeAll("\n") catch {};
            self.editor.draw(promptText(self.prompt orelse .ready), self.out) catch {};
        }
        self.out.flush() catch {};
    }

    const Post = enum { line, end, interrupt_prompt, interrupt_busy };

    /// Hand the window thread a line, the end of input or an interrupt, as
    /// a task of its loop. `line` is OWNED and taken.
    fn post(self: *Terminal, kind: Post, line: ?[]u8) void {
        const task = InputTask.create(self.allocator, self.console, kind, line) catch {
            if (line) |l| self.allocator.free(l);
            return;
        };
        const event_loop = self.browser.event_loop orelse return InputTask.drop(task);
        _ = event_loop.taskSink().post(.{ .run = InputTask.run, .drop = InputTask.drop, .data = task });
    }
};

/// A line, the end of input or an interrupt, posted by the terminal's thread
/// to the Browser's loop, where it runs as a task: the console takes it.
const InputTask = struct {
    allocator: std.mem.Allocator,
    console: *Console,
    kind: Terminal.Post,
    line: ?[]u8,

    fn create(allocator: std.mem.Allocator, console: *Console, kind: Terminal.Post, line: ?[]u8) !*InputTask {
        const self = try allocator.create(InputTask);
        self.* = .{ .allocator = allocator, .console = console, .kind = kind, .line = line };
        return self;
    }

    fn run(data: ?*anyopaque) void {
        const self: *InputTask = @ptrCast(@alignCast(data.?));
        defer destroy(self);
        switch (self.kind) {
            .line => self.console.submitLine(self.line.?),
            .end => self.console.requestExit(),
            .interrupt_prompt => self.console.interrupted(.prompt),
            .interrupt_busy => self.console.interrupted(.busy),
        }
    }

    /// Never run (the loop ended): any thread.
    fn drop(data: ?*anyopaque) void {
        destroy(@ptrCast(@alignCast(data.?)));
    }

    fn destroy(self: *InputTask) void {
        if (self.line) |line| self.allocator.free(line);
        self.allocator.destroy(self);
    }
};

/// Tab completion asked of the window thread by the terminal's: the
/// console's answer, then `done`.
const CompletionRequest = struct {
    allocator: std.mem.Allocator,
    console: *Console,
    /// OWNED copy of the line.
    text: []u8,
    result: ?Console.Completions = null,
    done: std.Io.Event = .unset,
    /// The terminal's and the task's: the last frees it.
    refs: std.atomic.Value(u32) = .init(1),

    fn create(allocator: std.mem.Allocator, console: *Console, text: []const u8) !*CompletionRequest {
        const self = try allocator.create(CompletionRequest);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .console = console, .text = try allocator.dupe(u8, text) };
        return self;
    }

    fn run(data: ?*anyopaque) void {
        const self: *CompletionRequest = @ptrCast(@alignCast(data.?));
        self.result = self.console.complete(self.allocator, self.text) catch null;
        self.done.set(std.Io.Threaded.global_single_threaded.io());
        self.destroy();
    }

    fn drop(data: ?*anyopaque) void {
        const self: *CompletionRequest = @ptrCast(@alignCast(data.?));
        self.done.set(std.Io.Threaded.global_single_threaded.io());
        self.destroy();
    }

    fn destroy(self: *CompletionRequest) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        if (self.result) |*r| r.deinit(self.allocator);
        self.allocator.free(self.text);
        self.allocator.destroy(self);
    }
};

pub fn main(init: std.process.Init) !u8 {
    // The main thread's alternate signal stack, for the life of the process
    // (platform 6.4): std_options sets std's own off.
    _ = @import("platform").attachSignalStack();
    // First, before any thread exists: the engine's per-process state that
    // only threads created after it inherit (V8's thread isolation key on
    // x86-64 Linux; docs/engine-protocol.md 4.1).
    engine.initializeBeforeThreadCreation();
    const io = init.io;
    var stderr_buffer: [1024]u8 = undefined;
    var stderr = std.Io.File.stderr().writerStreaming(io, &stderr_buffer);
    const err_out = &stderr.interface;

    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var bad: []const u8 = "";
    const rest = try init.arena.allocator().alloc([]const u8, if (args.len > 0) args.len - 1 else 0);
    for (rest, 0..) |*arg, i| arg.* = args[i + 1];
    const options = parseOptions(rest, &bad) catch |err| {
        try err_out.print("repl: {s}: {s}\n{s}", .{ bad, switch (err) {
            error.UnknownOption => "unknown option",
            error.MissingValue => "needs a value",
            error.InvalidTimeout => "not a number of milliseconds",
            error.TooManyArguments => "only one URL is opened",
        }, usage });
        try err_out.flush();
        return 2;
    };
    if (options.help) {
        try err_out.writeAll(usage);
        try err_out.flush();
        return 0;
    }
    if (options.profile) |dir| {
        try err_out.print("repl: --profile={s}: {s}\n", .{ dir, profile_refusal });
        try err_out.flush();
        return 2;
    }

    // The console's allocator, chosen - not init.gpa, which in a Debug build
    // captures a stack trace on every allocation and free (DWARF unwinding on
    // the page's hot path: the WPT runner's 37-second lesson, docs/lessons/
    // debugging-a-two-subtest-page-took-37-seconds-to-exit-and.md). libc
    // malloc, as a host embedding Crane would; --check-leaks: a leak-checking
    // DebugAllocator with no traces (tests/wpt_runner/runner_allocator.zig's
    // configurations), with six-frame traces under CRANE_LEAK_TRACES=1.
    // Thread-safe in every case: workers allocate from their threads.
    var leak_check: std.heap.DebugAllocator(.{ .stack_trace_frames = 0, .safety = true }) = .init;
    var leak_trace: std.heap.DebugAllocator(.{ .stack_trace_frames = 6, .safety = true }) = .init;
    const traces = if (init.environ_map.get("CRANE_LEAK_TRACES")) |v| v.len != 0 and v[0] != '0' else false;
    const allocator: std.mem.Allocator = if (!options.check_leaks) std.heap.c_allocator else if (traces) leak_trace.allocator() else leak_check.allocator();
    defer if (options.check_leaks) {
        const leaked = if (traces) leak_trace.deinit() == .leak else leak_check.deinit() == .leak;
        err_out.print("repl: --check-leaks: {s}\n", .{if (leaked) "leaks reported above" else "no leaks"}) catch {};
        err_out.flush() catch {};
    };

    // The process first (crane.Process), as the WPT runner starts it: the
    // engine, its snapshot - the one beside this binary - and every hook.
    const exe_dir = std.process.executableDirPathAlloc(io, allocator) catch null;
    defer if (exe_dir) |dir| allocator.free(dir);
    const snapshot = if (exe_dir) |dir| try std.fs.path.join(allocator, &.{ dir, "whatwg_snapshot.bin" }) else null;
    defer if (snapshot) |path| allocator.free(path);
    const has_snapshot = if (snapshot) |path| blk: {
        std.Io.Dir.cwd().access(io, path, .{}) catch break :blk false;
        break :blk true;
    } else false;
    var process = try browser_mod.Process.init(.{ .snapshot_path = if (has_snapshot) snapshot else null });
    defer process.deinit();

    // In memory (BrowserConfig's default): nothing is written to disk.
    const browser = try Browser.init(allocator, .{
        .ca_bundle_path = options.ca_bundle,
        .user_agent = options.user_agent,
        .proxy = options.proxy,
        .accept_insecure_certs = options.accept_insecure_certs,
    });
    defer browser.deinit();

    var out_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &out_buffer);
    var console = Console.init(allocator, browser, &stdout.interface);
    defer console.deinit();
    console.deadline_ms = options.timeout_ms;
    console.load_timeout_ms = options.timeout_ms;
    // A terminal gets its prompt back at once, as Chrome's console does;
    // piped input waits for an input's navigation, so its next line reads
    // the new page.
    const stdin_is_tty = std.Io.File.stdin().isTty(io) catch false;
    console.wait_for_navigation = options.wait_for_navigation or !stdin_is_tty;
    // The page's own output prints here from now on, not on stderr.
    try console.attach();
    console.banner();

    // The first tab's page, loaded before the first prompt.
    if (!std.mem.eql(u8, options.url, "about:blank")) {
        console.open(options.url);
        try console.runUntilReady();
    }

    var terminal = try Terminal.init(allocator, io, &console, browser, std.Io.File.stdin(), &stdout.interface);
    defer terminal.deinit();
    try terminal.start();
    // The first prompt.
    console.begin();
    // The page is live for the console's whole life: the loop runs until the
    // console exits.
    _ = browser.spinEventLoopUntil(.{ .context = &console, .met = Console.exitGoal }, std.math.maxInt(u64)) catch {};
    console.tell(.exit);
    terminal.stop();
    return 0;
}

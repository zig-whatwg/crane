//! A Browser's developer console: where what its pages, frames and workers
//! print - the Console Standard's Printer output (console.log and the rest),
//! and the exceptions and promise rejections nothing handled, which HTML says
//! "the user agent may report ... to a developer console" ("report an
//! exception" step 7, "notify about rejected promises" step 4.1.3) - goes when
//! the Browser's host shows one (the browser console, tools/repl.zig, as
//! Chrome DevTools' console is a tab's).
//!
//! One per Browser: a supplement of its scope (runtime.BrowserScope;
//! docs/instances.md), made when the host attaches to it. A realm reaches it
//! through the scope it carries - a frame's is its page's, a worker's its
//! creator's - so every realm of a Browser prints to the same console, and no
//! other Browser's. With no host attached - every host but the console, the
//! WPT runner among them - nothing changes: `report` says so and the caller
//! prints where it always did (stderr, or its debug log).
//!
//! A message is reported on its realm's own thread - a page's on the
//! Browser's window thread, a worker's on the worker's - and the host is
//! called there, WITH the console's lock held, so detaching (`detach`) waits
//! out a call under way and no call reaches a host that has ended (the shape
//! of dom.cookie_change_listeners' RegistrationsHook). The host therefore
//! runs no script and does not report again: it reads the message, which the
//! caller formatted before reporting, and prints or copies it.
//!
//! Spec: https://console.spec.whatwg.org/#printer ("The printer is
//! implementation-defined"), https://html.spec.whatwg.org/multipage/webappapis.html#report-an-exception

const std = @import("std");
const runtime = @import("runtime");

/// What a message is.
pub const Kind = enum {
    /// The Console Standard's Printer, for a console method: `text` is what
    /// it printed, one or more lines without the last newline.
    console,
    /// HTML "report an exception" step 7: an exception nothing handled.
    /// `text` is its message ("Uncaught TypeError: ...").
    exception,
    /// HTML "notify about rejected promises" step 4.1.3: a rejection nothing
    /// handled. `text` is its message ("Uncaught (in promise) ...").
    rejection,
};

/// The Console Standard's logLevel of a Printer call (Console 2.3: the
/// method's name), or `error` for an exception or a rejection.
pub const Level = enum {
    log,
    info,
    debug,
    warn,
    @"error",
    trace,
    assert,
    dir,
    dirxml,
    table,
    group,
    groupCollapsed,
    count,
    countReset,
    time,
    timeLog,
    timeEnd,
};

/// Where an exception was thrown, as "extract error information" found it.
pub const Location = struct {
    /// The script's URL; empty when unknown.
    url: []const u8 = "",
    line: u32 = 0,
    column: u32 = 0,
};

/// One message, every field BORROWED for the call.
pub const Message = struct {
    /// The realm it came from: whose console method ran, or whose global the
    /// exception was reported for. The host may read it to say where the
    /// message came from (a tab, a frame, a worker), on this thread.
    realm: runtime.Context,
    kind: Kind,
    level: Level,
    text: []const u8,
    /// An exception's or a rejection's source; empty for a console message.
    location: Location = .{},
};

/// The host's side: `report` runs on the message's realm's thread with the
/// console's lock held. It must not run script or report again.
pub const Host = struct {
    context: *anyopaque,
    report: *const fn (context: *anyopaque, message: *const Message) void,
};

/// The supplement.
pub const DeveloperConsole = struct {
    /// Guards `host`; held across a host's `report`.
    mutex: std.Io.Mutex = .init,
    host: ?Host = null,

    pub fn init(allocator: std.mem.Allocator) DeveloperConsole {
        _ = allocator;
        return .{};
    }

    pub fn deinit(self: *DeveloperConsole) void {
        self.host = null;
    }

    fn lock(self: *DeveloperConsole) void {
        std.Io.Threaded.mutexLockUncancelable(&self.mutex);
    }

    fn unlock(self: *DeveloperConsole) void {
        std.Io.Threaded.mutexUnlock(&self.mutex);
    }
};

/// The host shows `scope`'s Browser's developer console from now on, until
/// `detach`: every message of its realms is reported to `host`, and none is
/// printed where it was before. A second attach replaces the first.
pub fn attach(scope: *runtime.BrowserScope, host: Host) std.mem.Allocator.Error!void {
    const console = try scope.of(DeveloperConsole);
    console.lock();
    defer console.unlock();
    console.host = host;
}

/// The host no longer shows the console: once this returns, no call reaches
/// it - a call under way on another thread has ended - and messages print
/// where they did before it attached.
pub fn detach(scope: *runtime.BrowserScope) void {
    const console = scope.existing(DeveloperConsole) orelse return;
    console.lock();
    defer console.unlock();
    console.host = null;
}

/// Whether `realm`'s Browser has a developer console attached: what a caller
/// asks before it formats a message only the console would read.
pub fn isAttached(realm: runtime.Context) bool {
    const console = consoleOf(realm) orelse return false;
    console.lock();
    defer console.unlock();
    return console.host != null;
}

/// Report `message` to its realm's Browser's developer console. False when
/// none is attached: the caller prints the message where it did before
/// there was one. Allocates nothing.
pub fn report(message: *const Message) bool {
    const console = consoleOf(message.realm) orelse return false;
    console.lock();
    defer console.unlock();
    const host = console.host orelse return false;
    host.report(host.context, message);
    return true;
}

/// `realm`'s Browser's console, if one was ever attached (never made here).
fn consoleOf(realm: runtime.Context) ?*DeveloperConsole {
    const scope = realm.browserScope() orelse return null;
    return scope.existing(DeveloperConsole);
}

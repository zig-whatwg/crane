//! The CookieStores that hear their Browser's cookie jar - Cookie Store
//! "process cookie changes": whenever the user agent's cookie store changes,
//! every CookieStore whose creation URL observes the change gets a `change`
//! event. One list per Browser: a supplement of its scope
//! (runtime.BrowserScope; docs/instances.md), installed as the change hook of
//! the Browser's jar when the Browser makes both (`hearJar`).
//!
//! The jar changes on whichever thread changed it - document.cookie or
//! cookieStore on the Browser's window thread, a worker's fetch storing a
//! `Set-Cookie` on the worker's thread - and each CookieStore hears it on
//! its own realm's thread: a listener on the changing thread is told at
//! once, one on another thread by a task posted to its realm's task sink,
//! carrying a copy of the cookie. (It was a threadlocal list, each thread's
//! own: a cookie a worker's fetch stored was never heard by a page's
//! CookieStore - lane workers' known gap "jar hooks per thread".)
//!
//! A listener is a platform object (the CookieStore) and the step that tells
//! it (`Deliver`), its owner's: this module never names the CookieStore.
//!
//! "Process cookie changes" has a second step, for every service worker
//! registration (Cookie Store 7.4 step 2): the Browser's service worker
//! manager hears every change through `registrations`, one slot, which it
//! sets when a realm first reaches it and clears at its end. Per-Browser
//! state, set on this Browser's own object - not a process-wide hook (AGENTS.md
//! "Global state" rule 2 is about those).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const cookiestore = @import("cookiestore");

pub const ChangeType = cookiestore.CookieChangeType;
pub const Cookie = cookiestore.Cookie;

/// Tell `listener` that `cookie` (borrowed for the call) was inserted or
/// removed. Runs on the listener's realm's thread.
pub const Deliver = *const fn (listener: *runtime.Instance, change_type: ChangeType, cookie: *const Cookie) void;

/// Cookie Store "process cookie changes" step 2's owner: the Browser's
/// service worker registrations (src/service_worker's manager). `changed`
/// runs on the changing thread WITH the listeners' lock held - so that
/// clearing the slot (`stopHearingRegistrations`) waits out a call under
/// way, and no call reaches an owner that has ended. It must not run script
/// or reach these listeners: it may read, copy and post.
pub const RegistrationsHook = struct {
    context: *anyopaque,
    changed: *const fn (context: *anyopaque, change_type: ChangeType, cookie: *const Cookie) void,
};

pub const CookieChangeListeners = struct {
    /// Thread-safe (a supplement's; a delivery's copy is freed on any thread).
    allocator: Allocator,
    /// Protects `entries` and `registrations`. Never held across a
    /// delivery: a delivery runs script, which can make or end a
    /// CookieStore. Held across the registrations hook, which runs none.
    mutex: std.Io.Mutex = .init,
    entries: std.ArrayListUnmanaged(Entry) = .empty,
    /// The registrations' step, or null while no service worker manager
    /// hears this Browser's jar.
    registrations: ?RegistrationsHook = null,

    const Entry = struct {
        listener: *runtime.Instance,
        /// Its slab generation when it began to listen: an address is not
        /// an identity.
        generation: u64,
        /// The thread its realm runs on - the one it registered from.
        thread: std.Thread.Id,
        /// Its realm's task sink, retained: where a change on another thread
        /// is posted. Null for a realm with none (a test's), which hears
        /// only the changes made on its own thread.
        sink: ?*runtime.TaskSink,
        deliver: Deliver,
    };

    pub fn init(allocator: Allocator) CookieChangeListeners {
        return .{ .allocator = allocator };
    }

    /// With the Browser's scope: every realm is gone, and so is every
    /// listener; what is left is let go.
    pub fn deinit(self: *CookieChangeListeners) void {
        for (self.entries.items) |entry| if (entry.sink) |sink| sink.release();
        self.entries.deinit(self.allocator);
    }

    /// The listeners of the Browser `realm` belongs to, made on first use;
    /// null for a realm no Browser made.
    pub fn of(realm: runtime.Context) ?*CookieChangeListeners {
        const scope = realm.browser_scope orelse return null;
        return scope.of(CookieChangeListeners) catch null;
    }

    /// `realm`'s Browser's listeners if it made them; never makes them.
    pub fn existingOf(realm: runtime.Context) ?*CookieChangeListeners {
        const scope = realm.browser_scope orelse return null;
        return scope.existing(CookieChangeListeners);
    }

    /// Become `jar`'s change hook. The Browser does this once, when it makes
    /// its jar and these listeners - before any realm can change the jar.
    pub fn hearJar(self: *CookieChangeListeners, jar: *cookiestore.CookieJar) void {
        jar.on_change = .{ .callback = &jarChanged, .context = self };
    }

    /// The Browser's service worker registrations hear every change from
    /// now until `stopHearingRegistrations` (its manager's own end).
    pub fn hearRegistrations(self: *CookieChangeListeners, hook: RegistrationsHook) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        self.registrations = hook;
    }

    /// The registrations owner `context` hears nothing more: once this
    /// returns, no call to its hook is under way or will start.
    pub fn stopHearingRegistrations(self: *CookieChangeListeners, context: *anyopaque) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        const hook = self.registrations orelse return;
        if (hook.context == context) self.registrations = null;
    }

    /// `listener` hears every change from now until `unlisten`; `deliver`
    /// tells it, on this thread - its realm's.
    pub fn listen(self: *CookieChangeListeners, listener: *runtime.Instance, deliver: Deliver) Allocator.Error!void {
        const sink: ?*runtime.TaskSink = if (listener.ctx.task_sink) |s| s.retain() else null;
        errdefer if (sink) |s| s.release();
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        try self.entries.append(self.allocator, .{
            .listener = listener,
            .generation = runtime.SlabAllocator.generationOf(listener),
            .thread = std.Thread.getCurrentId(),
            .sink = sink,
            .deliver = deliver,
        });
    }

    /// `listener` hears nothing more; a delivery already posted finds it
    /// gone (`isListening`).
    pub fn unlisten(self: *CookieChangeListeners, listener: *runtime.Instance) void {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        var i: usize = 0;
        while (i < self.entries.items.len) {
            const entry = self.entries.items[i];
            if (entry.listener == listener) {
                if (entry.sink) |sink| sink.release();
                _ = self.entries.swapRemove(i);
            } else {
                i += 1;
            }
        }
        if (self.entries.items.len == 0) self.entries.clearAndFree(self.allocator);
    }

    /// Whether `listener`, as it was at `generation`, still hears changes.
    pub fn isListening(self: *CookieChangeListeners, listener: *runtime.Instance, generation: u64) bool {
        std.Io.Threaded.mutexLock(&self.mutex);
        defer std.Io.Threaded.mutexUnlock(&self.mutex);
        for (self.entries.items) |entry| {
            if (entry.listener == listener and entry.generation == generation) return true;
        }
        return false;
    }

    /// A listener this thread tells itself, after the lock is released.
    const Local = struct { listener: *runtime.Instance, generation: u64, deliver: Deliver };

    /// The jar's change hook: `cookie` (borrowed) was inserted or removed, on
    /// this thread, the jar unlocked. HttpOnly cookies are never observable
    /// to script.
    fn jarChanged(context: ?*anyopaque, change_type: ChangeType, cookie: *const Cookie) void {
        if (cookie.http_only) return;
        const self: *CookieChangeListeners = @ptrCast(@alignCast(context.?));
        const here = std.Thread.getCurrentId();
        var local: std.ArrayListUnmanaged(Local) = .empty;
        defer local.deinit(self.allocator);
        {
            std.Io.Threaded.mutexLock(&self.mutex);
            defer std.Io.Threaded.mutexUnlock(&self.mutex);
            for (self.entries.items) |entry| {
                if (entry.thread == here) {
                    local.append(self.allocator, .{ .listener = entry.listener, .generation = entry.generation, .deliver = entry.deliver }) catch continue;
                    continue;
                }
                // Another thread's: a task of its realm's loop, with a copy
                // of the cookie (the jar's may be gone by the time it runs).
                // `post` drops a task it cannot take - its loop has ended.
                const sink = entry.sink orelse continue;
                const delivery = Delivery.create(self, entry, change_type, cookie) catch continue;
                _ = sink.post(.{ .run = Delivery.run, .drop = Delivery.drop, .data = delivery });
            }
            // Step 2: the service worker registrations, told under the lock
            // (`RegistrationsHook`).
            if (self.registrations) |hook| hook.changed(hook.context, change_type, cookie);
        }
        for (local.items) |entry| {
            // A delivery runs script (its realm's task can run here and now,
            // in a realm with no loop), which can end another listener.
            if (!self.isListening(entry.listener, entry.generation)) continue;
            entry.deliver(entry.listener, change_type, cookie);
        }
    }
};

/// A change, posted to a listener's realm's loop on another thread.
const Delivery = struct {
    /// Outlives the task: the Browser's scope ends after every loop of the
    /// Browser, and a loop's end drops what it did not run.
    listeners: *CookieChangeListeners,
    listener: *runtime.Instance,
    generation: u64,
    deliver: Deliver,
    change_type: ChangeType,
    /// OWNED: a copy.
    cookie: Cookie,

    fn create(listeners: *CookieChangeListeners, entry: CookieChangeListeners.Entry, change_type: ChangeType, cookie: *const Cookie) !*Delivery {
        const self = try listeners.allocator.create(Delivery);
        errdefer listeners.allocator.destroy(self);
        self.* = .{
            .listeners = listeners,
            .listener = entry.listener,
            .generation = entry.generation,
            .deliver = entry.deliver,
            .change_type = change_type,
            .cookie = try cookie.clone(listeners.allocator),
        };
        return self;
    }

    fn destroy(self: *Delivery) void {
        self.cookie.deinit();
        self.listeners.allocator.destroy(self);
    }

    /// On the listener's thread, a task of its loop.
    fn run(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data.?));
        defer self.destroy();
        if (!self.listeners.isListening(self.listener, self.generation)) return;
        self.deliver(self.listener, self.change_type, &self.cookie);
    }

    /// Never to run: any thread.
    fn drop(data: ?*anyopaque) void {
        const self: *Delivery = @ptrCast(@alignCast(data.?));
        self.destroy();
    }
};

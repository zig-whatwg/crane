//! GC integration for JavaScript engine
//!
//! This module provides callbacks for JavaScript engine garbage collectors.
//! It handles:
//! - Object finalization (onObjectFreed): the object's own cleanup, then its
//!   storage back to its Browser's slab and arena (releaseStorage)
//! - The deferred teardown queue (DeferredTeardown)
//!
//! Supported JavaScript engines:
//! - V8 (Chrome, Node.js)
//! - JavaScriptCore (Safari, Bun)
//! - SpiderMonkey (Firefox)
//!
//! Thread safety: Callbacks are called from GC thread
//! Memory model: Two-phase cleanup (deinit resources, then return the storage)
//!
//! ## Typed GC Callback Support
//!
//! For type-safe GC finalizers, use runtime.TypedGCCallback:
//!
//! ```zig
//! const typed_callback = @import("typed_callback.zig");
//!
//! const NativeResource = struct {
//!     file_handle: std.Io.File,
//!     io: std.Io,
//!     buffer: []u8,
//!     allocator: std.mem.Allocator,
//! };
//!
//! fn cleanupResource(resource: *NativeResource) void {
//!     resource.file_handle.close(resource.io);
//!     resource.allocator.free(resource.buffer);
//! }
//!
//! // Create resource on heap (required for GC callbacks)
//! var resource = try allocator.create(NativeResource);
//! resource.* = .{ .file_handle = file, .buffer = buf, .allocator = allocator };
//!
//! // Create typed callback
//! var cb = typed_callback.TypedGCCallback(NativeResource).init(
//!     &cleanupResource,
//!     resource,
//!     allocator,
//! );
//!
//! // Register with V8 weak callback API
//! // The toLegacyCallbackC() provides C-compatible function pointer
//! v8_set_weak_callback(handle, cb.getDataAnyopaque(), TypedGCCallback(NativeResource).toLegacyCallbackC());
//! ```
//!
//! ## Lifetime Contracts
//!
//! ### GC Finalizer Callbacks
//! - UserData MUST be heap-allocated (stack is invalid during GC)
//! - GC may call finalizer on ANY thread (must be thread-safe)
//! - After finalizer returns, object is fully collected
//! - Do NOT access JavaScript objects from finalizer (may trigger GC recursion)
//! - Do NOT allocate in finalizer (may cause deadlock)

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const BrowserScope = @import("browser_scope.zig").BrowserScope;

/// GC finalizer callback - called when JS engine garbage collects an object
///
/// This is called by the JavaScript engine's GC when it determines an object
/// is no longer reachable. The callback must:
/// 1. Call the type-specific deinit function to clean up owned resources
/// 2. Return the Instance handle to the slab allocator
/// 3. NOT free FullState memory (arena handles that in batch)
///
/// Signature: extern "C" fn(user_data: ?*anyopaque) void
///
/// JavaScript engines register this as the finalizer when creating objects:
///   // V8 example:
///   v8::External::New(isolate, instance);
///   object->SetAlignedPointerInInternalField(0, instance);
///   // Register finalizer:
///   object.SetWeak(instance, onObjectFreed, v8::WeakCallbackType::kParameter);
///
/// Thread safety: Called from GC thread, must not allocate or access shared state
///
/// ## Type Safety Note (KEEP - C ABI boundary)
///
/// This function uses `?*anyopaque` because it must be compatible with the C ABI
/// for JavaScript engine callbacks. The `callconv(.c)` calling convention requires
/// C-compatible types. For type-safe GC callbacks, use `TypedGCCallback(T)` from
/// `runtime.typed_callback` which provides a typed wrapper that converts to this
/// C-compatible signature.
///
/// Example with TypedGCCallback:
/// ```zig
/// const typed_callback = @import("typed_callback.zig");
/// var cb = TypedGCCallback(MyResource).init(&cleanupFn, resource, allocator);
/// v8.setWeakCallback(handle, cb.getDataAnyopaque(), TypedGCCallback(MyResource).toLegacyCallbackC());
/// ```
pub fn onObjectFreed(user_data: ?*anyopaque) callconv(.c) void {
    // KEEP: @ptrCast/@alignCast required at C ABI boundary - use TypedGCCallback for type-safe wrappers
    const inst = @as(*Instance, @ptrCast(@alignCast(user_data orelse return)));

    // Step 1: Call type-specific deinit to clean up owned resources
    // (strings, arrays, etc. allocated by the implementation)
    if (inst.vtable.deinit) |deinit| {
        deinit(inst); // Calls Node.deinit_wrapper → Node.deinit
    }

    releaseStorage(inst);
}

/// The storage half of `onObjectFreed`, for an instance whose deinit has
/// already run - a node its tree tore down (`instance_lifecycle.isCleanedUp`)
/// while its wrapper was still cached. The caller has established that the
/// slot was not reissued.
pub fn releaseStorage(inst: *Instance) void {
    // Its Browser's: the scope whose slab issued it, read from its address -
    // never its context, which its realm's end may already have freed.
    const scope = BrowserScope.ofInstance(inst);

    // Step 2: Return the state block for reuse.
    //
    // The finalizer path, the counterpart to Instance.deinit - and the one that
    // actually runs for DOM nodes, since their lifetime is V8's to decide. Without
    // it a collected node returns its Instance handle to the slab but keeps its
    // state forever, which is what `zig build gc-bench` measures: live instances
    // fall to 9 under a forced GC while RSS keeps climbing.
    if (inst.vtable.state_size != 0) {
        scope.arena.destroyRaw(
            @ptrCast(inst.state),
            inst.vtable.state_size,
            inst.vtable.state_align,
        );
    }

    // Step 3: Return Instance handle to slab allocator
    scope.slab.free(inst);
}

/// An agent's queue of native objects whose last owner went away - a node
/// root whose wrapper the collector took, today; an object whose reference
/// count reached zero, once the DOM counts references - to be torn down soon,
/// but not where the owner went away. A collected tree of thousands of nodes
/// torn down in V8's second pass landed in the middle of whatever script the
/// next collection interrupted; Blink sweeps incrementally (Oilpan's lazy and
/// concurrent sweeping) and WebKit frees by reference count as it goes. Here
/// the teardown runs:
///
/// - a bounded slice at a time from the agent's event loop, between tasks
///   (`runSlice`: at most `slice_budget` nodes, so a 10,000-node tree is freed
///   over several slices);
/// - fully at the end of the realm an item belongs to (`drainOwner`), and at
///   the agent's and the Browser's ends (`drainAll`, then `close`);
/// - inline past the memory bound (`relieve`): over `high_water` queued nodes,
///   the safe point that queued an item frees as many nodes as it added, and a
///   slice more, so churn inside one long script cannot grow the queue.
///
/// The queue never interprets an item: its `Steps` re-check whether the object
/// may still be freed (a new owner may have taken it in between - the queue
/// holds it, not a reference) and free it, a budget at a time. An item's
/// instance keeps its slab generation until its steps free it.
///
/// One per agent, on the agent's thread (the host's AgentHost owns it; the
/// engine adapter queues into it - engine.AgentOptions.deferred_teardown).
/// Not thread-safe.
pub const DeferredTeardown = struct {
    allocator: std.mem.Allocator,
    head: ?*Item = null,
    tail: ?*Item = null,
    /// Items queued (not counting the one a slice has in hand).
    count: usize = 0,
    /// The nodes the queued items stood for when queued, less those freed
    /// since: what the memory bound reads.
    pending: usize = 0,
    /// A slice is running: the memory bound waits for it to return instead of
    /// running one inside it (a collection during a teardown queues more).
    slicing: bool = false,
    /// The agent ended: `push` refuses, and its caller tears down inline.
    closed: bool = false,
    /// Totals for tests and diagnostics.
    queued_total: usize = 0,
    freed_total: usize = 0,

    /// Nodes a slice frees at most.
    pub const slice_budget: usize = 512;
    /// Queued nodes past which the safe points that queue items free them.
    pub const high_water: usize = 100_000;
    /// Queued nodes an event loop's turn leaves at most: past it, the turn
    /// frees down to it whatever waits - a bounded pause between tasks - so a
    /// page whose every task makes more garbage than a turn's share never
    /// grows the queue into `high_water`, where it would be freed inside
    /// script again.
    pub const loop_low_water: usize = high_water / 4;

    /// What `push` takes.
    pub const Request = struct {
        /// The object; its slab slot stays issued until `steps` frees it.
        instance: *Instance,
        /// Its slab generation when it was queued.
        generation: u64,
        /// Whose end must drain it (`drainOwner`) - a realm's - or null.
        owner: ?*const anyopaque,
        steps: *const Steps,
        /// The steps' own, BORROWED while queued.
        data: ?*anyopaque = null,
        /// The nodes it stands for (an estimate is fine), for the memory bound.
        weight: usize = 1,
    };

    /// An item's place in its own teardown, kept by its steps between slices:
    /// the object the next slice resumes from, and its slab generation.
    pub const Position = struct {
        instance: ?*Instance = null,
        generation: u64 = 0,
    };

    pub const Item = struct {
        prev: ?*Item = null,
        next: ?*Item = null,
        instance: *Instance,
        generation: u64,
        owner: ?*const anyopaque,
        steps: *const Steps,
        data: ?*anyopaque,
        weight: usize,
        /// The part of `weight` already taken off `pending`.
        accounted: usize = 0,
        position: Position = .{},
    };

    /// How a slice of one item went.
    pub const Progress = struct {
        /// Nodes freed (or found already gone).
        freed: usize,
        /// The item is finished: freed, or no longer the queue's to free.
        done: bool,
    };

    pub const Steps = struct {
        /// Free at most `budget` nodes of `item` (at least one unless done);
        /// re-check first that it is still the queue's to free.
        run: *const fn (item: *Item, budget: usize) Progress,
    };

    pub fn init(allocator: std.mem.Allocator) DeferredTeardown {
        return .{ .allocator = allocator };
    }

    /// The queue is empty by now: its agent's end drained it.
    pub fn deinit(self: *DeferredTeardown) void {
        std.debug.assert(self.isEmpty());
        // Whatever a release build still holds goes without its teardown:
        // its instances go with the runtime's pools.
        while (self.popFront()) |item| self.allocator.destroy(item);
    }

    pub fn isEmpty(self: *const DeferredTeardown) bool {
        return self.head == null;
    }

    pub fn len(self: *const DeferredTeardown) usize {
        return self.count;
    }

    pub fn pendingNodes(self: *const DeferredTeardown) usize {
        return self.pending;
    }

    /// Queue `request`: false when the queue is closed or out of memory - the
    /// caller then tears the object down itself, as before there was a queue.
    pub fn push(self: *DeferredTeardown, request: Request) bool {
        if (self.closed) return false;
        const item = self.allocator.create(Item) catch return false;
        item.* = .{
            .instance = request.instance,
            .generation = request.generation,
            .owner = request.owner,
            .steps = request.steps,
            .data = request.data,
            .weight = request.weight,
        };
        self.pushBack(item);
        self.pending += request.weight;
        self.queued_total += 1;
        return true;
    }

    /// One slice: items in the order they were queued, until `budget` nodes
    /// are freed or the queue is empty. An item left unfinished stays first.
    /// Returns the nodes freed.
    pub fn runSlice(self: *DeferredTeardown, budget: usize) usize {
        const was_slicing = self.slicing;
        self.slicing = true;
        defer self.slicing = was_slicing;
        var freed: usize = 0;
        while (freed < budget) {
            const item = self.popFront() orelse break;
            const progress = item.steps.run(item, budget - freed);
            self.account(item, progress.freed);
            // An item that freed nothing and is not done would hold the
            // queue: count it as one, so the slice still ends.
            freed += @max(progress.freed, 1);
            if (progress.done) self.finish(item) else self.pushFront(item);
        }
        return freed;
    }

    /// `owner`'s end - its realm's: every item of it, in full, now. Items a
    /// teardown queues meanwhile for the same owner go too.
    pub fn drainOwner(self: *DeferredTeardown, owner: *const anyopaque) void {
        self.drainMatching(owner, false);
    }

    /// The agent's end, a full collection, the host short of memory: every
    /// item, in full, now.
    pub fn drainAll(self: *DeferredTeardown) void {
        self.drainMatching(null, true);
    }

    /// `owner` ends without teardowns (its objects go with the pools): forget
    /// its items.
    pub fn dropOwner(self: *DeferredTeardown, owner: *const anyopaque) void {
        var at = self.head;
        while (at) |item| {
            at = item.next;
            if (item.owner != @as(?*const anyopaque, owner)) continue;
            self.unlink(item);
            self.finish(item);
        }
    }

    /// The agent is ending: nothing is queued from here on.
    pub fn close(self: *DeferredTeardown) void {
        self.closed = true;
    }

    /// The memory bound, at a safe point that just queued `added` nodes: under
    /// `high_water`, nothing; over it, free `added` nodes and a slice more -
    /// inline, as before there was a queue - so the queue shrinks instead of
    /// growing. A no-op inside a slice, which returns soon.
    pub fn relieve(self: *DeferredTeardown, added: usize) void {
        if (self.slicing or self.pending <= high_water) return;
        _ = self.runSlice(added +| slice_budget);
    }

    fn drainMatching(self: *DeferredTeardown, owner: ?*const anyopaque, all: bool) void {
        const was_slicing = self.slicing;
        self.slicing = true;
        defer self.slicing = was_slicing;
        while (true) {
            // Take the matching items out first: a teardown may end another
            // realm, whose drain must not meet the items in hand.
            var taken: ?*Item = null;
            var at = self.head;
            while (at) |item| {
                at = item.next;
                if (!all and item.owner != owner) continue;
                self.unlink(item);
                item.next = taken;
                taken = item;
            }
            if (taken == null) return;
            // `taken` is in reverse; run in queue order.
            var ordered: ?*Item = null;
            while (taken) |item| {
                taken = item.next;
                item.next = ordered;
                ordered = item;
            }
            while (ordered) |item| {
                ordered = item.next;
                item.next = null;
                while (true) {
                    const progress = item.steps.run(item, std.math.maxInt(usize));
                    self.account(item, progress.freed);
                    if (progress.done) break;
                }
                self.finish(item);
            }
        }
    }

    fn account(self: *DeferredTeardown, item: *Item, freed: usize) void {
        self.freed_total += freed;
        const take = @min(freed, item.weight - item.accounted);
        item.accounted += take;
        self.pending -|= take;
    }

    /// The item is done: what is left of its weight comes off `pending`.
    fn finish(self: *DeferredTeardown, item: *Item) void {
        self.pending -|= item.weight - item.accounted;
        self.allocator.destroy(item);
    }

    fn pushBack(self: *DeferredTeardown, item: *Item) void {
        item.prev = self.tail;
        item.next = null;
        if (self.tail) |tail| tail.next = item else self.head = item;
        self.tail = item;
        self.count += 1;
    }

    fn pushFront(self: *DeferredTeardown, item: *Item) void {
        item.prev = null;
        item.next = self.head;
        if (self.head) |head| head.prev = item else self.tail = item;
        self.head = item;
        self.count += 1;
    }

    fn popFront(self: *DeferredTeardown) ?*Item {
        const item = self.head orelse return null;
        self.unlink(item);
        return item;
    }

    fn unlink(self: *DeferredTeardown, item: *Item) void {
        if (item.prev) |prev| prev.next = item.next else self.head = item.next;
        if (item.next) |next| next.prev = item.prev else self.tail = item.prev;
        item.prev = null;
        item.next = null;
        self.count -= 1;
    }
};

/// Error type for GC integration operations
pub const GCError = error{
    /// registerCallbacks was called but no JS engine implementation is available
    NotImplemented,
};

/// Register GC callbacks with JavaScript engine (engine-specific)
///
/// This is a helper that would be called during engine initialization.
/// The actual implementation depends on which JavaScript engine is used.
///
/// Returns error.NotImplemented if called without a specific JS engine binding.
/// In practice, engine-specific bindings (V8, JSC) provide their own registration.
///
/// Example for V8:
///   extern fn registerV8Callbacks(isolate: *v8.Isolate) void;
///
/// Example for JavaScriptCore:
///   extern fn registerJSCCallbacks(ctx: *JSC.JSContextRef) void;
pub fn registerCallbacks() GCError!void {
    // This is a placeholder - actual implementation depends on JS engine
    // In practice, this would be implemented in the JS engine binding layer
    return GCError.NotImplemented;
}

// ============================================================================
// Typed Wrapper for Internal Use
// ============================================================================

/// Create a typed finalizer function from a cleanup callback.
///
/// This is a convenience wrapper for internal Zig code that wants type safety
/// when registering GC finalizers. The underlying C ABI callback (`onObjectFreed`)
/// must still use `?*anyopaque` for engine compatibility.
///
/// ## Example
///
/// ```zig
/// const MyResource = struct {
///     buffer: []u8,
///     allocator: std.mem.Allocator,
///
///     pub fn cleanup(self: *MyResource) void {
///         self.allocator.free(self.buffer);
///     }
/// };
///
/// // Register with typed safety
/// const finalizer = TypedFinalizer(MyResource).init(&MyResource.cleanup);
/// // The finalizer can be stored and invoked with type safety
/// // For actual GC registration, use onObjectFreed which handles the C ABI
/// ```
pub fn TypedFinalizer(comptime T: type) type {
    return struct {
        const Self = @This();

        /// The typed cleanup function
        cleanup_fn: *const fn (*T) void,

        /// Initialize with a typed cleanup function
        pub fn init(cleanup_fn: *const fn (*T) void) Self {
            return .{ .cleanup_fn = cleanup_fn };
        }

        /// Invoke the cleanup function on a typed pointer
        pub fn invoke(self: Self, instance: *T) void {
            self.cleanup_fn(instance);
        }
    };
}

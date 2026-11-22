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
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;

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

/// An owner tears down `child`, a platform object it made and keeps for
/// its own life - a [SameObject] child (dom same_object.KeptChild), an
/// element's attribute map, a window's Location and History - and frees it
/// WHOLE, as the abortsig1 rule asks: an interface's deinit is a destructor,
/// not a free (docs/lessons/architecture-an-interfaces-deinit-is-a-destructor-not-a-free.md).
///
/// The destructor chain runs now, once (the cleanup flags guard it and
/// record it). The storage - the state block and the slab slot - goes back
/// to whoever can reach it last:
/// - no engine object can reach the child (instance_lifecycle
///   .provablyUnwrapped: never wrapped, or its last wrapper finalized):
///   now, or, inside a coordinated realm teardown, once its last phase is
///   done (cleanup_coordinator.deferStorageRelease) - every later phase sees
///   what it saw before;
/// - otherwise its wrapper's end - its finalizer, or its realm's wrapper
///   cache's sweep - which returns the storage of an instance whose cleanup
///   completed, and never runs the destructor again.
///
/// Makes no engine call, so it is safe in any teardown, the collector's
/// included. Only for a child that is still the object the owner made (a
/// generation check, the caller's - same_object.Link).
pub fn releaseOwned(child: *Instance) void {
    const instance_lifecycle = @import("instance_lifecycle.zig");
    const cleanup_coordinator = @import("cleanup_coordinator.zig");
    const generation = SlabAllocator.generationOf(child);
    if (generation == SlabAllocator.dead_generation) return;
    if (instance_lifecycle.markCleanupStarted(child)) {
        if (child.vtable.deinit) |deinit| deinit(child);
        instance_lifecycle.markCleanupComplete(child);
    }
    // The destructor may have freed the child some other way (a type that
    // frees itself): its slot is no longer this child's.
    if (SlabAllocator.generationOf(child) != generation or !instance_lifecycle.isCleanedUp(child)) return;
    const tracked = @import("engine").capabilities.wrap_tracking != .unsupported;
    if (!instance_lifecycle.provablyUnwrapped(tracked, child)) return;
    if (cleanup_coordinator.isContextTearingDown())
        cleanup_coordinator.deferStorageRelease(child, generation)
    else
        releaseStorage(child);
}

/// A realm's global object - a Window - whose realm has ended: its
/// destructor chain ran (its cleanup is marked complete) and its owner, the
/// realm's end, severed every engine object that named it (the WindowProxy,
/// the hidden global, the WindowProperties object), so no wrapper can reach
/// its slot. Its storage goes back now, or, inside a coordinated teardown
/// still under way (a realm ended within another's), once that teardown's
/// last phase is done - releaseOwned's rule, for an instance whose wrapper
/// its owner severed rather than one no wrapper reached. Only while its slot
/// is still the one `generation` names. Makes no engine call.
pub fn releaseSevered(instance: *Instance, generation: u64) void {
    const instance_lifecycle = @import("instance_lifecycle.zig");
    const cleanup_coordinator = @import("cleanup_coordinator.zig");
    if (SlabAllocator.generationOf(instance) != generation) return;
    if (!instance_lifecycle.isCleanedUp(instance)) return;
    if (cleanup_coordinator.isContextTearingDown())
        cleanup_coordinator.deferStorageRelease(instance, generation)
    else
        releaseStorage(instance);
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
    /// DOM algorithms on the agent's stack (refcount design 9, risk 4): the
    /// adapter counts every binding entry - script calling into the DOM - and
    /// every native-to-script callback invocation - a native dispatch, a
    /// custom element reaction, an observer callback calling script
    /// (docs/engine-protocol.md, "Deferred teardown"). Nothing of the queue
    /// is freed while it is not zero; what a push or a full collection asks
    /// for meanwhile is OWED and runs when the outermost binding exit brings
    /// it back to zero - back in script, no DOM frame below - or at the event
    /// loop's next slice. A callback's return into its native caller never
    /// runs it.
    algorithm_depth: u32 = 0,
    /// What the queue owes the next safe point (see `algorithm_depth`). One
    /// byte, which the agent's adapter also writes (`owedWord`).
    owed: Owed = .{},
    /// What the agent's adapter runs at a safe point when the agent's DOM
    /// memory moved past its report step (`Owed.report`; runtime.gc.
    /// ExternalMemory): it tells its engine. Set by the adapter while the
    /// agent lives (engine.AgentOptions.external_memory), null otherwise.
    report_steps: ?ReportSteps = null,
    /// What the agent's adapter runs at a safe point when its engine's
    /// collector found wrappers dead (`Owed.finalizers`, `Owed.fresh`): the
    /// finalizers the collector may not run itself. Set by the adapter while
    /// the agent lives, null otherwise.
    finalizer_steps: ?FinalizerSteps = null,
    /// The agent's callback clock (`Callbacks`): which native-to-script
    /// callback invocation is innermost on the stack, and when it began -
    /// what decides which finalizers may run inside a callback's script.
    callback: Callbacks = .{},
    /// The DOM memory the queued trees' dying bytes are counted in
    /// (`Item.dying`): the one the first push that decides bytes dead names
    /// (`Dying.memory`) - the agent's Browser's, one for the queue's life.
    /// BORROWED; it outlives the queue's items (a BrowserScope's). A push
    /// that names another decides nothing dead: its tree's bytes stay in
    /// that memory's figure until they are freed.
    memory: ?*ExternalMemory = null,
    /// The DOM's books of the trees its counts queued here (refcount step 7,
    /// dom.refcount_teardown): diagnostics and tests.
    books: Books = .{},
    /// Why the agent's end may find nodes alive - a test that exercises the
    /// final sweep or an out-of-memory path says so here
    /// (dom.refcount_teardown.allowLiveNodesAtAgentEnd); null, the default,
    /// makes any node alive there an error in a unit test.
    live_nodes_at_end_allowed: ?[]const u8 = null,
    /// Debug (`prediction_checks`): the roots predicted dead since the last
    /// `predictionsSettled`.
    predicted_roots: if (prediction_checks) std.ArrayListUnmanaged(PredictedRoot) else void = if (prediction_checks) std.ArrayListUnmanaged(PredictedRoot).empty else {},
    /// `runFreshTrees` looked at its `fresh_scan_budget` newest items and
    /// found no tree made inside the innermost callback: it looks again once
    /// one is queued, or another callback is the innermost.
    fresh_scan_spent: bool = false,
    /// Totals for tests and diagnostics.
    queued_total: usize = 0,
    freed_total: usize = 0,
    /// Of `freed_total`, the nodes `runFreshTrees` freed inside callbacks.
    freed_in_callbacks: usize = 0,

    /// Nodes a slice frees at most.
    pub const slice_budget: usize = 512;
    /// THE IN-TASK BOUND IN BYTES (lane mem1, follow-up A): past
    /// `max(dying_floor, the live DOM)` of the agent's DOM memory decided dead
    /// and not yet freed (`ExternalMemory.dying` against `.live`), each safe
    /// point frees a slice - the binding exit at depth zero any item, the
    /// binding return into a callback's own script the trees made inside
    /// that callback (`runFreshTrees`) - as cppgc sweeps a slice per
    /// allocation while V8's incremental marking runs inside a long task
    /// (V8 15.7.112.43 src/heap/cppgc/object-allocator.cc ->
    /// Sweeper::SweepForAllocationIfRunning; heap.cc Heap::
    /// IncrementalMarkingLimitReached against Heap::GlobalSizeOfObjects,
    /// which counts the C++ heap). V8 lets a heap grow by at least its
    /// conservative growing step past what it found alive before it collects
    /// again (heap-controller.cc MinimumAllocationLimitGrowingStep: 2 MB in
    /// its low-memory mode, 8 regular): Crane takes the low-memory step,
    /// memory over time (the user's dm3 ruling). Before this only
    /// `high_water` nodes bounded a task, and nothing at all bounded one
    /// inside a callback: 8,000 delete-joins in one timer callback peaked at
    /// 56.6 MB Zig-side against 5.8 MB spread over 80 callbacks.
    pub const dying_floor: usize = 2 * 1024 * 1024;
    /// Items `runFreshTrees` looks at, newest first, per safe point: the
    /// trees a callback dropped are queued last, so its fresh ones are at the
    /// tail; past this many it stops looking until a fresh tree is queued.
    pub const fresh_scan_budget: usize = 64;
    /// Queued nodes past which the safe points that queue items free them.
    pub const high_water: usize = 100_000;
    /// Queued nodes an event loop's turn leaves at most: past it, the turn
    /// frees down to it whatever waits - a bounded pause between tasks - so a
    /// page whose every task makes more garbage than a turn's share never
    /// grows the queue into `high_water`, where it would be freed inside
    /// script again.
    pub const loop_low_water: usize = high_water / 4;

    pub const Books = struct {
        /// Garbage trees queued, and the bytes of the Browser's DOM memory
        /// their queueing summed for them (DeferredTeardown.Dying).
        queued: u64 = 0,
        queued_bytes: u64 = 0,
        /// Trees freed, and their nodes.
        freed_trees: u64 = 0,
        freed_nodes: u64 = 0,
        /// Garbage trees held again before their slice (a raw holder the
        /// counts did not see).
        resurrections: u64 = 0,
        /// Trees a full collection's end of marking predicted dead with the
        /// wrappers it found dead (dom.dying_trees; ExternalMemory.
        /// predictDead), and the bytes that left the figure for them there.
        predicted: u64 = 0,
        predicted_bytes: u64 = 0,
        /// Of `predicted_bytes`, what no queueing had taken once those
        /// wrappers' references were all released, and went back into the
        /// figure (ExternalMemory.settlePredictions): trees predicted dead
        /// that lived - a native reference below a root, which the marks
        /// do not show (lane dm1's design 3.3) - less what trees nobody
        /// predicted took in the same window.
        put_back_bytes: u64 = 0,
        /// The trees predicted dead that were alive once those references
        /// were released, counted root by root: Debug builds only
        /// (`prediction_checks`), 0 elsewhere. The count that says how often
        /// the marks' rule is wrong (the integrator's ruling 2 on the
        /// design).
        mispredicted: u64 = 0,
    };

    /// Whether the queue keeps the roots a collection predicted dead, to
    /// count the mispredictions exactly (`Books.mispredicted`): Debug
    /// builds - unit tests and the bug-finding WPT run.
    pub const prediction_checks = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

    /// A root a collection's end of marking predicted dead (Debug:
    /// `prediction_checks`), until the releases of that collection's dead
    /// wrappers have all run (`predictionsSettled`).
    pub const PredictedRoot = struct {
        instance: *Instance,
        generation: u64,
        /// Whether the root - still the object it was, its teardown not
        /// begun - is alive: not decided dead by the counts. The DOM's.
        lives: *const fn (root: *Instance) bool,
    };

    /// What is owed, one bit each, so the binding exit's check - is
    /// anything owed - is one byte's compare whatever is.
    pub const Owed = packed struct(u8) {
        /// Past `high_water`: free down to it.
        relief: bool = false,
        /// A full collection asked for everything (requestGarbageCollection).
        drain: bool = false,
        /// The agent's DOM memory moved past its report step
        /// (ExternalMemory.due): `report_steps` tell the engine.
        report: bool = false,
        /// The engine's collector found wrappers dead, and their finalizers
        /// wait on the agent's adapter: `finalizer_steps` run them. The one
        /// bit the ADAPTER sets, from inside its engine's collector, by a
        /// store through `owedWord` - the collector calls nothing of the
        /// host's - and clears once it has run every finalizer that waited,
        /// at whichever of its safe points that was.
        finalizers: bool = false,
        /// Some of those finalizers have not been looked at by a callback's
        /// exit yet, or waited there for an outer callback that script is
        /// back in: one of them may be FRESH - its object made by a
        /// script-called constructor since the innermost callback invocation
        /// on the stack began - and so may run at a binding's return into
        /// that callback's script (`runFresh`). Set by the adapter's
        /// collector callback with `finalizers`, and by `leaveCallback`.
        fresh: bool = false,
        _: u3 = 0,

        /// `finalizers` and `fresh`, as the bits of the queue's owed word an
        /// adapter's collector callback sets.
        pub const finalizers_mask: u8 = @bitCast(Owed{ .finalizers = true });
        pub const fresh_mask: u8 = @bitCast(Owed{ .fresh = true });

        pub inline fn any(self: Owed) bool {
            return @as(u8, @bitCast(self)) != 0;
        }
    };

    /// The adapter's steps for `Owed.report`, and their data.
    pub const ReportSteps = struct {
        run: *const fn (data: ?*anyopaque) void,
        data: ?*anyopaque,
    };

    /// The adapter's steps for `Owed.finalizers`, and their data: run every
    /// finalizer that waits. False when they could not run here - the
    /// returning binding left an exception pending, which engine work would
    /// clear, or a finalizer is already on the stack - and still wait: the
    /// queue owes them to the next exit.
    pub const FinalizerSteps = struct {
        run: *const fn (data: ?*anyopaque) bool,
        /// Run the FRESH ones only (`runFresh`): those whose object was made
        /// at or after `innermost` on the callback clock (a script-called
        /// constructor's stamp, or what `freshSerialOf` answers for its
        /// slab generation). One made at or after `outermost` but before
        /// `innermost` waits where it is; anything else waits for depth
        /// zero. Answers whether it could run here (as `run`) and the newest
        /// stamp it left waiting.
        run_fresh: *const fn (data: ?*anyopaque, innermost: u32, outermost: u32) Fresh,
        data: ?*anyopaque,

        pub const Fresh = struct {
            done: bool,
            waiting: u32,
        };
    };

    /// THE CALLBACK CLOCK. A tick for every native-to-script callback
    /// invocation of the agent (`enterCallback`: the adapter's
    /// invokeCallbackFunction, constructCallbackFunction and
    /// callUserObjectOperation), and the invocations on the stack now.
    ///
    /// Script inside a callback runs with the algorithm that called it on the
    /// stack, so its bindings never return at depth zero and nothing the
    /// queue owes runs there - and most of a page's script runs inside
    /// callbacks. ONE thing may: the finalizer of an object that did not
    /// exist when the innermost callback began. Every DOM algorithm on the
    /// stack has been suspended in its call into script since before such an
    /// object was made, so none holds a pointer to it; a pointer some
    /// binding stored in a longer-lived structure since is the question it
    /// already is at depth zero. The adapter stamps the objects its
    /// script-called constructors make with the clock (`freshStamp`), any
    /// other object earns a stamp from its slab generation against the
    /// invocations' entries (`freshSerialOf`), and a stamp at or after the
    /// innermost callback's beginning is FRESH.
    pub const Callbacks = struct {
        /// The clock: the callback invocations that have begun. It stops at
        /// its last value rather than wrap, and nothing is stamped from then
        /// on (`freshStamp`) - an old stamp must never compare as new.
        serial: u32 = 0,
        /// The innermost invocation on the stack: the clock when it began,
        /// and `algorithm_depth` with it counted. 0 and 0: none.
        active: u32 = 0,
        depth: u32 = 0,
        /// The outermost invocation's clock: nothing stamped before it can
        /// be fresh until the stack is empty again. 0: none.
        outermost: u32 = 0,
        /// The newest stamp a fresh run left waiting for an outer callback
        /// (made inside the callbacks on the stack, before the innermost
        /// began); 0: none. `leaveCallback` owes a fresh run again when the
        /// callback script returns into is at or before it.
        waiting: u32 = 0,
        /// The innermost invocation's entry generation: its Browser slab's
        /// next generation when it began (SlabAllocator.generationNow, read
        /// by the adapter at the invocation). An object whose slab
        /// generation is at or above it was made inside that invocation,
        /// after every native frame below it was suspended - the fresh
        /// rule's test for trees (`runFreshTrees`). 0: none known, and
        /// nothing is fresh.
        entry_generation: u64 = 0,
        /// The slab `entry_generation` was read from: generations of two
        /// slabs do not compare, so an object another slab issued is OLD.
        entry_slab: ?*const SlabAllocator = null,
        /// The outermost invocation's entry (with `outermost`): an object
        /// made after it began but before the innermost did waits for the
        /// outer callback's script (`freshSerialOf`).
        outermost_entry: Entry = .{},
    };

    /// The invocation `enterCallback` found innermost, for `leaveCallback`.
    pub const OuterCallback = struct {
        active: u32,
        depth: u32,
        entry: Entry = .{},
    };

    /// Where a callback invocation began in its Browser's allocation order
    /// (`Callbacks.entry_generation`, `entry_slab`); the default knows
    /// nothing, and nothing is fresh against it.
    pub const Entry = struct {
        slab: ?*const SlabAllocator = null,
        generation: u64 = 0,
    };

    /// The byte an adapter's collector callback sets `Owed.finalizers_mask`
    /// in, valid while the queue lives. The adapter registers it with its
    /// engine while its agent lives and withdraws it at the agent's end.
    pub fn owedWord(self: *DeferredTeardown) *u8 {
        return @ptrCast(&self.owed);
    }

    /// A collection's end of marking predicted the tree of `root` dead
    /// (dom.dying_trees): kept, in Debug builds, until that collection's
    /// releases have run (`predictionsSettled`). Called inside the
    /// collection's pause; allocates from the queue's allocator, never the
    /// engine's heaps. Out of memory: the root is not kept, and the exact
    /// count misses it.
    pub fn notePredicted(self: *DeferredTeardown, root: PredictedRoot) void {
        if (!prediction_checks) return;
        self.predicted_roots.append(self.allocator, root) catch {};
    }

    /// The references of the wrappers a collection found dead are all
    /// released (ExternalMemory.settlePredictions): `put_back` bytes of what
    /// its end of marking predicted dead went back into the figure. In
    /// Debug builds each root kept by `notePredicted` is looked at: one
    /// that is still the same object, not being torn down and alive by the
    /// counts was predicted dead and lived.
    fn predictionsSettled(self: *DeferredTeardown, put_back: usize) void {
        self.books.put_back_bytes += put_back;
        if (!prediction_checks) return;
        const instance_lifecycle = @import("instance_lifecycle.zig");
        for (self.predicted_roots.items) |root| {
            if (SlabAllocator.generationOf(root.instance) != root.generation) continue;
            if (instance_lifecycle.isCleanupStarted(root.instance)) continue;
            if (root.lives(root.instance)) self.books.mispredicted += 1;
        }
        // A burst's capacity is not kept for the agent's life.
        if (self.predicted_roots.capacity > 4096) self.predicted_roots.clearAndFree(self.allocator) else self.predicted_roots.clearRetainingCapacity();
    }

    /// The agent's DOM memory is due to be reported (ExternalMemory, where
    /// its figure moves): the next safe point runs `report_steps`.
    pub fn oweReport(self: *DeferredTeardown) void {
        self.owed.report = true;
    }

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
        /// What the object's tree holds of a Browser's DOM memory, decided
        /// dead by this push (`Dying`); null: nothing of it is counted there.
        dying: ?Dying = null,
        /// The lowest slab generation in the object's tree
        /// (dom.tree_teardown.Measure.min_generation): the tree was made
        /// after any callback that began at a lower generation, and may be
        /// freed at that callback's safe points (`runFreshTrees`). 0, the
        /// default, is unknown, and unknown is OLD.
        min_generation: u64 = 0,
    };

    /// The bytes a queued tree holds of a Browser's DOM memory, and that
    /// memory (the one its nodes were counted in, which outlives the queue's
    /// items: a BrowserScope's). The tree is decided dead where it is queued,
    /// so its bytes leave the figure the engine is told THERE
    /// (ExternalMemory.decideDead) and not when its slices free them: an
    /// engine sets its next collection threshold from what it believes is
    /// alive, and a tree that waits for its slices is not (lane dm1's design,
    /// tmp/plans/dom-memory-figure-design.md 3.1 and 3.2 A). From the push on
    /// the queue owns them: the frees its steps make pay them down
    /// (`runSteps`), and whatever is left when the item leaves the queue -
    /// its tree freed with less than was summed, held again, forgotten with
    /// its owner - goes back into the figure (`finish`).
    pub const Dying = struct {
        memory: *ExternalMemory,
        bytes: usize,
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
        /// The nodes it stands for, as the memory bound counts them: the
        /// request's weight, clamped to what 32 bits hold (the bound itself
        /// is 100,000).
        weight: u32,
        /// The part of `weight` already taken off `pending`.
        accounted: u32 = 0,
        position: Position = .{},
        /// What is left, in the queue's DOM memory (`DeferredTeardown.memory`),
        /// of the bytes this item's push decided dead (`Dying`); 0: none.
        ///
        /// The item is 88 bytes, as it was before it carried this (two
        /// 32-bit counts where two words were; the memory is the queue's,
        /// not each item's). A script that drops elements one by one queues
        /// an item an element, up to 100,000 at once, so an item's size is
        /// paid 100,000 times: batch A's first form was 104 bytes
        /// (tests/runtime/dm2_dying_figure_test.zig pins the size).
        dying: usize = 0,
        /// The request's `min_generation` (0: OLD). 8 bytes more an item -
        /// 88 to 96, at most 800 KB at 100,000 queued items - for the fresh
        /// rule, which frees a long callback's own garbage inside it (lane
        /// mem1): the item had no padding to hold it.
        min_generation: u64 = 0,
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
        if (prediction_checks) self.predicted_roots.deinit(self.allocator);
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
            .weight = std.math.cast(u32, request.weight) orelse std.math.maxInt(u32),
            .min_generation = request.min_generation,
        };
        if (request.dying) |dying| {
            if (self.memory == null) self.memory = dying.memory;
            if (self.memory == dying.memory) item.dying = dying.memory.decideDead(dying.bytes);
        }
        self.pushBack(item);
        self.pending += item.weight;
        self.queued_total += 1;
        // The memory bounds: past one, the next safe points free down to it.
        if (self.isFresh(item)) self.fresh_scan_spent = false;
        if (!self.owed.drain and self.overBound()) self.owed.relief = true;
        return true;
    }

    /// A DOM algorithm begins on the agent's stack (the adapter's binding
    /// entries and callback invocations; `algorithm_depth`).
    pub fn enterAlgorithm(self: *DeferredTeardown) void {
        self.algorithm_depth += 1;
    }

    /// A binding returns to script: the outermost one runs what is owed;
    /// one that returns into a callback's own script - no binding between
    /// it and the callback invocation - runs the fresh finalizers, and
    /// nothing else. With nothing owed it is the one check it always was,
    /// and that check is all a binding's exit carries: inline, the rest out
    /// of line (`leaveOwing`). (Left to the optimizer, this was a call from
    /// every binding exit into a function that had `runOwed` inlined in it -
    /// and paid its prologue with nothing owed; measured, lane v8up b6c.)
    pub inline fn leaveAlgorithmToScript(self: *DeferredTeardown) void {
        self.algorithm_depth -|= 1;
        if (self.owed.any()) self.leaveOwing();
    }

    /// `leaveAlgorithmToScript` with something owed.
    noinline fn leaveOwing(self: *DeferredTeardown) void {
        if (self.algorithm_depth == 0) {
            self.runOwed();
        } else if (self.algorithm_depth == self.callback.depth) {
            if (self.owed.fresh) self.runFresh();
            if (self.owed.relief) self.runFreshTrees();
        }
    }

    /// A callback returns to the native algorithm that invoked it: nothing
    /// runs here, whatever is owed.
    pub fn leaveAlgorithmToNative(self: *DeferredTeardown) void {
        self.algorithm_depth -|= 1;
    }

    /// A native algorithm calls script (`enterAlgorithm` for a callback
    /// invocation): the clock ticks, and this invocation is the innermost.
    pub fn enterCallback(self: *DeferredTeardown, entry: Entry) OuterCallback {
        self.algorithm_depth += 1;
        const outer: OuterCallback = .{
            .active = self.callback.active,
            .depth = self.callback.depth,
            .entry = .{ .slab = self.callback.entry_slab, .generation = self.callback.entry_generation },
        };
        self.callback.entry_generation = entry.generation;
        self.callback.entry_slab = entry.slab;
        if (outer.active == 0) self.callback.outermost_entry = entry;
        self.fresh_scan_spent = false;
        if (self.callback.serial != std.math.maxInt(u32)) self.callback.serial += 1;
        self.callback.active = self.callback.serial;
        self.callback.depth = self.algorithm_depth;
        if (outer.active == 0) self.callback.outermost = self.callback.active;
        return outer;
    }

    /// The callback returns to the native algorithm that invoked it
    /// (`leaveAlgorithmToNative`): nothing runs here. Script may be back in
    /// the callback below, where a finalizer that waited for it is fresh:
    /// the next binding exit there looks.
    pub fn leaveCallback(self: *DeferredTeardown, outer: OuterCallback) void {
        self.algorithm_depth -|= 1;
        self.callback.active = outer.active;
        self.callback.depth = outer.depth;
        // What the inner callback made was made inside this one too: a tree
        // fresh for it is fresh here (a lower entry generation, at or below).
        self.callback.entry_generation = outer.entry.generation;
        self.callback.entry_slab = outer.entry.slab;
        self.fresh_scan_spent = false;
        if (outer.active == 0) {
            // No callback is on the stack: what waited runs with everything
            // else, at depth zero or the pump.
            self.callback.outermost = 0;
            self.callback.waiting = 0;
            self.callback.outermost_entry = .{};
        } else if (self.callback.waiting >= outer.active) {
            self.owed.fresh = true;
        }
    }

    /// The stamp of an object a script-called constructor has just made
    /// (the adapter's constructor trampoline, once the instance it created
    /// is wrapped): the clock, inside a callback; 0 - never fresh - outside
    /// one, where depth zero finalizes, and once the clock has stopped.
    /// A callback that began while the constructor ran (one it invoked) has
    /// ended by now, so the clock is at or past the beginning of every
    /// callback still on the stack, and before that of any to come.
    pub inline fn freshStamp(self: *const DeferredTeardown) u32 {
        if (self.callback.active == 0 or self.callback.serial == std.math.maxInt(u32)) return 0;
        return self.callback.serial;
    }

    /// Whether a DOM algorithm is on the agent's stack.
    pub fn inAlgorithm(self: *const DeferredTeardown) bool {
        return self.algorithm_depth != 0;
    }

    /// A full collection asked for every item (requestGarbageCollection):
    /// true when a DOM algorithm is on the stack, and the drain is owed to
    /// the outermost binding exit instead - the caller then drains nothing.
    pub fn oweDrainIfInAlgorithm(self: *DeferredTeardown) bool {
        if (self.algorithm_depth == 0) return false;
        self.owed.drain = true;
        return true;
    }

    /// What is owed, at a safe point (depth zero, back in script).
    fn runOwed(self: *DeferredTeardown) void {
        if (self.slicing) return;
        // The collector's finalizers first: what they let go of - a tree's
        // last reference, an object's native state - is what the frees below
        // free and what the report tells the engine about.
        if (self.owed.finalizers) self.runFinalizers();
        const owed = self.owed;
        // Finalizers that still wait stay owed.
        self.owed = .{ .finalizers = owed.finalizers, .fresh = owed.fresh };
        if (owed.drain) {
            self.drainAll();
        } else if (owed.relief) {
            // Past high_water, down to it at once (a tree weighs up to the
            // bound); past the byte bound, a slice a safe point.
            if (self.pending > high_water) {
                _ = self.runSlice(self.pending - high_water + slice_budget);
            } else if (self.overDyingBound()) {
                _ = self.runSlice(slice_budget);
                // Still past it: the next safe point frees another slice.
                if (self.overBound()) self.owed.relief = true;
            }
        }
        // After the frees: the figure the engine is told is what they left.
        if (owed.report) if (self.report_steps) |steps| steps.run(steps.data);
    }

    /// The safe point for the finalizers of the wrappers the engine's
    /// collector found dead (`Owed.finalizers`, `finalizer_steps`): a script
    /// that makes and drops objects in one task reaches no other - the
    /// engine's collector may not run them (V8 15.7 runs its weak callbacks
    /// under DisallowJSObjectModification), and the event loop's pump is a task
    /// away, each dead wrapper keeping its native state until then. Blink
    /// releases a dead wrappable's native state the same way, inside the
    /// running script: a wrappable is a cppgc object (blink ScriptWrappable :
    /// v8::Object::Wrappable : cppgc::GarbageCollected), its destructor is
    /// its finalizer, and cppgc sweeps lazily on allocation ("Lazily sweep
    /// pages of this heap", V8 15.7.112.43 src/heap/cppgc-internal/
    /// object-allocator.cc ObjectAllocator::TryRefillLinearAllocationBuffer
    /// -> Sweeper::SweepForAllocationIfRunning -> HeapObjectHeader::Finalize).
    ///
    /// Only here: at depth zero, from the outermost binding exit - no DOM
    /// algorithm is below a finalizer it runs.
    fn runFinalizers(self: *DeferredTeardown) void {
        std.debug.assert(self.algorithm_depth == 0);
        self.owed.finalizers = false;
        const steps = self.finalizer_steps orelse return;
        if (!steps.run(steps.data)) self.owed.finalizers = true;
    }

    /// The safe point INSIDE A CALLBACK: a binding returned into the script
    /// of the innermost callback invocation, with no other DOM algorithm
    /// between the two (a binding whose conversion ran that script would be
    /// one, and then nothing runs). Only the fresh finalizers run
    /// (`Callbacks`); the rest of what the queue owes - every other
    /// finalizer, the trees, the relief, the report - waits for depth zero.
    fn runFresh(self: *DeferredTeardown) void {
        std.debug.assert(self.algorithm_depth != 0 and self.algorithm_depth == self.callback.depth);
        self.owed.fresh = false;
        const steps = self.finalizer_steps orelse return;
        const result = steps.run_fresh(steps.data, self.callback.active, self.callback.outermost);
        // Not here (as `runFinalizers`): nothing was looked at, and the next
        // exit of this callback looks again.
        if (result.done) self.callback.waiting = result.waiting else self.owed.fresh = true;
    }

    /// Past a memory bound: `high_water` queued nodes, or the byte bound.
    fn overBound(self: *const DeferredTeardown) bool {
        return self.pending > high_water or self.overDyingBound();
    }

    /// Past the byte bound (`dying_floor`): more of the agent's DOM memory
    /// decided dead and not yet freed than `max(dying_floor, live)`.
    fn overDyingBound(self: *const DeferredTeardown) bool {
        const memory = self.memory orelse return false;
        return memory.dying > @max(dying_floor, memory.live);
    }

    /// Whether `item`'s whole tree was made inside the innermost callback on
    /// the stack: its lowest slab generation at or above that callback's
    /// entry generation. The ALLOWLIST: an item whose tree no walk vouched
    /// for (`min_generation` 0), and every item while no callback - or no
    /// entry generation - is known, is OLD.
    pub fn isFresh(self: *const DeferredTeardown, item: *const Item) bool {
        const entry = self.callback.entry_generation;
        const slab = self.callback.entry_slab orelse return false;
        if (self.callback.active == 0 or entry == 0) return false;
        if (item.min_generation == 0 or item.min_generation < entry) return false;
        // Issued by the slab the entry was read from (its address says).
        return SlabAllocator.ownerOf(item.instance) == slab;
    }

    /// The callback clock's stamp an object deserves by the fresh rule,
    /// whatever made it (lane mem1, follow-up A): `slab` issued it at
    /// `generation`. The innermost invocation's serial when that generation
    /// is at or above the invocation's entry - made inside it, after every
    /// native frame below it was suspended, so its finalizer may run at a
    /// binding's return into that callback's script; the OUTERMOST
    /// invocation's when it was made after the outermost began but before
    /// the innermost did - it waits, at least until script is back in the
    /// outermost callback (conservative: the invocations between keep no
    /// entry here, so one made inside a middle callback is not owed a look
    /// when an inner one returns into it; it runs when a later first pass
    /// owes one, or back in the outermost); 0 - never fresh, depth zero
    /// finalizes it - otherwise: made before every callback on the stack,
    /// generation unknown (`dead_generation`), another slab's (generations
    /// of two slabs do not compare), no callback on the stack, or once the
    /// clock has stopped (`freshStamp`: the invocations then share its last
    /// value, and an outermost serial would compare as innermost). The
    /// ALLOWLIST: fresh is proven by the two numbers, never assumed.
    ///
    /// The constructor stamp (`freshStamp`) knew only the objects a
    /// script-called constructor made; a factory method's (createRange)
    /// and the DOM's own (the Ranges and InputEvents editing makes) were
    /// never fresh and waited for depth zero - 56,000 Ranges after 8,000
    /// delete-joins in one timer callback. What a fresh finalizer releases
    /// is no wider for it: a `new Range()` was already fresh, and released
    /// its references to old nodes at the callback's binding exit.
    pub fn freshSerialOf(self: *const DeferredTeardown, slab: *const SlabAllocator, generation: u64) u32 {
        if (self.callback.active == 0 or self.callback.serial == std.math.maxInt(u32)) return 0;
        if (generation == SlabAllocator.dead_generation) return 0;
        if (self.callback.entry_slab == slab and self.callback.entry_generation != 0 and generation >= self.callback.entry_generation) return self.callback.active;
        const outermost = self.callback.outermost_entry;
        if (outermost.slab == slab and outermost.generation != 0 and generation >= outermost.generation) return self.callback.outermost;
        return 0;
    }

    /// THE SAFE POINT INSIDE A CALLBACK, for trees (lane mem1, follow-up
    /// A): a binding returned into the innermost callback's own script and
    /// a memory bound is passed. The frames below that callback - the
    /// native algorithm that invoked it, and everything under that - were
    /// suspended when it began, before any object made inside it existed,
    /// so none of them holds such an object: the argument by which the
    /// queue already runs that callback's FRESH finalizers here
    /// (`runFresh`). A garbage tree every node of which was made inside the
    /// callback (`isFresh`) is therefore freed here, a slice at a time -
    /// newest first, at most `fresh_scan_budget` items looked at per safe
    /// point - and every other item waits for depth zero or the event loop,
    /// as before. A pointer some binding stored in a longer-lived structure
    /// is the question it already is at depth zero. What the frees here let
    /// go of is queued, never freed inline (a teardown during this slice
    /// pushes; the slice does not chase it).
    fn runFreshTrees(self: *DeferredTeardown) void {
        if (self.slicing) return;
        std.debug.assert(self.algorithm_depth != 0 and self.algorithm_depth == self.callback.depth);
        if (!self.overBound()) {
            self.owed.relief = false;
            return;
        }
        if (self.fresh_scan_spent) return;
        self.slicing = true;
        defer self.slicing = false;
        var freed: usize = 0;
        while (freed < slice_budget) {
            // Newest first, looking again from the tail each time: a teardown
            // may unlink or free any item, so no pointer is kept across one.
            var at = self.tail;
            var looked: usize = 0;
            const found: ?*Item = while (at) |item| : (at = item.prev) {
                if (looked == fresh_scan_budget) break null;
                looked += 1;
                if (self.isFresh(item)) break item;
            } else null;
            const item = found orelse {
                if (freed == 0) self.fresh_scan_spent = true;
                break;
            };
            self.unlink(item);
            const progress = self.runSteps(item, slice_budget - freed);
            self.account(item, progress.freed);
            freed += @max(progress.freed, 1);
            if (progress.done) self.finish(item) else self.pushBack(item);
        }
        self.freed_in_callbacks += freed;
        if (!self.overBound()) self.owed.relief = false;
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
            const progress = self.runSteps(item, budget - freed);
            self.account(item, progress.freed);
            // An item that freed nothing and is not done would hold the
            // queue: count it as one, so the slice still ends.
            freed += @max(progress.freed, 1);
            if (progress.done) self.finish(item) else self.pushFront(item);
        }
        if (self.owed.relief and !self.overBound()) self.owed.relief = false;
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
        self.owed.relief = false;
        self.owed.drain = false;
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
        // A DOM algorithm on the stack: owed to its outermost exit.
        if (self.algorithm_depth != 0) {
            if (!self.owed.drain) self.owed.relief = true;
            return;
        }
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
                    const progress = self.runSteps(item, std.math.maxInt(usize));
                    self.account(item, progress.freed);
                    if (progress.done) break;
                }
                self.finish(item);
            }
        }
    }

    fn account(self: *DeferredTeardown, item: *Item, freed: usize) void {
        self.freed_total += freed;
        const take: u32 = @intCast(@min(freed, item.weight - item.accounted));
        item.accounted += take;
        self.pending -|= take;
    }

    /// The item is done: what is left of its weight comes off `pending`,
    /// and what is left of its dying bytes goes back into its DOM memory's
    /// figure - they are not dying any more, whichever way the item ended:
    /// its tree was freed and held less than was summed, it is held again
    /// (a resurrection), or it goes with its owner's pools, whose frees are
    /// not this item's.
    fn finish(self: *DeferredTeardown, item: *Item) void {
        self.pending -|= item.weight - item.accounted;
        if (item.dying != 0) if (self.memory) |memory| memory.rescue(item.dying);
        self.allocator.destroy(item);
    }

    /// One run of `item`'s steps. While they run, what they free of the
    /// item's DOM memory pays the item's dying bytes down first
    /// (ExternalMemory.beginTeardown): those bytes left the figure when the
    /// item was queued, and a free must not take them out of it twice. A
    /// teardown that runs another item's steps (a realm that ends inside it
    /// drains its own) nests: each run pays its own item - nothing, for an
    /// item whose push decided no bytes dead - and the outer one's rest is
    /// put back when the inner returns.
    fn runSteps(self: *DeferredTeardown, item: *Item, budget: usize) Progress {
        const memory = self.memory orelse return item.steps.run(item, budget);
        const outer = memory.beginTeardown(item.dying);
        const progress = item.steps.run(item, budget);
        item.dying = memory.endTeardown(outer);
        return progress;
    }

    /// The object queued as `instance` at `generation` with `steps` is held
    /// again before its teardown (a resurrection, dom.refcount_teardown.
    /// resurrect): its item, if one waits, leaves the queue now - its weight
    /// comes off the memory bound and its dying bytes go back into the
    /// figure at once, so a tree that is queued again later is counted
    /// once. Whether one was found: the item a slice has in hand is not in
    /// the queue, and that slice's own re-check drops it. A walk of the
    /// queue, for a path that is an anomaly (a holder the counts did not
    /// see).
    pub fn withdraw(self: *DeferredTeardown, instance: *const Instance, generation: u64, steps: *const Steps) bool {
        var at = self.head;
        while (at) |item| : (at = item.next) {
            if (item.instance != instance or item.generation != generation or item.steps != steps) continue;
            self.unlink(item);
            self.finish(item);
            return true;
        }
        return false;
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

/// Native memory that a host's objects keep alive beside an agent's engine
/// heap, which the engine's collector cannot see: a Browser's DOM - every
/// node's slab slot, state block and NodeBase (runtime.BrowserScope.
/// dom_memory, counted by dom.instance_bridge as nodes are made and freed),
/// its rare data, its text in a block of its own and its attribute values'
/// records (`blockBytes`).
///
/// The engine collects when ITS heap grows. A wrapper is a few dozen bytes
/// of it and keeps a whole native tree alive (a dropped cloneNode(true) of
/// 840 nodes is ~2.5 MB native and 200 bytes of engine heap), so a script
/// that makes and drops trees ran no collection at all and kept every one
/// (lane perf1: 650 clones, 548,150 nodes, 1.7 GB). The host keeps `live`;
/// the agent's adapter tells its collector how it changed
/// (engine.AgentOptions.external_memory) at its safe points, in steps of
/// `report_step`. Blink did the same before its DOM moved into the
/// collector's heap: V8GCController::reportDOMMemoryUsageToV8 passed the
/// change of the DOM partition's size to Isolate::
/// AdjustAmountOfExternalAllocatedMemory after every task (Chromium 45,
/// Source/bindings/core/v8/V8GCController.cpp); since its unified heap V8
/// counts the DOM's bytes itself (CppHeap's allocated size, against V8's
/// global limit).
///
/// One per Browser, written and read only on its window agent's thread: a
/// node is made and freed on the thread of its window agent (workers have no
/// nodes), and only the window agent is given it. Debug builds check the
/// thread once an agent has claimed it (`claim`).
pub const ExternalMemory = struct {
    /// Bytes alive now: everything counted and not yet freed (`held`) less
    /// the trees decided dead (`dying`). THE FIGURE: what the agent's
    /// adapter tells its engine.
    live: usize = 0,
    /// Of what is counted and not yet freed, the bytes of the trees decided
    /// dead: queued on the agent's deferred teardown queue, where each
    /// waits for its slices (DeferredTeardown.Dying). They leave `live` at
    /// the queueing and come off here as the tree's nodes are freed - or go
    /// back into `live` when the tree is held again. A counter that fell
    /// only at the free told the engine the dead were alive, and V8 set
    /// each next limit from it: 11.7 -> 54.8 -> 104.8 -> 162.1 -> 206.9 MB
    /// over four collections with 23 to 39 MB alive (lane dm1,
    /// tmp/plans/dom-memory-figure-design.md 0). Both browsers give their
    /// collector survivors only: Blink's nodes are on V8's C++ heap, whose
    /// MARKED bytes V8 reads (Chromium 157.0.8103.50 core/dom/node.h:165;
    /// V8 15.7.112.43 src/heap/cppgc-js/cpp-heap.cc:1016), and a full
    /// collection of JavaScriptCore zeroes its extra-memory sum and adds
    /// only what each visited wrapper keeps (WebKit 621b33b3b71
    /// Source/JavaScriptCore/heap/Heap.cpp:1811-1817, :2254-2270).
    dying: usize = 0,
    /// Of `dying`, the bytes of the trees a full collection's end of marking
    /// PREDICTED dead (`predictDead`), which no queueing has taken yet: the
    /// collector found their wrappers dead, and those wrappers' references
    /// are released at the agent's next safe point, where the counts queue
    /// each tree (`decideDead` takes its bytes from here first, so a tree
    /// is never taken out of the figure twice). What is left when those
    /// releases have all run was predicted dead and lived: it goes back
    /// into the figure (`settlePredictions`). The pool is bytes, not trees:
    /// `dying` is always the queued items' shares plus this.
    ///
    /// Why predict at all: the engine computes its next threshold when the
    /// collection ends, before any release runs - and a threshold computed
    /// with this collection's dead in it ratchets (V8's limits on the
    /// parser page: 105.7 MB after the first collection with 47 MB alive;
    /// lane dm1, tmp/plans/dom-memory-figure-design.md 2.1 and 3.2 B).
    predicted: usize = 0,
    /// While a queued tree's teardown steps run (`beginTeardown`): what is
    /// left of THAT tree's share of `dying`, which a free pays down first.
    /// 0 outside one.
    paying: usize = 0,
    /// `live` has left the window around what the engine was last told
    /// (`low`..`high`, `report_step` either side): the adapter's next safe
    /// point tells it. Set here, where the figure moves - once per node made
    /// or freed - and owed on the agent's queue (`queue`), so the binding exit
    /// back into script pays nothing for it: its one check of what the queue
    /// owes covers this too (DeferredTeardown.Owed.report).
    due: bool = false,
    /// The queue of the agent that claimed it, whose safe points report it.
    queue: ?*DeferredTeardown = null,
    low: usize = 0,
    high: usize = report_step,
    /// The thread of the agent it was given to (Debug only; `claim`): every
    /// later change must come from it. Null while no agent has it - a
    /// Browser-less scope's nodes (unit tests) are counted unchecked.
    thread: if (debug_checks) ?std.Thread.Id else void = if (debug_checks) null else {},

    const debug_checks = @import("builtin").mode == std.builtin.OptimizeMode.Debug;

    /// The change an adapter waits for before it tells its engine: 128 KB,
    /// V8's own step - it re-checks its external memory limits every
    /// kExternalAllocationLimitForInterrupt (128 KB) of growth (V8 13.1
    /// src/heap/heap.h, ExternalMemoryAccounting), and cppgc reports the
    /// unified heap's allocations to it every kIncrementalMarkingCheckInterval
    /// (128 KB; src/heap/cppgc-js/cpp-heap.cc). A smaller step would only
    /// cost calls; a larger one would let the engine see the growth late.
    pub const report_step: usize = 128 * 1024;

    /// What a block of `bytes` from a Browser's general allocator is counted
    /// as: its bytes to the next multiple of 16, malloc's granule - macOS's
    /// nano and tiny zones hand out multiples of 16 bytes, and a glibc chunk
    /// is its request plus an 8-byte header to the next multiple of 16 (at
    /// least 32). A floor on both: the figure never says more than is held.
    /// A node's text block and an attribute value's record are counted so
    /// (dom.character_data, dom.attribute_values; lane vm1) - each added
    /// when its block is made and subtracted, the same amount, when it is
    /// freed.
    pub fn blockBytes(bytes: usize) usize {
        return (bytes + 15) & ~@as(usize, 15);
    }

    /// An agent takes it, on its own thread (the adapter's createAgent),
    /// with the queue whose safe points report it (null: its microtask
    /// checkpoints only): its engine has been told nothing yet.
    pub fn claim(self: *ExternalMemory, queue: ?*DeferredTeardown) void {
        if (debug_checks) self.thread = std.Thread.getCurrentId();
        self.queue = queue;
        self.low = 0;
        self.high = report_step;
        self.due = false;
        if (self.live > self.high) self.becomeDue();
    }

    /// The agent ended: it no longer has it. What a collection predicted
    /// dead and no queueing took is back in the figure: no release of that
    /// agent's is still to come.
    pub fn release(self: *ExternalMemory) void {
        _ = self.settlePredictions();
        if (debug_checks) self.thread = null;
        self.queue = null;
        self.due = false;
    }

    pub fn add(self: *ExternalMemory, bytes: usize) void {
        self.checkThread();
        self.live += bytes;
        if (!self.due and self.live > self.high) self.becomeDue();
    }

    pub fn sub(self: *ExternalMemory, bytes: usize) void {
        self.checkThread();
        // A free inside a queued tree's teardown, or one of more than the
        // figure holds: out of line, so every other free pays one compare
        // for them.
        if (self.paying != 0 or bytes > self.live) return self.subDying(bytes);
        self.live -= bytes;
        if (!self.due and self.live < self.low) self.becomeDue();
    }

    /// `sub` while a queued tree's teardown runs: the bytes freed come off
    /// that tree's share of `dying` first - they left `live` when the tree
    /// was queued - and only what is freed beyond it (what the queueing's
    /// walk did not sum) comes off `live`.
    ///
    /// And `sub` of more than `live` holds. Such a free is of bytes that
    /// already left the figure and that no running teardown pays for: a
    /// tree predicted dead (`predicted`) that a forced teardown - its
    /// realm's end - frees before its wrappers' references are released.
    /// What `live` cannot give comes off that pool, so `settlePredictions`
    /// does not put back bytes that are freed. Past the pool too, `live`
    /// stops at zero, as it always did.
    noinline fn subDying(self: *ExternalMemory, bytes: usize) void {
        const paid = @min(bytes, self.paying);
        std.debug.assert(self.dying >= paid);
        self.paying -= paid;
        self.dying -|= paid;
        if (paid == bytes) return;
        const rest = bytes - paid;
        if (rest > self.live) {
            const freed_predicted = @min(rest - self.live, self.predicted);
            self.predicted -= freed_predicted;
            self.dying -|= freed_predicted;
            self.live = 0;
        } else self.live -= rest;
        if (!self.due and self.live < self.low) self.becomeDue();
    }

    /// Everything counted and not yet freed: the counter the figure was
    /// before it knew which trees are dead (tests, diagnostics).
    pub fn held(self: *const ExternalMemory) usize {
        return self.live + self.dying;
    }

    /// A tree that holds `bytes` of what is counted is decided dead (queued
    /// for its sliced free): they leave the figure now. Returns what moved
    /// into `dying` - `bytes`, or all of `live` when the sum was more than
    /// is counted - which the queue keeps for the tree
    /// (DeferredTeardown.Item.dying). The engine hears it at the agent's
    /// next safe point, as a decrease.
    ///
    /// A tree a collection's end of marking predicted dead left the figure
    /// there (`predictDead`): its queueing takes its bytes from that pool
    /// first, and only the rest from `live`.
    pub fn decideDead(self: *ExternalMemory, bytes: usize) usize {
        self.checkThread();
        const taken = @min(bytes, self.predicted);
        self.predicted -= taken;
        const moved = @min(bytes - taken, self.live);
        self.live -= moved;
        self.dying += moved;
        if (!self.due and self.live < self.low) self.becomeDue();
        return taken + moved;
    }

    /// A full collection's end of marking found `trees` trees, holding
    /// `bytes` of what is counted, dead with the wrappers it found dead
    /// (runtime.lifetime's `dyingWith`; dom.dying_trees): they leave the
    /// figure now, inside the collection, and wait in `predicted` for the
    /// queueings that follow those wrappers' releases. Returns what moved -
    /// `bytes`, or all of `live` when the sum was more than is counted.
    /// Owes no report: the adapter that asked tells its engine in the same
    /// pause, as a decrease (engine.capabilities.
    /// external_memory_at_collection), and `markReported` then.
    pub fn predictDead(self: *ExternalMemory, bytes: usize, trees: usize) usize {
        self.checkThread();
        const moved = @min(bytes, self.live);
        self.live -= moved;
        self.dying += moved;
        self.predicted += moved;
        if (self.queue) |queue| {
            queue.books.predicted += trees;
            queue.books.predicted_bytes += moved;
        }
        return moved;
    }

    /// The references of every wrapper a collection found dead are released
    /// (the adapter's drain emptied its list; or the agent ended): each
    /// tree that died with them has been queued and took its bytes out of
    /// `predicted`. What is left there was predicted dead and lived, and is
    /// back in the figure; returns it. The engine hears of it at the next
    /// report, as growth.
    pub fn settlePredictions(self: *ExternalMemory) usize {
        const left = self.predicted;
        if (self.queue) |queue| queue.predictionsSettled(left);
        if (left == 0) return 0;
        self.predicted = 0;
        self.rescue(left);
        return left;
    }

    /// `bytes` of `dying` are not dying any more and were not freed: the
    /// tree they were decided dead with is held again, or its item left the
    /// queue with a rest. They are back in the figure.
    pub fn rescue(self: *ExternalMemory, bytes: usize) void {
        if (bytes == 0) return;
        self.checkThread();
        std.debug.assert(self.dying >= bytes);
        const moved = @min(bytes, self.dying);
        self.dying -= moved;
        self.live += moved;
        if (!self.due and self.live > self.high) self.becomeDue();
    }

    /// A queued tree's teardown steps begin: frees pay `dying` - what is
    /// left of the tree's share - down first, until `endTeardown`. Returns
    /// the share of the teardown this one runs inside (0: none), for
    /// `endTeardown`.
    pub fn beginTeardown(self: *ExternalMemory, dying: usize) usize {
        const outer = self.paying;
        self.paying = dying;
        return outer;
    }

    /// The steps returned: what is left of the tree's share, which its item
    /// keeps for its next slice; the teardown it ran inside pays `outer`
    /// again.
    pub fn endTeardown(self: *ExternalMemory, outer: usize) usize {
        const left = self.paying;
        self.paying = outer;
        return left;
    }

    fn becomeDue(self: *ExternalMemory) void {
        self.due = true;
        if (self.queue) |queue| queue.oweReport();
    }

    /// The adapter told its engine `live`: the window moves around it.
    pub fn markReported(self: *ExternalMemory, live: usize) void {
        self.low = live -| report_step;
        self.high = live +| report_step;
        self.due = false;
        if (self.queue) |queue| queue.owed.report = false;
    }

    fn checkThread(self: *const ExternalMemory) void {
        if (!debug_checks) return;
        const owner = self.thread orelse return;
        if (owner != std.Thread.getCurrentId()) @panic("a Browser's DOM memory was counted on a thread other than its window agent's");
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

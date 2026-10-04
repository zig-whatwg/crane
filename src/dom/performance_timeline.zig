//! The Performance Timeline (W3C Performance Timeline, sections 2, 4 and 5):
//! each global's performance entry buffer map, its list of registered
//! performance observers and its performance observer task queued flag, the
//! algorithms over them - "queue a PerformanceEntry", "filter buffer map by
//! name and type", the observe() and disconnect() registration steps, "queue
//! the PerformanceObserver task" - and the entry types this engine supports.
//!
//! The state is each global's ("Each global object has ...") and lives on
//! that global's Performance object: Performance's InternalState holds the
//! `Timeline`, so the timeline lives exactly as long as the global's realm
//! keeps its Performance. A PerformanceObserver's own concepts (its callback,
//! observer buffer, observer type, requires dropped entries, and the options
//! list of its registration) are an `Observer`, kept by the observer's impl
//! and listed by the timeline while registered. Four owners meet here, and
//! none may name another's impl, so each installs what only it can do:
//!   - Performance installs `Performances`: the timeline and the current
//!     relative timestamp of a realm's global;
//!   - PerformanceEntry installs `Entries`: an entry's attributes, which every
//!     entry type sets through "initialize a PerformanceEntry";
//!   - PerformanceObserverEntryList installs `EntryLists`: a new list with an
//!     entry list (the observer task's step 3.5);
//!   - PerformanceMeasure installs `Measures`: a new measure (User Timing
//!     measure() steps 4-9; PerformanceMeasure has no constructor).
//!
//! Entries are platform objects the collector frees with their wrappers, so
//! every list here that holds one also keeps it: an edge from the list's
//! owner (`holdEntry`: the Performance object for its buffers, the observer
//! for its observer buffer, a PerformanceObserverEntryList for its entry
//! list), never a root - Blink's Performance traces its buffers and
//! PerformanceObserver its performance_entries_. Teardown order is the
//! collector's: a Performance and the observers it lists may be freed in
//! either order at the realm's end, so neither's teardown reads the other
//! unless a slab-generation link says it is still there (`Link`).
//!
//! Spec: https://w3c.github.io/performance-timeline/
//! Spec: https://w3c.github.io/user-timing/ (the mark and measure types)
//!
//! lint-impls: hook for Performance, PerformanceEntry, PerformanceObserverEntryList, PerformanceMeasure

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const clock = @import("clock");
const fetch = @import("fetch");
const interfaces = @import("interfaces");
const fire_event = @import("fire_event.zig");

const Instance = runtime.Instance;

/// getentropy(2): the seed of each timeline's id generator. std's random
/// sources need an Io value (Zig 0.16) this module does not have.
extern "c" fn getentropy(buf: [*]u8, len: usize) c_int;

// ============================================================================
// Entry types (the timing entry types registry)
// ============================================================================

/// The entry types this engine knows, in alphabetical order (the order the
/// frozen array of supported entry types lists them in).
/// https://w3c.github.io/timing-entrytypes-registry/#registry
pub const EntryType = enum {
    mark,
    measure,
    navigation,
    resource,

    /// The registry's identifier.
    pub fn name(self: EntryType) []const u8 {
        return @tagName(self);
    }

    /// The registry entry `identifier` names - exactly, the registry's
    /// identifiers being case-sensitive - or null for one it does not.
    pub fn fromName(identifier: []const u8) ?EntryType {
        inline for (@typeInfo(EntryType).@"enum".fields) |field| {
            if (std.mem.eql(u8, identifier, field.name)) return @enumFromInt(field.value);
        }
        return null;
    }

    /// The registry's maxBufferSize: null for infinite. The resource
    /// buffer's limit is Resource Timing's own "resource timing buffer size
    /// limit" (`Timeline.resource`), which its "add a
    /// PerformanceResourceTiming entry" enforces.
    pub fn maxBufferSize(self: EntryType) ?usize {
        return switch (self) {
            .mark, .measure, .navigation, .resource => null,
        };
    }

    /// The registry's availableFromTimeline.
    pub fn availableFromTimeline(self: EntryType) bool {
        return switch (self) {
            .mark, .measure, .navigation, .resource => true,
        };
    }

    /// Whether this engine produces entries of this type for a global of
    /// this kind: what the frozen array of supported entry types lists, and
    /// what observe() accepts. "navigation" is a Window's alone (Navigation
    /// Timing 3.1: supportedEntryTypes "for Window contexts").
    pub fn isSupported(self: EntryType, kind: GlobalKind) bool {
        return switch (self) {
            .mark, .measure, .resource => true,
            .navigation => kind == .window,
        };
    }
};

/// Which kind of global a supported-types question is asked for.
pub const GlobalKind = enum {
    window,
    worker,

    pub fn of(realm: runtime.Context) GlobalKind {
        return if (realm.isWindow()) .window else .worker;
    }
};

/// The entry types supported for a global of `kind`, in alphabetical order:
/// the strings its frozen array of supported entry types holds.
pub fn supportedEntryTypes(kind: GlobalKind) []const EntryType {
    const lists = comptime blk: {
        var result: [2][]const EntryType = undefined;
        for ([_]GlobalKind{ .window, .worker }, 0..) |k, i| {
            var list: []const EntryType = &.{};
            for (@typeInfo(EntryType).@"enum".fields) |field| {
                const t: EntryType = @enumFromInt(field.value);
                if (t.isSupported(k)) list = list ++ &[_]EntryType{t};
            }
            result[i] = list;
        }
        break :blk result;
    };
    return lists[@intFromEnum(kind)];
}

/// "should add entry" (registry): true for every type this engine has - the
/// types with a condition (event, first-input's durationThreshold) are not
/// among them.
fn shouldAddEntry(entry_type: EntryType, options: ?*const Options) bool {
    _ = entry_type;
    _ = options;
    return true;
}

/// The read only attributes of PerformanceTiming (Navigation Timing 1):
/// names User Timing reads from it ("convert a mark to a timestamp") and a
/// Window's marks may not take (the PerformanceMark constructor, step 1).
pub const performance_timing_attributes = [_][]const u8{
    "navigationStart",   "unloadEventStart",           "unloadEventEnd",
    "redirectStart",     "redirectEnd",                "fetchStart",
    "domainLookupStart", "domainLookupEnd",            "connectStart",
    "connectEnd",        "secureConnectionStart",      "requestStart",
    "responseStart",     "responseEnd",                "domLoading",
    "domInteractive",    "domContentLoadedEventStart", "domContentLoadedEventEnd",
    "domComplete",       "loadEventStart",             "loadEventEnd",
};

/// Whether `name` is one of PerformanceTiming's read only attributes.
pub fn isPerformanceTimingAttribute(name: []const u8) bool {
    for (performance_timing_attributes) |attribute| {
        if (std.mem.eql(u8, name, attribute)) return true;
    }
    return false;
}

// ============================================================================
// Entries
// ============================================================================

/// A PerformanceEntry's attributes, which its entry type initializes and the
/// timeline reads and completes (id, navigationId) when it queues the entry.
pub const EntryData = struct {
    /// `name`, owned by the entry.
    name: []const u8,
    entry_type: EntryType,
    start_time: f64,
    /// "end time": 0 until set, and duration is 0 while it is.
    end_time: f64 = 0,
    /// `id`: 0 while unset (the generated ids start above 100).
    id: u64 = 0,
    /// `navigationId`: the associated document's most recent navigation's id
    /// when the entry was queued; 0 for none.
    navigation_id: u64 = 0,

    /// The duration getter: 0 while the end time is 0, otherwise end time -
    /// startTime.
    pub fn duration(self: *const EntryData) f64 {
        if (self.end_time == 0) return 0;
        return self.end_time - self.start_time;
    }
};

/// What PerformanceEntry supplies.
pub const Entries = struct {
    /// "initialize a PerformanceEntry" `entry` - an instance of any
    /// PerformanceEntry type - with startTime, entryType, name (copied) and
    /// end time.
    initialize: *const fn (entry: *Instance, start_time: f64, entry_type: EntryType, entry_name: []const u8, end_time: f64) anyerror!void,
    /// `entry`'s attributes, or null for an entry never initialized.
    data: *const fn (entry: *Instance) ?*EntryData,
};

/// "initialize a PerformanceEntry" (Performance Timeline 3).
pub fn initializeEntry(entry: *Instance, start_time: f64, entry_type: EntryType, entry_name: []const u8, end_time: f64) !void {
    const impl = hooks.entries orelse return error.NotSupported;
    try impl.initialize(entry, start_time, entry_type, entry_name, end_time);
}

/// `entry`'s attributes, or null.
pub fn dataOf(entry: *Instance) ?*EntryData {
    const impl = hooks.entries orelse return null;
    return impl.data(entry);
}

/// The slot an owner keeps one entry in: one per entry, named by its address
/// (as Element keeps its Attr nodes).
fn entrySlot(buffer: []u8, entry: *Instance) engine.TracedSlot {
    return .{ .name = std.fmt.bufPrint(buffer, "pe:{x}", .{@intFromPtr(entry)}) catch "pe" };
}

/// `owner` keeps `entry` alive, for as long as `owner`'s wrapper lives or
/// until `releaseEntry`: an edge, never a root.
pub fn holdEntry(owner: *Instance, entry: *Instance) void {
    var buffer: [48]u8 = undefined;
    engine.traceChild(owner, entry, entrySlot(&buffer, entry));
}

/// `owner` no longer keeps `entry`. Not from teardown, where the edge goes
/// with `owner`'s wrapper - except for an owner freed unwrapped, whose
/// waiting edges this lets go.
pub fn releaseEntry(owner: *Instance, entry: *Instance) void {
    var buffer: [48]u8 = undefined;
    engine.forgetTracedChild(owner, entrySlot(&buffer, entry));
}

// ============================================================================
// Links that survive either side's teardown
// ============================================================================

/// A link to an instance that may be freed without telling the holder: the
/// slab recycles addresses, and the slot's generation says whether it still
/// holds the object the link was taken on.
pub const Link = struct {
    instance: *Instance,
    generation: u64,

    pub fn to(instance: *Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }

    pub fn isLive(self: Link) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

// ============================================================================
// The timeline (a global's state)
// ============================================================================

/// A performance entry buffer map's value: the buffer, its maxBufferSize,
/// availableFromTimeline and dropped entries count.
pub const Buffer = struct {
    entries: std.ArrayListUnmanaged(*Instance) = .empty,
    /// null: infinite.
    max_size: ?usize,
    available_from_timeline: bool,
    dropped_entries_count: u64 = 0,
};

/// One global's performance timeline. Kept by the global's Performance
/// object (`owner`), whose wrapper keeps every buffered entry.
pub const Timeline = struct {
    allocator: std.mem.Allocator,
    /// The Performance object this is the state of.
    owner: *Instance,
    /// The performance entry buffer map, keyed by entry type.
    buffers: std.EnumArray(EntryType, Buffer),
    /// The list of registered performance observer objects: each a
    /// PerformanceObserver's `Observer`, BORROWED from its impl, which takes
    /// itself off the list before it goes.
    observers: std.ArrayListUnmanaged(*Observer) = .empty,
    /// The performance observer task queued flag.
    task_queued: bool = false,
    /// The last performance entry id: a random integer between 100 and
    /// 10000 at first.
    last_entry_id: u64,
    /// This global's own generator for the ids' start and increments
    /// (never one shared by every global: 5.7's note on cross-origin leaks).
    prng: std.Random.DefaultPrng,
    /// The associated document's most recent navigation's id, 0 while unset
    /// (Performance Timeline 2: each Document has a most recent navigation;
    /// a global and its associated Document are one here).
    most_recent_navigation_id: u64 = 0,
    /// Resource Timing 3.4's per-global state.
    resource: ResourceBuffer = .{},
    /// The associated Document's load timing info and previous document
    /// unload timing (HTML 3.1.5), as relative times; reset for each new
    /// document (`createNavigationTimingEntry`).
    load_timing: LoadTimingInfo = .{},
    /// The associated Document's navigation timing entry, while it has one
    /// (kept by the navigation buffer's edge).
    navigation_entry: ?*Instance = null,

    pub fn init(allocator: std.mem.Allocator, owner: *Instance) Timeline {
        var buffers: std.EnumArray(EntryType, Buffer) = undefined;
        inline for (@typeInfo(EntryType).@"enum".fields) |field| {
            const t: EntryType = @enumFromInt(field.value);
            buffers.set(t, .{ .max_size = t.maxBufferSize(), .available_from_timeline = t.availableFromTimeline() });
        }
        var prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            if (getentropy(std.mem.asBytes(&seed).ptr, @sizeOf(u64)) != 0) seed = @bitCast(clock.wallMillis());
            break :blk seed;
        });
        return .{
            .allocator = allocator,
            .owner = owner,
            .buffers = buffers,
            .last_entry_id = prng.random().intRangeAtMost(u64, 100, 10000),
            .prng = prng,
        };
    }

    /// Free the lists. The entries and observers they name are not read:
    /// at the realm's end the collector frees them in no order, and their
    /// edges and registrations go with their wrappers.
    pub fn deinit(self: *Timeline) void {
        var it = self.buffers.iterator();
        while (it.next()) |kv| kv.value.entries.deinit(self.allocator);
        self.resource.secondary_buffer.deinit(self.allocator);
        // An observer still listed must not reach back into this timeline
        // through a link its own teardown checks: the owner's generation
        // moves on when the slab frees it, right after this.
        self.observers.deinit(self.allocator);
    }

    /// "generate an id" (Performance Timeline 5.7): the last performance
    /// entry id, increased by a small random number - not 1, so that the id
    /// does not count the entries made.
    fn generateId(self: *Timeline) u64 {
        self.last_entry_id += self.prng.random().intRangeAtMost(u64, 1, 4);
        return self.last_entry_id;
    }

    fn isRegistered(self: *const Timeline, observer: *const Observer) bool {
        for (self.observers.items) |listed| {
            if (listed == observer) return true;
        }
        return false;
    }
};

/// "determine if a performance entry buffer is full" (5.6).
fn isBufferFull(buffer: *Buffer) bool {
    const max = buffer.max_size orelse return false;
    if (buffer.entries.items.len < max) return false;
    buffer.dropped_entries_count += 1;
    return true;
}

/// "queue a PerformanceEntry" (5.1) `entry` on `timeline`, its relevant
/// global's.
pub fn queueEntry(timeline: *Timeline, entry: *Instance) !void {
    const data = dataOf(entry) orelse return error.InvalidStateError;
    // 1. If newEntry's id is unset, generate one.
    if (data.id == 0) data.id = timeline.generateId();
    // 2-4. interested observers, entryType, relevantGlobal (the timeline's).
    const entry_type = data.entry_type;
    // 5-6. navigationId: the associated document's most recent navigation's
    // id (0 while unset; a worker's entries have none either).
    data.navigation_id = timeline.most_recent_navigation_id;
    // 7-8. Every registered observer whose options list names entryType
    // gets the entry in its observer buffer - once, however many of its
    // options name it ("a set").
    for (timeline.observers.items) |observer| {
        const options = observer.optionsFor(entry_type) orelse continue;
        if (!shouldAddEntry(entry_type, options)) continue;
        try observer.buffer.append(observer.allocator, entry);
        holdEntry(observer.instance, entry);
    }
    // 9-12. The buffer, unless it is full. A resource entry is added by
    // Resource Timing's own "add a PerformanceResourceTiming entry" (mark
    // resource timing step 4), which keeps the secondary buffer and fires
    // resourcetimingbufferfull - adding it here too would add it twice.
    // A navigation entry was added when it was made ("create the navigation
    // timing entry" step 12); queueing it does not add it again.
    const buffer = timeline.buffers.getPtr(entry_type);
    const already_buffered = entry_type == .navigation and std.mem.indexOfScalar(*Instance, buffer.entries.items, entry) != null;
    if (entry_type != .resource and !already_buffered and !isBufferFull(buffer) and shouldAddEntry(entry_type, null)) {
        try buffer.entries.append(timeline.allocator, entry);
        holdEntry(timeline.owner, entry);
    }
    // 13. Queue the PerformanceObserver task.
    queueObserverTask(timeline);
}

/// "filter buffer by name and type" (5.5): the entries of `buffer` whose
/// entryType is `entry_type` and whose name is `entry_name` (null: any),
/// appended to `result` in chronological order of startTime. Returns how
/// many it appended.
pub fn filterBuffer(allocator: std.mem.Allocator, result: *std.ArrayListUnmanaged(*Instance), buffer: []const *Instance, entry_name: ?[]const u8, entry_type: ?[]const u8) !void {
    const start = result.items.len;
    for (buffer) |entry| {
        const data = dataOf(entry) orelse continue;
        if (entry_type) |wanted| {
            if (!std.mem.eql(u8, wanted, data.entry_type.name())) continue;
        }
        if (entry_name) |wanted| {
            if (!std.mem.eql(u8, wanted, data.name)) continue;
        }
        try result.append(allocator, entry);
    }
    sortChronologically(result.items[start..]);
}

/// "filter buffer map by name and type" (5.4) over `timeline`'s buffers:
/// OWNED (`allocator`).
pub fn filterBufferMap(timeline: *Timeline, allocator: std.mem.Allocator, entry_name: ?[]const u8, entry_type: ?[]const u8) ![]*Instance {
    var result: std.ArrayListUnmanaged(*Instance) = .empty;
    errdefer result.deinit(allocator);
    if (entry_type) |wanted| {
        // 4. The tuple of `type`: none for a type the map has no entry for.
        const t = EntryType.fromName(wanted) orelse return result.toOwnedSlice(allocator);
        const buffer = timeline.buffers.getPtr(t);
        if (buffer.available_from_timeline) try filterBuffer(allocator, &result, buffer.entries.items, entry_name, entry_type);
    } else {
        var it = timeline.buffers.iterator();
        while (it.next()) |kv| {
            if (!kv.value.available_from_timeline) continue;
            try filterBuffer(allocator, &result, kv.value.entries.items, entry_name, null);
        }
    }
    // 6. Sort the whole result chronologically.
    sortChronologically(result.items);
    return result.toOwnedSlice(allocator);
}

fn sortChronologically(items: []*Instance) void {
    const Order = struct {
        fn lessThan(_: void, a: *Instance, b: *Instance) bool {
            const da = dataOf(a) orelse return false;
            const db = dataOf(b) orelse return false;
            return da.start_time < db.start_time;
        }
    };
    // Stable: entries with the same startTime keep the buffer's order.
    std.sort.insertion(*Instance, items, {}, Order.lessThan);
}

/// Remove from `timeline`'s buffer of `entry_type` every entry whose name is
/// `entry_name` (null: every entry) - clearMarks(), clearMeasures(),
/// clearResourceTimings(). The timeline stops keeping them.
pub fn clearEntries(timeline: *Timeline, entry_type: EntryType, entry_name: ?[]const u8) void {
    const buffer = timeline.buffers.getPtr(entry_type);
    var kept: usize = 0;
    for (buffer.entries.items) |entry| {
        const matches = if (entry_name) |wanted| blk: {
            const data = dataOf(entry) orelse break :blk false;
            break :blk std.mem.eql(u8, wanted, data.name);
        } else true;
        if (matches) {
            releaseEntry(timeline.owner, entry);
            continue;
        }
        buffer.entries.items[kept] = entry;
        kept += 1;
    }
    buffer.entries.shrinkRetainingCapacity(kept);
}

/// The startTime of the most recent entry of `entry_type` named
/// `entry_name` in `timeline`'s buffer, or null when there is none (User
/// Timing "convert a mark to a timestamp" step 2 asks it of marks).
pub fn mostRecentStartTime(timeline: *Timeline, entry_type: EntryType, entry_name: []const u8) ?f64 {
    const items = timeline.buffers.getPtr(entry_type).entries.items;
    var i = items.len;
    while (i > 0) {
        i -= 1;
        const data = dataOf(items[i]) orelse continue;
        if (std.mem.eql(u8, data.name, entry_name)) return data.start_time;
    }
    return null;
}

// ============================================================================
// Observers
// ============================================================================

/// A PerformanceObserver's observer type.
pub const ObserverType = enum { undefined, single, multiple };

/// A PerformanceObserverInit as a registration keeps it, its entry types
/// already reduced to the supported ones (observe() steps 6.2 and 7.2).
pub const Options = struct {
    /// `entryTypes` (multiple) or `type` (single), as a set.
    types: std.EnumSet(EntryType),
    /// The `type` member, for a single-type registration.
    single: ?EntryType = null,
    buffered: bool = false,
};

/// A PerformanceObserver's concepts (Performance Timeline 4): its observer
/// callback, observer buffer, observer type and requires dropped entries -
/// and, while registered, its registered performance observer's options
/// list. Kept by the observer's impl; listed by its relevant global's
/// timeline while registered.
pub const Observer = struct {
    allocator: std.mem.Allocator,
    /// The PerformanceObserver.
    instance: *Instance,
    /// The observer callback, OWNED: released in `deinit`.
    callback: ?engine.CallbackFunction = null,
    /// The observer buffer; each entry kept by an edge from `instance`.
    buffer: std.ArrayListUnmanaged(*Instance) = .empty,
    observer_type: ObserverType = .undefined,
    requires_dropped_entries: bool = false,
    /// The options list of its registered performance observer: empty when
    /// it is not registered.
    options: std.ArrayListUnmanaged(Options) = .empty,
    /// The Performance whose timeline lists it, while it is listed.
    registered_on: ?Link = null,

    pub fn init(allocator: std.mem.Allocator, instance: *Instance) Observer {
        return .{ .allocator = allocator, .instance = instance };
    }

    /// The observer's teardown: off the timeline that lists it (if that
    /// timeline is still there), its callback released, its lists freed.
    /// Its entries' edges go with its wrapper.
    pub fn deinit(self: *Observer) void {
        self.unregister();
        if (self.callback) |callback| callback.release();
        self.callback = null;
        self.buffer.deinit(self.allocator);
        self.options.deinit(self.allocator);
        engine.releasePlatformObject(self.instance);
    }

    /// The options in its list naming `entry_type`, if any.
    fn optionsFor(self: *Observer, entry_type: EntryType) ?*const Options {
        for (self.options.items) |*options| {
            if (options.types.contains(entry_type)) return options;
        }
        return null;
    }

    fn timeline(self: *Observer) ?*Timeline {
        const link = self.registered_on orelse return null;
        if (!link.isLive()) return null;
        return timelineOfPerformance(link.instance);
    }

    /// Take it off the list of the timeline that lists it.
    fn unregister(self: *Observer) void {
        defer self.registered_on = null;
        const listing = self.timeline() orelse return;
        for (listing.observers.items, 0..) |listed, i| {
            if (listed != self) continue;
            _ = listing.observers.orderedRemove(i);
            break;
        }
    }

    /// Empty the observer buffer, its edges released: takeRecords() (4.3)
    /// does once the copy it returns holds the entries - an Array of their
    /// wrappers - and never before, or the collector could take one between.
    pub fn emptyBuffer(self: *Observer) void {
        for (self.buffer.items) |entry| releaseEntry(self.instance, entry);
        self.buffer.clearRetainingCapacity();
    }

    /// disconnect() (4.4): off its global's list, its buffer and options
    /// list emptied; and its wrapper no longer held for the registration.
    pub fn disconnect(self: *Observer) void {
        self.unregister();
        self.emptyBuffer();
        self.options.clearRetainingCapacity();
        engine.releasePlatformObject(self.instance);
    }
};

/// observe() step 6.2: the entry types among `identifiers` that are in the
/// frozen array of supported entry types of a global of `kind`; the rest
/// are removed.
pub fn supportedAmong(identifiers: []const []const u8, kind: GlobalKind) std.EnumSet(EntryType) {
    var types = std.EnumSet(EntryType).initEmpty();
    for (identifiers) |identifier| {
        const t = EntryType.fromName(identifier) orelse continue;
        if (t.isSupported(kind)) types.insert(t);
    }
    return types;
}

/// What observe() asks after its own checks (steps 1-5): `entry_types`
/// for an entryTypes call (multiple), else `single_type` (single).
pub const ObserveRequest = struct {
    entry_types: ?[]const []const u8 = null,
    single_type: ?[]const u8 = null,
    buffered: bool = false,
};

/// observe() steps 6 and 7, on `observer`'s relevant global's `timeline`.
pub fn observe(timeline: *Timeline, observer: *Observer, request: ObserveRequest) !void {
    if (observer.observer_type == .multiple) {
        // 6.1-6.2. entry types, reduced to the supported ones.
        const types = supportedAmong(request.entry_types orelse &.{}, GlobalKind.of(timeline.owner.ctx));
        // 6.3. None left: abort.
        if (types.count() == 0) return;
        const options: Options = .{ .types = types };
        // 6.4-6.5. Replace the options list, or register.
        if (timeline.isRegistered(observer)) {
            observer.options.clearRetainingCapacity();
            try observer.options.append(observer.allocator, options);
        } else {
            try register(timeline, observer, options);
        }
        return;
    }
    // 7.1. Single.
    const identifier = request.single_type orelse return;
    // 7.2. An unsupported type: abort.
    const t = EntryType.fromName(identifier) orelse return;
    if (!t.isSupported(GlobalKind.of(timeline.owner.ctx))) return;
    var single_types = std.EnumSet(EntryType).initEmpty();
    single_types.insert(t);
    const options: Options = .{ .types = single_types, .single = t, .buffered = request.buffered };
    if (timeline.isRegistered(observer)) {
        // 7.3.1-7.3.2. Replace the options of the same type, or append.
        for (observer.options.items) |*current| {
            if (current.single == t) {
                current.* = options;
                break;
            }
        } else try observer.options.append(observer.allocator, options);
    } else {
        // 7.4.
        try register(timeline, observer, options);
    }
    // 7.5. buffered: the buffer's entries (those "should add entry"
    // accepts) go to the observer buffer, and the task is queued.
    if (request.buffered) {
        const buffer = timeline.buffers.getPtr(t);
        for (buffer.entries.items) |entry| {
            if (!shouldAddEntry(t, &options)) continue;
            try observer.buffer.append(observer.allocator, entry);
            holdEntry(observer.instance, entry);
        }
        queueObserverTask(timeline);
    }
}

/// Create and append a registered performance observer for `observer`
/// with `options` as its only item. A registered observer is kept alive
/// whatever script holds of it (Blink: PerformanceObserver's
/// HasPendingActivity is its registration), until disconnect().
fn register(timeline: *Timeline, observer: *Observer, options: Options) !void {
    observer.options.clearRetainingCapacity();
    try observer.options.append(observer.allocator, options);
    try timeline.observers.append(timeline.allocator, observer);
    observer.registered_on = Link.to(timeline.owner);
    engine.keepPlatformObjectAlive(observer.instance);
}

// ============================================================================
// The PerformanceObserver task
// ============================================================================

/// "queue the PerformanceObserver task" (5.3) for `timeline`'s global: once
/// until it runs, on the performance timeline task source - a global task of
/// the timeline's realm, on its event loop (a window's: dropped, not run,
/// once the Window's document is not fully active), or a worker realm's
/// timer.
pub fn queueObserverTask(timeline: *Timeline) void {
    // 1-2.
    if (timeline.task_queued) return;
    const ctx = timeline.owner.ctx;
    const task = timeline.allocator.create(ObserverTask) catch return;
    task.* = .{ .allocator = timeline.allocator, .performance = Link.to(timeline.owner) };
    if (ctx.getOptionalEventLoop()) |loop| {
        timeline.task_queued = true;
        // A global task of the window: the Window names the document asked
        // about when it runs (streams Task.document).
        const global = globalOf(ctx);
        loop.queueTask(.{
            .callback = ObserverTask.run,
            .context = task,
            .drop = ObserverTask.drop,
            .document = if (global) |g| @ptrCast(g) else null,
            .document_generation = if (global) |g| runtime.SlabAllocator.generationOf(g) else 0,
        });
        return;
    }
    if (ctx.getOptionalTimer()) |timer| {
        if (timer.setTimeout(0, ObserverTask.run, task) != 0) {
            timeline.task_queued = true;
            return;
        }
    }
    // Nowhere to queue it: no task, and the flag stays unset so that a later
    // entry tries again.
    timeline.allocator.destroy(task);
}

/// A realm's global object, as its realm records it.
pub fn globalOf(ctx: runtime.Context) ?*Instance {
    const record = ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(record.global_object orelse return null));
}

const ObserverTask = struct {
    allocator: std.mem.Allocator,
    /// The Performance whose timeline queued it.
    performance: Link,

    fn run(context: ?*anyopaque) void {
        const self: *ObserverTask = @ptrCast(@alignCast(context.?));
        const performance = self.performance;
        self.allocator.destroy(self);
        if (!performance.isLive()) return;
        const timeline = timelineOfPerformance(performance.instance) orelse return;
        engine.runTaskInRealm(performance.instance.ctx, steps, timeline) catch {
            // The realm's tasks no longer run: its observers hear nothing.
            timeline.task_queued = false;
        };
    }

    /// A task that will never run: its loop is going, or its document is
    /// not fully active.
    fn drop(context: ?*anyopaque) void {
        const self: *ObserverTask = @ptrCast(@alignCast(context.?));
        const performance = self.performance;
        self.allocator.destroy(self);
        if (!performance.isLive()) return;
        const timeline = timelineOfPerformance(performance.instance) orelse return;
        timeline.task_queued = false;
    }

    /// The task's substeps (5.3 step 3), in the timeline's realm.
    fn steps(data: ?*anyopaque) void {
        const timeline: *Timeline = @ptrCast(@alignCast(data.?));
        notifyObservers(timeline);
    }
};

/// One registered observer as the notify list copies it.
const Notified = struct { observer: *Observer, link: Link };

/// 5.3 step 3's substeps.
fn notifyObservers(timeline: *Timeline) void {
    // 3.1. Unset the flag.
    timeline.task_queued = false;
    // 3.2. A copy of the list: a callback may disconnect observers.
    const notify_list = timeline.allocator.alloc(Notified, timeline.observers.items.len) catch return;
    defer timeline.allocator.free(notify_list);
    for (timeline.observers.items, notify_list) |observer, *slot| slot.* = .{ .observer = observer, .link = Link.to(observer.instance) };
    const realm = timeline.owner.ctx;
    // 3.3.
    for (notify_list) |notified| {
        // An observer a callback disconnected and script then let go.
        if (!notified.link.isLive()) continue;
        // The timeline may have gone with its realm during a callback.
        if (!timeline.owner.ctx.hasEngine()) return;
        notifyObserver(timeline, realm, notified.observer) catch continue;
    }
}

/// 5.3 steps 3.3.1-3.3.9 for one observer.
fn notifyObserver(timeline: *Timeline, realm: runtime.Context, po: *Observer) !void {
    // 3.3.2-3.3.4. A copy of its buffer, which is emptied. An empty one is
    // skipped: the spec's "return" would leave every later observer in the
    // list unnotified, which no engine does (Blink's
    // PerformanceObserver::Deliver returns for that observer only).
    if (po.buffer.items.len == 0) return;
    const entry_list_items = try timeline.allocator.dupe(*Instance, po.buffer.items);
    defer timeline.allocator.free(entry_list_items);
    // 3.3.5. The PerformanceObserverEntryList keeps the entries (before the
    // observer's edges go, so they are never unkept).
    const lists = hooks.entry_lists orelse return error.NotSupported;
    const observer_entry_list = try lists.create(realm, entry_list_items);
    const list_generation = runtime.SlabAllocator.generationOf(observer_entry_list);
    defer observer_entry_list.releaseIfUnwrapped(list_generation);
    po.emptyBuffer();
    // 3.3.6-3.3.7. The dropped entries count, for an observer that requires
    // it: summed over the entry types of every item in its options list.
    var dropped: ?u64 = null;
    if (po.requires_dropped_entries) {
        var count: u64 = 0;
        for (po.options.items) |item| {
            var it = item.types.iterator();
            while (it.next()) |t| count += timeline.buffers.getPtr(t).dropped_entries_count;
        }
        dropped = count;
        po.requires_dropped_entries = false;
    }
    // 3.3.8. The callback options: droppedEntriesCount when set.
    const members: []const engine.DictionaryMember = if (dropped) |count|
        &.{.{ .name = "droppedEntriesCount", .value = .{ .number = @floatFromInt(count) } }}
    else
        &.{};
    const callback_options = try engine.createDictionaryObject(realm, members);
    defer callback_options.release();
    // 3.3.9. Invoke po's observer callback with « observerEntryList, po,
    // callbackOptions », "report", and po.
    const callback = po.callback orelse return;
    const observer_value: runtime.JSValue = .{ .instance = po.instance };
    const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = observer_value }, &.{ .{ .instance = observer_entry_list }, observer_value, callback_options.value }, .{
        .report = .{ .report = reportException, .host = realm },
    });
    switch (completion) {
        inline else => |value| value.release(),
    }
}

/// HTML "report an exception" for the global of the realm the engine names -
/// the callback's - or else the observer's (`host`).
fn reportException(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
    const observer_realm: runtime.Context = @ptrCast(@alignCast(host orelse return));
    const realm = info.realm orelse observer_realm;
    const global = globalOf(realm) orelse return;
    const reporter = hooks.exception_reporter orelse return;
    reporter(global, info);
}

// ============================================================================
// Resource Timing (W3C Resource Timing 3.4, 4)
// ============================================================================

/// Resource Timing 3.4's state of a global ("Each ECMAScript global
/// environment has"): the buffer's size limit and current size, the buffer
/// full event pending flag and the secondary buffer.
pub const ResourceBuffer = struct {
    size_limit: usize = 250,
    current_size: usize = 0,
    full_event_pending: bool = false,
    /// The resource timing secondary buffer; each entry kept by an edge from
    /// the timeline's owner while it is here.
    secondary_buffer: std.ArrayListUnmanaged(*Instance) = .empty,
};

/// "can add resource timing entry".
fn canAddResourceTimingEntry(timeline: *const Timeline) bool {
    return timeline.resource.current_size < timeline.resource.size_limit;
}

/// "add a PerformanceResourceTiming entry" `entry` into `timeline`'s
/// performance entry buffer.
pub fn addResourceTimingEntry(timeline: *Timeline, entry: *Instance) !void {
    const state = &timeline.resource;
    // 1. Room, and no buffer full event pending: into the buffer.
    if (canAddResourceTimingEntry(timeline) and !state.full_event_pending) {
        try timeline.buffers.getPtr(.resource).entries.append(timeline.allocator, entry);
        holdEntry(timeline.owner, entry);
        state.current_size += 1;
        return;
    }
    // 2. Otherwise the buffer full event is pending, its task queued once.
    if (!state.full_event_pending) {
        state.full_event_pending = true;
        queueBufferFullTask(timeline);
    }
    // 3-4. Into the secondary buffer.
    try state.secondary_buffer.append(timeline.allocator, entry);
    holdEntry(timeline.owner, entry);
}

/// clearResourceTimings(): every PerformanceResourceTiming out of the
/// buffer, and its current size 0.
pub fn clearResourceTimings(timeline: *Timeline) void {
    clearEntries(timeline, .resource, null);
    timeline.resource.current_size = 0;
}

/// setResourceTimingBufferSize(maxSize): the size limit; entries already
/// buffered stay.
pub fn setResourceTimingBufferSize(timeline: *Timeline, max_size: u32) void {
    timeline.resource.size_limit = max_size;
}

/// "copy secondary buffer".
fn copySecondaryBuffer(timeline: *Timeline) void {
    const state = &timeline.resource;
    const buffer = timeline.buffers.getPtr(.resource);
    // 1. While the secondary buffer has entries and there is room, the
    // oldest moves to the end of the buffer (its edge from the owner stays).
    while (state.secondary_buffer.items.len > 0 and canAddResourceTimingEntry(timeline)) {
        const entry = state.secondary_buffer.orderedRemove(0);
        buffer.entries.append(timeline.allocator, entry) catch {
            releaseEntry(timeline.owner, entry);
            continue;
        };
        state.current_size += 1;
    }
}

/// "fire a buffer full event", in `timeline`'s realm.
fn fireBufferFullEvent(timeline: *Timeline) void {
    const state = &timeline.resource;
    // 1. While the secondary buffer has entries:
    while (state.secondary_buffer.items.len > 0) {
        // 1.1.
        const before = state.secondary_buffer.items.len;
        // 1.2. No room: resourcetimingbufferfull at the Performance object.
        if (!canAddResourceTimingEntry(timeline)) fireSimpleEvent(timeline.owner, "resourcetimingbufferfull");
        // A listener may have ended the realm.
        if (!timeline.owner.ctx.hasEngine()) return;
        // 1.3-1.4.
        copySecondaryBuffer(timeline);
        const after = state.secondary_buffer.items.len;
        // 1.5. No room was made: the rest are dropped - counted as the
        // resource buffer's dropped entries (Performance Timeline's dropped
        // entries count, which observers requiring it hear).
        if (before <= after) {
            for (state.secondary_buffer.items) |entry| releaseEntry(timeline.owner, entry);
            timeline.buffers.getPtr(.resource).dropped_entries_count += state.secondary_buffer.items.len;
            state.secondary_buffer.clearRetainingCapacity();
            break;
        }
    }
    // 2.
    state.full_event_pending = false;
}

/// Fire an event named `event_type` at `target` (DOM "fire an event").
fn fireSimpleEvent(target: *Instance, comptime event_type: []const u8) void {
    const event = interfaces.Event.call_constructor(target.ctx, runtime.DOMString.initInterned(event_type), .{ .was_passed = false, .value = .{} }) catch return;
    const generation = runtime.SlabAllocator.generationOf(event);
    _ = fire_event.dispatchTrusted(target, event) catch {};
    event.releaseIfUnwrapped(generation);
}

/// Queue a task on the performance timeline task source to fire a buffer
/// full event - a global task of the timeline's realm, as the observer task.
fn queueBufferFullTask(timeline: *Timeline) void {
    queueGlobalTask(timeline.owner, BufferFullTask.run, BufferFullTask.drop) catch {
        // Nowhere to queue it: the entries stay in the secondary buffer, and
        // the pending flag clears so that the next entry tries again.
        timeline.resource.full_event_pending = false;
    };
}

const BufferFullTask = struct {
    fn run(context: ?*anyopaque) void {
        const task: *GlobalTask = @ptrCast(@alignCast(context.?));
        const performance = task.target;
        task.destroy();
        if (!performance.isLive()) return;
        const timeline = timelineOfPerformance(performance.instance) orelse return;
        engine.runTaskInRealm(performance.instance.ctx, steps, timeline) catch {
            timeline.resource.full_event_pending = false;
        };
    }

    fn drop(context: ?*anyopaque) void {
        const task: *GlobalTask = @ptrCast(@alignCast(context.?));
        const performance = task.target;
        task.destroy();
        if (!performance.isLive()) return;
        const timeline = timelineOfPerformance(performance.instance) orelse return;
        timeline.resource.full_event_pending = false;
    }

    fn steps(data: ?*anyopaque) void {
        fireBufferFullEvent(@ptrCast(@alignCast(data.?)));
    }
};

/// A global task's context: its target (a Performance, a global), by a link
/// that says whether it is still there when the task runs.
const GlobalTask = struct {
    allocator: std.mem.Allocator,
    target: Link,
    fn destroy(self: *GlobalTask) void {
        self.allocator.destroy(self);
    }
};

/// Queue a global task for `target` (a Performance or a global) on its
/// realm's event loop - naming the realm's Window, so that it is dropped
/// once the Window's document is not fully active - or, in a worker realm,
/// as a timer.
fn queueGlobalTask(target: *Instance, run: *const fn (?*anyopaque) void, drop: *const fn (?*anyopaque) void) !void {
    const ctx = target.ctx;
    const allocator = ctx.allocator;
    const task = try allocator.create(GlobalTask);
    task.* = .{ .allocator = allocator, .target = Link.to(target) };
    if (ctx.getOptionalEventLoop()) |loop| {
        const global = globalOf(ctx);
        loop.queueTask(.{
            .callback = run,
            .context = task,
            .drop = drop,
            .document = if (global) |g| @ptrCast(g) else null,
            .document_generation = if (global) |g| runtime.SlabAllocator.generationOf(g) else 0,
        });
        return;
    }
    if (ctx.getOptionalTimer()) |timer| {
        if (timer.setTimeout(0, run, task) != 0) return;
    }
    task.destroy();
    return error.NotSupported;
}

/// How a PerformanceResourceTiming's cache mode reads.
pub const CacheMode = enum { none, local, validated };

/// What Resource Timing's "setup the resource timing entry" sets on an
/// entry, its fetch timing info's times already converted to the entry's
/// global's relative time ("convert fetch timestamp": 0 stays 0) - the
/// getters return them as they are. Strings OWNED (`allocator`).
pub const ResourceTiming = struct {
    allocator: std.mem.Allocator,
    /// The requested URL, which is also the entry's name.
    url: []u8,
    /// The initiator type ("fetch", "script", ...); static.
    initiator_type: []const u8,
    /// The delivery type: "" or "cache"; static.
    delivery_type: []const u8,
    cache_mode: CacheMode,
    response_status: u16,
    render_blocking: bool,
    /// Whether the response passed the timing allow check: without it,
    /// transferSize is 0 (Resource Timing 3.5.1).
    timing_allow_passed: bool = true,
    /// The entry's startTime and end time.
    start_time: f64,
    end_time: f64,
    worker_start: f64,
    redirect_start: f64,
    redirect_end: f64,
    fetch_start: f64,
    domain_lookup_start: f64,
    domain_lookup_end: f64,
    connect_start: f64,
    connect_end: f64,
    secure_connection_start: f64,
    request_start: f64,
    final_response_headers_start: f64,
    first_interim_response_start: f64,
    response_end: f64,
    next_hop_protocol: []u8,
    encoded_body_size: u64,
    decoded_body_size: u64,
    content_type: []u8,
    content_encoding: []u8,

    pub fn deinit(self: *ResourceTiming) void {
        self.allocator.free(self.url);
        self.allocator.free(self.next_hop_protocol);
        self.allocator.free(self.content_type);
        self.allocator.free(self.content_encoding);
    }

    /// A copy with strings of its own (`allocator`).
    pub fn clone(self: *const ResourceTiming, allocator: std.mem.Allocator) !ResourceTiming {
        var copy = self.*;
        copy.allocator = allocator;
        copy.url = try allocator.dupe(u8, self.url);
        errdefer allocator.free(copy.url);
        copy.next_hop_protocol = try allocator.dupe(u8, self.next_hop_protocol);
        errdefer allocator.free(copy.next_hop_protocol);
        copy.content_type = try allocator.dupe(u8, self.content_type);
        errdefer allocator.free(copy.content_type);
        copy.content_encoding = try allocator.dupe(u8, self.content_encoding);
        return copy;
    }

    /// "setup the resource timing entry" steps 3-11 for what fetch
    /// reported, with `convert` turning a fetch timestamp into the global's
    /// relative time.
    pub fn fromReport(allocator: std.mem.Allocator, report: *const fetch.internal.TimingReport, convert: anytype) !ResourceTiming {
        const timing = report.timing_info;
        const connection = timing.final_connection_timing_info orelse fetch.internal.ConnectionTimingInfo{};
        // 1. cacheMode is "", "local" or "validated".
        const cache_mode: CacheMode = if (std.mem.eql(u8, report.cache_state, "local"))
            .local
        else if (std.mem.eql(u8, report.cache_state, "validated"))
            .validated
        else
            .none;
        const url = try allocator.dupe(u8, report.url);
        errdefer allocator.free(url);
        const protocol = try allocator.dupe(u8, connection.alpn_negotiated_protocol);
        errdefer allocator.free(protocol);
        const content_type = try allocator.dupe(u8, report.body_info.content_type);
        errdefer allocator.free(content_type);
        const content_encoding = try allocator.dupe(u8, report.body_info.content_encoding);
        return .{
            .allocator = allocator,
            .url = url,
            .initiator_type = initiatorTypeName(report.initiator_type),
            // 10. A cache mode and no delivery type: "cache".
            .delivery_type = if (cache_mode != .none) "cache" else "",
            .cache_mode = cache_mode,
            .response_status = report.response_status,
            .render_blocking = timing.render_blocking,
            .timing_allow_passed = report.timing_allow_passed,
            // 3. startTime: the start time; end time: the end time.
            .start_time = convert.call(timing.start_time),
            .end_time = convert.call(timing.end_time),
            .worker_start = convert.call(timing.final_service_worker_start_time),
            .redirect_start = convert.call(timing.redirect_start_time),
            .redirect_end = convert.call(timing.redirect_end_time),
            .fetch_start = convert.call(timing.post_redirect_start_time),
            .domain_lookup_start = convert.call(connection.domain_lookup_start_time),
            .domain_lookup_end = convert.call(connection.domain_lookup_end_time),
            .connect_start = convert.call(connection.connection_start_time),
            .connect_end = convert.call(connection.connection_end_time),
            .secure_connection_start = convert.call(connection.secure_connection_start_time),
            .request_start = convert.call(timing.final_network_request_start_time),
            .final_response_headers_start = convert.call(timing.final_network_response_start_time),
            .first_interim_response_start = convert.call(timing.first_interim_network_response_start_time),
            .response_end = convert.call(timing.end_time),
            .next_hop_protocol = protocol,
            .encoded_body_size = report.body_info.encoded_size,
            .decoded_body_size = report.body_info.decoded_size,
            .content_type = content_type,
            .content_encoding = content_encoding,
        };
    }
};

/// A Fetch initiator type as Resource Timing names it.
pub fn initiatorTypeName(initiator_type: fetch.internal.InitiatorType) []const u8 {
    return switch (initiator_type) {
        .early_hints => "early-hints",
        inline else => |t| @tagName(t),
    };
}

/// Resource Timing "convert fetch timestamp" for `realm`'s global: zero
/// stays zero; any other time is its relative high resolution coarse time.
const FetchTimestampConverter = struct {
    realm: runtime.Context,

    fn call(self: FetchTimestampConverter, ts: f64) f64 {
        if (ts == 0) return 0;
        const impl = hooks.performances orelse return 0;
        return impl.relative_coarse_time(self.realm, ts) orelse 0;
    }
};

/// What PerformanceResourceTiming supplies.
pub const ResourceTimings = struct {
    /// "mark resource timing" step 1-2: a new PerformanceResourceTiming in
    /// `realm` set up with `timing` (copied). The caller's until the engine
    /// wraps it (Instance.releaseIfUnwrapped).
    create: *const fn (realm: runtime.Context, timing: *const ResourceTiming) anyerror!*Instance,
    /// "setup the resource timing entry" steps 4-11 for `entry`, an
    /// instance of a PerformanceResourceTiming type made elsewhere (a
    /// PerformanceNavigationTiming): `timing` copied into its
    /// PerformanceResourceTiming part. Step 3 (initialize the
    /// PerformanceEntry) is the caller's.
    setup: *const fn (entry: *Instance, timing: *const ResourceTiming) anyerror!void,
};

/// The timing reporter of requests whose client is `global`'s settings
/// object (fetch's TimingReporter): what fetch reports is marked as a
/// resource timing of `global`, in a global task.
pub fn timingReporterFor(global: *Instance) fetch.internal.TimingReporter {
    return .{ .context = global, .report = &reportResourceTiming };
}

/// A timing reporter for a global that can end before the reporter's last
/// use: it reports only while `global` is still the instance it was made for
/// and its realm still runs. A frame's navigation request holds one for its
/// container document's global (HTML "create navigation params by fetching"
/// step 3), whose document can go while the fetch is in flight - as
/// csp_violations.GuardedReporter does for the request's CSP violations. The
/// holder keeps it at a fixed address while a request holds its `reporter()`.
pub const GuardedTimingReporter = struct {
    global: Link,

    pub fn forGlobal(global: *Instance) GuardedTimingReporter {
        return .{ .global = Link.to(global) };
    }

    pub fn reporter(self: *GuardedTimingReporter) fetch.internal.TimingReporter {
        return .{ .context = self, .report = &reportWhileAlive };
    }

    fn reportWhileAlive(context: *anyopaque, report: *const fetch.internal.TimingReport) void {
        const self: *GuardedTimingReporter = @ptrCast(@alignCast(context));
        if (!self.global.isLive()) return;
        reportResourceTimingFor(self.global.instance, report);
    }
};

/// Fetch "report timing" for the request's client's `global` (the
/// reporter's context).
fn reportResourceTiming(context: *anyopaque, report: *const fetch.internal.TimingReport) void {
    reportResourceTimingFor(@ptrCast(@alignCast(context)), report);
}

/// Resource Timing's "mark resource timing" for `global`, with what fetch
/// reported - its times made relative to `global`'s time origin. Run in the
/// fetch's own turn, as Fetch runs the report timing steps in its end-of-body
/// steps: the entry is in the timeline before the task that tells the
/// resource's requester it is done (a script's load event, an XHR's
/// loadend), which buffer-full-*.html and the "await load; getEntries()"
/// idiom read. A separate task ran after that event and reordered entries
/// against clearResourceTimings(). Fetch reports only on the thread of the
/// event loop whose global it reports to, a fetch whose client went is
/// terminated first (async_fetch's `alive`), and a realm that has ended
/// takes nothing.
fn reportResourceTimingFor(global: *Instance, report: *const fetch.internal.TimingReport) void {
    if (!global.ctx.hasEngine()) return;
    var timing = ResourceTiming.fromReport(global.ctx.allocator, report, FetchTimestampConverter{ .realm = global.ctx }) catch return;
    defer timing.deinit();
    markResourceTiming(global.ctx, &timing) catch {};
}

/// Resource Timing 4 "mark resource timing" for `realm`'s global, given
/// what "setup the resource timing entry" sets.
pub fn markResourceTiming(realm: runtime.Context, timing: *const ResourceTiming) !void {
    const timeline = timelineOf(realm) orelse return;
    const impl = hooks.resource_timings orelse return error.NotSupported;
    // 1-2. A new PerformanceResourceTiming in global's realm, set up.
    const entry = try impl.create(realm, timing);
    const generation = runtime.SlabAllocator.generationOf(entry);
    // An entry no buffer and no observer kept is the caller's to free.
    defer entry.releaseIfUnwrapped(generation);
    // 3. Queue it.
    try queueEntry(timeline, entry);
    // 4. Add it to global's performance entry buffer.
    try addResourceTimingEntry(timeline, entry);
}

// ============================================================================
// Navigation Timing (W3C Navigation Timing 2, 5)
// ============================================================================

/// A navigation's type (NavigationTimingType).
pub const NavigationType = enum { navigate, reload, back_forward };

/// HTML's document load timing info and document unload timing info (3.1.5)
/// for the associated Document, each time relative to the global's time
/// origin; 0 while unset. `dom_loading` is when the document was made with
/// readiness "loading" (Navigation Timing 1's domLoading).
pub const LoadTimingInfo = struct {
    dom_loading: f64 = 0,
    dom_interactive: f64 = 0,
    dom_content_loaded_event_start: f64 = 0,
    dom_content_loaded_event_end: f64 = 0,
    dom_complete: f64 = 0,
    load_event_start: f64 = 0,
    load_event_end: f64 = 0,
    unload_event_start: f64 = 0,
    unload_event_end: f64 = 0,
};

/// A moment HTML records in a document's load timing info.
pub const LoadTimingMoment = enum {
    dom_interactive,
    dom_content_loaded_event_start,
    dom_content_loaded_event_end,
    dom_complete,
    load_event_start,
    load_event_end,
};

/// Record `moment` - the current high resolution time of `realm`'s global -
/// in the load timing info of its associated Document. The caller says the
/// document is the one its window shows. "Update the current document
/// readiness" step 3 sets DOM interactive and DOM complete only once.
pub fn recordLoadTiming(realm: runtime.Context, moment: LoadTimingMoment) void {
    const timeline = timelineOf(realm) orelse return;
    const now_ms = now(realm) orelse return;
    const info = &timeline.load_timing;
    switch (moment) {
        .dom_interactive => if (info.dom_interactive == 0) {
            info.dom_interactive = now_ms;
        },
        .dom_complete => if (info.dom_complete == 0) {
            info.dom_complete = now_ms;
        },
        .dom_content_loaded_event_start => info.dom_content_loaded_event_start = now_ms,
        .dom_content_loaded_event_end => info.dom_content_loaded_event_end = now_ms,
        .load_event_start => info.load_event_start = now_ms,
        .load_event_end => {
            info.load_event_end = now_ms;
            // Navigation Timing 3.1: the entry's duration is loadEventEnd -
            // startTime, which an end time of loadEventEnd gives.
            if (timeline.navigation_entry) |entry| {
                if (dataOf(entry)) |data| data.end_time = now_ms;
            }
        },
    }
}

/// The load timing info of `realm`'s global's associated Document.
pub fn loadTimingOf(realm: runtime.Context) ?*const LoadTimingInfo {
    const timeline = timelineOf(realm) orelse return null;
    return &timeline.load_timing;
}

/// The navigation timing entry of `realm`'s global's associated Document,
/// if it has one.
pub fn navigationEntryOf(realm: runtime.Context) ?*Instance {
    const timeline = timelineOf(realm) orelse return null;
    return timeline.navigation_entry;
}

/// What a navigation hands "create the navigation timing entry": its fetch's
/// timing (as fetch reports it, initiator type aside), redirect count and
/// type.
pub const NavigationRecord = struct {
    report: *const fetch.internal.TimingReport,
    redirect_count: u16,
    navigation_type: NavigationType,
    /// The previous document's unload event start and end times, unsafe
    /// shared current time in ms (HTML "unload a document" steps 11/13); 0
    /// when there was none, or it was not same origin.
    unload_event_start: f64 = 0,
    unload_event_end: f64 = 0,
};

/// Navigation Timing 5 "create the navigation timing entry" for the
/// Document `realm`'s global has just been given (HTML "create and
/// initialize a Document object"), which also starts the document's load
/// timing info afresh.
pub fn createNavigationTimingEntry(realm: runtime.Context, record: NavigationRecord) !void {
    const timeline = timelineOf(realm) orelse return;
    const impl = hooks.navigation_timings orelse return error.NotSupported;
    // HTML "create and initialize a Document object": the load timing
    // info's navigation start time is the response's timing info's start
    // time, and it is the settings object's time origin - so it is set
    // first, and every time below is relative to it. (The Window, made
    // earlier or later than the fetch, recorded its creation as a stand-in.)
    if (record.report.timing_info.start_time != 0) {
        if (hooks.performances) |performances_impl| performances_impl.set_navigation_start(realm, record.report.timing_info.start_time);
    }
    // A new document: a new load timing info, made with readiness
    // "loading"; only the current document's entry is in the timeline.
    timeline.load_timing = .{ .dom_loading = now(realm) orelse 0 };
    if (timeline.navigation_entry) |previous| {
        const buffer = timeline.buffers.getPtr(.navigation);
        if (std.mem.indexOfScalar(*Instance, buffer.entries.items, previous)) |i| {
            _ = buffer.entries.orderedRemove(i);
            releaseEntry(timeline.owner, previous);
        }
        timeline.navigation_entry = null;
    }
    // 5. The previous document unload timing, relative to the new time
    // origin.
    const convert = FetchTimestampConverter{ .realm = realm };
    timeline.load_timing.unload_event_start = convert.call(record.unload_event_start);
    timeline.load_timing.unload_event_end = convert.call(record.unload_event_end);
    // 3. Setup the resource timing entry given "navigation", the document's
    // URL, fetchTiming, cacheMode and bodyInfo.
    var timing = try ResourceTiming.fromReport(timeline.allocator, record.report, convert);
    defer timing.deinit();
    timing.initiator_type = "navigation";
    // Navigation Timing 3.2: no redirects (or a cross-origin one, which
    // counts none), no redirect times.
    if (record.redirect_count == 0) {
        timing.redirect_start = 0;
        timing.redirect_end = 0;
    }
    // 3.1: startTime is 0, and the end time follows loadEventEnd.
    timing.start_time = 0;
    timing.end_time = 0;
    // 1-2, 4-11. A new PerformanceNavigationTiming in global's realm.
    const entry = try impl.create(realm, &timing, record.redirect_count, record.navigation_type);
    const generation = runtime.SlabAllocator.generationOf(entry);
    errdefer entry.releaseIfUnwrapped(generation);
    // 12. Add it to global's performance entry buffer.
    try timeline.buffers.getPtr(.navigation).entries.append(timeline.allocator, entry);
    holdEntry(timeline.owner, entry);
    // 9. The document's navigation timing entry.
    timeline.navigation_entry = entry;
}

/// Navigation Timing 5 "queue the navigation timing entry" for `realm`'s
/// global's associated Document (HTML "the end" step 9.13): Performance
/// Timeline 5.2 "queue a navigation PerformanceEntry".
pub fn queueNavigationTimingEntry(realm: runtime.Context) void {
    const timeline = timelineOf(realm) orelse return;
    const entry = timeline.navigation_entry orelse return;
    const data = dataOf(entry) orelse return;
    // Queued once.
    if (data.id != 0) return;
    // 1-4. A new id, which is also its navigationId.
    data.id = timeline.generateId();
    // 5. The document's most recent navigation.
    timeline.most_recent_navigation_id = data.id;
    // 6. Queue it (which sets navigationId from the most recent navigation).
    queueEntry(timeline, entry) catch {};
}

/// What PerformanceNavigationTiming supplies.
pub const NavigationTimings = struct {
    /// "create the navigation timing entry" steps 2-8: a new
    /// PerformanceNavigationTiming in `realm`, initialized (startTime 0,
    /// "navigation", `timing.url`), its resource timing set up from `timing`,
    /// with its redirect count and navigation type. The caller's until the
    /// engine wraps it.
    create: *const fn (realm: runtime.Context, timing: *const ResourceTiming, redirect_count: u16, navigation_type: NavigationType) anyerror!*Instance,
};

/// "setup the resource timing entry" for an entry of a
/// PerformanceResourceTiming type made elsewhere (see ResourceTimings.setup).
pub fn setupResourceTiming(entry: *Instance, timing: *const ResourceTiming) !void {
    const impl = hooks.resource_timings orelse return error.NotSupported;
    try impl.setup(entry, timing);
}

// ============================================================================
// Hooks
// ============================================================================

/// What Performance supplies.
pub const Performances = struct {
    /// The timeline of the global object of `realm`: its Performance's, made
    /// if the global has not made it yet; null for a global with none.
    of_realm: *const fn (realm: runtime.Context) ?*Timeline,
    /// The timeline `performance` (a Performance object) keeps.
    of_performance: *const fn (performance: *Instance) ?*Timeline,
    /// The current relative timestamp of `realm`'s global (its Performance's
    /// now()); null for a global with no Performance.
    now: *const fn (realm: runtime.Context) ?f64,
    /// HR-Time "relative high resolution coarse time" of `unsafe_ms` (a
    /// moment of the unsafe shared current time, in ms) for `realm`'s
    /// global: coarsened, then made relative to its time origin. Null for
    /// a global with no Performance.
    relative_coarse_time: *const fn (realm: runtime.Context, unsafe_ms: f64) ?f64,
    /// HR-Time "get time origin timestamp" for `realm`'s global (its
    /// Performance's timeOrigin, ms since the Unix epoch).
    time_origin_timestamp: *const fn (realm: runtime.Context) ?f64,
    /// The time origin of `realm`'s global becomes `unsafe_ms` (a moment of
    /// the unsafe shared current time, coarsened): HTML gives a document a
    /// navigation made the navigation's start time as its time origin (its
    /// load timing info's navigation start time). Before any of the
    /// document's script runs.
    set_navigation_start: *const fn (realm: runtime.Context, unsafe_ms: f64) void,
};

/// What PerformanceObserverEntryList supplies.
pub const EntryLists = struct {
    /// A new PerformanceObserverEntryList in `realm` whose entry list is a
    /// copy of `list`, keeping its entries. The caller's until the engine
    /// wraps it (Instance.releaseIfUnwrapped).
    create: *const fn (realm: runtime.Context, list: []const *Instance) anyerror!*Instance,
};

/// What PerformanceMeasure supplies.
pub const Measures = struct {
    /// A new PerformanceMeasure in `realm` named `measure_name` (copied),
    /// from `start_time` to `end_time`, whose detail is `detail` (BORROWED;
    /// null for null). The caller's until the engine wraps it.
    create: *const fn (realm: runtime.Context, measure_name: []const u8, start_time: f64, end_time: f64, detail: ?runtime.JSValue) anyerror!*Instance,
};

/// HTML "report an exception" for a global, which this module cannot reach
/// itself (src/html): installed by the observer's owner.
pub const ExceptionReporter = *const fn (global: *Instance, info: *const engine.ErrorInfo) void;

/// What the timeline's owners installed: each owner's own field.
const Hooks = struct {
    navigation_timings: ?NavigationTimings = null,
    resource_timings: ?ResourceTimings = null,
    entries: ?Entries = null,
    performances: ?Performances = null,
    entry_lists: ?EntryLists = null,
    measures: ?Measures = null,
    exception_reporter: ?ExceptionReporter = null,
};

// process-wide: function pointers the timeline's owners (Performance, PerformanceEntry, PerformanceObserver, PerformanceObserverEntryList, PerformanceMeasure) install once at process start (crane.Process), the same for every instance
var hooks: Hooks = .{};

/// Called by PerformanceNavigationTiming's installHooks, once, at process
/// start.
pub fn installNavigationTimings(impl: NavigationTimings) void {
    process_start.assertInstalling();
    hooks.navigation_timings = impl;
}

/// Called by PerformanceResourceTiming's installHooks, once, at process
/// start.
pub fn installResourceTimings(impl: ResourceTimings) void {
    process_start.assertInstalling();
    hooks.resource_timings = impl;
}

/// Called by PerformanceEntry's installHooks, once, at process start.
pub fn installEntries(impl: Entries) void {
    process_start.assertInstalling();
    hooks.entries = impl;
}

/// Called by Performance's installHooks, once, at process start.
pub fn installPerformances(impl: Performances) void {
    process_start.assertInstalling();
    hooks.performances = impl;
}

/// Called by PerformanceObserverEntryList's installHooks, once, at process
/// start.
pub fn installEntryLists(impl: EntryLists) void {
    process_start.assertInstalling();
    hooks.entry_lists = impl;
}

/// Called by PerformanceMeasure's installHooks, once, at process start.
pub fn installMeasures(impl: Measures) void {
    process_start.assertInstalling();
    hooks.measures = impl;
}

/// Called by PerformanceObserver's installHooks, once, at process start.
pub fn installExceptionReporter(reporter: ExceptionReporter) void {
    process_start.assertInstalling();
    hooks.exception_reporter = reporter;
}

/// The timeline of `realm`'s global object, or null.
pub fn timelineOf(realm: runtime.Context) ?*Timeline {
    const impl = hooks.performances orelse return null;
    return impl.of_realm(realm);
}

/// The timeline a Performance object keeps, or null.
fn timelineOfPerformance(performance: *Instance) ?*Timeline {
    const impl = hooks.performances orelse return null;
    return impl.of_performance(performance);
}

/// The time origin timestamp of `realm`'s global (ms since the Unix epoch),
/// or null.
pub fn timeOriginTimestamp(realm: runtime.Context) ?f64 {
    const impl = hooks.performances orelse return null;
    return impl.time_origin_timestamp(realm);
}

/// The current relative timestamp of `realm`'s global, or null.
pub fn now(realm: runtime.Context) ?f64 {
    const impl = hooks.performances orelse return null;
    return impl.now(realm);
}

/// A new PerformanceMeasure (see Measures.create).
pub fn createMeasure(realm: runtime.Context, measure_name: []const u8, start_time: f64, end_time: f64, detail: ?runtime.JSValue) !*Instance {
    const impl = hooks.measures orelse return error.NotSupported;
    return impl.create(realm, measure_name, start_time, end_time, detail);
}

// ============================================================================
// Tests
// ============================================================================

/// An entry for the tests: a stand-in instance and its attributes, found
/// from the instance by its field (no table at file scope: that would be
/// global state).
const TestEntry = struct {
    instance: Instance = undefined,
    data: EntryData = undefined,

    fn data_of(entry: *Instance) ?*EntryData {
        const self: *TestEntry = @fieldParentPtr("instance", entry);
        return &self.data;
    }

    fn initialize(entry: *Instance, start_time: f64, entry_type: EntryType, entry_name: []const u8, end_time: f64) anyerror!void {
        const d = data_of(entry) orelse return error.InvalidStateError;
        d.* = .{ .name = entry_name, .entry_type = entry_type, .start_time = start_time, .end_time = end_time };
    }
};

test "entry type identifiers are exact, and the supported ones are listed alphabetically" {
    try std.testing.expectEqual(EntryType.mark, EntryType.fromName("mark").?);
    try std.testing.expect(EntryType.fromName("Mark") == null);
    try std.testing.expect(EntryType.fromName("marks") == null);
    const supported = supportedEntryTypes(.window);
    try std.testing.expect(supported.len > 0);
    var i: usize = 1;
    while (i < supported.len) : (i += 1) {
        try std.testing.expect(std.mem.order(u8, supported[i - 1].name(), supported[i].name()) == .lt);
    }
}

test "a buffer is full at its maxBufferSize, and each entry it turns away is counted" {
    var buffer: Buffer = .{ .max_size = 1, .available_from_timeline = true };
    defer buffer.entries.deinit(std.testing.allocator);
    try std.testing.expect(!isBufferFull(&buffer));
    var instance: Instance = undefined;
    try buffer.entries.append(std.testing.allocator, &instance);
    try std.testing.expect(isBufferFull(&buffer));
    try std.testing.expect(isBufferFull(&buffer));
    try std.testing.expectEqual(@as(u64, 2), buffer.dropped_entries_count);
    var unbounded: Buffer = .{ .max_size = null, .available_from_timeline = true };
    try std.testing.expect(!isBufferFull(&unbounded));
}

test "filter buffer by name and type keeps matches in chronological order, ties in buffer order" {
    const saved = hooks.entries;
    defer hooks.entries = saved;
    hooks.entries = .{ .initialize = &TestEntry.initialize, .data = &TestEntry.data_of };
    var e: [4]TestEntry = .{ .{}, .{}, .{}, .{} };
    try initializeEntry(&e[0].instance, 5, .mark, "a", 0);
    try initializeEntry(&e[1].instance, 1, .mark, "b", 0);
    try initializeEntry(&e[2].instance, 5, .mark, "a", 0);
    try initializeEntry(&e[3].instance, 3, .measure, "a", 7);
    const buffer = [_]*Instance{ &e[0].instance, &e[1].instance, &e[2].instance, &e[3].instance };

    var result: std.ArrayListUnmanaged(*Instance) = .empty;
    defer result.deinit(std.testing.allocator);
    try filterBuffer(std.testing.allocator, &result, &buffer, null, null);
    try std.testing.expectEqualSlices(*Instance, &.{ &e[1].instance, &e[3].instance, &e[0].instance, &e[2].instance }, result.items);

    result.clearRetainingCapacity();
    try filterBuffer(std.testing.allocator, &result, &buffer, "a", "mark");
    try std.testing.expectEqualSlices(*Instance, &.{ &e[0].instance, &e[2].instance }, result.items);

    result.clearRetainingCapacity();
    try filterBuffer(std.testing.allocator, &result, &buffer, null, "Mark");
    try std.testing.expectEqual(@as(usize, 0), result.items.len);

    try std.testing.expectEqual(@as(f64, 4), dataOf(&e[3].instance).?.duration());
    try std.testing.expectEqual(@as(f64, 0), dataOf(&e[0].instance).?.duration());
}

test "observe() keeps only the supported entry types, so an unsupported list registers nothing" {
    // (observe() itself reaches engine operations, which this module's
    // test binary does not link; its reduction step is tested alone.)
    try std.testing.expectEqual(@as(usize, 0), supportedAmong(&.{ "Mark", "longtask-not-here" }, .window).count());
    const types = supportedAmong(&.{ "mark", "mark", "measure", "bogus" }, .window);
    try std.testing.expect(types.contains(.mark) and types.contains(.measure));
    try std.testing.expectEqual(@as(usize, 2), types.count());
}

test "the last performance entry id starts between 100 and 10000 and only grows" {
    var owner: Instance = undefined;
    var timeline = Timeline.init(std.testing.allocator, &owner);
    defer timeline.deinit();
    try std.testing.expect(timeline.last_entry_id >= 100 and timeline.last_entry_id <= 10000);
    const first = timeline.generateId();
    const second = timeline.generateId();
    try std.testing.expect(second > first);
}

test "navigation entries are a Window's alone; the other supported types are every global's" {
    const window_types = supportedEntryTypes(.window);
    const worker_types = supportedEntryTypes(.worker);
    try std.testing.expect(std.mem.indexOfScalar(EntryType, window_types, .navigation) != null);
    try std.testing.expect(std.mem.indexOfScalar(EntryType, worker_types, .navigation) == null);
    try std.testing.expect(std.mem.indexOfScalar(EntryType, worker_types, .resource) != null);
    try std.testing.expectEqual(@as(usize, 0), supportedAmong(&.{"navigation"}, .worker).count());
}

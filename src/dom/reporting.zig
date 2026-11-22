//! Reporting requests are started from queued tasks, never from inside a
//! violation finder or the network pump. The native client owns its request
//! until Fetch finishes it. No script promise or resource timing entry is made.
//!
//! Spec: CSP §5.5 step 3.4; Reporting §3.5.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const fetch = @import("fetch");
const engine = @import("engine");
const platform = @import("platform");
const csp = @import("csp");
const global_settings = @import("global_settings.zig");
const callback_sequences = @import("callback_sequences.zig");
const keepalive_fetch = @import("keepalive_fetch.zig");

/// Reporting §2.1: native immutable report data shared by the delivery
/// queue, buffer and observer queues. Each holder takes its own reference.
pub const Record = struct {
    allocator: std.mem.Allocator,
    references: usize = 1,
    type: []u8,
    url: []u8,
    destination: []u8,
    body_json: []u8,
    timestamp_ms: i64,
    user_agent: []u8,
    attempts: u64 = 0,

    pub const Init = struct {
        type: []const u8,
        url: []const u8,
        destination: []const u8,
        body_json: []const u8,
        timestamp_ms: i64,
        user_agent: []const u8,
    };

    pub fn create(allocator: std.mem.Allocator, value: Init) !*Record {
        const self = try allocator.create(Record);
        errdefer allocator.destroy(self);
        const kind = try allocator.dupe(u8, value.type);
        errdefer allocator.free(kind);
        const url = try allocator.dupe(u8, value.url);
        errdefer allocator.free(url);
        const destination = try allocator.dupe(u8, value.destination);
        errdefer allocator.free(destination);
        const body = try allocator.dupe(u8, value.body_json);
        errdefer allocator.free(body);
        self.* = .{
            .allocator = allocator,
            .type = kind,
            .url = url,
            .destination = destination,
            .body_json = body,
            .timestamp_ms = value.timestamp_ms,
            .user_agent = try allocator.dupe(u8, value.user_agent),
        };
        return self;
    }

    pub fn retain(self: *Record) void {
        self.references += 1;
    }

    pub fn release(self: *Record) void {
        self.references -= 1;
        if (self.references != 0) return;
        const allocator = self.allocator;
        allocator.free(self.type);
        allocator.free(self.url);
        allocator.free(self.destination);
        allocator.free(self.body_json);
        allocator.free(self.user_agent);
        allocator.destroy(self);
    }
};

/// Empty globals allocate nothing. Teardown only releases native data;
/// it never enters script or dereferences another platform object.
pub const State = struct {
    pending: std.ArrayListUnmanaged(*Record) = .empty,
    buffer: std.ArrayListUnmanaged(*Record) = .empty,
    delivery_queued: bool = false,
    observers: std.ArrayListUnmanaged(*Observer) = .empty,
    /// The environment's unloading document cleanup steps ran (its document
    /// was destroyed, or its worker ended: `endRegistrations`). Nothing
    /// keeps an observer for it from then on.
    ended: bool = false,
    /// The opener policy access monitors this window used (dom.coop_reporting
    /// .checkAccess): one per accessing top-level window and direction, as
    /// Chromium's one-shot CoopAccessMonitor ("used once and destroyed").
    access_monitors_used: std.ArrayListUnmanaged(AccessMonitor) = .empty,

    /// An accessing top-level window - by slab generation, so a window
    /// freed and its slot reissued is a new one - and which side's report.
    pub const AccessMonitor = struct {
        accessor: *runtime.Instance,
        generation: u64,
        direction: Direction,

        pub const Direction = enum { from_coop_page, to_coop_page };
    };

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        for (self.pending.items) |record| record.release();
        for (self.buffer.items) |record| record.release();
        self.pending.deinit(allocator);
        self.buffer.deinit(allocator);
        self.observers.deinit(allocator);
        self.access_monitors_used.deinit(allocator);
        self.* = .{};
    }

    /// Use this window's monitor for accesses from `accessor` (the accessing
    /// top-level window) in `direction`: true the first time, false once it
    /// was used.
    pub fn useAccessMonitor(self: *State, allocator: std.mem.Allocator, accessor: *runtime.Instance, direction: AccessMonitor.Direction) error{OutOfMemory}!bool {
        const generation = runtime.SlabAllocator.generationOf(accessor);
        for (self.access_monitors_used.items) |used| {
            if (used.accessor == accessor and used.generation == generation and used.direction == direction) return false;
        }
        try self.access_monitors_used.append(allocator, .{ .accessor = accessor, .generation = generation, .direction = direction });
        return true;
    }

    pub fn bufferReport(self: *State, allocator: std.mem.Allocator, record: *Record) !void {
        // Reporting §4.2 steps 2-4: cap each report type separately at 100.
        try self.buffer.ensureUnusedCapacity(allocator, 1);
        var count: usize = 0;
        var first: ?usize = null;
        for (self.buffer.items, 0..) |entry, i| {
            if (!std.mem.eql(u8, entry.type, record.type)) continue;
            count += 1;
            if (first == null) first = i;
        }
        if (count >= 100) self.buffer.orderedRemove(first.?).release();
        record.retain();
        self.buffer.appendAssumeCapacity(record);
    }
};

const Link = struct {
    instance: *runtime.Instance,
    generation: u64,

    fn of(instance: *runtime.Instance) Link {
        return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
    }
    fn isLive(self: Link) bool {
        return runtime.SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

pub fn globalOf(ctx: runtime.Context) ?*runtime.Instance {
    const realm = ctx.getRealm() orelse return null;
    return @ptrCast(@alignCast(realm.global_object orelse return null));
}

/// An unloading document cleanup step (dom.unloading_cleanup; the
/// ReportingObserver impl installs it), which also runs when a worker's
/// global scope ends: `environment`'s document is destroyed, so its
/// registered observers stop being registered and their keeps end, while
/// its realm's wrapper cache can still count them. The Reporting spec
/// defines no such step; the engines end the hold there. Blink: the
/// ActiveScriptWrappableManager keeps no wrapper whose ExecutionContext is
/// destroyed, "even if HasPendingActivity() returns true"
/// (active_script_wrappable_manager.cc ScriptWrappableIsActive), and
/// ReportingObserver::HasPendingActivity is its registration; Gecko clears
/// the global's mReportingObservers (nsIGlobalObject::UnlinkObjectsInGlobal);
/// WebKit's ReportingObserver::virtualHasPendingActivity reads its
/// ReportingScope through a WeakPtr. Nothing reports into a destroyed
/// environment, so no delivery is lost; observers registered later are not
/// kept (`State.ended`).
pub fn endRegistrations(environment: runtime.Context) void {
    const global = globalOf(environment) orelse return;
    const state = global_settings.reportingOf(global) orelse return;
    state.ended = true;
    var observers = state.observers;
    state.observers = .empty;
    defer observers.deinit(environment.allocator);
    for (observers.items) |observer| {
        observer.registered_on = null;
        observer.endKeep();
    }
}

/// Reporting §4: owned by ReportingObserver's impl, borrowed by its
/// global's registration list. The callback and native queue are owned.
pub const Observer = struct {
    allocator: std.mem.Allocator,
    instance: *runtime.Instance,
    callback: ?engine.CallbackFunction = null,
    types: std.ArrayListUnmanaged([]u8) = .empty,
    buffered: bool = false,
    queue: std.ArrayListUnmanaged(*Record) = .empty,
    registered_on: ?Link = null,
    /// observe() kept the observer's wrapper (engine.keepPlatformObjectAlive)
    /// and nothing has ended that keep yet. Separate from `registered_on`:
    /// an observer registered after its environment ended holds none
    /// (`observe`), and only a keep this says was taken is released.
    kept: bool = false,
    exception_reporter: *const fn (?*anyopaque, *const engine.ErrorInfo) void,

    /// The instance's teardown. It runs only once the observer's wrapper is
    /// gone - collected, or with its realm's end - and the keep, counted on
    /// that wrapper's cache entry, went with it: in a detached realm the
    /// keep is an edge from the global object (WrapperCache.detach), and
    /// the collector takes the observer with its global. So the teardown
    /// leaves the registration list and releases nothing. Releasing here
    /// ended a keep that no longer existed ("releasePlatformObject on
    /// ReportingObserver ... with no keepPlatformObjectAlive left to end",
    /// dozens of times per COEP reporting file in the Debug runner).
    pub fn deinit(self: *Observer) void {
        self.kept = false;
        self.disconnect();
        if (self.callback) |callback| callback.release();
        self.emptyQueue();
        self.queue.deinit(self.allocator);
        for (self.types.items) |name| self.allocator.free(name);
        self.types.deinit(self.allocator);
    }

    pub fn observe(self: *Observer) !void {
        const global = globalOf(self.instance.ctx) orelse return;
        const state = global_settings.reportingOf(global) orelse return;
        if (self.registered_on == null) {
            try state.observers.append(self.allocator, self);
            self.registered_on = Link.of(global);
        }
        // The registration keeps the observer (Blink ReportingObserver::
        // HasPendingActivity is `registered_`) - while its environment
        // lives: Blink's ActiveScriptWrappableManager keeps nothing of a
        // destroyed ExecutionContext (ScriptWrappableIsActive:
        // IsContextDestroyed). One keep however often observe() runs, taken
        // on the wrapper script called this on, whose cache entry counts it
        // (docs/lessons/architecture-a-keep-on-an-unwrapped-object-can-fail-silently.md).
        if (!self.kept and !state.ended and engine.hasWrapper(self.instance)) {
            engine.keepPlatformObjectAlive(self.instance);
            self.kept = true;
        }
        if (!self.buffered) return;
        self.buffered = false;
        // Synchronous buffering is shared by all three engines, unlike
        // observe() step 5's task per report: Blink ReportingContext::
        // RegisterObserver, WebKit ReportingScope::appendQueuedReportsForRelevantType,
        // Gecko nsIGlobalObject::RegisterReportingObserver.
        // Related aligned wpt.fyi cc74d2669f evidence:
        // content-security-policy/reporting-api/
        // reporting-api-sends-reports-on-violation.https.sub.html:
        // C154 3/4, F157 4/4, S27 4/4; runs 6218298311311360,
        // 4877098740350976, 5164107446878208 respectively. This delivery
        // file does not isolate these ordering/lifetime deviations;
        // the engine functions above establish synchronous buffering.
        for (state.buffer.items) |record| try self.addReport(record);
    }

    pub fn disconnect(self: *Observer) void {
        if (self.registered_on) |global| {
            self.registered_on = null;
            if (global.isLive()) {
                if (global_settings.reportingOf(global.instance)) |state| {
                    for (state.observers.items, 0..) |observer, index| {
                        if (observer != self) continue;
                        _ = state.observers.orderedRemove(index);
                        break;
                    }
                }
            }
        }
        // Reporting disconnect leaves the native report queue intact.
        self.endKeep();
    }

    /// End the one keep observe() took, if this observer holds it.
    fn endKeep(self: *Observer) void {
        if (!self.kept) return;
        self.kept = false;
        engine.releasePlatformObject(self.instance);
    }

    pub fn emptyQueue(self: *Observer) void {
        for (self.queue.items) |record| record.release();
        self.queue.clearRetainingCapacity();
    }

    pub fn takeRecords(self: *Observer, realm: runtime.Context) !engine.Owned {
        const result = try reportsToScript(realm, self.queue.items);
        self.emptyQueue();
        return result;
    }

    fn addReport(self: *Observer, record: *Record) !void {
        // §4.3 step 1 / CSP §5: hash reports are not visible to observers,
        // including when observe() visits the native report buffer.
        if (std.mem.eql(u8, record.type, "csp-hash")) return;
        // §4.3 steps 1-3: the empty types list observes all report types.
        if (self.types.items.len != 0) {
            var matches = false;
            for (self.types.items) |name| if (std.mem.eql(u8, name, record.type)) {
                matches = true;
                break;
            };
            if (!matches) return;
        }
        const first = self.queue.items.len == 0;
        try self.queue.append(self.allocator, record);
        record.retain();
        if (!first) return;
        // Without a task, undo this append so the next report can schedule one.
        errdefer self.queue.pop().?.release();
        // Browser majority (2-1), deviating from §4.3.4 / §4.4.1.1:
        // Blink core/frame/reporting_observer.cc QueueReport/ReportToCallback
        // and WebKit Modules/reporting/ReportingObserver.cpp
        // appendQueuedReportIfCorrectType queue per observer on empty→one,
        // and invoke even if takeRecords emptied the queue. Gecko
        // dom/reporting/ReportingObserver.cpp MaybeNotify skips empty queues.
        // The aligned reporting-api-sends-reports-on-violation counts above
        // cover delivery; these functions establish the empty-queue timing.
        const task = try self.allocator.create(ObserverTask);
        task.* = .{ .allocator = self.allocator, .observer = self, .link = Link.of(self.instance) };
        if (self.instance.ctx.getOptionalEventLoop()) |loop| {
            loop.queueTask(.{ .callback = ObserverTask.run, .context = task, .drop = ObserverTask.drop });
            return; // A queue handoff may already have dropped task.
        }
        // With no event loop there is nowhere to schedule a notification.
        // Never turn this asynchronous API into a synchronous callback.
        ObserverTask.drop(task);
    }
};

const ObserverTask = struct {
    allocator: std.mem.Allocator,
    observer: *Observer,
    // This is deliberately a weak task: Blink WrapWeakPersistent and
    // Gecko's registered-only notification beat WebKit's strong task (2-1).
    // A disconnected observer dropped by script must be collectible.
    // The aligned WPT delivery counts above do not test weak lifetime;
    // the engine ownership comparison establishes this behavior.
    link: Link,

    fn drop(data: ?*anyopaque) void {
        const self: *ObserverTask = @ptrCast(@alignCast(data.?));
        self.allocator.destroy(self);
    }
    fn run(data: ?*anyopaque) void {
        const self: *ObserverTask = @ptrCast(@alignCast(data.?));
        defer drop(data);
        if (!self.link.isLive() or !self.link.instance.ctx.hasEngine()) return;
        engine.runTaskInRealm(self.link.instance.ctx, steps, self) catch {};
    }
    fn steps(data: ?*anyopaque) void {
        const self: *ObserverTask = @ptrCast(@alignCast(data.?));
        self.notify() catch {};
    }
    fn notify(self: *ObserverTask) !void {
        const realm = self.link.instance.ctx;
        // A live weak target is rooted only on this executing stack, before
        // script conversion can collect. Nothing is retained while queued.
        const active = try engine.retainValue(realm, .{ .instance = self.link.instance });
        defer active.release();
        const observer = self.observer;
        const callback = observer.callback orelse return;
        // The reports are made in the callback's realm and world (WebIDL
        // invoke steps 5 and 10: dom.callback_sequences), not the observer's.
        const records = try observer.takeRecords(callback_sequences.argumentRealm(realm, &callback));
        defer records.release();
        const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = active.value }, &.{ records.value, active.value }, .{
            .report = .{ .report = observer.exception_reporter, .host = realm },
        });
        switch (completion) {
            inline else => |value| value.release(),
        }
    }
};

/// The single native-report -> script conversion point. For each record,
/// Reporting §4.3 step 3 "Create a new Report r with type initialized to
/// report's type, url initialized to report's url, and body initialized to
/// report's body", and WebIDL 3.2.18 converts r - a dictionary since
/// w3c/reporting#284 (the user's ruling of 2026-11-14; WebKit 326027@main) -
/// to a new ordinary object of `realm`; the reports go in a new Array
/// (3.2.27, sequence<Report>). Every call makes new objects: takeRecords()
/// returns "a copy of this's report queue" (§4.1) and the callback "a copy of
/// observer's report queue" (§4.4 step 1.2), each converted when it is
/// returned or passed.
fn reportsToScript(realm: runtime.Context, records: []const *Record) !engine.Owned {
    var made: Made = .{ .arena = .init(realm.allocator) };
    defer made.deinit();
    const values = try made.arena.allocator().alloc(runtime.JSValue, records.len);
    for (records, values) |record, *value| {
        const body = try bodyToScript(realm, record, &made);
        value.* = try dictionaryToScript(dictionaries.Report, realm, ReportMembers{ .record = record, .body = body }, &made);
    }
    return engine.createSequenceOfValues(realm, values);
}

/// What one conversion made that the object or Array it goes into has not
/// taken yet: the objects (each released once `reportsToScript` returns -
/// its parent holds it by then) and the parsed bodies, whose strings the
/// members borrow until their objects are made.
const Made = struct {
    arena: std.heap.ArenaAllocator,
    objects: std.ArrayListUnmanaged(engine.Owned) = .empty,

    /// Keep `object` until the conversion ends; its value, borrowed.
    fn keep(self: *Made, object: engine.Owned) !runtime.JSValue {
        self.objects.append(self.arena.allocator(), object) catch |err| {
            object.release();
            return err;
        };
        return object.borrow();
    }

    fn deinit(self: *Made) void {
        for (self.objects.items) |object| object.release();
        self.arena.deinit();
    }
};

/// The members of a Report dictionary (`dictionaries.Report`) that §4.3
/// step 3 initializes: all three, so each exists (a body of null too).
const ReportMembers = struct {
    record: *const Record,
    body: runtime.JSValue,

    fn member(self: ReportMembers, realm: runtime.Context, comptime name: []const u8, made: *Made) !?runtime.JSValue {
        _ = realm;
        _ = made;
        if (comptime std.mem.eql(u8, name, "type")) return runtime.JSValue.fromStringRef(self.record.type);
        if (comptime std.mem.eql(u8, name, "url")) return runtime.JSValue.fromStringRef(self.record.url);
        if (comptime std.mem.eql(u8, name, "body")) return self.body;
        @compileError("Reporting §4.3 step 3 initializes no Report member " ++ name);
    }
};

/// The members of a report body: its record's body, an object each
/// reporting spec initializes with the members it names ("Let body be a new
/// CSPViolationReportBody, initialized as follows", CSP §5.5 step 5.1;
/// Permissions Policy §9.13 step 1 names five of its seven) and that
/// dom.reporting keeps as JSON (`Record.body_json`, also the upload's body,
/// §2.4). A member exists - WebIDL 3.2.18 step 3.1.2 - when the body has it,
/// null included. Each value is the IDL value its generator wrote, of the
/// member's type, so it converts as its JSON kind: a string to a String, a
/// number to a Number, a boolean to a Boolean, null to null, an array (a
/// sequence) to an Array, an object (an `object` member) to an object.
const BodyMembers = struct {
    object: std.json.ObjectMap,

    fn member(self: BodyMembers, realm: runtime.Context, comptime name: []const u8, made: *Made) !?runtime.JSValue {
        const value = self.object.get(name) orelse return null;
        return try jsonToScript(realm, value, made);
    }
};

/// A body value as an ECMAScript value of `realm` (`BodyMembers`).
fn jsonToScript(realm: runtime.Context, value: std.json.Value, made: *Made) !runtime.JSValue {
    switch (value) {
        .null => return .null,
        .bool => |b| return .{ .boolean = b },
        .integer => |i| return .{ .number = @floatFromInt(i) },
        .float => |f| return .{ .number = f },
        .number_string => |s| return .{ .number = std.fmt.parseFloat(f64, s) catch std.math.nan(f64) },
        .string => |s| return runtime.JSValue.fromStringRef(s),
        .array => |items| {
            const values = try made.arena.allocator().alloc(runtime.JSValue, items.items.len);
            for (items.items, values) |item, *out| out.* = try jsonToScript(realm, item, made);
            return made.keep(try engine.createSequenceOfValues(realm, values));
        },
        .object => |object| {
            const members = try made.arena.allocator().alloc(engine.DictionaryMember, object.count());
            var entries = object.iterator();
            var count: usize = 0;
            while (entries.next()) |entry| : (count += 1) {
                members[count] = .{ .name = entry.key_ptr.*, .value = try jsonToScript(realm, entry.value_ptr.*, made) };
            }
            return made.keep(try engine.createDictionaryObject(realm, members));
        },
    }
}

/// The body dictionary of each report type visible to ReportingObservers
/// that names one dictionary: the specs' (pinned webref) and Crane's
/// specs/supplementary/report-bodies.idl. "coep" has two (`bodyToScript`).
const body_dictionaries = .{
    // CSP §5.5 step 5.1.
    .{ "csp-violation", dictionaries.CSPViolationReportBody },
    // Subresource Integrity, Integrity-Policy reporting.
    .{ "integrity-violation", dictionaries.IntegrityViolationReportBody },
    // Permissions Policy §9.13-9.14.
    .{ "permissions-policy-violation", dictionaries.PermissionsPolicyViolationReportBody },
    // Deprecation Reporting §2, Intervention Reporting §2, Crash Reporting.
    .{ "deprecation", dictionaries.DeprecationReportBody },
    .{ "intervention", dictionaries.InterventionReportBody },
    .{ "crash", dictionaries.CrashReportBody },
    // Reporting §7.1 (WebKit's TestReportBody).
    .{ "test", dictionaries.TestReportBody },
    // Chromium's access report (dom.coop_reporting).
    .{ "coop-access-violation", dictionaries.CoopAccessViolationReportBody },
};

/// Report.body: the record's body converted with its report type's
/// dictionary. Reporting §4.3 step 3 initializes it to "report's body" and
/// asks "how to polymorphically initialize body?"; the declared type,
/// ReportBody, has no member. WebKit, the engine that ships the
/// dictionaries, converts each body with its own dictionary
/// (Source/WebCore/Modules/reporting/Report.idl: body is a union of the body
/// dictionaries; ReportingObserver.cpp dictionaryForReportBody), and so does
/// this. A "coep" body is HTML's inheritance violation body
/// (COEPInheritenceViolationReportBody: "navigation", "worker
/// initialization") or Fetch's CORP violation body (CORPViolationReportBody:
/// "corp"), by its type member, as WebKit picks by the body it made. A type
/// with no body dictionary converts as ReportBody: an object with no member.
/// A body is null or an object (§2.1.3).
fn bodyToScript(realm: runtime.Context, record: *const Record, made: *Made) !runtime.JSValue {
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, made.arena.allocator(), record.body_json, .{});
    const object = switch (parsed) {
        .object => |object| object,
        else => return .null,
    };
    const source: BodyMembers = .{ .object = object };
    inline for (body_dictionaries) |entry| {
        if (std.mem.eql(u8, record.type, entry[0])) return dictionaryToScript(entry[1], realm, source, made);
    }
    if (std.mem.eql(u8, record.type, "coep")) {
        const coep_type: []const u8 = if (object.get("type")) |value| switch (value) {
            .string => |s| s,
            else => "",
        } else "";
        if (std.mem.eql(u8, coep_type, "corp")) return dictionaryToScript(dictionaries.CORPViolationReportBody, realm, source, made);
        return dictionaryToScript(dictionaries.COEPInheritenceViolationReportBody, realm, source, made);
    }
    return dictionaryToScript(dictionaries.ReportBody, realm, source, made);
}

/// WebIDL 3.2.18, an IDL dictionary value to an ECMAScript value: a new
/// ordinary object of `realm` (step 1) with the members of dictionary `D` -
/// codegen's struct of it - its inherited dictionaries' first, each
/// dictionary's in lexicographical order (step 2), each defined only when
/// it exists (step 3.1.2: `source.member` answers its value, or null when it
/// does not exist).
fn dictionaryToScript(comptime D: type, realm: runtime.Context, source: anytype, made: *Made) !runtime.JSValue {
    const names = comptime memberNames(D);
    var members: [names.len]engine.DictionaryMember = undefined;
    var count: usize = 0;
    inline for (names) |name| {
        if (try source.member(realm, name, made)) |value| {
            members[count] = .{ .name = name, .value = value };
            count += 1;
        }
    }
    return made.keep(try engine.createDictionaryObject(realm, members[0..count]));
}

/// Whether field `name` of codegen's dictionary struct `D` holds the
/// inherited dictionary: codegen names it `base` and types it with the
/// inherited dictionary's struct (a member called `base` is an optional).
fn isInheritedDictionary(comptime D: type, comptime name: []const u8) bool {
    return std.mem.eql(u8, name, "base") and @typeInfo(@FieldType(D, name)) == .@"struct";
}

fn memberCount(comptime D: type) usize {
    comptime {
        var count: usize = 0;
        for (std.meta.fieldNames(D)) |name| {
            count += if (isInheritedDictionary(D, name)) memberCount(@FieldType(D, name)) else 1;
        }
        return count;
    }
}

/// Dictionary `D`'s members in WebIDL 3.2.18 step 2's order: from the least
/// derived dictionary to `D`, each one's members in lexicographical order.
fn memberNames(comptime D: type) [memberCount(D)][]const u8 {
    comptime {
        @setEvalBranchQuota(20_000);
        var names: [memberCount(D)][]const u8 = undefined;
        var count: usize = 0;
        for (std.meta.fieldNames(D)) |name| {
            if (!isInheritedDictionary(D, name)) continue;
            for (memberNames(@FieldType(D, name))) |inherited| {
                names[count] = inherited;
                count += 1;
            }
        }
        const own = count;
        for (std.meta.fieldNames(D)) |name| {
            if (isInheritedDictionary(D, name)) continue;
            names[count] = name;
            count += 1;
        }
        std.sort.insertion([]const u8, names[own..], {}, struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lessThan);
        return names;
    }
}

/// Reporting §2.1 "serialize a list of reports to JSON", steps 1-4.
/// Nested bodies remain objects; successful serialization is an attempt.
pub fn serializeReports(allocator: std.mem.Allocator, records: []const *Record, now_ms: i64) ![]u8 {
    const Entry = struct { age: i64, type: []const u8, url: []const u8, user_agent: []const u8, body: std.json.Value };
    const entries = try allocator.alloc(Entry, records.len);
    defer allocator.free(entries);
    var bodies: std.ArrayListUnmanaged(std.json.Parsed(std.json.Value)) = .empty;
    defer {
        for (bodies.items) |body| body.deinit();
        bodies.deinit(allocator);
    }
    try bodies.ensureTotalCapacity(allocator, records.len);
    for (records, entries) |record, *entry| {
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, record.body_json, .{});
        bodies.appendAssumeCapacity(parsed);
        entry.* = .{
            .age = @max(0, now_ms - record.timestamp_ms),
            .type = record.type,
            .url = record.url,
            .user_agent = record.user_agent,
            .body = parsed.value,
        };
    }
    const bytes = try std.json.Stringify.valueAlloc(allocator, entries, .{});
    for (records) |record| record.attempts +|= 1;
    return bytes;
}

/// Reporting §3.4.1: snapshot native report data, notify observers, then
/// append it to the global's delivery queue. No network pump is entered here.
pub fn generate(global: *runtime.Instance, kind: []const u8, destination: []const u8, report_url: []const u8, body_json: []const u8) !void {
    const state = global_settings.reportingOf(global) orelse return;
    const allocator = global.ctx.allocator;
    const record = try Record.create(allocator, .{
        .type = kind,
        .destination = destination,
        .url = report_url,
        .body_json = body_json,
        .timestamp_ms = platform.wallMillis(),
        // §3.4.1 step 7: "the value of navigator.userAgent" - the global's
        // Browser's user agent string.
        .user_agent = if (@import("browser_state.zig").networkOf(global.ctx)) |network| network.userAgent() else fetch.internal.user_agent.default_user_agent,
    });
    defer record.release();
    // §4.2: the registered list is borrowed; addReport queues tasks but
    // invokes no script on a live event loop.
    for (state.observers.items) |observer| observer.addReport(record) catch {};
    try state.bufferReport(allocator, record);
    try state.pending.append(allocator, record);
    record.retain();
    if (state.delivery_queued) return;
    const loop = global.ctx.getOptionalEventLoop() orelse return;
    const task = try allocator.create(DeliveryTask);
    task.* = .{ .allocator = allocator, .global = Link.of(global) };
    state.delivery_queued = true;
    loop.queueTask(.{ .callback = DeliveryTask.run, .context = task, .drop = DeliveryTask.drop });
}

/// A report made for a URL with no settings object: what the queue for an
/// endpoint list (`queueForEndpoint`) takes. Every field is borrowed for
/// the call.
pub const Detached = struct {
    /// The report type ("coop", "csp-violation").
    type: []const u8,
    /// The URL the report is made for - the policy's document's, or its
    /// response's - unstripped: the report's url is its stripping
    /// (Reporting "generate a report" step 4) and the upload's origin its
    /// origin (§3.5.1 step 3.2).
    url: []const u8,
    /// The endpoint name (the report's destination).
    destination: []const u8,
    body_json: []const u8,
    /// The endpoint list `destination` names an endpoint in: the
    /// Reporting-Endpoints of the policy's response or document. Null, or a
    /// list without the name: nothing is queued.
    endpoints: ?*fetch.internal.policy_container.Endpoints,
    /// Start the upload as a request its agent keeps from the start
    /// (keepalive_fetch.startKept): the sender's document may be going -
    /// the document a navigation report describes is being navigated away
    /// from. Chromium sends these from the network service
    /// (NetworkContext::QueueReport), whatever becomes of the document.
    kept: bool = false,
};

/// HTML's "queue body as type for endpoint with url" - a report of a
/// policy whose global does not exist or is going, with no settings object
/// (COOP's navigation reports, 7.1.3.3; CSP's response-policy violations,
/// csp_violations.reportNavigationResponse). Reporting no longer defines
/// that form: it renamed "queue a report" to "generate and queue a report"
/// (w3c/reporting 334a96b9, 2022) and removed generate-a-report's optional
/// URL (57e73b58, 2026-01-02). The engines resolve the endpoint name
/// against the policy's document's endpoints and send from outside the
/// document: Chromium NetworkContext::QueueReport(type, endpoint, url,
/// reporting_source), WebKit Document::sendReportToEndpoints(coopURL, {},
/// tokens). So does this: the endpoint is resolved now, against `report`'s
/// list; the report (§2.1.3's fields, its url stripped) is uploaded by a
/// task queued on `sender`'s event loop with §3.5.2's client-null request -
/// `sender` gives transport only (its Browser's network and cookie jar),
/// never report data. Not visible to ReportingObservers: there is no
/// settings object to notify. Nothing is queued without a matching
/// endpoint or an event loop.
pub fn queueForEndpoint(sender: *runtime.Instance, report: Detached) !void {
    const endpoints = report.endpoints orelse return;
    const endpoint = endpoints.find(report.destination) orelse return;
    const loop = sender.ctx.getOptionalEventLoop() orelse return;
    const allocator = sender.ctx.allocator;
    const task = try allocator.create(DetachedTask);
    task.* = .{ .allocator = allocator, .sender = Link.of(sender), .kept = report.kept };
    errdefer task.deinit();
    task.endpoint_url = try allocator.dupe(u8, endpoint.url);
    task.origin = try fetch.internal.origins.serializedOriginOf(allocator, report.url);
    const url = try csp.violation_events.stripUrlForReports(allocator, report.url);
    defer allocator.free(url);
    task.record = try Record.create(allocator, .{
        .type = report.type,
        .destination = report.destination,
        .url = url,
        .body_json = report.body_json,
        .timestamp_ms = platform.wallMillis(),
        .user_agent = if (@import("browser_state.zig").networkOf(sender.ctx)) |network| network.userAgent() else fetch.internal.user_agent.default_user_agent,
    });
    loop.queueTask(.{ .callback = DetachedTask.run, .context = task, .drop = DetachedTask.drop });
}

/// `queueForEndpoint`'s upload: Reporting §3.5.2 for one report, its
/// endpoint and origin copied when it was queued.
const DetachedTask = struct {
    allocator: std.mem.Allocator,
    sender: Link,
    kept: bool,
    endpoint_url: []const u8 = "",
    origin: []const u8 = "",
    record: ?*Record = null,

    fn deinit(self: *DetachedTask) void {
        const allocator = self.allocator;
        allocator.free(self.endpoint_url);
        allocator.free(self.origin);
        if (self.record) |record| record.release();
        allocator.destroy(self);
    }
    fn drop(data: ?*anyopaque) void {
        const self: *DetachedTask = @ptrCast(@alignCast(data.?));
        self.deinit();
    }
    fn run(data: ?*anyopaque) void {
        const self: *DetachedTask = @ptrCast(@alignCast(data.?));
        defer self.deinit();
        if (!self.sender.isLive() or !self.sender.instance.ctx.hasEngine()) return;
        engine.runTaskInRealm(self.sender.instance.ctx, steps, self) catch {};
    }
    fn steps(data: ?*anyopaque) void {
        const self: *DetachedTask = @ptrCast(@alignCast(data.?));
        self.send() catch {};
    }
    fn send(self: *DetachedTask) !void {
        const record = self.record orelse return;
        const sender = self.sender.instance;
        const bytes = try serializeReports(self.allocator, &.{record}, platform.wallMillis());
        defer self.allocator.free(bytes);
        const request = try modernRequest(self.allocator, self.endpoint_url, self.origin, bytes);
        // Client-null reports still use their Browser's network
        // configuration and cookie jar, as the delivery task does.
        request.cookie_jar = global_settings.cookieJarOf(sender);
        request.network = @import("browser_state.zig").networkOf(sender.ctx);
        // Both take the request on every path.
        if (self.kept) {
            try keepalive_fetch.startKept(sender, request, .ping);
        } else {
            _ = try keepalive_fetch.send(sender, request, .{ .load = .ping });
        }
    }
};

pub fn reportDestination(directive: *const csp.Directive) []const u8 {
    // Browser deviation from CSP §6.5.2's single-token grammar: Chromium
    // ParseReportDirective and Gecko nsCSPParser::reportGroup use the first
    // token, ignoring later ones. WebKit parseReportTo retains them all.
    // report-to-only-sends-reports-to-first-endpoint: C154/F157 3/3, S27 2/3
    // at wpt.fyi cc74d2669f. Presence still suppresses report-uri (§5.5).
    const values = directive.value.expressions.items;
    return if (values.len != 0) values[0].raw_value else "";
}

test "report-to names its first token while presence suppresses legacy reporting" {
    for ([_][2][]const u8{ .{ "report-to first second", "first" }, .{ "report-to", "" } }) |case| {
        var policy = try csp.parsing.parseSerializedCSP(std.testing.allocator, case[0], .header, .enforce);
        defer policy.deinit();
        const directive = policy.getDirective("report-to").?;
        try std.testing.expectEqualStrings(case[1], reportDestination(directive));
    }
}

/// CSP §6.7.1.2 step 1.1 and §4.1.4, at script-client body completion.
/// Both arguments are borrowed during AsyncFetch's done callback. It is
/// still pumping: generate() queues delivery and never starts another fetch.
pub fn reportScriptFetch(realm: runtime.Context, active: ?*fetch.algorithms.AsyncFetch, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
    reportScriptFetchFallible(realm, active, outcome) catch {};
}

fn reportScriptFetchFallible(realm: runtime.Context, active: ?*fetch.algorithms.AsyncFetch, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) !void {
    const global = globalOf(realm) orelse return;
    // §4.1.4 step 9: Window only. The client owns a live realm here.
    if (!std.mem.eql(u8, global.vtable.name, "Window")) return;
    const transport = active orelse return;
    const request = transport.job.request;
    const container = switch (request.policy_container) {
        .client => return,
        .container => |*value| value,
    };
    const result = outcome catch return;
    const response = result.response;
    if (response.response_type == .@"error") return;
    const destination = if (request.destination == .empty) "" else @tagName(request.destination);
    const effective = csp.request_check.effectiveDirective(.{ .url = .ofSerialized(request.getUrl()), .destination = destination }) orelse return;
    if (!std.mem.eql(u8, effective, "script-src-elem")) return;
    for (container.csp_list.policies.items) |*policy| {
        const report_to = policy.getDirective("report-to") orelse continue;
        for (csp.request_check.fallbackList(effective)) |name| {
            const directive = policy.getDirective(name) orelse continue;
            // No report-sha keyword: no allocations, including no URL copy.
            if (csp.hash.reportingAlgorithm(&directive.value) == null) break;
            const readable = response.response_type == .basic or response.response_type == .cors or response.response_type == .default;
            const bytes: ?[]const u8 = if (readable) (if (response.body) |body| body.getBytes() else "") else null;
            const hash = (try csp.hash.hashForReport(realm.allocator, &directive.value, bytes)).?;
            defer realm.allocator.free(hash);
            const document_url = try csp.violation_events.stripUrlForReports(realm.allocator, realm.documentUrl() orelse "");
            defer realm.allocator.free(document_url);
            // Browser deviation from CSP §4.1.4 step 13: Blink ReportHashes
            // (content_security_policy.cc:787-791) and WebKit
            // reportHashesIfNeeded (SubresourceIntegrity.cpp:248-249) strip
            // credentials and fragments, preserving even cross-origin paths.
            const subresource_url = try csp.violation_events.stripUrlForReports(realm.allocator, request.getUrl());
            defer realm.allocator.free(subresource_url);
            const body_json = try std.json.Stringify.valueAlloc(realm.allocator, .{
                .documentURL = document_url,
                .subresourceURL = subresource_url,
                .hash = hash,
                .type = "subresource",
                .destination = destination,
            }, .{});
            defer realm.allocator.free(body_json);
            try generate(global, "csp-hash", reportDestination(report_to), document_url, body_json);
            break;
        }
    }
}

fn endpointsOf(global: *runtime.Instance) ?*fetch.internal.policy_container.Endpoints {
    const settings = global_settings.of(global) orelse return null;
    const get = settings.policy_container orelse return null;
    const container = get(global) orelse return null;
    return container.endpoints;
}

const DeliveryTask = struct {
    allocator: std.mem.Allocator,
    global: Link,

    fn drop(data: ?*anyopaque) void {
        const self: *DeliveryTask = @ptrCast(@alignCast(data.?));
        if (self.global.isLive()) {
            if (global_settings.reportingOf(self.global.instance)) |state| state.delivery_queued = false;
        }
        self.allocator.destroy(self);
    }
    fn run(data: ?*anyopaque) void {
        const self: *DeliveryTask = @ptrCast(@alignCast(data.?));
        defer drop(data);
        if (!self.global.isLive() or !self.global.instance.ctx.hasEngine()) return;
        self.send() catch {};
    }
    fn send(self: *DeliveryTask) !void {
        const global = self.global.instance;
        const state = global_settings.reportingOf(global) orelse return;
        var pending = state.pending;
        state.pending = .empty;
        state.delivery_queued = false;
        defer {
            for (pending.items) |record| record.release();
            pending.deinit(self.allocator);
        }
        const endpoints = endpointsOf(global) orelse return;
        const grouped = try self.allocator.alloc(bool, pending.items.len);
        defer self.allocator.free(grouped);
        @memset(grouped, false);
        // §3.5.1 steps 1-3: partition by endpoint and report-URL origin.
        for (pending.items, 0..) |first, index| {
            if (grouped[index]) continue;
            const endpoint = endpoints.find(first.destination) orelse continue;
            const origin = try fetch.internal.origins.serializedOriginOf(self.allocator, first.url);
            defer self.allocator.free(origin);
            var batch: std.ArrayListUnmanaged(*Record) = .empty;
            defer batch.deinit(self.allocator);
            for (pending.items[index..], index..) |record, j| {
                if (grouped[j] or !std.mem.eql(u8, first.destination, record.destination)) continue;
                const candidate_origin = try fetch.internal.origins.serializedOriginOf(self.allocator, record.url);
                defer self.allocator.free(candidate_origin);
                if (!std.mem.eql(u8, origin, candidate_origin)) continue;
                try batch.append(self.allocator, record);
                grouped[j] = true;
            }
            const bytes = try serializeReports(self.allocator, batch.items, platform.wallMillis());
            defer self.allocator.free(bytes);
            const request = try modernRequest(self.allocator, endpoint.url, origin, bytes);
            request.cookie_jar = global_settings.cookieJarOf(global);
            request.network = @import("browser_state.zig").networkOf(global.ctx);
            // start takes the request on every path, and snapshots the
            // endpoint before any asynchronous completion can mutate it.
            Upload.start(global, request, endpoint.name, endpoint.url) catch {
                endpoint.failures +|= 1;
            };
        }
    }
};

/// Reporting §3.5.2 step 2: a client-null CORS request. In particular its
/// CSP container is NOT copied from the reporting document.
pub fn modernRequest(allocator: std.mem.Allocator, endpoint: []const u8, origin: []const u8, bytes: []const u8) !*fetch.internal.InternalRequest {
    const request = try fetch.internal.InternalRequest.init(allocator, endpoint);
    errdefer request.deinit();
    try request.setMethod("POST");
    try request.setOrigin(origin);
    try request.header_list.set("Content-Type", "application/reports+json");
    const body = try fetch.internal.Body.fromBytes(allocator, bytes);
    body.source = .{ .bytes = body.data.items };
    request.body = .{ .body = body };
    request.destination = .report;
    request.mode = .cors;
    request.credentials_mode = .same_origin;
    request.unsafe_request = true;
    request.service_workers_mode = .none;
    request.traversable_for_user_prompts = .no_traversable;
    return request;
}

/// Reporting §3.5.2 steps 5-7 for one upload: what it needs of its endpoint
/// when the response comes, copied, because the endpoint list can change
/// while the upload is in flight. The fetch is a dom.keepalive_fetch
/// dispatch, which frees itself - and this with it - when the fetch ends,
/// with no document-abort registry. Like fetch({keepalive:true}) today,
/// retirement of its realm still terminates it. Surviving that needs an
/// agent-level owner; retaining a dead global would not provide one.
const Upload = struct {
    allocator: std.mem.Allocator,
    global: Link,
    name: []const u8,
    url: []const u8,

    /// Takes request on every path, and copies the endpoint's borrowed
    /// strings. Not started (an error) counts as the endpoint's failure.
    fn start(global: *runtime.Instance, request: *fetch.internal.InternalRequest, name: []const u8, url: []const u8) !void {
        const allocator = global.ctx.allocator;
        var owns_request = true;
        defer if (owns_request) request.deinit();
        const self = try allocator.create(Upload);
        errdefer allocator.destroy(self);
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);
        self.* = .{ .allocator = allocator, .global = Link.of(global), .name = owned_name, .url = owned_url };
        owns_request = false;
        const dispatch = try keepalive_fetch.start(global, request, .{ .observer = .{ .context = self, .response = response, .ended = ended } });
        // Rejected: nothing was sent, and the observer will hear nothing.
        if (dispatch == null) return error.NetworkError;
    }
    fn response(context: *anyopaque, status: u16) void {
        const self: *Upload = @ptrCast(@alignCast(context));
        if (!self.global.isLive() or !self.global.instance.ctx.hasEngine()) return;
        const endpoints = endpointsOf(self.global.instance) orelse return;
        const endpoint = endpoints.find(self.name) orelse return;
        if (!std.mem.eql(u8, endpoint.url, self.url)) return;
        // §3.5.2 steps 5-7 / §3.5.1 step 3.3: success, removal, failure.
        if (status == 410) endpoints.remove(self.name, self.url) else if (status < 200 or status > 299) endpoint.failures +|= 1;
    }
    fn ended(context: *anyopaque) void {
        const self: *Upload = @ptrCast(@alignCast(context));
        self.allocator.free(self.name);
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }
};

/// CSP §5.5 step 3.4.2.1: parse an endpoint relative to the violation's URL,
/// not the document's possibly changed base URL. The result is owned by the
/// caller using global.ctx.allocator. A bad URL is simply skipped.
pub fn parseEndpoint(global: *runtime.Instance, value: []const u8, base: []const u8) !?[]const u8 {
    const parsed = (try interfaces.URL.call_static_parse(global, value, webidl.Opt(runtime.USVString).passed(base))) orelse return null;
    defer runtime.Instance.deinit(parsed);
    return try interfaces.URL.get_href(parsed);
}

/// CSP §5.5 step 3.4.2.3: create the legacy report request. It owns its body
/// bytes, origin and policy snapshot. Every input is borrowed for this call.
pub fn legacyRequest(
    allocator: std.mem.Allocator,
    endpoint: []const u8,
    bytes: []const u8,
    client: fetch.internal.RequestClient,
) !*fetch.internal.InternalRequest {
    const request = try fetch.internal.InternalRequest.init(allocator, endpoint);
    errdefer request.deinit();
    try request.setMethod("POST");
    try request.header_list.set("Content-Type", "application/csp-report");
    const body = try fetch.internal.Body.fromBytes(allocator, bytes);
    // fromBytes copies data but borrows its source. Both must name the
    // owned copy after the caller releases the serialization.
    body.source = .{ .bytes = body.data.items };
    request.body = .{ .body = body };
    request.destination = .report;
    request.mode = .no_cors;
    request.credentials_mode = .same_origin;
    request.keepalive = true;
    request.redirect_mode = .@"error";
    request.traversable_for_user_prompts = .no_traversable;
    try fetch.internal.populateRequestFromClient(request, client);
    // The initiator stays empty and initiator_type stays null: a report
    // upload is not a page resource and creates no Resource Timing entry.
    return request;
}

/// CSP §5.5 step 3.4.2.4. Called only from the violation's queued task.
pub fn sendLegacy(global: *runtime.Instance, endpoint: []const u8, bytes: []const u8) !void {
    var client = try global_settings.requestClient(global);
    defer client.deinit();
    const request = try legacyRequest(global.ctx.allocator, endpoint, bytes, client.request);
    // send takes the request even if starting the fetch fails. A ping
    // load: exempt from the fetch group's keepalive budget, as WebKit and
    // Gecko send CSP reports (keepalive_fetch.Load).
    _ = try keepalive_fetch.send(global, request, .{ .load = .ping });
}

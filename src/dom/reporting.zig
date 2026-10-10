//! Reporting requests are started from queued tasks, never from inside a
//! violation finder or the network pump. The native client owns its request
//! until Fetch finishes it. No script promise or resource timing entry is made.
//!
//! Spec: CSP §5.5 step 3.4; Reporting §3.5.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const fetch = @import("fetch");
const engine = @import("engine");
const platform = @import("platform");
const csp = @import("csp");
const global_settings = @import("global_settings.zig");

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

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        for (self.pending.items) |record| record.release();
        for (self.buffer.items) |record| record.release();
        self.pending.deinit(allocator);
        self.buffer.deinit(allocator);
        self.observers.deinit(allocator);
        self.* = .{};
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
    exception_reporter: *const fn (?*anyopaque, *const engine.ErrorInfo) void,

    pub fn deinit(self: *Observer) void {
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
            engine.keepPlatformObjectAlive(self.instance);
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
        const global = self.registered_on orelse return;
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
        // Reporting disconnect leaves the native report queue intact.
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
        const records = try observer.takeRecords(realm);
        defer records.release();
        const callback = observer.callback orelse return;
        const completion = try engine.invokeCallbackFunction(realm, &callback, .{ .value = active.value }, &.{ records.value, active.value }, .{
            .report = .{ .report = observer.exception_reporter, .host = realm },
        });
        switch (completion) {
            inline else => |value| value.release(),
        }
    }
};

/// The single native-report → script conversion point. The pinned webref
/// currently models Report/ReportBody as dictionaries; an eventual interface
/// implementation replaces this function, not the queues or delivery path.
fn reportToScript(realm: runtime.Context, record: *const Record) !engine.Owned {
    const body = try engine.parseJsonToValue(realm, record.body_json);
    defer body.release();
    return engine.createDictionaryObject(realm, &.{
        .{ .name = "type", .value = .{ .string = .{ .data = record.type, .owned = false } } },
        .{ .name = "url", .value = .{ .string = .{ .data = record.url, .owned = false } } },
        .{ .name = "body", .value = body.value },
    });
}

fn reportsToScript(realm: runtime.Context, records: []const *Record) !engine.Owned {
    const values = try realm.allocator.alloc(runtime.JSValue, records.len);
    defer realm.allocator.free(values);
    var converted: std.ArrayListUnmanaged(engine.Owned) = .empty;
    defer {
        for (converted.items) |value| value.release();
        converted.deinit(realm.allocator);
    }
    try converted.ensureTotalCapacity(realm.allocator, records.len);
    for (records, values) |record, *value| {
        const object = try reportToScript(realm, record);
        converted.appendAssumeCapacity(object);
        value.* = object.value;
    }
    return engine.createSequenceOfValues(realm, values);
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
        .user_agent = fetch.internal.user_agent.default_user_agent,
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
            // start takes the request on every path, and snapshots the
            // endpoint before any asynchronous completion can mutate it.
            Pending.start(global.ctx, request, .{ .global = Link.of(global), .name = endpoint.name, .url = endpoint.url }) catch {
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

/// Self-freeing AsyncFetch client (the html.hyperlink_auditing.Pending
/// pattern), with no document-abort registry. Like fetch({keepalive:true})
/// today, retirement of its realm still terminates it. Surviving that needs
/// an agent-level owner; retaining a dead global would not provide one.
const Pending = struct {
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    endpoint: ?Endpoint = null,
    active: ?*fetch.algorithms.AsyncFetch = null,

    const Endpoint = struct { global: Link, name: []const u8, url: []const u8 };

    /// Takes request on every path, and copies endpoint's borrowed strings.
    fn start(ctx: runtime.Context, request: *fetch.internal.InternalRequest, endpoint: ?Endpoint) !void {
        const allocator = ctx.allocator;
        var owns_request = true;
        defer if (owns_request) request.deinit();
        const self = try allocator.create(Pending);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .ctx = ctx };
        if (endpoint) |value| {
            const name = try allocator.dupe(u8, value.name);
            errdefer allocator.free(name);
            const url = try allocator.dupe(u8, value.url);
            self.endpoint = .{ .global = value.global, .name = name, .url = url };
        }
        errdefer self.freeEndpoint();
        owns_request = false;
        self.active = try fetch.algorithms.AsyncFetch.start(allocator, request, .{}, fetch.network.scheduler.threadScheduler(), .{
            .context = self,
            .done = done,
            .alive = alive,
            .gone = finish,
            .finished = finish,
        });
    }
    fn alive(context: *anyopaque) bool {
        const self: *Pending = @ptrCast(@alignCast(context));
        return self.ctx.hasEngine();
    }
    fn done(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
        const self: *Pending = @ptrCast(@alignCast(context));
        const status: u16 = blk: {
            var result = outcome catch break :blk 0;
            defer result.deinit();
            break :blk result.response.status;
        };
        const identity = self.endpoint orelse return;
        if (!identity.global.isLive() or !self.ctx.hasEngine()) return;
        const endpoints = endpointsOf(identity.global.instance) orelse return;
        const endpoint = endpoints.find(identity.name) orelse return;
        if (!std.mem.eql(u8, endpoint.url, identity.url)) return;
        // §3.5.2 steps 5-7 / §3.5.1 step 3.3: success, removal, failure.
        if (status == 410) endpoints.remove(identity.name, identity.url) else if (status < 200 or status > 299) endpoint.failures +|= 1;
    }
    fn freeEndpoint(self: *Pending) void {
        if (self.endpoint) |endpoint| {
            self.allocator.free(endpoint.name);
            self.allocator.free(endpoint.url);
        }
    }
    fn finish(context: *anyopaque) void {
        const self: *Pending = @ptrCast(@alignCast(context));
        self.active = null;
        self.freeEndpoint();
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
    // Pending.start takes the request even if starting the fetch fails.
    try Pending.start(global.ctx, request, null);
}

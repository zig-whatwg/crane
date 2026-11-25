//! InstallEvent.addRoutes(rules) (Service Workers 4.5.1), in the service
//! worker's realm: its argument converted - it reaches the impl as the
//! binding's value (codegen's argument_unions: the last argument keeps its
//! JSValue), so the WebIDL union and dictionary conversions run here - into
//! router.zig's engine-free rules, each verified (Verify Router Condition,
//! its URL patterns parsed with the worker's script URL as base), the event's
//! lifetime extended, and the rules enqueued to the worker's [[service worker
//! queue]] - the Browser's job thread (manager.addRoutesNow), which checks
//! the registration limit, sets the list, and settles the promise here.
//!
//! The rules are made with the manager's allocator: they cross to the job
//! thread, and the fetching threads read them. A condition's URL pattern is
//! a urlpattern.URLPattern of its own (`patternOps` frees it); Handle Fetch
//! matches it in a realm of the fetching thread (realm.zig).
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dom-installevent-addroutes
//! Spec: https://urlpattern.spec.whatwg.org/#build-a-url-pattern-from-a-web-idl-value

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const enums = @import("enums");
const dom = @import("dom");
const urlpattern = @import("urlpattern");
const router = @import("router.zig");
const realm_mod = @import("realm.zig");
const manager_mod = @import("manager.zig");

const log = std.log.scoped(.service_worker);

/// How a rule's URL pattern is freed.
pub const pattern_ops: router.PatternOps = .{ .free = freePattern };

fn freePattern(pattern: *anyopaque, allocator: Allocator) void {
    const p: *urlpattern.URLPattern = @ptrCast(@alignCast(pattern));
    p.deinit(allocator);
    allocator.destroy(p);
}

/// Whether `url` matches `pattern` (a rule's urlpattern.URLPattern) - URL
/// pattern "match", its regexps run in `realm` (the calling thread's).
pub fn patternMatches(realm: runtime.Context, pattern: *anyopaque, url: []const u8) bool {
    const p: *const urlpattern.URLPattern = @ptrCast(@alignCast(pattern));
    return urlpattern.matcher.testMatch(realm.allocator, realm, p, url, null) catch false;
}

/// addRoutes(rules) for the InstallEvent `event`; `rules_value` is its
/// argument as the binding converted it, the generated `(RouterRule or
/// sequence<RouterRule>)` union - WebIDL's conversion (every getter and
/// iterator of the rules, their dictionaries' members in lexicographic
/// order) is done before any step here.
pub fn addRoutes(event: *runtime.Instance, rules_value: anytype) !runtime.JSValue {
    const realm = engine.currentRealm() orelse event.ctx;
    // 2. serviceWorker: the current global object's service worker.
    const environment = realm_mod.environmentOf(realm, true) orelse return error.InvalidStateError;
    if (environment.kind != .service_worker) return error.InvalidStateError;
    const manager = environment.manager;
    const allocator = manager.allocator;
    var converter: Converter = .{ .realm = realm, .allocator = allocator, .base_url = environment.creation_url };
    // 1. A RouterRule dictionary becomes « rules ». Copied into the
    // manager's allocator: the binding's value is borrowed for the call and
    // the rules cross to the job thread.
    const rules = try converter.rules(rules_value);
    var owned = true;
    errdefer if (owned) router.freeRules(allocator, rules, pattern_ops);
    // 3. Each rule: its condition verified (3.1; its URL patterns were
    // parsed as the rules were copied), and a fetch-event or race source only
    // for a worker that handles fetch (3.2).
    const handles_fetch = manager.workerHandlesFetch(environment.service_worker_id);
    for (rules) |*rule| {
        if (!router.verifyCondition(&rule.condition)) return error.TypeError;
        switch (rule.source) {
            .fetch_event, .race_network_and_fetch_handler => if (!handles_fetch) return error.TypeError,
            else => {},
        }
    }
    // 4-5, 7. lifetimePromise, added to the event (as waitUntil() would add
    // it - and with its check: an event no longer active throws an
    // InvalidStateError, which is what browsers do for an addRoutes() made
    // after the install event, add-routes.https.html), fulfilled once
    // `promise` settles either way.
    const lifetime = try Lifetime.create(realm);
    var lifetime_owned = true;
    errdefer if (lifetime_owned) lifetime.destroy();
    try interfaces.ExtendableEvent.call_waitUntil(event, lifetime.promise.value);
    // 6. promise.
    const made = try environment.newPromise();
    errdefer made.promise.release();
    lifetime_owned = false;
    lifetime.follow(made.promise.value);
    // 8-9. Enqueue the rest to the worker's [[service worker queue]].
    owned = false;
    manager.report(.{ .add_routes = .{
        .allocator = allocator,
        .worker = environment.service_worker_id,
        .rules = rules,
        .ops = pattern_ops,
        .environment = environment.id,
        .promise = made.id,
    } });
    // 10.
    return made.promise.take();
}

/// lifetimePromise (steps 4, 5 and 7): a promise of its own, resolved with
/// undefined when the addRoutes() promise settles, whichever way.
const Lifetime = struct {
    realm: runtime.Context,
    capability: engine.PromiseCapability,
    promise: engine.Owned,

    fn create(realm: runtime.Context) !*Lifetime {
        var capability = try engine.createPromise(realm);
        errdefer engine.releasePromiseCapability(&capability);
        const promise = try engine.retainValue(realm, capability.promise);
        errdefer promise.release();
        const self = try realm.allocator.create(Lifetime);
        self.* = .{ .realm = realm, .capability = capability, .promise = promise };
        return self;
    }

    fn destroy(self: *Lifetime) void {
        engine.releasePromiseCapability(&self.capability);
        self.promise.release();
        self.realm.allocator.destroy(self);
    }

    /// 7. Upon fulfillment or rejection of `promise`, resolve lifetimePromise.
    fn follow(self: *Lifetime, promise: runtime.JSValue) void {
        engine.reactToPromise(self.realm, promise, &steps, self) catch {
            // Never followed: resolved at once rather than hold the event.
            self.settled();
        };
    }

    const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = dropped };

    fn fulfilled(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Lifetime = @ptrCast(@alignCast(data.?));
        self.settled();
    }

    fn rejected(data: ?*anyopaque, _: runtime.JSValue) void {
        const self: *Lifetime = @ptrCast(@alignCast(data.?));
        self.settled();
    }

    fn dropped(data: ?*anyopaque) void {
        const self: *Lifetime = @ptrCast(@alignCast(data.?));
        self.destroy();
    }

    fn settled(self: *Lifetime) void {
        engine.resolvePromise(&self.capability, runtime.JSValue.jsUndefined) catch {};
        self.destroy();
    }
};

/// The converted `(RouterRule or sequence<RouterRule>)` as the router's own
/// rules, owned by the manager's allocator. The binding did WebIDL's
/// conversions; what is left is copying, and Verify Router Condition's URL
/// pattern parse (steps 2.2-2.3), which needs the service worker's script url.
const Converter = struct {
    realm: runtime.Context,
    /// The manager's: what the rules are made with.
    allocator: Allocator,
    /// Parse URL Pattern's baseURL: the service worker's script url.
    base_url: []const u8,

    /// OWNED, each rule and the slice.
    fn rules(self: *Converter, value: anytype) ![]router.Rule {
        const given: []const @FieldType(@TypeOf(value), "router_rule") = switch (value) {
            .router_rule => |*one| one[0..1],
            .router_rule_sequence => |many| many,
        };
        var list: std.ArrayListUnmanaged(router.Rule) = .empty;
        errdefer {
            for (list.items) |*made| made.deinit(self.allocator, pattern_ops);
            list.deinit(self.allocator);
        }
        try list.ensureTotalCapacityPrecise(self.allocator, given.len);
        for (given) |item| list.appendAssumeCapacity(try self.rule(item));
        return list.toOwnedSlice(self.allocator);
    }

    /// RouterRule: required condition, required source.
    fn rule(self: *Converter, value: anytype) anyerror!router.Rule {
        var made = try self.condition(value.condition);
        errdefer made.deinit(self.allocator, pattern_ops);
        return .{ .condition = made, .source = try self.source(value.source) };
    }

    /// RouterCondition.
    fn condition(self: *Converter, value: anytype) anyerror!router.Condition {
        var out: router.Condition = .{};
        errdefer out.deinit(self.allocator, pattern_ops);
        if (value.not) |inner_value| {
            const inner = try self.allocator.create(router.Condition);
            inner.* = self.condition(inner_value.*) catch |err| {
                self.allocator.destroy(inner);
                return err;
            };
            out.not = inner;
        }
        if (value.@"or") |items| {
            var list: std.ArrayListUnmanaged(router.Condition) = .empty;
            errdefer {
                for (list.items) |*c| c.deinit(self.allocator, pattern_ops);
                list.deinit(self.allocator);
            }
            try list.ensureTotalCapacityPrecise(self.allocator, items.len);
            for (items) |item| list.appendAssumeCapacity(try self.condition(item));
            out.any_of = try list.toOwnedSlice(self.allocator);
        }
        // As the IDL spells it ("" included).
        if (value.requestDestination) |destination| out.destination = try self.allocator.dupe(u8, enums.RequestDestination.idl_values[@backingInt(destination)]);
        if (value.requestMethod) |method| out.method = try self.allocator.dupe(u8, method);
        if (value.requestMode) |mode| out.mode = switch (mode) {
            ._navigate_ => .navigate,
            ._same_origin_ => .same_origin,
            ._no_cors_ => .no_cors,
            ._cors_ => .cors,
        };
        if (value.runningStatus) |status| out.running_status = switch (status) {
            ._running_ => .running,
            ._not_running_ => .not_running,
        };
        if (value.urlPattern) |pattern| out.url_pattern = try self.urlPattern(pattern);
        return out;
    }

    /// RouterSource = (RouterSourceDict or RouterSourceEnum): {cacheName} a
    /// cache source with that name, {} one with none; else the enumeration.
    fn source(self: *Converter, value: anytype) !router.Source {
        return switch (value) {
            .router_source_dict => |dictionary| .{ .cache = if (dictionary.cacheName) |name| try self.allocator.dupe(u8, name.asSlice()) else null },
            .router_source_enum => |named| switch (named) {
                ._cache_ => .{ .cache = null },
                ._fetch_event_ => .fetch_event,
                ._network_ => .network,
                ._race_network_and_fetch_handler_ => .race_network_and_fetch_handler,
            },
        };
    }

    /// urlPattern (URLPatternCompatible): Verify Router Condition steps
    /// 2.2-2.3: Parse URL Pattern - "build a URL pattern from a Web IDL
    /// value" given the script url - a throw, or regexp groups, a TypeError
    /// (Verify returns false: addRoutes() rejects). OWNED through
    /// `pattern_ops`.
    fn urlPattern(self: *Converter, value: anytype) !*anyopaque {
        var pattern = try self.parseUrlPattern(value);
        errdefer pattern.deinit(self.allocator);
        // 2.3. Regexp groups are prohibited.
        if (pattern.hasRegexpGroups()) return error.TypeError;
        const boxed = try self.allocator.create(urlpattern.URLPattern);
        boxed.* = pattern;
        return @ptrCast(boxed);
    }

    fn parseUrlPattern(self: *Converter, value: anytype) !urlpattern.URLPattern {
        switch (value) {
            // 1. A URLPattern object: its associated URL pattern (a copy the
            // rule keeps).
            .urlpattern => |object| {
                const associated = dom.url_patterns.patternOf(object) orelse return error.TypeError;
                const p: *const urlpattern.URLPattern = @ptrCast(@alignCast(associated));
                return p.clone(self.allocator);
            },
            // 2. A URLPatternInit: its baseURL the script url when it has
            // none; created with null base. Its strings are the binding's,
            // borrowed for the call; the pattern copies what it keeps.
            .urlpattern_init => |dictionary| {
                const init: urlpattern.URLPatternInit = .{
                    .base_url = dictionary.baseURL orelse self.base_url,
                    .hash = dictionary.hash,
                    .hostname = dictionary.hostname,
                    .password = dictionary.password,
                    .pathname = dictionary.pathname,
                    .port = dictionary.port,
                    .protocol = dictionary.protocol,
                    .search = dictionary.search,
                    .username = dictionary.username,
                };
                return urlpattern.URLPattern.createWithBase(self.allocator, self.realm, .{ .init = init }, null, .{}) catch |err| patternError(err);
            },
            // 3. A USVString: created with the script url as its base.
            .usvstring => |text| return urlpattern.URLPattern.createWithBase(self.allocator, self.realm, .{ .string = text }, self.base_url, .{}) catch |err| patternError(err),
        }
    }
};

/// Parse URL Pattern threw: Verify Router Condition returns false, and
/// addRoutes() rejects with a TypeError.
fn patternError(err: anyerror) anyerror {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.TypeError,
    };
}

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

/// addRoutes(rules) for the InstallEvent `event`, `rules` its argument.
pub fn addRoutes(event: *runtime.Instance, rules_value: runtime.JSValue) !runtime.JSValue {
    const realm = engine.currentRealm() orelse event.ctx;
    // 2. serviceWorker: the current global object's service worker.
    const environment = realm_mod.environmentOf(realm, true) orelse return error.InvalidStateError;
    if (environment.kind != .service_worker) return error.InvalidStateError;
    const manager = environment.manager;
    const allocator = manager.allocator;
    var converter: Converter = .{ .realm = realm, .allocator = allocator, .base_url = environment.creation_url };
    // 1. A RouterRule dictionary becomes « rules ».
    const rules = try converter.rules(rules_value);
    var owned = true;
    errdefer if (owned) router.freeRules(allocator, rules, pattern_ops);
    // 3. Each rule: its condition verified (3.1; its URL patterns were
    // parsed as they were converted), and a fetch-event or race source only
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

/// WebIDL's conversions for addRoutes()'s argument: `(RouterRule or
/// sequence<RouterRule>)`, its dictionaries' members in lexicographic order.
const Converter = struct {
    realm: runtime.Context,
    /// The manager's: what the rules are made with.
    allocator: Allocator,
    /// Parse URL Pattern's baseURL: the service worker's script url.
    base_url: []const u8,

    /// The union: an Object with @@iterator is the sequence; anything else
    /// the dictionary (undefined and null included - a required member then
    /// throws). OWNED, each rule and the slice.
    fn rules(self: *Converter, value: runtime.JSValue) ![]router.Rule {
        var list: std.ArrayListUnmanaged(router.Rule) = .empty;
        errdefer {
            for (list.items) |*made| made.deinit(self.allocator, pattern_ops);
            list.deinit(self.allocator);
        }
        if (engine.typeOf(self.realm, value) == .object) {
            var collector: Collector = .{ .converter = self, .list = &list };
            const iterable = engine.iterate(self.realm, value, Collector.each, &collector) catch |err| {
                if (collector.failed) |failed| return failed;
                return err;
            };
            if (iterable) return list.toOwnedSlice(self.allocator);
        }
        try list.append(self.allocator, try self.rule(value));
        return list.toOwnedSlice(self.allocator);
    }

    const Collector = struct {
        converter: *Converter,
        list: *std.ArrayListUnmanaged(router.Rule),
        failed: ?anyerror = null,

        fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
            const self: *Collector = @ptrCast(@alignCast(data.?));
            const made = self.converter.rule(item) catch |err| {
                self.failed = err;
                return engineError(err);
            };
            self.list.append(self.converter.allocator, made) catch |err| {
                var dropped = made;
                dropped.deinit(self.converter.allocator, pattern_ops);
                self.failed = err;
                return error.OutOfMemory;
            };
        }
    };

    /// RouterRule: required condition, required source.
    fn rule(self: *Converter, value: runtime.JSValue) anyerror!router.Rule {
        try self.requireDictionary(value);
        var made = try self.conditionMember(value, "condition") orelse return error.TypeError;
        errdefer made.deinit(self.allocator, pattern_ops);
        const source = try self.sourceMember(value) orelse return error.TypeError;
        return .{ .condition = made, .source = source };
    }

    /// A dictionary's value: undefined, null or an Object.
    fn requireDictionary(self: *Converter, value: runtime.JSValue) !void {
        switch (engine.typeOf(self.realm, value)) {
            .undefined, .null, .object => {},
            else => return error.TypeError,
        }
    }

    /// Get(value, name), null when value is undefined or null (a dictionary
    /// converted from them has no members) or the member is undefined.
    fn member(self: *Converter, value: runtime.JSValue, name: []const u8) !?engine.Owned {
        switch (engine.typeOf(self.realm, value)) {
            .undefined, .null => return null,
            else => {},
        }
        const got = try engine.getProperty(self.realm, value, name);
        if (engine.typeOf(self.realm, got.value) == .undefined) {
            got.release();
            return null;
        }
        return got;
    }

    fn conditionMember(self: *Converter, value: runtime.JSValue, name: []const u8) anyerror!?router.Condition {
        const got = try self.member(value, name) orelse return null;
        defer got.release();
        return try self.condition(got.value);
    }

    /// RouterCondition, members in lexicographic order: not, or,
    /// requestDestination, requestMethod, requestMode, runningStatus,
    /// urlPattern.
    fn condition(self: *Converter, value: runtime.JSValue) anyerror!router.Condition {
        try self.requireDictionary(value);
        var out: router.Condition = .{};
        errdefer out.deinit(self.allocator, pattern_ops);
        if (try self.member(value, "not")) |got| {
            defer got.release();
            const inner = try self.allocator.create(router.Condition);
            inner.* = self.condition(got.value) catch |err| {
                self.allocator.destroy(inner);
                return err;
            };
            out.not = inner;
        }
        if (try self.member(value, "or")) |got| {
            defer got.release();
            out.any_of = try self.conditionSequence(got.value);
        }
        if (try self.member(value, "requestDestination")) |got| {
            defer got.release();
            out.destination = try self.enumString(got.value, &enums.RequestDestination.idl_values);
        }
        if (try self.member(value, "requestMethod")) |got| {
            defer got.release();
            out.method = try self.byteString(got.value);
        }
        if (try self.member(value, "requestMode")) |got| {
            defer got.release();
            const mode = try self.enumString(got.value, &enums.RequestMode.idl_values);
            defer self.allocator.free(mode);
            out.mode = modeOf(mode);
        }
        if (try self.member(value, "runningStatus")) |got| {
            defer got.release();
            const status = try self.enumString(got.value, &enums.RunningStatus.idl_values);
            defer self.allocator.free(status);
            out.running_status = if (std.mem.eql(u8, status, "running")) .running else .not_running;
        }
        if (try self.member(value, "urlPattern")) |got| {
            defer got.release();
            out.url_pattern = try self.urlPattern(got.value);
        }
        return out;
    }

    fn conditionSequence(self: *Converter, value: runtime.JSValue) anyerror![]router.Condition {
        if (engine.typeOf(self.realm, value) != .object) return error.TypeError;
        var list: std.ArrayListUnmanaged(router.Condition) = .empty;
        errdefer {
            for (list.items) |*c| c.deinit(self.allocator, pattern_ops);
            list.deinit(self.allocator);
        }
        const Each = struct {
            converter: *Converter,
            list: *std.ArrayListUnmanaged(router.Condition),
            failed: ?anyerror = null,

            fn each(data: ?*anyopaque, item: runtime.JSValue) engine.Error!void {
                const self_each: *@This() = @ptrCast(@alignCast(data.?));
                const made = self_each.converter.condition(item) catch |err| {
                    self_each.failed = err;
                    return engineError(err);
                };
                self_each.list.append(self_each.converter.allocator, made) catch |err| {
                    var dropped = made;
                    dropped.deinit(self_each.converter.allocator, pattern_ops);
                    self_each.failed = err;
                    return error.OutOfMemory;
                };
            }
        };
        var collector: Each = .{ .converter = self, .list = &list };
        const iterable = engine.iterate(self.realm, value, Each.each, &collector) catch |err| {
            if (collector.failed) |failed| return failed;
            return err;
        };
        if (!iterable) return error.TypeError;
        return list.toOwnedSlice(self.allocator);
    }

    /// An enumeration value: one of `values`, or a TypeError. OWNED.
    fn enumString(self: *Converter, value: runtime.JSValue, values: []const []const u8) ![]u8 {
        const text = try engine.convertToDOMString(self.realm, value, self.allocator);
        errdefer self.allocator.free(text);
        for (values) |v| if (std.mem.eql(u8, v, text)) return text;
        return error.TypeError;
    }

    /// A ByteString: a code point above U+00FF is a TypeError. OWNED (as
    /// text, as every Crane ByteString).
    fn byteString(self: *Converter, value: runtime.JSValue) ![]u8 {
        const text = try engine.convertToDOMString(self.realm, value, self.allocator);
        errdefer self.allocator.free(text);
        const view = std.unicode.Utf8View.init(text) catch return error.TypeError;
        var it = view.iterator();
        while (it.nextCodepoint()) |cp| if (cp > 0xFF) return error.TypeError;
        return text;
    }

    fn modeOf(name: []const u8) router.RequestMode {
        if (std.mem.eql(u8, name, "navigate")) return .navigate;
        if (std.mem.eql(u8, name, "same-origin")) return .same_origin;
        if (std.mem.eql(u8, name, "no-cors")) return .no_cors;
        return .cors;
    }

    /// RouterSource = (RouterSourceDict or RouterSourceEnum): an Object (or
    /// null/undefined) is the dictionary - {cacheName} a cache source with
    /// that name, {} one with none; anything else the enumeration.
    fn sourceMember(self: *Converter, value: runtime.JSValue) !?router.Source {
        const got = try self.member(value, "source") orelse return null;
        defer got.release();
        switch (engine.typeOf(self.realm, got.value)) {
            .object, .null => {
                const name = try self.member(got.value, "cacheName") orelse return .{ .cache = null };
                defer name.release();
                return .{ .cache = try engine.convertToDOMString(self.realm, name.value, self.allocator) };
            },
            else => {},
        }
        const text = try self.enumString(got.value, &enums.RouterSourceEnum.idl_values);
        defer self.allocator.free(text);
        if (std.mem.eql(u8, text, "cache")) return .{ .cache = null };
        if (std.mem.eql(u8, text, "fetch-event")) return .fetch_event;
        if (std.mem.eql(u8, text, "network")) return .network;
        return .race_network_and_fetch_handler;
    }

    /// urlPattern (URLPatternCompatible), then Verify Router Condition steps
    /// 2.2-2.3: Parse URL Pattern - "build a URL pattern from a Web IDL
    /// value" given the script url - a throw, or regexp groups, a TypeError
    /// (Verify returns false: addRoutes() rejects). OWNED through
    /// `pattern_ops`.
    fn urlPattern(self: *Converter, value: runtime.JSValue) !*anyopaque {
        var pattern = try self.parseUrlPattern(value);
        errdefer pattern.deinit(self.allocator);
        // 2.3. Regexp groups are prohibited.
        if (pattern.hasRegexpGroups()) return error.TypeError;
        const boxed = try self.allocator.create(urlpattern.URLPattern);
        boxed.* = pattern;
        return @ptrCast(boxed);
    }

    fn parseUrlPattern(self: *Converter, value: runtime.JSValue) !urlpattern.URLPattern {
        // 1. A URLPattern object: its associated URL pattern (a copy the
        // rule keeps).
        if (engine.typeOf(self.realm, value) == .object) {
            if (engine.convertToPlatformObject(self.realm, value)) |object| {
                if (dom.url_patterns.patternOf(object)) |associated| {
                    const p: *const urlpattern.URLPattern = @ptrCast(@alignCast(associated));
                    return p.clone(self.allocator);
                }
            }
        }
        // 2. A URLPatternInit (an Object, or null/undefined): its baseURL
        // the script url when it has none; created with null base.
        switch (engine.typeOf(self.realm, value)) {
            .object, .null, .undefined => {
                var strings: std.ArrayListUnmanaged([]u8) = .empty;
                defer {
                    for (strings.items) |s| self.allocator.free(s);
                    strings.deinit(self.allocator);
                }
                var init: urlpattern.URLPatternInit = .{};
                // Members in lexicographic order: baseURL, hash, hostname,
                // password, pathname, port, protocol, search, username.
                init.base_url = try self.usvMember(value, "baseURL", &strings);
                init.hash = try self.usvMember(value, "hash", &strings);
                init.hostname = try self.usvMember(value, "hostname", &strings);
                init.password = try self.usvMember(value, "password", &strings);
                init.pathname = try self.usvMember(value, "pathname", &strings);
                init.port = try self.usvMember(value, "port", &strings);
                init.protocol = try self.usvMember(value, "protocol", &strings);
                init.search = try self.usvMember(value, "search", &strings);
                init.username = try self.usvMember(value, "username", &strings);
                if (init.base_url == null) init.base_url = self.base_url;
                return urlpattern.URLPattern.createWithBase(self.allocator, self.realm, .{ .init = init }, null, .{}) catch |err| patternError(err);
            },
            else => {},
        }
        // 3. A USVString: created with the script url as its base.
        const text = try engine.convertToUSVString(self.realm, value, self.allocator);
        defer self.allocator.free(text);
        return urlpattern.URLPattern.createWithBase(self.allocator, self.realm, .{ .string = text }, self.base_url, .{}) catch |err| patternError(err);
    }

    fn usvMember(self: *Converter, value: runtime.JSValue, name: []const u8, strings: *std.ArrayListUnmanaged([]u8)) !?[]const u8 {
        const got = try self.member(value, name) orelse return null;
        defer got.release();
        const text = try engine.convertToUSVString(self.realm, got.value, self.allocator);
        strings.append(self.allocator, text) catch |err| {
            self.allocator.free(text);
            return err;
        };
        return text;
    }
};

/// An error of a conversion inside an iteration, as the iteration's steps
/// may return it: an engine error as it is, anything else a TypeError.
fn engineError(err: anyerror) engine.Error {
    inline for (@typeInfo(engine.Error).error_set.error_names.?) |e_name| {
        if (err == @field(anyerror, e_name)) return @field(engine.Error, e_name);
    }
    return error.TypeError;
}

/// Parse URL Pattern threw: Verify Router Condition returns false, and
/// addRoutes() rejects with a TypeError.
fn patternError(err: anyerror) anyerror {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.TypeError,
    };
}

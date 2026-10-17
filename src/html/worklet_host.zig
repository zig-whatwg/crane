//! Worklets: HTML chapter 11 - a worklet's global scopes, its added modules,
//! `addModule()`'s steps and the worklet global scopes' lifetime.
//!
//! Spec: https://html.spec.whatwg.org/multipage/worklets.html
//!
//! The Worklet impl keeps a `Worklet` record (HTML 11.3.2's state); the
//! worklet global scope impls keep their definition maps; everything between
//! them is here.
//!
//! Where a worklet runs. Every WorkletGlobalScope is a realm of its own, made
//! by the engine (`engine.createWorkletRealm`) in the agent of the worklet's
//! outside settings - its owner Window's, on the Window's thread - as Blink's
//! main-thread worklets are (WorkletGlobalScope(LocalFrame*): the frame's
//! isolate, ThreadType::kMainThread) and WebKit's PaintWorkletGlobalScope is.
//! Stated deviation: HTML 11.3.1.2 step 2 obtains a worklet agent of its own,
//! and Blink gives a main-thread worklet an Agent with a v8::MicrotaskQueue of
//! its own; Crane's shares its owner's agent - its event loop and microtask
//! queue - which nothing observes, since worklet script runs only inside the
//! tasks queued here, and a task boundary leaves the owner's microtask queue
//! empty. Blink and WebKit put an AudioWorkletGlobalScope on a real-time
//! rendering thread instead; Crane renders no audio (the host media backend
//! does, the user's 2026-10-08 ruling), so its audio worklets run here too.
//! When a host renderer arrives, AudioWorklet moves to a threaded agent of its
//! own: the graph fetched on the owner's thread, the source text handed over,
//! as HTML 11.3.2's note describes.
//!
//! One global scope per worklet. HTML 11.3.2 step 6.1 creates one and lets a
//! worklet's spec create more; WebKit makes one (Blink two for paint). The
//! added modules list is kept (HTML 11.3.2); the module responses map is not:
//! it exists so that a global scope made later gets equivalent module scripts
//! from the same source text, and Crane makes no global scope after the
//! first.
//!
//! The fetch client is the outside settings: "fetch a worklet script graph"
//! fetches with the worklet's relevant settings object - the document's - so
//! the request carries the document's policy container clone (CSP, its
//! violations reported at the document; Upgrade Insecure Requests), its Mixed
//! Content restriction and its resource timing reporter, while the module
//! records are made in the global scope's realm and kept in its module map
//! (HTML 11.3.1.3: the settings object's module map is the global scope's).
//!
//! Lifetime (HTML 11.3.3): a global scope lives at least as long as the
//! Document whose worklet global scopes contain it, and destroying the
//! document terminates it. The Browser's live global scopes are a supplement
//! of its scope (`Registry`, docs/instances.md rule 2); the Worklet impl
//! installs `environmentEnded` as an unloading document cleanup step
//! (dom.unloading_cleanup), which runs for a page's realm before its realm
//! ends and for a frame's as its realm ends, and terminates every global
//! scope that environment's worklets made.
//!
//! Every record here is used on its owner's thread only (the Window's): a
//! worklet is [Exposed=Window].

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const fetch = @import("fetch");
const dom = @import("dom");
const module_script = @import("module_script.zig");
const css = @import("css");

const log = std.log.scoped(.worklets);

/// The worklets Crane has, each with its worklet global scope type and its
/// worklet destination type (HTML 11.3.2).
pub const Kind = enum {
    /// CSS Painting API: PaintWorkletGlobalScope, destination "paintworklet".
    paint,
    /// CSS Layout API: LayoutWorkletGlobalScope. The spec names no
    /// destination; Blink fetches it as "script", and CSP 3 governs it by
    /// script-src as it does the others.
    layout,
    /// CSS Animation Worklet: AnimationWorkletGlobalScope, "script" (as
    /// layout).
    animation,
    /// Web Audio API: AudioWorkletGlobalScope, destination "audioworklet".
    audio,

    fn global(self: Kind) runtime.WorkletRealmOptions.WorkletGlobal {
        return switch (self) {
            .paint => .paint,
            .layout => .layout,
            .animation => .animation,
            .audio => .audio,
        };
    }

    /// The worklet destination type.
    pub fn destination(self: Kind) fetch.internal.Destination {
        return switch (self) {
            .paint => .paintworklet,
            .layout, .animation => .script,
            .audio => .audioworklet,
        };
    }
};

// =============================================================================
// The Worklet's state
// =============================================================================

/// HTML 11.3.2: a Worklet's global scopes and added modules list, and its
/// worklet global scope and destination types (`kind`). Owned by the Worklet
/// platform object's impl state; destroyed with it.
pub const Worklet = struct {
    allocator: Allocator,
    kind: Kind,
    /// "global scopes": BORROWED - each is the Registry's until its document
    /// ends, and points back here (`GlobalScope.worklet`) until this goes.
    global_scopes: std.ArrayListUnmanaged(*GlobalScope) = .empty,
    /// "added modules list": the URLs, OWNED.
    added_modules: std.ArrayListUnmanaged([]u8) = .empty,

    pub fn create(allocator: Allocator, kind: Kind) Allocator.Error!*Worklet {
        const self = try allocator.create(Worklet);
        self.* = .{ .allocator = allocator, .kind = kind };
        return self;
    }

    /// The Worklet platform object is gone. Its global scopes stay until
    /// their document ends (HTML 11.3.3); they only forget it. No addModule
    /// is in flight: one keeps the Worklet alive until it ends.
    pub fn destroy(self: *Worklet) void {
        for (self.global_scopes.items) |scope| scope.worklet = null;
        self.global_scopes.deinit(self.allocator);
        for (self.added_modules.items) |url| self.allocator.free(url);
        self.added_modules.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn forget(self: *Worklet, scope: *GlobalScope) void {
        for (self.global_scopes.items, 0..) |item, i| {
            if (item != scope) continue;
            _ = self.global_scopes.orderedRemove(i);
            return;
        }
    }
};

// =============================================================================
// Worklet global scopes
// =============================================================================

/// One WorkletGlobalScope: its realm, its module map and the loader that
/// fetches its module graphs. Reference counted: the Registry holds one
/// reference while the scope is live, and every task, fetch or graph that
/// names the scope holds one, so a scope terminated with work still queued
/// is freed when the last of it ends - each checks `terminated` first.
pub const GlobalScope = struct {
    allocator: Allocator,
    refs: usize = 1,
    terminated: bool = false,
    kind: Kind,
    /// The worklet's outside settings: the owner Window's realm. BORROWED;
    /// the scope ends before it (its document's end terminates the scope).
    outside: runtime.Context,
    /// The outside settings' document: the fetch client, and what URLs are
    /// parsed against. BORROWED, as above.
    document: *runtime.Instance,
    /// The Worklet whose global scopes contain this one; null once its
    /// platform object is gone.
    worklet: ?*Worklet,
    /// The realm, and its global object (the realm owns it).
    realm: runtime.Context,
    global_scope: *runtime.Instance,
    /// HTML 11.3.1: the global scope's module map - keyed as module_script
    /// keys a module map (module type and URL), values a `*ModuleScript` or
    /// `module_script.fetch_failed`. Keys and values OWNED until termination.
    module_map: std.StringHashMapUnmanaged(*anyopaque) = .empty,
    /// The scope's module graph fetches, made on its first addModule.
    loader: ?*module_script.AsyncModuleLoader = null,

    fn retain(self: *GlobalScope) *GlobalScope {
        self.refs += 1;
        return self;
    }

    fn release(self: *GlobalScope) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        std.debug.assert(self.terminated);
        self.allocator.destroy(self);
    }

    fn moduleMap(self: *GlobalScope) module_script.ModuleMap {
        return .{ .context = self, .getFn = &mapGet, .putFn = &mapPut };
    }

    fn mapGet(context: *anyopaque, key: []const u8) ?*anyopaque {
        const self: *GlobalScope = @ptrCast(@alignCast(context));
        return self.module_map.get(key);
    }

    fn mapPut(context: *anyopaque, key: []const u8, value: *anyopaque) bool {
        const self: *GlobalScope = @ptrCast(@alignCast(context));
        if (self.terminated) return false;
        const entry = self.module_map.getOrPut(self.allocator, key) catch return false;
        if (entry.found_existing) {
            module_script.disposeEntry(entry.value_ptr.*);
        } else {
            entry.key_ptr.* = self.allocator.dupe(u8, key) catch {
                self.module_map.removeByPtr(entry.key_ptr);
                return false;
            };
        }
        entry.value_ptr.* = value;
        return true;
    }

    /// The environment the scope's module graphs are fetched in: the
    /// document as the fetch client and URL base, the scope's realm for the
    /// records, its own module map, no import map (HTML "resolve a module
    /// specifier" step 3: only a Window has one), no CSS module (HTML
    /// "module type allowed": CSSStyleSheet is not exposed in a worklet), and
    /// the worklet destination type.
    fn environment(self: *GlobalScope) module_script.Environment {
        return .{
            .allocator = self.allocator,
            .context_instance = self.document,
            .map = self.moduleMap(),
            .realm_override = self.realm,
            .css_allowed = false,
            .script_destination = self.kind.destination(),
        };
    }

    fn loaderOf(self: *GlobalScope) ?*module_script.AsyncModuleLoader {
        if (self.loader) |loader| return loader;
        const loader = module_script.AsyncModuleLoader.create(self.environment(), self.document) catch return null;
        self.loader = loader;
        return loader;
    }

    /// HTML 11.3.1.2 "terminate a worklet global scope": its tasks are
    /// discarded (every graph and fetch of the loader ends, and each queued
    /// task finds the scope terminated), nothing of it runs again, its module
    /// scripts go while their realm still lives, the engine ends its realm
    /// (step 5), and it leaves its Worklet's global scopes (step 6). Leaving
    /// the Registry (step 7) is the caller's.
    fn terminate(self: *GlobalScope) void {
        if (self.terminated) return;
        self.terminated = true;
        if (self.loader) |loader| {
            self.loader = null;
            loader.destroy();
        }
        var entries = self.module_map.iterator();
        while (entries.next()) |entry| {
            module_script.disposeEntry(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.module_map.deinit(self.allocator);
        engine.destroyWorkletRealm(self.realm);
        if (self.worklet) |worklet| worklet.forget(self);
        self.worklet = null;
    }
};

/// HTML 11.3.1.2 "create a worklet global scope" for `worklet`, whose
/// relevant settings object is `outside`'s, with `document` its document.
/// Steps 2-5 are the engine's realm (`engine.createWorkletRealm`) and the
/// settings it records; step 7's runNextAddedModule has nothing to run in a
/// worklet's first global scope, the only one Crane makes. Steps 7.2-7.3
/// append it to the document's worklet global scopes (the Registry, keyed by
/// `outside`) and the worklet's.
fn createGlobalScope(registry: *Registry, worklet: *Worklet, outside: runtime.Context, document: *runtime.Instance) !*GlobalScope {
    const agent = outside.agent orelse return error.NotSupported;
    const made = try engine.createWorkletRealm(agent, &.{
        .global = worklet.kind.global(),
        .owner = outside,
        .api_base_url = outside.documentUrl() orelse "",
        .allocator = outside.allocator,
        .on_realm = onRealm,
    });
    errdefer engine.destroyWorkletRealm(made.realm);
    const scope = try registry.allocator.create(GlobalScope);
    errdefer registry.allocator.destroy(scope);
    scope.* = .{
        .allocator = registry.allocator,
        .kind = worklet.kind,
        .outside = outside,
        .document = document,
        .worklet = worklet,
        .realm = made.realm,
        .global_scope = made.global_scope,
    };
    try registry.scopes.append(registry.allocator, scope);
    errdefer _ = registry.scopes.pop();
    try worklet.global_scopes.append(worklet.allocator, scope);
    return scope;
}

/// The realm exists and its global object does not yet: what the worklet's
/// settings answer that the engine does not record.
fn onRealm(_: ?*anyopaque, realm: runtime.Context) void {
    // HTML "report an exception" in a WorkletGlobalScope: it is not an
    // EventTarget, so no error event is fired; the developer console hears
    // of it (Blink: WorkletGlobalScope reports to the console only).
    realm.report_exception = reportToConsole;
}

fn reportToConsole(_: *runtime.ContextData, info: *const runtime.ErrorInfo) void {
    log.info("uncaught in a worklet: {s} ({s}:{d}:{d})", .{ info.message, info.filename, info.lineno, info.colno });
}

/// The Browser's live worklet global scopes: HTML 11.3.3's "worklet global
/// scopes" of each of its documents, each scope keyed by its outside settings'
/// realm. A supplement of the Browser's scope (docs/instances.md rule 2).
pub const Registry = struct {
    allocator: Allocator,
    /// Every live global scope, in the order they were made; each holds the
    /// reference the Registry keeps.
    scopes: std.ArrayListUnmanaged(*GlobalScope) = .empty,
    /// Every addModule that has not ended (BORROWED: each is its tasks').
    operations: std.ArrayListUnmanaged(*AddModule) = .empty,

    pub fn init(allocator: Allocator) Registry {
        return .{ .allocator = allocator };
    }

    /// The Browser's end. Every document's end terminated its global scopes
    /// first (the unloading document cleanup steps run for every realm before
    /// it ends), so none is left: a realm left here would outlive its agent.
    pub fn deinit(self: *Registry) void {
        std.debug.assert(self.scopes.items.len == 0);
        std.debug.assert(self.operations.items.len == 0);
        self.scopes.deinit(self.allocator);
        self.operations.deinit(self.allocator);
    }

    fn forgetOperation(self: *Registry, operation: *AddModule) void {
        for (self.operations.items, 0..) |item, i| {
            if (item != operation) continue;
            _ = self.operations.swapRemove(i);
            return;
        }
    }

    /// The registry of the Browser `realm` belongs to; null for a realm with
    /// none (a test realm).
    pub fn of(realm: runtime.Context) ?*Registry {
        const scope = realm.browser_scope orelse return null;
        return scope.of(Registry) catch null;
    }

    /// The registry of the Browser `realm` belongs to, if one was made; never
    /// makes one (a realm's end asks, and most realms never made a worklet).
    pub fn existingOf(realm: runtime.Context) ?*Registry {
        const scope = realm.browser_scope orelse return null;
        return scope.existing(Registry);
    }
};

/// HTML 11.3.3, run as an unloading document cleanup step (installed by the
/// Worklet impl): `environment`'s document is being unloaded or destroyed, so
/// every global scope its worklets made is terminated and leaves the
/// document's worklet global scopes. A worker's environment has none.
pub fn environmentEnded(environment: runtime.Context) void {
    // Only a Window's environment has worklets - and a worker's realm ends on
    // the worker's thread, which must not touch the Window thread's records.
    if (windowOf(environment) == null) return;
    const registry = Registry.existingOf(environment) orelse return;
    // Its pending addModule calls end first: their promises are its realm's,
    // and nothing will settle them now.
    var op: usize = 0;
    while (op < registry.operations.items.len) {
        const operation = registry.operations.items[op];
        if (operation.outside != environment) {
            op += 1;
            continue;
        }
        operation.end();
    }
    var i: usize = 0;
    while (i < registry.scopes.items.len) {
        const scope = registry.scopes.items[i];
        if (scope.outside != environment) {
            i += 1;
            continue;
        }
        _ = registry.scopes.orderedRemove(i);
        scope.terminate();
        scope.release();
    }
}

// =============================================================================
// addModule
// =============================================================================

/// The Window `realm`'s global object, or null for a realm whose global is
/// not a Window.
fn windowOf(realm: runtime.Context) ?*runtime.Instance {
    const record = realm.getRealm() orelse return null;
    const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    if (global.stateAs(interfaces.Window.State) == null) return null;
    return global;
}

/// One call of addModule(): HTML 11.3.2 step 6's state - `pendingTasks`,
/// `addedSuccessfully` and the promise - shared by the steps run for each
/// global scope and the tasks they queue on the Worklet's realm. Reference
/// counted by every task and graph that may still reach it; the last one
/// frees it, and with it, if the promise never settled (its global scopes
/// were terminated), the capability and the Worklet's keep.
const AddModule = struct {
    allocator: Allocator,
    refs: usize = 1,
    /// The Browser's registry, which lists this until it ends.
    registry: *Registry,
    /// The Worklet platform object, kept alive (engine.keepPlatformObjectAlive)
    /// until this ends - Blink's WorkletPendingTasks keep their Worklet - so
    /// `worklet` lives as long as this has not ended.
    instance: *runtime.Instance,
    worklet: *Worklet,
    /// The Worklet's relevant realm: the outside settings'.
    outside: runtime.Context,
    capability: engine.PromiseCapability,
    /// moduleURLRecord, serialized. OWNED.
    url: []u8,
    credentials_mode: fetch.internal.CredentialsMode,
    /// "pendingTasks": -1 once the promise is settled.
    pending_tasks: isize,
    /// "addedSuccessfully".
    added_successfully: bool = false,
    /// Its engine values are released and its Worklet let go: it settled
    /// and nothing more will run for it, or its environment ended
    /// (`environmentEnded`), after which only its memory is left for the
    /// last task or graph that names it.
    ended: bool = false,

    fn retain(self: *AddModule) *AddModule {
        self.refs += 1;
        return self;
    }

    fn release(self: *AddModule) void {
        self.refs -= 1;
        if (self.refs > 0) return;
        self.end();
        self.allocator.free(self.url);
        self.allocator.destroy(self);
    }

    /// Release what it holds of its realm - the promise's capability, the
    /// Worklet's keep - while that realm lives, exactly once.
    fn end(self: *AddModule) void {
        if (self.ended) return;
        self.ended = true;
        engine.releasePromiseCapability(&self.capability);
        engine.releasePlatformObject(self.instance);
        self.registry.forgetOperation(self);
    }
};

/// `addModule(moduleURL, options)` (HTML 11.3.2) of the Worklet `instance`,
/// whose state is `worklet`. Returns the promise, for the binding.
pub fn addModule(instance: *runtime.Instance, worklet: *Worklet, module_url: []const u8, credentials_mode: fetch.internal.CredentialsMode) !runtime.JSValue {
    // Step 1: outsideSettings, this's relevant settings object.
    const outside = instance.ctx;
    const allocator = outside.allocator;
    const window = windowOf(outside) orelse return rejectedWith(outside, "AbortError", "The worklet has no Window");
    const document = interfaces.Window.get_document(window) catch
        return rejectedWith(outside, "AbortError", "The worklet's Window has no document");

    // Steps 2-3: encoding-parse moduleURL relative to outsideSettings.
    const url = (try dom.encoding_parse.encodingParseAndSerialize(document, module_url)) orelse
        return rejectedWith(outside, "SyntaxError", "The module URL could not be parsed");
    defer allocator.free(url);

    const registry = Registry.of(outside) orelse return rejectedWith(outside, "AbortError", "No Browser to run the worklet in");

    // Step 4: promise.
    var capability = try engine.createPromise(outside);
    const promise = engine.retainValue(outside, capability.promise) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    errdefer promise.release();

    // Step 6.1 - "in parallel", here at once: nothing observes the moment
    // the global scope is made. A worklet whose global scope cannot be made
    // fails as a failed fetch would.
    if (worklet.global_scopes.items.len == 0) {
        _ = createGlobalScope(registry, worklet, outside, document) catch |err| {
            log.debug("creating a worklet global scope failed: {}", .{err});
            engine.releasePromiseCapability(&capability);
            promise.release();
            return rejectedWith(outside, "AbortError", "The worklet global scope could not be created");
        };
    }

    // Steps 6.2-6.3.
    const operation = registry.allocator.create(AddModule) catch |err| {
        engine.releasePromiseCapability(&capability);
        return err;
    };
    registry.operations.append(registry.allocator, operation) catch |err| {
        engine.releasePromiseCapability(&capability);
        registry.allocator.destroy(operation);
        return err;
    };
    operation.* = .{
        .allocator = registry.allocator,
        .registry = registry,
        .instance = instance,
        .worklet = worklet,
        .outside = outside,
        .capability = capability,
        .url = registry.allocator.dupe(u8, url) catch |err| {
            engine.releasePromiseCapability(&capability);
            _ = registry.operations.pop();
            registry.allocator.destroy(operation);
            return err;
        },
        .credentials_mode = credentials_mode,
        .pending_tasks = @intCast(worklet.global_scopes.items.len),
    };
    engine.keepPlatformObjectAlive(instance);
    defer operation.release();

    // Step 6.4: for each global scope, a task on its networking task source
    // fetches a worklet script graph.
    for (worklet.global_scopes.items) |scope| queueFetch(operation, scope);

    // Step 7.
    return promise.take();
}

/// A promise of `realm`'s rejected with a new `name` DOMException.
fn rejectedWith(realm: runtime.Context, name: []const u8, message: []const u8) !runtime.JSValue {
    const exception = try engine.createDOMException(realm, name, message);
    defer exception.release();
    const rejected = try engine.createRejectedPromise(realm, exception.value);
    return rejected.take();
}

/// The steps one global scope runs for an addModule: `operation`'s, in
/// `scope`. Holds a reference to each.
const ScopeFetch = struct {
    operation: *AddModule,
    scope: *GlobalScope,

    fn create(operation: *AddModule, scope: *GlobalScope) ?*ScopeFetch {
        const self = operation.allocator.create(ScopeFetch) catch return null;
        self.* = .{ .operation = operation.retain(), .scope = scope.retain() };
        return self;
    }

    fn destroy(self: *ScopeFetch) void {
        const allocator = self.operation.allocator;
        self.operation.release();
        self.scope.release();
        allocator.destroy(self);
    }
};

/// HTML 11.3.2 step 6.4: queue a global task on the networking task source
/// given `scope` to fetch a worklet script graph.
fn queueFetch(operation: *AddModule, scope: *GlobalScope) void {
    const steps = ScopeFetch.create(operation, scope) orelse return;
    const loop = scope.realm.getOptionalEventLoop() orelse return steps.destroy();
    loop.queueTask(.{ .callback = runFetchTask, .context = steps, .drop = dropFetchTask });
}

fn dropFetchTask(data: ?*anyopaque) void {
    const steps: *ScopeFetch = @ptrCast(@alignCast(data orelse return));
    steps.destroy();
}

fn runFetchTask(data: ?*anyopaque) void {
    const steps: *ScopeFetch = @ptrCast(@alignCast(data orelse return));
    // A terminated scope's tasks are discarded (HTML 11.3.1.2 terminate,
    // step 2).
    if (steps.scope.terminated or !steps.scope.realm.hasEngine()) return steps.destroy();
    engine.runTaskInRealm(steps.scope.realm, startFetch, steps) catch steps.destroy();
}

/// HTML "fetch a worklet script graph" given moduleURLRecord, outsideSettings
/// (the fetch client), the worklet destination type, the credentials mode,
/// the scope's settings object and - not modelled, see the file's comment -
/// the module responses map: "fetch a worklet/module worker script graph"
/// step 1's script fetch options (empty nonce and integrity, not parser
/// inserted, the credentials mode, no referrer policy) and step 2's fetch
/// of the single module script and its descendants, through the scope's
/// loader. The graph's onComplete is `ScopeFetch`'s `graphDone`.
fn startFetch(data: ?*anyopaque) void {
    const steps: *ScopeFetch = @ptrCast(@alignCast(data.?));
    const loader = steps.scope.loaderOf() orelse return graphDone(steps, null);
    loader.start(steps.operation.url, .javascript, null, .{ .credentials_mode = steps.operation.credentials_mode }, .{
        .context = steps,
        .done = graphDoneCallback,
        .gone = graphGone,
    }) catch return graphDone(steps, null);
}

fn graphDoneCallback(context: *anyopaque, result: ?*module_script.ModuleScript) void {
    graphDone(@ptrCast(@alignCast(context)), result);
}

/// The graph ended without completing: its scope was terminated, so its
/// tasks are discarded and its part of the promise never comes.
fn graphGone(context: *anyopaque) void {
    const steps: *ScopeFetch = @ptrCast(@alignCast(context));
    steps.destroy();
}

/// HTML 11.3.2 step 6.4's steps given `script`, in the scope's realm (the
/// loader delivers them in a task of the scope's).
fn graphDone(steps: *ScopeFetch, result: ?*module_script.ModuleScript) void {
    defer steps.destroy();
    const operation = steps.operation;
    const scope = steps.scope;
    if (operation.ended) return;
    // Step 6.4.1: a null script rejects with an AbortError.
    const script = result orelse return queueSettle(operation, .abort);
    // Step 6.4.2: an error to rethrow rejects with it - in the Worklet's
    // realm. The browsers hand it over: Blink serializes it in the worklet
    // and deserializes it in the main world
    // (WorkletModuleTreeClient::NotifyModuleTreeLoadFinished), WebKit
    // recreates the Exception in the main realm (WorkletPendingTasks::abort).
    // A value that cannot be cloned rejects with an AbortError.
    if (script.error_to_rethrow) |error_value| {
        const serialized = engine.structuredSerializeForStorage(scope.realm, error_value.value, operation.allocator) catch
            return queueSettle(operation, .abort);
        return queueSettle(operation, .{ .reject_with = serialized });
    }
    // Step 6.4.3: the URL joins the worklet's added modules list, once.
    if (!operation.added_successfully) {
        const copy = operation.allocator.dupe(u8, operation.url) catch return queueSettle(operation, .abort);
        operation.worklet.added_modules.append(operation.worklet.allocator, copy) catch {
            operation.allocator.free(copy);
            return queueSettle(operation, .abort);
        };
        operation.added_successfully = true;
    }
    // Step 6.4.4: run a module script.
    runModuleScript(scope, script);
    // Step 6.4.5.
    queueSettle(operation, .added);
}

/// HTML "run a module script" for `script` in `scope`'s realm, whose task is
/// running (its "prepare to run script" and "clean up after running script"
/// are the task's): an exception is reported - to the console, since a
/// WorkletGlobalScope fires no error event - and a module waiting on
/// top-level await is reported upon rejection, as a reaction.
fn runModuleScript(scope: *GlobalScope, script: *module_script.ModuleScript) void {
    const loader = scope.loader orelse return;
    switch (module_script.run(&loader.env, script)) {
        .ok => {},
        .report => |value| {
            defer value.release();
            reportValue(scope.realm, value.value);
        },
        .pending => |promise| {
            defer promise.release();
            engine.reactToPromise(scope.realm, promise.value, &evaluation_steps, scope.realm) catch {};
        },
    }
}

const evaluation_steps: engine.PromiseReactionSteps = .{ .rejected = evaluationRejected };

fn evaluationRejected(data: ?*anyopaque, reason: runtime.JSValue) void {
    const realm: runtime.Context = @ptrCast(@alignCast(data.?));
    reportValue(realm, reason);
}

fn reportValue(realm: runtime.Context, value: runtime.JSValue) void {
    const allocator = realm.allocator;
    const info = engine.extractErrorInformation(realm, value, allocator) catch return;
    defer allocator.free(info.message);
    defer allocator.free(info.filename);
    log.info("uncaught in a worklet module: {s} ({s}:{d}:{d})", .{ info.message, info.filename, info.lineno, info.colno });
}

/// What one global scope's steps tell the Worklet's realm.
const Outcome = union(enum) {
    /// Step 6.4.1: reject with an AbortError.
    abort,
    /// Step 6.4.2: reject with the error to rethrow, serialized (OWNED).
    reject_with: []u8,
    /// Step 6.4.5: this global scope has the module.
    added,
};

const Settle = struct {
    operation: *AddModule,
    outcome: Outcome,

    fn destroy(self: *Settle) void {
        const operation = self.operation;
        switch (self.outcome) {
            .reject_with => |bytes| operation.allocator.free(bytes),
            else => {},
        }
        operation.allocator.destroy(self);
        operation.release();
    }
};

/// Queue a global task on the networking task source given the Worklet's
/// relevant global object, to settle `operation` as `outcome` says.
fn queueSettle(operation: *AddModule, outcome: Outcome) void {
    const settle = operation.allocator.create(Settle) catch {
        switch (outcome) {
            .reject_with => |bytes| operation.allocator.free(bytes),
            else => {},
        }
        return;
    };
    settle.* = .{ .operation = operation.retain(), .outcome = outcome };
    const loop = operation.outside.getOptionalEventLoop() orelse return settle.destroy();
    loop.queueTask(.{ .callback = runSettleTask, .context = settle, .drop = dropSettleTask });
}

fn dropSettleTask(data: ?*anyopaque) void {
    const settle: *Settle = @ptrCast(@alignCast(data orelse return));
    settle.destroy();
}

fn runSettleTask(data: ?*anyopaque) void {
    const settle: *Settle = @ptrCast(@alignCast(data orelse return));
    defer settle.destroy();
    // An operation whose environment ended, or a realm the adapter has
    // retired, has nobody to hear it.
    if (settle.operation.ended or !settle.operation.outside.hasEngine()) return;
    engine.runTaskInRealm(settle.operation.outside, settleSteps, settle) catch {};
}

/// The task's steps (HTML 11.3.2 steps 6.4.1.1, 6.4.2.1 and 6.4.5.1).
fn settleSteps(data: ?*anyopaque) void {
    const settle: *Settle = @ptrCast(@alignCast(data.?));
    const operation = settle.operation;
    if (operation.pending_tasks == -1) return;
    switch (settle.outcome) {
        .abort => {
            operation.pending_tasks = -1;
            rejectWithDOMException(operation, "AbortError", "The module could not be fetched");
        },
        .reject_with => |bytes| {
            operation.pending_tasks = -1;
            const reason = engine.structuredDeserialize(operation.outside, bytes) catch
                return rejectWithDOMException(operation, "AbortError", "The module's error could not be handed over");
            defer reason.release();
            engine.rejectPromise(&operation.capability, reason.value) catch {};
        },
        .added => {
            operation.pending_tasks -= 1;
            if (operation.pending_tasks == 0) engine.resolvePromise(&operation.capability, runtime.JSValue.jsUndefined) catch {};
        },
    }
}

fn rejectWithDOMException(operation: *AddModule, name: []const u8, message: []const u8) void {
    const exception = engine.createDOMException(operation.outside, name, message) catch return;
    defer exception.release();
    engine.rejectPromise(&operation.capability, exception.value) catch {};
}

// =============================================================================
// Registering classes
// =============================================================================
//
// What the worklet global scopes' register*() methods share: each checks the
// class constructor it is given and records a definition. Nothing invokes a
// definition - Crane paints, lays out, animates and renders audio nothing -
// so a definition records what the spec's map holds except the constructor
// and its functions, which are checked and not kept.

/// IsConstructor(`constructor`) - a TypeError when false - and its
/// prototype: Get(constructor, "prototype"), a TypeError unless an Object
/// (CSS Painting API 4 steps 15-17, CSS Layout API steps 14-15, CSS
/// Animation Worklet steps 4-5, Web Audio API registerProcessor steps 3-5).
/// The prototype is OWNED. A getter that throws leaves its exception
/// pending (error.ExceptionPending).
pub fn classPrototype(realm: runtime.Context, constructor: runtime.JSValue) !engine.Owned {
    if (!engine.isConstructor(realm, constructor)) return error.TypeError;
    const prototype = try engine.getProperty(realm, constructor, "prototype");
    errdefer prototype.release();
    if (engine.typeOf(realm, prototype.value) != .object) return error.TypeError;
    return prototype;
}

/// Get(`object`, `name`) converted to the Function callback type: a
/// TypeError unless callable (WebIDL 3.2.20 "converting to a callback
/// function type", Function not [LegacyTreatNonObjectAsNull]).
pub fn requireFunction(realm: runtime.Context, object: runtime.JSValue, name: []const u8) !void {
    const value = try engine.getProperty(realm, object, name);
    defer value.release();
    if (!engine.isCallable(realm, value.value)) return error.TypeError;
}

/// Get(`object`, `name`) converted to sequence<DOMString> when it is not
/// undefined; an empty list when it is. OWNED by `allocator`
/// (`freeStrings`).
pub fn stringSequence(realm: runtime.Context, object: runtime.JSValue, name: []const u8, allocator: Allocator) ![][]u8 {
    const value = try engine.getProperty(realm, object, name);
    defer value.release();
    if (engine.typeOf(realm, value.value) == .undefined) return allocator.alloc([]u8, 0);
    return (try engine.convertToSequenceOfDOMStrings(realm, value.value, allocator)) orelse error.TypeError;
}

pub fn freeStrings(allocator: Allocator, strings: [][]u8) void {
    for (strings) |string| allocator.free(string);
    allocator.free(strings);
}

/// CSS Painting API 4 step 7 and CSS Layout API's filter: keep only the
/// supported CSS properties (CSSOM) and custom properties (a name starting
/// "--", CSS Variables 2), in order. Frees what it drops.
pub fn keepSupportedProperties(allocator: Allocator, names: [][]u8) [][]u8 {
    var kept: usize = 0;
    for (names) |name| {
        if (isSupportedOrCustomProperty(name)) {
            names[kept] = name;
            kept += 1;
        } else allocator.free(name);
    }
    return allocator.realloc(names, kept) catch names[0..kept];
}

fn isSupportedOrCustomProperty(name: []const u8) bool {
    if (std.mem.startsWith(u8, name, "--")) return true;
    var buffer: [64]u8 = undefined;
    if (name.len == 0 or name.len > buffer.len) return false;
    return css.PropertyParser.getPropertyType(std.ascii.lowerString(&buffer, name)) != .unknown;
}

/// A definitions map of a worklet global scope: name -> `Definition`, the
/// names OWNED.
pub fn Definitions(comptime Definition: type) type {
    return struct {
        const Self = @This();
        map: std.StringArrayHashMapUnmanaged(Definition) = .empty,

        pub fn contains(self: *const Self, name: []const u8) bool {
            return self.map.contains(name);
        }

        pub fn put(self: *Self, allocator: Allocator, name: []const u8, definition: Definition) !void {
            const key = try allocator.dupe(u8, name);
            errdefer allocator.free(key);
            try self.map.put(allocator, key, definition);
        }

        /// Free the map; `freeDefinition` frees each definition's own parts.
        pub fn deinit(self: *Self, allocator: Allocator, freeDefinition: *const fn (Allocator, *Definition) void) void {
            var entries = self.map.iterator();
            while (entries.next()) |entry| {
                freeDefinition(allocator, entry.value_ptr);
                allocator.free(entry.key_ptr.*);
            }
            self.map.deinit(allocator);
        }
    };
}

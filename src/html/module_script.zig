//! Module scripts: fetching a module script graph, linking it, running it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetching-scripts
//!       https://html.spec.whatwg.org/multipage/webappapis.html#hostloadimportedmodule
//!       https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
//!
//! HTML's side of modules: the module map, fetching, resolving specifiers,
//! "run a module script". The ECMAScript Module Records are the engine's,
//! reached through the engine protocol (`@import("engine")`: parseModule,
//! parseJSONModule, moduleRequests, linkModule, evaluateModule,
//! releaseModuleRecord), whose [[HostDefined]] is the `ModuleScript` here.
//!
//! The spec drives loading through ECMA-262's LoadRequestedModules, which calls
//! the host's HostLoadImportedModule once per module request, asynchronously.
//! V8 13.1 exposes no such hook for static imports: it resolves requests
//! synchronously during Link, so records are fetched and parsed before Link
//! answers requests from recorded children. Document consumers use an
//! AsyncModuleLoader, coalescing resource fetches and keeping each root's
//! visited set and source-order error walk independent (Blink's
//! ModuleTreeLinker design). Worker callers retain the synchronous walk.
//!
//! Where the engine has no modules (`engine.capabilities.module_scripts ==
//! .unsupported`, JavaScriptCore's public API) no graph is ever made: a
//! <script type=module> has a null result, so it fires `error`.
//!
//! CSS module scripts export a constructed CSSStyleSheet (its model is
//! dom.style.SheetRecord) through the engine's
//! CreateDefaultExportSyntheticModule; import.meta.resolve is the engine's
//! builtin over `resolve` (the hosts' HostHooks.importMetaResolve).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const fetch = @import("fetch");
const script_request = @import("script_request.zig");
const engine = @import("engine");
const dictionaries = @import("dictionaries");
// "UTF-8 decode" of a CSS module's body.
const css_rules = @import("css").rules;

const log = std.log.scoped(.module_script);

/// Whether this build's engine has ECMAScript modules. Every operation on a
/// Module Record is behind it, so an engine without them compiles the
/// fallback (no graph, a null script result) and nothing else.
pub const supported = engine.capabilities.module_scripts != .unsupported;

/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-type-from-module-request
pub const ModuleType = enum {
    /// "javascript-or-wasm" - the type of a request with no type attribute.
    javascript,
    json,
    css,
    /// "text": the response body, UTF-8 decoded, as the default export
    /// (HTML "create a text module script", whatwg/html#11933, merged
    /// 2026-04-01 - TC39 proposal-import-text's CreateTextModule). Golden
    /// rule 2: newer spec, shipped by two browsers - text-module/module.html
    /// and charset-bom.any.html Chrome PASS, Firefox PASS, Safari ERROR
    /// ('Import attribute type "text" is not valid') at wpt.fyi stable,
    /// df642c4142.
    text,

    fn keyPrefix(self: ModuleType) []const u8 {
        return switch (self) {
            .javascript => "js:",
            .json => "json:",
            .css => "css:",
            .text => "text:",
        };
    }

    /// HTML "fetch destination from module type" given
    /// `default_destination`: "json", "style" and "text" for those types,
    /// else the default ("script", or a worklet's destination).
    ///
    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-destination-from-module-type
    pub fn fetchDestination(self: ModuleType, default_destination: fetch.internal.Destination) fetch.internal.Destination {
        return switch (self) {
            .json => .json,
            .css => .style,
            .text => .text,
            .javascript => default_destination,
        };
    }
};

/// A module script (HTML "module script") and the graph edges out of it.
///
/// Owned by the document's module map - see `ModuleMap` - for as long as the
/// document lives, which is what lets the same URL imported twice share one
/// record, as the module map requires.
pub const ModuleScript = struct {
    allocator: std.mem.Allocator,

    /// The Module Record (OWNED: releaseModuleRecord), or null when the
    /// source failed to parse ("record" in the spec). Its [[HostDefined]] is
    /// this script.
    record: ?*engine.ModuleRecord = null,

    /// Owned. The response URL for a fetched script, the document base URL for
    /// an inline one. Imports resolve against it; it is import.meta.url.
    base_url: []const u8,

    /// The parse error (OWNED), when `record` is null.
    parse_error: ?engine.Owned = null,
    /// HostLoadImportedModule validates every static specifier before
    /// fetching any child. Like a parse error, a validation error belongs to
    /// this script and is reused by each root that imports it.
    validation_error: ?engine.Owned = null,

    /// The error to rethrow (OWNED): set by "fetch the descendants of and
    /// link" when the graph cannot be linked, and reported instead of
    /// evaluating when the script runs.
    error_to_rethrow: ?engine.Owned = null,

    /// The error to rethrow came from LOADING the graph - a parse error, an
    /// unresolvable specifier or an unsupported type - not from linking it.
    /// HTML treats a load failure like a parse error, so it is kept: every
    /// later import of this script rethrows the same object. A link error is
    /// computed afresh by each attempt (dynamic-imports-script-error.html pins
    /// both halves).
    load_error: bool = false,

    /// Resolved module requests, in the order the source makes them.
    children: std.ArrayListUnmanaged(Child) = .empty,

    /// The script's fetch options, as far as an import() from it reads them
    /// (HTML "new descendant script fetch options"): its cryptographic nonce
    /// (OWNED when not empty), referrer policy, credentials and render-blocking.
    nonce: []const u8 = "",
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    credentials_mode: fetch.internal.CredentialsMode = .same_origin,
    render_blocking: bool = false,

    /// Depth-first walk state. `visiting` is set while this script's requests
    /// are being loaded, so a cycle back to it stops instead of recursing
    /// forever - the spec's LoadRequestedModules does the same through
    /// [[Status]] "new" versus "unlinked".
    visiting: bool = false,
    /// This script and everything under it has been loaded successfully.
    loaded: bool = false,

    /// Marks a node already visited by the current `findByRecord` walk.
    search_epoch: u32 = 0,

    /// Links in `live_scripts`, while this script exists: the engine hands
    /// it back as a record's [[HostDefined]] (import.meta, an import()'s
    /// referrer), and only a script still in the list is read.
    live_prev: ?*ModuleScript = null,
    live_next: ?*ModuleScript = null,
    live: bool = false,

    pub const Child = struct {
        /// Owned copy of the request's specifier.
        specifier: []const u8,
        module_type: ModuleType,
        /// Owned by the module map, like every fetched module script.
        script: *ModuleScript,
    };

    /// A module script with `base_url`, fetched (or inline) with `options`.
    fn create(allocator: std.mem.Allocator, base_url: []const u8, options: FetchOptions) !*ModuleScript {
        const self = try allocator.create(ModuleScript);
        errdefer allocator.destroy(self);
        const owned_base_url = try allocator.dupe(u8, base_url);
        errdefer allocator.free(owned_base_url);
        self.* = .{
            .allocator = allocator,
            .base_url = owned_base_url,
            .nonce = if (options.nonce.len > 0) try allocator.dupe(u8, options.nonce) else "",
            .referrer_policy = options.referrer_policy,
            .credentials_mode = options.credentials_mode,
            .render_blocking = options.render_blocking,
        };
        track(self);
        return self;
    }

    /// HTML "new descendant script fetch options" for this script's fetch
    /// options: nonce, referrer policy, credentials and render-blocking;
    /// integrity metadata "", parser metadata "not-parser-inserted".
    /// Borrowed from the script.
    pub fn descendantFetchOptions(self: *const ModuleScript) FetchOptions {
        return .{ .nonce = self.nonce, .referrer_policy = self.referrer_policy, .credentials_mode = self.credentials_mode, .render_blocking = self.render_blocking };
    }

    /// Release the script, its record and values, and its edge list.
    /// Children are not freed - the module map owns them.
    pub fn destroy(self: *ModuleScript) void {
        untrack(self);
        if (supported) {
            if (self.record) |record| engine.releaseModuleRecord(record);
        }
        if (self.parse_error) |value| value.release();
        if (self.validation_error) |value| value.release();
        if (self.error_to_rethrow) |value| value.release();
        for (self.children.items) |child| self.allocator.free(child.specifier);
        self.children.deinit(self.allocator);
        self.allocator.free(self.base_url);
        if (self.nonce.len > 0) self.allocator.free(self.nonce);
        self.allocator.destroy(self);
    }

    fn setErrorToRethrow(self: *ModuleScript, value: engine.Owned) void {
        if (self.error_to_rethrow) |old| old.release();
        self.error_to_rethrow = value;
    }
};

/// The settings object's module map - a document's or a worker global
/// scope's - reached through its owner.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
/// Keyed by (URL, module type). Values are a `*ModuleScript`, cast to
/// *anyopaque; the owner frees them through `disposeEntry`. A fetch that
/// failed leaves no entry (fetch a single module script step 13.1.2, after
/// whatwg/html#10327): the next import of the URL fetches it again. A fetch
/// still in flight is the asynchronous loader's (`AsyncModuleLoader.pending`,
/// the spec's callback list), not an entry here.
pub const ModuleMap = struct {
    context: *anyopaque,
    getFn: *const fn (context: *anyopaque, key: []const u8) ?*anyopaque,
    putFn: *const fn (context: *anyopaque, key: []const u8, value: *anyopaque) bool,

    fn get(self: ModuleMap, key: []const u8) ?*anyopaque {
        return self.getFn(self.context, key);
    }

    fn put(self: ModuleMap, key: []const u8, value: *anyopaque) bool {
        return self.putFn(self.context, key, value);
    }
};

/// Free a module map value. The owner of the map installs this as its dispose
/// function.
pub fn disposeEntry(value: *anyopaque) void {
    const script: *ModuleScript = @ptrCast(@alignCast(value));
    script.destroy();
}

/// HTML's script fetch options, as far as a module graph's requests use
/// them: cryptographic nonce, integrity, parser metadata, render-blocking,
/// referrer policy and credentials mode.
/// Borrowed for as long as the graph is fetched.
pub const FetchOptions = struct {
    nonce: []const u8 = "",
    /// The root request's integrity; each descendant obtains its metadata
    /// from the import map's integrity section.
    integrity: []const u8 = "",
    parser_inserted: bool = false,
    render_blocking: bool = false,
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    /// The script fetch options' credentials mode: "same-origin" by
    /// default; WorkerOptions or WorkletOptions supplies it for those
    /// graphs (HTML "fetch a worklet/module worker script graph" step 1).
    credentials_mode: fetch.internal.CredentialsMode = .same_origin,
    /// The fetch priority: a modulepreload link's fetchpriority attribute;
    /// "auto" otherwise (and for every descendant).
    fetch_priority: fetch.internal.request.Priority = .auto,
};

/// Everything the loader needs from the document it loads for.
pub const Environment = struct {
    allocator: std.mem.Allocator,
    /// Any instance of the document's realm: the ctx for URL parsing, and -
    /// unless `realm_override` names another - the realm the module scripts'
    /// records are made in.
    context_instance: *runtime.Instance,
    map: ModuleMap,
    /// The document's import map lookup: the mapped URL for `specifier`
    /// (borrowed), or null when the import map does not mention it. Called
    /// with `map.context`, the document.
    resolveImportFn: ?*const fn (context: *anyopaque, specifier: []const u8, base_url: []const u8) ?[]const u8 = null,
    resolveIntegrityFn: ?*const fn (context: *anyopaque, url: []const u8) ?[]const u8 = null,

    /// The realm the records are made in, when it is not the document's: a
    /// ShadowRealm's, whose synthetic realm settings object has a module map
    /// of its own and parses URLs against its principal realm's settings
    /// (`context_instance`). A ShadowRealm has no platform object to name it.
    realm_override: ?runtime.Context = null,
    /// HTML "module type allowed" for "css": only where the CSSStyleSheet
    /// interface is exposed in the settings object's realm - a Window's, not
    /// a worker's.
    css_allowed: bool = true,
    /// The script fetch options the graph's requests carry: the root's, and
    /// - "fetch the descendants of a module script" gets the descendant
    /// script fetch options from the referrer script's - its descendants'.
    fetch_options: FetchOptions = .{},
    /// The initial worker graph's creating-side referrer-policy default,
    /// used only by synchronous static requests with empty script options.
    /// This is not copied into module records: a later import() uses its
    /// own environment and the worker's policy. Response headers win.
    static_referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    /// The destination of a JavaScript module's request: "script", or a
    /// worker/worklet's destination type (HTML "fetch a worklet/module
    /// worker script graph"). A JSON or CSS module's is still "json" or
    /// "style" (HTML "fetch a single module script" step 1).
    script_destination: fetch.internal.Destination = .script,
    /// Borrowed for a synchronous fetch. Empty means the client referrer;
    /// an imported script otherwise uses the referencing script's base URL.
    referrer: []const u8 = "",

    /// A service worker's "perform the fetch" hook, as far as it keeps the
    /// responses of the module scripts its graph fetches beyond the root
    /// (Service Workers Update step 7's hook, step 4; the worker's script
    /// resource map): run after each such fetch with its URL and response
    /// (BORROWED for the call). Null - every other loader - changes nothing.
    fetched: ?FetchedHook = null,

    pub const FetchedHook = struct {
        context: *anyopaque,
        run: *const fn (context: *anyopaque, url: []const u8, response: *const fetch.internal.InternalResponse) void,
    };

    /// HTML resolve a module integrity metadata: absent entries give "".
    pub fn resolveIntegrity(self: *const Environment, url: []const u8) []const u8 {
        const lookup = self.resolveIntegrityFn orelse return "";
        return lookup(self.map.context, url) orelse "";
    }

    /// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-type-allowed
    pub fn moduleTypeAllowed(self: *const Environment, module_type: ModuleType) bool {
        return module_type != .css or self.css_allowed;
    }

    /// The settings object's realm: every record and value is made in it.
    pub fn realm(self: *const Environment) runtime.Context {
        return self.realm_override orelse self.context_instance.ctx;
    }
};

// =============================================================================
// Creating module scripts
// =============================================================================

/// Create a JavaScript module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-javascript-module-script
/// Step 7 ParseModule, with the script as [[HostDefined]]; step 8: on a
/// syntax error the script's parse error is that error and its record stays
/// null. `start` is where `source` starts in its resource: an inline module
/// script's position in its document (the parser's, script_element.State),
/// `.{}` for a fetched one - so what it throws reports its document's lines
/// (Blink's ModuleScriptCreationParams keep the inline script's start).
pub fn createJavaScriptModuleScript(
    env: *const Environment,
    source: []const u8,
    start: engine.SourcePosition,
    base_url: []const u8,
) !*ModuleScript {
    if (!supported) return error.NotSupported;
    const script = try ModuleScript.create(env.allocator, base_url, env.fetch_options);
    errdefer script.destroy();

    switch (try engine.parseModule(env.realm(), source, start, base_url, script)) {
        .record => |record| script.record = record,
        .parse_error => |parse_error| script.parse_error = parse_error,
    }
    return script;
}

// =============================================================================
// import.meta, and the scripts a record names
// =============================================================================

/// Every module script alive: the page's, its frames' and its workers'. A
/// module map owns each; this only links them, so that a [[HostDefined]]
/// the engine hands back is read only while its script exists. Workers run
/// on threads of their own (docs/instances.md), so the list is reached only
/// under its `mutex`.
const LiveScripts = struct {
    /// Protects `head` and every script's `live_prev`/`live_next`/`live`;
    /// held for one link, unlink or walk, never across a call out of this
    /// file.
    mutex: std.Io.Mutex = .init,
    head: ?*ModuleScript = null,
};
var live_scripts: LiveScripts = .{};

fn track(script: *ModuleScript) void {
    std.Io.Threaded.mutexLock(&live_scripts.mutex);
    defer std.Io.Threaded.mutexUnlock(&live_scripts.mutex);
    script.live_prev = null;
    script.live_next = live_scripts.head;
    if (live_scripts.head) |head| head.live_prev = script;
    live_scripts.head = script;
    script.live = true;
}

fn untrack(script: *ModuleScript) void {
    std.Io.Threaded.mutexLock(&live_scripts.mutex);
    defer std.Io.Threaded.mutexUnlock(&live_scripts.mutex);
    if (!script.live) return;
    if (script.live_prev) |prev| prev.live_next = script.live_next else live_scripts.head = script.live_next;
    if (script.live_next) |next| next.live_prev = script.live_prev;
    script.live = false;
}

/// The module script a record's [[HostDefined]] names, while it exists.
/// (A freed script's address reused by a new one is read as the new one: a
/// wrong base URL, never freed memory.) The engine hands back only a
/// [[HostDefined]] of the calling thread's own realms, so the script found
/// is this thread's, and stays while its realm does.
pub fn scriptOf(host_defined: *anyopaque) ?*ModuleScript {
    std.Io.Threaded.mutexLock(&live_scripts.mutex);
    defer std.Io.Threaded.mutexUnlock(&live_scripts.mutex);
    var it = live_scripts.head;
    while (it) |script| : (it = script.live_next) {
        if (@as(*anyopaque, @ptrCast(script)) == host_defined) return script;
    }
    return null;
}

/// A classic script's [[HostDefined]]: what the host hands runClassicScript
/// (and evaluateClassicScript*) as `host_defined` - HTML's classic script, as
/// far as import() needs it: its base URL, which an import() from it resolves
/// against (HostLoadImportedModule step 6). It must live as long as the
/// script's realm: a function the script defined can call import() at any
/// time.
pub const ClassicScript = struct {
    base_url: []const u8,
    /// Its fetch options, as far as an import() from it reads them (HTML
    /// "new descendant script fetch options"): nonce, referrer policy,
    /// credentials and render-blocking. Owned by whoever owns the script.
    nonce: []const u8 = "",
    referrer_policy: fetch.internal.ReferrerPolicy = .empty,
    credentials_mode: fetch.internal.CredentialsMode = .same_origin,
    render_blocking: bool = false,

    /// HTML "new descendant script fetch options" for this script's.
    pub fn descendantFetchOptions(self: *const ClassicScript) FetchOptions {
        return .{ .nonce = self.nonce, .referrer_policy = self.referrer_policy, .credentials_mode = self.credentials_mode, .render_blocking = self.render_blocking };
    }
};

/// The classic script a Script Record's [[HostDefined]] is (a worker's: its
/// host makes every one it runs).
pub fn classicScriptOf(host_defined: *anyopaque) *const ClassicScript {
    return @ptrCast(@alignCast(host_defined));
}

/// The base URL of the classic script a Script Record's [[HostDefined]] is.
pub fn classicScriptBaseUrl(host_defined: *anyopaque) []const u8 {
    return classicScriptOf(host_defined).base_url;
}

/// HTML HostGetImportMetaProperties(moduleRecord), steps 1-3 - the engine's
/// `HostHooks.importMetaUrl`: import.meta.url is the module script's base URL
/// - the response URL for a fetched script, the document's base URL for an
/// inline one. BORROWED while the script lives.
pub fn importMetaUrl(host: ?*anyopaque, module_host_defined: *anyopaque) []const u8 {
    _ = host;
    const script = scriptOf(module_host_defined) orelse return "";
    return script.base_url;
}

/// Create a JSON module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-json-module-script
/// Step 5: ParseJSONModule - a SyntaxError becomes the parse error.
fn createJsonModuleScript(env: *const Environment, source: []const u8, url: []const u8) !*ModuleScript {
    if (!supported) return error.NotSupported;
    const script = try ModuleScript.create(env.allocator, url, env.fetch_options);
    errdefer script.destroy();

    switch (try engine.parseJSONModule(env.realm(), source, url, script)) {
        .record => |record| script.record = record,
        .parse_error => |parse_error| script.parse_error = parse_error,
    }
    return script;
}

/// Create a CSS module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-css-module-script
/// "5. Let sheet be the result of running the steps to create a constructed
///  CSSStyleSheet with an empty dictionary as the argument. 6. Run the steps
///  to synchronously replace the rules of a CSSStyleSheet on sheet given
///  source. 7. If this throws an exception, catch it, and set script's parse
///  error to that exception, and return script. 8. Set script's record to
///  the result of CreateDefaultExportSyntheticModule(sheet)." The sheet is
/// made in the settings object's realm, through its interface.
///
/// The sheet's base URL is the module's URL (its response's, after any
/// redirect), passed as the constructor's baseURL: its url()s resolve
/// against the CSS file, not the importing document. Golden rule 2: HTML's
/// steps give the sheet no base URL; Chrome and Firefox resolve against the
/// module (css-module/relative-urls.html and redirect-relative-urls.html:
/// Chrome 1/1 and 2/2, Firefox 1/1 and 2/2, Safari ERROR - it has no CSS
/// module scripts - at wpt.fyi stable, df642c4142).
fn createCssModuleScript(env: *const Environment, source: []const u8, url: []const u8) !*ModuleScript {
    if (!supported) return error.NotSupported;
    const script = try ModuleScript.create(env.allocator, url, env.fetch_options);
    errdefer script.destroy();
    const realm = env.realm();

    // Step 5.
    const sheet = try interfaces.CSSStyleSheet.call_constructor(realm, webidl.Opt(dictionaries.CSSStyleSheetInit).passed(.{ .baseURL = runtime.DOMString.initInterned(url) }));
    // Until the record holds it, the sheet has no wrapper to be collected
    // with.
    var sheet_held = false;
    defer if (!sheet_held) runtime.Instance.deinit(sheet);

    // Steps 6-7. replaceSync throws only for a sheet that is not
    // constructed or not modifiable, which a new one never is: a failure
    // here is Crane's own (out of memory), and the script fails to load.
    try interfaces.CSSStyleSheet.call_replaceSync(sheet, source);

    // Step 8.
    script.record = try engine.createDefaultExportSyntheticModule(realm, .{ .instance = sheet }, url, script);
    sheet_held = true;
    return script;
}

/// Create a text module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-text-module-script
/// "5. Let result be CreateTextModule(text)" - TC39 proposal-import-text:
/// CreateDefaultExportSyntheticModule(text), a Synthetic Module Record whose
/// default export is the string. `text` is the UTF-8 decoded body (fetch a
/// single module script step 13.7.1), as UTF-8. Nothing is parsed, so there
/// is no parse error.
///
/// HTML step 3 makes the script's base URL null. The record still names
/// `url`, as a CSS or JSON one does: nothing resolves against it, since a
/// text module imports nothing.
fn createTextModuleScript(env: *const Environment, text: []const u8, url: []const u8) !*ModuleScript {
    if (!supported) return error.NotSupported;
    const script = try ModuleScript.create(env.allocator, url, env.fetch_options);
    errdefer script.destroy();
    script.record = try engine.createDefaultExportSyntheticModule(env.realm(), runtime.JSValue.fromStringRef(text), url, script);
    return script;
}

/// A second hold (OWNED) on a value a script keeps, in its realm.
fn copyOf(env: *const Environment, value: engine.Owned) ?engine.Owned {
    return engine.retainValue(env.realm(), value.value) catch null;
}

/// The errors the host raises itself.
const ErrorKind = enum { type_error, syntax_error };

/// A new exception of the given kind in `env`'s realm (OWNED). Used for the
/// errors the host itself raises: an unresolvable specifier, an unsupported
/// type attribute.
fn makeError(env: *const Environment, kind: ErrorKind, message: []const u8) ?engine.Owned {
    return engine.createSimpleException(env.realm(), switch (kind) {
        .type_error => .TypeError,
        .syntax_error => .SyntaxError,
    }, message) catch null;
}

// =============================================================================
// Fetching
// =============================================================================

/// Fetch a single module script, synchronously.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-single-module-script
/// Returns the module script, or null for "null" (a failed fetch, a status
/// that is not ok, or a MIME type that does not match the module type).
/// Used where no event loop can carry an asynchronous fetch: a module
/// worker's own graph, a ShadowRealm's import(), an engine-less context.
fn fetchSingleModuleScript(env: *const Environment, url: []const u8, module_type: ModuleType) ?*ModuleScript {
    // Step 5: moduleMap[(url, moduleType)] is a module script - reused. (No
    // fetch is ever in flight here, so step 6's callback list never is.)
    const key = std.mem.concat(env.allocator, u8, &.{ module_type.keyPrefix(), url }) catch return null;
    defer env.allocator.free(key);

    if (env.map.get(key)) |entry| return @ptrCast(@alignCast(entry));

    // Step 13.1: a failure removes the entry - here, never makes one - so a
    // later import fetches again (repeated-imports.any.js).
    const script = fetchAndCreate(env, url, module_type) orelse return null;

    // Step 13.9: moduleMap[(url, moduleType)] = moduleScript.
    if (!env.map.put(key, @ptrCast(script))) {
        // The map could not take ownership; nothing else will free it.
        script.destroy();
        return null;
    }
    return script;
}

fn fetchAndCreate(env: *const Environment, url: []const u8, module_type: ModuleType) ?*ModuleScript {
    // "Let request be a new request whose URL is url, mode is "cors",
    // referrer is referrer, and client is fetchClient." "Set request's
    // destination to the result of running the fetch destination from module
    // type steps given destination and moduleType" - "json" for a JSON
    // module, "style" for a CSS one, "script" otherwise. "Set request's
    // initiator type to "script"." Then "set up the module script request":
    // its credentials mode is the fetch options', "same-origin" by default.
    //
    // "Set up the module script request given request and options": its
    // cryptographic nonce metadata, integrity metadata, parser metadata and
    // referrer policy and credentials mode are the options'.
    const request = script_request.InternalRequest.init(env.allocator, url) catch return null;
    defer request.deinit();
    request.mode = .cors;
    request.credentials_mode = env.fetch_options.credentials_mode;
    const options = env.fetch_options;
    if (options.nonce.len > 0) request.setCryptographicNonceMetadata(options.nonce) catch return null;
    request.setIntegrityMetadata(options.integrity) catch return null;
    request.parser_metadata = if (options.parser_inserted) .parser_inserted else .not_parser_inserted;
    request.referrer_policy = if (options.referrer_policy != .empty) options.referrer_policy else env.static_referrer_policy;
    request.render_blocking = options.render_blocking;
    request.destination = module_type.fetchDestination(env.script_destination);
    request.initiator_type = .script;
    script_request.populateRequestFromClient(request, env.context_instance.ctx) catch return null;
    if (env.referrer.len > 0) request.setReferrerUrl(env.referrer) catch return null;

    // Step 13: fetch. A failure - transport, CORS, or main fetch step 19's MIME
    // type / nosniff block, which keys on the destination - comes back
    // in-band as a network-error response.
    var fetched = fetch.algorithms.fetch(env.allocator, request, .{}) catch return null;
    defer fetched.timing_info.deinit();
    const response = fetched.response;
    defer response.deinit();
    if (env.fetched) |hook| hook.run(hook.context, url, response);

    // The same response steps as the async loader, including a response's
    // Referrer-Policy for subsequent static and dynamic imports.
    return createFromResponse(env, url, module_type, response);
}

/// The essence of the MIME type Fetch's "extract a MIME type" finds in a
/// Content-Type value, lowercased - or "" for failure, which matches no MIME
/// type. Written into a thread-local buffer.
///
/// Spec: https://fetch.spec.whatwg.org/#concept-header-extract-mime-type
/// The value is split on commas outside quoted strings, every piece is
/// parsed as a MIME type, and the last one that parses (and is not */*)
/// wins. Only the essence matters here, so the charset bookkeeping of steps
/// 6.4-6.5 is not needed.
fn mimeEssence(content_type: []const u8) []const u8 {
    // The essence found so far, in a buffer of its own: parseMimeEssence
    // writes every piece it looks at into ITS buffer, so a slice of that is
    // overwritten by the next piece - even one then rejected ("*/*", or not a
    // MIME type at all), which turned "text/plain, */*" into "*/*t/plain".
    const R = struct {
        threadlocal var buf: [256]u8 = undefined;
    };
    var essence: []const u8 = "";
    var start: usize = 0;
    var in_quotes = false;
    var i: usize = 0;
    while (i <= content_type.len) : (i += 1) {
        if (i < content_type.len) {
            const c = content_type[i];
            if (in_quotes and c == '\\') {
                i += 1;
                continue;
            }
            if (c == '"') in_quotes = !in_quotes;
            if (in_quotes or c != ',') continue;
        }
        if (parseMimeEssence(content_type[start..i])) |parsed| {
            if (!std.mem.eql(u8, parsed, "*/*")) {
                @memcpy(R.buf[0..parsed.len], parsed);
                essence = R.buf[0..parsed.len];
            }
        }
        start = i + 1;
    }
    return essence;
}

/// MIME Sniffing "parse a MIME type", as far as the essence: null for
/// failure, else "type/subtype" lowercased into a thread-local buffer.
///
/// Spec: https://mimesniff.spec.whatwg.org/#parse-a-mime-type
/// Steps 1-9: the type and the subtype must each be non-empty and made of
/// HTTP token code points only - so a Content-Type of "text/json+x",
/// "applic ation/x+json" or "application/vnd api+json" is no JSON MIME type,
/// where taking everything before the first ";" would have made each one.
fn parseMimeEssence(input: []const u8) ?[]const u8 {
    const S = struct {
        threadlocal var buf: [256]u8 = undefined;
    };
    // Step 1: strip leading and trailing HTTP whitespace.
    const trimmed = std.mem.trim(u8, input, " \t\r\n");
    // Steps 2-5: the type runs to the first "/", which must exist.
    const slash = std.mem.indexOfScalar(u8, trimmed, '/') orelse return null;
    const type_part = trimmed[0..slash];
    if (type_part.len == 0 or !isHttpTokenString(type_part)) return null;
    // Steps 6-8: the subtype runs to the first ";", less trailing HTTP
    // whitespace.
    const rest = trimmed[slash + 1 ..];
    const end = std.mem.indexOfScalar(u8, rest, ';') orelse rest.len;
    const subtype = std.mem.trimEnd(u8, rest[0..end], " \t\r\n");
    if (subtype.len == 0 or !isHttpTokenString(subtype)) return null;
    // Step 9: both in ASCII lowercase.
    const len = type_part.len + 1 + subtype.len;
    if (len > S.buf.len) return null;
    _ = std.ascii.lowerString(S.buf[0..type_part.len], type_part);
    S.buf[type_part.len] = '/';
    _ = std.ascii.lowerString(S.buf[type_part.len + 1 .. len], subtype);
    return S.buf[0..len];
}

/// Spec: https://mimesniff.spec.whatwg.org/#http-token-code-point
fn isHttpTokenString(s: []const u8) bool {
    for (s) |c| {
        if (std.ascii.isAlphanumeric(c)) continue;
        if (std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~", c) == null) return false;
    }
    return true;
}

/// Whether the MIME type Fetch's "extract a MIME type" finds in a
/// Content-Type value is a JavaScript MIME type.
pub fn isJavaScriptMimeType(content_type: []const u8) bool {
    return isJavaScriptMimeTypeEssence(mimeEssence(content_type));
}

/// Spec: https://mimesniff.spec.whatwg.org/#javascript-mime-type
fn isJavaScriptMimeTypeEssence(essence: []const u8) bool {
    const types = [_][]const u8{
        "application/ecmascript",   "application/javascript", "application/x-ecmascript",
        "application/x-javascript", "text/ecmascript",        "text/javascript",
        "text/javascript1.0",       "text/javascript1.1",     "text/javascript1.2",
        "text/javascript1.3",       "text/javascript1.4",     "text/javascript1.5",
        "text/jscript",             "text/livescript",        "text/x-ecmascript",
        "text/x-javascript",
    };
    for (types) |t| if (std.mem.eql(u8, essence, t)) return true;
    return false;
}

/// Spec: https://mimesniff.spec.whatwg.org/#json-mime-type
/// "application/json", "text/json", or any subtype ending in "+json".
fn isJsonMimeTypeEssence(essence: []const u8) bool {
    if (std.mem.eql(u8, essence, "application/json") or std.mem.eql(u8, essence, "text/json")) return true;
    const slash = std.mem.indexOfScalar(u8, essence, '/') orelse return false;
    return std.mem.endsWith(u8, essence[slash + 1 ..], "+json");
}

// =============================================================================
// Resolving module specifiers
// =============================================================================

/// Resolve a module specifier.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#resolve-a-module-specifier
/// Returns an owned URL (env.context_instance.ctx.allocator), or null where
/// the spec throws its TypeError.
fn resolveModuleSpecifier(env: *const Environment, specifier: []const u8, base_url: []const u8) ?[]const u8 {
    // Steps 4-5: URL-like specifiers are normalized before the map lookup.
    // In particular, importing import.meta.resolve()'s result applies the map
    // again, using that absolute URL as the normalized specifier.
    const as_url = resolveUrlLikeModuleSpecifier(env, specifier, base_url);
    const normalized = as_url orelse specifier;
    if (env.resolveImportFn) |resolveImport| {
        if (resolveImport(env.map.context, normalized, base_url)) |mapped| {
            defer if (as_url) |url| env.context_instance.ctx.allocator.free(url);
            return parseUrl(env, mapped, "");
        }
    }

    // Step 9: with no mapping, use the URL-like resolution, if any.
    return as_url;
}

/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#resolving-a-url-like-module-specifier
fn resolveUrlLikeModuleSpecifier(env: *const Environment, specifier: []const u8, base_url: []const u8) ?[]const u8 {
    // Step 1: "/", "./" or "../" - parse relative to the base URL.
    if (std.mem.startsWith(u8, specifier, "/") or
        std.mem.startsWith(u8, specifier, "./") or
        std.mem.startsWith(u8, specifier, "../"))
    {
        return parseUrl(env, specifier, base_url);
    }
    // Steps 2-4: otherwise only an absolute URL resolves; anything else is a
    // bare specifier, which only an import map can map.
    return parseUrl(env, specifier, "");
}

fn parseUrl(env: *const Environment, input: []const u8, base: []const u8) ?[]const u8 {
    const base_arg = if (base.len > 0)
        webidl.Opt(runtime.USVString).passed(base)
    else
        webidl.Opt(runtime.USVString).notPassed();
    const url_instance = (interfaces.URL.call_static_parse(env.context_instance, input, base_arg) catch
        return null) orelse return null;
    // Never exposed to script, so nothing else will free it.
    defer runtime.Instance.deinit(url_instance);
    return interfaces.URL.get_href(url_instance) catch null;
}

// =============================================================================
// Fetching the descendants of and linking a module script
// =============================================================================

/// Fetch an external module script graph.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-module-script-tree
/// Returns the graph's root to hand onComplete, or null for "null".
pub fn fetchExternalModuleScriptGraph(env: *const Environment, url: []const u8) ?*ModuleScript {
    // No modules in this engine: no graph (the script's result is null, and
    // the element fires `error`).
    if (!supported) return null;
    // Step 1: fetch a single module script, "javascript-or-wasm".
    // Step 1.1: if result is null, onComplete is given null.
    const result = fetchSingleModuleScript(env, url, .javascript) orelse return null;
    // Step 1.2: fetch the descendants of and link result - with the
    // descendant script fetch options, whose integrity metadata is not the
    // root's.
    var descendants = env.*;
    descendants.fetch_options.integrity = "";
    descendants.fetch_options.parser_inserted = false;
    return fetchDescendantsAndLink(&descendants, result);
}

/// Fetch a module worker script graph, with the root's response in hand.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-a-module-worker-script-tree
/// "Fetch a worklet/module worker script graph": fetch a single module script
/// given url - moduleMap[(url, "javascript-or-wasm")], else the response,
/// which becomes a JavaScript module script whose base URL is the response's
/// URL (step 13.7.2) - then fetch the descendants of and link it. The
/// worker's constructor fetched the root already (a blob: URL may be revoked
/// as soon as it returns), so `source` and `response_url` are that fetch's
/// body and URL, its MIME type already checked; the module map, the
/// descendants and linking are the worker's settings object's.
/// Returns the graph's root for onComplete, or null for "null".
pub fn moduleWorkerScriptGraph(env: *const Environment, url: []const u8, response_url: []const u8, source: []const u8) ?*ModuleScript {
    if (!supported) return null;
    const key = std.mem.concat(env.allocator, u8, &.{ ModuleType.javascript.keyPrefix(), url }) catch return null;
    defer env.allocator.free(key);
    const script: *ModuleScript = if (env.map.get(key)) |entry| @ptrCast(@alignCast(entry)) else blk: {
        const created = createJavaScriptModuleScript(env, source, .{}, response_url) catch return null;
        if (!env.map.put(key, @ptrCast(created))) {
            created.destroy();
            return null;
        }
        break :blk created;
    };
    return fetchDescendantsAndLink(env, script);
}

/// The module type an import's "type" attribute asks for, or null for a type
/// the host does not support ("module type allowed" is false: TypeError).
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-type-from-module-request
pub fn moduleTypeFromAttribute(type_attribute: ?[]const u8) ?ModuleType {
    const t = type_attribute orelse return .javascript;
    if (std.mem.eql(u8, t, "json")) return .json;
    if (std.mem.eql(u8, t, "css")) return .css;
    if (std.mem.eql(u8, t, "text")) return .text;
    // "javascript-or-wasm" is the internal name of the default type: as an
    // attribute it is no type at all (module type from module request step
    // 2.1), and neither is anything else.
    return null;
}

/// Resolve a module specifier against `base_url`. Returns an owned URL
/// (env.context_instance.ctx.allocator), or null where the spec throws.
pub fn resolve(env: *const Environment, specifier: []const u8, base_url: []const u8) ?[]const u8 {
    return resolveModuleSpecifier(env, specifier, base_url);
}

/// The graph an import() loads: fetch a single imported module script of
/// `module_type` at `url` (through the module map), then fetch the
/// descendants of and link it. Null means "null" - a failed fetch.
pub fn fetchImportedModuleScriptGraph(env: *const Environment, url: []const u8, module_type: ModuleType) ?*ModuleScript {
    if (!supported) return null;
    var imported = env.*;
    imported.fetch_options.integrity = env.resolveIntegrity(url);
    const script = fetchSingleModuleScript(&imported, url, module_type) orelse return null;
    return fetchDescendantsAndLink(&imported, script);
}

/// What a failed load leaves behind, mirroring LoadRequestedModules' state:
/// either an error to rethrow (a "syntactic" failure somewhere in the graph)
/// or none (a fetch failure, which makes the whole graph null).
const LoadFailure = union(enum) {
    fetch_failed,
    /// OWNED.
    rethrow: engine.Owned,
};

/// Fetch the descendants of and link a module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-the-descendants-of-and-link-a-module-script
/// Returns the script to hand onComplete, or null for "null". The script may
/// carry an error to rethrow instead of a linkable record.
pub fn fetchDescendantsAndLink(env: *const Environment, script: *ModuleScript) ?*ModuleScript {
    if (!supported) return null;
    // Step 2: a script whose own source did not parse rethrows its parse error.
    if (script.record == null) {
        if (script.parse_error) |parse_error| {
            if (copyOf(env, parse_error)) |copy| script.setErrorToRethrow(copy);
        }
        return script;
    }

    // A graph that already failed to load fails the same way, with the same
    // error (see `load_error`); a link failure is retried below.
    if (script.error_to_rethrow != null and script.load_error) return script;

    // Step 5: LoadRequestedModules.
    if (loadRequestedModules(env, script)) |failure| {
        switch (failure) {
            // Step 7.2: rejected with no error to rethrow - a loading error.
            .fetch_failed => return null,
            // Step 7.1.
            .rethrow => |value| {
                script.setErrorToRethrow(value);
                script.load_error = true;
                return script;
            },
        }
    }

    // Step 6.1: Link. A failure becomes the error to rethrow; a success
    // clears one left by an earlier failed attempt.
    if (link(env, script)) |value| {
        script.setErrorToRethrow(value);
    } else if (script.error_to_rethrow) |old| {
        old.release();
        script.error_to_rethrow = null;
    }
    return script;
}

/// Per-root discovery state, independent of the shared module records. A
/// cycle or a second edge to the same URL never adds another pending fetch.
pub const GraphProgress = struct {
    allocator: std.mem.Allocator,
    visited: std.StringHashMap(void),
    pending: usize = 0,

    pub fn init(allocator: std.mem.Allocator) GraphProgress {
        return .{ .allocator = allocator, .visited = std.StringHashMap(void).init(allocator) };
    }

    pub fn deinit(self: *GraphProgress) void {
        self.cancel();
        self.visited.deinit();
    }

    pub fn visit(self: *GraphProgress, key: []const u8) !bool {
        if (self.visited.contains(key)) return false;
        const owned = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned);
        try self.visited.put(owned, {});
        self.pending += 1;
        return true;
    }

    pub fn completeOne(self: *GraphProgress) bool {
        std.debug.assert(self.pending > 0);
        self.pending -= 1;
        return self.pending == 0;
    }

    pub fn cancel(self: *GraphProgress) void {
        var keys = self.visited.keyIterator();
        while (keys.next()) |key| self.allocator.free(key.*);
        self.visited.clearRetainingCapacity();
        self.pending = 0;
    }
};

/// HTML's asynchronous module-map callback lists and per-root graph linkers,
/// for one settings object: a Document's (script elements, import(),
/// modulepreload, a worklet's graphs) or a worker global scope's (import()).
/// Owned by its owner - the Document, or the WorkerHost - and destroyed
/// before that owner's module-map records. All operations happen on the
/// owner's event-loop thread: the window agent's, or the worker's own.
///
/// Design reference: Blink core/loader/modulescript/module_tree_linker.cc,
/// FetchDescendants / NotifyModuleLoadFinished / FindFirstParseError; one
/// loader for every kind of owner as WebKit's ScriptModuleLoader serves a
/// Document and a WorkerGlobalScope alike (its OwnerType).
pub const AsyncModuleLoader = struct {
    allocator: std.mem.Allocator,
    env: Environment,
    /// The platform object whose settings object this is - the Document, or
    /// the WorkerGlobalScope - as (address, slab generation): its liveness is
    /// the loader's (`alive`).
    owner: *runtime.Instance,
    owner_generation: u64,
    pending: std.StringHashMap(*SingleFetch),
    graphs: std.ArrayListUnmanaged(*Graph) = .empty,

    pub const Client = struct {
        context: *anyopaque,
        done: *const fn (context: *anyopaque, result: ?*ModuleScript) void,
        /// A destroyed owner or canceled graph produces no script event.
        gone: *const fn (context: *anyopaque) void,
        /// Lets parser replacement cancel just its own element's graph.
        element: ?*runtime.Instance = null,
        /// An import(): a graph that needs no fetch - every module of it in
        /// the module map already - completes from a microtask, not a task.
        /// HTML fetch a single module script step 5 runs onComplete at once
        /// for a module in the map (whatwg/html#8264, with tc39/ecma262#2905
        /// HostLoadImportedModule); ECMA-262 ContinueDynamicImport then links
        /// and evaluates in a reaction to the already-settled loadPromise -
        /// one microtask, which is where this completion lands. A script
        /// element's graph keeps its task (lesson: a result the spec hands
        /// over from onComplete arrives in a task).
        ///
        /// microtasks/basic.any.js "...when loading an already loaded
        /// module", wpt.fyi stable df642c4142: Safari PASS in the Window and
        /// workers, Firefox PASS in workers (FAIL in the Window), Chrome FAIL
        /// (Blink's ModuleMap posts a task for a finished entry). Golden rule
        /// 2's first case: the newer spec, which a browser ships (wpt
        /// PR #35949 added the test with the HTML change).
        settle_cached_in_microtask: bool = false,
    };

    pub fn create(env: Environment, owner: *runtime.Instance) !*AsyncModuleLoader {
        // Queued payloads can outlive the owner's allocator on silent
        // destruction. Only module records use the owner's allocator.
        const allocator = std.heap.c_allocator;
        const self = try allocator.create(AsyncModuleLoader);
        self.* = .{
            .allocator = allocator,
            .env = env,
            .owner = owner,
            .owner_generation = runtime.SlabAllocator.generationOf(owner),
            .pending = std.StringHashMap(*SingleFetch).init(allocator),
        };
        // Resolution and request client data must survive the source element.
        self.env.context_instance = owner;
        self.env.fetch_options = .{};
        self.env.referrer = "";
        return self;
    }

    fn alive(self: *const AsyncModuleLoader) bool {
        return runtime.SlabAllocator.generationOf(self.owner) == self.owner_generation and
            self.env.realm().engine_ctx != null;
    }

    pub fn destroy(self: *AsyncModuleLoader) void {
        self.discard();
        self.graphs.deinit(self.allocator);
        self.pending.deinit();
        self.allocator.destroy(self);
    }

    pub fn prepareAbort(self: *AsyncModuleLoader) bool {
        for (self.graphs.items) |graph| graph.cancel_requested = true;
        return self.graphs.items.len != 0;
    }

    pub fn abortPrepared(self: *AsyncModuleLoader) void {
        var index: usize = 0;
        while (index < self.graphs.items.len) {
            const graph = self.graphs.items[index];
            if (!graph.cancel_requested) {
                index += 1;
                continue;
            }
            graph.cancel();
        }
    }

    pub fn discard(self: *AsyncModuleLoader) void {
        while (self.graphs.items.len > 0) self.graphs.items[self.graphs.items.len - 1].cancel();
    }

    pub fn cancelElement(self: *AsyncModuleLoader, element: *runtime.Instance) void {
        var index: usize = 0;
        while (index < self.graphs.items.len) {
            const graph = self.graphs.items[index];
            if (graph.client.element != element) {
                index += 1;
                continue;
            }
            graph.cancel();
        }
    }

    /// Starts the root fetch now, but completes only through queued tasks,
    /// after the element has joined its execution queue.
    pub fn start(self: *AsyncModuleLoader, url: []const u8, module_type: ModuleType, inline_script: ?*ModuleScript, options: FetchOptions, client: Client) !void {
        return self.startWithReferrer(url, module_type, inline_script, options, "", client);
    }

    /// HostLoadImportedModule step 14 supplies the referencing script's base
    /// URL as referrer. Borrow it only until startSingle makes its existing
    /// owned copy; the graph and its queued tasks keep no additional string.
    pub fn startWithReferrer(self: *AsyncModuleLoader, url: []const u8, module_type: ModuleType, inline_script: ?*ModuleScript, options: FetchOptions, referrer: []const u8, client: Client) !void {
        return self.startGraph(url, module_type, inline_script, options, referrer, null, client);
    }

    /// HTML "fetch a modulepreload module script graph" step 1: fetch a
    /// single module script of `url` - "javascript-or-wasm", the link's
    /// `destination`, referrer "client" - into the module map, and run
    /// `client.done` with the result: the module script, a parse error and
    /// all, or null. A later import() of the URL finds it there, or joins
    /// the fetch while it is in flight, instead of fetching again under its
    /// own options (modulepreload-referrerpolicy.html,
    /// modulepreload-inline-referrerpolicy.html). Step 1.3's optional
    /// "fetch the descendants of and link" is not done: the load event
    /// never waits for them, and nothing else observes them.
    pub fn startModulePreload(self: *AsyncModuleLoader, url: []const u8, destination: fetch.internal.Destination, options: FetchOptions, client: Client) !void {
        // Resource Timing's initiatorType stays "link" for the request, as
        // the link fetch it replaces had it (Firefox and Safari; row 47
        // Q5/Q6), where fetch-single step 11 says "script".
        return self.startGraph(url, .javascript, null, options, "", .{ .destination = destination, .initiator_type = .link }, client);
    }

    fn startGraph(self: *AsyncModuleLoader, url: []const u8, module_type: ModuleType, inline_script: ?*ModuleScript, options: FetchOptions, referrer: []const u8, modulepreload: ?RequestShape, client: Client) !void {
        if (!supported) return error.NotSupported;
        const loop = self.env.realm().getOptionalEventLoop() orelse return error.NotSupported;
        const graph = try self.allocator.create(Graph);
        errdefer self.allocator.destroy(graph);
        const owned_url = try self.allocator.dupe(u8, url);
        errdefer self.allocator.free(owned_url);
        const nonce = try self.allocator.dupe(u8, options.nonce);
        errdefer self.allocator.free(nonce);
        const integrity = try self.allocator.dupe(u8, options.integrity);
        errdefer self.allocator.free(integrity);
        graph.* = .{
            .allocator = self.allocator,
            .loader = self,
            .client = client,
            .url = owned_url,
            .module_type = module_type,
            .inline_script = inline_script,
            .options = options,
            .progress = GraphProgress.init(self.allocator),
            .modulepreload = modulepreload,
        };
        graph.options.nonce = nonce;
        graph.options.integrity = integrity;
        try self.graphs.append(self.allocator, graph);
        graph.startRoot(referrer);
        graph.task_queued = true;
        // Every module of an import()'s graph was in the module map: it
        // completes from a microtask (Client.settle_cached_in_microtask).
        // Should the microtask not queue, the task below completes it.
        if (client.settle_cached_in_microtask and !graph.failed and graph.progress.pending == 0) {
            if (engine.queueRealmMicrotask(self.env.realm(), &Graph.microtask_steps, graph)) |_| return else |_| {}
        }
        // queueTask may drop and destroy the graph on allocation failure.
        loop.queueTask(.{ .callback = Graph.runTask, .context = graph, .drop = Graph.dropTask });
    }

    fn forgetGraph(self: *AsyncModuleLoader, graph: *Graph) void {
        for (self.graphs.items, 0..) |existing, index| {
            if (existing != graph) continue;
            _ = self.graphs.swapRemove(index);
            break;
        }
    }

    const Node = struct {
        key: []const u8,
        url: []const u8,
        module_type: ModuleType,
        script: ?*ModuleScript = null,
        settled: bool = false,
        expanded: bool = false,
        searched: bool = false,
        children: std.ArrayListUnmanaged(*Node) = .empty,
    };

    /// A request's destination and Resource Timing initiator type, where
    /// they are not the module type's (HTML fetch-single steps 9 and 11).
    const RequestShape = struct {
        destination: fetch.internal.Destination,
        initiator_type: fetch.internal.InitiatorType = .script,
    };

    const Graph = struct {
        allocator: std.mem.Allocator,
        loader: ?*AsyncModuleLoader,
        client: Client,
        url: []const u8,
        module_type: ModuleType,
        inline_script: ?*ModuleScript,
        options: FetchOptions,
        progress: GraphProgress,
        /// A modulepreload's fetch of a single module script: its root's
        /// request shape. Nothing is expanded or linked; onComplete is given
        /// the root's module script as it is.
        modulepreload: ?RequestShape = null,
        nodes: std.ArrayListUnmanaged(*Node) = .empty,
        task_queued: bool = false,
        cancel_requested: bool = false,
        failed: bool = false,

        fn destroy(self: *Graph) void {
            for (self.nodes.items) |node| {
                self.allocator.free(node.key);
                self.allocator.free(node.url);
                node.children.deinit(self.allocator);
                self.allocator.destroy(node);
            }
            self.nodes.deinit(self.allocator);
            self.progress.deinit();
            self.allocator.free(self.url);
            self.allocator.free(self.options.nonce);
            self.allocator.free(self.options.integrity);
            self.allocator.destroy(self);
        }

        fn cancel(self: *Graph) void {
            const loader = self.loader orelse return;
            self.loader = null;
            loader.forgetGraph(self);
            // Detach callbacks before freeing their graph nodes. A queued
            // delivery keeps its SingleFetch allocation until callback/drop.
            for (self.nodes.items) |node| {
                if (loader.pending.get(node.key)) |single| single.removeWaiter(self);
            }
            const client = self.client;
            if (!self.task_queued) self.destroy();
            client.gone(client.context);
        }

        fn queue(self: *Graph) void {
            if (self.task_queued) return;
            const loader = self.loader orelse return;
            const loop = loader.env.realm().getOptionalEventLoop() orelse return self.cancel();
            self.task_queued = true;
            loop.queueTask(.{ .callback = runTask, .context = self, .drop = dropTask });
        }

        fn dropTask(data: ?*anyopaque) void {
            const self: *Graph = @ptrCast(@alignCast(data orelse return));
            self.task_queued = false;
            if (self.loader != null) self.cancel() else self.destroy();
        }

        fn runTask(data: ?*anyopaque) void {
            const self: *Graph = @ptrCast(@alignCast(data orelse return));
            // Remain task-owned while runTaskInRealm may re-enter cancellation.
            const loader = self.loader orelse return self.destroy();
            if (!loader.alive()) {
                self.task_queued = false;
                return self.cancel();
            }
            engine.runTaskInRealm(loader.env.realm(), processTask, self) catch {
                self.task_queued = false;
                return self.cancel();
            };
        }

        /// A cached import() graph's completion, queued as a microtask of
        /// the owner's realm. While queued it owns the graph as a queued
        /// task does (`task_queued`): a cancellation leaves the graph to
        /// this, or to its drop - at the realm's end - which is `dropTask`.
        const microtask_steps: engine.PromiseReactionSteps = .{ .fulfilled = runMicrotask, .dropped = dropTask };

        fn runMicrotask(data: ?*anyopaque, _: runtime.JSValue) void {
            const self: *Graph = @ptrCast(@alignCast(data orelse return));
            const loader = self.loader orelse return self.destroy();
            if (!loader.alive()) {
                self.task_queued = false;
                return self.cancel();
            }
            // In a checkpoint of the realm's agent already: no task to run.
            processTask(self);
        }

        fn startRoot(self: *Graph, referrer: []const u8) void {
            const loader = self.loader.?;
            const root = self.addNode(self.url, self.module_type) catch {
                self.failed = true;
                return;
            };
            // HTML fetch-single steps 8-13 initiate the request before returning.
            // File API 8.4: later revocation cannot cancel an already-started
            // blob URL request. AsyncFetch.start never delivers client callbacks.
            if (self.inline_script) |script| {
                self.receive(root, script);
            } else loader.fetchSingle(self, root, self.options, referrer, self.modulepreload orelse loader.shapeFor(root.module_type));
            // Fetch-inline step 2 and fetch-descendants step 5 start known
            // imports through LoadRequestedModules before returning. A cached
            // root (fetch-single step 5) has the same immediate continuation.
            // This only starts requests; linking and client delivery stay queued.
            self.expandReady();
        }

        fn processTask(data: ?*anyopaque) void {
            const self: *Graph = @ptrCast(@alignCast(data.?));
            self.expandReady();
            if (self.failed or self.progress.pending == 0) return self.finish();
            self.task_queued = false;
        }

        fn expandReady(self: *Graph) void {
            // A modulepreload is one module script.
            if (self.modulepreload != null) return;
            // New cached children can be appended during this walk. Remote
            // children come back through a later networking delivery task.
            var index: usize = 0;
            while (index < self.nodes.items.len) : (index += 1) {
                const node = self.nodes.items[index];
                if (!node.settled or node.expanded) continue;
                node.expanded = true;
                self.expand(node) catch {
                    self.failed = true;
                };
            }
        }

        fn addNode(self: *Graph, url: []const u8, module_type: ModuleType) !*Node {
            const key = try std.mem.concat(self.allocator, u8, &.{ module_type.keyPrefix(), url });
            errdefer self.allocator.free(key);
            for (self.nodes.items) |node| {
                if (!std.mem.eql(u8, node.key, key)) continue;
                self.allocator.free(key);
                return node;
            }
            const node = try self.allocator.create(Node);
            errdefer self.allocator.destroy(node);
            const owned_url = try self.allocator.dupe(u8, url);
            errdefer self.allocator.free(owned_url);
            node.* = .{ .key = key, .url = owned_url, .module_type = module_type };
            try self.nodes.append(self.allocator, node);
            errdefer _ = self.nodes.pop();
            _ = try self.progress.visit(key);
            return node;
        }

        fn receive(self: *Graph, node: *Node, script: ?*ModuleScript) void {
            node.settled = true;
            node.script = script;
            _ = self.progress.completeOne();
            if (script == null) self.failed = true;
        }

        fn expand(self: *Graph, node: *Node) !void {
            const script = node.script orelse return;
            // A graph's error to rethrow belongs to its root. This shared
            // record can still be reached from another root whose source-
            // order walk chooses a different descendant's parse error.
            const record = script.record orelse return;
            const loader = self.loader.?;
            const env = &loader.env;
            if (script.validation_error != null) return;
            const requests = try engine.moduleRequests(record, self.allocator);
            defer {
                for (requests) |request| {
                    self.allocator.free(request.specifier);
                    if (request.type_attribute) |attribute| self.allocator.free(attribute);
                }
                self.allocator.free(requests);
            }
            var resolved = std.ArrayListUnmanaged(Request).empty;
            defer {
                for (resolved.items) |request| env.context_instance.ctx.allocator.free(request.url);
                resolved.deinit(self.allocator);
            }
            // HostLoadImportedModule validates ALL this module's requests
            // before fetching any of them, in their source order.
            for (requests) |request| {
                const url = resolveModuleSpecifier(env, request.specifier, script.base_url) orelse {
                    script.validation_error = makeError(env, .type_error, "Failed to resolve module specifier");
                    if (script.validation_error == null) self.failed = true;
                    return;
                };
                const module_type = moduleTypeFromAttribute(request.type_attribute) orelse {
                    env.context_instance.ctx.allocator.free(url);
                    script.validation_error = makeError(env, .type_error, "Unsupported module type");
                    if (script.validation_error == null) self.failed = true;
                    return;
                };
                if (!env.moduleTypeAllowed(module_type)) {
                    env.context_instance.ctx.allocator.free(url);
                    script.validation_error = makeError(env, .type_error, "Unsupported module type");
                    if (script.validation_error == null) self.failed = true;
                    return;
                }
                resolved.append(self.allocator, .{ .specifier = request.specifier, .url = url, .module_type = module_type }) catch |err| {
                    env.context_instance.ctx.allocator.free(url);
                    return err;
                };
            }
            for (resolved.items) |request| {
                const child = try self.addNode(request.url, request.module_type);
                try node.children.append(self.allocator, child);
                if (!child.settled and loader.pending.get(child.key) == null) {
                    var options = script.descendantFetchOptions();
                    options.integrity = env.resolveIntegrity(request.url);
                    loader.fetchSingle(self, child, options, script.base_url, loader.shapeFor(child.module_type));
                } else if (!child.settled) {
                    try loader.pending.get(child.key).?.addWaiter(self, child);
                }
            }
        }

        fn firstError(node: *Node) ?engine.Owned {
            if (node.searched) return null;
            node.searched = true;
            const script = node.script orelse return null;
            if (script.parse_error) |value| return value;
            if (script.validation_error) |value| return value;
            // Only the script's own syntactic error can stop this walk.
            // Its error_to_rethrow may describe a different root's graph.
            for (node.children.items) |child| {
                if (firstError(child)) |value| return value;
            }
            return null;
        }

        fn recordEdges(self: *Graph) !void {
            const env = &self.loader.?.env;
            for (self.nodes.items) |node| {
                const script = node.script orelse continue;
                const record = script.record orelse continue;
                if (script.validation_error != null) continue;
                const requests = try engine.moduleRequests(record, self.allocator);
                defer {
                    for (requests) |request| {
                        self.allocator.free(request.specifier);
                        if (request.type_attribute) |attribute| self.allocator.free(attribute);
                    }
                    self.allocator.free(requests);
                }
                for (node.children.items, 0..) |child, index| {
                    const child_script = child.script orelse continue;
                    const specifier = requests[index].specifier;
                    var exists = false;
                    for (script.children.items) |edge| {
                        if (edge.module_type == child.module_type and std.mem.eql(u8, edge.specifier, specifier)) {
                            exists = true;
                            break;
                        }
                    }
                    if (exists) continue;
                    const owned_specifier = try env.allocator.dupe(u8, specifier);
                    script.children.append(env.allocator, .{ .specifier = owned_specifier, .module_type = child.module_type, .script = child_script }) catch |err| {
                        env.allocator.free(owned_specifier);
                        return err;
                    };
                }
                script.loaded = true;
            }
        }

        /// Fetch the descendants of and link, steps 6-7, for the root
        /// `script` of a graph whose every module has loaded: its error to
        /// rethrow is the first parse or validation error in source order,
        /// else Link's. Null when that cannot be recorded (out of memory).
        fn linkRoot(self: *Graph, script: *ModuleScript) ?*ModuleScript {
            const env = &self.loader.?.env;
            if (firstError(self.nodes.items[0])) |value| {
                const copy = copyOf(env, value) orelse return null;
                script.setErrorToRethrow(copy);
                script.load_error = true;
                return script;
            }
            self.recordEdges() catch return null;
            if (link(env, script)) |value| script.setErrorToRethrow(value) else if (script.error_to_rethrow) |old| {
                old.release();
                script.error_to_rethrow = null;
            }
            return script;
        }

        fn finish(self: *Graph) void {
            const loader = self.loader.?;
            var result: ?*ModuleScript = if (self.failed or self.nodes.items.len == 0) null else self.nodes.items[0].script;
            // A modulepreload's onComplete takes fetch-single's result as it
            // is; a graph's root is linked, or carries its error to rethrow.
            if (self.modulepreload == null) {
                if (result) |script| result = self.linkRoot(script);
            }
            // Null out all resource waiters before this root calls script.
            loader.forgetGraph(self);
            self.loader = null;
            for (self.nodes.items) |node| {
                if (loader.pending.get(node.key)) |single| single.removeWaiter(self);
            }
            const client = self.client;
            self.destroy();
            client.done(client.context, result);
        }
    };

    const Waiter = struct { graph: *Graph, node: *Node };

    const SingleFetch = struct {
        allocator: std.mem.Allocator,
        loader: ?*AsyncModuleLoader,
        key: []const u8,
        url: []const u8,
        module_type: ModuleType,
        options: FetchOptions,
        referrer: []const u8,
        waiters: std.ArrayListUnmanaged(Waiter) = .empty,
        transport: ?*fetch.algorithms.AsyncFetch = null,
        outcome: ?fetch.algorithms.FetchResult = null,
        task_queued: bool = false,

        fn destroy(self: *SingleFetch) void {
            if (self.transport) |transport| transport.terminate();
            if (self.outcome) |*outcome| outcome.deinit();
            self.waiters.deinit(self.allocator);
            self.allocator.free(self.key);
            self.allocator.free(self.url);
            self.allocator.free(self.options.nonce);
            self.allocator.free(self.options.integrity);
            self.allocator.free(self.referrer);
            self.allocator.destroy(self);
        }

        fn addWaiter(self: *SingleFetch, graph: *Graph, node: *Node) !void {
            for (self.waiters.items) |waiter| if (waiter.graph == graph and waiter.node == node) return;
            try self.waiters.append(self.allocator, .{ .graph = graph, .node = node });
        }

        fn removeWaiter(self: *SingleFetch, graph: *Graph) void {
            var index: usize = 0;
            while (index < self.waiters.items.len) {
                if (self.waiters.items[index].graph != graph) {
                    index += 1;
                    continue;
                }
                _ = self.waiters.swapRemove(index);
            }
            if (self.waiters.items.len != 0) return;
            if (self.loader) |loader| _ = loader.pending.remove(self.key);
            self.loader = null;
            if (self.transport) |transport| {
                self.transport = null;
                transport.terminate();
            }
            if (!self.task_queued) self.destroy();
        }

        fn fetchAlive(context: *anyopaque) bool {
            const self: *SingleFetch = @ptrCast(@alignCast(context));
            const loader = self.loader orelse return false;
            return loader.alive();
        }

        fn fetchGone(context: *anyopaque) void {
            const self: *SingleFetch = @ptrCast(@alignCast(context));
            self.transport = null;
            if (self.loader) |loader| loader.discard();
        }

        fn fetched(context: *anyopaque, outcome: fetch.algorithms.FetchError!fetch.algorithms.FetchResult) void {
            const self: *SingleFetch = @ptrCast(@alignCast(context));
            // The fetch client's realm reports (CSP 6.7.1.2): the document's,
            // also for a worklet's graph, whose records are made elsewhere.
            if (self.loader) |loader| @import("dom").reporting.reportScriptFetch(loader.env.context_instance.ctx, self.transport, outcome);
            self.transport = null;
            self.outcome = outcome catch null;
            const loader = self.loader orelse return self.destroy();
            const loop = loader.env.realm().getOptionalEventLoop() orelse return loader.discard();
            self.task_queued = true;
            loop.queueTask(.{ .callback = deliverTask, .context = self, .drop = dropTask });
        }

        fn dropTask(data: ?*anyopaque) void {
            const self: *SingleFetch = @ptrCast(@alignCast(data orelse return));
            if (self.loader) |loader| loader.discard();
            self.destroy();
        }

        fn deliverTask(data: ?*anyopaque) void {
            const self: *SingleFetch = @ptrCast(@alignCast(data orelse return));
            defer self.destroy();
            const loader = self.loader orelse return;
            if (!loader.alive()) return loader.discard();
            engine.runTaskInRealm(loader.env.realm(), deliver, self) catch loader.discard();
        }

        fn deliver(data: ?*anyopaque) void {
            const self: *SingleFetch = @ptrCast(@alignCast(data.?));
            const loader = self.loader.?;
            // Remove the fetching entry before callbacks: a failed fetch can
            // be retried from a rejection handler without joining this one.
            _ = loader.pending.remove(self.key);
            self.loader = null;
            var env = loader.env;
            env.fetch_options = self.options;
            var script: ?*ModuleScript = null;
            if (self.outcome) |outcome| script = createFromResponse(&env, self.url, self.module_type, outcome.response);
            if (script) |created| {
                if (!env.map.put(self.key, @ptrCast(created))) {
                    created.destroy();
                    script = null;
                }
            }
            for (self.waiters.items) |waiter| {
                waiter.graph.receive(waiter.node, script);
                waiter.graph.queue();
            }
        }
    };

    /// The request shape of a module of `module_type` in a graph: the fetch
    /// destination from module type, given the loader's script destination.
    fn shapeFor(self: *const AsyncModuleLoader, module_type: ModuleType) RequestShape {
        return .{ .destination = module_type.fetchDestination(self.env.script_destination) };
    }

    fn fetchSingle(self: *AsyncModuleLoader, graph: *Graph, node: *Node, options: FetchOptions, referrer: []const u8, shape: RequestShape) void {
        // HTML fetch-single steps 5-6: completed script or callback list.
        if (self.env.map.get(node.key)) |entry| {
            graph.receive(node, @ptrCast(@alignCast(entry)));
            return;
        }
        if (self.pending.get(node.key)) |single| {
            single.addWaiter(graph, node) catch {
                graph.failed = true;
            };
            return;
        }
        self.startSingle(graph, node, options, referrer, shape) catch {
            graph.failed = true;
        };
    }

    fn startSingle(self: *AsyncModuleLoader, graph: *Graph, node: *Node, options: FetchOptions, referring_url: []const u8, shape: RequestShape) !void {
        const single = try self.allocator.create(SingleFetch);
        errdefer self.allocator.destroy(single);
        const key = try self.allocator.dupe(u8, node.key);
        errdefer self.allocator.free(key);
        const url = try self.allocator.dupe(u8, node.url);
        errdefer self.allocator.free(url);
        const nonce = try self.allocator.dupe(u8, options.nonce);
        errdefer self.allocator.free(nonce);
        const integrity = try self.allocator.dupe(u8, options.integrity);
        errdefer self.allocator.free(integrity);
        const referrer = try self.allocator.dupe(u8, referring_url);
        errdefer self.allocator.free(referrer);
        single.* = .{ .allocator = self.allocator, .loader = self, .key = key, .url = url, .module_type = node.module_type, .options = options, .referrer = referrer };
        single.options.nonce = nonce;
        single.options.integrity = integrity;
        try single.addWaiter(graph, node);
        errdefer single.waiters.deinit(self.allocator);
        try self.pending.put(key, single);
        errdefer _ = self.pending.remove(key);

        const request = try script_request.InternalRequest.init(self.allocator, url);
        var request_owned = true;
        defer if (request_owned) request.deinit();
        request.mode = .cors;
        request.credentials_mode = options.credentials_mode;
        request.destination = shape.destination;
        request.initiator_type = shape.initiator_type;
        if (nonce.len > 0) try request.setCryptographicNonceMetadata(nonce);
        try request.setIntegrityMetadata(integrity);
        request.parser_metadata = if (options.parser_inserted) .parser_inserted else .not_parser_inserted;
        request.referrer_policy = options.referrer_policy;
        request.render_blocking = options.render_blocking;
        request.priority = options.fetch_priority;
        try script_request.populateRequestFromClient(request, self.env.context_instance.ctx);
        if (referrer.len > 0) try request.setReferrerUrl(referrer);
        request_owned = false;
        single.transport = try fetch.algorithms.AsyncFetch.start(self.allocator, request, .{}, @import("dom").agent_fetches.of(self.env.context_instance.ctx), .{
            .context = single,
            .done = SingleFetch.fetched,
            .alive = SingleFetch.fetchAlive,
            .gone = SingleFetch.fetchGone,
        });
    }
};

/// HTML fetch-single processResponseConsumeBody, shared by the queued graph
/// resource delivery. The created record's [[HostDefined]] stays stable.
fn createFromResponse(env: *const Environment, url: []const u8, module_type: ModuleType, response: *fetch.internal.InternalResponse) ?*ModuleScript {
    if (response.response_type == .@"error" or response.status < 200 or response.status >= 300) return null;
    const body = if (response.body) |value| value.getBytes() else "";
    const essence = mimeEssence(response.header_list.getFirstValue("content-type") orelse "");
    const base_url = response.url() orelse url;
    var response_env = env.*;
    const policy = fetch.internal.policy_container.parseReferrerPolicyHeader(response.header_list.getFirstValue("referrer-policy"));
    if (policy != .empty) response_env.fetch_options.referrer_policy = policy;
    return switch (module_type) {
        .javascript => if (isJavaScriptMimeTypeEssence(essence)) createJavaScriptModuleScript(&response_env, body, .{}, base_url) catch null else null,
        .json => blk: {
            if (!isJsonMimeTypeEssence(essence)) break :blk null;
            // Fetch a single module script, processResponseConsumeBody
            // step 13.7: UTF-8 decode bodyBytes before creating the module.
            // Encoding's UTF-8 decode strips a leading BOM and replaces
            // malformed sequences; JSON.parse must see that decoded text.
            const text = css_rules.decodeUtf8(env.allocator, body) catch break :blk null;
            defer env.allocator.free(text);
            break :blk createJsonModuleScript(&response_env, text, base_url) catch null;
        },
        .css => blk: {
            if (!std.mem.eql(u8, essence, "text/css")) break :blk null;
            const text = css_rules.decodeUtf8(env.allocator, body) catch break :blk null;
            defer env.allocator.free(text);
            break :blk createCssModuleScript(&response_env, text, base_url) catch null;
        },
        // Step 13.7.1-13.7.2: "Let sourceText be the result of UTF-8
        // decoding bodyBytes. If moduleType is "text", then set moduleScript
        // to the result of creating a text module script given sourceText" -
        // whatever the MIME type: the response's Content-Type is not looked
        // at (text-module/ignore-content-type.any.js). "UTF-8 decode" strips
        // a UTF-8 BOM and never fails: a bad sequence is U+FFFD
        // (charset-bom.any.js - a UTF-16 BOM is two of them).
        .text => blk: {
            const text = css_rules.decodeUtf8(env.allocator, body) catch break :blk null;
            defer env.allocator.free(text);
            break :blk createTextModuleScript(&response_env, text, base_url) catch null;
        },
    };
}

/// LoadRequestedModules, depth first. Null on success.
fn loadRequestedModules(env: *const Environment, script: *ModuleScript) ?LoadFailure {
    if (script.loaded or script.visiting) return null;
    const record = script.record orelse return null;

    // A script whose earlier load stopped partway keeps the edges it had
    // recorded; start its list afresh rather than append duplicates.
    for (script.children.items) |child| env.allocator.free(child.specifier);
    script.children.clearRetainingCapacity();

    script.visiting = true;
    defer script.visiting = false;

    // The record's [[RequestedModules]], in source order. (A request with an
    // import attribute other than "type" never gets here: ParseModule made it
    // the script's parse error, HostLoadImportedModule step 7.1.1.)
    const module_requests = engine.moduleRequests(record, env.allocator) catch return .fetch_failed;
    defer {
        for (module_requests) |request| {
            env.allocator.free(request.specifier);
            if (request.type_attribute) |t| env.allocator.free(t);
        }
        env.allocator.free(module_requests);
    }

    // HostLoadImportedModule step 7: when the first request is loaded, validate
    // every request of this module - specifiers and types - before loading
    // any of them. A module with a static error is treated like one that
    // failed to parse; nothing it imports is fetched.
    var requests = std.ArrayListUnmanaged(Request).empty;
    defer {
        for (requests.items) |r| env.context_instance.ctx.allocator.free(r.url);
        requests.deinit(env.allocator);
    }
    requests.ensureTotalCapacity(env.allocator, module_requests.len) catch return .fetch_failed;

    for (module_requests) |request| {
        // Steps 7.1.2-7.1.3: resolve a module specifier, or TypeError.
        const url = resolveModuleSpecifier(env, request.specifier, script.base_url) orelse
            return failWith(env, .type_error, "Failed to resolve module specifier");

        // Steps 7.1.4-7.1.5: module type from module request; "module type
        // allowed" admits javascript-or-wasm, css and json in a Window.
        const module_type = moduleTypeFromAttribute(request.type_attribute) orelse {
            env.context_instance.ctx.allocator.free(url);
            return failWith(env, .type_error, "Unsupported module type");
        };
        if (!env.moduleTypeAllowed(module_type)) {
            env.context_instance.ctx.allocator.free(url);
            return failWith(env, .type_error, "Unsupported module type");
        }

        requests.appendAssumeCapacity(.{ .specifier = request.specifier, .url = url, .module_type = module_type });
    }

    for (requests.items) |*request| {
        // Step 14: fetch a single imported module script.
        var descendant = env.*;
        descendant.fetch_options = script.descendantFetchOptions();
        descendant.fetch_options.integrity = env.resolveIntegrity(request.url);
        descendant.referrer = script.base_url;
        const child = fetchSingleModuleScript(&descendant, request.url, request.module_type) orelse return .fetch_failed;

        // onSingleFetchComplete step 3: a child that did not parse fails the
        // load, and its parse error is the error to rethrow.
        if (child.record == null) {
            const parse_error = child.parse_error orelse return .fetch_failed;
            return .{ .rethrow = copyOf(env, parse_error) orelse return .fetch_failed };
        }

        // Record the edge before descending: a cycle back to this script finds
        // it through here when Link resolves.
        const owned_specifier = env.allocator.dupe(u8, request.specifier) catch return .fetch_failed;
        script.children.append(env.allocator, .{
            .specifier = owned_specifier,
            .module_type = request.module_type,
            .script = child,
        }) catch {
            env.allocator.free(owned_specifier);
            return .fetch_failed;
        };

        if (loadRequestedModules(env, child)) |failure| return failure;
    }

    script.loaded = true;
    return null;
}

const Request = struct {
    /// BORROWED from the record's module requests.
    specifier: []const u8,
    url: []const u8, // env.context_instance.ctx.allocator
    module_type: ModuleType,
};

fn failWith(env: *const Environment, kind: ErrorKind, message: []const u8) LoadFailure {
    const value = makeError(env, kind, message) orelse return .fetch_failed;
    return .{ .rethrow = value };
}

/// The graph a Link resolves in, for the host's resolve: the root the walk
/// starts from, and the epoch that marks the nodes one walk has visited.
const Linking = struct {
    root: *ModuleScript,
};
/// The epoch of the latest walk. Atomic: each thread walks its own graphs,
/// but every walk must get an epoch no earlier walk of its thread had.
var search_epoch: std.atomic.Value(u32) = .init(0);

/// Link(), with each request answered from the edges recorded while loading
/// (HostLoadImportedModule, for a graph HTML has already fetched). The link
/// error (OWNED), or null on success.
fn link(env: *const Environment, script: *ModuleScript) ?engine.Owned {
    const record = script.record orelse return null;
    var linking: Linking = .{ .root = script };
    const link_error = engine.linkModule(env.realm(), record, resolveRequest, &linking) catch
        return makeError(env, .syntax_error, "Module could not be linked");
    return link_error;
}

/// The module `referrer` recorded for `request`, or null - which the engine
/// makes Link's TypeError.
fn resolveRequest(data: ?*anyopaque, referrer: *engine.ModuleRecord, request: engine.ModuleRequest) ?*engine.ModuleRecord {
    const linking: *Linking = @ptrCast(@alignCast(data orelse return null));
    const from = findByRecord(linking.root, referrer) orelse return null;
    const wanted_type = moduleTypeFromAttribute(request.type_attribute) orelse return null;
    for (from.children.items) |child| {
        if (!std.mem.eql(u8, child.specifier, request.specifier)) continue;
        if (child.module_type != wanted_type) continue;
        return child.script.record;
    }
    return null;
}

/// The script in `root`'s graph whose record is `record`.
fn findByRecord(root: *ModuleScript, record: *engine.ModuleRecord) ?*ModuleScript {
    const epoch = search_epoch.fetchAdd(1, .monotonic) +% 1;
    return findIn(root, record, epoch);
}

fn findIn(script: *ModuleScript, record: *engine.ModuleRecord, epoch: u32) ?*ModuleScript {
    if (script.search_epoch == epoch) return null;
    script.search_epoch = epoch;
    if (script.record == record) return script;
    for (script.children.items) |child| {
        if (findIn(child.script, record, epoch)) |found| return found;
    }
    return null;
}

// =============================================================================
// Running a module script
// =============================================================================

/// What running a module script produced, for the caller to report.
pub const RunResult = union(enum) {
    /// Evaluation completed.
    ok,
    /// An exception to report (OWNED).
    report: engine.Owned,
    /// Evaluation is waiting on top-level await: the evaluation promise
    /// (OWNED), already marked as handled. "Upon rejection" of it, the caller
    /// reports the reason.
    pending: engine.Owned,
};

/// Run a module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
/// Steps 6-8, between the caller's "prepare to run script" and "clean up
/// after running script" (steps 5 and 9). Reporting is the caller's: this
/// returns the exception that "report an exception" must be given, when
/// there is one.
pub fn run(env: *const Environment, script: *ModuleScript) RunResult {
    if (!supported) return .ok;
    // Step 6: an error to rethrow is reported instead of evaluating.
    if (script.error_to_rethrow) |value| {
        return if (copyOf(env, value)) |copy| .{ .report = copy } else .ok;
    }

    const record = script.record orelse return .ok;

    // Step 7: record.Evaluate(). A rejected evaluation promise is the
    // host's to report (step 8), so the engine marks it handled: it is not
    // also an unhandled rejection.
    const evaluation = engine.evaluateModule(env.realm(), record) catch |err| {
        log.debug("evaluating a module script failed: {}", .{err});
        return .ok;
    };
    return switch (evaluation) {
        .completed => .ok,
        // Step 8: upon rejection, report. A graph with no top-level await
        // settles synchronously, so the reason is already there.
        .rejected => |reason| .{ .report = reason },
        // A graph still waiting on top-level await reports when it settles.
        .pending => |promise| .{ .pending = promise },
    };
}

// =============================================================================
// Tests
// =============================================================================

test "an asynchronous graph counts a cycle once and two roots independently" {
    const allocator = std.testing.allocator;
    var first = GraphProgress.init(allocator);
    defer first.deinit();
    var second = GraphProgress.init(allocator);
    defer second.deinit();
    try std.testing.expect(try first.visit("js:https://example.test/a.mjs"));
    try std.testing.expect(try first.visit("js:https://example.test/b.mjs"));
    try std.testing.expect(!(try first.visit("js:https://example.test/a.mjs")));
    try std.testing.expect(try second.visit("js:https://example.test/b.mjs"));
    try std.testing.expectEqual(@as(usize, 2), first.pending);
    try std.testing.expectEqual(@as(usize, 1), second.pending);
    try std.testing.expect(!first.completeOne());
    try std.testing.expect(second.completeOne());
    try std.testing.expect(first.completeOne());
}

test "canceling graph progress releases every visited URL and remaining count" {
    var progress = GraphProgress.init(std.testing.allocator);
    defer progress.deinit();
    try std.testing.expect(try progress.visit("js:https://example.test/root.mjs"));
    try std.testing.expect(try progress.visit("json:https://example.test/data.json"));
    progress.cancel();
    try std.testing.expectEqual(@as(usize, 0), progress.pending);
    try std.testing.expectEqual(@as(usize, 0), progress.visited.count());
}

test "canceling one module graph preserves a shared fetch until its last waiter ends" {
    const Fixture = struct {
        fn done(_: *anyopaque, _: ?*ModuleScript) void {
            unreachable;
        }
        fn gone(data: *anyopaque) void {
            const count: *usize = @ptrCast(@alignCast(data));
            count.* += 1;
        }
        fn graph(loader: *AsyncModuleLoader, count: *usize) !*AsyncModuleLoader.Graph {
            const allocator = loader.allocator;
            const result = try allocator.create(AsyncModuleLoader.Graph);
            errdefer allocator.destroy(result);
            result.* = .{
                .allocator = allocator,
                .loader = loader,
                .client = .{ .context = count, .done = done, .gone = gone },
                .url = try allocator.dupe(u8, "https://example.test/module.mjs"),
                .module_type = .javascript,
                .inline_script = null,
                .options = .{},
                .progress = GraphProgress.init(allocator),
            };
            result.options.nonce = try allocator.dupe(u8, "");
            result.options.integrity = try allocator.dupe(u8, "");
            try loader.graphs.append(allocator, result);
            return result;
        }
    };
    const allocator = std.testing.allocator;
    var loader: AsyncModuleLoader = .{
        .allocator = allocator,
        .env = undefined,
        .owner = undefined,
        .owner_generation = 0,
        .pending = std.StringHashMap(*AsyncModuleLoader.SingleFetch).init(allocator),
    };
    defer loader.pending.deinit();
    defer loader.graphs.deinit(allocator);
    var count: usize = 0;
    const first = try Fixture.graph(&loader, &count);
    const second = try Fixture.graph(&loader, &count);
    const first_node = try first.addNode(first.url, .javascript);
    const second_node = try second.addNode(second.url, .javascript);
    const single = try allocator.create(AsyncModuleLoader.SingleFetch);
    single.* = .{
        .allocator = allocator,
        .loader = &loader,
        .key = try allocator.dupe(u8, first_node.key),
        .url = try allocator.dupe(u8, first.url),
        .module_type = .javascript,
        .options = .{ .nonce = try allocator.dupe(u8, ""), .integrity = try allocator.dupe(u8, "") },
        .referrer = try allocator.dupe(u8, ""),
    };
    try single.addWaiter(first, first_node);
    try single.addWaiter(first, first_node);
    try single.addWaiter(second, second_node);
    try loader.pending.put(single.key, single);
    try std.testing.expectEqual(@as(usize, 2), single.waiters.items.len);
    first.cancel();
    try std.testing.expectEqual(@as(usize, 1), single.waiters.items.len);
    try std.testing.expectEqual(@as(usize, 1), loader.pending.count());
    try std.testing.expectEqual(@as(usize, 1), count);
    // Last cancellation detaches queued payloads from the owner. They
    // remain owned only by their task, which may be dropped after teardown.
    single.task_queued = true;
    second.task_queued = true;
    second.cancel();
    try std.testing.expectEqual(@as(usize, 0), loader.pending.count());
    try std.testing.expectEqual(@as(usize, 0), loader.graphs.items.len);
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expect(single.loader == null);
    try std.testing.expect(second.loader == null);
    AsyncModuleLoader.SingleFetch.dropTask(single);
    AsyncModuleLoader.Graph.dropTask(second);
}

test "mimeEssence strips parameters and case" {
    try std.testing.expectEqualStrings("text/javascript", mimeEssence("Text/JavaScript; charset=utf-8"));
    try std.testing.expectEqualStrings("application/json", mimeEssence(" application/json "));
    try std.testing.expectEqualStrings("", mimeEssence(""));
}

test "mimeEssence fails a type or subtype that is not all HTTP token code points" {
    try std.testing.expectEqualStrings("", mimeEssence("applic ation/vnd.api+json"));
    try std.testing.expectEqualStrings("", mimeEssence("application/vnd api+json"));
    try std.testing.expectEqualStrings("", mimeEssence("application/vnd.api\"+json"));
    try std.testing.expectEqualStrings("", mimeEssence("/vnd.api+json"));
    try std.testing.expectEqualStrings("", mimeEssence("app\x00lication/vnd.api+json"));
    try std.testing.expectEqualStrings("", mimeEssence("aplicaci\xc3\xb3n/vnd.api+json"));
    try std.testing.expectEqualStrings("application/vnd", mimeEssence("application/vnd;api+json"));
    try std.testing.expectEqualStrings("text/html", mimeEssence("text/html;+json"));
}

test "mimeEssence takes the last MIME type of a comma-separated value" {
    try std.testing.expectEqualStrings("application/json", mimeEssence("text/plain, application/json"));
    try std.testing.expectEqualStrings("text/plain", mimeEssence("text/plain, */*"));
    try std.testing.expectEqualStrings("ation/vnd", mimeEssence("applic,ation/vnd,api+json"));
    try std.testing.expectEqualStrings("text/html", mimeEssence("text/html;charset=\"a,b\""));
}

test "isJsonMimeTypeEssence accepts +json subtypes and nothing else" {
    try std.testing.expect(isJsonMimeTypeEssence("application/json"));
    try std.testing.expect(isJsonMimeTypeEssence("text/json"));
    try std.testing.expect(isJsonMimeTypeEssence("application/manifest+json"));
    try std.testing.expect(!isJsonMimeTypeEssence("text/javascript"));
    try std.testing.expect(!isJsonMimeTypeEssence("application/jsonx"));
    try std.testing.expect(!isJsonMimeTypeEssence("json"));
}

test "isJavaScriptMimeTypeEssence matches whole essences only" {
    try std.testing.expect(isJavaScriptMimeTypeEssence("text/javascript"));
    try std.testing.expect(isJavaScriptMimeTypeEssence("application/x-javascript"));
    try std.testing.expect(!isJavaScriptMimeTypeEssence("text/javascript2"));
    try std.testing.expect(!isJavaScriptMimeTypeEssence("application/json"));
}

test "moduleTypeFromAttribute: json, css and text are module types; javascript-or-wasm and the rest are not" {
    try std.testing.expectEqual(ModuleType.javascript, moduleTypeFromAttribute(null).?);
    try std.testing.expectEqual(ModuleType.json, moduleTypeFromAttribute("json").?);
    try std.testing.expectEqual(ModuleType.css, moduleTypeFromAttribute("css").?);
    try std.testing.expectEqual(ModuleType.text, moduleTypeFromAttribute("text").?);
    try std.testing.expect(moduleTypeFromAttribute("javascript-or-wasm") == null);
    try std.testing.expect(moduleTypeFromAttribute("Text") == null);
    try std.testing.expect(moduleTypeFromAttribute("") == null);
}

test "fetch destination from module type: json, style and text; the default otherwise" {
    try std.testing.expectEqual(fetch.internal.Destination.json, ModuleType.json.fetchDestination(.script));
    try std.testing.expectEqual(fetch.internal.Destination.style, ModuleType.css.fetchDestination(.script));
    try std.testing.expectEqual(fetch.internal.Destination.text, ModuleType.text.fetchDestination(.paintworklet));
    try std.testing.expectEqual(fetch.internal.Destination.paintworklet, ModuleType.javascript.fetchDestination(.paintworklet));
    // Each type has its own module map key.
    try std.testing.expect(!std.mem.eql(u8, ModuleType.text.keyPrefix(), ModuleType.javascript.keyPrefix()));
}

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
//! synchronously during Link, so this follows d8's shape (and Blink's older
//! ModuleTreeLinker's): walk the graph first - resolve, fetch and parse every
//! request, depth first, recording each module's children - then Link,
//! answering each request from the recorded children. Crane's fetch is
//! synchronous, which is what makes a depth-first walk equivalent to the
//! spec's concurrent one: the first failure in DFS order is the one reported,
//! as `choice-of-error-*` expect.
//!
//! Where the engine has no modules (`engine.capabilities.module_scripts ==
//! .unsupported`, JavaScriptCore's public API) no graph is ever made: a
//! <script type=module> has a null result, so it fires `error`.
//!
//! What is NOT here yet: CSS module scripts (they need a constructable
//! CSSStyleSheet as a synthetic export), and import.meta.resolve.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const fetch = @import("fetch");
const engine = @import("engine");

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

    fn keyPrefix(self: ModuleType) []const u8 {
        return switch (self) {
            .javascript => "js:",
            .json => "json:",
            .css => "css:",
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

    fn create(allocator: std.mem.Allocator, base_url: []const u8) !*ModuleScript {
        const self = try allocator.create(ModuleScript);
        errdefer allocator.destroy(self);
        self.* = .{
            .allocator = allocator,
            .base_url = try allocator.dupe(u8, base_url),
        };
        track(self);
        return self;
    }

    /// Release the script, its record and values, and its edge list.
    /// Children are not freed - the module map owns them.
    pub fn destroy(self: *ModuleScript) void {
        untrack(self);
        if (supported) {
            if (self.record) |record| engine.releaseModuleRecord(record);
        }
        if (self.parse_error) |value| value.release();
        if (self.error_to_rethrow) |value| value.release();
        for (self.children.items) |child| self.allocator.free(child.specifier);
        self.children.deinit(self.allocator);
        self.allocator.free(self.base_url);
        self.allocator.destroy(self);
    }

    fn setErrorToRethrow(self: *ModuleScript, value: engine.Owned) void {
        if (self.error_to_rethrow) |old| old.release();
        self.error_to_rethrow = value;
    }
};

/// The document's module map, reached through its owner.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
/// Keyed by (URL, module type). Values are a `*ModuleScript`, or
/// `fetch_failed` for a fetch that failed ("null" in the spec) - both cast to
/// *anyopaque. The owner frees values through `disposeEntry`.
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

/// The map's "null": a fetch that failed. Never dereferenced.
var fetch_failed_marker: u8 = 0;
pub const fetch_failed: *anyopaque = @ptrCast(&fetch_failed_marker);

/// Free a module map value. The owner of the map installs this as its dispose
/// function.
pub fn disposeEntry(value: *anyopaque) void {
    if (value == fetch_failed) return;
    const script: *ModuleScript = @ptrCast(@alignCast(value));
    script.destroy();
}

/// Everything the loader needs from the document it loads for.
pub const Environment = struct {
    allocator: std.mem.Allocator,
    /// Any instance of the document's realm: the ctx for URL parsing, and
    /// the realm the module scripts' records are made in.
    context_instance: *runtime.Instance,
    map: ModuleMap,
    /// The document's import map lookup: the mapped URL for `specifier`
    /// (borrowed), or null when the import map does not mention it. Called
    /// with `map.context`, the document.
    resolveImportFn: ?*const fn (context: *anyopaque, specifier: []const u8, base_url: []const u8) ?[]const u8 = null,

    /// The settings object's realm: every record and value is made in it.
    pub fn realm(self: *const Environment) runtime.Context {
        return self.context_instance.ctx;
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
/// null.
pub fn createJavaScriptModuleScript(
    env: *const Environment,
    source: []const u8,
    base_url: []const u8,
) !*ModuleScript {
    if (!supported) return error.NotSupported;
    const script = try ModuleScript.create(env.allocator, base_url);
    errdefer script.destroy();

    switch (try engine.parseModule(env.realm(), source, base_url, script)) {
        .record => |record| script.record = record,
        .parse_error => |parse_error| script.parse_error = parse_error,
    }
    return script;
}

// =============================================================================
// import.meta, and the scripts a record names
// =============================================================================

/// Every module script alive on this thread. A module map owns each; this
/// only links them, so that a [[HostDefined]] the engine hands back is read
/// only while its script exists. Main thread only: worker module scripts go
/// through html/workers/module_worker.zig.
var live_scripts: ?*ModuleScript = null;

fn track(script: *ModuleScript) void {
    script.live_prev = null;
    script.live_next = live_scripts;
    if (live_scripts) |head| head.live_prev = script;
    live_scripts = script;
    script.live = true;
}

fn untrack(script: *ModuleScript) void {
    if (!script.live) return;
    if (script.live_prev) |prev| prev.live_next = script.live_next else live_scripts = script.live_next;
    if (script.live_next) |next| next.live_prev = script.live_prev;
    script.live = false;
}

/// The module script a record's [[HostDefined]] names, while it exists.
/// (A freed script's address reused by a new one is read as the new one: a
/// wrong base URL, never freed memory.)
pub fn scriptOf(host_defined: *anyopaque) ?*ModuleScript {
    var it = live_scripts;
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
};

/// The base URL of the classic script a Script Record's [[HostDefined]] is.
pub fn classicScriptBaseUrl(host_defined: *anyopaque) []const u8 {
    const script: *const ClassicScript = @ptrCast(@alignCast(host_defined));
    return script.base_url;
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
    const script = try ModuleScript.create(env.allocator, url);
    errdefer script.destroy();

    switch (try engine.parseJSONModule(env.realm(), source, url, script)) {
        .record => |record| script.record = record,
        .parse_error => |parse_error| script.parse_error = parse_error,
    }
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
fn fetchSingleModuleScript(env: *const Environment, url: []const u8, module_type: ModuleType) ?*ModuleScript {
    // Steps 4-6: moduleMap[(url, moduleType)] - an entry means this fetch has
    // already happened, and its result (including a null) is reused.
    const key = std.mem.concat(env.allocator, u8, &.{ module_type.keyPrefix(), url }) catch return null;
    defer env.allocator.free(key);

    if (env.map.get(key)) |entry| {
        if (entry == fetch_failed) return null;
        return @ptrCast(@alignCast(entry));
    }

    const script = fetchAndCreate(env, url, module_type);

    // Step 13.8 (and 13.1 for failures): moduleMap[(url, moduleType)] = result.
    if (!env.map.put(key, if (script) |s| @ptrCast(s) else fetch_failed)) {
        // The map could not take ownership; nothing else will free it.
        if (script) |s| s.destroy();
        return null;
    }
    return script;
}

fn fetchAndCreate(env: *const Environment, url: []const u8, module_type: ModuleType) ?*ModuleScript {
    // Step 13: fetch. A transport failure comes back in-band as a network-error
    // response (status 0), which the ok-status check rejects.
    const response = fetch.fetchSimple(env.allocator, url) catch return null;
    defer response.deinit();

    // Step 13.1: bodyBytes null, or not an ok status (200-299).
    if (response.status < 200 or response.status >= 300) return null;

    const body: []const u8 = if (response.body) |b| b.data.items else "";
    const content_type = response.header_list.getFirstValue("content-type") orelse "";
    const essence = mimeEssence(content_type);

    // The base URL of a fetched module script is the RESPONSE's URL - after
    // redirects - while the map stays keyed by the request URL (step 13.8's note).
    const base_url = response.url() orelse url;

    switch (module_type) {
        // Step 13.7.2: a JavaScript MIME type and moduleType "javascript-or-wasm".
        .javascript => {
            if (!isJavaScriptMimeTypeEssence(essence)) return null;
            return createJavaScriptModuleScript(env, body, base_url) catch null;
        },
        // Step 13.7.4: a JSON MIME type and moduleType "json".
        .json => {
            if (!isJsonMimeTypeEssence(essence)) return null;
            return createJsonModuleScript(env, body, base_url) catch null;
        },
        // Step 13.7.3 needs a constructable CSSStyleSheet as the synthetic
        // export. Until that exists a CSS module fetch yields no script, which
        // the graph reports as a load failure rather than running without it.
        .css => return null,
    }
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
    // Steps 6-8: the import map. Crane's lookup takes the raw specifier; a
    // mapping for a bare specifier is the case it serves.
    if (env.resolveImportFn) |resolveImport| {
        if (resolveImport(env.map.context, specifier, base_url)) |mapped| {
            return parseUrl(env, mapped, "");
        }
    }

    // Steps 4 and 9: a URL-like specifier resolves against the base URL.
    return resolveUrlLikeModuleSpecifier(env, specifier, base_url);
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
    // Step 1.2: fetch the descendants of and link result.
    return fetchDescendantsAndLink(env, result);
}

/// The module type an import's "type" attribute asks for, or null for a type
/// the host does not support ("module type allowed" is false: TypeError).
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-type-from-module-request
pub fn moduleTypeFromAttribute(type_attribute: ?[]const u8) ?ModuleType {
    const t = type_attribute orelse return .javascript;
    if (std.mem.eql(u8, t, "json")) return .json;
    if (std.mem.eql(u8, t, "css")) return .css;
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
    const script = fetchSingleModuleScript(env, url, module_type) orelse return null;
    return fetchDescendantsAndLink(env, script);
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

        requests.appendAssumeCapacity(.{ .specifier = request.specifier, .url = url, .module_type = module_type });
    }

    for (requests.items) |*request| {
        // Step 14: fetch a single imported module script.
        const child = fetchSingleModuleScript(env, request.url, request.module_type) orelse return .fetch_failed;

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
var search_epoch: u32 = 0;

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
    search_epoch +%= 1;
    return findIn(root, record, search_epoch);
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

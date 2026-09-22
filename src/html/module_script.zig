//! Module scripts: fetching a module script graph, linking it, running it.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetching-scripts
//!       https://html.spec.whatwg.org/multipage/webappapis.html#hostloadimportedmodule
//!       https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
//!
//! The spec drives loading through ECMA-262's LoadRequestedModules, which calls
//! the host's HostLoadImportedModule once per module request, asynchronously.
//! V8 13.1 exposes no such hook for static imports: it resolves requests
//! synchronously during `InstantiateModule`, through a ResolveModuleCallback
//! that must hand back an already-compiled module. So this follows d8's shape
//! (and Blink's older ModuleTreeLinker's): walk the graph first - resolve,
//! fetch and compile every request, depth first, recording each module's
//! children - then instantiate, answering V8's callback from the recorded
//! children. Crane's fetch is synchronous, which is what makes a depth-first
//! walk equivalent to the spec's concurrent one: the first failure in
//! DFS order is the one reported, as `choice-of-error-*` expect.
//!
//! What is NOT here yet: CSS module scripts (they need a constructable
//! CSSStyleSheet as a synthetic export), import.meta, and routing dynamic
//! `import()` through this loader - it still has its own path in
//! context_manager.zig.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const webidl = @import("webidl");
const fetch = @import("fetch");
const v8 = @import("v8");
const ffi = v8.ffi;

const log = std.log.scoped(.module_script);

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

    /// The V8 module (Global<Module>*), or null when the source failed to parse
    /// ("record" in the spec).
    record: ?*ffi.Module = null,

    /// Owned. The response URL for a fetched script, the document base URL for
    /// an inline one. Imports resolve against it.
    base_url: []const u8,

    /// Owned Global of the parse error, when `record` is null.
    parse_error: ?*ffi.Value = null,

    /// Owned Global of the error to rethrow: set by "fetch the descendants of
    /// and link" when the graph cannot be linked, and reported instead of
    /// evaluating when the script runs.
    error_to_rethrow: ?*ffi.Value = null,

    /// v8::Module::GetIdentityHash() of `record` - how the resolve callback,
    /// which only hears about the importer, finds it again.
    identity_hash: c_int = 0,

    /// Resolved module requests, in the order the source makes them.
    children: std.ArrayListUnmanaged(Child) = .empty,

    /// Depth-first walk state. `visiting` is set while this script's requests
    /// are being loaded, so a cycle back to it stops instead of recursing
    /// forever - the spec's LoadRequestedModules does the same through
    /// [[Status]] "new" versus "unlinked".
    visiting: bool = false,
    /// This script and everything under it has been loaded successfully.
    loaded: bool = false,

    /// Marks a node already visited by the current `findByIdentityHash` walk.
    search_epoch: u32 = 0,

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
        return self;
    }

    /// Release the script, its V8 handles and its edge list. Children are not
    /// freed - the module map owns them.
    pub fn destroy(self: *ModuleScript) void {
        if (self.record) |record| ffi.v8_Module_Dispose(record);
        if (self.parse_error) |value| ffi.v8_Global_Dispose(value);
        if (self.error_to_rethrow) |value| ffi.v8_Global_Dispose(value);
        for (self.children.items) |child| self.allocator.free(child.specifier);
        self.children.deinit(self.allocator);
        self.allocator.free(self.base_url);
        self.allocator.destroy(self);
    }

    fn setErrorToRethrow(self: *ModuleScript, value: *ffi.Value) void {
        if (self.error_to_rethrow) |old| ffi.v8_Global_Dispose(old);
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
    /// Any instance of the document's realm: the ctx for URL parsing.
    context_instance: *runtime.Instance,
    /// The realm's V8 context (Global<Context>*).
    v8_context: *ffi.Context,
    map: ModuleMap,
    /// The document's import map lookup: the mapped URL for `specifier`
    /// (borrowed), or null when the import map does not mention it. Called
    /// with `map.context`, the document.
    resolveImportFn: ?*const fn (context: *anyopaque, specifier: []const u8, base_url: []const u8) ?[]const u8 = null,
};

// =============================================================================
// Creating module scripts
// =============================================================================

/// Create a JavaScript module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-javascript-module-script
/// Step 7 ParseModule; step 8: on a syntax error the script's parse error is
/// that error and its record stays null.
pub fn createJavaScriptModuleScript(
    env: *const Environment,
    source: []const u8,
    base_url: []const u8,
) !*ModuleScript {
    const script = try ModuleScript.create(env.allocator, base_url);
    errdefer script.destroy();

    const isolate = ffi.v8_Isolate_GetCurrent() orelse return error.NoIsolate;
    const source_str = ffi.v8_String_NewFromUtf8(isolate, source.ptr, @intCast(source.len)) orelse return error.OutOfMemory;
    defer ffi.v8_String_Dispose(source_str);
    const name_str = ffi.v8_String_NewFromUtf8(isolate, base_url.ptr, @intCast(base_url.len)) orelse return error.OutOfMemory;
    defer ffi.v8_String_Dispose(name_str);

    const result = ffi.v8_Module_Compile_Safe(env.v8_context, source_str, name_str);
    defer ffi.v8_FreeModuleCompileResult(result);

    if (result.module) |module| {
        script.record = module;
        script.identity_hash = ffi.v8_Module_GetIdentityHash(module);
    } else {
        script.parse_error = takeException(result.error_info);
    }
    return script;
}

/// Create a JSON module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#creating-a-json-module-script
/// Step 5: ParseJSONModule - a SyntaxError becomes the parse error.
fn createJsonModuleScript(env: *const Environment, source: []const u8, url: []const u8) !*ModuleScript {
    const script = try ModuleScript.create(env.allocator, url);
    errdefer script.destroy();

    var error_info: ?*ffi.V8ErrorInfo = null;
    const module = ffi.v8_Module_CreateJsonModule(
        env.v8_context,
        source.ptr,
        @intCast(source.len),
        url.ptr,
        @intCast(url.len),
        &error_info,
    );
    if (module) |m| {
        script.record = m;
        script.identity_hash = ffi.v8_Module_GetIdentityHash(m);
    } else {
        script.parse_error = takeException(error_info);
        ffi.v8_FreeErrorInfo(error_info);
    }
    return script;
}

/// Copy the thrown value out of an error info the caller still frees.
/// Returns an owned Global, or null when the info carries no exception (a
/// failure V8 reported without an exception object).
fn takeException(info: ?*ffi.V8ErrorInfo) ?*ffi.Value {
    const i = info orelse return null;
    return copyGlobal(i.exception orelse return null);
}

/// A new Global of the same value, owned by the caller.
///
/// Opens its own HandleScope for the Local in between, so it is safe from any
/// caller - the event loop included, which has none.
pub fn copyGlobal(value: *ffi.Value) ?*ffi.Value {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    const scope = ffi.v8_HandleScope_New(isolate) orelse return null;
    defer ffi.v8_HandleScope_Dispose(scope);
    const local = ffi.v8_Global_Get(isolate, value) orelse return null;
    return ffi.v8_Value_ToGlobal(isolate, local);
}

/// The errors the host raises itself.
const ErrorKind = enum { type_error, syntax_error };

/// Make a new exception of the given kind in `env`'s realm, as an owned
/// Global. Used for the errors the host itself raises: an unresolvable
/// specifier, an unsupported type attribute.
fn makeError(env: *const Environment, kind: ErrorKind, message: []const u8) ?*ffi.Value {
    const isolate = ffi.v8_Isolate_GetCurrent() orelse return null;
    const msg = ffi.v8_String_NewFromUtf8(isolate, message.ptr, @intCast(message.len)) orelse return null;
    defer ffi.v8_String_Dispose(msg);
    return switch (kind) {
        .type_error => ffi.v8_Exception_TypeErrorInContext(env.v8_context, msg),
        .syntax_error => ffi.v8_Exception_SyntaxErrorInContext(env.v8_context, msg),
    };
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

/// The essence of a Content-Type value: the type/subtype, lowercased, with
/// parameters and whitespace dropped. Written into a thread-local buffer.
fn mimeEssence(content_type: []const u8) []const u8 {
    const S = struct {
        threadlocal var buf: [128]u8 = undefined;
    };
    const end = std.mem.indexOfScalar(u8, content_type, ';') orelse content_type.len;
    const trimmed = std.mem.trim(u8, content_type[0..end], " \t\r\n");
    const len = @min(trimmed.len, S.buf.len);
    return std.ascii.lowerString(S.buf[0..len], trimmed[0..len]);
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
    // Step 1: fetch a single module script, "javascript-or-wasm".
    // Step 1.1: if result is null, onComplete is given null.
    const result = fetchSingleModuleScript(env, url, .javascript) orelse return null;
    // Step 1.2: fetch the descendants of and link result.
    return fetchDescendantsAndLink(env, result);
}

/// What a failed load leaves behind, mirroring LoadRequestedModules' state:
/// either an error to rethrow (a "syntactic" failure somewhere in the graph)
/// or none (a fetch failure, which makes the whole graph null).
const LoadFailure = union(enum) {
    fetch_failed,
    /// Owned Global.
    rethrow: *ffi.Value,
};

/// Fetch the descendants of and link a module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#fetch-the-descendants-of-and-link-a-module-script
/// Returns the script to hand onComplete, or null for "null". The script may
/// carry an error to rethrow instead of a linkable record.
pub fn fetchDescendantsAndLink(env: *const Environment, script: *ModuleScript) ?*ModuleScript {
    // Step 2: a script whose own source did not parse rethrows its parse error.
    if (script.record == null) {
        if (script.parse_error) |parse_error| {
            if (copyGlobal(parse_error)) |copy| script.setErrorToRethrow(copy);
        }
        return script;
    }

    // Step 5: LoadRequestedModules.
    if (loadRequestedModules(env, script)) |failure| {
        switch (failure) {
            // Step 7.2: rejected with no error to rethrow - a loading error.
            .fetch_failed => return null,
            // Step 7.1.
            .rethrow => |value| {
                script.setErrorToRethrow(value);
                return script;
            },
        }
    }

    // Step 6.1: Link. A failure becomes the error to rethrow.
    if (link(env, script)) |value| script.setErrorToRethrow(value);
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

    const count: usize = @intCast(@max(ffi.v8_Module_GetModuleRequestsLength(record), 0));

    // HostLoadImportedModule step 7: when the first request is loaded, validate
    // every request of this module - attribute keys, specifiers and types -
    // before loading any of them. A module with a static error is treated like
    // one that failed to parse; nothing it imports is fetched.
    var requests = std.ArrayListUnmanaged(Request).empty;
    defer {
        for (requests.items) |r| {
            env.allocator.free(r.specifier);
            env.context_instance.ctx.allocator.free(r.url);
        }
        requests.deinit(env.allocator);
    }
    requests.ensureTotalCapacity(env.allocator, count) catch return .fetch_failed;

    for (0..count) |i| {
        const index: c_int = @intCast(i);
        const specifier = requestSpecifier(env, record, index) orelse return .fetch_failed;

        // Step 7.1.1: an attribute other than "type" is a SyntaxError.
        var status: c_int = 0;
        const type_attr = ffi.v8_Module_GetModuleRequestType(record, index, &status);
        defer ffi.v8_FreeString(type_attr);
        if (status == -1) {
            env.allocator.free(specifier);
            return failWith(env, .syntax_error, "Import attribute is not supported");
        }

        // Steps 7.1.2-7.1.3: resolve a module specifier, or TypeError.
        const url = resolveModuleSpecifier(env, specifier, script.base_url) orelse {
            env.allocator.free(specifier);
            return failWith(env, .type_error, "Failed to resolve module specifier");
        };

        // Steps 7.1.4-7.1.5: module type from module request; "module type
        // allowed" admits javascript-or-wasm, css and json in a Window.
        const module_type: ModuleType = blk: {
            const t = if (type_attr) |p| std.mem.span(p) else break :blk .javascript;
            if (std.mem.eql(u8, t, "json")) break :blk .json;
            if (std.mem.eql(u8, t, "css")) break :blk .css;
            env.allocator.free(specifier);
            env.context_instance.ctx.allocator.free(url);
            return failWith(env, .type_error, "Unsupported module type");
        };

        requests.appendAssumeCapacity(.{ .specifier = specifier, .url = url, .module_type = module_type });
    }

    for (requests.items) |*request| {
        // Step 14: fetch a single imported module script.
        const child = fetchSingleModuleScript(env, request.url, request.module_type) orelse return .fetch_failed;

        // onSingleFetchComplete step 3: a child that did not parse fails the
        // load, and its parse error is the error to rethrow.
        if (child.record == null) {
            const parse_error = child.parse_error orelse return .fetch_failed;
            return .{ .rethrow = copyGlobal(parse_error) orelse return .fetch_failed };
        }

        // Record the edge before descending: a cycle back to this script finds
        // it through here when V8 resolves.
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
    specifier: []const u8, // env.allocator
    url: []const u8, // env.context_instance.ctx.allocator
    module_type: ModuleType,
};

fn requestSpecifier(env: *const Environment, record: *ffi.Module, index: c_int) ?[]const u8 {
    const raw = ffi.v8_Module_GetModuleRequest(record, index) orelse return null;
    defer ffi.v8_FreeString(raw);
    return env.allocator.dupe(u8, std.mem.span(raw)) catch null;
}

fn failWith(env: *const Environment, kind: ErrorKind, message: []const u8) LoadFailure {
    const value = makeError(env, kind, message) orelse return .fetch_failed;
    return .{ .rethrow = value };
}

/// The graph being linked, for the resolve callback. Linking is synchronous
/// and never re-entered, so one slot is enough.
var linking_root: ?*ModuleScript = null;
var search_epoch: u32 = 0;

/// Link: InstantiateModule, with V8's resolve callback answered from the
/// edges recorded while loading. Returns an owned Global of the exception on
/// failure, null on success.
fn link(env: *const Environment, script: *ModuleScript) ?*ffi.Value {
    const record = script.record orelse return null;

    // Installed on every link rather than once: the wrapper drops its callback
    // at isolate teardown (v8_ClearModuleResolveCallback), and a stale "already
    // installed" flag would then fail every import that follows. Setting it is
    // a pointer store.
    ffi.v8_Module_SetResolveCallback(null, &resolveCallback);

    const previous = linking_root;
    linking_root = script;
    defer linking_root = previous;

    const result = ffi.v8_Module_Instantiate_Safe(env.v8_context, record);
    defer ffi.v8_FreeModuleInstantiateResult(result);
    if (result.success) return null;
    return takeException(result.error_info) orelse makeError(env, .syntax_error, "Module could not be linked");
}

/// V8's ResolveModuleCallback: the child `referrer` recorded for this request.
///
/// Returning null makes the wrapper throw the TypeError V8's contract requires
/// (see AGENTS.md on empty MaybeLocals from V8 callbacks).
fn resolveCallback(
    user_data: ?*anyopaque,
    specifier: [*]const u8,
    specifier_len: c_int,
    type_attribute: ?[*:0]const u8,
    referrer_identity_hash: c_int,
) callconv(.c) ?*anyopaque {
    _ = user_data;
    const root = linking_root orelse return null;
    const referrer = findByIdentityHash(root, referrer_identity_hash) orelse return null;

    const wanted_specifier = specifier[0..@intCast(specifier_len)];
    const wanted_type: ?ModuleType = blk: {
        const t = std.mem.span(type_attribute orelse break :blk .javascript);
        if (std.mem.eql(u8, t, "json")) break :blk .json;
        if (std.mem.eql(u8, t, "css")) break :blk .css;
        break :blk null;
    };

    for (referrer.children.items) |child| {
        if (!std.mem.eql(u8, child.specifier, wanted_specifier)) continue;
        if (wanted_type) |t| if (child.module_type != t) continue;
        return @ptrCast(child.script.record orelse return null);
    }
    return null;
}

/// The script in `root`'s graph whose record has this identity hash.
fn findByIdentityHash(root: *ModuleScript, hash: c_int) ?*ModuleScript {
    search_epoch +%= 1;
    return findIn(root, hash, search_epoch);
}

fn findIn(script: *ModuleScript, hash: c_int, epoch: u32) ?*ModuleScript {
    if (script.search_epoch == epoch) return null;
    script.search_epoch = epoch;
    if (script.record != null and script.identity_hash == hash) return script;
    for (script.children.items) |child| {
        if (findIn(child.script, hash, epoch)) |found| return found;
    }
    return null;
}

// =============================================================================
// Running a module script
// =============================================================================

/// V8's Promise::PromiseState values.
const promise_pending: c_int = 0;
const promise_rejected: c_int = 2;

/// What running a module script produced, for the caller to report.
pub const RunResult = union(enum) {
    /// Evaluation completed, or is waiting on top-level await.
    ok,
    /// An exception to report (owned Global).
    report: *ffi.Value,
};

/// Run a module script.
///
/// Spec: https://html.spec.whatwg.org/multipage/webappapis.html#run-a-module-script
/// Steps 6-8. Reporting is the caller's: this returns the exception that
/// "report an exception" must be given, when there is one.
pub fn run(env: *const Environment, script: *ModuleScript) RunResult {
    // Step 6: an error to rethrow is reported instead of evaluating.
    if (script.error_to_rethrow) |value| {
        return if (copyGlobal(value)) |copy| .{ .report = copy } else .ok;
    }

    const record = script.record orelse return .ok;

    // Step 7: record.Evaluate(). V8 returns the evaluation promise.
    const result = ffi.v8_Module_Evaluate_Safe(env.v8_context, record);
    defer ffi.v8_FreeModuleEvaluateResult(result);

    if (result.error_info) |_| {
        return if (takeException(result.error_info)) |value| .{ .report = value } else .ok;
    }
    const promise_value = result.value orelse return .ok;
    defer ffi.v8_Global_Dispose(promise_value);

    // With top-level await shipped, Evaluate always returns a promise; anything
    // else means evaluation completed with nothing to report.
    if (!ffi.v8_Value_IsPromise(promise_value)) return .ok;
    const promise: *ffi.Promise = @ptrCast(promise_value);
    const state = ffi.v8_Promise_State(promise);

    // Step 8: upon rejection, report. A graph with no top-level await settles
    // synchronously, so the reason is already there.
    if (state == promise_rejected) {
        if (ffi.v8_Promise_Result(promise)) |reason| return .{ .report = reason };
        return .ok;
    }

    // A graph still waiting on top-level await reports when it settles.
    // TODO: chain a rejection reaction (engine.chainPromiseHandlers) so a
    // top-level await that rejects later is reported too.
    if (state == promise_pending) log.debug("module evaluation awaits top-level await", .{});
    return .ok;
}

// =============================================================================
// Tests
// =============================================================================

test "mimeEssence strips parameters and case" {
    try std.testing.expectEqualStrings("text/javascript", mimeEssence("Text/JavaScript; charset=utf-8"));
    try std.testing.expectEqualStrings("application/json", mimeEssence(" application/json "));
    try std.testing.expectEqualStrings("", mimeEssence(""));
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

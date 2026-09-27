//! The engine protocol's modules on V8 (design 4.3, [module_scripts]): the
//! ECMAScript Module Record operations - ParseModule, a JSON module's
//! record, [[RequestedModules]], Link(), Evaluate() - and the host hooks that
//! reach modules: HostLoadImportedModule for import() (finished by
//! FinishLoadingImportedModule) and HostGetImportMetaProperties.
//!
//! HTML keeps the module map and fetches the graph; the engine keeps the
//! records. V8 names a module only by its object, so each record the adapter
//! hands out is registered here by the module's identity hash, for the
//! callbacks that are handed a module - a Link's referrer, import.meta - to
//! find the host's record for it.
//!
//! protocol.zig forwards these operations here; protocol_agents.zig installs
//! the hooks on each agent that has them.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const realm_entry = @import("realm_entry.zig");
const context_manager = @import("context_manager.zig");
const support = @import("protocol_support.zig");
const protocol_values = @import("protocol_values.zig");
const protocol_agents = @import("protocol_agents.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Owned = engine.Owned;
const Error = engine.Error;
const Allocator = std.mem.Allocator;

// ============================================================================
// Module Records
// ============================================================================

/// The adapter's Module Record: the host's `*engine.ModuleRecord`.
const Record = struct {
    /// The module, OWNED.
    module: *ffi.Module,
    /// The realm it was parsed in: its [[Realm]].
    realm: Context,
    /// [[HostDefined]]: the host's module script.
    host_defined: ?*anyopaque,
    identity_hash: c_int,
};

fn recordOf(record: *engine.ModuleRecord) *Record {
    return @ptrCast(@alignCast(record));
}

/// The records alive on this thread, by their module's identity hash (which
/// V8 does not promise unique: a collision is told apart with Equals).
/// Modules belong to an agent, and an agent to its thread.
threadlocal var records: std.AutoHashMapUnmanaged(c_int, std.ArrayListUnmanaged(*Record)) = .empty;
const registry_allocator = std.heap.c_allocator;

fn register(record: *Record) Error!void {
    const entry = records.getOrPut(registry_allocator, record.identity_hash) catch return error.OutOfMemory;
    if (!entry.found_existing) entry.value_ptr.* = .empty;
    entry.value_ptr.append(registry_allocator, record) catch return error.OutOfMemory;
}

fn unregister(record: *Record) void {
    const list = records.getPtr(record.identity_hash) orelse return;
    for (list.items, 0..) |r, i| {
        if (r == record) {
            _ = list.swapRemove(i);
            break;
        }
    }
    if (list.items.len == 0) {
        list.deinit(registry_allocator);
        _ = records.remove(record.identity_hash);
    }
}

/// The record whose module `module` is (a handle V8 lent a callback).
fn find(module: *ffi.Module, identity_hash: c_int) ?*Record {
    const list = records.get(identity_hash) orelse return null;
    for (list.items) |r| {
        if (ffi.v8_Module_Equals(r.module, module)) return r;
    }
    return null;
}

fn newRecord(module: *ffi.Module, realm: Context, host_defined: ?*anyopaque) Error!*engine.ModuleRecord {
    const record = registry_allocator.create(Record) catch return error.OutOfMemory;
    errdefer registry_allocator.destroy(record);
    record.* = .{
        .module = module,
        .realm = realm,
        .host_defined = host_defined,
        .identity_hash = ffi.v8_Module_GetIdentityHash(module),
    };
    try register(record);
    return @ptrCast(record);
}

/// The parse error V8 caught, OWNED.
fn caughtError(info: ?*ffi.V8ErrorInfo) Error!Owned {
    const caught = info orelse return error.OperationFailed;
    const exception = caught.exception orelse return error.OperationFailed;
    return support.owned(ffi.v8_Global_Clone(exception) orelse return error.OperationFailed);
}

/// ECMAScript ParseModule(sourceText, realm, hostDefined), as HTML "create a
/// JavaScript module script" uses it: the record, or the SyntaxError that is
/// the script's parse error. The module's ScriptOrigin carries `host_defined`,
/// so that an import() in it names the module as its referrer.
pub fn parseModule(realm: Context, source: []const u8, url: []const u8, host_defined: ?*anyopaque) Error!engine.ParseResult {
    const entered = try support.enter(realm);
    defer entered.leave();
    const isolate = entered.isolate;

    const text = try support.newString(isolate, source);
    defer ffi.v8_String_Dispose(text);
    var name: ?*ffi.String = null;
    defer if (name) |n| ffi.v8_String_Dispose(n);
    if (url.len > 0) name = try support.newString(isolate, url);

    const compiled = ffi.v8_Module_CompileWithHostDefined_Safe(entered.context(), text, name, host_defined);
    defer ffi.v8_FreeModuleCompileResult(compiled);
    const module = compiled.module orelse return .{ .parse_error = try caughtError(compiled.error_info) };

    // HTML "create a JavaScript module script": a request whose import
    // attributes name a key other than "type" (HostGetSupportedImportAttributes
    // is « "type" ») is a SyntaxError, and the script's parse error - its
    // dependencies are never fetched.
    const count = ffi.v8_Module_GetModuleRequestsLength(module);
    var index: c_int = 0;
    while (index < count) : (index += 1) {
        var status: c_int = 0;
        ffi.v8_FreeString(ffi.v8_Module_GetModuleRequestType(module, index, &status));
        if (status == -1) {
            ffi.v8_Module_Dispose(module);
            return .{ .parse_error = try protocol_values.createSyntaxError(realm, "Import attribute is not supported") };
        }
    }

    return .{ .record = newRecord(module, realm, host_defined) catch |err| {
        ffi.v8_Module_Dispose(module);
        return err;
    } };
}

/// HTML "create a JSON module script" steps 4-5: ParseJSONModule(source) - a
/// Synthetic Module Record whose default export is the parsed value - or the
/// SyntaxError JSON.parse threw.
pub fn parseJSONModule(realm: Context, source: []const u8, url: []const u8, host_defined: ?*anyopaque) Error!engine.ParseResult {
    const entered = try support.enter(realm);
    defer entered.leave();
    var parse_error: ?*ffi.V8ErrorInfo = null;
    defer ffi.v8_FreeErrorInfo(parse_error);
    const module = ffi.v8_Module_CreateJsonModule(
        entered.context(),
        source.ptr,
        @intCast(source.len),
        url.ptr,
        @intCast(url.len),
        &parse_error,
    ) orelse return .{ .parse_error = try caughtError(parse_error) };
    return .{ .record = newRecord(module, realm, host_defined) catch |err| {
        ffi.v8_Module_Dispose(module);
        return err;
    } };
}

/// A Module Record's [[RequestedModules]], in source order: the slice and
/// every string in it allocated with `allocator` - the caller frees each
/// specifier and type attribute, then the slice.
pub fn moduleRequests(record: *engine.ModuleRecord, allocator: Allocator) Error![]engine.ModuleRequest {
    const r = recordOf(record);
    const entered = try support.enter(r.realm);
    defer entered.leave();

    const count: usize = @intCast(@max(ffi.v8_Module_GetModuleRequestsLength(r.module), 0));
    const requests = try allocator.alloc(engine.ModuleRequest, count);
    var filled: usize = 0;
    errdefer {
        for (requests[0..filled]) |request| freeRequest(request, allocator);
        allocator.free(requests);
    }
    while (filled < count) : (filled += 1) {
        const index: c_int = @intCast(filled);
        const specifier_z = ffi.v8_Module_GetModuleRequest(r.module, index) orelse return error.OperationFailed;
        defer ffi.v8_FreeString(specifier_z);
        var status: c_int = 0;
        const type_z = ffi.v8_Module_GetModuleRequestType(r.module, index, &status);
        defer ffi.v8_FreeString(type_z);
        const specifier = try allocator.dupe(u8, std.mem.span(specifier_z));
        errdefer allocator.free(specifier);
        const type_attribute: ?[]const u8 = if (type_z) |t| try allocator.dupe(u8, std.mem.span(t)) else null;
        requests[filled] = .{ .specifier = specifier, .type_attribute = type_attribute };
    }
    return requests;
}

fn freeRequest(request: engine.ModuleRequest, allocator: Allocator) void {
    allocator.free(request.specifier);
    if (request.type_attribute) |t| allocator.free(t);
}

/// The Link in progress: the host's resolve, and a place for a failure of
/// its own (out of memory) to be kept.
const Resolving = struct {
    resolve: engine.ResolveModule,
    data: ?*anyopaque,

    fn callback(data: ?*anyopaque, referrer: *ffi.Module, specifier: [*]const u8, specifier_len: c_int, type_attribute: ?[*:0]const u8) callconv(.c) ?*ffi.Module {
        const self: *Resolving = @ptrCast(@alignCast(data orelse return null));
        // The referrer is a record the host holds: every record in its graph
        // came from parseModule or parseJSONModule.
        const referrer_record = find(referrer, ffi.v8_Module_GetIdentityHash(referrer)) orelse return null;
        const resolved = self.resolve(self.data, @ptrCast(referrer_record), .{
            .specifier = specifier[0..@intCast(specifier_len)],
            .type_attribute = if (type_attribute) |t| std.mem.span(t) else null,
        }) orelse return null;
        return recordOf(resolved).module;
    }
};

/// ECMAScript Link() on `record`: each of the graph's requests resolved
/// through the host's `resolve` - HTML has fetched the whole graph by then,
/// and V8 13.1 resolves static imports synchronously, inside Link (docs/
/// lessons/architecture-v8-13-1-resolves-static-imports-synchronously.md).
/// The link error (OWNED) - a request `resolve` could not answer is a
/// TypeError - or null.
pub fn linkModule(realm: Context, record: *engine.ModuleRecord, resolve: engine.ResolveModule, data: ?*anyopaque) Error!?Owned {
    const entered = try support.enter(realm);
    defer entered.leave();
    var resolving = Resolving{ .resolve = resolve, .data = data };
    var exception: ?*ffi.Value = null;
    if (ffi.v8_Module_LinkWithResolver(entered.context(), recordOf(record).module, Resolving.callback, &resolving, &exception)) return null;
    const thrown = exception orelse return error.OperationFailed;
    return support.owned(thrown);
}

/// ECMAScript Evaluate() on a linked `record`: completed, rejected with the
/// reason, or pending on top-level await with the promise (the host reacts
/// to it). A rejected evaluation promise is marked as handled - it is never
/// script's to observe, and its reason is the host's to report - so it is not
/// also an unhandled rejection.
///
/// The host runs this between prepareToRunScript and
/// cleanUpAfterRunningScript (HTML "run a module script" steps 5-9): V8's
/// automatic microtask checkpoint is held off until that clean up, as it is
/// for a classic script.
pub fn evaluateModule(realm: Context, record: *engine.ModuleRecord) Error!engine.ModuleEvaluation {
    const entered = try support.enter(realm);
    defer entered.leave();
    var call = EvaluateCall{ .context = entered.context(), .module = recordOf(record).module };
    ffi.v8_RunWithMicrotasksSuppressed(entered.isolate, EvaluateCall.run, &call);
    return switch (call.outcome) {
        0 => .completed,
        1 => .{ .rejected = support.owned(call.value orelse return error.OperationFailed) },
        2 => .{ .pending = support.owned(call.value orelse return error.OperationFailed) },
        else => error.OperationFailed,
    };
}

const EvaluateCall = struct {
    context: *ffi.Context,
    module: *ffi.Module,
    outcome: c_int = -1,
    value: ?*ffi.Value = null,

    fn run(data: ?*anyopaque) callconv(.c) void {
        const self: *EvaluateCall = @ptrCast(@alignCast(data orelse return));
        self.outcome = ffi.v8_Module_EvaluateForProtocol(self.context, self.module, &self.value);
    }
};

/// The end of the host's hold on a record. The module lives on while V8
/// needs it (another module's import of it, a namespace object).
pub fn releaseModuleRecord(record: *engine.ModuleRecord) void {
    const r = recordOf(record);
    unregister(r);
    ffi.v8_Module_Dispose(r.module);
    registry_allocator.destroy(r);
}

// ============================================================================
// import() - HostLoadImportedModule and FinishLoadingImportedModule
// ============================================================================

/// An import() in flight: the host's `*engine.ImportRequest`.
const ImportRequest = struct {
    /// The context import() was called in, and the promise's resolver: V8
    /// handles, consumed when the import is finished.
    context: *ffi.Context,
    resolver: *anyopaque,
    realm: Context,
};

/// HostLoadImportedModule(referrer, moduleRequest, loadState: undefined,
/// payload) for an import(), handed to the host of the agent whose isolate
/// this is. HTML's step 1 settings object is the current one - the realm
/// import() was called in - and step 6 replaces it with the referrer's when
/// there is a referrer (the host's, through `referrer`).
pub fn onDynamicImport(
    isolate: *ffi.Isolate,
    context: *ffi.Context,
    referrer_kind: c_int,
    referrer: ?*anyopaque,
    specifier: [*]const u8,
    specifier_len: c_int,
    type_attribute: ?[*:0]const u8,
    resolver: *anyopaque,
) callconv(.c) void {
    const fail = struct {
        fn with(ctx: *ffi.Context, res: *anyopaque, message: []const u8) void {
            ffi.v8_DynamicImport_Reject(ctx, res, message.ptr, @intCast(message.len));
        }
    };
    const agent = protocol_agents.recordOf(isolate) orelse return fail.with(context, resolver, "import() is not supported here");
    const load = agent.hooks.loadImportedModule orelse return fail.with(context, resolver, "import() is not supported here");
    const realm = context_manager.get(context) orelse return fail.with(context, resolver, "import() from a realm that has ended");

    const request = registry_allocator.create(ImportRequest) catch return fail.with(context, resolver, "out of memory");
    request.* = .{ .context = context, .resolver = resolver, .realm = realm };
    const import_referrer: engine.ImportReferrer = switch (referrer_kind) {
        0 => if (referrer) |p| .{ .script = p } else .realm,
        1 => if (referrer) |p| .{ .module = p } else .realm,
        // [[ScriptOrModule]] is null: an event handler, eval, a timer's
        // string handler, or script compiled outside the protocol.
        else => .realm,
    };
    load(
        agent.host,
        realm,
        import_referrer,
        specifier[0..@intCast(specifier_len)],
        if (type_attribute) |t| std.mem.span(t) else null,
        @ptrCast(request),
    );
}

/// FinishLoadingImportedModule(referrer, moduleRequest, payload, result) for
/// an import(): ContinueDynamicImport - reject with the failure, or Link,
/// Evaluate and resolve with the module namespace once evaluation settles.
/// Ends the host's hold on `request`.
pub fn finishDynamicImport(request: *engine.ImportRequest, outcome: engine.DynamicImportOutcome) void {
    const pending: *ImportRequest = @ptrCast(@alignCast(request));
    defer registry_allocator.destroy(pending);
    const entered = support.enter(pending.realm) catch {
        // The realm has ended: nothing can observe the promise any more.
        ffi.v8_DynamicImport_Reject(pending.context, pending.resolver, "", 0);
        return;
    };
    defer entered.leave();
    switch (outcome) {
        .module => |record| ffi.v8_DynamicImport_ContinueWithModule(pending.context, pending.resolver, recordOf(record).module),
        .failure => |reason| {
            const value = realm_entry.EngineValue.of(entered.isolate, entered.context(), reason) catch {
                ffi.v8_DynamicImport_Reject(pending.context, pending.resolver, "", 0);
                return;
            };
            defer value.release();
            ffi.v8_DynamicImport_RejectWithValue(pending.context, pending.resolver, value.ptr);
        },
    }
}

// ============================================================================
// import.meta - HostGetImportMetaProperties
// ============================================================================

/// HostGetImportMetaProperties(moduleRecord), step 1-3: import.meta.url is
/// the host's module script's base URL. (Steps 4-6, import.meta.resolve, are
/// not provided: the hook names only the URL.)
pub fn onImportMetaUrl(isolate: *ffi.Isolate, module: *ffi.Module, identity_hash: c_int, len: *usize) callconv(.c) ?[*]const u8 {
    const agent = protocol_agents.recordOf(isolate) orelse return null;
    const url_of = agent.hooks.importMetaUrl orelse return null;
    const record = find(module, identity_hash) orelse return null;
    const host_defined = record.host_defined orelse return null;
    const url = url_of(agent.host, host_defined);
    len.* = url.len;
    return url.ptr;
}

// ============================================================================
// The legacy entry points' bridge
//
// TODO(protocol): removed when Browser creates its agent with
// engine.createAgent (navigation lane resume). Until then the page's agent
// is a bare isolate, with no HostHooks installed: script_execution's shim
// takes import() from engine.zig's legacy handler, and import.meta from V8's
// import.meta callback, and hands them to the same host code the hooks run.
// These two turn what those entry points hold into the protocol's types.
// ============================================================================

/// TRANSITIONAL. The protocol's request for an import() the legacy handler
/// took: its Global<Context> and Global<Promise::Resolver> - the pair
/// onDynamicImport builds, consumed by the same v8_DynamicImport_* calls -
/// OWNED by the request from here, until finishDynamicImport releases them.
/// TODO(protocol): removed when Browser creates its agent with
/// engine.createAgent (navigation lane resume).
pub fn adoptLegacyImport(context: *anyopaque, resolver: *anyopaque, realm: Context) Error!*engine.ImportRequest {
    const request = registry_allocator.create(ImportRequest) catch return error.OutOfMemory;
    request.* = .{ .context = @ptrCast(@alignCast(context)), .resolver = resolver, .realm = realm };
    return @ptrCast(request);
}

/// TRANSITIONAL. The host_defined of the record whose module `module` is
/// (V8's import.meta callback names a module only by itself), or null.
/// TODO(protocol): removed when Browser creates its agent with
/// engine.createAgent (navigation lane resume).
pub fn hostDefinedOf(module: *ffi.Module, identity_hash: c_int) ?*anyopaque {
    const record = find(module, identity_hash) orelse return null;
    return record.host_defined;
}

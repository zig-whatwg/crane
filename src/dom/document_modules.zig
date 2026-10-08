//! A Document's module map and import map, as HTML's module script loading
//! reaches them.
//!
//! HTML keeps a module map - the module scripts fetched so far, by URL and
//! type - and an import map on a script's settings object and global. Crane
//! keeps both on the Document, with the allocator module scripts are made
//! with: a module script lives in the map, and dies with the Document, whose
//! teardown runs the dispose function the loader installed. None of that is
//! reachable from script, so Document installs this hook from its installHooks and
//! html's script_execution builds a module loading environment from it
//! (module_script.Environment). Blink keeps the same on the document's
//! Modulator (core/script/modulator.h): its ModuleMap and its import map.
//!
//! Map values are the loader's module scripts, opaque here: module_script
//! defines them, and dom cannot see html.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#module-map
//! Spec: https://html.spec.whatwg.org/multipage/webappapis.html#import-maps
//!
//! lint-impls: hook for Document

const std = @import("std");
const process_start = @import("process_start.zig");
const runtime = @import("runtime");

pub const Error = error{ InvalidStateError, OutOfMemory };

/// Frees one module map value, when the Document goes.
pub const DisposeFn = *const fn (module: *anyopaque) void;
pub const VisitLoaderFn = *const fn (loader: *anyopaque, data: ?*anyopaque) void;

/// What Document supplies.
pub const Implementation = struct {
    /// The allocator the document's module scripts are made with; null for
    /// an object that is no Document.
    allocator: *const fn (document: *runtime.Instance) ?std.mem.Allocator,
    get_module: *const fn (document: *runtime.Instance, key: []const u8) ?*anyopaque,
    /// Stores `module` under `key`, disposing of any module it replaces.
    set_module: *const fn (document: *runtime.Instance, key: []const u8, module: *anyopaque) Error!void,
    set_module_dispose_function: *const fn (document: *runtime.Instance, dispose: ?DisposeFn) void,
    import_map_acquired: *const fn (document: *runtime.Instance) bool,
    acquire_import_map: *const fn (document: *runtime.Instance) void,
    add_import_mapping: *const fn (document: *runtime.Instance, specifier: []const u8, resolved_url: []const u8) Error!void,
    add_scoped_import_mapping: *const fn (document: *runtime.Instance, scope_prefix: []const u8, specifier: []const u8, resolved_url: []const u8) Error!void,
    resolve_import_specifier: *const fn (document: *runtime.Instance, specifier: []const u8, referrer_url: []const u8) ?[]const u8,
    get_loader: ?*const fn (document: *runtime.Instance) ?*anyopaque = null,
    set_loader: ?*const fn (document: *runtime.Instance, loader: *anyopaque, dispose: DisposeFn) Error!void = null,
    visit_realm_loaders: ?*const fn (realm: runtime.Context, visit: VisitLoaderFn, data: ?*anyopaque) void = null,
};

/// Process-wide, written once at start-up (process_start.zig).
var implementation: ?Implementation = null;

/// Called by Document's installHooks, once, at process start (process_start.zig).
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// The allocator `document`'s module scripts are made with; null for an
/// object that is no Document.
pub fn allocator(document: *runtime.Instance) ?std.mem.Allocator {
    const impl = implementation orelse return null;
    return impl.allocator(document);
}

/// The module stored in `document`'s module map under `key`.
pub fn getModule(document: *runtime.Instance, key: []const u8) ?*anyopaque {
    const impl = implementation orelse return null;
    return impl.get_module(document, key);
}

/// Store `module` in `document`'s module map under `key`; the map owns it
/// from here on.
pub fn setModule(document: *runtime.Instance, key: []const u8, module: *anyopaque) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.set_module(document, key, module);
}

/// How `document` frees its module map's values when it goes.
pub fn setModuleDisposeFunction(document: *runtime.Instance, dispose: ?DisposeFn) void {
    const impl = implementation orelse return;
    impl.set_module_dispose_function(document, dispose);
}

/// The document owns its asynchronous module loader until teardown, before
/// releasing the module records that the loader's graphs reference.
pub fn getLoader(document: *runtime.Instance) ?*anyopaque {
    const impl = implementation orelse return null;
    const get = impl.get_loader orelse return null;
    return get(document);
}

pub fn setLoader(document: *runtime.Instance, loader: *anyopaque, dispose: DisposeFn) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    const set = impl.set_loader orelse return error.InvalidStateError;
    try set(document, loader, dispose);
}

/// Includes old documents retained when a Window's realm is reused. The
/// callback must not run script or mutate the document registry.
pub fn visitRealmLoaders(realm: runtime.Context, visit: VisitLoaderFn, data: ?*anyopaque) void {
    const impl = implementation orelse return;
    const visit_loaders = impl.visit_realm_loaders orelse return;
    visit_loaders(realm, visit, data);
}

/// Whether `document` already took an import map (later ones are ignored).
pub fn importMapAcquired(document: *runtime.Instance) bool {
    const impl = implementation orelse return false;
    return impl.import_map_acquired(document);
}

/// Mark `document`'s import map as acquired.
pub fn acquireImportMap(document: *runtime.Instance) void {
    const impl = implementation orelse return;
    impl.acquire_import_map(document);
}

/// Map `specifier` to `resolved_url` in `document`'s import map.
pub fn addImportMapping(document: *runtime.Instance, specifier: []const u8, resolved_url: []const u8) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.add_import_mapping(document, specifier, resolved_url);
}

/// Map `specifier` to `resolved_url` for the scope `scope_prefix` in
/// `document`'s import map.
pub fn addScopedImportMapping(document: *runtime.Instance, scope_prefix: []const u8, specifier: []const u8, resolved_url: []const u8) Error!void {
    const impl = implementation orelse return error.InvalidStateError;
    return impl.add_scoped_import_mapping(document, scope_prefix, specifier, resolved_url);
}

/// `specifier` resolved through `document`'s import map for a script at
/// `referrer_url`, or null when no mapping applies. Borrowed from the map.
pub fn resolveImportSpecifier(document: *runtime.Instance, specifier: []const u8, referrer_url: []const u8) ?[]const u8 {
    const impl = implementation orelse return null;
    return impl.resolve_import_specifier(document, specifier, referrer_url);
}

test "without an installed implementation a document has no module map" {
    const saved = implementation;
    defer implementation = saved;
    implementation = null;
    // Never dereferenced: with no implementation nothing reads it.
    var document: runtime.Instance = undefined;
    try std.testing.expect(allocator(&document) == null);
    try std.testing.expect(getModule(&document, "javascript-or-wasm:https://example.test/m.js") == null);
    try std.testing.expect(!importMapAcquired(&document));
    try std.testing.expect(resolveImportSpecifier(&document, "a", "https://example.test/") == null);
}

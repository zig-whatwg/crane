//! CSS Font Loading 3 §2: descriptor, promise and request ownership.
//! Shared algorithms live in dom.style.font_loading; this owner installs
//! their hook and participates in document abort and realm teardown.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const fonts = dom.style.engine.resource_loading.font_loading;
const FontFace = interfaces.FontFace;

pub const State = FontFace.State;
pub const ImplError = error{ NotImplemented, InvalidStateError, SyntaxError };
pub const InternalState = fonts.Face;
const Registry = runtime.InstanceRegistry(.font_face, InternalState);

pub fn installHooks() void {
    dom.style.hooks.install(.{ .font_face_of = fontFaceOf });
    dom.orphan_states.installRegistrySweep(Registry);
    dom.document_fetches.install(.{ .discard = discardRealm, .prepare_abort = prepareAbort, .abort = abortDocument });
}

pub fn initOwn(instance: *runtime.Instance, _: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    instance.getState(StateType).own._internal = null;
    // Q16: worker realms share BrowserScope but not its window thread.
    // Their font loading is deferred; never even read that registry there.
    if (!instance.ctx.isWindow()) return;
    const internal = try Registry.createIn(instance, runtime.arenaOf(instance));
    internal.* = fonts.Face.init(instance);
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    if (!instance.ctx.isWindow()) return;
    if (Registry.get(instance)) |internal| internal.deinit();
    if (instance.stateAs(State)) |state| state.own._internal = null;
    Registry.remove(instance);
}

fn fontFaceOf(instance: *runtime.Instance) ?*fonts.Face {
    if (!instance.ctx.isWindow()) return null;
    return Registry.get(instance);
}

fn faceOf(instance: *runtime.Instance) !*fonts.Face {
    return fontFaceOf(instance) orelse error.InvalidStateError;
}

/// Font Loading 3 §2.1 steps 1–3. Invalid syntax rejects loaded rather
/// than throwing from construction; allocation failures remain errors.
pub fn call_constructor(ctx: runtime.Context, family: typedefs.CSSOMString, source: typedefs.CSSOMStringOrBufferSource, descriptors: webidl.Opt(dictionaries.FontFaceDescriptors)) !*runtime.Instance {
    const instance = try FontFace.init(ctx.allocator, ctx);
    errdefer runtime.Instance.deinit(instance);
    if (!ctx.isWindow()) return instance;
    const face = try faceOf(instance);
    try face.loaded.ensure(instance);
    try face.setDescriptorValue(.family, "font-family", family.asSlice());
    const dict: dictionaries.FontFaceDescriptors = if (descriptors.was_passed) descriptors.value else .{};
    var invalid = false;
    if (dict.style) |value| face.setDescriptorValue(.style, "font-style", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            // Chrome/Firefox/Safari retain initial "normal" for an invalid
            // constructor style (integrator fontstyle probe, 2026-10-22).
            // Rejection/status still follow Font Loading 3 §2.1 step 2.
            invalid = true;
        },
        else => return err,
    };
    if (dict.weight) |value| face.setDescriptorValue(.weight, "font-weight", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("font-weight");
            invalid = true;
        },
        else => return err,
    };
    if (dict.stretch) |value| face.setDescriptorValue(.stretch, "font-stretch", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("font-stretch");
            invalid = true;
        },
        else => return err,
    };
    if (dict.unicodeRange) |value| face.setDescriptorValue(.unicode_range, "unicode-range", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("unicode-range");
            invalid = true;
        },
        else => return err,
    };
    if (dict.featureSettings) |value| face.setDescriptorValue(.feature_settings, "font-feature-settings", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("font-feature-settings");
            invalid = true;
        },
        else => return err,
    };
    if (dict.variationSettings) |value| face.setDescriptorValue(.variation_settings, "font-variation-settings", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("font-variation-settings");
            invalid = true;
        },
        else => return err,
    };
    if (dict.display) |value| face.setDescriptorValue(.display, "font-display", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("font-display");
            invalid = true;
        },
        else => return err,
    };
    if (dict.ascentOverride) |value| face.setDescriptorValue(.ascent_override, "ascent-override", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("ascent-override");
            invalid = true;
        },
        else => return err,
    };
    if (dict.descentOverride) |value| face.setDescriptorValue(.descent_override, "descent-override", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("descent-override");
            invalid = true;
        },
        else => return err,
    };
    if (dict.lineGapOverride) |value| face.setDescriptorValue(.line_gap_override, "line-gap-override", value.asSlice()) catch |err| switch (err) {
        error.SyntaxError => {
            try face.emptyDescriptor("line-gap-override");
            invalid = true;
        },
        else => return err,
    };
    switch (source) {
        .cssomstring => |text| {
            if (!try face.setSource(text.asSlice())) invalid = true;
            if (invalid) try face.reject(.syntax);
        },
        .buffer_source => |buffer| {
            if (invalid) {
                try face.reject(.syntax);
            } else if (buffer.jsValue(runtime.JSValue)) |value| {
                const bytes = (try engine.getCopyOfBufferSourceBytes(ctx, value, ctx.allocator)) orelse return error.TypeError;
                defer ctx.allocator.free(bytes);
                try face.startBuffer(bytes);
            } else {
                const bytes = buffer.asBytes() catch {
                    try face.reject(.syntax);
                    return instance;
                };
                try face.startBuffer(bytes);
            }
        },
    }
    return instance;
}

fn descriptor(instance: *runtime.Instance, comptime name: []const u8) !typedefs.CSSOMString {
    return runtime.DOMString.initDupe(instance.ctx.allocator, (try faceOf(instance)).getDescriptor(name));
}

pub fn get_family(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-family");
}
pub fn set_family(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.family, "font-family", value.asSlice());
}

pub fn get_style(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-style");
}
pub fn set_style(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.style, "font-style", value.asSlice());
}

pub fn get_weight(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-weight");
}
pub fn set_weight(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.weight, "font-weight", value.asSlice());
}

pub fn get_stretch(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-stretch");
}
pub fn set_stretch(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.stretch, "font-stretch", value.asSlice());
}

pub fn get_unicodeRange(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "unicode-range");
}
pub fn set_unicodeRange(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.unicode_range, "unicode-range", value.asSlice());
}

pub fn get_featureSettings(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-feature-settings");
}
pub fn set_featureSettings(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.feature_settings, "font-feature-settings", value.asSlice());
}

pub fn get_variationSettings(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-variation-settings");
}
pub fn set_variationSettings(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.variation_settings, "font-variation-settings", value.asSlice());
}

pub fn get_display(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "font-display");
}
pub fn set_display(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.display, "font-display", value.asSlice());
}

pub fn get_ascentOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "ascent-override");
}
pub fn set_ascentOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.ascent_override, "ascent-override", value.asSlice());
}

pub fn get_descentOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "descent-override");
}
pub fn set_descentOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.descent_override, "descent-override", value.asSlice());
}

pub fn get_lineGapOverride(instance: *runtime.Instance) anyerror!typedefs.CSSOMString {
    return descriptor(instance, "line-gap-override");
}
pub fn set_lineGapOverride(instance: *runtime.Instance, value: typedefs.CSSOMString) anyerror!void {
    try (try faceOf(instance)).setDescriptorValue(.line_gap_override, "line-gap-override", value.asSlice());
}

pub fn get_status(instance: *runtime.Instance) anyerror!enums.FontFaceLoadStatus {
    return switch ((try faceOf(instance)).status) {
        .unloaded => ._unloaded_,
        .loading => ._loading_,
        .loaded => ._loaded_,
        .failure => ._error_,
    };
}

pub fn get_loaded(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return (try (try faceOf(instance)).loadedPromise()).take();
}

pub fn call_load(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const face = try faceOf(instance);
    const promise = try face.loadedPromise();
    errdefer promise.release();
    try face.start();
    return promise.take();
}

// The font introspection interfaces require the platform font capability.
pub fn get_features(_: *runtime.Instance) anyerror!*runtime.Instance {
    return error.NotImplemented;
}
pub fn get_variations(_: *runtime.Instance) anyerror!*runtime.Instance {
    return error.NotImplemented;
}
pub fn get_palettes(_: *runtime.Instance) anyerror!*runtime.Instance {
    return error.NotImplemented;
}

fn discardRealm(realm: runtime.Context) void {
    if (!realm.isWindow()) return;
    var iterator = Registry.iterator(realm.browserScope() orelse return) orelse return;
    while (iterator.next()) |entry| if (entry.internal.realm == realm) {
        entry.internal.discardForRealm();
    };
}
fn prepareAbort(document: *runtime.Instance) bool {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return false;
    var marked = false;
    while (iterator.next()) |entry| marked = entry.internal.markAbort(document) or marked;
    return marked;
}
fn abortDocument(document: *runtime.Instance) void {
    var iterator = Registry.iterator(runtime.BrowserScope.ofInstance(document)) orelse return;
    while (iterator.next()) |entry| entry.internal.abortMarked(document);
}

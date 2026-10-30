//! Implementation of the WebIDL namespace CSS.
//!
//! CSSOM defines the namespace (escape); CSS Conditional 3 adds supports();
//! the Houdini specs (Properties and Values, Paint, Layout, Animation
//! Worklet), the Highlight API, CSS Images 4, the Parser API and Typed OM
//! (the numeric factories CSS.px(), CSS.em(), ...) extend it with partial
//! namespaces. escape and both supports overloads are implemented; every
//! other operation answers NotImplemented until it is. They exist because
//! codegen merges every partial namespace (WebIDL "partial definitions"); it
//! used to keep only the last file's.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const css_syntax = @import("css");
const engine = @import("engine");
const interfaces = @import("interfaces");
const selector = @import("selector");

/// CSSOM: "The escape(ident) operation must return the result of invoking
/// serialize an identifier of ident."
/// https://drafts.csswg.org/cssom/#dom-css-escape
pub fn call_escape(ctx: runtime.Context, ident: runtime.DOMString) anyerror!runtime.DOMString {
    const escaped = try css_syntax.serialize.serializeIdentifier(ctx.getAllocator(), ident.asSlice());
    return runtime.DOMString.initOwned(escaped);
}

/// CSS Conditional 3: supports(property, value) - "If property is an ASCII
/// case-insensitive match for any defined CSS property that the UA supports,
/// or is a custom property name string, and value successfully parses
/// according to that property's grammar, return true. Otherwise, return
/// false." Never throws.
/// https://drafts.csswg.org/css-conditional-3/#dom-css-supports
pub fn call_supports(ctx: runtime.Context, property: runtime.DOMString, value: runtime.DOMString) anyerror!bool {
    return css_syntax.supports.supportsDeclaration(ctx.getAllocator(), property.asSlice(), value.asSlice());
}

/// CSS Conditional 3: supports(conditionText) - the text parsed and
/// evaluated as a <supports-condition>, then retried wrapped in
/// parentheses; selector() asks src/selector. Never throws.
/// https://drafts.csswg.org/css-conditional-3/#dom-css-supports-conditiontext
pub fn call_supports__1(ctx: runtime.Context, conditionText: runtime.DOMString) anyerror!bool {
    return css_syntax.supports.supportsCondition(ctx.getAllocator(), conditionText.asSlice(), &selectorIsSupported, null);
}

/// CSS Conditional 4 <supports-selector-fn>: "true if the UA supports the
/// selector" - it parses as exactly one <complex-selector>.
fn selectorIsSupported(allocator: std.mem.Allocator, text: []const u8, _: ?*const css_syntax.namespace_map.NamespaceMap) bool {
    return selector.isSupported(allocator, text, .{}) catch false;
}

// The worklets (CSS Painting API 3, CSS Layout API, CSS Animation Worklet):
// the paintWorklet, layoutWorklet and animationWorklet attributes are
// [SameObject] Worklets of the Window - each "the Worklet object" of its
// worklet type, made on first read and kept by the Window (engine.traceChild,
// as a generated [SameObject] cache keeps its child), so a later read in the
// same realm returns the same object. The namespace's getter runs in the
// current realm, the CSS namespace object's - a Window's ([Exposed=Window]).

pub fn get_paintWorklet(ctx: runtime.Context) anyerror!runtime.JSValue {
    return windowWorklet(ctx, .paint, "CSS.paintWorklet");
}

pub fn get_layoutWorklet(ctx: runtime.Context) anyerror!runtime.JSValue {
    return windowWorklet(ctx, .layout, "CSS.layoutWorklet");
}

pub fn get_animationWorklet(ctx: runtime.Context) anyerror!runtime.JSValue {
    return windowWorklet(ctx, .animation, "CSS.animationWorklet");
}

fn windowWorklet(ctx: runtime.Context, comptime kind: @TypeOf(.enum_literal), comptime slot_name: []const u8) !runtime.JSValue {
    const record = ctx.getRealm() orelse return error.InvalidStateError;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return error.InvalidStateError));
    if (window.stateAs(interfaces.Window.State) == null) return error.InvalidStateError;
    const slot: engine.TracedSlot = .{ .name = slot_name };
    if (engine.tracedValue(window, slot)) |held| {
        defer held.release();
        if (engine.convertToPlatformObject(ctx, held.value)) |worklet| return .{ .instance = worklet };
    }
    const worklet = try interfaces.Worklet.initWith(ctx.allocator, ctx, .{ .worklet_kind = kind });
    engine.traceChild(window, worklet, slot);
    return .{ .instance = worklet };
}

// Not implemented yet: each answers NotImplemented (an operation throws).

pub fn call_parseDeclarationList(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_parseCommaValueList(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    return error.NotImplemented;
}

pub fn call_ric(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "ric") };
}

pub fn call_lvmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lvmin") };
}

pub fn call_cqmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cqmax") };
}

pub fn call_svmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "svmin") };
}

pub fn call_s(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "s") };
}

pub fn call_ch(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "ch") };
}

pub fn call_rcap(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "rcap") };
}

pub fn call_vi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "vi") };
}

pub fn call_lh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lh") };
}

pub fn call_cqh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cqh") };
}

pub fn call_cm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cm") };
}

pub fn call_Hz(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "Hz") };
}

pub fn call_svb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "svb") };
}

pub fn call_svh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "svh") };
}

pub fn call_in(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "in") };
}

pub fn call_vmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "vmax") };
}

pub fn call_deg(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "deg") };
}

pub fn call_dvb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dvb") };
}

pub fn call_lvw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lvw") };
}

pub fn call_cqb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cqb") };
}

pub fn call_pt(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "pt") };
}

pub fn call_kHz(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "kHz") };
}

pub fn call_fr(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "fr") };
}

pub fn call_ex(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "ex") };
}

pub fn call_Q(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "Q") };
}

pub fn call_dpcm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dpcm") };
}

pub fn call_rch(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "rch") };
}

pub fn call_rex(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "rex") };
}

pub fn call_parseRuleList(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_rad(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "rad") };
}

pub fn call_mm(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "mm") };
}

pub fn call_svmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "svmax") };
}

pub fn call_cqw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cqw") };
}

pub fn call_percent(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "percent") };
}

pub fn call_em(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "em") };
}

pub fn call_grad(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "grad") };
}

pub fn call_vmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "vmin") };
}

pub fn call_dvh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dvh") };
}

pub fn call_svw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "svw") };
}

pub fn call_vb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "vb") };
}

pub fn call_lvh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lvh") };
}

pub fn call_rem(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "rem") };
}

pub fn call_lvb(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lvb") };
}

pub fn call_svi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "svi") };
}

pub fn call_vw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "vw") };
}

pub fn call_parseRule(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_cap(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cap") };
}

pub fn call_dvw(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dvw") };
}

pub fn call_dvmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dvmax") };
}

pub fn call_dpi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dpi") };
}

pub fn call_number(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "number") };
}

pub fn call_lvmax(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lvmax") };
}

pub fn call_ic(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "ic") };
}

pub fn call_rlh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "rlh") };
}

pub fn call_turn(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "turn") };
}

pub fn call_px(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "px") };
}

pub fn call_parseDeclaration(ctx: runtime.Context, css: runtime.DOMString, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_parseStylesheet(ctx: runtime.Context, css: runtime.JSValue, options: webidl.Opt(runtime.JSValue)) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    _ = options;
    return error.NotImplemented;
}

pub fn call_cqmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cqmin") };
}

pub fn call_parseValue(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    return error.NotImplemented;
}

/// Properties and Values §4.1. The namespace binding currently passes this
/// dictionary as JSValue, so WebIDL §3.2.18 conversion happens here, once and
/// in lexicographical member order, before any registration algorithm step.
pub fn call_registerProperty(ctx: runtime.Context, definition: runtime.JSValue) anyerror!void {
    // Null/undefined are empty dictionaries and lack required inherits/name;
    // other primitives fail dictionary conversion at step 1.
    if (engine.typeOf(ctx, definition) != .object) return error.TypeError;
    // Current-browser seam (Q2): inherits is still required.
    const inherits = (try engine.getPropertyBoolean(ctx, definition, "inherits")) orelse return error.TypeError;
    const initial = try registrationString(ctx, definition, "initialValue");
    defer if (initial) |text| ctx.allocator.free(text);
    const name = (try registrationString(ctx, definition, "name")) orelse return error.TypeError;
    defer ctx.allocator.free(name);
    const syntax = try registrationString(ctx, definition, "syntax");
    defer if (syntax) |text| ctx.allocator.free(text);

    // §4.1 step 1: the relevant global's associated Document owns the set.
    const dom = @import("dom");
    const document = dom.style.objects.associatedDocument(ctx) orelse return error.NotSupportedError;
    const styles = dom.style.hooks.engineOf(document) orelse return error.InvalidStateError;
    var parse_context = try dom.style.engine.resource_loading.inlineParseContext(document, ctx.allocator, false, initial orelse "");
    defer parse_context.deinit();
    try styles.registerProperty(document, parse_context.options(), .{
        .name = name,
        .syntax = syntax orelse "*",
        .inherits = inherits,
        .initial_value = initial,
    });
}

/// WebIDL DOMString member conversion. Get's handle and the returned string
/// have distinct owners; the caller keeps only the copied UTF-8 string.
fn registrationString(ctx: runtime.Context, definition: runtime.JSValue, member: []const u8) !?[]u8 {
    const got = try engine.getProperty(ctx, definition, member);
    defer got.release();
    if (engine.typeOf(ctx, got.value) == .undefined) return null;
    return try engine.convertToDOMString(ctx, got.value, ctx.allocator);
}

pub fn call_dvi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dvi") };
}

pub fn call_pc(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "pc") };
}

pub fn call_dppx(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dppx") };
}

pub fn call_cqi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "cqi") };
}

pub fn call_ms(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "ms") };
}

pub fn call_dvmin(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "dvmin") };
}

pub fn call_parseValueList(ctx: runtime.Context, css: runtime.DOMString) anyerror!runtime.JSValue {
    _ = ctx;
    _ = css;
    return error.NotImplemented;
}

pub fn call_vh(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "vh") };
}

pub fn call_lvi(ctx: runtime.Context, value: f64) anyerror!runtime.JSValue {
    // CSS Typed OM §4.3.5: a new numeric value in the factory's unit.
    return .{ .instance = try interfaces.CSSUnitValue.call_constructor(ctx, value, "lvi") };
}

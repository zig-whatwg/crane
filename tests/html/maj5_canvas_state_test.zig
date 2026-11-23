//! Lane maj5: a 2D context's drawing state (HTML 4.12.5.1.3-5, .17-.20) -
//! each attribute's initial value, its setter's validation, save() /
//! restore() of the whole state, reset() - for CanvasRenderingContext2D and
//! OffscreenCanvasRenderingContext2D, which share the mixins. Chrome,
//! Firefox and Safari expose them all with values of the IDL types
//! (html/dom/idlharness.https.html CanvasRenderingContext2D "must inherit
//! property ... with the proper type").
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const engine = @import("engine");

fn onFreshThread(comptime exercise: fn () anyerror!void) !void {
    const Run = struct {
        fn run(failure: *?anyerror) void {
            exercise() catch |err| {
                failure.* = err;
            };
        }
    };
    var failure: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn open() !*browser_mod.Browser {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .snapshot_path = "" });
    errdefer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "https://maj5.test/page.html" });
    _ = try browser.runEventLoopBlocking(20);
    return browser;
}

fn run(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    held.release();
}

fn expectTrue(browser: *browser_mod.Browser, source: []const u8) !void {
    const held = try browser.evaluateScript(source);
    defer held.release();
    const realm = browser.getRealm() orelse return error.NoRealm;
    if (!engine.toBoolean(realm, held.borrow())) {
        const page = browser.current_context orelse return error.NoPage;
        const log = try page.evaluateScriptToString("JSON.stringify(globalThis.log || null)", testing.allocator);
        defer testing.allocator.free(log);
        std.debug.print("expected true: {s}\nlog: {s}\n", .{ source, log });
        return error.TestExpectedTrue;
    }
}

/// Every drawing state attribute's initial value, read from `ctx` - which a
/// script defines first - into `globalThis.log` where it differs.
const initial_values =
    \\globalThis.log = [];
    \\(() => {
    \\const initial = {
    \\  lineWidth: 1, lineCap: 'butt', lineJoin: 'miter', miterLimit: 10, lineDashOffset: 0,
    \\  globalAlpha: 1, globalCompositeOperation: 'source-over',
    \\  shadowOffsetX: 0, shadowOffsetY: 0, shadowBlur: 0, shadowColor: 'rgba(0, 0, 0, 0)',
    \\  filter: 'none', font: '10px sans-serif', textAlign: 'start', textBaseline: 'alphabetic',
    \\  direction: 'inherit', letterSpacing: '0px', wordSpacing: '0px', fontKerning: 'auto',
    \\  fontStretch: 'normal', fontVariantCaps: 'normal', textRendering: 'auto', lang: 'inherit',
    \\  imageSmoothingEnabled: true, imageSmoothingQuality: 'low',
    \\  fillStyle: '#000000', strokeStyle: '#000000',
    \\};
    \\for (const [name, value] of Object.entries(initial)) {
    \\  if (ctx[name] !== value) log.push(name + '=' + String(ctx[name]));
    \\}
    \\return log.length === 0;
    \\})();
;

fn initialState() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "globalThis.ctx = document.createElement('canvas').getContext('2d'); 0;");
    try expectTrue(browser, initial_values);
    try run(browser, "globalThis.ctx = new OffscreenCanvas(4, 4).getContext('2d'); 0;");
    try expectTrue(browser, initial_values);
    try expectTrue(browser, "ctx.isContextLost() === false");
}

test "each drawing state attribute starts at its initial value" {
    try onFreshThread(initialState);
}

fn setters() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser, "globalThis.log = []; globalThis.ctx = document.createElement('canvas').getContext('2d'); 0;");
    // Zero, negative, infinite and NaN widths and limits are ignored.
    try expectTrue(browser, "for (const v of [0, -1, Infinity, NaN]) { ctx.lineWidth = v; ctx.miterLimit = v; } ctx.lineWidth === 1 && ctx.miterLimit === 10");
    try expectTrue(browser, "ctx.lineWidth = 2.5; ctx.miterLimit = 3; ctx.lineWidth === 2.5 && ctx.miterLimit === 3");
    try expectTrue(browser, "ctx.lineCap = 'round'; ctx.lineCap = 'nope'; ctx.lineJoin = 'bevel'; ctx.lineCap === 'round' && ctx.lineJoin === 'bevel'");
    // Global alpha outside 0..1, and unknown or differently cased operators.
    try expectTrue(browser, "ctx.globalAlpha = 0.5; ctx.globalAlpha = 2; ctx.globalAlpha = -0.1; ctx.globalAlpha = NaN; ctx.globalAlpha === 0.5");
    try expectTrue(browser, "ctx.globalCompositeOperation = 'multiply'; ctx.globalCompositeOperation = 'Copy'; ctx.globalCompositeOperation = 'nope'; ctx.globalCompositeOperation === 'multiply'");
    try expectTrue(browser, "ctx.globalCompositeOperation = 'xor'; ctx.globalCompositeOperation === 'xor'");
    // Shadows: non-finite offsets, negative blur, unparseable colors.
    try expectTrue(browser, "ctx.shadowOffsetX = -3; ctx.shadowOffsetX = Infinity; ctx.shadowOffsetY = NaN; ctx.shadowOffsetX === -3 && ctx.shadowOffsetY === 0");
    try expectTrue(browser, "ctx.shadowBlur = 4; ctx.shadowBlur = -1; ctx.shadowBlur === 4");
    try expectTrue(browser, "ctx.shadowColor = 'red'; ctx.shadowColor = 'not a color'; ctx.shadowColor === '#ff0000'");
    try expectTrue(browser, "ctx.shadowColor = 'rgba(0, 0, 255, 0.5)'; ctx.shadowColor === 'rgba(0, 0, 255, 0.5)'");
    // Filters: a <filter-value-list> or "none"; CSS-wide keywords and junk ignored.
    try expectTrue(browser, "ctx.filter = 'blur(2px)'; ctx.filter = 'inherit'; ctx.filter = ''; ctx.filter = 'nope'; ctx.filter === 'blur(2px)'");
    try expectTrue(browser, "ctx.filter = 'none'; ctx.filter === 'none'");
    // Fonts: computed, line-height dropped, CSS-wide keywords ignored.
    // (How a family name is quoted is the font-family serializer's, not
    // checked here.)
    try expectTrue(browser, "ctx.font = 'italic 400 12px/2 Unknown Font, sans-serif'; (ctx.font.startsWith('italic 12px ') && ctx.font.endsWith(', sans-serif') && !ctx.font.includes('/') && !ctx.font.includes('400')) || (log.push(ctx.font), false)");
    try expectTrue(browser, "const f = ctx.font; ctx.font = 'inherit'; ctx.font = 'not a font'; ctx.font === f");
    try expectTrue(browser, "ctx.font = 'bold 2em serif'; ctx.font.endsWith(' 20px serif') || (log.push(ctx.font), false)");
    // Keyword attributes and the language.
    try expectTrue(browser, "ctx.textAlign = 'center'; ctx.textAlign = 'middle'; ctx.textAlign === 'center'");
    try expectTrue(browser, "ctx.textBaseline = 'top'; ctx.direction = 'rtl'; ctx.fontKerning = 'none'; ctx.fontStretch = 'condensed'; ctx.fontVariantCaps = 'small-caps'; ctx.textRendering = 'optimizeSpeed'; [ctx.textBaseline, ctx.direction, ctx.fontKerning, ctx.fontStretch, ctx.fontVariantCaps, ctx.textRendering].join() === 'top,rtl,none,condensed,small-caps,optimizeSpeed'");
    try expectTrue(browser, "ctx.lang = 'fr-CA'; ctx.lang === 'fr-CA'");
    // Spacing: a CSS <length>; percentages and junk ignored.
    try expectTrue(browser, "ctx.letterSpacing = '3px'; ctx.letterSpacing = '10%'; ctx.letterSpacing = 'nope'; ctx.wordSpacing = '-1em'; ctx.letterSpacing === '3px' && ctx.wordSpacing === '-1em'");
    try expectTrue(browser, "ctx.imageSmoothingEnabled = false; ctx.imageSmoothingQuality = 'high'; ctx.imageSmoothingEnabled === false && ctx.imageSmoothingQuality === 'high'");
}

test "the setters change the state and ignore what the spec says to ignore" {
    try onFreshThread(setters);
}

fn saveRestoreReset() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.canvas = document.createElement('canvas');
        \\canvas.width = 2; canvas.height = 1;
        \\globalThis.ctx = canvas.getContext('2d');
        \\ctx.lineWidth = 5; ctx.fillStyle = 'red'; ctx.font = 'bold 12px serif'; ctx.setLineDash([1, 2]);
        \\globalThis.savedFont = ctx.font;
        \\ctx.save();
        \\ctx.lineWidth = 7; ctx.fillStyle = 'blue'; ctx.font = '20px monospace'; ctx.setLineDash([]); ctx.globalAlpha = 0.25;
        \\0;
    );
    try expectTrue(browser, "ctx.restore(); ctx.lineWidth === 5 && ctx.fillStyle === '#ff0000' && ctx.font === savedFont && ctx.font !== '20px monospace' && ctx.getLineDash().join() === '1,2' && ctx.globalAlpha === 1");
    // Nothing saved: restore() does nothing.
    try expectTrue(browser, "ctx.restore(); ctx.lineWidth === 5");
    // Two levels.
    try expectTrue(browser, "ctx.save(); ctx.lineWidth = 8; ctx.save(); ctx.lineWidth = 9; ctx.restore(); const a = ctx.lineWidth; ctx.restore(); a === 8 && ctx.lineWidth === 5");
    // reset(): the bitmap cleared, the stack emptied, every value initial.
    try run(browser, "ctx.fillRect(0, 0, 2, 1); ctx.save(); ctx.lineWidth = 3; ctx.reset(); 0;");
    try expectTrue(browser, "Array.from(ctx.getImageData(0, 0, 2, 1).data).every(v => v === 0)");
    try expectTrue(browser, "ctx.lineWidth === 1 && ctx.fillStyle === '#000000' && ctx.font === '10px sans-serif' && ctx.getLineDash().length === 0");
    try expectTrue(browser, "ctx.restore(); ctx.lineWidth === 1");
    // Resizing resets the state too (set bitmap dimensions step 1).
    try expectTrue(browser, "ctx.lineWidth = 4; ctx.save(); canvas.width = 3; ctx.restore(); ctx.lineWidth === 1");
}

test "save() and restore() take the whole drawing state; reset() clears it" {
    try onFreshThread(saveRestoreReset);
}

fn painting() !void {
    const browser = try open();
    defer browser.deinit();
    try run(browser,
        \\globalThis.ctx = (() => { const c = document.createElement('canvas'); c.width = 8; c.height = 8; return c.getContext('2d'); })();
        \\ctx.globalAlpha = 0.5; ctx.fillStyle = '#000';
        \\ctx.fillRect(0, 0, 1, 1);
        \\ctx.globalAlpha = 1; ctx.lineWidth = 2; ctx.strokeStyle = '#000';
        \\ctx.strokeRect(3, 3, 3, 3);
        \\0;
    );
    // Global alpha scales a fill's alpha.
    try expectTrue(browser, "ctx.getImageData(0, 0, 1, 1).data[3] === 128");
    // A 2-wide stroke of (3,3)-(6,6) covers (2,2)-(7,7) less (4,4)-(5,5).
    try expectTrue(browser, "ctx.getImageData(2, 2, 1, 1).data[3] === 255 && ctx.getImageData(4, 4, 1, 1).data[3] === 0 && ctx.getImageData(1, 1, 1, 1).data[3] === 0");
}

test "painting reads global alpha and the line width" {
    try onFreshThread(painting);
}

//! The Console Standard's Formatter and Printer (https://console.spec.whatwg.org/
//! 2.2.1 and 2.2.3): what `console.log` and its siblings print, and what the
//! browser console (tools/repl.zig) prints for an expression's result and for
//! an uncaught exception - ONE printer, so a value looks the same whichever
//! printed it.
//!
//! It writes to a writer the caller gives: the console namespace's impl hands
//! it stderr's, the console its stdout's, a test a buffer.
//!
//! The Printer's output is implementation-defined ("optimally useful
//! formatting", "generic JavaScript object formatting"). This one prints the
//! text forms Chrome DevTools and Node's console share:
//!
//!   undefined  null  true  42  -0  NaN  1n  Symbol()
//!   'a string' (quoted inside a value, and as a console result; a string
//!   argument of console.log itself is printed as it is)
//!   [1, 'a', [2]]  [<2 empty items>, 3]  [1, 2, ... 99900 more items]
//!   {a: 1, 'b-c': 2}  Foo {x: 1}  [Object: null prototype] {}
//!   Map(1) {'k' => 1}  Set(2) {1, 2}  Uint8Array(3) [1, 2, 3]
//!   [Function: f]  Promise {}  <div id="a"></div>  #text 'hi'  #document
//!   an Error as its stack (V8: "Error: boom\n    at ...")
//!
//! Nested values are printed two levels deep ([Object], [Array] past that),
//! at most 100 items each, and a value that contains itself prints
//! [Circular]. Everything is read through the engine protocol, so a getter or
//! a Proxy trap can run while a value is printed (Chrome's console reads
//! previews without running them; the protocol has no own-property
//! descriptor read): what one throws is caught and printed as
//! [Exception: ...], and never reaches the script that logged.
//!
//! Known gaps, each an engine operation the protocol does not have yet: a
//! Symbol's description (SymbolDescriptiveString: ToString throws for a
//! Symbol) - a symbol prints as `Symbol()`; a promise's [[PromiseState]] -
//! a promise prints as `Promise {}`.

const std = @import("std");
const engine = @import("engine");

const Writer = std.Io.Writer;
const Allocator = std.mem.Allocator;
const JSValue = engine.JSValue;
const Context = engine.Context;

/// How deep nested values are printed: a value nested deeper than this is
/// abbreviated ([Array], [Object]), as Node's util.inspect's default depth.
pub const max_depth: usize = 2;
/// How many items (array elements, properties, entries) a value prints.
pub const max_items: usize = 100;
/// How many bytes of an element's markup are printed.
pub const max_markup: usize = 300;
/// How many of an array's indices are looked at, holes included.
pub const max_scan: usize = 10_000;

/// Logger(logLevel, args) (2.1.1): Formatter(args) when there is more than
/// one argument and the first is a string, then the Printer: the results
/// separated by spaces, on one line - more, when a value prints on several -
/// each indented by `group_depth` levels (2.2.3: "the group stack's size"),
/// ending in a newline. Never fails for what script does; only the writer's
/// own failure is returned.
pub fn printLogged(allocator: Allocator, realm: Context, args: []const JSValue, group_depth: usize, out: *Writer) Writer.Error!void {
    var line: Writer.Allocating = .init(allocator);
    defer line.deinit();
    formatLogged(allocator, realm, args, &line.writer) catch return error.WriteFailed;
    try writeIndented(out, line.written(), group_depth);
}

/// Printer(logLevel, args) (2.3) alone, with no Formatter - timeLog's and
/// dir's: each value printed (a string argument as it is), separated by
/// spaces, indented by `group_depth` levels, ending in a newline.
pub fn printValues(allocator: Allocator, realm: Context, args: []const JSValue, group_depth: usize, out: *Writer) Writer.Error!void {
    var line: Writer.Allocating = .init(allocator);
    defer line.deinit();
    var printer: Printer = .{ .allocator = allocator, .realm = realm, .out = &line.writer, .strings_raw = true };
    defer printer.deinit();
    for (args, 0..) |arg, i| {
        if (i > 0) line.writer.writeByte(' ') catch return error.WriteFailed;
        printer.value(arg, 0) catch return error.WriteFailed;
    }
    try writeIndented(out, line.written(), group_depth);
}

/// A console result: what the browser console prints for the value an
/// evaluation completed with - the value inspected (a string quoted), then a
/// newline.
pub fn printResult(allocator: Allocator, realm: Context, value: JSValue, out: *Writer) Writer.Error!void {
    var line: Writer.Allocating = .init(allocator);
    defer line.deinit();
    var printer: Printer = .{ .allocator = allocator, .realm = realm, .out = &line.writer };
    defer printer.deinit();
    printer.value(value, 0) catch return error.WriteFailed;
    try writeIndented(out, line.written(), 0);
}

/// What a console prints for an uncaught exception - an evaluation that
/// threw, or a promise it awaited that rejected: "Uncaught ", then the value
/// inspected (an Error as its stack), then a newline. Chrome DevTools and
/// Node print `Uncaught Error: boom` and `Uncaught 1` alike.
pub fn printUncaught(allocator: Allocator, realm: Context, value: JSValue, out: *Writer) Writer.Error!void {
    var line: Writer.Allocating = .init(allocator);
    defer line.deinit();
    line.writer.writeAll("Uncaught ") catch return error.WriteFailed;
    var printer: Printer = .{ .allocator = allocator, .realm = realm, .out = &line.writer };
    defer printer.deinit();
    printer.value(value, 0) catch return error.WriteFailed;
    try writeIndented(out, line.written(), 0);
}

/// `text`, every line of it indented by `group_depth` levels of two spaces,
/// ending in a newline.
fn writeIndented(out: *Writer, text: []const u8, group_depth: usize) Writer.Error!void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        try out.splatByteAll(' ', group_depth * 2);
        try out.writeAll(line);
        try out.writeByte('\n');
    }
}

const FormatError = Writer.Error || Allocator.Error;

/// Logger step 3 and the Printer, for `args`, into `out` (unindented).
fn formatLogged(allocator: Allocator, realm: Context, args: []const JSValue, out: *Writer) FormatError!void {
    var printer: Printer = .{ .allocator = allocator, .realm = realm, .out = out, .strings_raw = true };
    defer printer.deinit();
    if (args.len == 0) return;
    var rest = args;
    // Logger step 3: "If rest is empty, perform Printer(logLevel, « first »)
    // and return. Otherwise, perform Printer(logLevel, Formatter(args))."
    if (args.len > 1) {
        if (stringOf(args[0])) |target| {
            rest = try formatter(&printer, target, args[1..]);
        } else |_| {}
    } else {
        try printer.value(args[0], 0);
        return;
    }
    for (rest, 0..) |arg, i| {
        if (i > 0 or rest.len != args.len) try out.writeByte(' ');
        try printer.value(arg, 0);
    }
}

/// A string argument's text, or an error for any other value.
fn stringOf(value: JSValue) error{NotString}![]const u8 {
    return switch (value) {
        .string => |s| s.data,
        else => error.NotString,
    };
}

/// Formatter(args) (2.2.1), with `target` the first argument and `args` the
/// rest: the format specifiers in `target` replaced, left to right, by the
/// arguments they consume, written to the printer's writer. Returns the
/// arguments no specifier consumed, for the Printer.
///
/// The spec re-runs Formatter on its own result, so a converted value that
/// itself contains a specifier would be expanded again (`console.log("%s",
/// "%d", 1)`). The browsers scan the target once, left to right, and never
/// expand what a specifier produced: Chrome DevTools
/// (front_end/core/platform/string-utilities.ts, formatWithSubstitutionString)
/// and Firefox (devtools/server/actors/webconsole/utils formatting) both
/// tokenize the format string first. Golden rule 2: the browsers.
fn formatter(printer: *Printer, target: []const u8, args: []const JSValue) FormatError![]const JSValue {
    const out = printer.out;
    var rest = args;
    var i: usize = 0;
    var literal_start: usize = 0;
    while (i < target.len) {
        if (target[i] != '%' or i + 1 >= target.len or rest.len == 0) {
            i += 1;
            continue;
        }
        const specifier = target[i + 1];
        switch (specifier) {
            's', 'd', 'i', 'f', 'o', 'O', 'c' => {},
            else => {
                i += 1;
                continue;
            },
        }
        try out.writeAll(target[literal_start..i]);
        const current = rest[0];
        rest = rest[1..];
        switch (specifier) {
            // "%s: Let converted be the result of Call(%String%, undefined,
            // « current »)."
            's' => try printer.string(current),
            // "%d or %i: If Type(current) is Symbol, let converted be NaN.
            // Otherwise, let converted be the result of Call(%parseInt%,
            // undefined, « current, 10 »)."
            'd', 'i' => try printer.number(if (printer.isSymbol(current)) std.math.nan(f64) else parseInt(try printer.converted(current))),
            // "%f: If Type(current) is Symbol, let converted be NaN.
            // Otherwise, let converted be the result of Call(%parseFloat%,
            // undefined, « current »)."
            'f' => try printer.number(if (printer.isSymbol(current)) std.math.nan(f64) else parseFloat(try printer.converted(current))),
            // "%o: Optionally let converted be current with optimally useful
            // formatting applied. %O: ... generic JavaScript object
            // formatting applied."
            'o', 'O' => try printer.value(current, 0),
            // "%c: Optionally, let converted be current with CSS styles
            // applied" - there is nothing to style: it consumes its argument
            // and prints nothing.
            'c' => {},
            else => unreachable,
        }
        i += 2;
        literal_start = i;
    }
    try out.writeAll(target[literal_start..]);
    return rest;
}

/// ECMAScript parseInt(string, 10) (19.2.5) over `text`, the argument
/// already ToString'd (step 1).
fn parseInt(text: []const u8) f64 {
    // 2. Let S be ! TrimString(inputString, start).
    var s = trimStart(text);
    // 3-5. The sign.
    var sign: f64 = 1;
    if (s.len > 0 and (s[0] == '-' or s[0] == '+')) {
        if (s[0] == '-') sign = -1;
        s = s[1..];
    }
    // 11-12. The longest prefix of radix-10 digits; none is NaN.
    var end: usize = 0;
    while (end < s.len and std.ascii.isDigit(s[end])) end += 1;
    if (end == 0) return std.math.nan(f64);
    // 14-16. Its mathematical value (the parse rounds, as the spec allows
    // past 20 significant digits).
    const magnitude = std.fmt.parseFloat(f64, s[0..end]) catch return std.math.nan(f64);
    return sign * magnitude;
}

/// ECMAScript parseFloat(string) (19.2.4) over `text`, the argument already
/// ToString'd (step 1).
fn parseFloat(text: []const u8) f64 {
    // 2. Let trimmedString be ! TrimString(inputString, start).
    const s = trimStart(text);
    // 4-5. The longest prefix that is a StrDecimalLiteral; none is NaN.
    var at: usize = 0;
    var negative = false;
    if (at < s.len and (s[at] == '-' or s[at] == '+')) {
        negative = s[at] == '-';
        at += 1;
    }
    if (std.mem.startsWith(u8, s[at..], "Infinity")) return if (negative) -std.math.inf(f64) else std.math.inf(f64);
    const int_start = at;
    while (at < s.len and std.ascii.isDigit(s[at])) at += 1;
    const int_digits = s[int_start..at];
    var fraction_digits: []const u8 = "";
    if (at < s.len and s[at] == '.') {
        const fraction_start = at + 1;
        var fraction_end = fraction_start;
        while (fraction_end < s.len and std.ascii.isDigit(s[fraction_end])) fraction_end += 1;
        fraction_digits = s[fraction_start..fraction_end];
        if (int_digits.len + fraction_digits.len > 0) at = fraction_end;
    }
    if (int_digits.len + fraction_digits.len == 0) return std.math.nan(f64);
    var exponent: []const u8 = "";
    if (at < s.len and (s[at] == 'e' or s[at] == 'E')) {
        var exponent_end = at + 1;
        if (exponent_end < s.len and (s[exponent_end] == '-' or s[exponent_end] == '+')) exponent_end += 1;
        const exponent_digits = exponent_end;
        while (exponent_end < s.len and std.ascii.isDigit(s[exponent_end])) exponent_end += 1;
        if (exponent_end > exponent_digits) exponent = s[at..exponent_end];
    }
    // As one literal std.fmt.parseFloat reads: digits on both sides of the
    // point.
    var buffer: [512]u8 = undefined;
    const literal = std.fmt.bufPrint(&buffer, "{s}{s}.{s}{s}", .{
        if (int_digits.len == 0) "0" else int_digits,
        "",
        if (fraction_digits.len == 0) "0" else fraction_digits,
        exponent,
    }) catch return std.math.nan(f64);
    const magnitude = std.fmt.parseFloat(f64, literal) catch return std.math.nan(f64);
    return if (negative) -magnitude else magnitude;
}

/// TrimString(s, start) for ASCII and the Latin-1 white space and line
/// terminators of ECMAScript's WhiteSpace and LineTerminator, in UTF-8.
fn trimStart(text: []const u8) []const u8 {
    var s = text;
    while (s.len > 0) {
        if (std.mem.indexOfScalar(u8, " \t\n\r\x0b\x0c", s[0]) != null) {
            s = s[1..];
        } else if (std.mem.startsWith(u8, s, "\u{a0}") or std.mem.startsWith(u8, s, "\u{feff}") or
            std.mem.startsWith(u8, s, "\u{2028}") or std.mem.startsWith(u8, s, "\u{2029}"))
        {
            s = s[std.unicode.utf8ByteSequenceLength(s[0]) catch 1 ..];
        } else break;
    }
    return s;
}

/// One value's text: the Printer's "generic JavaScript object formatting".
const Printer = struct {
    allocator: Allocator,
    realm: Context,
    out: *Writer,
    /// A string printed at the top level is printed as it is (console.log's
    /// arguments); otherwise quoted (inside a value, and a console result).
    strings_raw: bool = false,
    /// The objects being printed, outermost first: a value that is one of
    /// them prints [Circular].
    stack: [max_depth + 2]JSValue = undefined,
    stack_len: usize = 0,
    /// The text `converted` returned last.
    last_converted: ?[]u8 = null,

    fn value(self: *Printer, v: JSValue, depth: usize) FormatError!void {
        switch (engine.typeOf(self.realm, v)) {
            .undefined => try self.out.writeAll("undefined"),
            .null => try self.out.writeAll("null"),
            .boolean => try self.out.writeAll(if (engine.toBoolean(self.realm, v)) "true" else "false"),
            .number => try self.number(self.numberOf(v) orelse std.math.nan(f64)),
            .string => {
                const text = try self.toStringAlloc(v);
                defer self.allocator.free(text);
                if (self.strings_raw and depth == 0) try self.out.writeAll(text) else try quoted(self.out, text);
            },
            .bigint => {
                const digits = try self.toStringAlloc(v);
                defer self.allocator.free(digits);
                try self.out.print("{s}n", .{digits});
            },
            .symbol => try self.out.writeAll("Symbol()"),
            .object => try self.object(v, depth),
        }
    }

    /// %s: String(current) - a Symbol's descriptive string, any other value's
    /// ToString.
    fn string(self: *Printer, v: JSValue) FormatError!void {
        if (self.isSymbol(v)) return self.out.writeAll("Symbol()");
        const text = try self.toStringAlloc(v);
        defer self.allocator.free(text);
        try self.out.writeAll(text);
    }

    fn isSymbol(self: *Printer, v: JSValue) bool {
        return engine.typeOf(self.realm, v) == .symbol;
    }

    /// ToString(v), caught: a throw gives "[Exception]". OWNED by the
    /// printer's allocator.
    fn toStringAlloc(self: *Printer, v: JSValue) FormatError![]u8 {
        switch (v) {
            .string => |s| return self.allocator.dupe(u8, s.data),
            else => {},
        }
        var call: ToString = .{ .realm = self.realm, .value = v, .allocator = self.allocator };
        const thrown = engine.completionOf(self.realm, ToString.run, &call) catch |err| {
            if (call.result) |r| self.allocator.free(r);
            if (err == error.OutOfMemory) return error.OutOfMemory;
            return self.allocator.dupe(u8, "[Exception]");
        };
        if (thrown) |t| {
            t.release();
            if (call.result) |r| self.allocator.free(r);
            return self.allocator.dupe(u8, "[Exception]");
        }
        return call.result orelse try self.allocator.dupe(u8, "");
    }

    const ToString = struct {
        realm: Context,
        value: JSValue,
        allocator: Allocator,
        result: ?[]u8 = null,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *ToString = @ptrCast(@alignCast(data.?));
            self.result = try engine.convertToDOMString(self.realm, self.value, self.allocator);
        }
    };

    /// ToString(v) for %d, %i and %f, kept until the printer's next call
    /// (`last_converted`).
    fn converted(self: *Printer, v: JSValue) FormatError![]const u8 {
        if (self.last_converted) |text| self.allocator.free(text);
        self.last_converted = null;
        const text = try self.toStringAlloc(v);
        self.last_converted = text;
        return text;
    }

    fn deinit(self: *Printer) void {
        if (self.last_converted) |text| self.allocator.free(text);
        self.last_converted = null;
    }

    /// A Number as ECMAScript's Number::toString prints it - but -0 as -0,
    /// as the consoles do.
    fn number(self: *Printer, n: f64) FormatError!void {
        if (n == 0 and std.math.signbit(n)) return self.out.writeAll("-0");
        const text = engine.convertToDOMString(self.realm, .{ .number = n }, self.allocator) catch {
            return self.out.print("{d}", .{n});
        };
        defer self.allocator.free(text);
        try self.out.writeAll(text);
    }

    fn object(self: *Printer, v: JSValue, depth: usize) FormatError!void {
        for (self.stack[0..self.stack_len]) |outer| {
            if (engine.sameValue(self.realm, outer, v)) return self.out.writeAll("[Circular]");
        }
        if (self.stack_len == self.stack.len) return self.out.writeAll("[Object]");
        self.stack[self.stack_len] = v;
        self.stack_len += 1;
        defer self.stack_len -= 1;

        if (engine.isCallable(self.realm, v)) return self.function(v);
        if (engine.convertToPlatformObject(self.realm, v) != null) {
            if (try self.node(v)) return;
        }
        if (engine.thisTimeValue(self.realm, v) != null) {
            const text = try self.toStringAlloc(v);
            defer self.allocator.free(text);
            return self.out.writeAll(text);
        }
        if (try self.errorText(v)) return;
        if (engine.describeArrayBufferView(self.realm, v)) |view| {
            const name = try self.constructorName(v);
            defer if (name) |n| self.allocator.free(n);
            return self.elements(v, name orelse @tagName(view.view_type), depth, true);
        }
        if (engine.isArrayExoticObject(self.realm, v)) return self.elements(v, null, depth, false);

        const name = try self.constructorName(v);
        defer if (name) |n| self.allocator.free(n);
        if (name) |n| {
            if (std.mem.eql(u8, n, "Map") or std.mem.eql(u8, n, "Set")) {
                if (try self.collection(v, n, depth)) return;
            }
        }
        try self.properties(v, name, depth);
    }

    /// [Function: name], or [Function (anonymous)].
    fn function(self: *Printer, v: JSValue) FormatError!void {
        const name = try self.stringProperty(v, "name");
        defer if (name) |n| self.allocator.free(n);
        if (name) |n| if (n.len > 0) return self.out.print("[Function: {s}]", .{n});
        try self.out.writeAll("[Function (anonymous)]");
    }

    /// A DOM node as the consoles show one: an element as its markup (cut at
    /// `max_markup` bytes), a text node or comment as its data, a document as
    /// #document. False for a platform object that is no node.
    fn node(self: *Printer, v: JSValue) FormatError!bool {
        const node_type = (try self.property(v, "nodeType")) orelse return false;
        defer node_type.release();
        const kind = self.numberOf(node_type.value) orelse return false;
        switch (@as(i64, @intFromFloat(if (kind >= 0 and kind <= 64) @trunc(kind) else 0))) {
            // ELEMENT_NODE
            1 => {
                const markup = (try self.stringProperty(v, "outerHTML")) orelse return false;
                defer self.allocator.free(markup);
                if (markup.len <= max_markup) {
                    try self.out.writeAll(markup);
                } else {
                    var cut = max_markup;
                    while (cut > 0 and (markup[cut] & 0xC0) == 0x80) cut -= 1;
                    try self.out.print("{s}…", .{markup[0..cut]});
                }
            },
            // TEXT_NODE, CDATA_SECTION_NODE
            3, 4 => {
                const data = (try self.stringProperty(v, "data")) orelse return false;
                defer self.allocator.free(data);
                try self.out.writeAll("#text ");
                try quoted(self.out, data);
            },
            // COMMENT_NODE
            8 => {
                const data = (try self.stringProperty(v, "data")) orelse return false;
                defer self.allocator.free(data);
                try self.out.print("<!--{s}-->", .{data});
            },
            // DOCUMENT_NODE
            9 => try self.out.writeAll("#document"),
            else => {
                const name = (try self.stringProperty(v, "nodeName")) orelse return false;
                defer self.allocator.free(name);
                try self.out.writeAll(name);
            },
        }
        return true;
    }

    /// An Error (or a DOMException) as the consoles print one: its stack
    /// when that is a string - V8's (Chrome's and Node's consoles print it),
    /// "Error: boom\n    at ..." - else "name: message". False for any
    /// other object.
    fn errorText(self: *Printer, v: JSValue) FormatError!bool {
        const name = try self.constructorName(v);
        defer if (name) |n| self.allocator.free(n);
        const n = name orelse return false;
        if (!std.mem.endsWith(u8, n, "Error") and !std.mem.eql(u8, n, "DOMException")) return false;
        if (try self.stringProperty(v, "stack")) |stack| {
            defer self.allocator.free(stack);
            try self.out.writeAll(stack);
            return true;
        }
        const error_name = try self.stringProperty(v, "name");
        defer if (error_name) |e| self.allocator.free(e);
        const message = try self.stringProperty(v, "message");
        defer if (message) |m| self.allocator.free(m);
        try self.out.writeAll(error_name orelse n);
        if (message) |m| if (m.len > 0) try self.out.print(": {s}", .{m});
        return true;
    }

    /// An array's or a typed array's elements: `[1, 2]`, a typed array's
    /// prefixed with its name and length - holes as `<n empty items>`, at
    /// most `max_items`, nested ones past `max_depth` as [Array].
    fn elements(self: *Printer, v: JSValue, name: ?[]const u8, depth: usize, typed: bool) FormatError!void {
        const length = try self.lengthOf(v);
        if (name) |n| try self.out.print("{s}({d}) ", .{ n, length });
        if (depth > max_depth) return self.out.writeAll(if (typed) "[...]" else "[Array]");
        try self.out.writeByte('[');
        var printed: usize = 0;
        var index: usize = 0;
        var holes: usize = 0;
        // A sparse array is scanned at most `max_scan` indices: its holes are
        // counted one by one.
        const scan_end = @min(length, max_scan);
        while (index < scan_end and printed < max_items) : (index += 1) {
            var key_buffer: [24]u8 = undefined;
            const key = std.fmt.bufPrint(&key_buffer, "{d}", .{index}) catch unreachable;
            if (!typed and !(try self.hasOwn(v, key))) {
                holes += 1;
                continue;
            }
            if (holes > 0) {
                try self.separator(printed);
                try self.emptyItems(holes);
                printed += 1;
                holes = 0;
            }
            try self.separator(printed);
            try self.item(v, key, depth);
            printed += 1;
        }
        if (holes > 0) {
            try self.separator(printed);
            try self.emptyItems(holes);
        }
        if (index < length) {
            try self.separator(1);
            try self.out.print("... {d} more item{s}", .{ length - index, if (length - index == 1) "" else "s" });
        }
        try self.out.writeByte(']');
    }

    fn emptyItems(self: *Printer, count: usize) FormatError!void {
        try self.out.print("<{d} empty item{s}>", .{ count, if (count == 1) "" else "s" });
    }

    fn separator(self: *Printer, printed: usize) FormatError!void {
        if (printed > 0) try self.out.writeAll(", ");
    }

    /// The value of `v[key]`, printed one level down.
    fn item(self: *Printer, v: JSValue, key: []const u8, depth: usize) FormatError!void {
        const got = self.get(v, key) catch |err| return self.exception(err);
        defer got.release();
        try self.value(got.value, depth + 1);
    }

    /// A Map's or Set's entries: `Map(1) {'k' => 1}`. False when it does not
    /// iterate as one.
    fn collection(self: *Printer, v: JSValue, name: []const u8, depth: usize) FormatError!bool {
        const size = try self.lengthProperty(v, "size");
        try self.out.print("{s}({d}) ", .{ name, size });
        if (depth > max_depth) {
            try self.out.writeAll("{...}");
            return true;
        }
        try self.out.writeByte('{');
        var each: Each = .{ .printer = self, .depth = depth, .map = std.mem.eql(u8, name, "Map") };
        var call: Iterate = .{ .realm = self.realm, .value = v, .each = &each };
        const thrown = engine.completionOf(self.realm, Iterate.run, &call) catch |err| switch (err) {
            // Each.step's way of stopping at max_items, or after the writer
            // failed (`each.failed`).
            error.OperationFailed => null,
            error.OutOfMemory => return error.OutOfMemory,
            else => blk: {
                try self.separator(each.printed);
                try self.out.writeAll("[?]");
                break :blk null;
            },
        };
        if (each.failed) |err| return err;
        if (thrown) |t| {
            t.release();
            try self.separator(each.printed);
            try self.out.writeAll("[Exception]");
        }
        if (each.printed >= max_items and size > max_items) {
            try self.separator(1);
            try self.out.print("... {d} more", .{size - max_items});
        }
        try self.out.writeByte('}');
        return true;
    }

    const Iterate = struct {
        realm: Context,
        value: JSValue,
        each: *Each,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *Iterate = @ptrCast(@alignCast(data.?));
            _ = try engine.iterate(self.realm, self.value, Each.step, self.each);
        }
    };

    const Each = struct {
        printer: *Printer,
        depth: usize,
        map: bool,
        printed: usize = 0,
        /// The writer failed: what to return once the iteration stopped.
        failed: ?FormatError = null,

        fn step(data: ?*anyopaque, entry: JSValue) engine.Error!void {
            const self: *Each = @ptrCast(@alignCast(data.?));
            if (self.printed >= max_items) return error.OperationFailed;
            self.write(entry) catch |err| {
                self.failed = err;
                return error.OperationFailed;
            };
            self.printed += 1;
        }

        fn write(self: *Each, entry: JSValue) FormatError!void {
            const p = self.printer;
            try p.separator(self.printed);
            if (!self.map) return p.value(entry, self.depth + 1);
            // A Map's iterator yields [key, value] arrays.
            try p.item(entry, "0", self.depth);
            try p.out.writeAll(" => ");
            try p.item(entry, "1", self.depth);
        }
    };

    /// An ordinary object's own enumerable string-keyed properties:
    /// `Foo {a: 1}` (no prefix for a plain Object).
    fn properties(self: *Printer, v: JSValue, name: ?[]const u8, depth: usize) FormatError!void {
        if (name) |n| {
            if (!std.mem.eql(u8, n, "Object")) try self.out.print("{s} ", .{n});
        } else try self.out.writeAll("[Object: null prototype] ");
        if (depth > max_depth) return self.out.writeAll(if (name == null or std.mem.eql(u8, name.?, "Object")) "[Object]" else "{...}");
        var keys_call: Keys = .{ .realm = self.realm, .value = v, .allocator = self.allocator };
        const thrown = engine.completionOf(self.realm, Keys.run, &keys_call) catch |err| {
            if (keys_call.keys) |keys| freeKeys(self.allocator, keys);
            if (err == error.OutOfMemory) return error.OutOfMemory;
            return self.out.writeAll("{[?]}");
        };
        if (thrown) |t| {
            t.release();
            if (keys_call.keys) |keys| freeKeys(self.allocator, keys);
            return self.out.writeAll("{[Exception]}");
        }
        const keys = keys_call.keys orelse return self.out.writeAll("{}");
        defer freeKeys(self.allocator, keys);
        if (keys.len == 0) return self.out.writeAll("{}");
        try self.out.writeByte('{');
        for (keys, 0..) |key, i| {
            if (i == max_items) {
                try self.out.print(", ... {d} more", .{keys.len - max_items});
                break;
            }
            try self.separator(i);
            if (isIdentifier(key)) try self.out.writeAll(key) else try quoted(self.out, key);
            try self.out.writeAll(": ");
            try self.item(v, key, depth);
        }
        try self.out.writeByte('}');
    }

    fn freeKeys(allocator: Allocator, keys: [][]u8) void {
        for (keys) |k| allocator.free(k);
        allocator.free(keys);
    }

    const Keys = struct {
        realm: Context,
        value: JSValue,
        allocator: Allocator,
        keys: ?[][]u8 = null,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *Keys = @ptrCast(@alignCast(data.?));
            self.keys = try engine.enumerableOwnPropertyKeys(self.realm, self.value, self.allocator);
        }
    };

    /// The name of `v`'s constructor (`v.constructor.name`), or null when it
    /// has none that is a non-empty string (an object with a null
    /// prototype). OWNED by the printer's allocator.
    fn constructorName(self: *Printer, v: JSValue) FormatError!?[]u8 {
        const constructor = (try self.property(v, "constructor")) orelse return null;
        defer constructor.release();
        if (engine.typeOf(self.realm, constructor.value) != .object) return null;
        const name = (try self.stringProperty(constructor.value, "name")) orelse return null;
        if (name.len == 0) {
            self.allocator.free(name);
            return null;
        }
        return name;
    }

    /// `v[key]` when it is a string. OWNED by the printer's allocator.
    fn stringProperty(self: *Printer, v: JSValue, key: []const u8) FormatError!?[]u8 {
        const got = (try self.property(v, key)) orelse return null;
        defer got.release();
        if (engine.typeOf(self.realm, got.value) != .string) return null;
        const text = try self.toStringAlloc(got.value);
        defer self.allocator.free(text);
        return try self.allocator.dupe(u8, text);
    }

    /// A length-like property, as a count: 0 when it is not a non-negative
    /// number.
    fn lengthProperty(self: *Printer, v: JSValue, key: []const u8) FormatError!usize {
        const got = (try self.property(v, key)) orelse return 0;
        defer got.release();
        const n = self.numberOf(got.value) orelse return 0;
        return if (std.math.isFinite(n) and n >= 0) @intFromFloat(@min(n, 9007199254740991)) else 0;
    }

    /// `v` when it is a Number (inline, or an engine value), else null.
    fn numberOf(self: *Printer, v: JSValue) ?f64 {
        return switch (v) {
            .number => |n| n,
            else => if (engine.typeOf(self.realm, v) == .number) engine.convertToUnrestrictedDouble(self.realm, v) catch null else null,
        };
    }

    fn lengthOf(self: *Printer, v: JSValue) FormatError!usize {
        return self.lengthProperty(v, "length");
    }

    /// `v[key]`, or null when reading it threw.
    fn property(self: *Printer, v: JSValue, key: []const u8) FormatError!?engine.Owned {
        return self.get(v, key) catch |err| switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => null,
        };
    }

    const GetError = Allocator.Error || error{ Threw, Failed };

    /// Get(v, key), caught: a throw is error.Threw, with nothing pending.
    fn get(self: *Printer, v: JSValue, key: []const u8) GetError!engine.Owned {
        var call: Get = .{ .realm = self.realm, .value = v, .key = key };
        const thrown = engine.completionOf(self.realm, Get.run, &call) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => error.Failed,
        };
        if (thrown) |t| {
            t.release();
            if (call.result) |r| r.release();
            return error.Threw;
        }
        return call.result orelse error.Failed;
    }

    const Get = struct {
        realm: Context,
        value: JSValue,
        key: []const u8,
        result: ?engine.Owned = null,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *Get = @ptrCast(@alignCast(data.?));
            self.result = try engine.getProperty(self.realm, self.value, self.key);
        }
    };

    /// HasOwnProperty(v, key), caught: false when it threw.
    fn hasOwn(self: *Printer, v: JSValue, key: []const u8) FormatError!bool {
        var call: HasOwn = .{ .realm = self.realm, .value = v, .key = key };
        const thrown = engine.completionOf(self.realm, HasOwn.run, &call) catch |err| return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            else => false,
        };
        if (thrown) |t| {
            t.release();
            return false;
        }
        return call.result;
    }

    const HasOwn = struct {
        realm: Context,
        value: JSValue,
        key: []const u8,
        result: bool = false,
        fn run(data: ?*anyopaque) engine.Error!void {
            const self: *HasOwn = @ptrCast(@alignCast(data.?));
            self.result = try engine.hasOwnProperty(self.realm, self.value, self.key);
        }
    };

    fn exception(self: *Printer, err: GetError) FormatError!void {
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.Threw => self.out.writeAll("[Exception]"),
            error.Failed => self.out.writeAll("[?]"),
        };
    }
};

/// `text` in single quotes, with what would break the quoting escaped:
/// the consoles' form of a string inside a value.
fn quoted(out: *Writer, text: []const u8) Writer.Error!void {
    try out.writeByte('\'');
    for (text) |c| switch (c) {
        '\'' => try out.writeAll("\\'"),
        '\\' => try out.writeAll("\\\\"),
        '\n' => try out.writeAll("\\n"),
        '\r' => try out.writeAll("\\r"),
        '\t' => try out.writeAll("\\t"),
        0...8, 0x0b, 0x0c, 0x0e...0x1f, 0x7f => try out.print("\\x{x:0>2}", .{c}),
        else => try out.writeByte(c),
    };
    try out.writeByte('\'');
}

/// Whether `key` prints bare as a property name: an IdentifierName of ASCII
/// letters, digits, `_` and `$`, not starting with a digit.
fn isIdentifier(key: []const u8) bool {
    if (key.len == 0 or std.ascii.isDigit(key[0])) return false;
    for (key) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '$') return false;
    }
    return true;
}

test "parseInt and parseFloat follow ECMAScript's prefixes" {
    try std.testing.expectEqual(@as(f64, 42), parseInt("  42px"));
    try std.testing.expectEqual(@as(f64, -7), parseInt("-7.9"));
    try std.testing.expect(std.math.isNan(parseInt("px")));
    try std.testing.expectEqual(@as(f64, 3.5), parseFloat("3.5abc"));
    try std.testing.expectEqual(@as(f64, 0.5), parseFloat(".5"));
    try std.testing.expectEqual(@as(f64, 1e3), parseFloat("1e3x"));
    try std.testing.expectEqual(@as(f64, 1), parseFloat("1e"));
    try std.testing.expect(std.math.isInf(parseFloat("-Infinity")));
    try std.testing.expect(std.math.isNan(parseFloat(".")));
}

test "a string inside a value is quoted, its quotes and controls escaped" {
    var buffer: Writer.Allocating = .init(std.testing.allocator);
    defer buffer.deinit();
    try quoted(&buffer.writer, "it's\na\x01");
    try std.testing.expectEqualStrings("'it\\'s\\na\\x01'", buffer.written());
}

test "every line of a grouped message is indented" {
    var buffer: Writer.Allocating = .init(std.testing.allocator);
    defer buffer.deinit();
    try writeIndented(&buffer.writer, "a\nb", 2);
    try std.testing.expectEqualStrings("    a\n    b\n", buffer.written());
}

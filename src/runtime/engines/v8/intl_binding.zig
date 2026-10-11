//! V8 Binding for Pure Zig Intl API
//!
//! This module wires the pure Zig internationalization library to V8,
//! creating the `Intl` global object with `DateTimeFormat` and other formatters.
//!
//! ## Design
//!
//! - Creates `Intl` namespace object on global
//! - `Intl.DateTimeFormat` is a constructor function
//! - Uses CLDR data from src/intl/cldr/embedded_data.zig for 30 locales
//! - NO global caches - each instance is independent (prevents ICU OOM bug)
//! - Each Intl object's internal slots live in a cell of its agent's
//!   (`Objects`, on the agent's record): freed when the object is collected
//!   or when the agent ends ("Native state" below)
//!
//! ## Supported Locales (Tier 1)
//!
//! en, en-GB, en-AU, en-CA, de, de-AT, de-CH, fr, fr-CA, es, es-MX,
//! it, pt, pt-PT, zh, zh-Hans, zh-Hant, ja, ko, ar, ar-SA, ar-EG,
//! ru, nl, pl, tr, vi, th, id, hi
//!
//! ## Usage
//!
//! ```javascript
//! const dtf = new Intl.DateTimeFormat('en-US', { dateStyle: 'full' });
//! console.log(dtf.format(new Date())); // "Thursday, December 12, 2024"
//! ```

const std = @import("std");
const v8 = @import("ffi.zig");
const conv = @import("conversions.zig");
const protocol_agents = @import("protocol_agents.zig");

// Import CLDR data via intl module
const intl = @import("intl");
const clock = @import("clock");
const cldr = intl.cldr;
const cldr_embedded = cldr.embedded;

// ============================================================================
// Timezone Helper
// ============================================================================

/// Get the local timezone offset in minutes from UTC
/// Uses V8's Date.prototype.getTimezoneOffset() via JavaScript evaluation
/// Returns negative offset for timezones ahead of UTC (e.g., -60 for UTC+1)
fn getLocalTimezoneOffset(isolate: *v8.Isolate, context: *v8.Context) i32 {
    // Create a Date object and get its timezone offset
    // getTimezoneOffset() returns the offset in minutes from UTC
    // For UTC-5, it returns +300 (positive). For UTC+1, it returns -60 (negative).
    // The source, the script and its result are each an owned Global.
    const script_str = v8.v8_String_NewFromUtf8(isolate, "new Date().getTimezoneOffset()", 30) orelse return 0;
    defer release(script_str);
    const script = v8.v8_Script_Compile(context, script_str) orelse return 0;
    defer release(script);
    const result = v8.v8_Script_Run(context, script) orelse return 0;
    defer release(result);
    const offset = v8.v8_Value_NumberValue(result, context);
    if (std.math.isNan(offset)) return 0;
    // getTimezoneOffset returns minutes from local to UTC
    // We need the inverse (UTC to local), so negate it
    return -@as(i32, @intFromFloat(offset));
}

// ============================================================================
// DateTime Helper (simplified from src/intl/datetime/datetime.zig)
// ============================================================================

/// Simple DateTime struct for formatting
const DateTime = struct {
    year: i32,
    month: u8, // 1-12
    day: u8, // 1-31
    hour: u8, // 0-23
    minute: u8, // 0-59
    second: u8, // 0-59
    nanosecond: u32 = 0,

    /// Create DateTime from Unix timestamp in milliseconds (UTC)
    fn fromTimestampMillis(ts: i64) DateTime {
        return fromTimestampMillisWithOffset(ts, 0);
    }

    /// Create DateTime from Unix timestamp in milliseconds with timezone offset in minutes
    fn fromTimestampMillisWithOffset(ts: i64, offset_minutes: i32) DateTime {
        // Apply timezone offset (convert UTC to local time)
        const adjusted_ts = ts + @as(i64, offset_minutes) * 60 * 1000;
        const ns = @as(i128, adjusted_ts) * std.time.ns_per_ms;
        var remaining_ns = ns;
        var year: i32 = 1970;

        // Calculate year
        if (remaining_ns >= 0) {
            while (true) {
                const days_in_year: i128 = if (isLeapYear(year)) 366 else 365;
                const ns_in_year = days_in_year * std.time.ns_per_day;
                if (remaining_ns < ns_in_year) break;
                remaining_ns -= ns_in_year;
                year += 1;
            }
        } else {
            while (remaining_ns < 0) {
                year -= 1;
                const days_in_year: i128 = if (isLeapYear(year)) 366 else 365;
                const ns_in_year = days_in_year * std.time.ns_per_day;
                remaining_ns += ns_in_year;
            }
        }

        // Calculate month
        var month: u8 = 1;
        while (month <= 12) : (month += 1) {
            const days = daysInMonth(month, year);
            const ns_in_month: i128 = @as(i128, days) * std.time.ns_per_day;
            if (remaining_ns < ns_in_month) break;
            remaining_ns -= ns_in_month;
        }

        const day: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_day) + 1);
        remaining_ns = @mod(remaining_ns, std.time.ns_per_day);

        const hour: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_hour));
        remaining_ns = @mod(remaining_ns, std.time.ns_per_hour);

        const minute: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_min));
        remaining_ns = @mod(remaining_ns, std.time.ns_per_min);

        const second: u8 = @intCast(@divFloor(remaining_ns, std.time.ns_per_s));

        return .{
            .year = year,
            .month = month,
            .day = day,
            .hour = hour,
            .minute = minute,
            .second = second,
        };
    }

    fn isLeapYear(year: i32) bool {
        if (@mod(year, 400) == 0) return true;
        if (@mod(year, 100) == 0) return false;
        return @mod(year, 4) == 0;
    }

    fn daysInMonth(month: u8, year: i32) u8 {
        const days_per_month = [_]u8{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
        if (month == 2 and isLeapYear(year)) return 29;
        return days_per_month[month - 1];
    }

    /// Get day of week (0 = Sunday, 6 = Saturday)
    fn dayOfWeek(self: DateTime) u8 {
        // Zeller's congruence (modified for 0-indexed Sunday)
        var y = self.year;
        var m = self.month;
        if (m < 3) {
            m += 12;
            y -= 1;
        }
        const q = self.day;
        const k = @mod(y, 100);
        const j = @divFloor(y, 100);

        const h_calc = @as(i32, q) + @divFloor((13 * (@as(i32, m) + 1)), 5) +
            @as(i32, @intCast(k)) + @divFloor(@as(i32, @intCast(k)), 4) +
            @divFloor(j, 4) - 2 * j;
        const h = @mod(h_calc, 7);
        // Convert from Zeller (0=Saturday) to 0=Sunday
        return @intCast(@mod(h + 6, 7));
    }
};

// ============================================================================
// DateTimeFormat Instance Storage
// ============================================================================

/// Style enums matching ECMA-402
const DateStyle = enum { full, long, medium, short };
const TimeStyle = enum { full, long, medium, short };

// ============================================================================
// Handles: what one native call owns
// ============================================================================
//
// Every `v8_*` call below that returns a pointer allocates a Global the caller
// owns - where V8's own API hands back a Local that the call's HandleScope
// frees - and so do `info.getThis()` and `info.get(i)`; `setReturnValue`,
// `v8_Object_Set` and `v8_Array_Set` copy what they are given. So each one is
// released as soon as the call is done with it. Kept, they were Globals per
// call for the life of the agent (lane callleak, gc_bench --c-alloc, V8's own
// count: +160 B per `collator.compare(a, b)`, +96 B per `numberFormat.format(k)`,
// +192 B per `dateTimeFormat.format(0)`), and the object each constructor
// returned stayed rooted by its own Global, so none was ever collected.

/// Release `handle` - a Global a `v8_*` call returned, or null - with its own
/// type's dispose.
fn release(handle: anytype) void {
    const ptr = if (@typeInfo(@TypeOf(handle)) == .optional) (handle orelse return) else handle;
    switch (@TypeOf(ptr)) {
        *v8.Context => v8.v8_Context_Dispose(ptr),
        *v8.Object => v8.v8_Object_Dispose(ptr),
        *v8.String => v8.v8_String_Dispose(ptr),
        *v8.Array => v8.v8_Array_Dispose(ptr),
        *v8.Script => v8.v8_Script_Dispose(ptr),
        *v8.Value, *v8.Number => v8.v8_Value_Dispose(@ptrCast(ptr)),
        else => @compileError("release: no dispose for " ++ @typeName(@TypeOf(ptr))),
    }
}

/// `value` - an owned Global, or null for undefined - as the call's result,
/// then released: SetReturnValue copies it.
fn returnOwned(info: *const v8.FunctionCallbackInfo, value: anytype) void {
    const ptr = if (@typeInfo(@TypeOf(value)) == .optional) (value orelse return returnUndefined(info)) else value;
    info.setReturnValue(@ptrCast(ptr));
    release(ptr);
}

/// undefined as the call's result, with no handle made for it (a null Global
/// is V8's SetUndefined).
fn returnUndefined(info: *const v8.FunctionCallbackInfo) void {
    v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnValueGlobal(info, null);
}

fn returnString(info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, s: []const u8) void {
    returnOwned(info, v8.v8_String_NewFromUtf8(isolate, s.ptr, @intCast(s.len)));
}

fn returnInteger(info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, n: i32) void {
    returnOwned(info, v8.v8_Integer_New(isolate, n));
}

fn returnBoolean(info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, b: bool) void {
    returnOwned(info, v8.v8_Boolean_New(isolate, b));
}

/// A new array of `values`, as strings, as the call's result.
fn returnStringArray(info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, context: *v8.Context, values: []const []const u8) void {
    const arr = v8.v8_Array_New(isolate, @intCast(values.len));
    for (values, 0..) |value, i| {
        setElementOwned(context, arr, @intCast(i), v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)));
    }
    returnOwned(info, arr);
}

/// `obj[key] = value`, `value` an owned Global (or null: nothing is set),
/// released here.
fn setOwned(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, key: []const u8, value: anytype) void {
    defer release(value);
    const v = if (@typeInfo(@TypeOf(value)) == .optional) (value orelse return) else value;
    const k = v8.v8_String_NewFromUtf8(isolate, key.ptr, @intCast(key.len)) orelse return;
    defer release(k);
    _ = v8.v8_Object_Set(obj, context, @ptrCast(k), @ptrCast(v));
}

/// `arr[index] = value`, `value` an owned Global (or null), released here.
fn setElementOwned(context: *v8.Context, arr: *v8.Array, index: u32, value: anytype) void {
    defer release(value);
    const v = if (@typeInfo(@TypeOf(value)) == .optional) (value orelse return) else value;
    _ = v8.v8_Array_Set(arr, context, index, @ptrCast(v));
}

fn setStringProperty(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, key: []const u8, value: []const u8) void {
    setOwned(isolate, context, obj, key, v8.v8_String_NewFromUtf8(isolate, value.ptr, @intCast(value.len)));
}

fn setNumberProperty(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, key: []const u8, value: f64) void {
    setOwned(isolate, context, obj, key, v8.v8_Number_New(isolate, value));
}

fn setBooleanProperty(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, key: []const u8, value: bool) void {
    setOwned(isolate, context, obj, key, v8.v8_Boolean_New(isolate, value));
}

/// `obj[name]`: a function of `context` running `callback`, made with
/// Function::New. A FunctionTemplate's function is cached in its context for
/// the context's life (the template instantiation cache), and each Intl
/// object had templates of its own - the DateTimeFormat's, NumberFormat's,
/// Segmenter's and Locale's with the object itself as their data - so no
/// Intl object was ever collected while its realm lived.
fn defineMethod(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, name: []const u8, callback: v8.FunctionCallback) void {
    setOwned(isolate, context, obj, name, v8.v8_Function_NewWithData(context, callback, null, 0));
}

/// `options[name]`, when it is a string: its UTF-8 in `buf` (readV8String's
/// limits), or null. `options` is borrowed; what this makes is released.
fn stringOption(isolate: *v8.Isolate, context: *v8.Context, options: *v8.Value, name: []const u8, buf: []u8) ?[]const u8 {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    defer release(key);
    const value = v8.v8_Object_Get(@ptrCast(options), context, @ptrCast(key)) orelse return null;
    defer release(value);
    if (!v8.v8_Value_IsString(value)) return null;
    return readV8String(v8.v8_Value_ToString(value, context), context, buf);
}

/// `options[name]`, when it is a boolean, or null.
fn booleanOption(isolate: *v8.Isolate, context: *v8.Context, options: *v8.Value, name: []const u8) ?bool {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    defer release(key);
    const value = v8.v8_Object_Get(@ptrCast(options), context, @ptrCast(key)) orelse return null;
    defer release(value);
    if (!v8.v8_Value_IsBoolean(value)) return null;
    return v8.v8_Value_BooleanValue(value, isolate);
}

/// `options[name]`, when it is a number, or null.
fn numberOption(isolate: *v8.Isolate, context: *v8.Context, options: *v8.Value, name: []const u8) ?f64 {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    defer release(key);
    const value = v8.v8_Object_Get(@ptrCast(options), context, @ptrCast(key)) orelse return null;
    defer release(value);
    if (!v8.v8_Value_IsNumber(value)) return null;
    return v8.v8_Value_NumberValue(value, context);
}

/// `info[index]` when it is a string: its UTF-8 in `buf`; null when it is
/// not, or when there is no such argument. Its handle is released.
fn stringArgument(info: *const v8.FunctionCallbackInfo, index: c_int, context: *v8.Context, buf: []u8) ?[]const u8 {
    if (info.length() <= index) return null;
    const arg = info.get(index);
    defer release(arg);
    if (!v8.v8_Value_IsString(arg)) return null;
    return readV8String(v8.v8_Value_ToString(arg, context), context, buf);
}

/// `info[index]` when it is an object - an options bag: an owned Global
/// (release it); null when it is not, or when there is no such argument.
fn objectArgument(info: *const v8.FunctionCallbackInfo, index: c_int) ?*v8.Value {
    if (info.length() <= index) return null;
    const arg = info.get(index);
    if (!v8.v8_Value_IsObject(arg)) {
        release(arg);
        return null;
    }
    return arg;
}

// ============================================================================
// Native state: what an Intl object's constructor resolved
// ============================================================================
//
// Each Intl object's internal slots live in a Cell: made by its constructor,
// freed when the garbage collector takes the object (a weak handle on it) or
// when its agent ends, whichever comes first. The object finds its cell
// through a private property (`state_key`) script can neither read nor set,
// which also brands it: a method called on another object finds no cell of
// its kind. Before (until lane intlleak), the state sat in nine process-wide
// registries keyed by an index stored in an ordinary property - every agent's
// on every thread, behind locks, and freed by nothing but the host agent's end:
// the weak handle was armed on the wrong value and never fired, and each entry
// took three pages (std.heap.page_allocator: the entry, its locale, the weak
// data - 48 KB per object on 16 KB pages).

/// Which constructor made an Intl object: its brand.
const Kind = enum {
    datetime_format,
    number_format,
    collator,
    plural_rules,
    relative_time_format,
    list_format,
    display_names,
    segmenter,
    locale,
};

/// An Intl object's internal slots, by the constructor that made it.
const State = union(Kind) {
    datetime_format: DateTimeFormatEntry,
    number_format: NumberFormatEntry,
    collator: CollatorEntry,
    plural_rules: PluralRulesEntry,
    relative_time_format: RelativeTimeFormatEntry,
    list_format: ListFormatEntry,
    display_names: DisplayNamesEntry,
    segmenter: SegmenterEntry,
    locale: LocaleEntry,

    fn deinit(self: *State) void {
        switch (self.*) {
            inline else => |*entry| entry.deinit(),
        }
    }
};

const Cell = struct {
    state: State,
    objects: *Objects,
    /// The weak Global on the object; its collection frees the cell
    /// (`cellCollected`). Null when it could not be armed: the agent's end
    /// frees the cell then.
    weak: ?*v8.Value = null,
    prev: ?*Cell = null,
    next: ?*Cell = null,
};

/// The private property an Intl object keeps its cell in: an External,
/// which keeps nothing alive.
const state_key = "crane.intl.state";

/// The live Intl objects' cells of one agent - one isolate (instances B2: the
/// adapter's per-isolate state is the agent's). Made by the agent's first
/// Intl construction and kept on its record (protocol_agents.intlObjectsOf);
/// freed by its end. Read and written on the agent's thread only, where V8
/// also runs its weak callbacks, so it takes no lock.
pub const Objects = struct {
    allocator: std.mem.Allocator,
    first: ?*Cell = null,
    /// Cells alive: their objects not yet collected.
    live: usize = 0,

    pub fn create(allocator: std.mem.Allocator) error{OutOfMemory}!*Objects {
        const self = try allocator.create(Objects);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// The agent's end, its isolate entered and alive: every object's state
    /// is freed, each weak arm disarmed first - so no collection after this
    /// reaches a freed cell, and no weak record is left behind.
    pub fn destroy(self: *Objects) void {
        while (self.first) |cell| {
            v8.v8_Global_Dispose(cell.weak);
            cell.weak = null;
            self.free(cell);
        }
        self.allocator.destroy(self);
    }

    /// A new cell holding `state`, alive until `free`. On failure `state`
    /// is freed.
    fn adopt(self: *Objects, state: State) error{OutOfMemory}!*Cell {
        const cell = self.allocator.create(Cell) catch |err| {
            var doomed = state;
            doomed.deinit();
            return err;
        };
        cell.* = .{ .state = state, .objects = self, .next = self.first };
        if (self.first) |first| first.prev = cell;
        self.first = cell;
        self.live += 1;
        return cell;
    }

    fn free(self: *Objects, cell: *Cell) void {
        if (cell.prev) |prev| prev.next = cell.next else self.first = cell.next;
        if (cell.next) |next| next.prev = cell.prev;
        self.live -= 1;
        cell.state.deinit();
        self.allocator.destroy(cell);
    }
};

/// The current agent's Intl objects; null for an isolate no agent made (a
/// test's own), whose Intl constructors then throw.
fn agentObjects(isolate: *v8.Isolate) ?*Objects {
    return protocol_agents.intlObjectsOf(isolate);
}

/// How many Intl objects of `isolate`'s agent are alive (not yet collected):
/// what a test reads.
pub fn liveObjectCount(isolate: *v8.Isolate) usize {
    const objects = protocol_agents.intlObjectsOf(isolate) orelse return 0;
    return objects.live;
}

/// The first-pass weak callback of an Intl object's weak handle: the object
/// is collected, so its cell goes. Bookkeeping only - no V8 API call (the
/// handle is Reset already by the wrapper; disposing deletes its Global).
fn cellCollected(data: ?*anyopaque, length_in_bytes: usize) callconv(.c) void {
    _ = length_in_bytes;
    const cell: *Cell = @ptrCast(@alignCast(data orelse return));
    v8.v8_Global_Dispose(cell.weak);
    cell.weak = null;
    cell.objects.free(cell);
}

/// `object`, just made by a constructor, takes `state`: a cell of the
/// agent's holds it, the object's private `state_key` holds the cell, and a
/// weak handle on the object frees the cell once it is collected. False -
/// a TypeError thrown, `state` freed - when there is no agent or no memory.
fn adopt(isolate: *v8.Isolate, object: *v8.Object, state: State) bool {
    const objects = agentObjects(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return false;
    };
    const cell = objects.adopt(state) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return false;
    };
    const external = v8.v8_External_New(isolate, cell) orelse {
        objects.free(cell);
        conv.throwTypeError(isolate, "Out of memory");
        return false;
    };
    defer v8.v8_External_Dispose(external);
    v8.v8_Object_SetPrivateRef(object, state_key.ptr, state_key.len, @ptrCast(external));
    // The weak handle wants a Local of the object, not our Global.
    if (v8.v8_Global_Get(isolate, @ptrCast(object))) |local| {
        cell.weak = v8.v8_Value_ToWeakGlobal(isolate, local, cell, cellCollected);
    }
    return true;
}

/// `object`'s state when `kind`'s constructor made it; null for any other
/// object. The pointer is good while `object` is alive - for the rest of a
/// call whose receiver it is.
fn stateOf(comptime kind: Kind, object: *v8.Object) ?*@FieldType(State, @tagName(kind)) {
    const held = v8.v8_Object_GetPrivateRef(object, state_key.ptr, state_key.len) orelse return null;
    defer release(held);
    // Only `adopt` writes the key (a Private, unreachable from script), and
    // always an External.
    const cell: *Cell = @ptrCast(@alignCast(v8.v8_External_Value(@ptrCast(held)) orelse return null));
    if (std.meta.activeTag(cell.state) != kind) return null;
    return &@field(cell.state, @tagName(kind));
}

/// The receiver's state when `kind`'s constructor made it; null otherwise.
fn thisState(comptime kind: Kind, info: *const v8.FunctionCallbackInfo) ?*@FieldType(State, @tagName(kind)) {
    const this_obj = info.getThis();
    defer release(this_obj);
    return stateOf(kind, this_obj);
}

// ============================================================================
// DateTimeFormat state
// ============================================================================

const DateTimeFormatEntry = struct {
    locale: []const u8,
    locale_data: ?*const cldr.LocaleData,
    date_style: ?DateStyle,
    time_style: ?TimeStyle,
    allocator: std.mem.Allocator,

    fn deinit(self: *DateTimeFormatEntry) void {
        self.allocator.free(self.locale);
    }
};

// ============================================================================
// Locale Resolution
// ============================================================================

/// Find the best matching locale from CLDR data
fn resolveLocale(locale_tag: []const u8) ?*const cldr.LocaleData {
    // Try exact match first
    if (cldr_embedded.getLocale(locale_tag)) |data| {
        return data;
    }

    // Try normalizing (replace _ with -)
    var normalized: [64]u8 = undefined;
    var norm_len: usize = 0;
    for (locale_tag) |c| {
        if (norm_len >= normalized.len) break;
        normalized[norm_len] = if (c == '_') '-' else c;
        norm_len += 1;
    }
    if (cldr_embedded.getLocale(normalized[0..norm_len])) |data| {
        return data;
    }

    // Try base language (e.g., "en-US" -> "en")
    if (std.mem.indexOf(u8, locale_tag, "-")) |idx| {
        if (cldr_embedded.getLocale(locale_tag[0..idx])) |data| {
            return data;
        }
    }

    // Default to English
    return cldr_embedded.getLocale("en");
}

// ============================================================================
// CLDR Pattern Formatting
// ============================================================================

/// Format DateTime using CLDR pattern
fn formatWithPattern(
    buf: []u8,
    pattern: []const u8,
    dt: DateTime,
    locale_data: *const cldr.LocaleData,
) []const u8 {
    var out_idx: usize = 0;
    var pat_idx: usize = 0;

    while (pat_idx < pattern.len and out_idx < buf.len - 1) {
        const c = pattern[pat_idx];

        if (c == '\'') {
            // Quoted literal
            pat_idx += 1;
            if (pat_idx < pattern.len and pattern[pat_idx] == '\'') {
                // Escaped quote ''
                if (out_idx < buf.len) {
                    buf[out_idx] = '\'';
                    out_idx += 1;
                }
                pat_idx += 1;
            } else {
                // Find closing quote
                while (pat_idx < pattern.len and out_idx < buf.len) {
                    if (pattern[pat_idx] == '\'') {
                        pat_idx += 1;
                        break;
                    }
                    buf[out_idx] = pattern[pat_idx];
                    out_idx += 1;
                    pat_idx += 1;
                }
            }
        } else if (isPatternChar(c)) {
            // Count consecutive pattern characters
            const start = pat_idx;
            while (pat_idx < pattern.len and pattern[pat_idx] == c) : (pat_idx += 1) {}
            const count = pat_idx - start;

            out_idx = formatField(buf, out_idx, c, count, dt, locale_data);
        } else {
            // Literal character
            buf[out_idx] = c;
            out_idx += 1;
            pat_idx += 1;
        }
    }

    return buf[0..out_idx];
}

fn isPatternChar(c: u8) bool {
    return switch (c) {
        'y', 'Y', 'M', 'L', 'd', 'E', 'e', 'c', 'a', 'h', 'H', 'k', 'K', 'm', 's', 'S', 'z', 'Z', 'G' => true,
        else => false,
    };
}

fn formatField(
    buf: []u8,
    start_idx: usize,
    field: u8,
    count: usize,
    dt: DateTime,
    locale_data: *const cldr.LocaleData,
) usize {
    var idx = start_idx;

    switch (field) {
        'y', 'Y' => {
            // Year
            const abs_year: u32 = @intCast(if (dt.year < 0) -dt.year else dt.year);
            if (count == 2) {
                // Two-digit year
                const yy = @mod(abs_year, 100);
                idx = writeNumber(buf, idx, yy, 2);
            } else {
                // Full year
                idx = writeNumber(buf, idx, abs_year, 4);
            }
        },
        'M', 'L' => {
            // Month
            if (count == 1) {
                idx = writeNumber(buf, idx, dt.month, 1);
            } else if (count == 2) {
                idx = writeNumber(buf, idx, dt.month, 2);
            } else if (count == 3) {
                // Abbreviated
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.abbreviated[dt.month - 1]);
                }
            } else if (count == 4) {
                // Wide
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.wide[dt.month - 1]);
                }
            } else {
                // Narrow
                if (dt.month >= 1 and dt.month <= 12) {
                    idx = writeString(buf, idx, locale_data.months.narrow[dt.month - 1]);
                }
            }
        },
        'd' => {
            // Day
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.day, 2);
            } else {
                idx = writeNumber(buf, idx, dt.day, 1);
            }
        },
        'E', 'e', 'c' => {
            // Weekday
            const dow = dt.dayOfWeek();
            if (count <= 3) {
                idx = writeString(buf, idx, locale_data.weekdays.abbreviated[dow]);
            } else if (count == 4) {
                idx = writeString(buf, idx, locale_data.weekdays.wide[dow]);
            } else if (count == 5) {
                idx = writeString(buf, idx, locale_data.weekdays.narrow[dow]);
            } else {
                idx = writeString(buf, idx, locale_data.weekdays.short[dow]);
            }
        },
        'a' => {
            // AM/PM
            if (dt.hour < 12) {
                idx = writeString(buf, idx, locale_data.day_periods.am);
            } else {
                idx = writeString(buf, idx, locale_data.day_periods.pm);
            }
        },
        'h' => {
            // Hour 1-12
            var h = dt.hour;
            if (h == 0) h = 12 else if (h > 12) h -= 12;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'H' => {
            // Hour 0-23
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.hour, 2);
            } else {
                idx = writeNumber(buf, idx, dt.hour, 1);
            }
        },
        'k' => {
            // Hour 1-24
            var h = dt.hour;
            if (h == 0) h = 24;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'K' => {
            // Hour 0-11
            const h = if (dt.hour >= 12) dt.hour - 12 else dt.hour;
            if (count >= 2) {
                idx = writeNumber(buf, idx, h, 2);
            } else {
                idx = writeNumber(buf, idx, h, 1);
            }
        },
        'm' => {
            // Minute
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.minute, 2);
            } else {
                idx = writeNumber(buf, idx, dt.minute, 1);
            }
        },
        's' => {
            // Second
            if (count >= 2) {
                idx = writeNumber(buf, idx, dt.second, 2);
            } else {
                idx = writeNumber(buf, idx, dt.second, 1);
            }
        },
        'z', 'Z' => {
            // Time zone (UTC for now)
            idx = writeString(buf, idx, "UTC");
        },
        'G' => {
            // Era
            const era_idx: usize = if (dt.year < 1) 0 else 1;
            if (count <= 3) {
                idx = writeString(buf, idx, locale_data.eras.abbreviated[era_idx]);
            } else if (count == 4) {
                idx = writeString(buf, idx, locale_data.eras.wide[era_idx]);
            } else {
                idx = writeString(buf, idx, locale_data.eras.narrow[era_idx]);
            }
        },
        else => {},
    }

    return idx;
}

fn writeNumber(buf: []u8, start: usize, value: anytype, comptime min_digits: usize) usize {
    var temp: [16]u8 = undefined;
    const slice = switch (min_digits) {
        1 => std.fmt.bufPrint(&temp, "{d}", .{value}) catch return start,
        2 => std.fmt.bufPrint(&temp, "{d:0>2}", .{value}) catch return start,
        3 => std.fmt.bufPrint(&temp, "{d:0>3}", .{value}) catch return start,
        4 => std.fmt.bufPrint(&temp, "{d:0>4}", .{value}) catch return start,
        else => std.fmt.bufPrint(&temp, "{d}", .{value}) catch return start,
    };
    return writeString(buf, start, slice);
}

fn writeString(buf: []u8, start: usize, s: []const u8) usize {
    var idx = start;
    for (s) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }
    return idx;
}

// ============================================================================
// V8 String Helpers
// ============================================================================

/// Read a V8 string into `buf`, TAKING OWNERSHIP of the handle.
///
/// Every one of the 49 call sites passes a freshly created handle - inline as
/// `readV8String(v8.v8_Value_ToString(v, ctx), ...)`, or bound on the line above -
/// and none of them released it. `v8_Value_ToString` allocates a
/// `Global<String>` where V8's own API returns a borrowed `Local`, so each call
/// leaked one.
///
/// Consuming it here rather than adding 49 `defer`s: the ownership is uniform, a
/// single point cannot drift out of sync with the call sites, and a caller that
/// wanted to keep the handle would have to stop using this helper - which is a
/// compile-visible change rather than a silent leak.
fn readV8String(str: ?*v8.String, context: *v8.Context, buf: []u8) ?[]const u8 {
    defer if (str) |s| v8.v8_String_Dispose(s);
    if (str) |s| {
        const len = v8.v8_String_Utf8Length(s);
        if (len > 0 and len < buf.len) {
            const written = v8.v8_String_WriteUtf8(s, buf.ptr, @intCast(buf.len));
            // V8's WriteUtf8 includes null terminator in count
            if (written > 1) {
                return buf[0..@intCast(written - 1)];
            } else if (written == 1) {
                return "";
            }
        }
    }
    _ = context;
    return null;
}

// ============================================================================
// DateTimeFormat Constructor Callback
// ============================================================================

/// The DateStyle or TimeStyle `name` is.
fn parseStyle(comptime Style: type, name: []const u8) ?Style {
    if (std.mem.eql(u8, name, "full")) return .full;
    if (std.mem.eql(u8, name, "long")) return .long;
    if (std.mem.eql(u8, name, "medium")) return .medium;
    if (std.mem.eql(u8, name, "short")) return .short;
    return null;
}

/// Callback for `new Intl.DateTimeFormat(locales, options)`
fn dateTimeFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var date_style: ?DateStyle = null;
    var time_style: ?TimeStyle = null;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        var ds_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "dateStyle", &ds_buf)) |ds| {
            if (parseStyle(DateStyle, ds)) |style| date_style = style;
        }
        var ts_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "timeStyle", &ts_buf)) |ts| {
            if (parseStyle(TimeStyle, ts)) |style| time_style = style;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .datetime_format = .{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .date_style = date_style,
        .time_style = time_style,
        .allocator = allocator,
    } };

    // Create the result object
    const result = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create DateTimeFormat object");
        return;
    };
    defer release(result);
    if (!adopt(isolate, result, state)) return;

    defineMethod(isolate, context, result, "format", dateTimeFormatFormatCallback);
    defineMethod(isolate, context, result, "formatToParts", dateTimeFormatToPartsCallback);
    defineMethod(isolate, context, result, "resolvedOptions", dateTimeFormatResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result));
}

/// The time value `info[0]` is - a number, or a Date by its valueOf - or now
/// when it is absent, null, undefined or NaN.
fn timestampArgument(info: *const v8.FunctionCallbackInfo, context: *v8.Context) i64 {
    if (info.length() > 0) {
        const date_arg = info.get(0);
        defer release(date_arg);
        // Use v8_Value_NumberValue which handles both numbers and Date objects
        // (Date objects implement valueOf() which returns the timestamp)
        if (!v8.v8_Value_IsNullOrUndefined(date_arg)) {
            const num_val = v8.v8_Value_NumberValue(date_arg, context);
            if (!std.math.isNan(num_val)) return @intFromFloat(num_val);
        }
    }
    return clock.wallMillis();
}

// ============================================================================
// DateTimeFormat.format() Callback
// ============================================================================

/// Callback for `dtf.format(date)`
fn dateTimeFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.datetime_format, info) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    // Get timestamp from argument (can be number or Date object)
    const timestamp_ms = timestampArgument(info, context);

    // Format using CLDR patterns with local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(timestamp_ms, tz_offset);
    var buf: [256]u8 = undefined;

    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;

    // Format based on options
    const formatted = formatDateTime(&buf, dt, locale_data, entry.date_style, entry.time_style);

    returnString(info, isolate, formatted);
}

/// Format DateTime with combined date and time styles
fn formatDateTime(
    buf: []u8,
    dt: DateTime,
    locale_data: *const cldr.LocaleData,
    date_style: ?DateStyle,
    time_style: ?TimeStyle,
) []const u8 {
    // Both date and time - need to combine using datetime pattern
    if (date_style != null and time_style != null) {
        // Get the datetime combination pattern (e.g., "{1}, {0}")
        const datetime_pattern = switch (date_style.?) {
            .full => locale_data.datetime_patterns.datetime_full,
            .long => locale_data.datetime_patterns.datetime_long,
            .medium => locale_data.datetime_patterns.datetime_medium,
            .short => locale_data.datetime_patterns.datetime_short,
        };

        // Get individual date and time patterns
        const date_pattern = getDatePattern(locale_data, date_style.?);
        const time_pattern = getTimePattern(locale_data, time_style.?);

        // Format date and time separately
        var date_buf: [128]u8 = undefined;
        var time_buf: [128]u8 = undefined;
        const date_str = formatWithPattern(&date_buf, date_pattern, dt, locale_data);
        const time_str = formatWithPattern(&time_buf, time_pattern, dt, locale_data);

        // Replace {0} with time and {1} with date in the datetime pattern
        return combineDateTimePattern(buf, datetime_pattern, date_str, time_str);
    }

    // Date only
    if (date_style) |ds| {
        const pattern = getDatePattern(locale_data, ds);
        return formatWithPattern(buf, pattern, dt, locale_data);
    }

    // Time only
    if (time_style) |ts| {
        const pattern = getTimePattern(locale_data, ts);
        return formatWithPattern(buf, pattern, dt, locale_data);
    }

    // Default date format - most locales use medium, but some prefer short (ISO format)
    // Per WPT locale-compat.html: sv-SE and en-CA should default to short (yyyy-mm-dd)
    const default_pattern = if (std.mem.eql(u8, locale_data.tag, "sv-SE") or
        std.mem.eql(u8, locale_data.tag, "en-CA"))
        locale_data.datetime_patterns.date_short
    else
        locale_data.datetime_patterns.date_medium;

    return formatWithPattern(buf, default_pattern, dt, locale_data);
}

fn getDatePattern(locale_data: *const cldr.LocaleData, style: DateStyle) []const u8 {
    return switch (style) {
        .full => locale_data.datetime_patterns.date_full,
        .long => locale_data.datetime_patterns.date_long,
        .medium => locale_data.datetime_patterns.date_medium,
        .short => locale_data.datetime_patterns.date_short,
    };
}

fn getTimePattern(locale_data: *const cldr.LocaleData, style: TimeStyle) []const u8 {
    return switch (style) {
        .full => locale_data.datetime_patterns.time_full,
        .long => locale_data.datetime_patterns.time_long,
        .medium => locale_data.datetime_patterns.time_medium,
        .short => locale_data.datetime_patterns.time_short,
    };
}

/// Combine date and time strings using a datetime pattern like "{1}, {0}"
fn combineDateTimePattern(
    buf: []u8,
    pattern: []const u8,
    date_str: []const u8,
    time_str: []const u8,
) []const u8 {
    var idx: usize = 0;
    var pat_idx: usize = 0;

    while (pat_idx < pattern.len and idx < buf.len - 1) {
        // Check for placeholders
        if (pat_idx + 2 < pattern.len and pattern[pat_idx] == '{' and pattern[pat_idx + 2] == '}') {
            const placeholder = pattern[pat_idx + 1];
            if (placeholder == '0') {
                // {0} = time
                for (time_str) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                pat_idx += 3;
                continue;
            } else if (placeholder == '1') {
                // {1} = date
                for (date_str) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                pat_idx += 3;
                continue;
            }
        }

        // Regular character
        buf[idx] = pattern[pat_idx];
        idx += 1;
        pat_idx += 1;
    }

    return buf[0..idx];
}

// ============================================================================
// DateTimeFormat.formatToParts() Callback
// ============================================================================

/// Callback for `dtf.formatToParts(date)`
fn dateTimeFormatToPartsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.datetime_format, info) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    // Get timestamp from argument (can be number or Date object)
    const timestamp_ms = timestampArgument(info, context);

    // Convert to local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(timestamp_ms, tz_offset);
    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;

    // Create parts array
    // For simplicity, we'll create a basic parts array
    const result_array = v8.v8_Array_New(isolate, 11);
    defer release(result_array);

    // Format individual components
    var year_buf: [8]u8 = undefined;
    var month_buf: [4]u8 = undefined;
    var day_buf: [4]u8 = undefined;
    var hour_buf: [4]u8 = undefined;
    var minute_buf: [4]u8 = undefined;
    var second_buf: [4]u8 = undefined;

    const year_str = std.fmt.bufPrint(&year_buf, "{d}", .{@as(u32, @intCast(if (dt.year < 0) -dt.year else dt.year))}) catch "0";
    const month_str = std.fmt.bufPrint(&month_buf, "{d:0>2}", .{dt.month}) catch "0";
    const day_str = std.fmt.bufPrint(&day_buf, "{d:0>2}", .{dt.day}) catch "0";
    const hour_str = std.fmt.bufPrint(&hour_buf, "{d:0>2}", .{dt.hour}) catch "0";
    const minute_str = std.fmt.bufPrint(&minute_buf, "{d:0>2}", .{dt.minute}) catch "0";
    const second_str = std.fmt.bufPrint(&second_buf, "{d:0>2}", .{dt.second}) catch "0";

    _ = locale_data;

    var part_idx: u32 = 0;
    addPart(isolate, context, result_array, &part_idx, "year", year_str);
    addPart(isolate, context, result_array, &part_idx, "literal", "-");
    addPart(isolate, context, result_array, &part_idx, "month", month_str);
    addPart(isolate, context, result_array, &part_idx, "literal", "-");
    addPart(isolate, context, result_array, &part_idx, "day", day_str);
    addPart(isolate, context, result_array, &part_idx, "literal", " ");
    addPart(isolate, context, result_array, &part_idx, "hour", hour_str);
    addPart(isolate, context, result_array, &part_idx, "literal", ":");
    addPart(isolate, context, result_array, &part_idx, "minute", minute_str);
    addPart(isolate, context, result_array, &part_idx, "literal", ":");
    addPart(isolate, context, result_array, &part_idx, "second", second_str);

    info.setReturnValue(@ptrCast(result_array));
}

/// `arr[idx] = { type: part_type, value: value }`, and `idx` moves on.
fn addPart(
    isolate: *v8.Isolate,
    context: *v8.Context,
    arr: *v8.Array,
    idx: *u32,
    part_type: []const u8,
    value: []const u8,
) void {
    const part_obj = v8.v8_Object_New(isolate) orelse return;
    defer release(part_obj);
    setStringProperty(isolate, context, part_obj, "type", part_type);
    setStringProperty(isolate, context, part_obj, "value", value);
    _ = v8.v8_Array_Set(arr, context, idx.*, @ptrCast(part_obj));
    idx.* += 1;
}

// ============================================================================
// DateTimeFormat.resolvedOptions() Callback
// ============================================================================

fn styleName(style: anytype) []const u8 {
    return switch (style) {
        .full => "full",
        .long => "long",
        .medium => "medium",
        .short => "short",
    };
}

/// Callback for `dtf.resolvedOptions()`
fn dateTimeFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.datetime_format, info) orelse {
        conv.throwTypeError(isolate, "Invalid DateTimeFormat object");
        return;
    };

    // Create options object
    const result = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create options object");
        return;
    };
    defer release(result);

    // Set locale
    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "calendar", "gregory");
    setStringProperty(isolate, context, result, "numberingSystem", "latn");
    setStringProperty(isolate, context, result, "timeZone", "UTC");

    // Set dateStyle and timeStyle if present
    if (entry.date_style) |ds| setStringProperty(isolate, context, result, "dateStyle", styleName(ds));
    if (entry.time_style) |ts| setStringProperty(isolate, context, result, "timeStyle", styleName(ts));

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Intl.DateTimeFormat.supportedLocalesOf() Callback
// ============================================================================

/// Callback for `Intl.DateTimeFormat.supportedLocalesOf(locales)`
fn supportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Return all supported locale tags
    returnStringArray(info, isolate, context, &cldr_embedded.locale_tags);
}

// ============================================================================
// NumberFormat Instance Storage
// ============================================================================

/// NumberFormat style enum
const NumberStyle = enum { decimal, currency, percent, unit };

/// NumberFormat notation enum
const NumberNotation = enum { standard, scientific, engineering, compact };

/// A NumberFormat's internal slots
const NumberFormatEntry = struct {
    locale: []const u8,
    locale_data: ?*const cldr.LocaleData,
    style: NumberStyle,
    notation: NumberNotation,
    currency: ?[]const u8,
    minimum_integer_digits: u8,
    minimum_fraction_digits: u8,
    maximum_fraction_digits: u8,
    use_grouping: bool,
    allocator: std.mem.Allocator,

    fn deinit(self: *NumberFormatEntry) void {
        self.allocator.free(self.locale);
        if (self.currency) |c| self.allocator.free(c);
    }
};

// ============================================================================
// NumberFormat Constructor Callback
// ============================================================================

/// Callback for `new Intl.NumberFormat(locales, options)`
fn numberFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var style: NumberStyle = .decimal;
    var notation: NumberNotation = .standard;
    var currency: ?[]const u8 = null;
    const minimum_integer_digits: u8 = 1; // TODO: parse from options
    var minimum_fraction_digits: u8 = 0;
    var maximum_fraction_digits: u8 = 3;
    var use_grouping: bool = true;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // style
        var s_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "style", &s_buf)) |s| {
            if (std.mem.eql(u8, s, "decimal")) style = .decimal else if (std.mem.eql(u8, s, "currency")) style = .currency else if (std.mem.eql(u8, s, "percent")) style = .percent else if (std.mem.eql(u8, s, "unit")) style = .unit;
        }

        // notation
        var n_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "notation", &n_buf)) |n| {
            if (std.mem.eql(u8, n, "standard")) notation = .standard else if (std.mem.eql(u8, n, "scientific")) notation = .scientific else if (std.mem.eql(u8, n, "engineering")) notation = .engineering else if (std.mem.eql(u8, n, "compact")) notation = .compact;
        }

        // currency
        var c_buf: [8]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "currency", &c_buf)) |c| {
            currency = allocator.dupe(u8, c) catch null;
        }

        // useGrouping
        if (booleanOption(isolate, context, options_obj, "useGrouping")) |grouping| use_grouping = grouping;

        // minimumFractionDigits
        if (numberOption(isolate, context, options_obj, "minimumFractionDigits")) |num| {
            if (num >= 0 and num <= 20) minimum_fraction_digits = @intFromFloat(num);
        }

        // maximumFractionDigits
        if (numberOption(isolate, context, options_obj, "maximumFractionDigits")) |num| {
            if (num >= 0 and num <= 20) maximum_fraction_digits = @intFromFloat(num);
        }
    }

    // Set defaults based on style
    if (style == .currency) {
        minimum_fraction_digits = 2;
        maximum_fraction_digits = 2;
    } else if (style == .percent) {
        maximum_fraction_digits = 0;
    }

    const locale_copy = allocator.dupe(u8, locale) catch {
        if (currency) |c| allocator.free(c);
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .number_format = .{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .style = style,
        .notation = notation,
        .currency = currency,
        .minimum_integer_digits = minimum_integer_digits,
        .minimum_fraction_digits = minimum_fraction_digits,
        .maximum_fraction_digits = maximum_fraction_digits,
        .use_grouping = use_grouping,
        .allocator = allocator,
    } };

    // Create the result object
    const result = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create NumberFormat object");
        return;
    };
    defer release(result);
    if (!adopt(isolate, result, state)) return;

    defineMethod(isolate, context, result, "format", numberFormatFormatCallback);
    defineMethod(isolate, context, result, "formatToParts", numberFormatToPartsCallback);
    defineMethod(isolate, context, result, "resolvedOptions", numberFormatResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result));
}

/// `info[0]` when it is a number, else 0.
fn numberArgument(info: *const v8.FunctionCallbackInfo, context: *v8.Context) f64 {
    if (info.length() == 0) return 0;
    const num_arg = info.get(0);
    defer release(num_arg);
    if (!v8.v8_Value_IsNumber(num_arg)) return 0;
    return v8.v8_Value_NumberValue(num_arg, context);
}

// ============================================================================
// NumberFormat.format() Callback
// ============================================================================

/// Format a number with locale-specific formatting
fn formatNumber(
    buf: []u8,
    value: f64,
    entry: *const NumberFormatEntry,
) []const u8 {
    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;
    const symbols = locale_data.number_symbols;

    var idx: usize = 0;

    // Handle special cases
    if (std.math.isNan(value)) {
        idx = writeSliceTo(buf, idx, symbols.nan);
        return buf[0..idx];
    }
    if (std.math.isInf(value)) {
        if (value < 0) {
            idx = writeSliceTo(buf, idx, symbols.minus);
        }
        idx = writeSliceTo(buf, idx, symbols.infinity);
        return buf[0..idx];
    }

    // Handle negative numbers
    var abs_value = value;
    if (value < 0) {
        idx = writeSliceTo(buf, idx, symbols.minus);
        abs_value = -value;
    }

    // Handle percent
    if (entry.style == .percent) {
        abs_value *= 100;
    }

    // Add currency symbol (prepend)
    if (entry.style == .currency) {
        if (entry.currency) |curr| {
            const currency_symbol = getCurrencySymbol(curr);
            idx = writeSliceTo(buf, idx, currency_symbol);
        }
    }

    // Format the number
    const formatted = formatDecimalNumber(
        buf[idx..],
        abs_value,
        entry.minimum_fraction_digits,
        entry.maximum_fraction_digits,
        entry.use_grouping,
        symbols.decimal,
        symbols.group,
    );
    idx += formatted.len;

    // Add percent sign
    if (entry.style == .percent) {
        idx = writeSliceTo(buf, idx, symbols.percent);
    }

    return buf[0..idx];
}

fn writeSliceTo(buf: []u8, start: usize, s: []const u8) usize {
    var idx = start;
    for (s) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }
    return idx;
}

fn formatDecimalNumber(
    buf: []u8,
    value: f64,
    min_frac: u8,
    max_frac: u8,
    use_grouping: bool,
    decimal_sep: []const u8,
    group_sep: []const u8,
) []const u8 {
    var idx: usize = 0;

    // Split into integer and fractional parts
    const int_part: u64 = @intFromFloat(@floor(value));
    var frac_part = value - @floor(value);

    // Format integer part with grouping
    var int_buf: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{int_part}) catch "0";

    if (use_grouping and int_str.len > 3) {
        // Insert group separators
        var pos: usize = 0;
        const first_group = int_str.len % 3;
        if (first_group > 0) {
            for (int_str[0..first_group]) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }
            pos = first_group;
            if (pos < int_str.len) {
                for (group_sep) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
            }
        }
        while (pos < int_str.len) {
            for (int_str[pos .. pos + 3]) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }
            pos += 3;
            if (pos < int_str.len) {
                for (group_sep) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
            }
        }
    } else {
        for (int_str) |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
    }

    // Format fractional part
    if (max_frac > 0 or min_frac > 0) {
        // Round to max_frac digits
        var multiplier: f64 = 1;
        for (0..max_frac) |_| multiplier *= 10;
        frac_part = @round(frac_part * multiplier) / multiplier;

        if (frac_part > 0 or min_frac > 0) {
            for (decimal_sep) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }

            // Output fractional digits
            var frac_digits: u8 = 0;
            var remaining = frac_part;
            while (frac_digits < max_frac and (remaining > 0.000001 or frac_digits < min_frac)) {
                remaining *= 10;
                const digit: u8 = @intFromFloat(@floor(remaining));
                remaining -= @floor(remaining);
                if (idx >= buf.len) break;
                buf[idx] = '0' + digit;
                idx += 1;
                frac_digits += 1;
            }
        }
    }

    return buf[0..idx];
}

fn getCurrencySymbol(currency_code: []const u8) []const u8 {
    // Common currency symbols
    if (std.mem.eql(u8, currency_code, "USD")) return "$";
    if (std.mem.eql(u8, currency_code, "EUR")) return "€";
    if (std.mem.eql(u8, currency_code, "GBP")) return "£";
    if (std.mem.eql(u8, currency_code, "JPY")) return "¥";
    if (std.mem.eql(u8, currency_code, "CNY")) return "¥";
    if (std.mem.eql(u8, currency_code, "KRW")) return "₩";
    if (std.mem.eql(u8, currency_code, "INR")) return "₹";
    if (std.mem.eql(u8, currency_code, "RUB")) return "₽";
    if (std.mem.eql(u8, currency_code, "BRL")) return "R$";
    if (std.mem.eql(u8, currency_code, "CAD")) return "CA$";
    if (std.mem.eql(u8, currency_code, "AUD")) return "A$";
    if (std.mem.eql(u8, currency_code, "CHF")) return "CHF";
    if (std.mem.eql(u8, currency_code, "MXN")) return "MX$";
    // Default to currency code
    return currency_code;
}

/// Callback for `nf.format(number)`
fn numberFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.number_format, info) orelse {
        conv.throwTypeError(isolate, "Invalid NumberFormat object");
        return;
    };

    // Get number argument
    const value = numberArgument(info, context);

    // Format the number
    var buf: [256]u8 = undefined;
    const formatted = formatNumber(&buf, value, entry);

    returnString(info, isolate, formatted);
}

// ============================================================================
// NumberFormat.formatToParts() Callback
// ============================================================================

/// Callback for `nf.formatToParts(number)`
fn numberFormatToPartsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.number_format, info) orelse {
        conv.throwTypeError(isolate, "Invalid NumberFormat object");
        return;
    };

    // Get number argument
    var value = numberArgument(info, context);

    const locale_data = entry.locale_data orelse cldr_embedded.getLocale("en").?;
    const symbols = locale_data.number_symbols;

    // Create parts array: as long as its parts (a length made up front left
    // holes after the last part)
    const result_array = v8.v8_Array_New(isolate, 0);
    defer release(result_array);
    var part_idx: u32 = 0;

    // Handle negative
    if (value < 0) {
        addPart(isolate, context, result_array, &part_idx, "minusSign", symbols.minus);
        value = -value;
    }

    // Handle percent
    if (entry.style == .percent) {
        value *= 100;
    }

    // Currency symbol
    if (entry.style == .currency) {
        if (entry.currency) |curr| {
            addPart(isolate, context, result_array, &part_idx, "currency", getCurrencySymbol(curr));
        }
    }

    // Integer part
    const int_part: u64 = @intFromFloat(@floor(value));
    var int_buf: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{int_part}) catch "0";
    addPart(isolate, context, result_array, &part_idx, "integer", int_str);

    // Decimal and fraction
    const frac_part = value - @floor(value);
    if (entry.maximum_fraction_digits > 0 and (frac_part > 0.000001 or entry.minimum_fraction_digits > 0)) {
        addPart(isolate, context, result_array, &part_idx, "decimal", symbols.decimal);

        var frac_buf: [32]u8 = undefined;
        var frac_idx: usize = 0;
        var remaining = frac_part;
        var digits: u8 = 0;
        while (digits < entry.maximum_fraction_digits and (remaining > 0.000001 or digits < entry.minimum_fraction_digits)) {
            remaining *= 10;
            const digit: u8 = @intFromFloat(@floor(remaining));
            remaining -= @floor(remaining);
            frac_buf[frac_idx] = '0' + digit;
            frac_idx += 1;
            digits += 1;
        }
        addPart(isolate, context, result_array, &part_idx, "fraction", frac_buf[0..frac_idx]);
    }

    // Percent sign
    if (entry.style == .percent) {
        addPart(isolate, context, result_array, &part_idx, "percentSign", symbols.percent);
    }

    info.setReturnValue(@ptrCast(result_array));
}

// ============================================================================
// NumberFormat.resolvedOptions() Callback
// ============================================================================

/// Callback for `nf.resolvedOptions()`
fn numberFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.number_format, info) orelse {
        conv.throwTypeError(isolate, "Invalid NumberFormat object");
        return;
    };

    // Create options object
    const result = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create options object");
        return;
    };
    defer release(result);

    // Set properties
    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "numberingSystem", "latn");

    const style_str = switch (entry.style) {
        .decimal => "decimal",
        .currency => "currency",
        .percent => "percent",
        .unit => "unit",
    };
    setStringProperty(isolate, context, result, "style", style_str);

    const notation_str = switch (entry.notation) {
        .standard => "standard",
        .scientific => "scientific",
        .engineering => "engineering",
        .compact => "compact",
    };
    setStringProperty(isolate, context, result, "notation", notation_str);

    if (entry.currency) |curr| {
        setStringProperty(isolate, context, result, "currency", curr);
    }

    // Set numeric properties
    setNumberProperty(isolate, context, result, "minimumIntegerDigits", @floatFromInt(entry.minimum_integer_digits));
    setNumberProperty(isolate, context, result, "minimumFractionDigits", @floatFromInt(entry.minimum_fraction_digits));
    setNumberProperty(isolate, context, result, "maximumFractionDigits", @floatFromInt(entry.maximum_fraction_digits));

    // Set useGrouping
    setBooleanProperty(isolate, context, result, "useGrouping", entry.use_grouping);

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Intl.NumberFormat.supportedLocalesOf() Callback
// ============================================================================

/// Callback for `Intl.NumberFormat.supportedLocalesOf(locales)`
fn numberFormatSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Return all supported locale tags (same as DateTimeFormat)
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Collator Instance Storage
// ============================================================================

/// Collator usage enum
const CollatorUsage = enum { sort, search };

/// Collator sensitivity enum
const CollatorSensitivity = enum { base, accent, case, variant };

/// Collator caseFirst enum
const CollatorCaseFirst = enum { upper, lower, false };

/// A Collator's internal slots
const CollatorEntry = struct {
    locale: []const u8,
    usage: CollatorUsage,
    sensitivity: CollatorSensitivity,
    ignore_punctuation: bool,
    numeric: bool,
    case_first: CollatorCaseFirst,
    allocator: std.mem.Allocator,

    fn deinit(self: *CollatorEntry) void {
        self.allocator.free(self.locale);
    }
};

// ============================================================================
// Collator Constructor Callback
// ============================================================================

/// Callback for `new Intl.Collator(locales, options)`
fn collatorConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var usage: CollatorUsage = .sort;
    var sensitivity: CollatorSensitivity = .variant;
    var ignore_punctuation: bool = false;
    var numeric: bool = false;
    var case_first: CollatorCaseFirst = .false;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // usage
        var u_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "usage", &u_buf)) |u| {
            if (std.mem.eql(u8, u, "sort")) usage = .sort else if (std.mem.eql(u8, u, "search")) usage = .search;
        }

        // sensitivity
        var s_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "sensitivity", &s_buf)) |s| {
            if (std.mem.eql(u8, s, "base")) sensitivity = .base else if (std.mem.eql(u8, s, "accent")) sensitivity = .accent else if (std.mem.eql(u8, s, "case")) sensitivity = .case else if (std.mem.eql(u8, s, "variant")) sensitivity = .variant;
        }

        // ignorePunctuation
        if (booleanOption(isolate, context, options_obj, "ignorePunctuation")) |b| ignore_punctuation = b;

        // numeric
        if (booleanOption(isolate, context, options_obj, "numeric")) |b| numeric = b;

        // caseFirst
        var cf_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "caseFirst", &cf_buf)) |cf| {
            if (std.mem.eql(u8, cf, "upper")) case_first = .upper else if (std.mem.eql(u8, cf, "lower")) case_first = .lower else if (std.mem.eql(u8, cf, "false")) case_first = .false;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Failed to allocate locale");
        return;
    };
    const state: State = .{ .collator = .{
        .locale = locale_copy,
        .usage = usage,
        .sensitivity = sensitivity,
        .ignore_punctuation = ignore_punctuation,
        .numeric = numeric,
        .case_first = case_first,
        .allocator = allocator,
    } };

    // Create the Collator object
    const collator_obj = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create Collator object");
        return;
    };
    defer release(collator_obj);
    if (!adopt(isolate, collator_obj, state)) return;

    // compare and resolvedOptions use 'this' to find the collator's state
    defineMethod(isolate, context, collator_obj, "compare", collatorCompareCallback);
    defineMethod(isolate, context, collator_obj, "resolvedOptions", collatorResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(collator_obj));
}

// ============================================================================
// Collator.prototype.compare
// ============================================================================

/// Compare two strings with locale awareness
fn collatorCompare(entry: *const CollatorEntry, a: []const u8, b: []const u8) i32 {
    // For base sensitivity, we only compare the base characters (ignore case and accents)
    // For now, use a simple comparison with sensitivity handling

    switch (entry.sensitivity) {
        .base => {
            // Case-insensitive, accent-insensitive comparison
            // Simple ASCII case-folding for now
            return compareIgnoreCase(a, b);
        },
        .accent => {
            // Case-insensitive but accent-sensitive
            // For now, just do case-insensitive
            return compareIgnoreCase(a, b);
        },
        .case => {
            // Case-sensitive but accent-insensitive
            return compareBytes(a, b);
        },
        .variant => {
            // Full comparison (case and accent sensitive)
            return compareBytes(a, b);
        },
    }
}

fn compareBytes(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |ac, bc| {
        if (ac < bc) return -1;
        if (ac > bc) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

fn compareIgnoreCase(a: []const u8, b: []const u8) i32 {
    const min_len = @min(a.len, b.len);
    for (a[0..min_len], b[0..min_len]) |ac, bc| {
        const ac_lower = if (ac >= 'A' and ac <= 'Z') ac + 32 else ac;
        const bc_lower = if (bc >= 'A' and bc <= 'Z') bc + 32 else bc;
        if (ac_lower < bc_lower) return -1;
        if (ac_lower > bc_lower) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

/// Callback for `collator.compare(a, b)`
fn collatorCompareCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        returnInteger(info, isolate, 0);
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // The collator's state, through 'this'
    const entry = thisState(.collator, info) orelse {
        returnInteger(info, isolate, 0);
        return;
    };

    // Get the two string arguments
    if (info.length() < 2) {
        returnInteger(info, isolate, 0);
        return;
    }

    var a_buf: [1024]u8 = undefined;
    var b_buf: [1024]u8 = undefined;
    const a_str = stringArgument(info, 0, context, &a_buf) orelse "";
    const b_str = stringArgument(info, 1, context, &b_buf) orelse "";

    // Compare the strings
    returnInteger(info, isolate, collatorCompare(entry, a_str, b_str));
}

// ============================================================================
// Collator.prototype.resolvedOptions
// ============================================================================

/// Callback for `collator.resolvedOptions()`
fn collatorResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // The collator's state, through 'this'
    const entry = thisState(.collator, info) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "usage", switch (entry.usage) {
        .sort => "sort",
        .search => "search",
    });
    setStringProperty(isolate, context, result, "sensitivity", switch (entry.sensitivity) {
        .base => "base",
        .accent => "accent",
        .case => "case",
        .variant => "variant",
    });
    setBooleanProperty(isolate, context, result, "ignorePunctuation", entry.ignore_punctuation);
    setBooleanProperty(isolate, context, result, "numeric", entry.numeric);
    setStringProperty(isolate, context, result, "caseFirst", switch (entry.case_first) {
        .upper => "upper",
        .lower => "lower",
        .false => "false",
    });
    setStringProperty(isolate, context, result, "collation", "default");

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Collator.supportedLocalesOf
// ============================================================================

/// Callback for `Intl.Collator.supportedLocalesOf(locales)`
fn collatorSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Return all supported locale tags (same as other Intl objects)
    supportedLocalesOfCallback(info);
}

// ============================================================================
// toLocaleString Methods
// ============================================================================

/// Format a number for toLocaleString (standalone, doesn't require registry entry)
fn formatNumberForLocale(
    buf: []u8,
    value: f64,
    style: NumberStyle,
    currency: ?[]const u8,
    use_grouping: bool,
    min_frac: u8,
    max_frac: u8,
    locale_data: *const cldr.LocaleData,
) []const u8 {
    const symbols = locale_data.number_symbols;
    var idx: usize = 0;

    // Handle special cases
    if (std.math.isNan(value)) {
        idx = writeSliceTo(buf, idx, symbols.nan);
        return buf[0..idx];
    }
    if (std.math.isInf(value)) {
        if (value < 0) {
            idx = writeSliceTo(buf, idx, symbols.minus);
        }
        idx = writeSliceTo(buf, idx, symbols.infinity);
        return buf[0..idx];
    }

    // Handle negative numbers
    var abs_value = value;
    if (value < 0) {
        idx = writeSliceTo(buf, idx, symbols.minus);
        abs_value = -value;
    }

    // Handle percent
    if (style == .percent) {
        abs_value *= 100;
    }

    // Add currency symbol (prepend)
    if (style == .currency) {
        if (currency) |curr| {
            const currency_symbol = getCurrencySymbol(curr);
            idx = writeSliceTo(buf, idx, currency_symbol);
        }
    }

    // Format the number
    const formatted = formatDecimalNumber(
        buf[idx..],
        abs_value,
        min_frac,
        max_frac,
        use_grouping,
        symbols.decimal,
        symbols.group,
    );
    idx += formatted.len;

    // Add percent sign
    if (style == .percent) {
        idx = writeSliceTo(buf, idx, symbols.percent);
    }

    return buf[0..idx];
}

/// Callback for `Number.prototype.toLocaleString(locales, options)`
fn numberToLocaleStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Get the number value from 'this'
    // For Number.prototype methods, 'this' can be a primitive or boxed Number
    const number = receiverNumber(info, context);
    if (std.math.isNan(number)) {
        // If we got NaN and the original wasn't a number, return "NaN"
        returnString(info, isolate, "NaN");
        return;
    }

    // Get locale argument (optional)
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Get locale data (fallback to English if locale not found)
    const locale_data = resolveLocale(locale) orelse cldr_embedded.getLocale("en").?;

    // Parse options for style, currency, etc.
    var style: NumberStyle = .decimal;
    var currency: ?[]const u8 = null;
    var minimum_fraction_digits: u8 = 0;
    var maximum_fraction_digits: u8 = 3;
    const use_grouping: bool = true;

    // Outlives the options block: `currency` points into it.
    var c_buf: [8]u8 = undefined;
    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // style
        var s_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "style", &s_buf)) |s| {
            if (std.mem.eql(u8, s, "currency")) {
                style = .currency;
                minimum_fraction_digits = 2;
                maximum_fraction_digits = 2;
            } else if (std.mem.eql(u8, s, "percent")) {
                style = .percent;
            }
        }

        // currency
        if (stringOption(isolate, context, options_obj, "currency", &c_buf)) |c| currency = c;
    }

    // Format the number
    var buf: [128]u8 = undefined;
    const formatted = formatNumberForLocale(&buf, number, style, currency, use_grouping, minimum_fraction_digits, maximum_fraction_digits, locale_data);

    returnString(info, isolate, formatted);
}

/// The receiver as a number: its [[NumberData]], or a Date's time value
/// (valueOf); NaN for anything else.
fn receiverNumber(info: *const v8.FunctionCallbackInfo, context: *v8.Context) f64 {
    const this_val = info.getThis();
    defer release(this_val);
    return v8.v8_Value_NumberValue(@ptrCast(this_val), context);
}

/// `options.dateStyle` (`name` "dateStyle") or `options.timeStyle`, of the
/// options bag `info[1]`, when it names a style.
fn styleOptionArgument(comptime Style: type, info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, context: *v8.Context, name: []const u8) ?Style {
    const options = objectArgument(info, 1) orelse return null;
    defer release(options);
    var s_buf: [16]u8 = undefined;
    const s = stringOption(isolate, context, options, name, &s_buf) orelse return null;
    return parseStyle(Style, s);
}

/// What Date.prototype.toLocaleString, toLocaleDateString and
/// toLocaleTimeString share: `this` formatted with the date and time styles
/// asked for, each defaulting as given (null: not shown).
fn dateToLocale(info: *const v8.FunctionCallbackInfo, default_date: ?DateStyle, default_time: ?TimeStyle) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Get the date value from 'this'
    // Date objects have an internal [[DateValue]] accessible via valueOf()
    const timestamp = receiverNumber(info, context);
    if (std.math.isNan(timestamp)) {
        returnString(info, isolate, "Invalid Date");
        return;
    }

    // Get locale argument (optional)
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Get locale data (fallback to English if locale not found)
    const locale_data = resolveLocale(locale) orelse cldr_embedded.getLocale("en").?;

    // The styles: an option replaces a default only where that part is shown
    // (toLocaleDateString reads no timeStyle, toLocaleTimeString no dateStyle).
    var date_style = default_date;
    var time_style = default_time;
    if (default_date != null) {
        if (styleOptionArgument(DateStyle, info, isolate, context, "dateStyle")) |style| date_style = style;
    }
    if (default_time != null) {
        if (styleOptionArgument(TimeStyle, info, isolate, context, "timeStyle")) |style| time_style = style;
    }

    // Format the date with local timezone
    const tz_offset = getLocalTimezoneOffset(isolate, context);
    const dt = DateTime.fromTimestampMillisWithOffset(@intFromFloat(timestamp), tz_offset);
    var buf: [256]u8 = undefined;
    const formatted = formatDateTime(&buf, dt, locale_data, date_style, time_style);

    returnString(info, isolate, formatted);
}

/// Callback for `Date.prototype.toLocaleString(locales, options)`
fn dateToLocaleStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    dateToLocale(info, .medium, .medium);
}

/// Callback for `Date.prototype.toLocaleDateString(locales, options)`
fn dateToLocaleDateStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // dateStyle (default to medium, no time)
    dateToLocale(info, .medium, null);
}

/// Callback for `Date.prototype.toLocaleTimeString(locales, options)`
fn dateToLocaleTimeStringCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // timeStyle (default to medium, no date)
    dateToLocale(info, null, .medium);
}

/// Register toLocaleString methods on built-in prototypes
pub fn registerToLocaleStringMethods(isolate: *v8.Isolate, context: *v8.Context) void {
    // Every handle below is released: each points into `context` - the
    // functions made here are the realm's - and one kept keeps the realm
    // (docs/lessons/debugging-find-what-keeps-a-page-alive-count-native.md).
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);

    // Number.prototype.toLocaleString
    installOnPrototype(isolate, context, global, "Number", &.{
        .{ .name = "toLocaleString", .callback = numberToLocaleStringCallback },
    });
    // Date.prototype.toLocaleString, toLocaleDateString, toLocaleTimeString
    installOnPrototype(isolate, context, global, "Date", &.{
        .{ .name = "toLocaleString", .callback = dateToLocaleStringCallback },
        .{ .name = "toLocaleDateString", .callback = dateToLocaleDateStringCallback },
        .{ .name = "toLocaleTimeString", .callback = dateToLocaleTimeStringCallback },
    });
}

const PrototypeMethod = struct {
    name: []const u8,
    callback: v8.FunctionCallback,
};

/// `methods` on the prototype of the global constructor `constructor_name`.
fn installOnPrototype(isolate: *v8.Isolate, context: *v8.Context, global: *v8.Object, constructor_name: []const u8, methods: []const PrototypeMethod) void {
    const constructor_key = v8.v8_String_NewFromUtf8(isolate, constructor_name.ptr, @intCast(constructor_name.len)) orelse return;
    defer v8.v8_String_Dispose(constructor_key);
    const constructor = v8.v8_Object_Get(global, context, @ptrCast(constructor_key)) orelse return;
    defer v8.v8_Value_Dispose(constructor);
    if (!v8.v8_Value_IsFunction(constructor)) return;

    const prototype_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return;
    defer v8.v8_String_Dispose(prototype_key);
    const prototype = v8.v8_Object_Get(@ptrCast(constructor), context, @ptrCast(prototype_key)) orelse return;
    defer v8.v8_Value_Dispose(prototype);
    if (!v8.v8_Value_IsObject(prototype)) return;

    for (methods) |method| {
        const key = v8.v8_String_NewFromUtf8(isolate, method.name.ptr, @intCast(method.name.len)) orelse continue;
        defer v8.v8_String_Dispose(key);
        const template = v8.v8_FunctionTemplate_New(isolate, method.callback, null) orelse continue;
        defer v8.v8_FunctionTemplate_Dispose(template);
        const function = v8.v8_FunctionTemplate_GetFunction(template, context) orelse continue;
        defer v8.v8_Function_Dispose(function);
        _ = v8.v8_Object_Set(@ptrCast(prototype), context, @ptrCast(key), @ptrCast(function));
    }
}

// ============================================================================
// Phase 3: PluralRules
// ============================================================================

/// Plural categories as defined by ECMA-402
const PluralCategory = enum {
    zero,
    one,
    two,
    few,
    many,
    other,

    fn toString(self: PluralCategory) []const u8 {
        return switch (self) {
            .zero => "zero",
            .one => "one",
            .two => "two",
            .few => "few",
            .many => "many",
            .other => "other",
        };
    }
};

/// Plural rules type
const PluralRulesType = enum {
    cardinal,
    ordinal,
};

/// A PluralRules' internal slots
const PluralRulesEntry = struct {
    locale: []const u8,
    locale_data: ?*const cldr.LocaleData,
    type: PluralRulesType,
    minimum_integer_digits: u8,
    minimum_fraction_digits: u8,
    maximum_fraction_digits: u8,
    allocator: std.mem.Allocator,

    fn deinit(self: *PluralRulesEntry) void {
        self.allocator.free(self.locale);
    }
};

/// Get plural category for a number (simplified CLDR rules)
fn getPluralCategory(n: f64, locale: []const u8, rule_type: PluralRulesType) PluralCategory {
    // Handle NaN and infinity
    if (std.math.isNan(n) or std.math.isInf(n)) return .other;

    const abs_n = @abs(n);
    const i: u64 = @intFromFloat(@floor(abs_n)); // Integer part

    // Ordinal rules
    if (rule_type == .ordinal) {
        // English ordinal rules
        if (std.mem.startsWith(u8, locale, "en")) {
            const mod10 = i % 10;
            const mod100 = i % 100;
            if (mod10 == 1 and mod100 != 11) return .one; // 1st, 21st, 31st...
            if (mod10 == 2 and mod100 != 12) return .two; // 2nd, 22nd, 32nd...
            if (mod10 == 3 and mod100 != 13) return .few; // 3rd, 23rd, 33rd...
            return .other;
        }
        return .other;
    }

    // Cardinal rules (simplified for major locales)
    // Arabic
    if (std.mem.startsWith(u8, locale, "ar")) {
        if (abs_n == 0) return .zero;
        if (abs_n == 1) return .one;
        if (abs_n == 2) return .two;
        const mod100 = i % 100;
        if (mod100 >= 3 and mod100 <= 10) return .few;
        if (mod100 >= 11 and mod100 <= 99) return .many;
        return .other;
    }

    // Polish, Russian and other Slavic languages
    if (std.mem.startsWith(u8, locale, "pl") or std.mem.startsWith(u8, locale, "ru")) {
        const mod10 = i % 10;
        const mod100 = i % 100;
        if (abs_n == 1) return .one;
        if (mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14)) return .few;
        if (mod10 == 0 or (mod10 >= 5 and mod10 <= 9) or (mod100 >= 11 and mod100 <= 14)) return .many;
        return .other;
    }

    // French, Spanish, Portuguese, Italian - simple rule
    if (std.mem.startsWith(u8, locale, "fr") or
        std.mem.startsWith(u8, locale, "es") or
        std.mem.startsWith(u8, locale, "pt") or
        std.mem.startsWith(u8, locale, "it"))
    {
        if (i == 0 or i == 1) return .one;
        return .other;
    }

    // Default: English and most Germanic languages
    if (abs_n == 1) return .one;
    return .other;
}

/// Intl.PluralRules constructor callback
fn pluralRulesConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Parse locale
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var rule_type: PluralRulesType = .cardinal;
    const minimum_integer_digits: u8 = 1;
    const minimum_fraction_digits: u8 = 0;
    const maximum_fraction_digits: u8 = 3;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // type
        var t_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "type", &t_buf)) |t| {
            if (std.mem.eql(u8, t, "ordinal")) rule_type = .ordinal;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .plural_rules = .{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .type = rule_type,
        .minimum_integer_digits = minimum_integer_digits,
        .minimum_fraction_digits = minimum_fraction_digits,
        .maximum_fraction_digits = maximum_fraction_digits,
        .allocator = allocator,
    } };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };
    defer release(result_obj);
    if (!adopt(isolate, result_obj, state)) return;

    defineMethod(isolate, context, result_obj, "select", pluralRulesSelectCallback);
    defineMethod(isolate, context, result_obj, "resolvedOptions", pluralRulesResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.PluralRules.prototype.select callback
fn pluralRulesSelectCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.plural_rules, info) orelse return;

    // Get number argument
    if (info.length() < 1) {
        returnString(info, isolate, "other");
        return;
    }

    const num_arg = info.get(0);
    defer release(num_arg);
    const num = v8.v8_Value_NumberValue(num_arg, context);

    // Get plural category
    returnString(info, isolate, getPluralCategory(num, entry.locale, entry.type).toString());
}

/// Intl.PluralRules.prototype.resolvedOptions callback
fn pluralRulesResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.plural_rules, info) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "type", if (entry.type == .ordinal) "ordinal" else "cardinal");
    setNumberProperty(isolate, context, result, "minimumIntegerDigits", @floatFromInt(entry.minimum_integer_digits));
    setNumberProperty(isolate, context, result, "minimumFractionDigits", @floatFromInt(entry.minimum_fraction_digits));
    setNumberProperty(isolate, context, result, "maximumFractionDigits", @floatFromInt(entry.maximum_fraction_digits));

    // pluralCategories
    const categories = v8.v8_Array_New(isolate, 6);
    const cat_strs = [_][]const u8{ "zero", "one", "two", "few", "many", "other" };
    for (cat_strs, 0..) |cat_str, idx| {
        setElementOwned(context, categories, @intCast(idx), v8.v8_String_NewFromUtf8(isolate, cat_str.ptr, @intCast(cat_str.len)));
    }
    setOwned(isolate, context, result, "pluralCategories", categories);

    info.setReturnValue(@ptrCast(result));
}

/// Intl.PluralRules.supportedLocalesOf callback
fn pluralRulesSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Same implementation as other supportedLocalesOf
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: RelativeTimeFormat
// ============================================================================

/// Time unit for relative time formatting
const RelativeTimeUnit = enum {
    year,
    quarter,
    month,
    week,
    day,
    hour,
    minute,
    second,

    fn fromString(s: []const u8) ?RelativeTimeUnit {
        if (std.mem.eql(u8, s, "year") or std.mem.eql(u8, s, "years")) return .year;
        if (std.mem.eql(u8, s, "quarter") or std.mem.eql(u8, s, "quarters")) return .quarter;
        if (std.mem.eql(u8, s, "month") or std.mem.eql(u8, s, "months")) return .month;
        if (std.mem.eql(u8, s, "week") or std.mem.eql(u8, s, "weeks")) return .week;
        if (std.mem.eql(u8, s, "day") or std.mem.eql(u8, s, "days")) return .day;
        if (std.mem.eql(u8, s, "hour") or std.mem.eql(u8, s, "hours")) return .hour;
        if (std.mem.eql(u8, s, "minute") or std.mem.eql(u8, s, "minutes")) return .minute;
        if (std.mem.eql(u8, s, "second") or std.mem.eql(u8, s, "seconds")) return .second;
        return null;
    }

    fn singular(self: RelativeTimeUnit) []const u8 {
        return switch (self) {
            .year => "year",
            .quarter => "quarter",
            .month => "month",
            .week => "week",
            .day => "day",
            .hour => "hour",
            .minute => "minute",
            .second => "second",
        };
    }

    fn plural(self: RelativeTimeUnit) []const u8 {
        return switch (self) {
            .year => "years",
            .quarter => "quarters",
            .month => "months",
            .week => "weeks",
            .day => "days",
            .hour => "hours",
            .minute => "minutes",
            .second => "seconds",
        };
    }
};

/// Relative time format style
const RelativeTimeStyle = enum {
    long,
    short,
    narrow,
};

/// Relative time numeric option
const RelativeTimeNumeric = enum {
    always,
    auto,
};

/// A RelativeTimeFormat's internal slots
const RelativeTimeFormatEntry = struct {
    locale: []const u8,
    locale_data: ?*const cldr.LocaleData,
    style: RelativeTimeStyle,
    numeric: RelativeTimeNumeric,
    allocator: std.mem.Allocator,

    fn deinit(self: *RelativeTimeFormatEntry) void {
        self.allocator.free(self.locale);
    }
};

/// Format relative time (simplified implementation)
fn formatRelativeTime(buf: []u8, value: f64, unit: RelativeTimeUnit, locale: []const u8, numeric: RelativeTimeNumeric) []const u8 {
    var idx: usize = 0;
    const abs_value = @abs(value);
    const is_past = value < 0;
    const int_value: i64 = @intFromFloat(abs_value);

    // Auto mode: use special forms for -1, 0, 1
    if (numeric == .auto) {
        if (int_value == 0) {
            // "now", "this year", "today", etc.
            const now_str = switch (unit) {
                .second => "now",
                .minute => "this minute",
                .hour => "this hour",
                .day => "today",
                .week => "this week",
                .month => "this month",
                .quarter => "this quarter",
                .year => "this year",
            };
            for (now_str) |c| {
                if (idx >= buf.len) break;
                buf[idx] = c;
                idx += 1;
            }
            return buf[0..idx];
        }
        if (int_value == 1) {
            // "yesterday", "last week", "next year", etc.
            const one_str = if (is_past) switch (unit) {
                .day => "yesterday",
                .week => "last week",
                .month => "last month",
                .year => "last year",
                else => null,
            } else switch (unit) {
                .day => "tomorrow",
                .week => "next week",
                .month => "next month",
                .year => "next year",
                else => null,
            };
            if (one_str) |s| {
                for (s) |c| {
                    if (idx >= buf.len) break;
                    buf[idx] = c;
                    idx += 1;
                }
                return buf[0..idx];
            }
        }
    }

    // Numeric format: "X units ago" or "in X units"
    _ = locale; // Would use for localized strings

    if (!is_past) {
        // "in X units"
        for ("in ") |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
    }

    // Format number
    var num_buf: [20]u8 = undefined;
    const num_str = std.fmt.bufPrint(&num_buf, "{d}", .{int_value}) catch "0";
    for (num_str) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }

    // Add space
    if (idx < buf.len) {
        buf[idx] = ' ';
        idx += 1;
    }

    // Add unit
    const unit_str = if (int_value == 1) unit.singular() else unit.plural();
    for (unit_str) |c| {
        if (idx >= buf.len) break;
        buf[idx] = c;
        idx += 1;
    }

    if (is_past) {
        // " ago"
        for (" ago") |c| {
            if (idx >= buf.len) break;
            buf[idx] = c;
            idx += 1;
        }
    }

    return buf[0..idx];
}

/// Intl.RelativeTimeFormat constructor callback
fn relativeTimeFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Parse locale
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var style: RelativeTimeStyle = .long;
    var numeric: RelativeTimeNumeric = .always;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // style
        var s_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "style", &s_buf)) |s| {
            if (std.mem.eql(u8, s, "short")) style = .short else if (std.mem.eql(u8, s, "narrow")) style = .narrow;
        }

        // numeric
        var n_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "numeric", &n_buf)) |n| {
            if (std.mem.eql(u8, n, "auto")) numeric = .auto;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .relative_time_format = .{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .style = style,
        .numeric = numeric,
        .allocator = allocator,
    } };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };
    defer release(result_obj);
    if (!adopt(isolate, result_obj, state)) return;

    defineMethod(isolate, context, result_obj, "format", relativeTimeFormatFormatCallback);
    defineMethod(isolate, context, result_obj, "resolvedOptions", relativeTimeFormatResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.RelativeTimeFormat.prototype.format callback
fn relativeTimeFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.relative_time_format, info) orelse return;

    // Get arguments: value, unit
    if (info.length() < 2) {
        conv.throwTypeError(isolate, "RelativeTimeFormat.format requires value and unit");
        return;
    }

    const value_arg = info.get(0);
    defer release(value_arg);
    const value = v8.v8_Value_NumberValue(value_arg, context);

    var unit_buf: [16]u8 = undefined;
    const unit_arg = info.get(1);
    defer release(unit_arg);
    if (!v8.v8_Value_IsString(unit_arg)) {
        conv.throwTypeError(isolate, "Unit must be a string");
        return;
    }

    const unit_str = readV8String(v8.v8_Value_ToString(unit_arg, context), context, &unit_buf) orelse {
        conv.throwTypeError(isolate, "Failed to read unit");
        return;
    };

    const unit = RelativeTimeUnit.fromString(unit_str) orelse {
        conv.throwTypeError(isolate, "Invalid unit");
        return;
    };

    // Format
    var buf: [128]u8 = undefined;
    returnString(info, isolate, formatRelativeTime(&buf, value, unit, entry.locale, entry.numeric));
}

/// Intl.RelativeTimeFormat.prototype.resolvedOptions callback
fn relativeTimeFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.relative_time_format, info) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "style", switch (entry.style) {
        .long => "long",
        .short => "short",
        .narrow => "narrow",
    });
    setStringProperty(isolate, context, result, "numeric", if (entry.numeric == .auto) "auto" else "always");
    setStringProperty(isolate, context, result, "numberingSystem", "latn");

    info.setReturnValue(@ptrCast(result));
}

/// Intl.RelativeTimeFormat.supportedLocalesOf callback
fn relativeTimeFormatSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: ListFormat
// ============================================================================

/// List format type
const ListFormatType = enum {
    conjunction, // "A, B, and C"
    disjunction, // "A, B, or C"
    unit, // "A, B, C"
};

/// List format style
const ListFormatStyle = enum {
    long,
    short,
    narrow,
};

/// A ListFormat's internal slots
const ListFormatEntry = struct {
    locale: []const u8,
    locale_data: ?*const cldr.LocaleData,
    type: ListFormatType,
    style: ListFormatStyle,
    allocator: std.mem.Allocator,

    fn deinit(self: *ListFormatEntry) void {
        self.allocator.free(self.locale);
    }
};

/// Format a list
fn formatList(allocator: std.mem.Allocator, items: []const []const u8, format_type: ListFormatType, locale: []const u8) ![]u8 {
    if (items.len == 0) return allocator.dupe(u8, "");
    if (items.len == 1) return allocator.dupe(u8, items[0]);

    // Get conjunction/disjunction based on locale
    const conjunction = getListConjunction(locale, format_type);

    // Calculate total size
    var total_size: usize = 0;
    for (items) |item| {
        total_size += item.len;
    }
    // Add separators: ", " between all except last, " and/or " before last
    total_size += (items.len - 2) * 2 + conjunction.len + 2; // ", " * (n-2) + " and " or " or "

    var result = try allocator.alloc(u8, total_size + 16); // Extra buffer
    var idx: usize = 0;

    for (items, 0..) |item, i| {
        // Copy item
        for (item) |c| {
            if (idx >= result.len) break;
            result[idx] = c;
            idx += 1;
        }

        if (i < items.len - 2) {
            // Add ", "
            if (idx + 2 <= result.len) {
                result[idx] = ',';
                result[idx + 1] = ' ';
                idx += 2;
            }
        } else if (i == items.len - 2) {
            // Add conjunction
            if (idx + conjunction.len + 2 <= result.len) {
                result[idx] = ',';
                result[idx + 1] = ' ';
                idx += 2;
                for (conjunction) |c| {
                    result[idx] = c;
                    idx += 1;
                }
                result[idx] = ' ';
                idx += 1;
            }
        }
    }

    // The caller frees what it is given: hand back exactly what was allocated.
    if (allocator.resize(result, idx)) return result[0..idx];
    defer allocator.free(result);
    return allocator.dupe(u8, result[0..idx]);
}

fn getListConjunction(locale: []const u8, format_type: ListFormatType) []const u8 {
    _ = locale; // Would use for localized conjunctions
    return switch (format_type) {
        .conjunction => "and",
        .disjunction => "or",
        .unit => "",
    };
}

/// Intl.ListFormat constructor callback
fn listFormatConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Parse locale
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var format_type: ListFormatType = .conjunction;
    var style: ListFormatStyle = .long;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // type
        var t_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "type", &t_buf)) |t| {
            if (std.mem.eql(u8, t, "disjunction")) format_type = .disjunction else if (std.mem.eql(u8, t, "unit")) format_type = .unit;
        }

        // style
        var s_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "style", &s_buf)) |s| {
            if (std.mem.eql(u8, s, "short")) style = .short else if (std.mem.eql(u8, s, "narrow")) style = .narrow;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .list_format = .{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .type = format_type,
        .style = style,
        .allocator = allocator,
    } };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };
    defer release(result_obj);
    if (!adopt(isolate, result_obj, state)) return;

    defineMethod(isolate, context, result_obj, "format", listFormatFormatCallback);
    defineMethod(isolate, context, result_obj, "resolvedOptions", listFormatResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.ListFormat.prototype.format callback
fn listFormatFormatCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.list_format, info) orelse return;

    // Get array argument
    if (info.length() < 1) {
        returnString(info, isolate, "");
        return;
    }

    const list_arg = info.get(0);
    defer release(list_arg);
    if (!v8.v8_Value_IsArray(list_arg)) {
        conv.throwTypeError(isolate, "ListFormat.format requires an array");
        return;
    }

    const arr: *v8.Array = @ptrCast(list_arg);
    const len = v8.v8_Array_Length(arr);

    if (len == 0) {
        returnString(info, isolate, "");
        return;
    }

    // Collect strings from array
    const allocator = entry.allocator;
    var items = allocator.alloc([]const u8, len) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    defer allocator.free(items);

    var string_bufs = allocator.alloc([256]u8, len) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    defer allocator.free(string_bufs);

    for (0..len) |i| {
        const elem = v8.v8_Array_Get(context, arr, @intCast(i)) orelse {
            items[i] = "";
            continue;
        };
        defer release(elem);
        // A string as it is, anything else converted to one
        items[i] = readV8String(v8.v8_Value_ToString(elem, context), context, &string_bufs[i]) orelse "";
    }

    // Format list
    const formatted = formatList(allocator, items, entry.type, entry.locale) catch {
        conv.throwTypeError(isolate, "Failed to format list");
        return;
    };
    defer allocator.free(formatted);

    returnString(info, isolate, formatted);
}

/// Intl.ListFormat.prototype.resolvedOptions callback
fn listFormatResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.list_format, info) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "type", switch (entry.type) {
        .conjunction => "conjunction",
        .disjunction => "disjunction",
        .unit => "unit",
    });
    setStringProperty(isolate, context, result, "style", switch (entry.style) {
        .long => "long",
        .short => "short",
        .narrow => "narrow",
    });

    info.setReturnValue(@ptrCast(result));
}

/// Intl.ListFormat.supportedLocalesOf callback
fn listFormatSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: DisplayNames
// ============================================================================

/// DisplayNames type
const DisplayNamesType = enum {
    language,
    region,
    script,
    currency,
    calendar,
    dateTimeField,
};

/// DisplayNames fallback mode
const DisplayNamesFallback = enum { code, none };

/// A DisplayNames' internal slots
const DisplayNamesEntry = struct {
    locale: []const u8,
    locale_data: ?*const cldr.LocaleData,
    type: DisplayNamesType,
    style: ListFormatStyle,
    fallback: DisplayNamesFallback,
    allocator: std.mem.Allocator,

    fn deinit(self: *DisplayNamesEntry) void {
        self.allocator.free(self.locale);
    }
};

/// Get display name for a code
fn getDisplayName(code: []const u8, display_type: DisplayNamesType, locale: []const u8) ?[]const u8 {
    _ = locale; // Would use for localized names
    return switch (display_type) {
        .language => getLanguageDisplayName(code),
        .region => getRegionDisplayName(code),
        .currency => getCurrencyDisplayName(code),
        .script => getScriptDisplayName(code),
        .calendar => getCalendarDisplayName(code),
        .dateTimeField => getDateTimeFieldDisplayName(code),
    };
}

fn getLanguageDisplayName(code: []const u8) ?[]const u8 {
    // Common language codes
    if (std.mem.eql(u8, code, "en")) return "English";
    if (std.mem.eql(u8, code, "de")) return "German";
    if (std.mem.eql(u8, code, "fr")) return "French";
    if (std.mem.eql(u8, code, "es")) return "Spanish";
    if (std.mem.eql(u8, code, "it")) return "Italian";
    if (std.mem.eql(u8, code, "pt")) return "Portuguese";
    if (std.mem.eql(u8, code, "zh")) return "Chinese";
    if (std.mem.eql(u8, code, "ja")) return "Japanese";
    if (std.mem.eql(u8, code, "ko")) return "Korean";
    if (std.mem.eql(u8, code, "ar")) return "Arabic";
    if (std.mem.eql(u8, code, "ru")) return "Russian";
    if (std.mem.eql(u8, code, "nl")) return "Dutch";
    if (std.mem.eql(u8, code, "pl")) return "Polish";
    if (std.mem.eql(u8, code, "tr")) return "Turkish";
    if (std.mem.eql(u8, code, "vi")) return "Vietnamese";
    if (std.mem.eql(u8, code, "th")) return "Thai";
    if (std.mem.eql(u8, code, "id")) return "Indonesian";
    if (std.mem.eql(u8, code, "hi")) return "Hindi";
    return null;
}

fn getRegionDisplayName(code: []const u8) ?[]const u8 {
    // Common region codes
    if (std.mem.eql(u8, code, "US")) return "United States";
    if (std.mem.eql(u8, code, "GB")) return "United Kingdom";
    if (std.mem.eql(u8, code, "DE")) return "Germany";
    if (std.mem.eql(u8, code, "FR")) return "France";
    if (std.mem.eql(u8, code, "ES")) return "Spain";
    if (std.mem.eql(u8, code, "IT")) return "Italy";
    if (std.mem.eql(u8, code, "JP")) return "Japan";
    if (std.mem.eql(u8, code, "CN")) return "China";
    if (std.mem.eql(u8, code, "KR")) return "South Korea";
    if (std.mem.eql(u8, code, "BR")) return "Brazil";
    if (std.mem.eql(u8, code, "IN")) return "India";
    if (std.mem.eql(u8, code, "RU")) return "Russia";
    if (std.mem.eql(u8, code, "AU")) return "Australia";
    if (std.mem.eql(u8, code, "CA")) return "Canada";
    if (std.mem.eql(u8, code, "MX")) return "Mexico";
    return null;
}

fn getCurrencyDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "USD")) return "US Dollar";
    if (std.mem.eql(u8, code, "EUR")) return "Euro";
    if (std.mem.eql(u8, code, "GBP")) return "British Pound";
    if (std.mem.eql(u8, code, "JPY")) return "Japanese Yen";
    if (std.mem.eql(u8, code, "CNY")) return "Chinese Yuan";
    if (std.mem.eql(u8, code, "KRW")) return "South Korean Won";
    if (std.mem.eql(u8, code, "INR")) return "Indian Rupee";
    if (std.mem.eql(u8, code, "RUB")) return "Russian Ruble";
    if (std.mem.eql(u8, code, "BRL")) return "Brazilian Real";
    if (std.mem.eql(u8, code, "CAD")) return "Canadian Dollar";
    if (std.mem.eql(u8, code, "AUD")) return "Australian Dollar";
    if (std.mem.eql(u8, code, "CHF")) return "Swiss Franc";
    return null;
}

fn getScriptDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "Latn")) return "Latin";
    if (std.mem.eql(u8, code, "Cyrl")) return "Cyrillic";
    if (std.mem.eql(u8, code, "Arab")) return "Arabic";
    if (std.mem.eql(u8, code, "Hans")) return "Simplified Han";
    if (std.mem.eql(u8, code, "Hant")) return "Traditional Han";
    if (std.mem.eql(u8, code, "Jpan")) return "Japanese";
    if (std.mem.eql(u8, code, "Kore")) return "Korean";
    if (std.mem.eql(u8, code, "Deva")) return "Devanagari";
    if (std.mem.eql(u8, code, "Grek")) return "Greek";
    if (std.mem.eql(u8, code, "Hebr")) return "Hebrew";
    return null;
}

fn getCalendarDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "gregory")) return "Gregorian Calendar";
    if (std.mem.eql(u8, code, "buddhist")) return "Buddhist Calendar";
    if (std.mem.eql(u8, code, "chinese")) return "Chinese Calendar";
    if (std.mem.eql(u8, code, "hebrew")) return "Hebrew Calendar";
    if (std.mem.eql(u8, code, "islamic")) return "Islamic Calendar";
    if (std.mem.eql(u8, code, "japanese")) return "Japanese Calendar";
    if (std.mem.eql(u8, code, "persian")) return "Persian Calendar";
    return null;
}

fn getDateTimeFieldDisplayName(code: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, code, "era")) return "era";
    if (std.mem.eql(u8, code, "year")) return "year";
    if (std.mem.eql(u8, code, "month")) return "month";
    if (std.mem.eql(u8, code, "week")) return "week";
    if (std.mem.eql(u8, code, "day")) return "day";
    if (std.mem.eql(u8, code, "hour")) return "hour";
    if (std.mem.eql(u8, code, "minute")) return "minute";
    if (std.mem.eql(u8, code, "second")) return "second";
    if (std.mem.eql(u8, code, "weekday")) return "day of the week";
    if (std.mem.eql(u8, code, "dayPeriod")) return "AM/PM";
    if (std.mem.eql(u8, code, "timeZoneName")) return "time zone";
    return null;
}

/// Intl.DisplayNames constructor callback
fn displayNamesConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Parse locale
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options (required for type)
    var display_type: DisplayNamesType = .language;
    var style: ListFormatStyle = .long;
    var fallback: DisplayNamesFallback = .code;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // type (required)
        var t_buf: [32]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "type", &t_buf)) |t| {
            if (std.mem.eql(u8, t, "language")) display_type = .language else if (std.mem.eql(u8, t, "region")) display_type = .region else if (std.mem.eql(u8, t, "script")) display_type = .script else if (std.mem.eql(u8, t, "currency")) display_type = .currency else if (std.mem.eql(u8, t, "calendar")) display_type = .calendar else if (std.mem.eql(u8, t, "dateTimeField")) display_type = .dateTimeField;
        }

        // style
        var s_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "style", &s_buf)) |s| {
            if (std.mem.eql(u8, s, "short")) style = .short else if (std.mem.eql(u8, s, "narrow")) style = .narrow;
        }

        // fallback
        var f_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "fallback", &f_buf)) |f| {
            if (std.mem.eql(u8, f, "none")) fallback = .none;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .display_names = .{
        .locale = locale_copy,
        .locale_data = resolveLocale(locale),
        .type = display_type,
        .style = style,
        .fallback = fallback,
        .allocator = allocator,
    } };

    // Create result object with methods
    const result_obj = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create result object");
        return;
    };
    defer release(result_obj);
    if (!adopt(isolate, result_obj, state)) return;

    defineMethod(isolate, context, result_obj, "of", displayNamesOfCallback);
    defineMethod(isolate, context, result_obj, "resolvedOptions", displayNamesResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result_obj));
}

/// Intl.DisplayNames.prototype.of callback
fn displayNamesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.display_names, info) orelse return;

    // Get code argument
    if (info.length() < 1) {
        returnUndefined(info);
        return;
    }

    var code_buf: [32]u8 = undefined;
    const code_arg = info.get(0);
    defer release(code_arg);
    if (!v8.v8_Value_IsString(code_arg)) {
        conv.throwTypeError(isolate, "Code must be a string");
        return;
    }

    const code = readV8String(v8.v8_Value_ToString(code_arg, context), context, &code_buf) orelse {
        returnUndefined(info);
        return;
    };

    // Get display name
    if (getDisplayName(code, entry.type, entry.locale)) |name| {
        returnString(info, isolate, name);
    } else if (entry.fallback == .code) {
        // Return the code itself as fallback
        returnString(info, isolate, code);
    } else {
        returnUndefined(info);
    }
}

/// Intl.DisplayNames.prototype.resolvedOptions callback
fn displayNamesResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.display_names, info) orelse return;

    // Create result object
    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "type", switch (entry.type) {
        .language => "language",
        .region => "region",
        .script => "script",
        .currency => "currency",
        .calendar => "calendar",
        .dateTimeField => "dateTimeField",
    });
    setStringProperty(isolate, context, result, "style", switch (entry.style) {
        .long => "long",
        .short => "short",
        .narrow => "narrow",
    });
    setStringProperty(isolate, context, result, "fallback", if (entry.fallback == .code) "code" else "none");

    info.setReturnValue(@ptrCast(result));
}

/// Intl.DisplayNames.supportedLocalesOf callback
fn displayNamesSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 4: Intl.Segmenter (ECMA-402 §17)
// ============================================================================

// Import the segmenter module
const segmenter_module = @import("intl").segmenter;

/// Segmenter granularity
const SegmenterGranularity = enum {
    grapheme,
    word,
    sentence,
};

/// A Segmenter's internal slots
const SegmenterEntry = struct {
    locale: []const u8,
    granularity: SegmenterGranularity,
    allocator: std.mem.Allocator,

    fn deinit(self: *SegmenterEntry) void {
        self.allocator.free(self.locale);
    }
};

/// Callback for `new Intl.Segmenter(locales, options)`
fn segmenterConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Get locale argument
    var locale_buf: [64]u8 = undefined;
    const locale: []const u8 = stringArgument(info, 0, context, &locale_buf) orelse "en";

    // Parse options
    var granularity: SegmenterGranularity = .grapheme;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        // granularity
        var g_buf: [16]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "granularity", &g_buf)) |g| {
            if (std.mem.eql(u8, g, "grapheme")) granularity = .grapheme else if (std.mem.eql(u8, g, "word")) granularity = .word else if (std.mem.eql(u8, g, "sentence")) granularity = .sentence;
        }
    }

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;
    const locale_copy = allocator.dupe(u8, locale) catch {
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };
    const state: State = .{ .segmenter = .{
        .locale = locale_copy,
        .granularity = granularity,
        .allocator = allocator,
    } };

    // Create the result object
    const result = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create Segmenter object");
        return;
    };
    defer release(result);
    if (!adopt(isolate, result, state)) return;

    defineMethod(isolate, context, result, "segment", segmenterSegmentCallback);
    defineMethod(isolate, context, result, "resolvedOptions", segmenterResolvedOptionsCallback);

    info.setReturnValue(@ptrCast(result));
}

fn granularityName(granularity: SegmenterGranularity) []const u8 {
    return switch (granularity) {
        .grapheme => "grapheme",
        .word => "word",
        .sentence => "sentence",
    };
}

/// Callback for `segmenter.segment(text)`
/// Returns a Segments object (which is an iterable)
fn segmenterSegmentCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.segmenter, info) orelse {
        conv.throwTypeError(isolate, "Invalid Segmenter object");
        return;
    };

    // Get text argument
    if (info.length() < 1) {
        conv.throwTypeError(isolate, "segment() requires a string argument");
        return;
    }

    var text_buf: [4096]u8 = undefined;
    const text_arg = info.get(0);
    defer release(text_arg);
    if (!v8.v8_Value_IsString(text_arg)) {
        conv.throwTypeError(isolate, "segment() argument must be a string");
        return;
    }

    const text = readV8String(v8.v8_Value_ToString(text_arg, context), context, &text_buf) orelse {
        conv.throwTypeError(isolate, "Failed to read text");
        return;
    };

    // Create Segments object - contains the text and granularity
    const segments_obj = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create Segments object");
        return;
    };
    defer release(segments_obj);

    // Store text and granularity in the Segments object
    setStringProperty(isolate, context, segments_obj, "__text__", text);
    setStringProperty(isolate, context, segments_obj, "__granularity__", granularityName(entry.granularity));

    // Add containing() method
    defineMethod(isolate, context, segments_obj, "containing", segmentsContainingCallback);

    // Add [Symbol.iterator]() method for iterable protocol
    // For simplicity, we'll iterate and return an array that JS can iterate
    // A full implementation would create a proper iterator object
    const iter_fn = v8.v8_Function_NewWithData(context, segmentsIteratorCallback, null, 0) orelse return;
    defer release(iter_fn);

    // Get Symbol.iterator
    const global = v8.v8_Context_Global(context) orelse return;
    defer release(global);
    const symbol_key = v8.v8_String_NewFromUtf8(isolate, "Symbol", 6) orelse return;
    defer release(symbol_key);
    const symbol_obj = v8.v8_Object_Get(global, context, @ptrCast(symbol_key)) orelse return;
    defer release(symbol_obj);
    if (!v8.v8_Value_IsObject(symbol_obj)) return;
    const iter_symbol_key = v8.v8_String_NewFromUtf8(isolate, "iterator", 8) orelse return;
    defer release(iter_symbol_key);
    const iter_symbol = v8.v8_Object_Get(@ptrCast(symbol_obj), context, @ptrCast(iter_symbol_key)) orelse return;
    defer release(iter_symbol);

    _ = v8.v8_Object_Set(segments_obj, context, @ptrCast(iter_symbol), @ptrCast(iter_fn));

    info.setReturnValue(@ptrCast(segments_obj));
}

/// The text and granularity a Segments object (`this`) was made with; null
/// when it has none. The text is read into `text_buf`.
fn segmentsOf(info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, context: *v8.Context, text_buf: []u8) ?struct { text: []const u8, granularity: segmenter_module.Granularity } {
    const this_obj = info.getThis();
    defer release(this_obj);

    const text = stringProperty(isolate, context, this_obj, "__text__", text_buf) orelse return null;

    var gran_buf: [16]u8 = undefined;
    const gran_str = stringProperty(isolate, context, this_obj, "__granularity__", &gran_buf) orelse return null;

    // Determine granularity
    const granularity: segmenter_module.Granularity = if (std.mem.eql(u8, gran_str, "word"))
        .word
    else if (std.mem.eql(u8, gran_str, "sentence"))
        .sentence
    else
        .grapheme;
    return .{ .text = text, .granularity = granularity };
}

/// `obj[name]` converted to a string (ToString), its UTF-8 in `buf`.
fn stringProperty(isolate: *v8.Isolate, context: *v8.Context, obj: *v8.Object, name: []const u8, buf: []u8) ?[]const u8 {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, @intCast(name.len)) orelse return null;
    defer release(key);
    const value = v8.v8_Object_Get(obj, context, @ptrCast(key)) orelse return null;
    defer release(value);
    return readV8String(v8.v8_Value_ToString(value, context), context, buf);
}

/// `{ segment, index, input, isWordLike? }` for `seg` of `text`: an owned
/// Global.
fn segmentDataObject(isolate: *v8.Isolate, context: *v8.Context, seg: anytype, text: []const u8) ?*v8.Object {
    const seg_obj = v8.v8_Object_New(isolate) orelse return null;
    setStringProperty(isolate, context, seg_obj, "segment", seg.segment);
    setNumberProperty(isolate, context, seg_obj, "index", @floatFromInt(seg.index));
    setStringProperty(isolate, context, seg_obj, "input", text);
    // isWordLike property (only for word granularity)
    if (seg.is_word_like) |is_word_like| setBooleanProperty(isolate, context, seg_obj, "isWordLike", is_word_like);
    return seg_obj;
}

/// Callback for Segments[Symbol.iterator]()
/// Returns an iterator object with next() method
fn segmentsIteratorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    // Get text and granularity from Segments object
    var text_buf: [4096]u8 = undefined;
    const of = segmentsOf(info, isolate, context, &text_buf) orelse return;

    // Create iterator object that pre-computes all segments
    // (Full implementation would lazily compute)
    const iter_obj = v8.v8_Object_New(isolate) orelse return;
    defer release(iter_obj);

    // Collect all segments into an array
    var segments = segmenter_module.Segments.init(of.text, of.granularity);
    const segments_arr = v8.v8_Array_New(isolate, 0);
    var arr_idx: u32 = 0;

    while (segments.next()) |seg| {
        const seg_obj = segmentDataObject(isolate, context, seg, of.text) orelse continue;
        setElementOwned(context, segments_arr, arr_idx, seg_obj);
        arr_idx += 1;
    }

    // Store array and current index in iterator
    setOwned(isolate, context, iter_obj, "__arr__", segments_arr);
    setNumberProperty(isolate, context, iter_obj, "__pos__", 0);

    // Add next() method
    defineMethod(isolate, context, iter_obj, "next", segmentsIteratorNextCallback);

    info.setReturnValue(@ptrCast(iter_obj));
}

/// Callback for iterator.next()
fn segmentsIteratorNextCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const this_obj = info.getThis();
    defer release(this_obj);

    // Get array and position
    const arr_key = v8.v8_String_NewFromUtf8(isolate, "__arr__", 7) orelse return;
    defer release(arr_key);
    const arr_val = v8.v8_Object_Get(this_obj, context, @ptrCast(arr_key)) orelse return;
    defer release(arr_val);
    if (!v8.v8_Value_IsArray(arr_val)) return;
    const arr: *v8.Array = @ptrCast(arr_val);
    const len = v8.v8_Array_Length(arr);

    const pos_key = v8.v8_String_NewFromUtf8(isolate, "__pos__", 7) orelse return;
    defer release(pos_key);
    const pos_val = v8.v8_Object_Get(this_obj, context, @ptrCast(pos_key)) orelse return;
    defer release(pos_val);
    const pos: u32 = @intFromFloat(v8.v8_Value_NumberValue(pos_val, context));

    // Create iterator result
    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    if (pos >= len) {
        // Done
        setBooleanProperty(isolate, context, result, "done", true);
        setOwned(isolate, context, result, "value", v8.v8_Undefined(isolate));
    } else {
        // Get current segment
        const seg_val = v8.v8_Array_Get(context, arr, pos) orelse return;

        setBooleanProperty(isolate, context, result, "done", false);
        setOwned(isolate, context, result, "value", seg_val);

        // Increment position
        setNumberProperty(isolate, context, this_obj, "__pos__", @floatFromInt(pos + 1));
    }

    info.setReturnValue(@ptrCast(result));
}

/// Callback for `segments.containing(index)`
fn segmentsContainingCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    // Get index argument
    if (info.length() < 1) {
        returnUndefined(info);
        return;
    }

    const index_arg = info.get(0);
    defer release(index_arg);
    if (!v8.v8_Value_IsNumber(index_arg)) {
        returnUndefined(info);
        return;
    }
    const index: usize = @intFromFloat(v8.v8_Value_NumberValue(index_arg, context));

    // Get text and granularity
    var text_buf: [4096]u8 = undefined;
    const of = segmentsOf(info, isolate, context, &text_buf) orelse return;

    // Find segment containing the index
    var segments = segmenter_module.Segments.init(of.text, of.granularity);

    if (segments.containing(index)) |seg| {
        returnOwned(info, segmentDataObject(isolate, context, seg, of.text));
    } else {
        returnUndefined(info);
    }
}

/// Callback for `segmenter.resolvedOptions()`
fn segmenterResolvedOptionsCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    const entry = thisState(.segmenter, info) orelse {
        conv.throwTypeError(isolate, "Invalid Segmenter object");
        return;
    };

    // Create options object
    const result = v8.v8_Object_New(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to create options object");
        return;
    };
    defer release(result);

    setStringProperty(isolate, context, result, "locale", entry.locale);
    setStringProperty(isolate, context, result, "granularity", granularityName(entry.granularity));

    info.setReturnValue(@ptrCast(result));
}

/// Callback for `Intl.Segmenter.supportedLocalesOf(locales)`
fn segmenterSupportedLocalesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Return all supported locale tags (same as other Intl objects)
    supportedLocalesOfCallback(info);
}

// ============================================================================
// Phase 3: Intl.Locale
// ============================================================================

/// A Locale's internal slots
const LocaleEntry = struct {
    locale_tag: []const u8,
    language: []const u8,
    script: ?[]const u8,
    region: ?[]const u8,
    calendar: ?[]const u8,
    collation: ?[]const u8,
    hour_cycle: ?[]const u8,
    numbering_system: ?[]const u8,
    case_first: ?[]const u8,
    numeric: bool,
    base_name: []const u8,
    allocator: std.mem.Allocator,

    fn deinit(self: *LocaleEntry) void {
        self.allocator.free(self.locale_tag);
        self.allocator.free(self.language);
        if (self.script) |s| self.allocator.free(s);
        if (self.region) |r| self.allocator.free(r);
        if (self.calendar) |c| self.allocator.free(c);
        if (self.collation) |c| self.allocator.free(c);
        if (self.hour_cycle) |h| self.allocator.free(h);
        if (self.numbering_system) |n| self.allocator.free(n);
        if (self.case_first) |c| self.allocator.free(c);
        self.allocator.free(self.base_name);
    }
};

/// Callback for `new Intl.Locale(tag, options)`
fn localeConstructorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse {
        conv.throwTypeError(isolate, "Failed to get context");
        return;
    };
    defer v8.v8_Context_Dispose(context);

    // Get locale tag argument (required)
    if (info.length() < 1) {
        conv.throwTypeError(isolate, "Intl.Locale requires a locale tag");
        return;
    }

    var tag_buf: [128]u8 = undefined;
    const tag_arg = info.get(0);
    defer release(tag_arg);
    if (!v8.v8_Value_IsString(tag_arg)) {
        conv.throwTypeError(isolate, "First argument must be a string");
        return;
    }

    const tag = readV8String(v8.v8_Value_ToString(tag_arg, context), context, &tag_buf) orelse {
        conv.throwRangeError(isolate, "Invalid locale tag");
        return;
    };

    const objects = agentObjects(isolate) orelse {
        conv.throwTypeError(isolate, "Intl objects need an agent");
        return;
    };
    const allocator = objects.allocator;

    // Parse the locale tag using our Zig parser
    const locale_parser = @import("intl").locale;
    var parsed = locale_parser.Locale.parse(allocator, tag) catch {
        conv.throwRangeError(isolate, "Invalid locale identifier");
        return;
    };
    defer parsed.deinit();

    // Extract options if provided
    var calendar: ?[]const u8 = null;
    var collation: ?[]const u8 = null;
    var hour_cycle: ?[]const u8 = null;
    var numbering_system: ?[]const u8 = null;
    var case_first: ?[]const u8 = null;
    var numeric: bool = false;

    const options = objectArgument(info, 1);
    defer release(options);
    if (options) |options_obj| {
        var buf: [64]u8 = undefined;
        if (stringOption(isolate, context, options_obj, "calendar", &buf)) |val| calendar = allocator.dupe(u8, val) catch null;
        if (stringOption(isolate, context, options_obj, "collation", &buf)) |val| collation = allocator.dupe(u8, val) catch null;
        if (stringOption(isolate, context, options_obj, "hourCycle", &buf)) |val| hour_cycle = allocator.dupe(u8, val) catch null;
        if (stringOption(isolate, context, options_obj, "numberingSystem", &buf)) |val| numbering_system = allocator.dupe(u8, val) catch null;
        if (stringOption(isolate, context, options_obj, "caseFirst", &buf)) |val| case_first = allocator.dupe(u8, val) catch null;
        if (booleanOption(isolate, context, options_obj, "numeric")) |b| numeric = b;
    }

    // Override from unicode extensions if not provided in options
    if (calendar == null and parsed.unicode_extensions.calendar != null) {
        calendar = allocator.dupe(u8, parsed.unicode_extensions.calendar.?) catch null;
    }
    if (collation == null and parsed.unicode_extensions.collation != null) {
        collation = allocator.dupe(u8, parsed.unicode_extensions.collation.?) catch null;
    }
    if (hour_cycle == null and parsed.unicode_extensions.hour_cycle != null) {
        hour_cycle = allocator.dupe(u8, parsed.unicode_extensions.hour_cycle.?.toString()) catch null;
    }
    if (numbering_system == null and parsed.unicode_extensions.numbering_system != null) {
        numbering_system = allocator.dupe(u8, parsed.unicode_extensions.numbering_system.?) catch null;
    }
    if (parsed.unicode_extensions.case_first) |cf| {
        // The tag's -kf- wins over the option: the one the option made goes.
        if (case_first) |previous| allocator.free(previous);
        case_first = allocator.dupe(u8, cf.toString()) catch null;
    }
    if (parsed.unicode_extensions.numeric) |n| {
        numeric = n;
    }

    // Everything the entry would own, freed if it is never made.
    var entry: LocaleEntry = .{
        .locale_tag = &.{},
        .language = &.{},
        .script = null,
        .region = null,
        .calendar = calendar,
        .collation = collation,
        .hour_cycle = hour_cycle,
        .numbering_system = numbering_system,
        .case_first = case_first,
        .numeric = numeric,
        .base_name = &.{},
        .allocator = allocator,
    };
    if (!fillLocaleNames(&entry, &parsed)) {
        entry.deinit();
        conv.throwTypeError(isolate, "Out of memory");
        return;
    }
    // Build the base name (language[-script][-region])
    entry.base_name = parsed.toBaseName(allocator) catch {
        entry.deinit();
        conv.throwTypeError(isolate, "Out of memory");
        return;
    };

    const result = newLocaleObject(isolate, context, entry) orelse return;
    defer release(result);
    info.setReturnValue(@ptrCast(result));
}

/// The entry's tag, language, script and region, from `parsed`, made with
/// the entry's allocator; false when one could not be (the entry stays
/// whole for deinit: what was not made is empty).
fn fillLocaleNames(entry: *LocaleEntry, parsed: *const @import("intl").locale.Locale) bool {
    const allocator = entry.allocator;
    entry.locale_tag = parsed.toString(allocator) catch return false;
    entry.language = allocator.dupe(u8, parsed.language) catch return false;
    entry.script = if (parsed.script) |s| allocator.dupe(u8, s) catch null else null;
    entry.region = if (parsed.region) |r| allocator.dupe(u8, r) catch null else null;
    return true;
}

/// A new Locale object holding `entry` (which it takes over), with its
/// accessors and methods: an owned Global, or null - a TypeError thrown,
/// `entry` freed.
fn newLocaleObject(isolate: *v8.Isolate, context: *v8.Context, entry: LocaleEntry) ?*v8.Object {
    const state: State = .{ .locale = entry };
    const result = v8.v8_Object_New(isolate) orelse {
        var doomed = state;
        doomed.deinit();
        conv.throwTypeError(isolate, "Failed to create Locale object");
        return null;
    };
    if (!adopt(isolate, result, state)) {
        release(result);
        return null;
    }

    // Property getters
    defineMethod(isolate, context, result, "baseName", localeGetBaseName);
    defineMethod(isolate, context, result, "language", localeGetLanguage);
    defineMethod(isolate, context, result, "script", localeGetScript);
    defineMethod(isolate, context, result, "region", localeGetRegion);
    defineMethod(isolate, context, result, "calendar", localeGetCalendar);
    defineMethod(isolate, context, result, "collation", localeGetCollation);
    defineMethod(isolate, context, result, "hourCycle", localeGetHourCycle);
    defineMethod(isolate, context, result, "numberingSystem", localeGetNumberingSystem);
    defineMethod(isolate, context, result, "caseFirst", localeGetCaseFirst);
    defineMethod(isolate, context, result, "numeric", localeGetNumeric);

    // Methods
    defineMethod(isolate, context, result, "maximize", localeMaximize);
    defineMethod(isolate, context, result, "minimize", localeMinimize);
    defineMethod(isolate, context, result, "toString", localeToString);
    defineMethod(isolate, context, result, "getCalendars", localeGetCalendars);
    defineMethod(isolate, context, result, "getCollations", localeGetCollations);
    defineMethod(isolate, context, result, "getHourCycles", localeGetHourCycles);
    defineMethod(isolate, context, result, "getNumberingSystems", localeGetNumberingSystems);
    defineMethod(isolate, context, result, "getTimeZones", localeGetTimeZones);
    defineMethod(isolate, context, result, "getTextInfo", localeGetTextInfo);
    defineMethod(isolate, context, result, "getWeekInfo", localeGetWeekInfo);

    return result;
}

/// The receiver's Locale field `field` as the call's result: a string, or
/// undefined when the field is absent.
fn returnLocaleField(info: *const v8.FunctionCallbackInfo, comptime field: []const u8) void {
    const isolate = info.getIsolate();
    const entry = thisState(.locale, info) orelse return;
    const value = @field(entry, field);
    if (@typeInfo(@TypeOf(value)) == .optional) {
        if (value) |s| returnString(info, isolate, s) else returnUndefined(info);
    } else {
        returnString(info, isolate, value);
    }
}

// Property getters
fn localeGetBaseName(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "base_name");
}

fn localeGetLanguage(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "language");
}

fn localeGetScript(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "script");
}

fn localeGetRegion(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "region");
}

fn localeGetCalendar(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "calendar");
}

fn localeGetCollation(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "collation");
}

fn localeGetHourCycle(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "hour_cycle");
}

fn localeGetNumberingSystem(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "numbering_system");
}

fn localeGetCaseFirst(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "case_first");
}

fn localeGetNumeric(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const entry = thisState(.locale, info) orelse return;
    returnBoolean(info, isolate, entry.numeric);
}

/// A new Locale object from a parsed locale: its names from `parsed`, its
/// Unicode extension options from `original_entry` (the receiver's).
fn createLocaleObject(
    isolate: *v8.Isolate,
    context: *v8.Context,
    parsed: *const @import("intl").locale.Locale,
    original_entry: *const LocaleEntry,
) ?*v8.Object {
    const allocator = original_entry.allocator;

    // Build base name (language-script-region)
    var base_name_buf: [64]u8 = undefined;
    var base_name_len: usize = 0;

    // Copy language
    for (parsed.language) |c| {
        if (base_name_len >= base_name_buf.len) break;
        base_name_buf[base_name_len] = c;
        base_name_len += 1;
    }

    // Add script if present
    if (parsed.script) |script| {
        if (base_name_len < base_name_buf.len) {
            base_name_buf[base_name_len] = '-';
            base_name_len += 1;
        }
        for (script) |c| {
            if (base_name_len >= base_name_buf.len) break;
            base_name_buf[base_name_len] = c;
            base_name_len += 1;
        }
    }

    // Add region if present
    if (parsed.region) |region| {
        if (base_name_len < base_name_buf.len) {
            base_name_buf[base_name_len] = '-';
            base_name_len += 1;
        }
        for (region) |c| {
            if (base_name_len >= base_name_buf.len) break;
            base_name_buf[base_name_len] = c;
            base_name_len += 1;
        }
    }

    // Preserve Unicode extension options from the original
    var entry: LocaleEntry = .{
        .locale_tag = &.{},
        .language = &.{},
        .script = null,
        .region = null,
        .calendar = if (original_entry.calendar) |c| allocator.dupe(u8, c) catch null else null,
        .collation = if (original_entry.collation) |c| allocator.dupe(u8, c) catch null else null,
        .hour_cycle = if (original_entry.hour_cycle) |h| allocator.dupe(u8, h) catch null else null,
        .numbering_system = if (original_entry.numbering_system) |n| allocator.dupe(u8, n) catch null else null,
        .case_first = if (original_entry.case_first) |c| allocator.dupe(u8, c) catch null else null,
        .numeric = original_entry.numeric,
        .base_name = &.{},
        .allocator = allocator,
    };
    if (!fillLocaleNames(&entry, parsed)) {
        entry.deinit();
        return null;
    }
    entry.base_name = allocator.dupe(u8, base_name_buf[0..base_name_len]) catch {
        entry.deinit();
        return null;
    };

    return newLocaleObject(isolate, context, entry);
}

// Methods
fn localeMaximize(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    localeAdjusted(info, .maximize);
}

fn localeMinimize(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    localeAdjusted(info, .minimize);
}

/// maximize() and minimize(): a new Locale of the receiver's tag, adjusted.
fn localeAdjusted(info: *const v8.FunctionCallbackInfo, comptime how: enum { maximize, minimize }) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const entry = thisState(.locale, info) orelse return;

    const locale_parser = @import("intl").locale;

    // Parse and adjust
    var parsed = locale_parser.Locale.parse(entry.allocator, entry.locale_tag) catch return;
    defer parsed.deinit();
    switch (how) {
        .maximize => parsed.maximize() catch return,
        .minimize => parsed.minimize(),
    }

    // Create new Locale object directly
    returnOwned(info, createLocaleObject(isolate, context, &parsed, entry));
}

fn localeToString(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleField(info, "locale_tag");
}

/// `values` as the call's result, an array of strings.
fn returnLocaleList(info: *const v8.FunctionCallbackInfo, values: []const []const u8) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    returnStringArray(info, isolate, context, values);
}

fn localeGetCalendars(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Return common calendars (actual per-locale data would come from CLDR)
    returnLocaleList(info, &.{ "gregory", "buddhist", "chinese", "coptic", "ethiopic", "hebrew", "indian", "islamic", "islamic-civil", "japanese", "persian" });
}

fn localeGetCollations(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleList(info, &.{ "standard", "search", "phonebk", "pinyin", "stroke" });
}

fn localeGetHourCycles(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleList(info, &.{ "h11", "h12", "h23", "h24" });
}

fn localeGetNumberingSystems(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    returnLocaleList(info, &.{ "latn", "arab", "arabext", "beng", "deva", "fullwide", "gujr", "guru", "hanidec", "khmr", "knda", "laoo", "mlym", "mong", "mymr", "orya", "tamldec", "telu", "thai", "tibt" });
}

fn localeGetTimeZones(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const entry = thisState(.locale, info) orelse return;

    // Return time zones based on region (simplified)
    var time_zones: []const []const u8 = &[_][]const u8{};

    if (entry.region) |region| {
        if (std.mem.eql(u8, region, "US")) {
            time_zones = &[_][]const u8{ "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu" };
        } else if (std.mem.eql(u8, region, "GB")) {
            time_zones = &[_][]const u8{"Europe/London"};
        } else if (std.mem.eql(u8, region, "DE")) {
            time_zones = &[_][]const u8{"Europe/Berlin"};
        } else if (std.mem.eql(u8, region, "FR")) {
            time_zones = &[_][]const u8{"Europe/Paris"};
        } else if (std.mem.eql(u8, region, "JP")) {
            time_zones = &[_][]const u8{"Asia/Tokyo"};
        } else if (std.mem.eql(u8, region, "CN")) {
            time_zones = &[_][]const u8{"Asia/Shanghai"};
        } else if (std.mem.eql(u8, region, "AU")) {
            time_zones = &[_][]const u8{ "Australia/Sydney", "Australia/Melbourne", "Australia/Perth" };
        }
    }

    if (time_zones.len == 0) {
        // Return undefined for locales without region
        returnUndefined(info);
        return;
    }

    returnLocaleList(info, time_zones);
}

fn localeGetTextInfo(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const entry = thisState(.locale, info) orelse return;

    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    // Determine text direction based on language
    const direction: []const u8 = if (std.mem.eql(u8, entry.language, "ar") or
        std.mem.eql(u8, entry.language, "he") or
        std.mem.eql(u8, entry.language, "fa") or
        std.mem.eql(u8, entry.language, "ur"))
        "rtl"
    else
        "ltr";
    setStringProperty(isolate, context, result, "direction", direction);

    info.setReturnValue(@ptrCast(result));
}

fn localeGetWeekInfo(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const entry = thisState(.locale, info) orelse return;

    const result = v8.v8_Object_New(isolate) orelse return;
    defer release(result);

    // Default values (would come from CLDR supplemental data)
    var first_day: u8 = 1; // Monday
    var weekend: [2]u8 = .{ 6, 7 }; // Sat, Sun
    const min_days: u8 = 4;

    // Customize based on region
    if (entry.region) |region| {
        if (std.mem.eql(u8, region, "US") or
            std.mem.eql(u8, region, "CA") or
            std.mem.eql(u8, region, "AU") or
            std.mem.eql(u8, region, "JP"))
        {
            first_day = 7; // Sunday
        }
        if (std.mem.eql(u8, region, "SA") or
            std.mem.eql(u8, region, "AE") or
            std.mem.eql(u8, region, "EG"))
        {
            first_day = 6; // Saturday
            weekend = .{ 5, 6 }; // Fri, Sat
        }
    }

    setNumberProperty(isolate, context, result, "firstDay", @floatFromInt(first_day));
    setNumberProperty(isolate, context, result, "minimalDays", @floatFromInt(min_days));

    // Create weekend array
    const weekend_arr = v8.v8_Array_New(isolate, 2);
    for (weekend, 0..) |day, i| setElementOwned(context, weekend_arr, @intCast(i), v8.v8_Number_New(isolate, @floatFromInt(day)));
    setOwned(isolate, context, result, "weekend", weekend_arr);

    info.setReturnValue(@ptrCast(result));
}

// ============================================================================
// Phase 3: Intl.supportedValuesOf
// ============================================================================

/// Intl.supportedValuesOf callback
fn supportedValuesOfCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    if (info.length() < 1) {
        conv.throwTypeError(isolate, "supportedValuesOf requires a key argument");
        return;
    }

    var key_buf: [32]u8 = undefined;
    const key_arg = info.get(0);
    defer release(key_arg);
    if (!v8.v8_Value_IsString(key_arg)) {
        conv.throwRangeError(isolate, "Invalid key");
        return;
    }

    const key = readV8String(v8.v8_Value_ToString(key_arg, context), context, &key_buf) orelse {
        conv.throwRangeError(isolate, "Invalid key");
        return;
    };

    // Get supported values based on key
    if (std.mem.eql(u8, key, "calendar")) {
        const calendars = [_][]const u8{ "gregory", "buddhist", "chinese", "coptic", "dangi", "ethiopic", "hebrew", "indian", "islamic", "islamic-civil", "islamic-rgsa", "islamic-tbla", "islamic-umalqura", "japanese", "persian", "roc" };
        createStringArray(isolate, context, &calendars, info);
    } else if (std.mem.eql(u8, key, "collation")) {
        const collations = [_][]const u8{ "big5han", "compat", "dict", "direct", "ducet", "emoji", "eor", "gb2312", "phonebk", "phonetic", "pinyin", "reformed", "search", "searchjl", "standard", "stroke", "trad", "unihan", "zhuyin" };
        createStringArray(isolate, context, &collations, info);
    } else if (std.mem.eql(u8, key, "currency")) {
        const currencies = [_][]const u8{ "AED", "AFN", "ALL", "AMD", "ANG", "AOA", "ARS", "AUD", "AWG", "AZN", "BAM", "BBD", "BDT", "BGN", "BHD", "BIF", "BMD", "BND", "BOB", "BRL", "BSD", "BTN", "BWP", "BYN", "BZD", "CAD", "CDF", "CHF", "CLP", "CNY", "COP", "CRC", "CUC", "CUP", "CVE", "CZK", "DJF", "DKK", "DOP", "DZD", "EGP", "ERN", "ETB", "EUR", "FJD", "FKP", "GBP", "GEL", "GGP", "GHS", "GIP", "GMD", "GNF", "GTQ", "GYD", "HKD", "HNL", "HRK", "HTG", "HUF", "IDR", "ILS", "IMP", "INR", "IQD", "IRR", "ISK", "JEP", "JMD", "JOD", "JPY", "KES", "KGS", "KHR", "KMF", "KPW", "KRW", "KWD", "KYD", "KZT", "LAK", "LBP", "LKR", "LRD", "LSL", "LYD", "MAD", "MDL", "MGA", "MKD", "MMK", "MNT", "MOP", "MRU", "MUR", "MVR", "MWK", "MXN", "MYR", "MZN", "NAD", "NGN", "NIO", "NOK", "NPR", "NZD", "OMR", "PAB", "PEN", "PGK", "PHP", "PKR", "PLN", "PYG", "QAR", "RON", "RSD", "RUB", "RWF", "SAR", "SBD", "SCR", "SDG", "SEK", "SGD", "SHP", "SLL", "SOS", "SPL", "SRD", "STN", "SVC", "SYP", "SZL", "THB", "TJS", "TMT", "TND", "TOP", "TRY", "TTD", "TVD", "TWD", "TZS", "UAH", "UGX", "USD", "UYU", "UZS", "VEF", "VND", "VUV", "WST", "XAF", "XCD", "XDR", "XOF", "XPF", "YER", "ZAR", "ZMW", "ZWD" };
        createStringArray(isolate, context, &currencies, info);
    } else if (std.mem.eql(u8, key, "numberingSystem")) {
        const numbering_systems = [_][]const u8{ "adlm", "ahom", "arab", "arabext", "bali", "beng", "bhks", "brah", "cakm", "cham", "deva", "diak", "fullwide", "gong", "gonm", "gujr", "guru", "hanidec", "hmng", "hmnp", "java", "kali", "khmr", "knda", "lana", "lanatham", "laoo", "latn", "lepc", "limb", "mathbold", "mathdbl", "mathmono", "mathsanb", "mathsans", "mlym", "modi", "mong", "mroo", "mtei", "mymr", "mymrshan", "mymrtlng", "newa", "nkoo", "olck", "orya", "osma", "rohg", "saur", "segment", "shrd", "sind", "sinh", "sora", "sund", "takr", "talu", "tamldec", "telu", "thai", "tibt", "tirh", "vaii", "wara", "wcho" };
        createStringArray(isolate, context, &numbering_systems, info);
    } else if (std.mem.eql(u8, key, "timeZone")) {
        const time_zones = [_][]const u8{ "Africa/Abidjan", "Africa/Cairo", "Africa/Johannesburg", "Africa/Lagos", "America/Chicago", "America/Denver", "America/Los_Angeles", "America/New_York", "America/Sao_Paulo", "America/Toronto", "Asia/Dubai", "Asia/Hong_Kong", "Asia/Kolkata", "Asia/Seoul", "Asia/Shanghai", "Asia/Singapore", "Asia/Tokyo", "Australia/Melbourne", "Australia/Sydney", "Europe/Berlin", "Europe/London", "Europe/Moscow", "Europe/Paris", "Pacific/Auckland", "UTC" };
        createStringArray(isolate, context, &time_zones, info);
    } else if (std.mem.eql(u8, key, "unit")) {
        const units = [_][]const u8{ "acre", "bit", "byte", "celsius", "centimeter", "day", "degree", "fahrenheit", "fluid-ounce", "foot", "gallon", "gigabit", "gigabyte", "gram", "hectare", "hour", "inch", "kilobit", "kilobyte", "kilogram", "kilometer", "liter", "megabit", "megabyte", "meter", "mile", "mile-scandinavian", "milliliter", "millimeter", "millisecond", "minute", "month", "ounce", "percent", "petabyte", "pound", "second", "stone", "terabit", "terabyte", "week", "yard", "year" };
        createStringArray(isolate, context, &units, info);
    } else {
        conv.throwRangeError(isolate, "Invalid key for supportedValuesOf");
        return;
    }
}

fn createStringArray(isolate: *v8.Isolate, context: *v8.Context, values: []const []const u8, info: *const v8.FunctionCallbackInfo) void {
    returnStringArray(info, isolate, context, values);
}

// ============================================================================
// Public API
// ============================================================================

/// Register the Intl global object with V8
pub fn registerGlobal(isolate: *v8.Isolate, context: *v8.Context) void {
    // Every handle below is released (see registerToLocaleStringMethods):
    // the Intl object and its constructors are the realm's, and the realm's
    // global keeps them.
    const intl_obj = v8.v8_Object_New(isolate) orelse return;
    defer v8.v8_Object_Dispose(intl_obj);
    const supported_key = v8.v8_String_NewFromUtf8(isolate, "supportedLocalesOf", 18) orelse return;
    defer v8.v8_String_Dispose(supported_key);

    // The constructors, each with its supportedLocalesOf static method.
    const constructors = [_]IntlConstructor{
        .{ .name = "DateTimeFormat", .constructor = dateTimeFormatConstructorCallback, .supported_locales_of = supportedLocalesOfCallback },
        .{ .name = "NumberFormat", .constructor = numberFormatConstructorCallback, .supported_locales_of = numberFormatSupportedLocalesOfCallback },
        .{ .name = "Collator", .constructor = collatorConstructorCallback, .supported_locales_of = collatorSupportedLocalesOfCallback },
        .{ .name = "PluralRules", .constructor = pluralRulesConstructorCallback, .supported_locales_of = pluralRulesSupportedLocalesOfCallback },
        .{ .name = "RelativeTimeFormat", .constructor = relativeTimeFormatConstructorCallback, .supported_locales_of = relativeTimeFormatSupportedLocalesOfCallback },
        .{ .name = "ListFormat", .constructor = listFormatConstructorCallback, .supported_locales_of = listFormatSupportedLocalesOfCallback },
        .{ .name = "DisplayNames", .constructor = displayNamesConstructorCallback, .supported_locales_of = displayNamesSupportedLocalesOfCallback },
        .{ .name = "Locale", .constructor = localeConstructorCallback, .supported_locales_of = null },
        .{ .name = "Segmenter", .constructor = segmenterConstructorCallback, .supported_locales_of = segmenterSupportedLocalesOfCallback },
    };
    for (constructors) |c| defineIntlConstructor(isolate, context, intl_obj, supported_key, c);

    // Intl.supportedValuesOf (static method on Intl object)
    if (v8.v8_FunctionTemplate_New(isolate, supportedValuesOfCallback, null)) |svo_fn| {
        defer v8.v8_FunctionTemplate_Dispose(svo_fn);
        if (v8.v8_FunctionTemplate_GetFunction(svo_fn, context)) |svo_fn_obj| {
            defer v8.v8_Function_Dispose(svo_fn_obj);
            if (v8.v8_String_NewFromUtf8(isolate, "supportedValuesOf", 17)) |svo_key| {
                defer v8.v8_String_Dispose(svo_key);
                _ = v8.v8_Object_Set(intl_obj, context, @ptrCast(svo_key), @ptrCast(svo_fn_obj));
            }
        }
    }

    // Add Intl to the global object: writable, configurable, not enumerable.
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);
    const intl_key = v8.v8_String_NewFromUtf8(isolate, "Intl", 4) orelse return;
    defer v8.v8_String_Dispose(intl_key);

    _ = v8.v8_Object_DefineProperty(
        global,
        context,
        @ptrCast(intl_key),
        @ptrCast(intl_obj),
        true,
        false,
        true,
    );
}

const IntlConstructor = struct {
    name: []const u8,
    constructor: v8.FunctionCallback,
    supported_locales_of: ?v8.FunctionCallback,
};

/// `Intl[c.name]`: the constructor, with its supportedLocalesOf.
fn defineIntlConstructor(isolate: *v8.Isolate, context: *v8.Context, intl_object: *v8.Object, supported_key: *v8.String, c: IntlConstructor) void {
    const template = v8.v8_FunctionTemplate_New(isolate, c.constructor, null) orelse return;
    defer v8.v8_FunctionTemplate_Dispose(template);
    const constructor = v8.v8_FunctionTemplate_GetFunction(template, context) orelse return;
    defer v8.v8_Function_Dispose(constructor);

    if (c.supported_locales_of) |callback| {
        if (v8.v8_FunctionTemplate_New(isolate, callback, null)) |supported_template| {
            defer v8.v8_FunctionTemplate_Dispose(supported_template);
            if (v8.v8_FunctionTemplate_GetFunction(supported_template, context)) |supported| {
                defer v8.v8_Function_Dispose(supported);
                _ = v8.v8_Object_Set(@ptrCast(constructor), context, @ptrCast(supported_key), @ptrCast(supported));
            }
        }
    }

    const key = v8.v8_String_NewFromUtf8(isolate, c.name.ptr, @intCast(c.name.len)) orelse return;
    defer v8.v8_String_Dispose(key);
    _ = v8.v8_Object_Set(intl_object, context, @ptrCast(key), @ptrCast(constructor));
}

/// Register external references for V8 snapshots
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");

    // DateTimeFormat
    ext_refs.registerCallbackRuntime(dateTimeFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatFormatCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatToPartsCallback);
    ext_refs.registerCallbackRuntime(dateTimeFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(supportedLocalesOfCallback);

    // NumberFormat
    ext_refs.registerCallbackRuntime(numberFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(numberFormatFormatCallback);
    ext_refs.registerCallbackRuntime(numberFormatToPartsCallback);
    ext_refs.registerCallbackRuntime(numberFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(numberFormatSupportedLocalesOfCallback);

    // Collator
    ext_refs.registerCallbackRuntime(collatorConstructorCallback);
    ext_refs.registerCallbackRuntime(collatorCompareCallback);
    ext_refs.registerCallbackRuntime(collatorResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(collatorSupportedLocalesOfCallback);

    // toLocaleString methods
    ext_refs.registerCallbackRuntime(numberToLocaleStringCallback);
    ext_refs.registerCallbackRuntime(dateToLocaleStringCallback);
    ext_refs.registerCallbackRuntime(dateToLocaleDateStringCallback);
    ext_refs.registerCallbackRuntime(dateToLocaleTimeStringCallback);

    // PluralRules
    ext_refs.registerCallbackRuntime(pluralRulesConstructorCallback);
    ext_refs.registerCallbackRuntime(pluralRulesSelectCallback);
    ext_refs.registerCallbackRuntime(pluralRulesResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(pluralRulesSupportedLocalesOfCallback);

    // RelativeTimeFormat
    ext_refs.registerCallbackRuntime(relativeTimeFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(relativeTimeFormatFormatCallback);
    ext_refs.registerCallbackRuntime(relativeTimeFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(relativeTimeFormatSupportedLocalesOfCallback);

    // ListFormat
    ext_refs.registerCallbackRuntime(listFormatConstructorCallback);
    ext_refs.registerCallbackRuntime(listFormatFormatCallback);
    ext_refs.registerCallbackRuntime(listFormatResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(listFormatSupportedLocalesOfCallback);

    // DisplayNames
    ext_refs.registerCallbackRuntime(displayNamesConstructorCallback);
    ext_refs.registerCallbackRuntime(displayNamesOfCallback);
    ext_refs.registerCallbackRuntime(displayNamesResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(displayNamesSupportedLocalesOfCallback);

    // Locale
    ext_refs.registerCallbackRuntime(localeConstructorCallback);
    ext_refs.registerCallbackRuntime(localeGetBaseName);
    ext_refs.registerCallbackRuntime(localeGetLanguage);
    ext_refs.registerCallbackRuntime(localeGetScript);
    ext_refs.registerCallbackRuntime(localeGetRegion);
    ext_refs.registerCallbackRuntime(localeGetCalendar);
    ext_refs.registerCallbackRuntime(localeGetCollation);
    ext_refs.registerCallbackRuntime(localeGetHourCycle);
    ext_refs.registerCallbackRuntime(localeGetNumberingSystem);
    ext_refs.registerCallbackRuntime(localeGetCaseFirst);
    ext_refs.registerCallbackRuntime(localeGetNumeric);
    ext_refs.registerCallbackRuntime(localeMaximize);
    ext_refs.registerCallbackRuntime(localeMinimize);
    ext_refs.registerCallbackRuntime(localeToString);
    ext_refs.registerCallbackRuntime(localeGetCalendars);
    ext_refs.registerCallbackRuntime(localeGetCollations);
    ext_refs.registerCallbackRuntime(localeGetHourCycles);
    ext_refs.registerCallbackRuntime(localeGetNumberingSystems);
    ext_refs.registerCallbackRuntime(localeGetTimeZones);
    ext_refs.registerCallbackRuntime(localeGetTextInfo);
    ext_refs.registerCallbackRuntime(localeGetWeekInfo);

    // Intl.supportedValuesOf
    ext_refs.registerCallbackRuntime(supportedValuesOfCallback);

    // Segmenter
    ext_refs.registerCallbackRuntime(segmenterConstructorCallback);
    ext_refs.registerCallbackRuntime(segmenterSegmentCallback);
    ext_refs.registerCallbackRuntime(segmentsIteratorCallback);
    ext_refs.registerCallbackRuntime(segmentsIteratorNextCallback);
    ext_refs.registerCallbackRuntime(segmentsContainingCallback);
    ext_refs.registerCallbackRuntime(segmenterResolvedOptionsCallback);
    ext_refs.registerCallbackRuntime(segmenterSupportedLocalesOfCallback);
}
// ============================================================================
// Tests
// ============================================================================

test "DateTime.fromTimestampMillis" {
    const testing = std.testing;

    // 2023-11-14 12:30:45 UTC
    const dt = DateTime.fromTimestampMillis(1699964445000);
    try testing.expectEqual(@as(i32, 2023), dt.year);
    try testing.expectEqual(@as(u8, 11), dt.month);
    try testing.expectEqual(@as(u8, 14), dt.day);
    try testing.expectEqual(@as(u8, 12), dt.hour);
    try testing.expectEqual(@as(u8, 27), dt.minute); // Close to 30
}

test "resolveLocale" {
    const testing = std.testing;

    // Exact match
    const en = resolveLocale("en");
    try testing.expect(en != null);

    // With fallback
    const en_us = resolveLocale("en-US");
    try testing.expect(en_us != null);

    // Unknown locale falls back to en
    const unknown = resolveLocale("xx-YY");
    try testing.expect(unknown != null);
}

test "formatWithPattern" {
    const dt = DateTime{
        .year = 2024,
        .month = 12,
        .day = 13,
        .hour = 14,
        .minute = 30,
        .second = 45,
    };

    const locale_data = cldr_embedded.getLocale("en").?;
    var buf: [256]u8 = undefined;

    // Simple date pattern
    const result = formatWithPattern(&buf, "yyyy-MM-dd", dt, locale_data);
    const testing = std.testing;
    try testing.expectEqualStrings("2024-12-13", result);
}

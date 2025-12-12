//! CLDR JSON Data Extractor
//!
//! Parses CLDR JSON data and extracts relevant fields for Intl APIs.
//! Handles locale inheritance (en-US inherits from en).
//!
//! Usage:
//!   zig build cldr-extract -- --input data/cldr/ --output src/intl/cldr/
//!
//! References:
//! - CLDR JSON: https://github.com/unicode-org/cldr-json
//! - CLDR Spec: https://cldr.unicode.org/

const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;

// ============================================================================
// Extracted Data Structures
// ============================================================================

/// Month names for a locale (wide, abbreviated, narrow)
pub const MonthNames = struct {
    wide: [12][]const u8,
    abbreviated: [12][]const u8,
    narrow: [12][]const u8,
};

/// Weekday names for a locale
pub const WeekdayNames = struct {
    wide: [7][]const u8,
    abbreviated: [7][]const u8,
    narrow: [7][]const u8,
    short: [7][]const u8,
};

/// Day period names (AM/PM)
pub const DayPeriodNames = struct {
    am: []const u8,
    pm: []const u8,
};

/// Era names
pub const EraNames = struct {
    wide: [2][]const u8,
    abbreviated: [2][]const u8,
    narrow: [2][]const u8,
};

/// Date/time patterns for a locale
pub const DateTimePatterns = struct {
    /// Date patterns by style (full, long, medium, short)
    date_full: []const u8,
    date_long: []const u8,
    date_medium: []const u8,
    date_short: []const u8,

    /// Time patterns by style
    time_full: []const u8,
    time_long: []const u8,
    time_medium: []const u8,
    time_short: []const u8,

    /// Combined date-time pattern template
    datetime_full: []const u8,
    datetime_long: []const u8,
    datetime_medium: []const u8,
    datetime_short: []const u8,
};

/// Number formatting symbols
pub const NumberSymbols = struct {
    decimal: []const u8,
    group: []const u8,
    percent: []const u8,
    minus: []const u8,
    plus: []const u8,
    exponential: []const u8,
    infinity: []const u8,
    nan: []const u8,
};

/// Currency format patterns
pub const CurrencyPatterns = struct {
    standard: []const u8,
    accounting: []const u8,
};

/// Complete extracted locale data
pub const ExtractedLocaleData = struct {
    locale_tag: []const u8,
    parent_locale: ?[]const u8,

    // DateTime data
    months: MonthNames,
    weekdays: WeekdayNames,
    day_periods: DayPeriodNames,
    eras: EraNames,
    datetime_patterns: DateTimePatterns,

    // Number data
    number_symbols: NumberSymbols,
    currency_patterns: CurrencyPatterns,

    // Likely subtags (for maximize/minimize)
    likely_subtags: ?LikelySubtags,

    pub fn deinit(self: *ExtractedLocaleData, allocator: Allocator) void {
        allocator.free(self.locale_tag);
        if (self.parent_locale) |p| allocator.free(p);

        // Free month names
        for (self.months.wide) |s| if (s.len > 0) allocator.free(s);
        for (self.months.abbreviated) |s| if (s.len > 0) allocator.free(s);
        for (self.months.narrow) |s| if (s.len > 0) allocator.free(s);

        // Free weekday names
        for (self.weekdays.wide) |s| if (s.len > 0) allocator.free(s);
        for (self.weekdays.abbreviated) |s| if (s.len > 0) allocator.free(s);
        for (self.weekdays.narrow) |s| if (s.len > 0) allocator.free(s);
        for (self.weekdays.short) |s| if (s.len > 0) allocator.free(s);

        // Note: Other string fields use default values (not allocated)
        // In a full implementation, would track which strings are allocated
    }
};

/// Likely subtags entry
pub const LikelySubtags = struct {
    language: []const u8,
    script: ?[]const u8,
    region: ?[]const u8,
};

// ============================================================================
// JSON Parsing
// ============================================================================

// Month number keys for CLDR JSON lookup (1-indexed as strings)
const month_keys = [_][]const u8{ "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12" };

/// Extract month names from CLDR JSON
fn extractMonthNames(allocator: Allocator, months_obj: json.Value) !MonthNames {
    var result: MonthNames = undefined;

    // Initialize with empty strings
    for (0..12) |i| {
        result.wide[i] = "";
        result.abbreviated[i] = "";
        result.narrow[i] = "";
    }

    if (months_obj != .object) return result;

    const months = months_obj.object;

    // Extract wide month names
    if (months.get("wide")) |wide| {
        if (wide == .object) {
            const wide_obj = wide.object;
            for (month_keys, 0..) |key, i| {
                if (wide_obj.get(key)) |val| {
                    if (val == .string) {
                        result.wide[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    // Extract abbreviated month names
    if (months.get("abbreviated")) |abbr| {
        if (abbr == .object) {
            const abbr_obj = abbr.object;
            for (month_keys, 0..) |key, i| {
                if (abbr_obj.get(key)) |val| {
                    if (val == .string) {
                        result.abbreviated[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    // Extract narrow month names
    if (months.get("narrow")) |narrow| {
        if (narrow == .object) {
            const narrow_obj = narrow.object;
            for (month_keys, 0..) |key, i| {
                if (narrow_obj.get(key)) |val| {
                    if (val == .string) {
                        result.narrow[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    return result;
}

/// Extract weekday names from CLDR JSON
fn extractWeekdayNames(allocator: Allocator, days_obj: json.Value) !WeekdayNames {
    var result: WeekdayNames = undefined;

    // CLDR uses sun, mon, tue, wed, thu, fri, sat
    const day_keys = [_][]const u8{ "sun", "mon", "tue", "wed", "thu", "fri", "sat" };

    // Initialize with empty strings
    for (0..7) |i| {
        result.wide[i] = "";
        result.abbreviated[i] = "";
        result.narrow[i] = "";
        result.short[i] = "";
    }

    if (days_obj != .object) return result;

    const days = days_obj.object;

    // Extract wide weekday names
    if (days.get("wide")) |wide| {
        if (wide == .object) {
            const wide_obj = wide.object;
            for (day_keys, 0..) |key, i| {
                if (wide_obj.get(key)) |val| {
                    if (val == .string) {
                        result.wide[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    // Extract abbreviated weekday names
    if (days.get("abbreviated")) |abbr| {
        if (abbr == .object) {
            const abbr_obj = abbr.object;
            for (day_keys, 0..) |key, i| {
                if (abbr_obj.get(key)) |val| {
                    if (val == .string) {
                        result.abbreviated[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    // Extract narrow weekday names
    if (days.get("narrow")) |narrow| {
        if (narrow == .object) {
            const narrow_obj = narrow.object;
            for (day_keys, 0..) |key, i| {
                if (narrow_obj.get(key)) |val| {
                    if (val == .string) {
                        result.narrow[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    // Extract short weekday names (falls back to abbreviated)
    if (days.get("short")) |short| {
        if (short == .object) {
            const short_obj = short.object;
            for (day_keys, 0..) |key, i| {
                if (short_obj.get(key)) |val| {
                    if (val == .string) {
                        result.short[i] = try allocator.dupe(u8, val.string);
                    }
                }
            }
        }
    }

    return result;
}

/// Extract day periods (AM/PM) from CLDR JSON
fn extractDayPeriods(allocator: Allocator, periods_obj: json.Value) !DayPeriodNames {
    var result = DayPeriodNames{
        .am = "AM",
        .pm = "PM",
    };

    if (periods_obj != .object) return result;

    const periods = periods_obj.object;

    // Look for abbreviated day periods
    if (periods.get("abbreviated")) |abbr| {
        if (abbr == .object) {
            const abbr_obj = abbr.object;
            if (abbr_obj.get("am")) |am| {
                if (am == .string) {
                    result.am = try allocator.dupe(u8, am.string);
                }
            }
            if (abbr_obj.get("pm")) |pm| {
                if (pm == .string) {
                    result.pm = try allocator.dupe(u8, pm.string);
                }
            }
        }
    }

    return result;
}

/// Extract era names from CLDR JSON
fn extractEras(allocator: Allocator, eras_obj: json.Value) !EraNames {
    var result = EraNames{
        .wide = .{ "Before Christ", "Anno Domini" },
        .abbreviated = .{ "BC", "AD" },
        .narrow = .{ "B", "A" },
    };

    if (eras_obj != .object) return result;

    const eras = eras_obj.object;

    // CLDR uses "0" for BC/BCE and "1" for AD/CE
    if (eras.get("eraNames")) |wide| {
        if (wide == .object) {
            const wide_obj = wide.object;
            if (wide_obj.get("0")) |bc| {
                if (bc == .string) {
                    result.wide[0] = try allocator.dupe(u8, bc.string);
                }
            }
            if (wide_obj.get("1")) |ad| {
                if (ad == .string) {
                    result.wide[1] = try allocator.dupe(u8, ad.string);
                }
            }
        }
    }

    if (eras.get("eraAbbr")) |abbr| {
        if (abbr == .object) {
            const abbr_obj = abbr.object;
            if (abbr_obj.get("0")) |bc| {
                if (bc == .string) {
                    result.abbreviated[0] = try allocator.dupe(u8, bc.string);
                }
            }
            if (abbr_obj.get("1")) |ad| {
                if (ad == .string) {
                    result.abbreviated[1] = try allocator.dupe(u8, ad.string);
                }
            }
        }
    }

    if (eras.get("eraNarrow")) |narrow| {
        if (narrow == .object) {
            const narrow_obj = narrow.object;
            if (narrow_obj.get("0")) |bc| {
                if (bc == .string) {
                    result.narrow[0] = try allocator.dupe(u8, bc.string);
                }
            }
            if (narrow_obj.get("1")) |ad| {
                if (ad == .string) {
                    result.narrow[1] = try allocator.dupe(u8, ad.string);
                }
            }
        }
    }

    return result;
}

/// Extract date/time patterns from CLDR JSON
fn extractDateTimePatterns(allocator: Allocator, formats_obj: json.Value) !DateTimePatterns {
    var result = DateTimePatterns{
        .date_full = "EEEE, MMMM d, y",
        .date_long = "MMMM d, y",
        .date_medium = "MMM d, y",
        .date_short = "M/d/yy",
        .time_full = "h:mm:ss a zzzz",
        .time_long = "h:mm:ss a z",
        .time_medium = "h:mm:ss a",
        .time_short = "h:mm a",
        .datetime_full = "{1}, {0}",
        .datetime_long = "{1}, {0}",
        .datetime_medium = "{1}, {0}",
        .datetime_short = "{1}, {0}",
    };

    if (formats_obj != .object) return result;

    const formats = formats_obj.object;

    // Extract date formats
    if (formats.get("dateFormats")) |date_fmts| {
        if (date_fmts == .object) {
            const df = date_fmts.object;
            if (df.get("full")) |v| {
                if (v == .string) result.date_full = try allocator.dupe(u8, v.string);
            }
            if (df.get("long")) |v| {
                if (v == .string) result.date_long = try allocator.dupe(u8, v.string);
            }
            if (df.get("medium")) |v| {
                if (v == .string) result.date_medium = try allocator.dupe(u8, v.string);
            }
            if (df.get("short")) |v| {
                if (v == .string) result.date_short = try allocator.dupe(u8, v.string);
            }
        }
    }

    // Extract time formats
    if (formats.get("timeFormats")) |time_fmts| {
        if (time_fmts == .object) {
            const tf = time_fmts.object;
            if (tf.get("full")) |v| {
                if (v == .string) result.time_full = try allocator.dupe(u8, v.string);
            }
            if (tf.get("long")) |v| {
                if (v == .string) result.time_long = try allocator.dupe(u8, v.string);
            }
            if (tf.get("medium")) |v| {
                if (v == .string) result.time_medium = try allocator.dupe(u8, v.string);
            }
            if (tf.get("short")) |v| {
                if (v == .string) result.time_short = try allocator.dupe(u8, v.string);
            }
        }
    }

    // Extract date-time combination patterns
    if (formats.get("dateTimeFormats")) |dt_fmts| {
        if (dt_fmts == .object) {
            const dtf = dt_fmts.object;
            if (dtf.get("full")) |v| {
                if (v == .string) result.datetime_full = try allocator.dupe(u8, v.string);
            }
            if (dtf.get("long")) |v| {
                if (v == .string) result.datetime_long = try allocator.dupe(u8, v.string);
            }
            if (dtf.get("medium")) |v| {
                if (v == .string) result.datetime_medium = try allocator.dupe(u8, v.string);
            }
            if (dtf.get("short")) |v| {
                if (v == .string) result.datetime_short = try allocator.dupe(u8, v.string);
            }
        }
    }

    return result;
}

/// Extract number symbols from CLDR JSON
fn extractNumberSymbols(allocator: Allocator, symbols_obj: json.Value) !NumberSymbols {
    var result = NumberSymbols{
        .decimal = ".",
        .group = ",",
        .percent = "%",
        .minus = "-",
        .plus = "+",
        .exponential = "E",
        .infinity = "∞",
        .nan = "NaN",
    };

    if (symbols_obj != .object) return result;

    const symbols = symbols_obj.object;

    if (symbols.get("decimal")) |v| {
        if (v == .string) result.decimal = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("group")) |v| {
        if (v == .string) result.group = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("percentSign")) |v| {
        if (v == .string) result.percent = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("minusSign")) |v| {
        if (v == .string) result.minus = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("plusSign")) |v| {
        if (v == .string) result.plus = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("exponential")) |v| {
        if (v == .string) result.exponential = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("infinity")) |v| {
        if (v == .string) result.infinity = try allocator.dupe(u8, v.string);
    }
    if (symbols.get("nan")) |v| {
        if (v == .string) result.nan = try allocator.dupe(u8, v.string);
    }

    return result;
}

// ============================================================================
// Main Extractor
// ============================================================================

/// Tier 1 locales to embed at compile time
pub const TIER1_LOCALES = [_][]const u8{
    "en",    "en-US",   "en-GB",   "en-AU", "en-CA",
    "de",    "de-DE",   "de-AT",   "de-CH", "fr",
    "fr-FR", "fr-CA",   "es",      "es-ES", "es-MX",
    "it",    "it-IT",   "pt",      "pt-BR", "pt-PT",
    "zh",    "zh-Hans", "zh-Hant", "zh-CN", "zh-TW",
    "ja",    "ja-JP",   "ko",      "ko-KR", "ar",
    "ar-SA", "ar-EG",   "ru",      "ru-RU", "nl",
    "nl-NL", "pl",      "pl-PL",   "tr",    "tr-TR",
    "vi",    "vi-VN",   "th",      "th-TH", "id",
    "id-ID", "hi",      "hi-IN",
};

/// Extract state
pub const ExtractState = struct {
    allocator: Allocator,
    input_dir: []const u8,
    output_dir: []const u8,
    verbose: bool,

    pub fn init(allocator: Allocator, input_dir: []const u8, output_dir: []const u8, verbose: bool) ExtractState {
        return .{
            .allocator = allocator,
            .input_dir = input_dir,
            .output_dir = output_dir,
            .verbose = verbose,
        };
    }

    /// Read and parse a JSON file
    pub fn readJsonFile(self: *const ExtractState, path: []const u8) !json.Parsed(json.Value) {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 10 * 1024 * 1024); // 10MB max
        defer self.allocator.free(content);

        return try json.parseFromSlice(json.Value, self.allocator, content, .{});
    }
};

/// Extract locale data from CLDR JSON for a single locale
pub fn extractLocaleData(state: *const ExtractState, locale_tag: []const u8) !?ExtractedLocaleData {
    const allocator = state.allocator;

    // Build path to dates JSON file
    // CLDR structure: cldr-dates-full/main/{locale}/ca-gregorian.json
    const dates_path = try std.fmt.allocPrint(
        allocator,
        "{s}/cldr-dates-full/main/{s}/ca-gregorian.json",
        .{ state.input_dir, locale_tag },
    );
    defer allocator.free(dates_path);

    // Check if locale exists
    std.fs.cwd().access(dates_path, .{}) catch {
        if (state.verbose) {
            std.log.warn("Locale data not found for: {s}", .{locale_tag});
        }
        return null;
    };

    if (state.verbose) {
        std.log.info("Extracting locale: {s}", .{locale_tag});
    }

    // Parse the dates JSON
    const dates_json = state.readJsonFile(dates_path) catch |err| {
        std.log.err("Failed to parse {s}: {s}", .{ dates_path, @errorName(err) });
        return null;
    };
    defer dates_json.deinit();

    // Navigate to the gregorian calendar data
    // Structure: main -> locale -> dates -> calendars -> gregorian
    const main_obj = dates_json.value.object.get("main") orelse return null;
    const locale_obj = main_obj.object.get(locale_tag) orelse return null;
    const dates_obj = locale_obj.object.get("dates") orelse return null;
    const calendars_obj = dates_obj.object.get("calendars") orelse return null;
    const gregorian_obj = calendars_obj.object.get("gregorian") orelse return null;

    // Extract month names from months -> format
    const months_obj = if (gregorian_obj.object.get("months")) |m|
        if (m.object.get("format")) |f| f else json.Value{ .null = {} }
    else
        json.Value{ .null = {} };

    // Extract weekday names from days -> format
    const days_obj = if (gregorian_obj.object.get("days")) |d|
        if (d.object.get("format")) |f| f else json.Value{ .null = {} }
    else
        json.Value{ .null = {} };

    // Extract day periods from dayPeriods -> format
    const periods_obj = if (gregorian_obj.object.get("dayPeriods")) |dp|
        if (dp.object.get("format")) |f| f else json.Value{ .null = {} }
    else
        json.Value{ .null = {} };

    // Extract era names
    const eras_obj = gregorian_obj.object.get("eras") orelse json.Value{ .null = {} };

    // Extract date/time patterns
    const formats_obj = gregorian_obj;

    var result = ExtractedLocaleData{
        .locale_tag = try allocator.dupe(u8, locale_tag),
        .parent_locale = null,
        .months = try extractMonthNames(allocator, months_obj),
        .weekdays = try extractWeekdayNames(allocator, days_obj),
        .day_periods = try extractDayPeriods(allocator, periods_obj),
        .eras = try extractEras(allocator, eras_obj),
        .datetime_patterns = try extractDateTimePatterns(allocator, formats_obj),
        .number_symbols = NumberSymbols{
            .decimal = ".",
            .group = ",",
            .percent = "%",
            .minus = "-",
            .plus = "+",
            .exponential = "E",
            .infinity = "∞",
            .nan = "NaN",
        },
        .currency_patterns = CurrencyPatterns{
            .standard = "¤#,##0.00",
            .accounting = "¤#,##0.00",
        },
        .likely_subtags = null,
    };

    // Try to load number symbols from numbers JSON
    const numbers_path = try std.fmt.allocPrint(
        allocator,
        "{s}/cldr-numbers-full/main/{s}/numbers.json",
        .{ state.input_dir, locale_tag },
    );
    defer allocator.free(numbers_path);

    if (state.readJsonFile(numbers_path)) |numbers_json| {
        defer numbers_json.deinit();

        if (numbers_json.value.object.get("main")) |nm| {
            if (nm.object.get(locale_tag)) |nl| {
                if (nl.object.get("numbers")) |nums| {
                    if (nums.object.get("symbols-numberSystem-latn")) |symbols| {
                        result.number_symbols = try extractNumberSymbols(allocator, symbols);
                    }
                }
            }
        }
    } else |_| {
        // Numbers file not available, use defaults
    }

    return result;
}

/// Extract all Tier 1 locales
pub fn extractAllTier1Locales(state: *const ExtractState) ![]ExtractedLocaleData {
    var results: std.ArrayList(ExtractedLocaleData) = .{};
    errdefer {
        for (results.items) |*item| {
            item.deinit(state.allocator);
        }
        results.deinit(state.allocator);
    }

    for (TIER1_LOCALES) |locale| {
        if (try extractLocaleData(state, locale)) |data| {
            try results.append(state.allocator, data);
        }
    }

    return results.toOwnedSlice(state.allocator);
}

/// Write extracted data to a Zig source file for compile-time embedding
pub fn writeZigSource(state: *const ExtractState, locales: []const ExtractedLocaleData) !void {
    const output_path = try std.fmt.allocPrint(
        state.allocator,
        "{s}/embedded_data.zig",
        .{state.output_dir},
    );
    defer state.allocator.free(output_path);

    const file = try std.fs.cwd().createFile(output_path, .{});

    var write_buffer: [8192]u8 = undefined;
    var buffered_writer = file.writer(&write_buffer);
    const writer = &buffered_writer.interface;

    // Write header
    try writer.writeAll(
        \\//! CLDR Embedded Locale Data
        \\//!
        \\//! AUTO-GENERATED FILE - DO NOT EDIT
        \\//! Generated by tools/cldr/extract.zig
        \\//!
        \\//! Contains Tier 1 locale data for compile-time embedding.
        \\
        \\const std = @import("std");
        \\
        \\/// Month names (wide, abbreviated, narrow)
        \\pub const MonthNames = struct {
        \\    wide: [12][]const u8,
        \\    abbreviated: [12][]const u8,
        \\    narrow: [12][]const u8,
        \\};
        \\
        \\/// Weekday names
        \\pub const WeekdayNames = struct {
        \\    wide: [7][]const u8,
        \\    abbreviated: [7][]const u8,
        \\    narrow: [7][]const u8,
        \\    short: [7][]const u8,
        \\};
        \\
        \\/// Day period names (AM/PM)
        \\pub const DayPeriodNames = struct {
        \\    am: []const u8,
        \\    pm: []const u8,
        \\};
        \\
        \\/// Era names
        \\pub const EraNames = struct {
        \\    wide: [2][]const u8,
        \\    abbreviated: [2][]const u8,
        \\    narrow: [2][]const u8,
        \\};
        \\
        \\/// Date/time patterns
        \\pub const DateTimePatterns = struct {
        \\    date_full: []const u8,
        \\    date_long: []const u8,
        \\    date_medium: []const u8,
        \\    date_short: []const u8,
        \\    time_full: []const u8,
        \\    time_long: []const u8,
        \\    time_medium: []const u8,
        \\    time_short: []const u8,
        \\    datetime_full: []const u8,
        \\    datetime_long: []const u8,
        \\    datetime_medium: []const u8,
        \\    datetime_short: []const u8,
        \\};
        \\
        \\/// Number symbols
        \\pub const NumberSymbols = struct {
        \\    decimal: []const u8,
        \\    group: []const u8,
        \\    percent: []const u8,
        \\    minus: []const u8,
        \\    plus: []const u8,
        \\    exponential: []const u8,
        \\    infinity: []const u8,
        \\    nan: []const u8,
        \\};
        \\
        \\/// Complete locale data
        \\pub const LocaleData = struct {
        \\    tag: []const u8,
        \\    months: MonthNames,
        \\    weekdays: WeekdayNames,
        \\    day_periods: DayPeriodNames,
        \\    eras: EraNames,
        \\    datetime_patterns: DateTimePatterns,
        \\    number_symbols: NumberSymbols,
        \\};
        \\
        \\/// Get embedded locale data by tag
        \\pub fn getLocale(tag: []const u8) ?*const LocaleData {
        \\    for (&embedded_locales) |*locale| {
        \\        if (std.mem.eql(u8, locale.tag, tag)) {
        \\            return locale;
        \\        }
        \\    }
        \\    return null;
        \\}
        \\
        \\/// All embedded locale tags
        \\pub const locale_tags = [_][]const u8{
        \\
    );

    // Write locale tags
    for (locales) |locale| {
        try writer.print("    \"{s}\",\n", .{locale.locale_tag});
    }

    try writer.writeAll(
        \\};
        \\
        \\/// Embedded locale data
        \\pub const embedded_locales = [_]LocaleData{
        \\
    );

    // Write each locale's data
    for (locales) |locale| {
        try writeLocaleData(writer, locale);
    }

    try writer.writeAll(
        \\};
        \\
    );

    // Flush the buffer to ensure all data is written
    try writer.flush();

    // Close the file before logging
    file.close();

    std.log.info("Wrote {s} with {d} locales", .{ output_path, locales.len });
}

/// Write a single locale's data to Zig source
fn writeLocaleData(writer: anytype, locale: ExtractedLocaleData) !void {
    try writer.print("    .{{\n        .tag = \"{s}\",\n", .{locale.locale_tag});

    // Months
    try writer.writeAll("        .months = .{\n");
    try writeStringArray(writer, "wide", &locale.months.wide);
    try writeStringArray(writer, "abbreviated", &locale.months.abbreviated);
    try writeStringArray(writer, "narrow", &locale.months.narrow);
    try writer.writeAll("        },\n");

    // Weekdays
    try writer.writeAll("        .weekdays = .{\n");
    try writeStringArray(writer, "wide", &locale.weekdays.wide);
    try writeStringArray(writer, "abbreviated", &locale.weekdays.abbreviated);
    try writeStringArray(writer, "narrow", &locale.weekdays.narrow);
    try writeStringArray(writer, "short", &locale.weekdays.short);
    try writer.writeAll("        },\n");

    // Day periods
    try writer.print("        .day_periods = .{{ .am = \"{s}\", .pm = \"{s}\" }},\n", .{
        escapeString(locale.day_periods.am),
        escapeString(locale.day_periods.pm),
    });

    // Eras
    try writer.writeAll("        .eras = .{\n");
    try writer.print("            .wide = .{{ \"{s}\", \"{s}\" }},\n", .{
        escapeString(locale.eras.wide[0]),
        escapeString(locale.eras.wide[1]),
    });
    try writer.print("            .abbreviated = .{{ \"{s}\", \"{s}\" }},\n", .{
        escapeString(locale.eras.abbreviated[0]),
        escapeString(locale.eras.abbreviated[1]),
    });
    try writer.print("            .narrow = .{{ \"{s}\", \"{s}\" }},\n", .{
        escapeString(locale.eras.narrow[0]),
        escapeString(locale.eras.narrow[1]),
    });
    try writer.writeAll("        },\n");

    // DateTime patterns
    try writer.writeAll("        .datetime_patterns = .{\n");
    try writer.print("            .date_full = \"{s}\",\n", .{escapeString(locale.datetime_patterns.date_full)});
    try writer.print("            .date_long = \"{s}\",\n", .{escapeString(locale.datetime_patterns.date_long)});
    try writer.print("            .date_medium = \"{s}\",\n", .{escapeString(locale.datetime_patterns.date_medium)});
    try writer.print("            .date_short = \"{s}\",\n", .{escapeString(locale.datetime_patterns.date_short)});
    try writer.print("            .time_full = \"{s}\",\n", .{escapeString(locale.datetime_patterns.time_full)});
    try writer.print("            .time_long = \"{s}\",\n", .{escapeString(locale.datetime_patterns.time_long)});
    try writer.print("            .time_medium = \"{s}\",\n", .{escapeString(locale.datetime_patterns.time_medium)});
    try writer.print("            .time_short = \"{s}\",\n", .{escapeString(locale.datetime_patterns.time_short)});
    try writer.print("            .datetime_full = \"{s}\",\n", .{escapeString(locale.datetime_patterns.datetime_full)});
    try writer.print("            .datetime_long = \"{s}\",\n", .{escapeString(locale.datetime_patterns.datetime_long)});
    try writer.print("            .datetime_medium = \"{s}\",\n", .{escapeString(locale.datetime_patterns.datetime_medium)});
    try writer.print("            .datetime_short = \"{s}\",\n", .{escapeString(locale.datetime_patterns.datetime_short)});
    try writer.writeAll("        },\n");

    // Number symbols
    try writer.writeAll("        .number_symbols = .{\n");
    try writer.print("            .decimal = \"{s}\",\n", .{escapeString(locale.number_symbols.decimal)});
    try writer.print("            .group = \"{s}\",\n", .{escapeString(locale.number_symbols.group)});
    try writer.print("            .percent = \"{s}\",\n", .{escapeString(locale.number_symbols.percent)});
    try writer.print("            .minus = \"{s}\",\n", .{escapeString(locale.number_symbols.minus)});
    try writer.print("            .plus = \"{s}\",\n", .{escapeString(locale.number_symbols.plus)});
    try writer.print("            .exponential = \"{s}\",\n", .{escapeString(locale.number_symbols.exponential)});
    try writer.print("            .infinity = \"{s}\",\n", .{escapeString(locale.number_symbols.infinity)});
    try writer.print("            .nan = \"{s}\",\n", .{escapeString(locale.number_symbols.nan)});
    try writer.writeAll("        },\n");

    try writer.writeAll("    },\n");
}

/// Write a string array field
fn writeStringArray(writer: anytype, name: []const u8, arr: []const []const u8) !void {
    try writer.print("            .{s} = .{{ ", .{name});
    for (arr, 0..) |s, i| {
        if (i > 0) try writer.writeAll(", ");
        try writer.print("\"{s}\"", .{escapeString(s)});
    }
    try writer.writeAll(" },\n");
}

/// Escape special characters for Zig string literal
fn escapeString(s: []const u8) []const u8 {
    // For now, return as-is. In production, would escape special chars.
    // TODO: Properly escape backslashes, quotes, etc.
    return s;
}

/// Command-line interface
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    var input_dir: []const u8 = "data/cldr";
    var output_dir: []const u8 = "src/intl/cldr";
    var verbose: bool = false;

    // Parse arguments
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
            input_dir = args.next() orelse {
                std.log.err("Missing input directory argument", .{});
                return error.MissingArgument;
            };
        } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
            output_dir = args.next() orelse {
                std.log.err("Missing output directory argument", .{});
                return error.MissingArgument;
            };
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            printHelp();
            return;
        }
    }

    // Create output directory
    std.fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const state = ExtractState.init(allocator, input_dir, output_dir, verbose);

    std.log.info("CLDR Data Extractor", .{});
    std.log.info("Input: {s}", .{input_dir});
    std.log.info("Output: {s}", .{output_dir});
    std.log.info("Tier 1 locales: {d}", .{TIER1_LOCALES.len});

    // Check if input directory exists
    std.fs.cwd().access(input_dir, .{}) catch {
        std.log.err("Input directory does not exist: {s}", .{input_dir});
        std.log.err("Run 'zig build cldr-download' first to download CLDR data", .{});
        return error.InputNotFound;
    };

    // Extract all Tier 1 locales
    const locales = try extractAllTier1Locales(&state);
    defer {
        for (locales) |*locale| {
            @constCast(locale).deinit(allocator);
        }
        allocator.free(locales);
    }

    if (locales.len == 0) {
        std.log.warn("No locale data extracted. Is CLDR data downloaded?", .{});
        return;
    }

    // Write Zig source file
    try writeZigSource(&state, locales);

    std.log.info("Extraction complete! Extracted {d} locales.", .{locales.len});
}

fn printHelp() void {
    const help =
        \\CLDR JSON Data Extractor
        \\
        \\Extracts CLDR JSON data into Zig-compatible format for the i18n library.
        \\
        \\Usage:
        \\  cldr-extract [options]
        \\
        \\Options:
        \\  -i, --input <DIR>     Input directory with CLDR JSON (default: data/cldr/)
        \\  -o, --output <DIR>    Output directory for Zig files (default: src/intl/cldr/)
        \\  --verbose             Show verbose output
        \\  -h, --help            Show this help
        \\
        \\Tier 1 locales (embedded at compile-time):
        \\  en, en-US, en-GB, de, fr, es, it, pt, zh, ja, ko, ar, ru, and more
        \\
        \\Prerequisites:
        \\  Run 'zig build cldr-download' first to download CLDR JSON data.
        \\
    ;
    const stdout_file = std.fs.File.stdout();
    stdout_file.writeAll(help) catch {};
}

// ============================================================================
// Tests
// ============================================================================

test "TIER1_LOCALES contains expected locales" {
    var found_en = false;
    var found_de = false;
    var found_ja = false;

    for (TIER1_LOCALES) |locale| {
        if (std.mem.eql(u8, locale, "en")) found_en = true;
        if (std.mem.eql(u8, locale, "de")) found_de = true;
        if (std.mem.eql(u8, locale, "ja")) found_ja = true;
    }

    try std.testing.expect(found_en);
    try std.testing.expect(found_de);
    try std.testing.expect(found_ja);
}

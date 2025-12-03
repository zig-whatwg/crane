//! NavigatorLanguage Mixin
//!
//! HTML Standard § 8.8.1.2 - NavigatorLanguage
//! https://html.spec.whatwg.org/#navigatorlanguage
//!
//! This mixin provides language preference information.

const std = @import("std");
const Allocator = std.mem.Allocator;
const infra = @import("infra");

/// NavigatorLanguage mixin implementation
/// Spec: HTML Standard § 8.8.1.2
pub const NavigatorLanguage = struct {
    allocator: Allocator,

    /// Preferred language (BCP 47 tag)
    language: []const u8,

    /// All preferred languages (frozen array in JS)
    languages: []const []const u8,

    /// Whether the language is owned (allocated)
    language_owned: bool,

    const Self = @This();

    /// Initialize with default language
    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .language = "en-US",
            .languages = &[_][]const u8{"en-US"},
            .language_owned = false,
        };
    }

    /// Initialize with custom language
    pub fn initWithLanguage(allocator: Allocator, language: []const u8) !Self {
        const lang_copy = try allocator.dupe(u8, language);
        errdefer allocator.free(lang_copy);

        // Create languages array with single element
        const languages = try allocator.alloc([]const u8, 1);
        languages[0] = lang_copy;

        return .{
            .allocator = allocator,
            .language = lang_copy,
            .languages = languages,
            .language_owned = true,
        };
    }

    /// Initialize with multiple languages
    pub fn initWithLanguages(allocator: Allocator, languages: []const []const u8) !Self {
        if (languages.len == 0) {
            return init(allocator);
        }

        // Copy all language strings
        const langs_copy = try allocator.alloc([]const u8, languages.len);
        errdefer allocator.free(langs_copy);

        var copied: usize = 0;
        errdefer {
            for (langs_copy[0..copied]) |lang| {
                allocator.free(lang);
            }
        }

        for (languages) |lang| {
            langs_copy[copied] = try allocator.dupe(u8, lang);
            copied += 1;
        }

        return .{
            .allocator = allocator,
            .language = langs_copy[0],
            .languages = langs_copy,
            .language_owned = true,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.language_owned) {
            for (self.languages) |lang| {
                self.allocator.free(lang);
            }
            self.allocator.free(self.languages);
        }
    }

    // ========================================================================
    // NavigatorLanguage Properties
    // ========================================================================

    /// Get the preferred language.
    /// Spec: "Must return a valid BCP 47 language tag representing
    /// the user's preferred language."
    pub fn getLanguage(self: *const Self) []const u8 {
        return self.language;
    }

    /// Get all preferred languages.
    /// Spec: "Must return a frozen array of valid BCP 47 language tags."
    pub fn getLanguages(self: *const Self) []const []const u8 {
        return self.languages;
    }

    /// Set the preferred language (for testing/simulation)
    pub fn setLanguage(self: *Self, language: []const u8) !void {
        if (self.language_owned) {
            for (self.languages) |lang| {
                self.allocator.free(lang);
            }
            self.allocator.free(self.languages);
        }

        const lang_copy = try self.allocator.dupe(u8, language);
        errdefer self.allocator.free(lang_copy);

        const languages = try self.allocator.alloc([]const u8, 1);
        languages[0] = lang_copy;

        self.language = lang_copy;
        self.languages = languages;
        self.language_owned = true;
    }
};

// ============================================================================
// Tests
// ============================================================================

test "NavigatorLanguage - default" {
    const allocator = std.testing.allocator;

    var lang = NavigatorLanguage.init(allocator);
    defer lang.deinit();

    try std.testing.expectEqualStrings("en-US", lang.getLanguage());
    try std.testing.expectEqual(@as(usize, 1), lang.getLanguages().len);
    try std.testing.expectEqualStrings("en-US", lang.getLanguages()[0]);
}

test "NavigatorLanguage - custom language" {
    const allocator = std.testing.allocator;

    var lang = try NavigatorLanguage.initWithLanguage(allocator, "de-DE");
    defer lang.deinit();

    try std.testing.expectEqualStrings("de-DE", lang.getLanguage());
}

test "NavigatorLanguage - multiple languages" {
    const allocator = std.testing.allocator;

    const languages = [_][]const u8{ "en-US", "en", "de-DE" };
    var lang = try NavigatorLanguage.initWithLanguages(allocator, &languages);
    defer lang.deinit();

    try std.testing.expectEqualStrings("en-US", lang.getLanguage());
    try std.testing.expectEqual(@as(usize, 3), lang.getLanguages().len);
    try std.testing.expectEqualStrings("de-DE", lang.getLanguages()[2]);
}

test "NavigatorLanguage - setLanguage" {
    const allocator = std.testing.allocator;

    var lang = NavigatorLanguage.init(allocator);
    defer lang.deinit();

    try lang.setLanguage("fr-FR");
    try std.testing.expectEqualStrings("fr-FR", lang.getLanguage());
}

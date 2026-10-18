const std = @import("std");
const picker = @import("html").forms.select_picker;

test "Enter opens a closed picker except on Mac platforms" {
    // select-keyboard-behavior.optional.html follows navigator.platform.
    // Exercise both conventions independently of the native test machine.
    try std.testing.expect(!picker.enterOpensPicker("MacIntel"));
    try std.testing.expect(!picker.enterOpensPicker("MacPPC"));
    try std.testing.expect(picker.enterOpensPicker("Linux x86_64"));
    try std.testing.expect(picker.enterOpensPicker("Win32"));
}

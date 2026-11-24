//! Puppeteer's keyboard (puppeteer-core 25.17.0 src/cdp/Input.ts
//! CdpKeyboard, src/common/USKeyboardLayout.ts; Copyright 2017 Google Inc.,
//! Apache-2.0; THIRD_PARTY_NOTICES.md) and chrome-devtools-mcp's key parsing
//! (src/utils/keyboard.ts parseKey at chrome-devtools-mcp-v1.13.0, Copyright
//! 2025 Google LLC, Apache-2.0): what press_key and type_text send -
//! Input.dispatchKeyEvent per key down and up with the US layout's key, code,
//! virtual key code, text and location, the held modifiers' bits, and
//! Input.insertText for a character the layout has no key for. The layout
//! table is copied from USKeyboardLayout.ts's _keyDefinitions (data).

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const KeyDefinition = struct {
    input: []const u8,
    key_code: u32 = 0,
    shift_key_code: u32 = 0,
    key: []const u8 = "",
    shift_key: []const u8 = "",
    code: []const u8 = "",
    text: []const u8 = "",
    shift_text: []const u8 = "",
    location: u32 = 0,
};

/// USKeyboardLayout.ts _keyDefinitions, in its order (also the order of
/// chrome-devtools-mcp's validKeys).
pub const definitions = [_]KeyDefinition{
    .{ .input = "0", .key_code = 48, .key = "0", .code = "Digit0" },
    .{ .input = "1", .key_code = 49, .key = "1", .code = "Digit1" },
    .{ .input = "2", .key_code = 50, .key = "2", .code = "Digit2" },
    .{ .input = "3", .key_code = 51, .key = "3", .code = "Digit3" },
    .{ .input = "4", .key_code = 52, .key = "4", .code = "Digit4" },
    .{ .input = "5", .key_code = 53, .key = "5", .code = "Digit5" },
    .{ .input = "6", .key_code = 54, .key = "6", .code = "Digit6" },
    .{ .input = "7", .key_code = 55, .key = "7", .code = "Digit7" },
    .{ .input = "8", .key_code = 56, .key = "8", .code = "Digit8" },
    .{ .input = "9", .key_code = 57, .key = "9", .code = "Digit9" },
    .{ .input = "Power", .key = "Power", .code = "Power" },
    .{ .input = "Eject", .key = "Eject", .code = "Eject" },
    .{ .input = "Abort", .key_code = 3, .key = "Cancel", .code = "Abort" },
    .{ .input = "Help", .key_code = 6, .key = "Help", .code = "Help" },
    .{ .input = "Backspace", .key_code = 8, .key = "Backspace", .code = "Backspace" },
    .{ .input = "Tab", .key_code = 9, .key = "Tab", .code = "Tab" },
    .{ .input = "Numpad5", .key_code = 12, .shift_key_code = 101, .key = "Clear", .shift_key = "5", .code = "Numpad5", .location = 3 },
    .{ .input = "NumpadEnter", .key_code = 13, .key = "Enter", .code = "NumpadEnter", .text = "\r", .location = 3 },
    .{ .input = "Enter", .key_code = 13, .key = "Enter", .code = "Enter", .text = "\r" },
    .{ .input = "\r", .key_code = 13, .key = "Enter", .code = "Enter", .text = "\r" },
    .{ .input = "\n", .key_code = 13, .key = "Enter", .code = "Enter", .text = "\r" },
    .{ .input = "ShiftLeft", .key_code = 16, .key = "Shift", .code = "ShiftLeft", .location = 1 },
    .{ .input = "ShiftRight", .key_code = 16, .key = "Shift", .code = "ShiftRight", .location = 2 },
    .{ .input = "ControlLeft", .key_code = 17, .key = "Control", .code = "ControlLeft", .location = 1 },
    .{ .input = "ControlRight", .key_code = 17, .key = "Control", .code = "ControlRight", .location = 2 },
    .{ .input = "AltLeft", .key_code = 18, .key = "Alt", .code = "AltLeft", .location = 1 },
    .{ .input = "AltRight", .key_code = 18, .key = "Alt", .code = "AltRight", .location = 2 },
    .{ .input = "Pause", .key_code = 19, .key = "Pause", .code = "Pause" },
    .{ .input = "CapsLock", .key_code = 20, .key = "CapsLock", .code = "CapsLock" },
    .{ .input = "Escape", .key_code = 27, .key = "Escape", .code = "Escape" },
    .{ .input = "Convert", .key_code = 28, .key = "Convert", .code = "Convert" },
    .{ .input = "NonConvert", .key_code = 29, .key = "NonConvert", .code = "NonConvert" },
    .{ .input = "Space", .key_code = 32, .key = " ", .code = "Space" },
    .{ .input = "Numpad9", .key_code = 33, .shift_key_code = 105, .key = "PageUp", .shift_key = "9", .code = "Numpad9", .location = 3 },
    .{ .input = "PageUp", .key_code = 33, .key = "PageUp", .code = "PageUp" },
    .{ .input = "Numpad3", .key_code = 34, .shift_key_code = 99, .key = "PageDown", .shift_key = "3", .code = "Numpad3", .location = 3 },
    .{ .input = "PageDown", .key_code = 34, .key = "PageDown", .code = "PageDown" },
    .{ .input = "End", .key_code = 35, .key = "End", .code = "End" },
    .{ .input = "Numpad1", .key_code = 35, .shift_key_code = 97, .key = "End", .shift_key = "1", .code = "Numpad1", .location = 3 },
    .{ .input = "Home", .key_code = 36, .key = "Home", .code = "Home" },
    .{ .input = "Numpad7", .key_code = 36, .shift_key_code = 103, .key = "Home", .shift_key = "7", .code = "Numpad7", .location = 3 },
    .{ .input = "ArrowLeft", .key_code = 37, .key = "ArrowLeft", .code = "ArrowLeft" },
    .{ .input = "Numpad4", .key_code = 37, .shift_key_code = 100, .key = "ArrowLeft", .shift_key = "4", .code = "Numpad4", .location = 3 },
    .{ .input = "Numpad8", .key_code = 38, .shift_key_code = 104, .key = "ArrowUp", .shift_key = "8", .code = "Numpad8", .location = 3 },
    .{ .input = "ArrowUp", .key_code = 38, .key = "ArrowUp", .code = "ArrowUp" },
    .{ .input = "ArrowRight", .key_code = 39, .key = "ArrowRight", .code = "ArrowRight" },
    .{ .input = "Numpad6", .key_code = 39, .shift_key_code = 102, .key = "ArrowRight", .shift_key = "6", .code = "Numpad6", .location = 3 },
    .{ .input = "Numpad2", .key_code = 40, .shift_key_code = 98, .key = "ArrowDown", .shift_key = "2", .code = "Numpad2", .location = 3 },
    .{ .input = "ArrowDown", .key_code = 40, .key = "ArrowDown", .code = "ArrowDown" },
    .{ .input = "Select", .key_code = 41, .key = "Select", .code = "Select" },
    .{ .input = "Open", .key_code = 43, .key = "Execute", .code = "Open" },
    .{ .input = "PrintScreen", .key_code = 44, .key = "PrintScreen", .code = "PrintScreen" },
    .{ .input = "Insert", .key_code = 45, .key = "Insert", .code = "Insert" },
    .{ .input = "Numpad0", .key_code = 45, .shift_key_code = 96, .key = "Insert", .shift_key = "0", .code = "Numpad0", .location = 3 },
    .{ .input = "Delete", .key_code = 46, .key = "Delete", .code = "Delete" },
    .{ .input = "NumpadDecimal", .key_code = 46, .shift_key_code = 110, .key = "\x00", .shift_key = ".", .code = "NumpadDecimal", .location = 3 },
    .{ .input = "Digit0", .key_code = 48, .key = "0", .shift_key = ")", .code = "Digit0" },
    .{ .input = "Digit1", .key_code = 49, .key = "1", .shift_key = "!", .code = "Digit1" },
    .{ .input = "Digit2", .key_code = 50, .key = "2", .shift_key = "@", .code = "Digit2" },
    .{ .input = "Digit3", .key_code = 51, .key = "3", .shift_key = "#", .code = "Digit3" },
    .{ .input = "Digit4", .key_code = 52, .key = "4", .shift_key = "$", .code = "Digit4" },
    .{ .input = "Digit5", .key_code = 53, .key = "5", .shift_key = "%", .code = "Digit5" },
    .{ .input = "Digit6", .key_code = 54, .key = "6", .shift_key = "^", .code = "Digit6" },
    .{ .input = "Digit7", .key_code = 55, .key = "7", .shift_key = "&", .code = "Digit7" },
    .{ .input = "Digit8", .key_code = 56, .key = "8", .shift_key = "*", .code = "Digit8" },
    .{ .input = "Digit9", .key_code = 57, .key = "9", .shift_key = "(", .code = "Digit9" },
    .{ .input = "KeyA", .key_code = 65, .key = "a", .shift_key = "A", .code = "KeyA" },
    .{ .input = "KeyB", .key_code = 66, .key = "b", .shift_key = "B", .code = "KeyB" },
    .{ .input = "KeyC", .key_code = 67, .key = "c", .shift_key = "C", .code = "KeyC" },
    .{ .input = "KeyD", .key_code = 68, .key = "d", .shift_key = "D", .code = "KeyD" },
    .{ .input = "KeyE", .key_code = 69, .key = "e", .shift_key = "E", .code = "KeyE" },
    .{ .input = "KeyF", .key_code = 70, .key = "f", .shift_key = "F", .code = "KeyF" },
    .{ .input = "KeyG", .key_code = 71, .key = "g", .shift_key = "G", .code = "KeyG" },
    .{ .input = "KeyH", .key_code = 72, .key = "h", .shift_key = "H", .code = "KeyH" },
    .{ .input = "KeyI", .key_code = 73, .key = "i", .shift_key = "I", .code = "KeyI" },
    .{ .input = "KeyJ", .key_code = 74, .key = "j", .shift_key = "J", .code = "KeyJ" },
    .{ .input = "KeyK", .key_code = 75, .key = "k", .shift_key = "K", .code = "KeyK" },
    .{ .input = "KeyL", .key_code = 76, .key = "l", .shift_key = "L", .code = "KeyL" },
    .{ .input = "KeyM", .key_code = 77, .key = "m", .shift_key = "M", .code = "KeyM" },
    .{ .input = "KeyN", .key_code = 78, .key = "n", .shift_key = "N", .code = "KeyN" },
    .{ .input = "KeyO", .key_code = 79, .key = "o", .shift_key = "O", .code = "KeyO" },
    .{ .input = "KeyP", .key_code = 80, .key = "p", .shift_key = "P", .code = "KeyP" },
    .{ .input = "KeyQ", .key_code = 81, .key = "q", .shift_key = "Q", .code = "KeyQ" },
    .{ .input = "KeyR", .key_code = 82, .key = "r", .shift_key = "R", .code = "KeyR" },
    .{ .input = "KeyS", .key_code = 83, .key = "s", .shift_key = "S", .code = "KeyS" },
    .{ .input = "KeyT", .key_code = 84, .key = "t", .shift_key = "T", .code = "KeyT" },
    .{ .input = "KeyU", .key_code = 85, .key = "u", .shift_key = "U", .code = "KeyU" },
    .{ .input = "KeyV", .key_code = 86, .key = "v", .shift_key = "V", .code = "KeyV" },
    .{ .input = "KeyW", .key_code = 87, .key = "w", .shift_key = "W", .code = "KeyW" },
    .{ .input = "KeyX", .key_code = 88, .key = "x", .shift_key = "X", .code = "KeyX" },
    .{ .input = "KeyY", .key_code = 89, .key = "y", .shift_key = "Y", .code = "KeyY" },
    .{ .input = "KeyZ", .key_code = 90, .key = "z", .shift_key = "Z", .code = "KeyZ" },
    .{ .input = "MetaLeft", .key_code = 91, .key = "Meta", .code = "MetaLeft", .location = 1 },
    .{ .input = "MetaRight", .key_code = 92, .key = "Meta", .code = "MetaRight", .location = 2 },
    .{ .input = "ContextMenu", .key_code = 93, .key = "ContextMenu", .code = "ContextMenu" },
    .{ .input = "NumpadMultiply", .key_code = 106, .key = "*", .code = "NumpadMultiply", .location = 3 },
    .{ .input = "NumpadAdd", .key_code = 107, .key = "+", .code = "NumpadAdd", .location = 3 },
    .{ .input = "NumpadSubtract", .key_code = 109, .key = "-", .code = "NumpadSubtract", .location = 3 },
    .{ .input = "NumpadDivide", .key_code = 111, .key = "/", .code = "NumpadDivide", .location = 3 },
    .{ .input = "F1", .key_code = 112, .key = "F1", .code = "F1" },
    .{ .input = "F2", .key_code = 113, .key = "F2", .code = "F2" },
    .{ .input = "F3", .key_code = 114, .key = "F3", .code = "F3" },
    .{ .input = "F4", .key_code = 115, .key = "F4", .code = "F4" },
    .{ .input = "F5", .key_code = 116, .key = "F5", .code = "F5" },
    .{ .input = "F6", .key_code = 117, .key = "F6", .code = "F6" },
    .{ .input = "F7", .key_code = 118, .key = "F7", .code = "F7" },
    .{ .input = "F8", .key_code = 119, .key = "F8", .code = "F8" },
    .{ .input = "F9", .key_code = 120, .key = "F9", .code = "F9" },
    .{ .input = "F10", .key_code = 121, .key = "F10", .code = "F10" },
    .{ .input = "F11", .key_code = 122, .key = "F11", .code = "F11" },
    .{ .input = "F12", .key_code = 123, .key = "F12", .code = "F12" },
    .{ .input = "F13", .key_code = 124, .key = "F13", .code = "F13" },
    .{ .input = "F14", .key_code = 125, .key = "F14", .code = "F14" },
    .{ .input = "F15", .key_code = 126, .key = "F15", .code = "F15" },
    .{ .input = "F16", .key_code = 127, .key = "F16", .code = "F16" },
    .{ .input = "F17", .key_code = 128, .key = "F17", .code = "F17" },
    .{ .input = "F18", .key_code = 129, .key = "F18", .code = "F18" },
    .{ .input = "F19", .key_code = 130, .key = "F19", .code = "F19" },
    .{ .input = "F20", .key_code = 131, .key = "F20", .code = "F20" },
    .{ .input = "F21", .key_code = 132, .key = "F21", .code = "F21" },
    .{ .input = "F22", .key_code = 133, .key = "F22", .code = "F22" },
    .{ .input = "F23", .key_code = 134, .key = "F23", .code = "F23" },
    .{ .input = "F24", .key_code = 135, .key = "F24", .code = "F24" },
    .{ .input = "NumLock", .key_code = 144, .key = "NumLock", .code = "NumLock" },
    .{ .input = "ScrollLock", .key_code = 145, .key = "ScrollLock", .code = "ScrollLock" },
    .{ .input = "AudioVolumeMute", .key_code = 173, .key = "AudioVolumeMute", .code = "AudioVolumeMute" },
    .{ .input = "AudioVolumeDown", .key_code = 174, .key = "AudioVolumeDown", .code = "AudioVolumeDown" },
    .{ .input = "AudioVolumeUp", .key_code = 175, .key = "AudioVolumeUp", .code = "AudioVolumeUp" },
    .{ .input = "MediaTrackNext", .key_code = 176, .key = "MediaTrackNext", .code = "MediaTrackNext" },
    .{ .input = "MediaTrackPrevious", .key_code = 177, .key = "MediaTrackPrevious", .code = "MediaTrackPrevious" },
    .{ .input = "MediaStop", .key_code = 178, .key = "MediaStop", .code = "MediaStop" },
    .{ .input = "MediaPlayPause", .key_code = 179, .key = "MediaPlayPause", .code = "MediaPlayPause" },
    .{ .input = "Semicolon", .key_code = 186, .key = ";", .shift_key = ":", .code = "Semicolon" },
    .{ .input = "Equal", .key_code = 187, .key = "=", .shift_key = "+", .code = "Equal" },
    .{ .input = "NumpadEqual", .key_code = 187, .key = "=", .code = "NumpadEqual", .location = 3 },
    .{ .input = "Comma", .key_code = 188, .key = ",", .shift_key = "<", .code = "Comma" },
    .{ .input = "Minus", .key_code = 189, .key = "-", .shift_key = "_", .code = "Minus" },
    .{ .input = "Period", .key_code = 190, .key = ".", .shift_key = ">", .code = "Period" },
    .{ .input = "Slash", .key_code = 191, .key = "/", .shift_key = "?", .code = "Slash" },
    .{ .input = "Backquote", .key_code = 192, .key = "`", .shift_key = "~", .code = "Backquote" },
    .{ .input = "BracketLeft", .key_code = 219, .key = "[", .shift_key = "{", .code = "BracketLeft" },
    .{ .input = "Backslash", .key_code = 220, .key = "\\", .shift_key = "|", .code = "Backslash" },
    .{ .input = "BracketRight", .key_code = 221, .key = "]", .shift_key = "}", .code = "BracketRight" },
    .{ .input = "Quote", .key_code = 222, .key = "'", .shift_key = "\"", .code = "Quote" },
    .{ .input = "AltGraph", .key_code = 225, .key = "AltGraph", .code = "AltGraph" },
    .{ .input = "Props", .key_code = 247, .key = "CrSel", .code = "Props" },
    .{ .input = "Cancel", .key_code = 3, .key = "Cancel", .code = "Abort" },
    .{ .input = "Clear", .key_code = 12, .key = "Clear", .code = "Numpad5", .location = 3 },
    .{ .input = "Shift", .key_code = 16, .key = "Shift", .code = "ShiftLeft", .location = 1 },
    .{ .input = "Control", .key_code = 17, .key = "Control", .code = "ControlLeft", .location = 1 },
    .{ .input = "Alt", .key_code = 18, .key = "Alt", .code = "AltLeft", .location = 1 },
    .{ .input = "Accept", .key_code = 30, .key = "Accept" },
    .{ .input = "ModeChange", .key_code = 31, .key = "ModeChange" },
    .{ .input = " ", .key_code = 32, .key = " ", .code = "Space" },
    .{ .input = "Print", .key_code = 42, .key = "Print" },
    .{ .input = "Execute", .key_code = 43, .key = "Execute", .code = "Open" },
    .{ .input = "\x00", .key_code = 46, .key = "\x00", .code = "NumpadDecimal", .location = 3 },
    .{ .input = "a", .key_code = 65, .key = "a", .code = "KeyA" },
    .{ .input = "b", .key_code = 66, .key = "b", .code = "KeyB" },
    .{ .input = "c", .key_code = 67, .key = "c", .code = "KeyC" },
    .{ .input = "d", .key_code = 68, .key = "d", .code = "KeyD" },
    .{ .input = "e", .key_code = 69, .key = "e", .code = "KeyE" },
    .{ .input = "f", .key_code = 70, .key = "f", .code = "KeyF" },
    .{ .input = "g", .key_code = 71, .key = "g", .code = "KeyG" },
    .{ .input = "h", .key_code = 72, .key = "h", .code = "KeyH" },
    .{ .input = "i", .key_code = 73, .key = "i", .code = "KeyI" },
    .{ .input = "j", .key_code = 74, .key = "j", .code = "KeyJ" },
    .{ .input = "k", .key_code = 75, .key = "k", .code = "KeyK" },
    .{ .input = "l", .key_code = 76, .key = "l", .code = "KeyL" },
    .{ .input = "m", .key_code = 77, .key = "m", .code = "KeyM" },
    .{ .input = "n", .key_code = 78, .key = "n", .code = "KeyN" },
    .{ .input = "o", .key_code = 79, .key = "o", .code = "KeyO" },
    .{ .input = "p", .key_code = 80, .key = "p", .code = "KeyP" },
    .{ .input = "q", .key_code = 81, .key = "q", .code = "KeyQ" },
    .{ .input = "r", .key_code = 82, .key = "r", .code = "KeyR" },
    .{ .input = "s", .key_code = 83, .key = "s", .code = "KeyS" },
    .{ .input = "t", .key_code = 84, .key = "t", .code = "KeyT" },
    .{ .input = "u", .key_code = 85, .key = "u", .code = "KeyU" },
    .{ .input = "v", .key_code = 86, .key = "v", .code = "KeyV" },
    .{ .input = "w", .key_code = 87, .key = "w", .code = "KeyW" },
    .{ .input = "x", .key_code = 88, .key = "x", .code = "KeyX" },
    .{ .input = "y", .key_code = 89, .key = "y", .code = "KeyY" },
    .{ .input = "z", .key_code = 90, .key = "z", .code = "KeyZ" },
    .{ .input = "Meta", .key_code = 91, .key = "Meta", .code = "MetaLeft", .location = 1 },
    .{ .input = "*", .key_code = 106, .key = "*", .code = "NumpadMultiply", .location = 3 },
    .{ .input = "+", .key_code = 107, .key = "+", .code = "NumpadAdd", .location = 3 },
    .{ .input = "-", .key_code = 109, .key = "-", .code = "NumpadSubtract", .location = 3 },
    .{ .input = "/", .key_code = 111, .key = "/", .code = "NumpadDivide", .location = 3 },
    .{ .input = ";", .key_code = 186, .key = ";", .code = "Semicolon" },
    .{ .input = "=", .key_code = 187, .key = "=", .code = "Equal" },
    .{ .input = ",", .key_code = 188, .key = ",", .code = "Comma" },
    .{ .input = ".", .key_code = 190, .key = ".", .code = "Period" },
    .{ .input = "`", .key_code = 192, .key = "`", .code = "Backquote" },
    .{ .input = "[", .key_code = 219, .key = "[", .code = "BracketLeft" },
    .{ .input = "\\", .key_code = 220, .key = "\\", .code = "Backslash" },
    .{ .input = "]", .key_code = 221, .key = "]", .code = "BracketRight" },
    .{ .input = "'", .key_code = 222, .key = "'", .code = "Quote" },
    .{ .input = "Attn", .key_code = 246, .key = "Attn" },
    .{ .input = "CrSel", .key_code = 247, .key = "CrSel", .code = "Props" },
    .{ .input = "ExSel", .key_code = 248, .key = "ExSel" },
    .{ .input = "EraseEof", .key_code = 249, .key = "EraseEof" },
    .{ .input = "Play", .key_code = 250, .key = "Play" },
    .{ .input = "ZoomOut", .key_code = 251, .key = "ZoomOut" },
    .{ .input = ")", .key_code = 48, .key = ")", .code = "Digit0" },
    .{ .input = "!", .key_code = 49, .key = "!", .code = "Digit1" },
    .{ .input = "@", .key_code = 50, .key = "@", .code = "Digit2" },
    .{ .input = "#", .key_code = 51, .key = "#", .code = "Digit3" },
    .{ .input = "$", .key_code = 52, .key = "$", .code = "Digit4" },
    .{ .input = "%", .key_code = 53, .key = "%", .code = "Digit5" },
    .{ .input = "^", .key_code = 54, .key = "^", .code = "Digit6" },
    .{ .input = "&", .key_code = 55, .key = "&", .code = "Digit7" },
    .{ .input = "(", .key_code = 57, .key = "(", .code = "Digit9" },
    .{ .input = "A", .key_code = 65, .key = "A", .code = "KeyA" },
    .{ .input = "B", .key_code = 66, .key = "B", .code = "KeyB" },
    .{ .input = "C", .key_code = 67, .key = "C", .code = "KeyC" },
    .{ .input = "D", .key_code = 68, .key = "D", .code = "KeyD" },
    .{ .input = "E", .key_code = 69, .key = "E", .code = "KeyE" },
    .{ .input = "F", .key_code = 70, .key = "F", .code = "KeyF" },
    .{ .input = "G", .key_code = 71, .key = "G", .code = "KeyG" },
    .{ .input = "H", .key_code = 72, .key = "H", .code = "KeyH" },
    .{ .input = "I", .key_code = 73, .key = "I", .code = "KeyI" },
    .{ .input = "J", .key_code = 74, .key = "J", .code = "KeyJ" },
    .{ .input = "K", .key_code = 75, .key = "K", .code = "KeyK" },
    .{ .input = "L", .key_code = 76, .key = "L", .code = "KeyL" },
    .{ .input = "M", .key_code = 77, .key = "M", .code = "KeyM" },
    .{ .input = "N", .key_code = 78, .key = "N", .code = "KeyN" },
    .{ .input = "O", .key_code = 79, .key = "O", .code = "KeyO" },
    .{ .input = "P", .key_code = 80, .key = "P", .code = "KeyP" },
    .{ .input = "Q", .key_code = 81, .key = "Q", .code = "KeyQ" },
    .{ .input = "R", .key_code = 82, .key = "R", .code = "KeyR" },
    .{ .input = "S", .key_code = 83, .key = "S", .code = "KeyS" },
    .{ .input = "T", .key_code = 84, .key = "T", .code = "KeyT" },
    .{ .input = "U", .key_code = 85, .key = "U", .code = "KeyU" },
    .{ .input = "V", .key_code = 86, .key = "V", .code = "KeyV" },
    .{ .input = "W", .key_code = 87, .key = "W", .code = "KeyW" },
    .{ .input = "X", .key_code = 88, .key = "X", .code = "KeyX" },
    .{ .input = "Y", .key_code = 89, .key = "Y", .code = "KeyY" },
    .{ .input = "Z", .key_code = 90, .key = "Z", .code = "KeyZ" },
    .{ .input = ":", .key_code = 186, .key = ":", .code = "Semicolon" },
    .{ .input = "<", .key_code = 188, .key = "<", .code = "Comma" },
    .{ .input = "_", .key_code = 189, .key = "_", .code = "Minus" },
    .{ .input = ">", .key_code = 190, .key = ">", .code = "Period" },
    .{ .input = "?", .key_code = 191, .key = "?", .code = "Slash" },
    .{ .input = "~", .key_code = 192, .key = "~", .code = "Backquote" },
    .{ .input = "{", .key_code = 219, .key = "{", .code = "BracketLeft" },
    .{ .input = "|", .key_code = 220, .key = "|", .code = "Backslash" },
    .{ .input = "}", .key_code = 221, .key = "}", .code = "BracketRight" },
    .{ .input = "\"", .key_code = 222, .key = "\"", .code = "Quote" },
    .{ .input = "SoftLeft", .key = "SoftLeft", .code = "SoftLeft", .location = 4 },
    .{ .input = "SoftRight", .key = "SoftRight", .code = "SoftRight", .location = 4 },
    .{ .input = "Camera", .key_code = 44, .key = "Camera", .code = "Camera", .location = 4 },
    .{ .input = "Call", .key = "Call", .code = "Call", .location = 4 },
    .{ .input = "EndCall", .key_code = 95, .key = "EndCall", .code = "EndCall", .location = 4 },
    .{ .input = "VolumeDown", .key_code = 182, .key = "VolumeDown", .code = "VolumeDown", .location = 4 },
    .{ .input = "VolumeUp", .key_code = 183, .key = "VolumeUp", .code = "VolumeUp", .location = 4 },
};

pub fn definition(input: []const u8) ?*const KeyDefinition {
    for (&definitions) |*d| if (std.mem.eql(u8, d.input, input)) return d;
    return null;
}

/// One page's keyboard (CdpKeyboard): the held modifiers' bits and the codes
/// of the keys down.
pub const Keyboard = struct {
    modifiers: u8 = 0,
    /// Codes (the table's strings) of the keys down.
    pressed: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *Keyboard, allocator: Allocator) void {
        self.pressed.deinit(allocator);
    }

    const Description = struct {
        key: []const u8,
        key_code: u32,
        code: []const u8,
        text: []const u8,
        location: u32,
    };

    /// #keyDescriptionForString.
    fn describe(self: *const Keyboard, d: *const KeyDefinition) Description {
        const shift = self.modifiers & 8 != 0;
        var description: Description = .{ .key = d.key, .key_code = d.key_code, .code = d.code, .text = "", .location = d.location };
        if (shift and d.shift_key.len != 0) description.key = d.shift_key;
        if (shift and d.shift_key_code != 0) description.key_code = d.shift_key_code;
        // `key.length === 1`: one UTF-16 code unit.
        if (utf16Length(description.key) == 1) description.text = description.key;
        if (d.text.len != 0) description.text = d.text;
        if (shift and d.shift_text.len != 0) description.text = d.shift_text;
        // Any modifier but Shift: no text.
        if (self.modifiers & ~@as(u8, 8) != 0) description.text = "";
        return description;
    }

    /// Input.dispatchKeyEvent's params for `down(key)`; `commands` sends
    /// down()'s default `commands: []` (a press's down sends none).
    pub fn down(self: *Keyboard, allocator: Allocator, arena: Allocator, d: *const KeyDefinition, commands: bool) ![]const u8 {
        const description = self.describe(d);
        var auto_repeat = false;
        for (self.pressed.items) |code| if (std.mem.eql(u8, code, description.code)) {
            auto_repeat = true;
        };
        if (!auto_repeat) try self.pressed.append(allocator, description.code);
        self.modifiers |= modifierBit(description.key);
        const text = description.text;
        var out: std.Io.Writer.Allocating = .init(arena);
        const w = &out.writer;
        try w.print("{{\"type\":\"{s}\",\"modifiers\":{d},\"windowsVirtualKeyCode\":{d},\"code\":{f},\"key\":{f},\"text\":{f},\"unmodifiedText\":{f},\"autoRepeat\":{},\"location\":{d},\"isKeypad\":{}", .{
            if (text.len != 0) "keyDown" else "rawKeyDown",
            self.modifiers,
            description.key_code,
            std.json.fmt(description.code, .{}),
            std.json.fmt(description.key, .{}),
            std.json.fmt(text, .{}),
            std.json.fmt(text, .{}),
            auto_repeat,
            description.location,
            description.location == 3,
        });
        if (commands) try w.writeAll(",\"commands\":[]");
        try w.writeAll("}");
        return out.written();
    }

    /// Input.dispatchKeyEvent's params for `up(key)`.
    pub fn up(self: *Keyboard, arena: Allocator, d: *const KeyDefinition) ![]const u8 {
        const description = self.describe(d);
        self.modifiers &= ~modifierBit(description.key);
        for (self.pressed.items, 0..) |code, at| if (std.mem.eql(u8, code, description.code)) {
            _ = self.pressed.orderedRemove(at);
            break;
        };
        return std.fmt.allocPrint(arena, "{{\"type\":\"keyUp\",\"modifiers\":{d},\"key\":{f},\"windowsVirtualKeyCode\":{d},\"code\":{f},\"location\":{d}}}", .{
            self.modifiers,
            std.json.fmt(description.key, .{}),
            description.key_code,
            std.json.fmt(description.code, .{}),
            description.location,
        });
    }
};

/// #modifierBit.
fn modifierBit(key: []const u8) u8 {
    if (std.mem.eql(u8, key, "Alt")) return 1;
    if (std.mem.eql(u8, key, "Control")) return 2;
    if (std.mem.eql(u8, key, "Meta")) return 4;
    if (std.mem.eql(u8, key, "Shift")) return 8;
    return 0;
}

fn utf16Length(text: []const u8) usize {
    const view = std.unicode.Utf8View.init(text) catch return text.len;
    var it = view.iterator();
    var n: usize = 0;
    while (it.nextCodepoint()) |cp| n += if (cp >= 0x10000) 2 else 1;
    return n;
}

/// chrome-devtools-mcp's invalidKeyMessage.
pub fn invalidKeyMessage(arena: Allocator, key: []const u8) ![]const u8 {
    var out: std.Io.Writer.Allocating = .init(arena);
    try out.writer.print("{s} is invalid. Valid keys are: ", .{key});
    for (definitions, 0..) |d, i| {
        if (i != 0) try out.writer.writeByte(',');
        try out.writer.writeAll(d.input);
    }
    try out.writer.writeByte('.');
    return out.written();
}

pub const Parsed = union(enum) {
    /// The primary key, then the modifiers in the order given.
    keys: []const *const KeyDefinition,
    /// Why it does not parse (parseKey's error message).
    invalid: []const u8,
};

/// parseKey: "Control+Shift+R" -> R, then Control, Shift; "Control++" -> +.
pub fn parseKey(arena: Allocator, input: []const u8) !Parsed {
    var result: std.ArrayList(*const KeyDefinition) = .empty;
    var key: std.ArrayList(u8) = .empty;
    const view = std.unicode.Utf8View.init(input) catch return .{ .invalid = try std.fmt.allocPrint(arena, "Key {s} could not be parsed.", .{input}) };
    var it = view.iterator();
    while (it.nextCodepointSlice()) |ch| {
        if (std.mem.eql(u8, ch, "+") and key.items.len > 0) {
            const d = definition(key.items) orelse return .{ .invalid = try invalidKeyMessage(arena, key.items) };
            try result.append(arena, d);
            key = .empty;
        } else try key.appendSlice(arena, ch);
    }
    if (key.items.len > 0) {
        const d = definition(key.items) orelse return .{ .invalid = try invalidKeyMessage(arena, key.items) };
        try result.append(arena, d);
    }
    if (result.items.len == 0) return .{ .invalid = try std.fmt.allocPrint(arena, "Key {s} could not be parsed.", .{input}) };
    for (result.items, 0..) |a, i| for (result.items[i + 1 ..]) |b| if (a == b) {
        return .{ .invalid = try std.fmt.allocPrint(arena, "Key {s} contains duplicate keys.", .{input}) };
    };
    var ordered: std.ArrayList(*const KeyDefinition) = .empty;
    try ordered.append(arena, result.items[result.items.len - 1]);
    try ordered.appendSlice(arena, result.items[0 .. result.items.len - 1]);
    return .{ .keys = ordered.items };
}

test "parseKey: the primary key last, modifiers before it, '+' as a key, unknown and duplicate keys refused" {
    var arena_state = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const combo = (try parseKey(arena, "Control+Shift+R")).keys;
    try std.testing.expectEqualStrings("R", combo[0].input);
    try std.testing.expectEqualStrings("Control", combo[1].input);
    try std.testing.expectEqualStrings("Shift", combo[2].input);
    const plus = (try parseKey(arena, "Control++")).keys;
    try std.testing.expectEqualStrings("+", plus[0].input);
    try std.testing.expect(std.mem.startsWith(u8, (try parseKey(arena, "Ctrl+A")).invalid, "Ctrl is invalid. Valid keys are: 0,1,2,"));
    try std.testing.expectEqualStrings("Key A+A contains duplicate keys.", (try parseKey(arena, "A+A")).invalid);
}

test "a key's events: keyDown with text, Shift's text and modifiers, no text under Control" {
    const allocator = std.testing.allocator;
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    var keyboard: Keyboard = .{};
    defer keyboard.deinit(allocator);
    try std.testing.expectEqualStrings(
        \\{"type":"keyDown","modifiers":0,"windowsVirtualKeyCode":65,"code":"KeyA","key":"a","text":"a","unmodifiedText":"a","autoRepeat":false,"location":0,"isKeypad":false}
    , try keyboard.down(allocator, arena, definition("a").?, false));
    try std.testing.expectEqualStrings(
        \\{"type":"keyUp","modifiers":0,"key":"a","windowsVirtualKeyCode":65,"code":"KeyA","location":0}
    , try keyboard.up(arena, definition("a").?));
    _ = try keyboard.down(allocator, arena, definition("Shift").?, true);
    try std.testing.expect(std.mem.indexOf(u8, try keyboard.down(allocator, arena, definition("KeyA").?, false), "\"key\":\"A\",\"text\":\"A\"") != null);
    _ = try keyboard.up(arena, definition("KeyA").?);
    _ = try keyboard.up(arena, definition("Shift").?);
    _ = try keyboard.down(allocator, arena, definition("Control").?, true);
    try std.testing.expect(std.mem.startsWith(u8, try keyboard.down(allocator, arena, definition("a").?, false), "{\"type\":\"rawKeyDown\",\"modifiers\":2,"));
}

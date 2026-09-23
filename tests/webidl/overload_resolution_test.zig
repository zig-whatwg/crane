//! The WebIDL overload resolution algorithm, against a fake JavaScript value.
//!
//! Spec: https://webidl.spec.whatwg.org/#dfn-overload-resolution-algorithm
//! and https://webidl.spec.whatwg.org/#compute-the-effective-overload-set
//!
//! The binding layer answers "what is this value?" for V8; these tests answer
//! it with a struct, so the algorithm - argcount, the effective overload set,
//! the distinguishing argument index and the step-12 type tests - is checked
//! without an isolate. The overload sets are real ones from specs/idl/.

const std = @import("std");
const testing = std.testing;

const webidl = @import("webidl");
const ovl = webidl.overload_resolution;
const Arg = ovl.Arg;
const Overload = ovl.Overload;

/// What the binding would learn about one JavaScript argument.
const Fake = struct {
    kind: enum { undefined, null, boolean, number, bigint, string, object } = .undefined,
    callable: bool = false,
    /// Non-null for a platform object: the interface it implements.
    platform: ?ovl.Id = null,
    array_buffer: bool = false,
    data_view: bool = false,
    typed_array: ?[]const u8 = null,
    iterable: bool = false,
    string_object: bool = false,

    pub fn isUndefined(self: Fake) bool {
        return self.kind == .undefined;
    }
    pub fn isNull(self: Fake) bool {
        return self.kind == .null;
    }
    pub fn isObject(self: Fake) bool {
        return self.kind == .object;
    }
    pub fn isCallable(self: Fake) bool {
        return self.callable;
    }
    pub fn isPlatformObject(self: Fake) bool {
        return self.platform != null;
    }
    pub fn implements(self: Fake, id: ovl.Id) bool {
        return self.platform == id;
    }
    pub fn hasArrayBufferData(self: Fake) bool {
        return self.array_buffer;
    }
    pub fn isDataView(self: Fake) bool {
        return self.data_view;
    }
    pub fn typedArrayName(self: Fake) ?[]const u8 {
        return self.typed_array;
    }
    pub fn hasStringData(self: Fake) bool {
        return self.string_object;
    }
    pub fn hasIteratorMethod(self: Fake) !bool {
        return self.iterable;
    }
    pub fn hasAsyncIteratorMethod(self: Fake) !bool {
        return self.iterable;
    }
    pub fn isBoolean(self: Fake) bool {
        return self.kind == .boolean;
    }
    pub fn isNumber(self: Fake) bool {
        return self.kind == .number;
    }
    pub fn isBigInt(self: Fake) bool {
        return self.kind == .bigint;
    }
};

/// `args` for `select`: the values, by index.
const Args = struct {
    values: []const Fake,
    pub fn at(self: Args, i: usize) Fake {
        return if (i < self.values.len) self.values[i] else .{};
    }
};

fn pick(overloads: []const Overload, values: []const Fake) !usize {
    return ovl.select(overloads, values.len, Args{ .values = values });
}

// Stand-ins for interface identities; the binding uses the State type's id.
const blob_marker: u8 = 0;
const path2d_marker: u8 = 0;
const node_marker: u8 = 0;
const event_marker: u8 = 0;
const blob_id: ovl.Id = @ptrCast(&blob_marker);
const path2d_id: ovl.Id = @ptrCast(&path2d_marker);
const node_id: ovl.Id = @ptrCast(&node_marker);
const event_id: ovl.Id = @ptrCast(&event_marker);

const string_arg = Arg{ .kinds = &.{.string} };
const bool_arg = Arg{ .kinds = &.{.boolean} };
const any_arg = Arg{ .kinds = &.{.any} };
const double_arg = Arg{ .kinds = &.{.numeric} };

const xhr_open = [_]Overload{
    // undefined open(ByteString method, USVString url);
    .{ .function = "call_open", .args = &.{ string_arg, string_arg } },
    // undefined open(ByteString method, USVString url, boolean async,
    //                optional USVString? username = null, optional USVString? password = null);
    .{ .function = "call_open__1", .args = &.{
        string_arg,
        string_arg,
        bool_arg,
        .{ .kinds = &.{.string}, .nullable = true, .optionality = .optional },
        .{ .kinds = &.{.string}, .nullable = true, .optionality = .optional },
    } },
};

test "XMLHttpRequest.open - two arguments are the two-argument overload" {
    try testing.expectEqual(@as(usize, 0), try pick(&xhr_open, &.{ .{ .kind = .string }, .{ .kind = .string } }));
}

test "XMLHttpRequest.open - an async argument selects the five-argument overload, whatever its value" {
    // `open("GET", url, false)` is how a synchronous request is made, and it
    // is also what `open("GET", url, undefined)` means: argcount is 3 either
    // way, and only the second overload has an entry of length 3.
    try testing.expectEqual(@as(usize, 1), try pick(&xhr_open, &.{ .{ .kind = .string }, .{ .kind = .string }, .{ .kind = .boolean } }));
    try testing.expectEqual(@as(usize, 1), try pick(&xhr_open, &.{ .{ .kind = .string }, .{ .kind = .string }, .{} }));
    try testing.expectEqual(@as(usize, 1), try pick(&xhr_open, &.{ .{ .kind = .string }, .{ .kind = .string }, .{ .kind = .boolean }, .{ .kind = .null }, .{ .kind = .string } }));
}

test "XMLHttpRequest.open - extra arguments clamp argcount to maxarg" {
    const six = [_]Fake{ .{ .kind = .string }, .{ .kind = .string }, .{ .kind = .boolean }, .{}, .{}, .{ .kind = .number } };
    try testing.expectEqual(@as(usize, 1), try pick(&xhr_open, &six));
}

test "XMLHttpRequest.open - one argument has no entry, which is a TypeError" {
    try testing.expectError(error.TypeError, pick(&xhr_open, &.{.{ .kind = .string }}));
    try testing.expectError(error.TypeError, pick(&xhr_open, &.{}));
}

const window_post_message = [_]Overload{
    // undefined postMessage(any message, USVString targetOrigin, optional sequence<object> transfer = []);
    .{ .function = "call_postMessage", .args = &.{
        any_arg,
        string_arg,
        .{ .kinds = &.{.sequence}, .optionality = .optional },
    } },
    // undefined postMessage(any message, optional WindowPostMessageOptions options = {});
    .{ .function = "call_postMessage__1", .args = &.{
        any_arg,
        .{ .kinds = &.{.dictionary}, .optionality = .optional },
    } },
};

test "Window.postMessage - one argument is the options overload" {
    try testing.expectEqual(@as(usize, 1), try pick(&window_post_message, &.{.{ .kind = .string }}));
}

test "Window.postMessage - a string second argument is targetOrigin" {
    try testing.expectEqual(@as(usize, 0), try pick(&window_post_message, &.{ .{ .kind = .object }, .{ .kind = .string } }));
}

test "Window.postMessage - an object second argument is the options dictionary" {
    // Step 12.11: an object, and an entry with a dictionary type.
    try testing.expectEqual(@as(usize, 1), try pick(&window_post_message, &.{ .{ .kind = .number }, .{ .kind = .object } }));
}

test "Window.postMessage - undefined at the distinguishing index picks the optional argument" {
    // Step 12.2.
    try testing.expectEqual(@as(usize, 1), try pick(&window_post_message, &.{ .{ .kind = .number }, .{} }));
}

test "Window.postMessage - three arguments are the targetOrigin overload" {
    try testing.expectEqual(@as(usize, 0), try pick(&window_post_message, &.{ .{ .kind = .number }, .{ .kind = .string }, .{ .kind = .object, .iterable = true } }));
}

test "Window.postMessage - null at the distinguishing index is the dictionary" {
    // Step 12.3: null, and an entry with a dictionary type at i.
    try testing.expectEqual(@as(usize, 1), try pick(&window_post_message, &.{ .{ .kind = .number }, .{ .kind = .null } }));
}

const form_data_append = [_]Overload{
    // undefined append(USVString name, USVString value);
    .{ .function = "call_append", .args = &.{ string_arg, string_arg } },
    // undefined append(USVString name, Blob blobValue, optional USVString filename);
    .{ .function = "call_append__1", .args = &.{
        string_arg,
        .{ .kinds = &.{.{ .interface = blob_id }} },
        .{ .kinds = &.{.string}, .optionality = .optional },
    } },
};

test "FormData.append - a Blob is the Blob overload" {
    try testing.expectEqual(@as(usize, 1), try pick(&form_data_append, &.{ .{ .kind = .string }, .{ .kind = .object, .platform = blob_id } }));
}

test "FormData.append - a string, a number or another platform object is the string overload" {
    try testing.expectEqual(@as(usize, 0), try pick(&form_data_append, &.{ .{ .kind = .string }, .{ .kind = .string } }));
    // Step 12.15: no numeric entry, so the string entry takes a number.
    try testing.expectEqual(@as(usize, 0), try pick(&form_data_append, &.{ .{ .kind = .string }, .{ .kind = .number } }));
    // A Node is a platform object, but not a Blob: step 12.4 does not match,
    // and step 12.15 falls to the string overload.
    try testing.expectEqual(@as(usize, 0), try pick(&form_data_append, &.{ .{ .kind = .string }, .{ .kind = .object, .platform = node_id } }));
}

test "FormData.append - three arguments are the Blob overload" {
    try testing.expectEqual(@as(usize, 1), try pick(&form_data_append, &.{ .{ .kind = .string }, .{ .kind = .object, .platform = blob_id }, .{ .kind = .string } }));
}

const element_scroll = [_]Overload{
    // undefined scroll(optional ScrollToOptions options = {});
    .{ .function = "call_scroll", .args = &.{.{ .kinds = &.{.dictionary}, .optionality = .optional }} },
    // undefined scroll(unrestricted double x, unrestricted double y);
    .{ .function = "call_scroll__1", .args = &.{ double_arg, double_arg } },
};

test "Element.scroll - by argument count" {
    try testing.expectEqual(@as(usize, 0), try pick(&element_scroll, &.{}));
    try testing.expectEqual(@as(usize, 0), try pick(&element_scroll, &.{.{ .kind = .object }}));
    try testing.expectEqual(@as(usize, 1), try pick(&element_scroll, &.{ .{ .kind = .number }, .{ .kind = .number } }));
}

const path_fill = [_]Overload{
    // undefined fill(optional CanvasFillRule fillRule = "nonzero");
    .{ .function = "call_fill", .args = &.{.{ .kinds = &.{.string}, .optionality = .optional }} },
    // undefined fill(Path2D path, optional CanvasFillRule fillRule = "nonzero");
    .{ .function = "call_fill__1", .args = &.{
        .{ .kinds = &.{.{ .interface = path2d_id }} },
        .{ .kinds = &.{.string}, .optionality = .optional },
    } },
};

test "CanvasDrawPath.fill - a Path2D is the path overload, an enum string is not" {
    try testing.expectEqual(@as(usize, 0), try pick(&path_fill, &.{}));
    try testing.expectEqual(@as(usize, 1), try pick(&path_fill, &.{.{ .kind = .object, .platform = path2d_id }}));
    try testing.expectEqual(@as(usize, 0), try pick(&path_fill, &.{.{ .kind = .string }}));
    // Undefined at the distinguishing index, and the first overload's
    // argument is optional there: step 12.2.
    try testing.expectEqual(@as(usize, 0), try pick(&path_fill, &.{.{}}));
    try testing.expectEqual(@as(usize, 1), try pick(&path_fill, &.{ .{ .kind = .object, .platform = path2d_id }, .{ .kind = .string } }));
}

// The example from "compute the effective overload set":
//   /* f1 */ undefined f(DOMString a);
//   /* f2 */ undefined f(Node a, DOMString b, double... c);
//   /* f3 */ undefined f();
//   /* f4 */ undefined f(Event a, DOMString b, optional DOMString c, double... d);
const spec_example = [_]Overload{
    .{ .function = "f1", .args = &.{string_arg} },
    .{ .function = "f2", .args = &.{
        .{ .kinds = &.{.{ .interface = node_id }} },
        string_arg,
        .{ .kinds = &.{.numeric}, .optionality = .variadic },
    } },
    .{ .function = "f3", .args = &.{} },
    .{ .function = "f4", .args = &.{
        .{ .kinds = &.{.{ .interface = event_id }} },
        string_arg,
        .{ .kinds = &.{.string}, .optionality = .optional },
        .{ .kinds = &.{.numeric}, .optionality = .variadic },
    } },
};

test "spec example - variadic and optional truncations" {
    try testing.expectEqual(@as(usize, 2), try pick(&spec_example, &.{}));
    try testing.expectEqual(@as(usize, 0), try pick(&spec_example, &.{.{ .kind = .string }}));

    const node = Fake{ .kind = .object, .platform = node_id };
    const event = Fake{ .kind = .object, .platform = event_id };
    try testing.expectEqual(@as(usize, 1), try pick(&spec_example, &.{ node, .{ .kind = .string } }));
    try testing.expectEqual(@as(usize, 3), try pick(&spec_example, &.{ event, .{ .kind = .string } }));
    // f2's variadic entry of length 3 against f4's optional DOMString.
    try testing.expectEqual(@as(usize, 1), try pick(&spec_example, &.{ node, .{ .kind = .string }, .{ .kind = .number } }));
    try testing.expectEqual(@as(usize, 3), try pick(&spec_example, &.{ event, .{ .kind = .string }, .{ .kind = .string } }));
    // Length 5 is past maxarg (4): argcount clamps to 4, and f2's variadic
    // expansion still has an entry there.
    try testing.expectEqual(@as(usize, 1), try pick(&spec_example, &.{ node, .{ .kind = .string }, .{ .kind = .number }, .{ .kind = .number }, .{ .kind = .number } }));
}

test "no entry matches the distinguishing value - TypeError" {
    // Two interface overloads and neither is implemented by the value.
    const two = [_]Overload{
        .{ .function = "a", .args = &.{.{ .kinds = &.{.{ .interface = node_id }} }} },
        .{ .function = "b", .args = &.{.{ .kinds = &.{.{ .interface = event_id }} }} },
    };
    try testing.expectError(error.TypeError, pick(&two, &.{.{ .kind = .number }}));
    try testing.expectEqual(@as(usize, 1), try pick(&two, &.{.{ .kind = .object, .platform = event_id }}));
}

test "a union argument matches through its flattened member types" {
    // f((Node or DOMString) x) and f(boolean x, boolean y): argument count
    // decides here, but the union's members must still be seen at d.
    const set = [_]Overload{
        .{ .function = "u", .args = &.{.{ .kinds = &.{ .{ .interface = node_id }, .string } }} },
        .{ .function = "b", .args = &.{.{ .kinds = &.{.sequence} }} },
    };
    try testing.expectEqual(@as(usize, 0), try pick(&set, &.{.{ .kind = .object, .platform = node_id }}));
    try testing.expectEqual(@as(usize, 1), try pick(&set, &.{.{ .kind = .object, .iterable = true }}));
    // A plain non-iterable object: not a platform object, not iterable - the
    // string member takes it (step 12.15).
    try testing.expectEqual(@as(usize, 0), try pick(&set, &.{.{ .kind = .object }}));
}

test "functionLength - the fewest required arguments of any overload" {
    try testing.expectEqual(@as(usize, 2), ovl.functionLength(&xhr_open));
    try testing.expectEqual(@as(usize, 1), ovl.functionLength(&window_post_message));
    try testing.expectEqual(@as(usize, 0), ovl.functionLength(&element_scroll));
    try testing.expectEqual(@as(usize, 0), ovl.functionLength(&spec_example));
}

# Architecture: A setter and an operation converted the same type through different code

**Date**: 2026-09-26
**Lesson**: Attribute setters converted their value with `interface.zig`'s `convertV8ToZig`, operation arguments with `conversions.fromV8Value`, and the two disagreed on every numeric type.

**Why**: `fromV8Value` implements WebIDL's ToNumber-then-ConvertToInt. `convertV8ToZig` special-cased each numeric type before falling through to it, and its special cases called helpers that rejected anything not already a number. Nothing compared the two paths, and most tests assign numbers.

**What Happened**: `textarea.rows = "7"`, `domRect.x = "2.5"` and every other numeric attribute set from a string threw a TypeError, while `range.setStart(node, "2")` worked. A six-line probe - three setters, one operation, one V8-native control - showed the split at once. The same branches narrowed a `long` to `short` or `byte` with `@intCast`, which would have panicked on 70000 instead of wrapping.

**Fix**: the helpers do ToNumber and ConvertToInt themselves, and `convertV8ToZig` sends every integer and floating-point type to `fromV8Value` (77f9b5016). crane/numeric-attribute-conversion.html pins both paths.

**Takeaway**: **When one WebIDL type is converted in two places, test the same value through both.** A probe that assigns a string to a setter and passes it to an operation separates "conversion is wrong" from "this member is unimplemented" in one run.

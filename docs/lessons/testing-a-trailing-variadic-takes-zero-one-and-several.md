# Testing: A trailing variadic takes zero, one and several arguments

**Date**: 2026-10-03
**Lesson**: The binding's two- and three-parameter paths converted the ONE value at a trailing variadic's index as the whole slice, so `policy.createHTML("x", "a")` threw a TypeError while `createHTML("x")` worked.

**Why**: The variadic's default (an empty slice) is what every existing call exercised; the code path that converts arguments from the variadic's index onward existed only for a sole variadic.

**What Happened**: TrustedTypePolicy's createHTML/createScript/createScriptURL(input, ...arguments) failed every WPT case passing extra arguments.

**Fix**: 51575bd41: the 2/3-parameter operation, constructor and static paths collect `args[index..]`; tests/v8/trailing_variadic_test.zig calls through the real binding with 0, 1 and 3 extra arguments and measures that the extra arguments' handles go when the call returns.

**Takeaway**: **Test a variadic through the real binding with zero, one and several arguments - the default (empty) case proves nothing about conversion.**

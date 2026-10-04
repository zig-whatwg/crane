# Architecture: A conversion that fails part-way has already converted the rest

**Date**: 2026-10-04
**Lesson**: A dictionary's members and an overload variant's arguments are converted one at a time; when a later one fails, the earlier ones are converted values - copied strings, kept `any` handles - and a bare `try` drops them. And a path that builds arguments must also be the path that frees them: the overloaded constructor built its ConstructorArgs and freed nothing.

**Why**: `try` returns the error and runs only `errdefer`s; the partly filled struct is a local nobody frees. The binding's argument cleanup (`freeArgument`) was written for the one-argument-at-a-time operation path, and two other builders - `conversions.fromV8Value`'s dictionary loop and `overload_resolver.buildVariant` - had no cleanup of their own. `callConstructorWithArgs`' overloaded branch passed the resolved union to the constructor and returned.

**What Happened**: ~900 of main's 959 sweep `leaked:` lines were urlpattern's: urlpattern.any.js 376, urlpattern.https.any.js 375, -hasregexpgroups 54, -constructor 7 per file alone - every `new URLPattern(...)` leaked its input dictionary's strings and base URL, and a failed first variant leaked what it had converted before the next was tried. fetch's request-init-stream leaked 3: a RequestInit whose `duplex` member failed after `body` had been copied.

**Fix**: The cleanup helpers became module-level (`interface.freeConvertedArg`, `freeArgument`); the dictionary loop and `buildVariant` count the members/arguments converted and `errdefer` frees exactly those; `overload_resolver.freeConstructorOverload` frees the chosen variant's arguments after the constructor returns (every impl taking ConstructorArgs was read: they copy or hold what they keep). All five files went to 0. tests/v8/partial_conversion_cleanup_test.zig drives both builders with std.testing.allocator.

**Takeaway**: **Every place that converts a list of values one by one needs an errdefer for the ones already converted, and every place that builds arguments needs the matching free - check builders, not just the call path you know.**

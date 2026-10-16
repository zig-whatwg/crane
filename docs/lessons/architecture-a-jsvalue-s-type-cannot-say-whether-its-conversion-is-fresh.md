# Architecture: A JSValue's type cannot say whether its conversion is fresh

**Date**: 2026-10-16
**Lesson**: When a converter releases what it made, decide on the VALUE for a runtime.JSValue or a union. Decide on the type only where every value of the type converts the same way.

**Why**: `conversions.toV8Value` makes a new Global for undefined, null, a boolean, a number or a string. It hands back the impl's own handle for `.handle` and the wrapper cache's wrapper for `.instance`. The type-level predicates (`dictionaryMemberValueIsOwned`, `getterValueIsOwned`) must answer "kept" for `runtime.JSValue` and for unions, because releasing a borrowed handle is a use-after-free. So every fresh value of those types leaked: one Global per entry or element, on every call.

**What Happened**: URLPattern exec()'s result leaked 9 Globals per successful call on main (leaks --atExit: 182 for 20 calls; Codex row 26 Q14).
- The groups record, `record<USVString, (USVString or undefined)>` with JSValue values, leaked a Global per group.
- The `inputs` sequence of the URLPatternInput union leaked its String.

Once lane regexop made URLPattern match properly, many more exec() calls succeeded. urlpattern/urlpattern.any.js went from 2,586 leaks (main) to 3,632, though the code that leaked was unchanged.

**Fix**:
1. `jsValueConversionIsFresh(value)`: an allowlist of the JSValue arms that toV8Value makes a Global for (undefined, null, boolean, number, string). `.handle`, `.instance` and any unnamed arm are kept. A test names every arm, so a new arm fails until someone classifies it.
2. The record branch releases a JSValue value when that predicate says so. toV8Sequence releases a union element when `unionValueIsOwned` (the existing rule for returned unions) says so.
3. Result: crane/up-exec-result-retention.html 182 -> 2 leaks (the snapshot's two roots), urlpattern.any.js 2,586 -> 2.

**Takeaway**: **A type-level "is it fresh?" answer must be "kept" for JSValue and unions, so it leaks every fresh value: ask the value (its arm) with an allowlist, and keep borrowed arms as the default.**

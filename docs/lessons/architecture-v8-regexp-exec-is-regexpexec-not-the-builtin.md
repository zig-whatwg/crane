# Architecture: V8's RegExp::Exec is RegExpExec, not the built-in exec

**Date**: 2026-10-09
**Lesson**: `v8::RegExp::Exec` looks `exec` up on the regexp and calls whatever it finds, so a native step that matches with it in the page's realm runs the page's script and writes the page's legacy RegExp statics; match in a context of the adapter's own.

**Why**: The header says Exec is "Equivalent to RegExp.prototype.exec", which reads like the built-in. It is ECMAScript RegExpExec: api.cc calls `RegExpUtils::RegExpExec(isolate, regexp, subject, undefined)`, which does `Object::GetProperty(regexp, "exec")` and `Execution::Call`s it (regexp-utils.cc). In the page's realm a replaced `RegExp.prototype.exec` decides the answer, and even the real one updates `RegExp.$1`, `lastMatch` and `input` - which no browser lets an input's pattern check do.

**What Happened**: HTML 4.10.5.3.6 (input pattern) needs RegExpCreate(pattern, "v") and RegExpBuiltinExec with built-in intrinsics only (forms Q6, engine.matchesPatternAttribute). A negative control on the linked 13.1 - matching in the page's context instead of a new one - failed the poisoned-exec and legacy-statics tests (7/9). A new context per call fixed both but cost ~230 us a call, too slow for checkValidity and :invalid. Blink keeps one ScriptRegexp context per isolate (V8PerIsolateData::EnsureScriptRegexpContext) and HTMLInputElement caches its compiled ScriptRegexp; Gecko matches in a junk scope; WebKit uses Yarr with no JS object at all.

**Fix**: The V8 adapter's AgentRecord owns a PatternMatcher (v8_wrapper.cpp): one utility context made on first use, plus a 16-entry MRU cache of compiled anchored regexps (invalid patterns cached as invalid), deleted at the agent's end before its isolate is disposed. Strings cross as UTF-16, lone surrogates kept. The step runs under NativeStepScope. First call of an agent 236 us, a new pattern 14 us, a repeat 1.6 us (Debug). Note also that Crane's V8 is built with `v8_enable_i18n_support = false`: `\p{...}` is a SyntaxError in every realm.

**Takeaway**: **A V8 API named after a built-in may still do the spec's observable lookups; read api.cc for what it calls, and run built-in-only steps in a context no script can reach - one per agent, not one per call.**

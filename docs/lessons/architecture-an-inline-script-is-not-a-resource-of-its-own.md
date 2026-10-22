# Architecture: An inline script is not a resource of its own - carry where its text starts

**Date**: 2026-10-19
**Lesson**: An inline `<script>`'s text was compiled as if it were a file of its own, so everything V8 reported from it - an uncaught error's line and column, a parse error, the running-script location a CSP violation reads, an inline module's evaluation error - counted from the script's first line instead of the document's, and a blocked inline script or style, where no script runs, had no location at all.

**Why**: HTML's "create a classic script" has no position, but every engine compiles an inline script at its place in the document: the parser's position after the start tag travels with the source text (Blink's ScriptSourceCode start_position_ and WebKit's TextPosition) into v8::ScriptOrigin's resource_line_offset / resource_column_offset (JavaScriptCore: JSEvaluateScript's startingLineNumber). The protocol carried text and URL only, and the parser recorded no position.

**What Happened**: Codex row 46 found blockeduri-eval reporting line 11 for 15 and blockeduri-inline 0 for 15; window-onerror-runtime-error got 8 for 36, evaluation-error-5 1 for 16, seven targeting-for-inline-handler-* files 4-8 for 10-13, and runtime-error-in-attribute no file name (the handler was compiled with no ScriptOrigin at all). Lane engine1 added engine.SourcePosition (`ScriptSource.embedded`, parseModule's `start`, EventHandlerSource lineno/colno -> ScriptOrigin), recorded the tokenizer position for script and style elements as the parser creates them (read through the document's InputStreamManager, so no field on every node), and located a blocked inline element's violation at it when runningScriptLocation finds no script (Blink's SourceLocation::Capture order: the stack when script runs, else the context line).

**Fix**:
1. The position is a property of the source, not of the call: a third ScriptSource arm, so the ~20 callers that run scripts of their own changed nothing.
2. Record it only where it is used: the parser's position is read when a script or style element is created, never stored on every node.
3. Use it only when the parser prepares the element: a script whose text changed later, or one inserted from script, has none (Blink passes MinimumPosition outside the parser).
4. V8 offsets the column of the first line only; the HTML input stream counts code points where V8 counts UTF-16 units - a non-BMP character earlier on the start tag's line shifts first-line columns by one (stated). And document.write'd newlines advance Crane's line count, where Blink's SegmentedString excludes inserted text from line numbering (stated; a follow-up).

**Takeaway**: **When a report crosses the engine seam with a location, ask where the engine thinks the source starts; text embedded in a larger resource needs its offset carried beside it, or every line it reports is relative to nothing the page can see.**

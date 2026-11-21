# Workflow: Trace a single shipper's expectation to every mechanism before scoping a lane for it

**Date**: 2026-11-21
**Lesson**: When only one browser passes a key, find EVERY engine mechanism that produces its value before a lane is scoped to "build the feature that flips it" - the feature may be one of several, and the others may be that browser's alone.

**Why**: resource-timing/render-blocking-status-link.html's last key,
'stylesheet-inline-imported-dynamic-docwrite' = "blocking", was traced (lane blk6) to Chrome's speculative preload
scanner (css_preload_scanner.cc EmitRule with in_body_ false), and a lane (pscan1) was scoped by user ruling to
build the scanner and reach 38/38. Reading Blink's HTMLDocumentParser::insert showed the insertion scanner runs only
`if (IsPaused() && preloader_)` - and the parser is paused there only because Chrome pauses PARSING on an in-body
style sheet (DidAddPendingParserBlockingStylesheet -> WaitingForStylesheets), which WebKit
(HTMLDocumentParser isWaitingForScripts) and Gecko (nsHtml5Parser::Parse, mBlocked by scripts only) do not, and the
spec does not (document write steps step 11; HTML 13.2.8 starts the speculative parser only while a pending
parsing-blocking script waits). The scanner alone could never flip the key.

**What Happened**: The lane's first message, before any code, said so; the integrator took it to the user, who
ruled a new exemption kind (`single-shipper`, 2026-11-21) for a file testing a feature only one browser ships whose
remaining failures hinge on a mechanism where Crane does what the other two and the spec do. The scanner was still
built (HTML 13.2.8, all three ship it) for its real target, html/syntax/speculative-parsing/.

**Fix**: For a key only one browser passes:
1. Read the shipping engine's code from the value backwards to the first condition, every condition on the path
   (here: `IsPaused()`, then why the parser is paused at that write).
2. For each condition, ask whether the other two engines and the spec share it (golden rule 2 per mechanism).
3. Scope the lane to what the majority shares; name the single-shipper mechanisms in the scope message.

**Takeaway**: **A single shipper's expected value can hinge on several mechanisms; trace all of them in its engine
before scoping work to flip it, and check each against the other two engines and the spec.**

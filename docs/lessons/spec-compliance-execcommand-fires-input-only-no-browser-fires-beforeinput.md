# Spec Compliance: execCommand fires input only - no browser fires beforeinput for it

**Date**: 2026-10-23
**Lesson**: The Editing draft's `execCommand()` steps fire a cancelable `beforeinput` before the action, but no browser does; a script's execCommand fires `input` alone, and only user input (keys, IME, paste) gets `beforeinput`.

**Why**: The execCommand draft (w3c/editing, "Methods to query and execute commands", step 4) was written to make script commands observable to editors. Input Events as shipped tie `beforeinput` to the user's intent, so that an editor can cancel what the USER did; a script that calls execCommand already knows what it is doing. All three engines kept that line, and WPT encodes it as `input-events/input-events-exec-command.html`, titled "execCommand() should only trigger 'input'".

**What Happened**: Lane editing1 built the delete and forwardDelete commands from the spec text and designed the key path as "Backspace calls execCommand('delete')", with the method steps firing both events for keys and script alike. The integrator asked for browser evidence before wiring the events. wpt.fyi (Chrome 156, Firefox 158 at c645564b0e) passes every "(shouldn't fire beforeinput)" subtest of that file; its failures are dataTransfer details. Had the spec's step 4 shipped, every execCommand would have fired a spurious `beforeinput` and failed those subtests, and a listener cancelling it would have blocked script edits no browser blocks.

**Fix**:

1. The script path (`Document.execCommand` -> `html.execcommand.execCommand`) runs the method's steps 3 and 5-8: enabled check, the action, `input` with the mapped inputType when the DOM changed. No `beforeinput`.
2. The key path (`user_input` -> `html.execcommand.deleteByKey`) fires the cancelable `beforeinput` (deleteContentBackward / deleteContentForward) at the affected editing host, re-checks "enabled" (the listener may have moved the selection), then runs the SAME action and fires `input`. With no selection range it does nothing and fires nothing (`editing/other/no-beforeinput-when-no-selection.html`).
3. The two paths share the action, not the method steps, so they can never drift in which events they fire.

**Takeaway**: **Before wiring events from a spec's method steps, read the WPT file that names the event and the browsers' per-subtest results: a cancelable event the spec fires and no browser does is a compatibility break, not conformance - share the action between user and script paths, and let only the user path announce itself.**

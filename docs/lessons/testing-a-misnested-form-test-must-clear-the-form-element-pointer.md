# Testing: A misnested-form test must clear the form element pointer

**Date**: 2026-10-10
**Lesson**: While the HTML parser's form element pointer is set, every later form start tag outside a template is ignored. A test page with several misnested-form cases needs a `</form>` after each case, or the later forms are never created.

**Why**: "In body" and "in table": "a start tag whose tag name is form - if the form element pointer is not null, and there is no template element on the stack of open elements, then this is a parse error; ignore the token." Misnested markup like `<div><form></div>` pops the form off the stack but leaves the pointer set. Only an end tag "form" clears it, and it clears the pointer even when the form is not in scope (a parse error, after the pointer is set to null).

**What Happened**: lf2-parser-form-association.html ("red by design" until the parser's form association landed) put a misnested `<div><form id=misnested></div>` before a `<table><form id=tabled>` case. With the association implemented it still failed: `tabled` was null, because the parser ignored its start tag. Every browser does the same, so that subtest could never have passed. Adding a `</form>` between the cases fixed the test, not the engine (2/4 -> 4/4).

**Fix**: End each case with `</form>`. To test that parsing template contents makes no association, put the template case BEFORE the `</form>`, while the pointer is still set.

**Takeaway**: **A "red by design" test is only evidence once it passes in a browser. Check its markup against the parser's state (the form element pointer, the head pointer, the open-element stack) before treating it as the target.**

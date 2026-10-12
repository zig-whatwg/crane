# Spec Compliance: Form-associated does not mean listed

**Date**: 2026-10-12
**Lesson**: The form content attribute overrides ownership only for listed form-associated elements.

**Why**: Images can have a form owner, including one supplied by the parser, but they are not listed controls. HTML's "reset the form owner" step 4 therefore does not apply their form attribute; step 5 uses their nearest ancestor form.

**What Happened**: The shared `form_associated.formOwner` query applied a connected element's form attribute without testing the listed category. The new form named getter exposed the defect: an image inside one form could be redirected to another, and an external image could be incorrectly adopted.

**Fix**: Under codex-lpo Q8, use the existing `isListed` predicate inside the existing connected-and-form-attribute branch. Leave parser associations first and let unlisted elements fall through to the ancestor walk. The regression checks both a redirected descendant image and an external image. Compare seven alternating pairs of the parser fixture before committing because the query is shared.

**Takeaway**: **Use the category named by each form algorithm; membership in a broader category does not grant the narrower category's behavior.**

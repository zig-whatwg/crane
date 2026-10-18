# Spec Compliance: Textarea API and Submission Values Differ

**Date**: 2026-10-18
**Lesson**: A textarea's API value normalizes newlines; its form-entry value additionally applies hard wrapping.

**Why**: HTML defines raw value, API value, and submission value separately. The IDL `value` getter is therefore not the entire form-submission algorithm.

**What Happened**: Entry-list construction called `HTMLTextAreaElement.get_value` directly. Normalized newlines worked, but `wrap=hard` never inserted line breaks. The wrapping WPT failed even though the value getter was correct.

**Fix**: Keep the existing API getter and apply the wrapping transformation when constructing the textarea's form entry. Read `cols` and `wrap` through the generated interfaces. Insert LF without changing the original value or selection; serialization handles any later CRLF conversion. Pin the chosen implementation-defined break algorithm with native tests, including Unicode boundaries and idempotent round trips.

WebKit's `HTMLTextAreaElement::appendFormData` and Blink's `HTMLTextAreaElement::AppendToFormData` apply wrapping at this same boundary. See HTML 4.10.11, the textarea wrapping transformation, and 4.10.22.4 step 5.10.

**Takeaway**: **Follow the specification's particular value representation at each consumer; an IDL getter may expose a different one.**

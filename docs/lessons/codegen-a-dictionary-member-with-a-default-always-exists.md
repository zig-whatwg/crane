# Codegen: A dictionary member with a default always exists - write it to script

**Date**: 2026-10-17
**Lesson**: Converting a dictionary to script wrote only the members whose Zig value was not null, in Zig declaration order, with the inherited dictionary as a nested `base` object. A member with an IDL default that the impl left unset vanished, and so did a nullable member whose default is null - Sanitizer.get()'s `namespace: null`.

**Why**: Codegen keeps no default in the Zig struct: every optional member is `?T = null` (or a `webidl.Opt`), so null means "unset" and, for `DOMString? _namespace = null`, also "null". The input converter can live with that - an absent member stays null and the impl applies its default. The output converter cannot: WebIDL 2.7 says a default is "the value used by default when author code or specification text does not provide a value for that member", so the member exists and 3.2.18 writes it. Blink and Gecko initialise every defaulted member in their generated dictionary classes, so their ToV8 always writes it. And `base` is how codegen stores an inherited dictionary; 3.2.18 step 2 lists the dictionary and its ancestors, least-derived first, and writes every one's members onto the ONE object, each dictionary's in code-unit order - the order the input converter already read them in (`dictionaryMemberOrder`).

**What Happened**: Codex rows 41 and 59 (Sanitizer) found three return-shape defects their impls could not fix: attributes without `namespace`, elements as `{base: {name, namespace}, removeAttributes}`, and members in declaration order. sanitizer-config.html and sanitizer-modifiers.html failed 35 subtests on those alone (elements[0].name undefined read as "duplicates"). Looking for the defaults turned up a second loss: the IDL parser read `= {}` and `= []` as `null`, so `SetHTMLUnsafeOptions.sanitizer = {}` looked like a null default.

**Fix**:
1. The parser keeps `{}` and `[]` as `.emptyDictionary` and `.emptySequence`.
2. Codegen writes `member_defaults` - one tag literal per defaulted optional member (`.null`, `.{ .boolean = b }`, `.{ .number = n }`, `.{ .string = "s" }`, `.empty_sequence`, ...), so the dictionary files need no new import.
3. `toV8Value`'s dictionary branch (`writeDictionaryMembers`) writes the inherited dictionary's members onto the same object first, then its own in code-unit order; a member is written when present, else with its default. Only a `base` field that is a dictionary struct is inheritance: JsonLdOptions has a member named `base`.
4. Pinned by tests/v8/dictionary_output_shape_test.zig in script, through the generated Sanitizer and Event dictionaries, and tests/codegen/member_defaults_test.zig.

**Takeaway**: **Output conversion needs IDL facts input conversion can do without - a member's default, and that inheritance is storage, not shape. Before trusting a struct to describe a dictionary's JavaScript form, ask what its Zig null means.**

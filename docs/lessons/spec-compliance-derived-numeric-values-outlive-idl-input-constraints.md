# Spec Compliance: Derived Numeric Values Outlive IDL Input Constraints

**Date**: 2026-10-27
**Lesson**: A restricted WebIDL numeric input does not imply that every value later produced by the API is finite.

**Why**: WebIDL conversion validates caller inputs. An algorithm can subsequently overflow finite operands, divide internally, or create NaN. Reapplying the input conversion rule to those internal results changes the algorithm.

**What Happened**: The Typed OM audit initially treated non-finite values as unable to reach CSSUnitValue. Chrome156 and Safari27 probes showed that finite inputs such as CSS.px(1e308).mul(2) produce Infinity, and zero multiplied by such a result produces NaN. The integrator distinguished binding validation from arithmetic and property computation (Q81/Q83,2026-10-27). The same value also legitimately has different Typed OM and specified-property serialization: the literal Typed OM algorithm gives infinitypx or calc(infinitypx), while a specified width uses calc(infinity * 1px).

**Fix**: Keep restricted-double checks at the WebIDL boundary. Preserve algorithm-produced non-finite numbers in the existing numeric representation. When a property consumes one, use its existing math wrapper and its own computation/range rules. Test direct invalid inputs, derived values, constructor graph strings, specified text, reified values and computed ranges separately. Do not make the two serializers agree by introducing a nested-only formatting special case.

**Takeaway**: **Validate at the boundary that owns the rule; internal arithmetic and property computation have different obligations.**

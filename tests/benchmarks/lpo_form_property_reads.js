// Form interceptor regression benchmark. Run in a fresh gc_bench process:
// zig-out/bin/gc_bench 1 1 --body="$(cat tests/benchmarks/lpo_form_property_reads.js)"
// Build with the default ReleaseSafe gc-bench step; use the matching snapshot.
// Alternate BASE/TIP and TIP/BASE for seven pairs. Compare per-case medians;
// plain form properties must remain within 2x div.id at each document size.
// div.addEventListener also exposes the cost of reading an inherited method.
// A named hit on a base without the getter is undefined; report that fact.
// Date.now is used because gc_bench also supports realms without Performance.
(() => {
    let sink;
    function readTime(receiver, property) {
        for (let i = 0; i < 8; ++i) sink = receiver[property];
        let count = 64;
        for (;;) {
            const start = Date.now();
            for (let i = 0; i < count; ++i) sink = receiver[property];
            const elapsed = Date.now() - start;
            if (elapsed >= 50 || count >= 4194304) {
                return {count, milliseconds: elapsed, nanoseconds: elapsed * 1e6 / count,
                        resultType: typeof sink};
            }
            count *= 2;
        }
    }
    for (const size of [100, 1000, 5000]) {
        const doc = document.implementation.createHTMLDocument('form lookup benchmark');
        for (let i = 0; i < size; ++i) doc.body.appendChild(doc.createElement('div'));
        const div = doc.body.firstChild;
        div.id = 'control';
        const form = doc.createElement('form');
        for (let i = 0; i < 20; ++i) {
            const input = doc.createElement('input');
            input.id = 'id' + i;
            input.name = 'c' + i;
            form.appendChild(input);
        }
        doc.body.appendChild(form);
        const controls = form.elements;
        const cases = [
            ['div.id', div, 'id'],
            ['div.addEventListener', div, 'addEventListener'],
            ['form.submit', form, 'submit'],
            ['form.elements', form, 'elements'],
            ['form.method', form, 'method'],
            ['form.addEventListener', form, 'addEventListener'],
            ['form.c5', form, 'c5'],
            ['form.elements.c5', controls, 'c5'],
            ['form[5]', form, '5'],
        ];
        for (const [name, receiver, property] of cases) {
            console.log('LPO_BENCH ' + JSON.stringify({size, name, ...readTime(receiver, property)}));
        }
    }
    globalThis.lpoBenchmarkSink = sink;
})();

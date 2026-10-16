// Form interceptor regression benchmark. Run in a fresh gc_bench process:
// zig-out/bin/gc_bench 1 1 --body="$(cat tests/benchmarks/lpo_form_property_reads.js)"
// Build with the default ReleaseSafe gc-bench step; use the matching snapshot.
// Alternate BASE/TIP and TIP/BASE for seven pairs. Compare per-case medians;
// plain form properties must remain within 2x div.id at each document size.
// div.addEventListener also exposes the cost of reading an inherited method.
// A named hit on a base without the getter is undefined; report that fact.
// Date.now is used because gc_bench also supports realms without Performance.
// The mutation cases (lane formnamed) time one appendChild + remove of a div
// in the document, before and after 20 past names were recorded on the form:
// the past names map hears every mutation while it has entries.
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
    function mutationTime(parent) {
        const child = parent.ownerDocument.createElement('div');
        for (let i = 0; i < 8; ++i) parent.appendChild(child).remove();
        let count = 64;
        for (;;) {
            const start = Date.now();
            for (let i = 0; i < count; ++i) parent.appendChild(child).remove();
            const elapsed = Date.now() - start;
            if (elapsed >= 50 || count >= 4194304) {
                return {count, milliseconds: elapsed, nanoseconds: elapsed * 1e6 / count,
                        resultType: 'mutation'};
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
        const inputs = [];
        for (let i = 0; i < 20; ++i) {
            const input = doc.createElement('input');
            input.id = 'id' + i;
            input.name = 'c' + i;
            form.appendChild(input);
            inputs.push(input);
        }
        doc.body.appendChild(form);
        const controls = form.elements;
        const host = doc.body.children[size >> 1];
        console.log('LPO_BENCH ' + JSON.stringify({size, name: 'mutation (no past names)', ...mutationTime(host)}));
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
        // form.c<i> above recorded c5 only; record all 20, as a page reading
        // every control by name does.
        for (let i = 0; i < 20; ++i) sink = form['c' + i];
        console.log('LPO_BENCH ' + JSON.stringify({size, name: 'mutation (20 past names)', ...mutationTime(host)}));
        // A renamed control answers to its past name (step 3).
        inputs[5].name = 'renamed5';
        console.log('LPO_BENCH ' + JSON.stringify({size, name: 'form.c5 (past name)', ...readTime(form, 'c5')}));
    }
    globalThis.lpoBenchmarkSink = sink;
})();

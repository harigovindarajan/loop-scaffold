# Contributing

Thanks for your interest in improving the portable agent loop. Most contributions are
changes to the **canon docs** — the prose-and-protocol an agent reads — or to the
optional reconciler CLI that mechanizes it.

For larger changes (anything touching the kernel's plan shape, position function,
gates, taxonomy, or notes format), please
[open an issue](https://github.com/harigovindarajan/loop-scaffold/issues) first so the
approach can be agreed before you invest in a PR. By contributing, you agree that your
contributions are licensed under the [MIT license](LICENSE).

## The one thing to know

**Reference the kernel, never restate it.** [`LOOP.md`](LOOP.md) is the single source
of truth for the plan shape, the position function, the gate-commit invariant, and the
failure taxonomy. Every other doc links to the relevant `LOOP.md` section instead of
re-declaring it — a second normative copy anywhere is a defect even while the copies
agree, because they will drift. The review test: if a reviewer finds any kernel rule
normatively defined in two places, the rule has failed.

When unsure whether something is kernel or canon: if an agent needs it to run a loop
cold, it is kernel and already lives in `LOOP.md`; otherwise it references the kernel.

## Changing the docs

There is no build or linter for the docs. Validate a change by reading it against the
rule above and checking that every cross-reference resolves — relative links point at
files that exist, and section anchors match the target's headings.

After solving a non-obvious problem in or around the protocol, capture the learning in
[`docs/solutions/`](docs/solutions/) under the fitting category — it is the
compounding store, and the only part of `docs/` in version control.

## Changing the reconciler

[`reconciler/loop`](reconciler/) adds **no rules** — every behavior it implements is
defined in the kernel. If a change needs a rule that isn't in `LOOP.md`, it is a
kernel change first and a reconciler change second.

- Dependencies stay minimal by design: `bash`, `git`, `jq`, `shasum`/`sha256sum`.
- There is no test suite. Smoke-test against a throwaway fixture repo: `git init` a
  temp dir, commit [`examples/loop.minimal.json`](examples/loop.minimal.json) as its
  `loop.json`, and drive `validate` / `status` / `gate` / `note` / `next` through a
  full item.
- The script targets macOS's bash 3.2. Beware: quoted command substitutions inside
  array assignments get brace-expanded there — hoist them into plain variables first.

## Before you open a PR

1. **If you touched the reconciler:** `bash -n reconciler/loop`, then run the fixture
   smoke test above.
2. **If you touched the docs:** confirm links and anchors resolve, and that no kernel
   rule got restated outside `LOOP.md`.
3. Use clear, conventional commit messages (`feat:`, `fix:`, `docs:`, `chore:`) and
   open the PR against `main`.

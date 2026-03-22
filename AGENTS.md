# AGENTS.md

This repository is documentation-heavy and currently centers on a Helm chart
for remote build infrastructure. Keep edits narrow, deterministic, and easy to
review.

## Scope

- Do not revert unrelated work already present in the tree.
- Prefer small, composable changes over broad repo reshaping.
- Keep README and `docs/` aligned when changing product positioning or client
  support language.

## Diagrams

- Source diagrams live in `docs/diagrams/*.d2`.
- Generated artifacts live beside the sources as `docs/diagrams/*.svg`.
- Use `just diagrams` to render SVGs.
- Use `just check-diagrams` to verify committed SVGs are up to date.
- Commit both the `.d2` source and the generated `.svg`.
- Prefer deterministic local rendering over AI-generated SVG output in the
  checked-in pipeline.

## Client Positioning

- rek8s exposes REAPI-style endpoints; document client compatibility carefully.
- Bazel is the primary client for Buildfarm.
- Buildbarn supports a broader client set including Bazel, Buck2, Reninja,
  Pants, BuildStream, and `recc`.
- When mentioning Reninja, describe it as a Ninja-compatible REAPI client, not
  as a Bazel replacement.

## Editing Rules

- Use ASCII unless the file already relies on Unicode.
- Prefer `rg` for search.
- Use `apply_patch` for manual file edits.
- If you update docs examples, keep example filenames and README references in
  sync.

## Verification

- For docs and diagram changes, run the smallest relevant checks locally.
- If a command could not be run, say so explicitly in the handoff.

## Git

- When asked to commit, stage only the files that belong to the requested work.
- Avoid bundling unrelated chart, template, or values changes into the same
  commit.

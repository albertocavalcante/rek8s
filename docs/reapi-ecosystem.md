# REAPI Ecosystem

This page tracks the broader Remote Execution API ecosystem around rek8s.
It exists to separate:

- what rek8s supports as charted providers today
- what Bazel and the wider `remote-apis` ecosystem recognize as compatible
  clients and servers

## Current Chart Scope

rek8s currently charts these providers:

| Role | Provider | Status in rek8s |
|------|----------|-----------------|
| **BES** | BuildBuddy OSS | Supported today |
| **RBE** | Buildfarm | Supported today |
| **RBE** | Buildbarn | Supported today |

Everything else on this page is ecosystem context, not a statement that rek8s
already deploys it.

## RBE Servers To Track

### Bazel's current self-service list

As of Bazel's `Remote Execution Services` page updated on **2026-02-26**,
the self-service remote execution implementations called out are:

- [Buildbarn](https://github.com/buildbarn)
- [Buildfarm](https://github.com/bazelbuild/bazel-buildfarm)
- [BuildGrid](https://buildgrid.build/)
- [NativeLink](https://github.com/TraceMachina/nativelink)

Source:
- [Bazel: Remote Execution Services](https://bazel.build/versions/8.6.0/community/remote-execution-services)

### Additional ecosystem servers in `remote-apis`

The upstream [`remote-apis`](https://github.com/bazelbuild/remote-apis)
README lists a broader set of server implementations and cache services,
including:

- [Aspect Build](https://www.aspect.build/)
- [bazel-remote](https://github.com/buchgr/bazel-remote) as a **cache-only**
  implementation
- [BuildBuddy](https://www.buildbuddy.io/)
- [EngFlow](https://www.engflow.com/)
- [Flare Build Execution](https://flare.build/products/flare-build-execution)
- [Justbuild](https://github.com/just-buildsystem/justbuild/blob/master/doc/tutorial/just-execute.org)
- [Kajiya](https://chromium.googlesource.com/build/+/refs/heads/main/kajiya/)

Source:
- [remote-apis README](https://github.com/bazelbuild/remote-apis)

### Notable candidates for rek8s follow-up

These are the most relevant additional backends for future rek8s evaluation:

| Provider | Why it matters | Notes |
|----------|----------------|-------|
| [NativeLink](https://github.com/TraceMachina/nativelink) | Modern high-performance cache + remote execution system | Upstream positions it as compatible with Bazel, Buck2, Goma, and Reclient; current upstream license is `FSL-1.1-Apache-2.0` |
| [BuildGrid](https://buildgrid.build/) | Well-known Apache-2.0 REAPI server | Good candidate when teams want another OSS server family beyond Buildfarm/Buildbarn |
| [bazel-remote](https://github.com/buchgr/bazel-remote) | Useful **cache-only** deployment target | Relevant when teams want remote cache without full remote execution |

## Clients Beyond Bazel, Buck2, and Reninja

The upstream `remote-apis` README currently lists these client-side users of
REAPI:

- [Bazel](https://bazel.build)
- [Buck2](https://github.com/facebook/buck2)
- [BuildStream](https://buildstream.build/)
- [Justbuild](https://github.com/just-buildsystem/justbuild)
- [Pants](https://www.pantsbuild.org)
- [Please](https://please.build)
- [Recc](https://gitlab.com/bloomberg/recc)
- [Reclient](https://github.com/bazelbuild/reclient)
- [Siso](https://chromium.googlesource.com/build/+/refs/heads/main/siso/)

Source:
- [remote-apis README](https://github.com/bazelbuild/remote-apis)

### Which of these are especially worth knowing?

| Client | Category | Why it matters |
|--------|----------|----------------|
| [Reclient](https://github.com/bazelbuild/reclient) | Command wrapper / integration layer | Not a build system by itself; it integrates with an existing build system to enable remote execution and caching |
| [Siso](https://chromium.googlesource.com/build/+/refs/heads/main/siso/) | Build client used in Chromium infrastructure | Important example of a non-Bazel REAPI client in a large production environment |
| [BuildStream](https://buildstream.build/) | Build system | Broadens rek8s beyond Bazel-centric language |
| [Pants](https://www.pantsbuild.org) | Build system | Common Python monorepo use case |
| [Please](https://please.build) | Build system | Another open-source REAPI client worth tracking |
| [Recc](https://gitlab.com/bloomberg/recc) | Remote-execution-oriented client tooling | Useful when discussing non-Bazel client ecosystems |

Source for `Reclient` description:
- [reclient README](https://github.com/bazelbuild/reclient)

## Tooling To Know

Two tools are especially useful around deployed clusters:

- [`bf-client`](https://github.com/buildfarm/bf-client): a Buildfarm-specific
  terminal UI that talks to the Buildfarm Redis backplane and REAPI endpoint
- [`reclient`](https://github.com/bazelbuild/reclient): an integration layer
  that lets an existing build system use remote execution and remote caching

See [`client-tooling.md`](client-tooling.md) for rek8s-specific usage notes.

## BES Caveat

REAPI compatibility is **not** the same thing as Build Event Service
compatibility.

- Many tools can use a remote cache and remote executor over REAPI.
- Fewer tools expose a Bazel-style `--bes_backend` / results URL workflow.
- In rek8s docs today, BuildBuddy BES examples are intentionally focused on
  clients we can describe concretely here: Bazel and Reninja.

This distinction matters when evaluating future client examples. A tool may be
a strong fit for `rbe.*` without being a good fit for `bes.*`.

## Suggested Future Work

- Evaluate [NativeLink](https://github.com/TraceMachina/nativelink) as a third
  RBE backend candidate.
- Evaluate [BuildGrid](https://buildgrid.build/) as another OSS server family.
- Consider a cache-only profile based on
  [bazel-remote](https://github.com/buchgr/bazel-remote).
- Split examples into `BES-capable clients` and `REAPI-only clients`.

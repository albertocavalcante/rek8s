# Client And Operator Tooling

This page covers tools that interact with a deployed rek8s cluster without
being charted providers themselves.

## Quick Map

| Tool | Type | Best fit |
|------|------|----------|
| `bf-client` | Buildfarm operator UI | Live queue and worker visibility for Buildfarm |
| `reclient` | REAPI integration layer | Wrapping existing build actions for remote exec/cache |
| `tools_remote` / `remote_client` | REAPI debug client | Downloading blobs, inspecting actions, replaying failures |
| `remotetool` | REAPI debug toolkit | Downloading action results, re-executing actions, cache inspection |
| `rexec` | One-shot REAPI executor | Probing a remote executor with a single command |
| `bazelcredswrapper` | Auth bridge | Reusing Bazel credential helpers with SDK tools |
| `tweag-credential-helper` | Credential helper framework | Auth for remote cache/execution endpoints and external artifacts |
| `bb-clientd` | Client-side daemon / proxy | Local caching, CAS browsing, remote-build acceleration |
| `bb-browser` | Web browser for CAS/AC | Human inspection of CAS/AC objects |
| `bb-portal` | BES / BEP web UI | Persisted, browsable Bazel invocation results |
| `recc` | Compiler wrapper client | C/C++-oriented remote cache and execution adoption |
| `bgd` internal client | Minimal REAPI client | Quick BuildGrid-side functional testing |
| `buildbox-casd` | Local CAS proxy/cache | Worker-side or local CAS acceleration |
| `rexplorer` | Action inspector | Structured Action + ActionResult inspection |
| `casdownload` / `casupload` | CAS transfer tools | Pulling or pushing trees and blobs |
| `logstreamtail` | Log stream reader | Following REAPI LogStream output |

## `bf-client`

Upstream:
- [buildfarm/bf-client](https://github.com/buildfarm/bf-client)

What it is:
- A terminal UI for **Buildfarm** operators.
- It connects to the **Buildfarm Redis backplane** and the **Buildfarm REAPI
  gRPC endpoint**.
- It is **Buildfarm-specific**; it is not a generic REAPI client for Buildbarn,
  NativeLink, or bazel-remote.

What it is good for:
- Watching queue depth and dispatched operations.
- Inspecting worker state.
- Looking at Buildfarm-side operation flow while a cluster is live.

How to use it against rek8s:

1. Port-forward the Buildfarm server service to your workstation.

```bash
kubectl port-forward -n rek8s-rbe svc/<buildfarm-server-service> 8980:8980
```

2. Port-forward the Redis service used by the Buildfarm deployment.

```bash
kubectl get svc -n rek8s-rbe
kubectl port-forward -n rek8s-rbe svc/<buildfarm-redis-service> 6379:6379
```

3. Run `bf-client` against those two endpoints.

```bash
bf-client localhost:6379 localhost:8980
```

If you connect through an ingress-terminated TLS endpoint instead of a local
port-forward, `bf-client` also accepts a `grpcs://...` REAPI address and an
optional CA PEM path:

```bash
bf-client redis.internal:6379 grpcs://rbe.build.example.com:443 /path/to/ca.pem
```

How rek8s maps to it:
- `bf-client` is mainly relevant when `rbe.buildfarm.enabled: true`.
- It pairs naturally with the Buildfarm server ingress shown in Helm
  `NOTES.txt`.

## `reclient`

Upstream:
- [bazelbuild/reclient](https://github.com/bazelbuild/reclient)

What it is:
- A **client implementation of REAPI** that integrates with an existing build
  system.
- The core pieces are `reproxy`, `rewrapper`, `bootstrap`, and
  `scandeps_server`.
- It is not itself a build system; it is an integration layer for remote
  execution and remote caching.

What it is good for:
- Wrapping non-Bazel build actions and sending them to a remote execution
  backend.
- Incrementally adopting REAPI for C/C++ style toolchains and custom build
  graphs.

How to use it against rek8s:

For a first bring-up, use a local port-forward to the RBE service instead of
starting with ingress, auth, and TLS:

```bash
kubectl port-forward -n rek8s-rbe svc/<rbe-service> 8980:8980
```

Use one of the example configs in [`examples/`](../examples/):

- [`reclient-buildfarm.cfg`](../examples/reclient-buildfarm.cfg)
- [`reclient-buildbarn.cfg`](../examples/reclient-buildbarn.cfg)

Start `reproxy` through `bootstrap`:

```bash
bootstrap -re_proxy=/path/to/reproxy -cfg=/path/to/reclient-buildfarm.cfg
```

Wrap a command through `rewrapper`:

```bash
rewrapper \
  -cfg=/path/to/reclient-buildfarm.cfg \
  -exec_root="$PWD" \
  -labels=type=tool \
  -exec_strategy=remote_local_fallback \
  -- /bin/echo hello
```

Important details for rek8s:
- Point `service=` at the **RBE endpoint**, not the BES endpoint.
- For self-hosted local testing, `service_no_auth=true` and
  `use_rpc_credentials=false` are usually the right starting point.
- `Buildbarn` often uses an instance name, so the Buildbarn example includes
  `instance=default`.
- `reclient` is an RBE tool. It is not a BuildBuddy BES client and it is not a
  Buildfarm-specific operator console like `bf-client`.

## `tools_remote` / `remote_client`

Upstream:
- [bazelbuild/tools_remote](https://github.com/bazelbuild/tools_remote)

What it is:
- A debug client for remote cache and remote execution users.
- It can download blobs by digest, list and download CAS directories, print
  gRPC logs, identify failed actions, and reconstruct an action locally.

What it is good for:
- Pulling a failed action's inputs and outputs out of CAS.
- Inspecting a `--remote_grpc_log` file from Bazel.
- Replaying a failing remote action locally in Docker.

How to use it against rek8s:

```bash
kubectl port-forward -n rek8s-cache svc/<bazel-remote-service> 9092:9092
```

Download a blob by digest:

```bash
remote_client \
  --remote_cache=127.0.0.1:9092 \
  cat \
  --digest=<sha256>/<size> \
  --file=/tmp/blob
```

List a directory tree by digest:

```bash
remote_client \
  --remote_cache=127.0.0.1:9092 \
  ls \
  --digest=<directory-digest>
```

Print a Bazel gRPC log:

```bash
remote_client --grpc_log=/tmp/remote.log printlog
```

How rek8s maps to it:
- Works naturally against `bazel-remote`, `BuildBuddy`, `Buildfarm`, or
  `Buildbarn` cache/CAS endpoints.
- Best suited for post-failure inspection and cache debugging.

## `remotetool`

Upstream:
- [bazelbuild/remote-apis-sdks](https://github.com/bazelbuild/remote-apis-sdks)

What it is:
- A CLI from the Remote API SDKs repository for common REAPI debugging
  operations.
- Upstream describes it as supporting file and directory upload/download,
  displaying action details, downloading action results, and re-executing
  actions.

What it is good for:
- Inspecting a single action without a full build-system integration.
- Downloading a remote action result to a local directory.
- Re-running a remote action for debugging.

Example shape:

```bash
remotetool \
  --operation=download_action_result \
  --service=127.0.0.1:8980 \
  --instance=default \
  --digest=<sha256>/<size> \
  --path=/tmp/action-out
```

How rek8s maps to it:
- A strong fit for Buildfarm, Buildbarn, and other REAPI executors exposed by
  rek8s.
- More execution-oriented than `remote_client`, which is especially handy for
  cache and gRPC-log debugging.

## `rexec`

Upstream:
- [bazelbuild/remote-apis-sdks](https://github.com/bazelbuild/remote-apis-sdks)

What it is:
- A one-shot command runner for remote execution.
- Upstream describes it as executing a command remotely, then downloading the
  outputs and propagating `stdout` and `stderr`.

What it is good for:
- Smoke-testing a newly deployed executor.
- Validating platform properties, instance names, and auth/TLS settings
  without involving Bazel or another build system.
- Reproducing “can this backend execute this command at all?” issues quickly.

Example shape:

```bash
rexec \
  --service=127.0.0.1:8980 \
  --instance=default \
  --exec_root="$PWD" \
  --inputs=README.md \
  --output_files=out.txt \
  -- /bin/sh -c 'cat README.md > out.txt'
```

How rek8s maps to it:
- This is one of the cleanest ways to validate the RBE side of a rek8s
  deployment before layering on Bazel, Reninja, or `reclient`.

## `bazelcredswrapper`

Upstream:
- [bazelbuild/remote-apis-sdks](https://github.com/bazelbuild/remote-apis-sdks)

What it is:
- A small bridge binary that lets Remote API SDK tools authenticate using a
  Bazel-style credentials helper.
- Upstream states it is used to authenticate the SDK tools with Bazel-style
  credentials helpers.

What it is good for:
- Reusing an existing Bazel credential-helper setup with `rexec` or
  `remotetool`.
- Avoiding duplicate auth configuration between Bazel and SDK-side debug tools.

How rek8s maps to it:
- Useful when a rek8s deployment is fronted by TLS and auth and you want the
  SDK tools to follow the same helper path as Bazel.

## `tweag-credential-helper`

Upstream:
- [tweag/credential-helper](https://github.com/tweag/credential-helper)

What it is:
- A credential-helper framework and agent for Bazel and related tooling.
- It supports multiple providers, including “Remote Execution & Remote Caching
  Services”, and can be configured for host patterns such as a private
  `bazel-remote` instance.

What it is good for:
- Standardizing auth for remote cache/execution endpoints.
- Separating credential logic from `.bazelrc` and workspace dependency config.
- Covering both REAPI endpoints and artifact download hosts with one helper
  stack.

How rek8s maps to it:
- Worth knowing when a rek8s deployment is not anonymous and clients need a
  real credential-helper story.
- Especially relevant for organizations that also secure artifact downloads,
  not just the REAPI endpoint itself.

## `bb-clientd`

Upstream:
- [buildbarn/bb-clientd](https://github.com/buildbarn/bb-clientd)

What it is:
- A client-side daemon that proxies REAPI traffic, adds local caching, and
  exposes CAS data through a FUSE/NFS-mounted filesystem.
- Developed in the Buildbarn ecosystem, but designed to work with other REAPI
  implementations too.

What it is good for:
- Speeding up builds through local request/result caching.
- Browsing CAS contents without writing one-off scripts.
- Supporting “remote builds without the bytes” workflows with local access to
  lazily-fetched data.

How to use it against rek8s:
- Run `bb-clientd` on your workstation, not in-cluster.
- Point it at the deployed RBE endpoint and route per-instance traffic through
  its local Unix socket.

Conceptually:

```bash
bazel build \
  --remote_executor="unix://${XDG_CACHE_HOME:-$HOME/.cache}/bb_clientd/grpc" \
  --remote_instance_name=rbe.build.example.com/default \
  //...
```

How rek8s maps to it:
- Most useful for Buildbarn users, but it is not limited to Buildbarn-only
  backends.
- Especially interesting when local cache amplification and CAS exploration are
  more important than a simple one-shot CLI.

## `bb-browser`

Upstream:
- [buildbarn/bb-browser](https://github.com/buildbarn/bb-browser)

What it is:
- A web UI for browsing CAS and AC objects.
- Primarily aimed at Buildbarn, but conceptually useful anywhere digests and
  ActionResults need human inspection.

What it is good for:
- Inspecting failed action data.
- Navigating directories and blobs in CAS.
- Making digest-oriented debugging less painful.

How rek8s maps to it:
- rek8s already exposes the Buildbarn browser when `rbe.buildbarn.browser` is
  enabled.
- This is the main browser-style inspection surface in the current chart.

## `bb-portal`

Upstream:
- [buildbarn/bb-portal](https://github.com/buildbarn/bb-portal)

What it is:
- A web service for browsing Bazel build results.
- Upstream says it consumes Build Event Protocol data either from local files
  or streamed through the Build Event Service protocol, and persists analyzed
  invocation results for later browsing and search.

What it is good for:
- Browsable BEP/BES results outside of the BuildBuddy UI model.
- Grouping Bazel invocations into higher-level builds.
- Persisted lookup of prior invocation failures and summaries.

How rek8s maps to it:
- Not charted today, but important as a BES-adjacent alternative in the wider
  ecosystem.
- Relevant if rek8s ever grows beyond “BuildBuddy OSS as the BES provider”.

## `recc`

Upstream:
- [BuildGrid `recc`](https://buildgrid.gitlab.io/recc/)

What it is:
- The Remote Execution Caching Compiler.
- Upstream describes it as a compiler command launcher that uses REAPI for
  caching and remote execution of compilation and link actions.

What it is good for:
- Incremental adoption of REAPI for C and C++ toolchains.
- Wrapping compiler commands directly, with a simpler mental model than a full
  build-system integration in some environments.
- Environments where `reclient` is not the preferred fit.

How to use it against rek8s:
- Configure `RECC_SERVER` to point at the remote execution server.
- Set `RECC_CAS_SERVER` if the CAS endpoint differs.
- Set `RECC_INSTANCE` if the backend expects a non-empty instance name.

Conceptually:

```bash
export RECC_SERVER=127.0.0.1:8980
export RECC_INSTANCE=default
recc /usr/bin/gcc -c hello.c -o hello.o
```

How rek8s maps to it:
- Another real REAPI client worth documenting beside Bazel, Buck2, Reninja,
  and `reclient`.
- Especially relevant when users want compiler-wrapper adoption instead of a
  build-graph-native integration.

## `bgd` internal client

Upstream:
- [BuildGrid internal client docs](https://buildgrid.gitlab.io/buildgrid/user/using_internal.html)

What it is:
- A minimal remote execution client exposed through the `bgd` CLI.
- Upstream describes it as an internal client that can be used to exercise a
  BuildGrid deployment without bringing in a separate build system.

What it is good for:
- Functional testing of a BuildGrid endpoint.
- Local demos and bring-up flows.
- Understanding the BuildGrid execution model with fewer moving parts.

How rek8s maps to it:
- Not directly relevant to the currently charted providers, but worth knowing
  if rek8s ever adds BuildGrid.
- Another example of the ecosystem having small “probe” clients that operators
  often miss.

## `buildbox-casd`

Upstream:
- [BuildBox docs](https://buildgrid.gitlab.io/buildbox/buildbox/)

What it is:
- A local CAS daemon and proxy used in the BuildBox ecosystem.
- Upstream describes it as a local cache in front of remote CAS, improving
  worker performance by avoiding repeated remote blob fetches.

What it is good for:
- Worker-side CAS acceleration.
- Shared local blob caching on machines that run remote-worker processes.
- Exploring a richer “local CAS in front of remote CAS” deployment model.

How rek8s maps to it:
- Not a direct rek8s chart component today, but important for understanding the
  BuildGrid/BuildBox worker model.
- Useful context if rek8s ever adds BuildGrid or worker-side cache patterns.

## `rexplorer`

Upstream:
- [BuildBox `rexplorer`](https://gitlab.com/BuildGrid/buildbox/buildbox)

What it is:
- A CLI that fetches an Action and its ActionResult and prints them as JSON or
  pretty text.

What it is good for:
- Structured inspection of a single action digest.
- Piping Action/ActionResult metadata into `jq`.
- Looking at inputs, platform properties, outputs, and execution metadata.

Example shape:

```bash
rexplorer \
  --remote=https://rbe.build.example.com:443 \
  --instance=default \
  --action=<sha256>/<size> \
  --pretty
```

How rek8s maps to it:
- Most useful once you already have an action digest from logs, BES, or worker
  output.
- Good fit for BuildGrid/BuildBox ecosystems, but the workflow is relevant
  across REAPI deployments.

## `casdownload` and `casupload`

Upstream:
- [BuildBox `casdownload` / `casupload`](https://gitlab.com/BuildGrid/buildbox/buildbox)

What they are:
- CLI tools for pulling trees/blobs out of CAS or uploading trees/blobs into
  CAS.

What they are good for:
- Reconstructing build inputs locally.
- Exporting or importing test fixtures.
- Debugging cache contents without writing a custom client.

Examples:

```bash
casdownload \
  --remote=http://127.0.0.1:9092 \
  --instance=default \
  --destination-dir=/tmp/out \
  --action-digest=<sha256>/<size>
```

```bash
casupload \
  --remote=http://127.0.0.1:9092 \
  --instance=default \
  path/to/file path/to/dir
```

How rek8s maps to it:
- These are particularly useful against cache-oriented deployments such as
  `bazel-remote`.
- They are also a good complement to `remote_client` when you want an explicit
  “move data in/out of CAS” workflow.

## `logstreamtail`

Upstream:
- [BuildBox `logstreamtail`](https://gitlab.com/BuildGrid/buildbox/buildbox)

What it is:
- A CLI that reads LogStream API data and prints it to `stdout`.

What it is good for:
- Following remote log output when a backend exposes LogStream resources.
- Building simple tail-like debugging workflows around remote jobs.

How rek8s maps to it:
- rek8s does not expose a dedicated LogStream-specific integration today.
- This is still worth knowing about when evaluating richer execution backends
  and worker ecosystems.

## `bazel-remote`

Upstream:
- [buchgr/bazel-remote](https://github.com/buchgr/bazel-remote)

What it is:
- A **cache-only** remote cache server.
- It exposes HTTP and gRPC cache services for REAPI clients.
- It does **not** provide remote execution and it does **not** provide a BES UI.

How to use it with rek8s:
- Enable `cache.bazelRemote.enabled: true`.
- Point `--remote_cache` at the cache gRPC ingress hostname.
- Optionally combine it with `BuildBuddy OSS` for BES / invocation UX.

Example Bazel config:
- [`bazelrc-bazel-remote.bazelrc`](../examples/bazelrc-bazel-remote.bazelrc)

Important distinction:
- `bazel-remote` is a strong fit for **cache-only** use cases.
- `reclient` and `bf-client` are oriented around **remote execution** workflows.

## Current Ecosystem Gaps

This section is an inference based on the tooling above and the broader REAPI
ecosystem as it exists today.

What seems to be missing:
- A **generic operator console** for REAPI backends. `bf-client` is useful, but
  it is Buildfarm-specific. There is still no widely-adopted cross-backend CLI
  that can inspect queue state, workers, leases, and operations across
  Buildfarm, Buildbarn, NativeLink, BuildGrid, and commercial services through
  a common interface.
- A **generic web debugger** for REAPI objects. `bb-browser` is valuable, but it
  is tied to the Buildbarn ecosystem. A neutral browser for CAS, AC,
  `Operations`, `ActionResult`, and ByteStream data across arbitrary backends
  would fill a real gap.
- A **turnkey client bootstrap tool**. Users still piece together endpoint URLs,
  instance names, TLS roots, auth helpers, and per-client flags by hand for
  Bazel, Buck2, Reninja, Pants, Please, and `reclient`. A tool that emitted
  known-good client configs from a deployed cluster would remove a lot of
  friction.
- A **protocol probe / smoke-test binary**. There are useful debug tools, but
  there is still no standard “doctor” command that validates `Capabilities`,
  CAS upload/download, AC lookup, execution, ByteStream, LogStream, and Remote
  Asset support in one pass against a target endpoint.
- A **cross-backend replay tool** for failed actions. Today the ecosystem has
  pieces like `remote_client`, `rexplorer`, `casdownload`, and `casupload`, but
  not one dominant workflow that can pull an action from backend A, replay it
  locally or remotely, and then compare outputs against backend B.
- A **cache migration and mirroring utility**. Cache-only and RBE deployments
  often need to seed, mirror, or evacuate CAS and AC data, yet the ecosystem
  still leans on lower-level blob tools instead of a purpose-built migration
  workflow.
- A **shared conformance and interoperability harness** for real client/backend
  combinations. The protocol exists, but operators still lack an easy way to
  answer questions like “does this exact `reclient` setup work against this
  exact Buildbarn or NativeLink deployment with these features enabled?”

What would be especially useful for rek8s users:
- A `rek8s doctor`-style tool that can verify the deployed endpoints and emit
  ready-to-use config fragments for Bazel, Reninja, and `reclient`.
- A small REAPI browser that works across providers, not just within one
  backend family.
- A repeatable cache/RBE interoperability test suite that the chart can run in
  CI against multiple client/provider combinations.

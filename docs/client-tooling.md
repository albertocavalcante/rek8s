# Client And Operator Tooling

This page covers tools that interact with a deployed rek8s cluster without
being charted providers themselves.

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

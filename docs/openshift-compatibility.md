# OpenShift Compatibility

This document records the current state of `rek8s` on managed OpenShift
variants such as:

- ROSA
- ARO
- OSD and other OpenShift-managed offerings

As of March 22, 2026, `rek8s` does not ship a supported OpenShift profile yet.
This is a compatibility guide and gap analysis, not a promise that the current
chart works unchanged on every OpenShift cluster.

## What OpenShift Changes

OpenShift differs from the cloud and distribution profiles already in `rek8s`
in two important ways:

- north-south traffic is Route-centric, even though standard Kubernetes
  `Ingress` objects can generate managed Routes
- workload admission is controlled by Security Context Constraints, with
  `restricted-v2` as the default on new installs

## Ingress and Route Reality

OpenShift documents Routes as the first-class ingress surface. Route TLS modes
include:

- edge
- reencrypt
- passthrough

OpenShift also documents automatic Route generation from `Ingress` objects.
Important details:

- If an `Ingress` is created without TLS, OpenShift generates an insecure
  Route.
- If an `Ingress` has an empty TLS section, OpenShift can generate an
  edge-terminated Route using the default ingress certificate.
- OpenShift documents the
  `route.openshift.io/destination-ca-certificate-secret` annotation for
  generating a reencrypt Route from an `Ingress`.

What this means for `rek8s`:

- The current `nginx` provider emits standard Kubernetes `Ingress` resources,
  not `Route` resources.
- The current `gateway-api` provider emits `HTTPRoute` and `GRPCRoute`
  resources, not OpenShift `Route` resources.
- `rek8s` does not currently model Route TLS termination choices directly.

Practical inference:

- The most plausible first OpenShift path is not a brand new profile yet.
- It is either:
  - validating generated Routes from the existing `Ingress` path, especially
    for BuildBuddy and gRPC endpoints
  - or adding native `Route` support as a new ingress provider once the TLS and
    gRPC story is tested end to end

## SCC Reality

OpenShift 4.11 and later new installs default authenticated users to
`restricted-v2`. Red Hat documents that `restricted-v2`:

- drops all capabilities by default
- only allows `NET_BIND_SERVICE` to be added explicitly
- requires `allowPrivilegeEscalation` to be unset or `false`
- applies `runtime/default` seccomp by default

What this means for `rek8s`:

- The umbrella chart does not currently add OpenShift-specific SCC resources.
- The umbrella chart does not currently generate OpenShift-specific pod
  security overrides.
- Subcharts and their container images still need explicit admission testing on
  `restricted-v2`.

Practical inference:

- Until that validation is done, any OpenShift deployment should be treated as
  experimental.
- The first compatibility pass should test the deployed workloads under the
  default SCC before considering `anyuid` or custom SCC exceptions.

## Current Recommendation

For OpenShift users today:

1. Treat `rek8s` as an evaluation target, not a supported OpenShift profile.
2. Prefer validating one ingress path first:
   either generated Routes from `Ingress`, or a future native Route provider.
3. Test admission under default `restricted-v2` before granting broader SCCs.
4. Keep storage, ingress, and SCC exceptions explicit and minimal.

## Recommended Next Work

The next real OpenShift support step should be:

1. render `rek8s` on a current OpenShift cluster
2. record which workloads fail `restricted-v2`
3. verify whether OpenShift-generated Routes preserve the required gRPC/TLS
   behavior for BuildBuddy and Buildfarm
4. only then decide whether `rek8s` needs:
   - a native `route` ingress provider
   - OpenShift-specific security values
   - or both

## Sources

- OpenShift Routes: <https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/ingress_and_load_balancing/routes>
- OpenShift route TLS modes: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/pdf/ingress_and_load_balancing/configuring-routes>
- OpenShift Ingress to Route behavior: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/pdf/ingress_and_load_balancing/configuring-routes>
- OpenShift SCCs: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html-single/authentication_and_authorization/index>
- OpenShift default `restricted-v2`: <https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/pdf/migrating_from_version_3_to_4/OpenShift_Container_Platform-4.18-Migrating_from_version_3_to_4-en-US.pdf>

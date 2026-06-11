# Quenchworks common

The shared Helm **library chart** (`quench-common`) for the Quenchworks catalog:
common labels, hardened pod/container security contexts, and the digest-only image
resolver that every app chart builds on.

It is published as an OCI artifact and consumed by the app charts in
[`quenchworks/charts`](https://github.com/quenchworks/charts).

## Published location

```
oci://ghcr.io/quenchworks/charts/quench-common
```

App charts depend on it like this:

```yaml
# Chart.yaml
dependencies:
  - name: quench-common
    version: 0.0.0
    repository: oci://ghcr.io/quenchworks/charts
```

## What it provides

- `quench-common.fullname` / `name` / `labels` / `selectorLabels`
- `quench-common.image` — resolves an image strictly by `repository@sha256:digest`
  (a tag-only reference is refused on purpose)
- `quench-common.podSecurityContext` — `runAsNonRoot`, uid/gid/fsGroup 1001, seccomp RuntimeDefault
- `quench-common.containerSecurityContext` — read-only rootfs, no privilege escalation, drop ALL caps

## Release

Pushing to `main` runs `.github/workflows/release-common.yml`: lint, package, push the
OCI chart to GHCR, and cosign-sign it (keyless). It is a `type: library` chart, so there
is nothing to install directly.

## License

MIT.

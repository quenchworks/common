# Quenchworks common

The shared Helm **library chart** (`quench-common`) for the
[Quenchworks](https://github.com/quenchworks) catalog: common labels, hardened pod/container
security contexts, and the digest-only image resolver that every app chart builds on. It is the one
place the catalog's security baseline is defined, so all 28 charts inherit it identically.

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
    version: 0.0.1
    repository: oci://ghcr.io/quenchworks/charts
```

## What it provides

- `quench-common.fullname` / `name` / `labels` / `selectorLabels`
- `quench-common.image` — resolves an image strictly by `repository@sha256:digest`
  (a tag-only reference is refused on purpose, so a chart can never ship an unpinned image)
- `quench-common.podSecurityContext` — `runAsNonRoot`, uid/gid/fsGroup 1001, seccomp RuntimeDefault
- `quench-common.containerSecurityContext` — read-only rootfs, no privilege escalation, drop ALL caps
- shared knob surface used across charts: scheduling, probes, extra env/volumes/volumeMounts,
  init containers, sidecars, lifecycle hooks, and security-context overrides

## Versioning

Patch-bump the chart `version` on every change and never overwrite a published version; app charts
then move to the new version on their next release. (Library-chart semantics: there is nothing to
install directly.)

## Release

Pushing to `main` runs `.github/workflows/release-common.yml`: lint, package, push the
OCI chart to GHCR, and cosign-sign it (keyless).

## License

MIT.

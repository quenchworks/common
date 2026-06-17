# quench-common

The shared Helm **library chart** behind the [QuenchWorks](https://github.com/quenchworks) catalog. It's the one place the security baseline is defined, so all 54 app charts inherit the exact same hardening: identical labels, identical pod and container security contexts, and a digest-only image resolver that makes shipping an unpinned image impossible.

<p align="center">
  <a href="https://quench-works.com"><img src="https://raw.githubusercontent.com/quenchworks/.github/main/profile/assets/demo.gif" alt="QuenchWorks in a terminal: run a 0-CVE image, verify it with cosign, deploy the Helm chart, and watch the pod reach Running." width="760"></a>
</p>

Harden it once here, and every chart in the catalog moves together.

Published as an OCI artifact and consumed by the charts in [quenchworks/charts](https://github.com/quenchworks/charts):

```
oci://ghcr.io/quenchworks/charts/quench-common
```

## How charts depend on it

```yaml
# Chart.yaml
dependencies:
  - name: quench-common
    version: 0.0.1
    repository: oci://ghcr.io/quenchworks/charts
```

## What it provides

- **Naming and labels**: `quench-common.fullname` / `name` / `labels` / `selectorLabels`, consistent across the whole catalog.
- **The digest-only image resolver**: `quench-common.image` resolves an image strictly by `repository@sha256:digest`. A tag-only reference is refused on purpose, so a chart can never ship an unpinned image.
- **Hardened pod security context**: `quench-common.podSecurityContext` sets `runAsNonRoot`, uid/gid/fsGroup 1001, seccomp `RuntimeDefault`.
- **Hardened container security context**: `quench-common.containerSecurityContext` sets a read-only root filesystem, no privilege escalation, drop ALL capabilities.
- **A shared knob surface**: the override points every chart exposes the same way, including scheduling, probes, extra env/volumes/volumeMounts, init containers, sidecars, lifecycle hooks, and security-context overrides.

## Versioning

Patch-bump the chart `version` on every change, and never overwrite a published version. App charts then move to the new version on their next release. This is a library chart, so there's nothing to `helm install` directly.

## Release

Pushing to `main` runs `.github/workflows/release-common.yml`: lint, package, push the OCI chart to GHCR, and cosign-sign it (keyless).

## License

MIT.

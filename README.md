# quench-common

**English** · [العربية](README.ar.md) · [Español](README.es.md)

The shared Helm **library chart** behind the [QuenchWorks](https://github.com/quenchworks) catalog. It's the one place the security baseline is defined, so every app chart inherits the exact same hardening: identical labels, identical pod and container security contexts, and a digest-only image resolver that makes shipping an unpinned image impossible.

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
    version: 0.0.6
    repository: oci://ghcr.io/quenchworks/charts
```

## What it provides

- **Naming and labels**: `quench-common.fullname` / `name` / `labels` / `selectorLabels`, consistent across the whole catalog.
- **The digest-only image resolver**: `quench-common.image` resolves an image strictly by `repository@sha256:digest`. A tag-only reference is refused on purpose, so a chart can never ship an unpinned image.
- **Hardened pod security context**: `quench-common.podSecurityContext` sets `runAsNonRoot`, uid/gid/fsGroup 1001, seccomp `RuntimeDefault`.
- **Hardened container security context**: `quench-common.containerSecurityContext` sets a read-only root filesystem, no privilege escalation, drop ALL capabilities.
- **A shared knob surface**: the override points every chart exposes the same way, including scheduling, probes, extra env/volumes/volumeMounts, init containers, sidecars, lifecycle hooks, and security-context overrides.

### Shared objects (0.0.3+)

Five families of manifest that were near-identical in every chart now render from here. A chart adopts one with a single line, e.g. `templates/rbac.yaml` containing `{{- include "quench-common.rbac" . }}`.

| helper | renders | opt-in via |
| --- | --- | --- |
| `quench-common.ingress` | `Ingress` | `ingress.enabled` (**default false**) |
| `quench-common.serviceAccount` | `ServiceAccount` | `serviceAccount.create` |
| `quench-common.rbac` | `Role` + `RoleBinding`, optionally `ClusterRole` + `ClusterRoleBinding` | `rbac.create` |
| `quench-common.pdb` | `PodDisruptionBudget` | `podDisruptionBudget.enabled` |
| `quench-common.hpa` | `HorizontalPodAutoscaler` | `autoscaling.enabled` |
| `quench-common.networkPolicy` | `NetworkPolicy` | `networkPolicy.enabled` |

Which manifests moved here was decided by measuring the catalog, not by taste. Grouping all 138 charts by rendered shape: `serviceaccount.yaml` 117/132 identical, `poddisruptionbudget.yaml` 105/123, `rbac.yaml` 104/123, `hpa.yaml` 20/23. `networkpolicy.yaml` produced 91 distinct shapes because every app allows different ports, so its helper takes them from values instead of fixing them. `service.yaml` produced 98 distinct shapes from 128 charts and deliberately stays per-chart: the port list is the application's identity, so a helper would need as much configuration as the manifest it replaced.

Every helper is built to be overridden rather than fought:

- `extraLabels` and `annotations` on each object.
- **Ingress**: multi-host, per-host `paths` (a host with no `paths` gets one `/` `Prefix`), `pathType`, TLS list, and `className` omitted entirely when unset so the cluster default applies. The backend port resolves from `ingress.servicePort`, then `service.port`, then `service.ports.http` / `.https`, covering both service shapes in the catalog. It refuses to render an Ingress with no rules, and refuses to guess a port it cannot resolve.
- **RBAC**: `rbac.rules` (default **empty**, so nothing is granted implicitly), plus `rbac.clusterScoped` with `rbac.clusterRules`. The `ClusterRoleBinding` name carries the namespace, because cluster-scoped names are global and two releases in different namespaces would otherwise fight over one object.
- **PDB**: `minAvailable` *or* `maxUnavailable`, `unhealthyPodEvictionPolicy`, or a wholesale `spec` override.
- **HPA**: `targetKind` / `targetName` (so a StatefulSet chart can scale itself), `behavior`, CPU and/or memory targets, or a fully custom `metrics` list.
- **NetworkPolicy**: `ingressPorts`, `extraFrom` peers (namespace selector, ipBlock), wholesale `ingress` / `egress` rule lists, and `denyAllEgress`.

Ingress is only adopted by charts that serve HTTP. An `Ingress` is an HTTP router, so it cannot front PostgreSQL, Redis, Kafka or etcd — expose those with `service.type=LoadBalancer` or the ingress controller's TCP passthrough. Shipping an `ingress.enabled` flag that silently did nothing would be worse than not having one.

### Layout

One concern per file, so a chart author can read one thing at a time:

| file | provides |
| --- | --- |
| `_names.tpl` | `name`, `fullname` (`nameOverride`, `fullnameOverride`) |
| `_labels.tpl` | `labels`, `podTemplateLabels`, `commonAnnotations` |
| `_selector-labels.tpl` | `selectorLabels`, `selectorLabelsBase` — **read it before adding any** |
| `_image.tpl` | `image` (digest-only), `imagePullSecrets` |
| `_security.tpl` | `podSecurityContext`, `containerSecurityContext` |
| `_pod.tpl` | pod-spec knobs: `podSpecFields`, `probe`, env, volumes, init containers, sidecars, lifecycle hooks, command, args |
| `_serviceaccount.tpl` | `serviceAccountName`, `serviceAccount` |
| `_rbac.tpl` | `rbac` |
| `_pdb.tpl` | `pdb` |
| `_hpa.tpl` | `hpa` |
| `_networkpolicy.tpl` | `networkPolicy` |
| `_ingress.tpl` | `ingress` |

`_helpers.tpl` now defines nothing; it is the index of the files above.

### Label and naming knobs

| value | applies to | safe to change later? |
| --- | --- | --- |
| `nameOverride` / `fullnameOverride` | object names | no (renames objects) |
| `partOf` | `app.kubernetes.io/part-of` on every object | yes |
| `commonLabels` | every object's metadata | **yes** |
| `commonAnnotations` | every object's metadata | **yes** |
| `podLabels` | the pod template only | **yes** |
| `selectorLabels` | the workload selector **and** pod template | **NO — immutable** |

`spec.selector` is immutable on Deployment, StatefulSet, DaemonSet and Job. Adding a selector label to a release that already exists makes every later `helm upgrade` fail with `field is immutable`, and the only way out is deleting and recreating the workload. So use `commonLabels` or `podLabels` for anything you just want to query on, and reach for `selectorLabels` only when a label must genuinely participate in pod selection — set before the first install. `selectorLabelsBase` gives the two standard selector labels without the additions, for templates that must keep matching a workload created before any were added.

`partOf` exists because an application can *require* a particular value: Argo CD's settings manager only sees ConfigMaps and Secrets labelled `app.kubernetes.io/part-of=argocd`, so with the catalog default its own configuration is invisible and every component dies on `configmap "argocd-cm" not found`.

`image.registry` is optional and only prepended when set, so an air-gapped mirror can be pointed at without rewriting every `repository`. `imagePullSecrets` accepts plain strings or `{name: ...}` maps.

## Versioning

Patch-bump the chart `version` on every change, and never overwrite a published version. App charts then move to the new version on their next release. This is a library chart, so there's nothing to `helm install` directly.

## Release

Pushing to `main` runs `.github/workflows/release-common.yml`: lint, package, push the OCI chart to GHCR, and cosign-sign it (keyless).

## License

MIT.

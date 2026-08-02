# quench-common

[English](README.md) · **العربية** · [Español](README.es.md)

مخطط **مكتبة Helm** المشترك الذي يقف خلف كتالوج [QuenchWorks](https://github.com/quenchworks). إنه المكان الوحيد الذي يُعرَّف فيه الأساس الأمني، لذا ترث جميع مخططات التطبيقات التحصين نفسه تمامًا: تسميات متطابقة، وسياقات أمان متطابقة للحاوية والـ pod، ومُحلِّل صور قائم على البصمة (digest) فقط يجعل شحن صورة غير مثبَّتة أمرًا مستحيلًا.

<p align="center">
  <a href="https://quench-works.com"><img src="https://raw.githubusercontent.com/quenchworks/.github/main/profile/assets/demo.gif" alt="QuenchWorks داخل طرفية: شغّل صورة بصفر ثغرات (0-CVE)، وتحقق منها باستخدام cosign، وانشر مخطط Helm، وراقب الـ pod وهو يصل إلى حالة Running." width="760"></a>
</p>

حصِّنه مرة واحدة هنا، فيتحرك كل مخطط في الكتالوج معًا.

يُنشَر بوصفه أداة OCI وتستهلكه المخططات في [quenchworks/charts](https://github.com/quenchworks/charts):

```
oci://ghcr.io/quenchworks/charts/quench-common
```

## كيف تعتمد عليه المخططات

```yaml
# Chart.yaml
dependencies:
  - name: quench-common
    version: 0.0.6
    repository: oci://ghcr.io/quenchworks/charts
```

## ما الذي يوفره

- **التسمية والتسميات (labels)**: `quench-common.fullname` / `name` / `labels` / `selectorLabels`، متسقة عبر الكتالوج بأكمله.
- **مُحلِّل الصور القائم على البصمة فقط**: يحل `quench-common.image` الصورة حصريًا عبر `repository@sha256:digest`. يُرفَض المرجع القائم على الوسم (tag) فقط عن قصد، حتى لا يتمكن أي مخطط أبدًا من شحن صورة غير مثبَّتة.
- **سياق أمان مُحصَّن للـ pod**: يضبط `quench-common.podSecurityContext` كلًا من `runAsNonRoot`، وuid/gid/fsGroup 1001، وseccomp `RuntimeDefault`.
- **سياق أمان مُحصَّن للحاوية**: يضبط `quench-common.containerSecurityContext` نظام ملفات جذر للقراءة فقط، ومنع تصعيد الامتيازات، وإسقاط كل الصلاحيات (drop ALL capabilities).
- **سطح مفاتيح ضبط مشترك**: نقاط التجاوز (override points) التي يكشفها كل مخطط بالطريقة نفسها، بما في ذلك الجدولة، والفحوص (probes)، والمتغيرات/المجلدات/تركيبات المجلدات الإضافية، وحاويات التهيئة (init containers)، والحاويات الجانبية (sidecars)، وخطافات دورة الحياة (lifecycle hooks)، وتجاوزات سياق الأمان.

### الكائنات المشتركة (0.0.3 وما بعده)

خمس عائلات من الملفات (manifests) كانت شبه متطابقة في كل مخطط تُصاغ الآن من هنا. يعتمدها المخطط بسطر واحد، مثلًا `templates/rbac.yaml` يحتوي على `{{- include "quench-common.rbac" . }}`.

| المساعد | ما يُنتجه | التمكين عبر |
| --- | --- | --- |
| `quench-common.ingress` | `Ingress` | `ingress.enabled` (**افتراضيًا false**) |
| `quench-common.serviceAccount` | `ServiceAccount` | `serviceAccount.create` |
| `quench-common.rbac` | `Role` + `RoleBinding`، واختياريًا `ClusterRole` + `ClusterRoleBinding` | `rbac.create` |
| `quench-common.pdb` | `PodDisruptionBudget` | `podDisruptionBudget.enabled` |
| `quench-common.hpa` | `HorizontalPodAutoscaler` | `autoscaling.enabled` |
| `quench-common.networkPolicy` | `NetworkPolicy` | `networkPolicy.enabled` |

تحديد ما انتقل إلى هنا جاء بقياس الكتالوج، لا بالتفضيل. بتجميع المخططات الـ138 حسب الشكل الناتج: `serviceaccount.yaml` متطابق في 117 من 132، و`poddisruptionbudget.yaml` في 105 من 123، و`rbac.yaml` في 104 من 123، و`hpa.yaml` في 20 من 23. أما `networkpolicy.yaml` فأنتج 91 شكلًا مختلفًا لأن كل تطبيق يسمح بمنافذ مختلفة، لذلك يأخذ مساعده المنافذ من القيم بدل تثبيتها. و`service.yaml` أنتج 98 شكلًا مختلفًا من 128 مخططًا ويبقى عن قصد داخل كل مخطط: قائمة المنافذ هي هوية التطبيق، فأي مساعد سيحتاج إعدادات بحجم الملف الذي يستبدله.

كل مساعد مبني ليُجاوَز لا ليُقاوَم:

- `extraLabels` و`annotations` على كل كائن.
- **Ingress**: مضيفات متعددة، و`paths` لكل مضيف (المضيف بلا `paths` يحصل على `/` واحد بنوع `Prefix`)، و`pathType`، وقائمة TLS، و`className` يُحذف كليًا عند عدم تعيينه ليُطبَّق افتراضي العنقود. يُحلّ منفذ الخدمة من `ingress.servicePort` ثم `service.port` ثم `service.ports.http` / `.https`، وهذا يغطي شكلَي الخدمة في الكتالوج. ويرفض إنتاج Ingress بلا قواعد، ويرفض تخمين منفذ لا يستطيع تحديده.
- **RBAC**: `rbac.rules` (افتراضيًا **فارغة**، فلا تُمنح أي صلاحية ضمنًا)، مع `rbac.clusterScoped` و`rbac.clusterRules`. اسم `ClusterRoleBinding` يحمل اسم مساحة الأسماء، لأن الأسماء على مستوى العنقود عالمية وإصداران في مساحتين مختلفتين سيتنازعان على كائن واحد.
- **PDB**: `minAvailable` *أو* `maxUnavailable`، و`unhealthyPodEvictionPolicy`، أو تجاوز `spec` بالكامل.
- **HPA**: `targetKind` / `targetName` (ليتمكن مخطط StatefulSet من تحجيم نفسه)، و`behavior`، وأهداف المعالج و/أو الذاكرة، أو قائمة `metrics` مخصصة بالكامل.
- **NetworkPolicy**: `ingressPorts`، ونظائر `extraFrom` (محدد مساحة أسماء، ipBlock)، وقوائم قواعد `ingress` / `egress` كاملة، و`denyAllEgress`.

لا يعتمد Ingress إلا في المخططات التي تخدم HTTP. فـ `Ingress` موجِّه HTTP، ولا يمكنه أن يتقدم PostgreSQL أو Redis أو Kafka أو etcd — تُعرَض هذه عبر `service.type=LoadBalancer` أو تمرير TCP في وحدة تحكم الـ ingress. وشحن مفتاح `ingress.enabled` لا يفعل شيئًا بصمت أسوأ من عدم وجوده.

### التقسيم

مفهوم واحد لكل ملف، ليقرأ مؤلف المخطط شيئًا واحدًا في كل مرة:

| الملف | ما يوفره |
| --- | --- |
| `_names.tpl` | `name`، `fullname` (`nameOverride`، `fullnameOverride`) |
| `_labels.tpl` | `labels`، `podTemplateLabels`، `commonAnnotations` |
| `_selector-labels.tpl` | `selectorLabels`، `selectorLabelsBase` — **اقرأه قبل إضافة أي منها** |
| `_image.tpl` | `image` (بالبصمة فقط)، `imagePullSecrets` |
| `_security.tpl` | `podSecurityContext`، `containerSecurityContext` |
| `_pod.tpl` | مفاتيح مواصفة الـ pod: `podSpecFields`، `probe`، البيئة، المجلدات، حاويات التهيئة، الحاويات الجانبية، خطافات دورة الحياة، command، args |
| `_serviceaccount.tpl` | `serviceAccountName`، `serviceAccount` |
| `_rbac.tpl` | `rbac` |
| `_pdb.tpl` | `pdb` |
| `_hpa.tpl` | `hpa` |
| `_networkpolicy.tpl` | `networkPolicy` |
| `_ingress.tpl` | `ingress` |

لم يعد `_helpers.tpl` يعرّف شيئًا؛ صار فهرسًا للملفات أعلاه.

### مفاتيح التسميات والأسماء

| القيمة | تُطبَّق على | آمنة للتغيير لاحقًا؟ |
| --- | --- | --- |
| `nameOverride` / `fullnameOverride` | أسماء الكائنات | لا (تعيد تسمية الكائنات) |
| `partOf` | `app.kubernetes.io/part-of` على كل كائن | نعم |
| `commonLabels` | بيانات وصف كل كائن | **نعم** |
| `commonAnnotations` | بيانات وصف كل كائن | **نعم** |
| `podLabels` | قالب الـ pod فقط | **نعم** |
| `selectorLabels` | مُحدِّد الحمل **و** قالب الـ pod | **لا — غير قابل للتغيير** |

الحقل `spec.selector` غير قابل للتغيير في Deployment وStatefulSet وDaemonSet وJob. إضافة تسمية مُحدِّد إلى إصدار قائم تجعل كل `helm upgrade` لاحق يفشل برسالة `field is immutable`، والمخرج الوحيد هو حذف الحمل وإعادة إنشائه. لذلك استخدم `commonLabels` أو `podLabels` لأي تسمية تريد الاستعلام بها فقط، ولا تلجأ إلى `selectorLabels` إلا إذا كان على التسمية أن تشارك فعلًا في اختيار الـ pods — وتُضبط قبل أول تثبيت. ويمنحك `selectorLabelsBase` التسميتين المعياريتين دون الإضافات، للقوالب التي يجب أن تبقى مطابقة لحمل أُنشئ قبل إضافة أي منها.

يوجد `partOf` لأن التطبيق قد *يشترط* قيمة معينة: فمدير إعدادات Argo CD لا يرى إلا ConfigMaps وSecrets الموسومة بـ `app.kubernetes.io/part-of=argocd`، وبالقيمة الافتراضية للكتالوج تصبح إعداداته غير مرئية ويموت كل مكوّن برسالة `configmap "argocd-cm" not found`.

و`image.registry` اختياري ولا يُضاف إلا عند تعيينه، ليتيح توجيه مرآة معزولة عن الشبكة دون إعادة كتابة كل `repository`. ويقبل `imagePullSecrets` نصوصًا مباشرة أو خرائط `{name: ...}`.

## الإصدارات

ارفع رقم التصحيح (patch) في `version` الخاص بالمخطط مع كل تغيير، ولا تستبدل أبدًا إصدارًا منشورًا. تنتقل عندئذٍ مخططات التطبيقات إلى الإصدار الجديد في إصدارها التالي. هذا مخطط مكتبة، لذا لا يوجد ما يمكن تنفيذ `helm install` عليه مباشرة.

## الإصدار

يؤدي الدفع إلى `main` إلى تشغيل `.github/workflows/release-common.yml`: الفحص (lint)، والتحزيم، ودفع مخطط OCI إلى GHCR، وتوقيعه بـ cosign (بدون مفاتيح / keyless).

## الترخيص

MIT.

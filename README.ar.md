# quench-common

[English](README.md) · **العربية** · [Español](README.es.md)

مخطط **مكتبة Helm** المشترك الذي يقف خلف كتالوج [QuenchWorks](https://github.com/quenchworks). إنه المكان الوحيد الذي يُعرَّف فيه الأساس الأمني، لذا ترث جميع مخططات التطبيقات الـ 54 التحصين نفسه تمامًا: تسميات متطابقة، وسياقات أمان متطابقة للحاوية والـ pod، ومُحلِّل صور قائم على البصمة (digest) فقط يجعل شحن صورة غير مثبَّتة أمرًا مستحيلًا.

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
    version: 0.0.1
    repository: oci://ghcr.io/quenchworks/charts
```

## ما الذي يوفره

- **التسمية والتسميات (labels)**: `quench-common.fullname` / `name` / `labels` / `selectorLabels`، متسقة عبر الكتالوج بأكمله.
- **مُحلِّل الصور القائم على البصمة فقط**: يحل `quench-common.image` الصورة حصريًا عبر `repository@sha256:digest`. يُرفَض المرجع القائم على الوسم (tag) فقط عن قصد، حتى لا يتمكن أي مخطط أبدًا من شحن صورة غير مثبَّتة.
- **سياق أمان مُحصَّن للـ pod**: يضبط `quench-common.podSecurityContext` كلًا من `runAsNonRoot`، وuid/gid/fsGroup 1001، وseccomp `RuntimeDefault`.
- **سياق أمان مُحصَّن للحاوية**: يضبط `quench-common.containerSecurityContext` نظام ملفات جذر للقراءة فقط، ومنع تصعيد الامتيازات، وإسقاط كل الصلاحيات (drop ALL capabilities).
- **سطح مفاتيح ضبط مشترك**: نقاط التجاوز (override points) التي يكشفها كل مخطط بالطريقة نفسها، بما في ذلك الجدولة، والفحوص (probes)، والمتغيرات/المجلدات/تركيبات المجلدات الإضافية، وحاويات التهيئة (init containers)، والحاويات الجانبية (sidecars)، وخطافات دورة الحياة (lifecycle hooks)، وتجاوزات سياق الأمان.

## الإصدارات

ارفع رقم التصحيح (patch) في `version` الخاص بالمخطط مع كل تغيير، ولا تستبدل أبدًا إصدارًا منشورًا. تنتقل عندئذٍ مخططات التطبيقات إلى الإصدار الجديد في إصدارها التالي. هذا مخطط مكتبة، لذا لا يوجد ما يمكن تنفيذ `helm install` عليه مباشرة.

## الإصدار

يؤدي الدفع إلى `main` إلى تشغيل `.github/workflows/release-common.yml`: الفحص (lint)، والتحزيم، ودفع مخطط OCI إلى GHCR، وتوقيعه بـ cosign (بدون مفاتيح / keyless).

## الترخيص

MIT.

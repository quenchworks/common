{{/*
Index of the quench-common library. Each concern lives in its own file so a chart author
can find and read one thing at a time:

  _names.tpl             quench-common.name, .fullname
  _labels.tpl            quench-common.labels, .podTemplateLabels, .commonAnnotations
  _selector-labels.tpl   quench-common.selectorLabels, .selectorLabelsBase
                         (READ IT before adding selector labels -- they are IMMUTABLE)
  _image.tpl             quench-common.image (digest-only), .imagePullSecrets
  _security.tpl          quench-common.podSecurityContext, .containerSecurityContext
  _pod.tpl               pod-spec knobs: podSpecFields, probes, env, volumes,
                         initContainers, sidecars, lifecycleHooks, command, args
  _serviceaccount.tpl    quench-common.serviceAccountName, .serviceAccount
  _rbac.tpl              quench-common.rbac
  _pdb.tpl               quench-common.pdb
  _hpa.tpl               quench-common.hpa
  _networkpolicy.tpl     quench-common.networkPolicy
  _ingress.tpl           quench-common.ingress

This file intentionally defines nothing. It used to hold names, labels, selectorLabels
and image; those moved to the files above without changing behaviour.
*/}}

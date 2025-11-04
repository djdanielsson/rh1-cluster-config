# Cluster Config Repository Structure

This document shows the complete structure of the rh1-cluster-config repository.

## Directory Tree

```
rh1-cluster-config/
├── README.md                           # Repository overview and links
├── DEPLOYMENT.md                       # Step-by-step deployment guide
├── STRUCTURE.md                        # This file
├── ARCHITECTURE.md                     # Architecture diagrams
├── QUICKREF.md                         # Quick reference commands
├── .gitignore                          # Git ignore patterns
│
├── bootstrap-openshift-gitops/         # Bootstrap Resources (Apply Once)
│   ├── openshift-gitops-operator-subscription.yml  # Install GitOps operator
│   └── cluster-applicationset.yml      # Auto-discovers applications/*
│
└── applications/                       # Application Directories (Auto-discovered)
    │
    ├── aap-dev/                        # Dev AAP Environment (Self-contained)
    │   ├── kustomization.yaml          # Kustomize config for this app
    │   ├── aap-dev-namespace.yml       # Namespace definition
    │   ├── aap-dev-operatorgroup.yml   # OperatorGroup (namespace-scoped)
    │   ├── aap-dev-subscription.yml    # AAP Operator subscription
    │   └── aap-dev-ansibleautomationplatform.yml  # AAP instance CR
    │
    ├── aap-qa/                         # QA AAP Environment (Self-contained)
    │   ├── kustomization.yaml
    │   ├── aap-qa-namespace.yml
    │   ├── aap-qa-operatorgroup.yml
    │   ├── aap-qa-subscription.yml
    │   └── aap-qa-ansibleautomationplatform.yml
    │
    ├── aap-prod/                       # Prod AAP Environment (Self-contained)
    │   ├── kustomization.yaml
    │   ├── aap-prod-namespace.yml
    │   ├── aap-prod-operatorgroup.yml
    │   ├── aap-prod-subscription.yml
    │   └── aap-prod-ansibleautomationplatform.yml
    │
    ├── openshift-pipelines/            # OpenShift Pipelines Operator
    │   ├── kustomization.yaml
    │   └── openshift-pipelines-operator-subscription.yaml
    │
    ├── ansible-molecule-ci/            # CI for Ansible Collections
    │   ├── kustomization.yaml
    │   ├── ansible-molecule-ci-namespace.yml
    │   └── ansible-collection-foo-repository.yml  # Tekton Repository CR
    │
    └── ee-builder-ci/                  # CI for Execution Environments
        ├── kustomization.yml
        ├── ee-builder-ci-namespace.yml
        └── rh1-ee-repository.yml       # Tekton Repository CR
```

## Resource Counts

| Category | Count | Purpose |
|----------|-------|---------|
| ApplicationSet | 1 | Auto-discovers applications/* directories |
| ArgoCD Applications | 6 | One per applications/* subdirectory |
| Namespaces | 5 | aap-dev, aap-qa, aap-prod, ansible-molecule-ci, ee-builder-ci |
| Operator Subscriptions | 4 | 3x AAP (namespace-scoped), 1x Pipelines (cluster-scoped) |
| OperatorGroups | 3 | One per AAP namespace (name: aap-operatorgroup) |
| AnsibleAutomationPlatform CRs | 3 | dev, qa, prod |
| Repository CRs | 2 | ansible-collection-foo, rh1-ee |
| Kustomization files | 6 | One per application directory |

**Total Application Directories**: 6 (auto-discovered)
**Total Kubernetes Resources**: ~22 resources managed by ArgoCD

## Deployment Flow

The ApplicationSet automatically discovers and deploys applications:

```
Step 1: Manually apply bootstrap resources
    ├── openshift-gitops-operator-subscription.yml
    └── cluster-applicationset.yml
            ↓
Step 2: ApplicationSet discovers applications/* directories
    └── Creates one Application per subdirectory
            ↓
Step 3: Each Application deploys its resources via Kustomization
    ├── aap-dev/       → Wave -2: OperatorGroup, Subscription
    │                  → Wave 0:  Namespace, AAP CR
    ├── aap-qa/        → Wave -2: OperatorGroup, Subscription
    │                  → Wave 0:  Namespace, AAP CR
    ├── aap-prod/      → Wave -2: OperatorGroup, Subscription
    │                  → Wave 0:  Namespace, AAP CR
    ├── openshift-pipelines/ → Operator Subscription (cluster-scoped)
    ├── ansible-molecule-ci/ → Namespace + Repository CR
    └── ee-builder-ci/       → Namespace + Repository CR
```

**Key Deployment Characteristics**:
- Each AAP environment is **self-contained** with its own operator
- OperatorGroups all have the same name (`aap-operatorgroup`) but are namespace-scoped
- Sync waves within each application ensure operators install before CRs
- New applications are **automatically discovered** when added to `applications/`

**Total Deployment Time**: ~10-15 minutes from bootstrap to fully operational

## GitOps Compliance

### Constitution Article I: Law of GitOps ✓

- **Single Source of Truth**: All cluster state in this repository
- **No Manual Changes**: ApplicationSet + Applications auto-sync enabled
- **Auditability**: Git log provides complete audit trail
- **Auto-Discovery**: New applications automatically deployed when directories added

### Managed by ArgoCD

✅ All YAML files in `applications/*/` are managed by ArgoCD
✅ Changes pushed to Git are automatically synced to cluster (3 min poll interval)
✅ Manual cluster changes are detected and reverted (self-heal enabled)
✅ Deletions in Git trigger resource pruning in cluster (prune: true)
✅ New application directories automatically discovered and deployed

### Not Managed by ArgoCD

❌ OpenShift GitOps Operator installation (manual bootstrap step 1)
❌ ApplicationSet resource (manual bootstrap step 2)
❌ Secrets auto-generated by operators (e.g., AAP admin passwords)

## File Naming Conventions

- **Directories**: `applications/{app-name}/` - One directory per application
- **Kustomization**: `kustomization.yaml` - Required in each app directory
- **Namespaces**: `{namespace-name}-namespace.yml`
- **OperatorGroups**: `{env}-operatorgroup.yml` (all named `aap-operatorgroup`)
- **Subscriptions**: `{env}-subscription.yml` - Operator subscriptions
- **AAP Instances**: `{env}-ansibleautomationplatform.yml`
- **Repositories**: `{repo-name}-repository.yml` - Tekton Repository CRs

## Key Annotations

Sync waves control deployment order within each application:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-2"  # Operators before CRs
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true  # For CRDs
```

Common sync wave values:
- **Wave -2**: OperatorGroups and Subscriptions (operators must install first)
- **Wave 0** (default): All other resources (namespaces, CRs, etc.)

## Adding New Applications

To add a new application to the platform:

1. Create directory: `applications/my-new-app/`
2. Add `kustomization.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   namespace: my-namespace
   resources:
   - namespace.yml
   - other-resources.yml
   ```
3. Add your resource YAML files
4. Commit and push to Git
5. ApplicationSet automatically discovers and creates Application
6. Resources deploy within ~3 minutes

## Next Steps

1. ✅ **Completed**: Repository structure created
2. ✅ **Completed**: Bootstrap resources in place
3. 🔄 **Next**: Follow DEPLOYMENT.md to bootstrap platform
4. 🔄 **Next**: Configure AAP instances
5. 🔄 **Next**: Add CI/CD pipelines

---

**Repository Type**: GitOps Platform Configuration
**Pattern**: ApplicationSet with Auto-Discovery
**Tool**: OpenShift GitOps (ArgoCD)
**Automation Level**: 98% (only 2 manual bootstrap commands required)
**Last Updated**: 2025-11-04


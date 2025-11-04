# Architecture Overview - ApplicationSet Managed AAP Platform

## 🏗️ High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          OpenShift Cluster                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │                    GitOps Control Plane                      │ │
│  │                   (openshift-gitops ns)                      │ │
│  │                                                              │ │
│  │   ┌────────────────────────────────────────────────┐        │ │
│  │   │  ApplicationSet (cluster)                      │        │ │
│  │   │  - Watches: applications/* directories         │        │ │
│  │   │  - Auto-creates: Application per directory     │        │ │
│  │   │                                                 │        │ │
│  │   │  Creates Applications:                         │        │ │
│  │   │  ├── aap-dev      (self-contained)            │        │ │
│  │   │  ├── aap-qa       (self-contained)            │        │ │
│  │   │  ├── aap-prod     (self-contained)            │        │ │
│  │   │  ├── openshift-pipelines                       │        │ │
│  │   │  ├── ansible-molecule-ci                       │        │ │
│  │   │  └── ee-builder-ci                             │        │ │
│  │   └────────────────────────────────────────────────┘        │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │   Each AAP Application deploys (self-contained):             │ │
│  │   Wave -2: OperatorGroup + Subscription                      │ │
│  │   Wave 0:  Namespace + AnsibleAutomationPlatform CR          │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │   aap-dev    │  │   aap-qa     │  │   aap-prod   │            │
│  │  namespace   │  │  namespace   │  │  namespace   │            │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤            │
│  │ AAP Operator │  │ AAP Operator │  │ AAP Operator │            │
│  │ (ns-scoped)  │  │ (ns-scoped)  │  │ (ns-scoped)  │            │
│  │              │  │              │  │              │            │
│  │ AAP Instance │  │ AAP Instance │  │ AAP Instance │            │
│  │ - API        │  │ - API        │  │ - API        │            │
│  │ - Web UI     │  │ - Web UI     │  │ - Web UI     │            │
│  │ - Hub        │  │ - Hub        │  │ - Hub        │            │
│  │ - EDA        │  │ - EDA        │  │ - EDA        │            │
│  │ - Database   │  │ - Database   │  │ - Database   │            │
│  │ - Redis      │  │ - Redis      │  │ - Redis      │            │
│  └──────────────┘  └──────────────┘  └──────────────┘            │
│                                                                     │
│  ┌──────────────────────┐  ┌──────────────────────┐              │
│  │ ansible-molecule-ci  │  │   ee-builder-ci      │              │
│  │    namespace         │  │     namespace        │              │
│  ├──────────────────────┤  ├──────────────────────┤              │
│  │ Tekton Repository CR │  │ Tekton Repository CR │              │
│  │ (PipelinesAsCode)    │  │ (PipelinesAsCode)    │              │
│  │ - CI for collections │  │ - CI for EEs         │              │
│  └──────────────────────┘  └──────────────────────┘              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## 🔄 GitOps Workflow with ApplicationSet

```
┌──────────────────────────────────────────────────────────────────┐
│                       Developer Workflow                         │
└──────────────────────────────────────────────────────────────────┘

    Developer                Git Repository      ApplicationSet/ArgoCD  OpenShift
        │                         │                      │                    │
        │  1. Edit YAML in        │                      │                    │
        │     applications/       │                      │                    │
        ├────────────────────────>│                      │                    │
        │                         │                      │                    │
        │  2. Git Commit & Push   │                      │                    │
        ├────────────────────────>│                      │                    │
        │                         │                      │                    │
        │                         │  3. Detect Change    │                    │
        │                         │  (Poll every 3min)   │                    │
        │                         ├─────────────────────>│                    │
        │                         │                      │                    │
        │                         │  4. Git Pull         │                    │
        │                         │<─────────────────────┤                    │
        │                         │                      │                    │
        │                         │  5. ApplicationSet   │                    │
        │                         │     discovers dirs   │                    │
        │                         │     & updates Apps   │                    │
        │                         │                      │                    │
        │                         │                      │  6. Apply Changes  │
        │                         │                      │  via Kustomize     │
        │                         │                      ├───────────────────>│
        │                         │                      │                    │
        │                         │                      │  7. Health Check   │
        │                         │                      │<───────────────────┤
        │                         │                      │                    │
        │  8. Check ArgoCD UI     │                      │                    │
        │<────────────────────────┼──────────────────────┤                    │
        │  (See "Synced" status)  │                      │                    │

        Auto-Heal: ArgoCD reverts manual changes to match Git (prune: true)
        Auto-Discovery: New directories automatically become Applications
```

## 🎯 CI/CD with Tekton Pipelines as Code

The repository uses **Tekton Pipelines as Code** via Repository CRs:

```
┌────────────────────────────────────────────────────────────────────┐
│              Pipelines as Code (Repository CRs)                    │
└────────────────────────────────────────────────────────────────────┘

GitHub Repositories              OpenShift Namespaces       Pipeline Definition
     │                                  │                            │
     │  ansible-collection-foo          │                            │
     ├─────────────────────────────────>│  ansible-molecule-ci       │
     │  Repository CR creates           │  - Watches repo            │
     │  connection                      │  - .tekton/ in repo        │
     │                                  │    defines pipelines       │
     │                                  │                            │
     │  Push/PR triggers pipeline       │                            │
     ├─────────────────────────────────>│────────────────────────────>
     │                                  │  Pipeline runs from        │
     │                                  │  .tekton/*.yaml in repo    │
     │                                  │                            │
     │  rh1-ee                          │                            │
     ├─────────────────────────────────>│  ee-builder-ci             │
     │  Repository CR creates           │  - Watches repo            │
     │  connection                      │  - .tekton/ in repo        │
     │                                  │    defines pipelines       │
     │                                  │                            │

Key Concepts:
- Repository CRs in this repo define which GitHub repos to watch
- Pipeline definitions (.tekton/*.yaml) live in the watched repositories
- Webhooks are automatically configured by Pipelines as Code
- Each push/PR triggers pipelines defined in the source repo
```

## 🔐 Security Model

```
┌────────────────────────────────────────────────────────────────────┐
│                    Security and Isolation                          │
└────────────────────────────────────────────────────────────────────┘

Namespace Isolation:
  ├─ aap-dev/       → Isolated AAP operator + instance
  ├─ aap-qa/        → Isolated AAP operator + instance
  ├─ aap-prod/      → Isolated AAP operator + instance
  ├─ ansible-molecule-ci/ → CI namespace for collections
  └─ ee-builder-ci/       → CI namespace for execution environments

Operator Deployment Model:
  - Each AAP namespace has its own AAP operator (namespace-scoped)
  - OperatorGroup restricts operator to watch only its namespace
  - Operators cannot interfere with other AAP environments
  - OpenShift Pipelines operator is cluster-scoped (openshift-operators)

Secrets Management:
  ├─ aap-*-admin-password (per AAP namespace)
  │   └─ Auto-generated by AAP operator
  │   └─ Referenced by AnsibleAutomationPlatform CR
  │
  └─ Future: CI/CD secrets (will be added as pipelines are configured)
      ├─ AAP API credentials for automation
      └─ Git/registry credentials for pipelines

Constitution Article V: Zero-Trust Security ✓
  ✓ No secrets committed to Git
  ✓ Resources reference secrets by name only
  ✓ Namespace isolation prevents cross-environment access
  ✓ Operator permissions scoped to namespace
```

## 📊 Platform Deployment Flow

```
┌────────────────────────────────────────────────────────────────────┐
│            Bootstrap to Running AAP Instances                      │
└────────────────────────────────────────────────────────────────────┘

Administrator                Git Repository      ApplicationSet        OpenShift
     │                            │                      │                │
     │ 1. Apply bootstrap         │                      │                │
     │    resources               │                      │                │
     ├───────────────────────────>│                      │                │
     │ - GitOps operator          │                      │                │
     │ - ApplicationSet CR        │                      │                │
     │                            │                      │                │
     │                            │  2. Discover apps/*  │                │
     │                            │<─────────────────────┤                │
     │                            │                      │                │
     │                            │  3. Create Apps      │                │
     │                            │     (one per dir)    │                │
     │                            │                      │                │
     │                            │                      │  4. Deploy     │
     │                            │                      │     Wave -2:   │
     │                            │                      │     Operators  │
     │                            │                      ├───────────────>│
     │                            │                      │                │
     │                            │                      │  5. Deploy     │
     │                            │                      │     Wave 0:    │
     │                            │                      │     AAP CRs    │
     │                            │                      ├───────────────>│
     │                            │                      │                │
     │                            │                      │  6. Operators  │
     │                            │                      │     create AAP │
     │                            │                      │     resources  │
     │                            │                      │<───────────────┤
     │                            │                      │                │
     │  7. Access AAP UIs         │                      │                │
     │<───────────────────────────┼──────────────────────┼────────────────┤
     │  - Dev, QA, Prod ready     │                      │                │

Result:
  - 3 independent AAP environments running
  - Each with its own operator (namespace-scoped)
  - Auto-generated admin passwords
  - Ready for configuration and use
```

## 🏛️ Constitution Compliance Mapping

```
┌────────────────────────────────────────────────────────────────────┐
│                   Constitution Article Compliance                  │
└────────────────────────────────────────────────────────────────────┘

Article I: Law of GitOps ✓
  ✓ Single Source of Truth
    └─> All platform state in rh1-cluster-config repository
  ✓ No Manual Changes
    └─> ApplicationSet auto-discovers + Applications auto-sync
    └─> Self-heal enabled (prune: true)
  ✓ Auditability
    └─> Git log provides immutable audit trail
  ✓ Auto-Discovery
    └─> New applications automatically deployed when directories added
  Implementation: ApplicationSet with directory auto-discovery

Article II: Law of Separation of Duties ✓
  ✓ Platform vs Application
    └─> Platform: ArgoCD manages OpenShift resources (this repo)
    └─> Application: Pipelines manage Ansible content (in source repos)
  ✓ Infrastructure Isolation
    └─> Each AAP environment has its own operator (namespace-scoped)
    └─> CI/CD namespaces separated from AAP environments
  Implementation: Namespace isolation + operator scoping

Article III: Law of Atomic Promotion
  🔄 Future Implementation
    └─> Will be implemented via CI/CD pipelines
    └─> Pipeline definitions will live in .tekton/ dirs of source repos
    └─> Repository CRs already configured to watch repos

Article IV: Law of Production-Grade Quality ✓
  ✓ Declarative Infrastructure
    └─> All resources defined as YAML
  ✓ Idempotency
    └─> Kustomize ensures consistent deployments
  ✓ Modularity
    └─> Each application self-contained in own directory
  ✓ Environment Separation
    └─> Dev, QA, Prod isolated with dedicated operators
  Implementation: Kustomize + ApplicationSet pattern

Article V: Law of Zero-Trust Security ✓
  ✓ No Secrets in Git
    └─> All secrets in OpenShift Secret resources
  ✓ Reference by Name
    └─> AnsibleAutomationPlatform CRs reference secret names
  ✓ Namespace Isolation
    └─> Operators scoped to single namespace via OperatorGroup
    └─> Cannot access resources in other namespaces
  ✓ Least Privilege
    └─> Namespace-scoped operators have minimal permissions
  Implementation: Secret references + OperatorGroup namespace scoping
```

## 📁 Repository Relationships

```
┌────────────────────────────────────────────────────────────────────┐
│                Current Repository Architecture                     │
└────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  rh1-cluster-config (Platform GitOps) - THIS REPO               │
│  ├── bootstrap-openshift-gitops/                                │
│  │   ├── openshift-gitops-operator-subscription.yml             │
│  │   └── cluster-applicationset.yml                             │
│  └── applications/                                               │
│      ├── aap-dev/      (self-contained AAP environment)         │
│      ├── aap-qa/       (self-contained AAP environment)         │
│      ├── aap-prod/     (self-contained AAP environment)         │
│      ├── openshift-pipelines/ (Tekton operator)                 │
│      ├── ansible-molecule-ci/  (CI namespace + Repository CR)   │
│      └── ee-builder-ci/        (CI namespace + Repository CR)   │
│                                                                  │
│  Managed by: ApplicationSet (auto-discovers directories)        │
│  Sync: Automatic (3 min poll)                                   │
│  URL: github.com/djdanielsson/rh1-cluster-config                │
└─────────────────────────────────────────────────────────────────┘
           │
           │  Repository CRs watch ↓
           │
┌──────────┴──────────────────────────────────────────────────────┐
│  ansible-collection-foo (Ansible Collection)                    │
│  - roles/                                                        │
│  - plugins/                                                      │
│  - .tekton/ (pipeline definitions for CI)                       │
│                                                                  │
│  CI by: Pipelines as Code (ansible-molecule-ci namespace)       │
│  URL: github.com/david-igou/ansible-collection-foo              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  rh1-ee (Execution Environment)                                 │
│  - execution-environment.yml                                    │
│  - requirements.yml (collections)                               │
│  - .tekton/ (pipeline definitions for CI)                       │
│                                                                  │
│  CI by: Pipelines as Code (ee-builder-ci namespace)             │
│  URL: github.com/djdanielsson/rh1-ee                            │
└─────────────────────────────────────────────────────────────────┘

Key Patterns:
  - Platform infrastructure defined in rh1-cluster-config
  - CI/CD pipeline definitions live in source repositories (.tekton/)
  - Repository CRs create connections between OpenShift and GitHub
  - Pipelines as Code automatically configures webhooks
```

---

**Architecture Pattern**: ApplicationSet with Auto-Discovery + Pipelines as Code
**Deployment Model**: Directory-based Application discovery
**Automation**: Git-based auto-discovery + Tekton Pipelines as Code
**Security Model**: Namespace isolation with scoped operators
**Constitution Compliant**: Articles I, II, IV, V verified ✓ (Article III future)
**Last Updated**: 2025-11-04


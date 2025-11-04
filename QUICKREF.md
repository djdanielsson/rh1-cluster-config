# Quick Reference Card - ApplicationSet AAP Platform

## 🚀 Bootstrap Commands

```bash
# 1. Install OpenShift GitOps (one time)
oc apply -f bootstrap-openshift-gitops/openshift-gitops-operator-subscription.yml

# 2. Deploy ApplicationSet (auto-discovers all applications)
oc apply -f bootstrap-openshift-gitops/cluster-applicationset.yml
```

## 📊 Status Checks

```bash
# ArgoCD Applications (should see one per applications/* directory)
oc get applications -n openshift-gitops

# ApplicationSet
oc get applicationset -n openshift-gitops

# AAP Instances
oc get ansibleautomationplatform -A

# Operators
oc get csv -n aap-dev,aap-qa,aap-prod
oc get csv -n openshift-operators | grep pipelines

# All Pods
oc get pods -n aap-dev
oc get pods -n aap-qa
oc get pods -n aap-prod
oc get pods -n ansible-molecule-ci
oc get pods -n ee-builder-ci
```

## 🔗 Important URLs

```bash
# ArgoCD UI
echo "https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"

# AAP Instances (routes created by operator)
echo "Dev:  https://$(oc get route -n aap-dev -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo 'Not ready')"
echo "QA:   https://$(oc get route -n aap-qa -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo 'Not ready')"
echo "Prod: https://$(oc get route -n aap-prod -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo 'Not ready')"
```

## 🔐 Secrets Management

```bash
# Get auto-generated AAP admin passwords
echo "Username: admin"
echo "Dev password:  $(oc get secret aap-dev-admin-password -n aap-dev -o jsonpath='{.data.password}' | base64 -d)"
echo "QA password:   $(oc get secret aap-qa-admin-password -n aap-qa -o jsonpath='{.data.password}' | base64 -d)"
echo "Prod password: $(oc get secret aap-prod-admin-password -n aap-prod -o jsonpath='{.data.password}' | base64 -d)"
```

## 🔄 Common Operations

### Force ArgoCD Sync
```bash
# Sync specific application
oc patch application <app-name> -n openshift-gitops \
  --type merge \
  --patch '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Sync all applications
for app in $(oc get applications -n openshift-gitops -o name); do
  oc patch $app -n openshift-gitops --type merge --patch '{"operation":{"sync":{}}}'
done
```

### Add New Application
```bash
# 1. Create directory structure
mkdir -p applications/my-new-app

# 2. Create kustomization.yaml
cat > applications/my-new-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: my-namespace
resources:
- namespace.yml
- deployment.yml
EOF

# 3. Add your resources, commit and push
git add applications/my-new-app/
git commit -m "Add my-new-app"
git push

# ApplicationSet will automatically discover and create the Application
```

### Rollback (Git)
```bash
git revert <commit-sha>
git push origin main
# ArgoCD will auto-sync in ~3 minutes
```

### Delete an Application
```bash
# 1. Remove directory from Git
rm -rf applications/my-app/
git commit -am "Remove my-app"
git push

# 2. ApplicationSet will remove the Application
# 3. Resources will be cleaned up automatically (prune: true)
```

## 🐛 Troubleshooting

### Check ApplicationSet
```bash
# Check ApplicationSet status
oc describe applicationset cluster -n openshift-gitops

# Check ApplicationSet controller logs
oc logs -n openshift-gitops \
  -l app.kubernetes.io/name=openshift-gitops-applicationset-controller \
  --tail=50
```

### Check ArgoCD Application Controller
```bash
oc logs -n openshift-gitops \
  -l app.kubernetes.io/name=openshift-gitops-application-controller \
  --tail=50
```

### Check AAP Operator
```bash
# Check operator in AAP namespace
oc get csv -n aap-dev
oc logs -n aap-dev -l control-plane=controller-manager --tail=50

# Or check in openshift-operators for Pipelines
oc get csv -n openshift-operators
oc logs -n openshift-operators -l name=openshift-pipelines-operator --tail=50
```

### AAP Not Starting
```bash
# Check AnsibleAutomationPlatform CR
oc describe ansibleautomationplatform aap-dev -n aap-dev

# Check operator subscription
oc describe subscription ansible-automation-platform-operator -n aap-dev

# Check pods
oc get pods -n aap-dev
oc logs <pod-name> -n aap-dev
```

### Application Not Syncing
```bash
# Check application details
oc describe application aap-dev -n openshift-gitops

# Check sync status
oc get application aap-dev -n openshift-gitops -o jsonpath='{.status.sync.status}'

# Check health
oc get application aap-dev -n openshift-gitops -o jsonpath='{.status.health.status}'
```

## 📝 Git Workflow

```bash
# 1. Make changes to an application
vi applications/aap-dev/aap-dev-ansibleautomationplatform.yml

# 2. Commit & push
git add .
git commit -m "Update AAP dev replicas"
git push origin main

# 3. Watch ArgoCD sync (automatic within 3 minutes)
watch oc get applications -n openshift-gitops

# Or force immediate sync
oc patch application aap-dev -n openshift-gitops \
  --type merge \
  --patch '{"operation":{"sync":{}}}'
```

## 📈 Monitoring

### Application Health
```bash
# View all applications with status
oc get applications -n openshift-gitops \
  -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

# Count synced vs out-of-sync
oc get applications -n openshift-gitops -o json | \
  jq '[.items[].status.sync.status] | group_by(.) | map({status: .[0], count: length})'
```

### Resource Usage
```bash
# AAP pods resource consumption
oc adm top pods -n aap-dev
oc adm top pods -n aap-qa
oc adm top pods -n aap-prod

# Node resource usage
oc adm top nodes
```

### Operator Status
```bash
# Check all AAP operators
for ns in aap-dev aap-qa aap-prod; do
  echo "=== $ns ==="
  oc get csv -n $ns
done

# Check cluster-scoped operators
oc get csv -n openshift-operators
```

## 🔗 Repository URLs

- **cluster-config**: `https://github.com/djdanielsson/rh1-cluster-config.git`
- **rh1-ee**: `https://github.com/djdanielsson/rh1-ee.git`
- **ansible-collection-foo**: `https://github.com/david-igou/ansible-collection-foo.git`

## 📚 Documentation Links

- **Full Deployment Guide**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **Repository Structure**: [STRUCTURE.md](STRUCTURE.md)
- **Architecture Details**: [README.md](README.md)
- **Quickstart**: [../specs/001-cloud-native-ansible-lifecycle/quickstart.md](../specs/001-cloud-native-ansible-lifecycle/quickstart.md)

---

**Tip**: Bookmark this file for quick reference during operations!


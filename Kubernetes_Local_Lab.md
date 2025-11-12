# Kubernetes Local Lab: Minikube & KIND

## 1. Local Kubernetes Setup

### Minikube Installation & Verification

#### Installation (Linux):
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

#### Start and Verify:
```bash
minikube start
minikube status
kubectl get nodes
kubectl get namespaces
```
Default namespaces: `default`, `kube-system`, `kube-public`, `kube-node-lease`

### Minikube vs KIND

| Feature              | Minikube                          | KIND                              |
|----------------------|------------------------------------|-----------------------------------|
| **Cluster type**     | Single-node VM or container       | Multi-node Docker-in-Docker       |
| **Storage**          | Native persistent volume support  | Ephemeral by default; persistent needs manual config |
| **Add-ons**          | Quick enable (e.g., dashboard)    | Manual add-ons                   |
| **Use case**         | Dev, prod-like local clusters, stateful testing | CI/CD, rapid multi-node, ephemeral |
| **Resource usage**   | Higher (VM unless docker driver used) | Lightweight, fast               |

#### Volume Limitations:
- **Minikube**: Supports realistic persistent volumes (hostPath and dynamic provisioning).
- **KIND**: Volumes are ephemeral by default; persistent storage is hacky—not for production-stateful testing.

#### Recommended:
- Use **Minikube** for serious stateful/local testing.
- Use **KIND** for CI, quick/ephemeral experiments.

---

## 2. Application Deployment Basics

### Deploy a Simple (Stateless) Web App

#### Deployment YAML:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-web
  template:
    metadata:
      labels:
        app: hello-web
    spec:
      containers:
      - name: web
        image: kicbase/echo-server:1.0
        ports:
        - containerPort: 8080
```

#### Apply:
```bash
kubectl apply -f deployment.yaml
```

#### Service YAML (NodePort):
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-web-service
spec:
  type: NodePort
  selector:
    app: hello-web
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30036
```

#### Apply and Test:
```bash
kubectl apply -f service.yaml
kubectl get service hello-web-service
minikube service hello-web-service --url
# Or: curl $(minikube ip):30036
```

### Horizontal Pod Autoscaler (HPA)

#### HPA YAML:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: hello-web-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: hello-web
  minReplicas: 1
  maxReplicas: 3
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
```

#### Apply and Verify:
```bash
kubectl apply -f hpa.yaml
kubectl get hpa
```
- `targetCPUUtilizationPercentage`: Triggers scaling.
- `minReplicas`, `maxReplicas`: Lower/upper bounds.
- **Load test**: Run CPU load in containers to see scaling.

---

## 3. Stateful Application Deployment

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: stateful-app
spec:
  serviceName: "stateful-app"
  replicas: 1
  selector:
    matchLabels:
      app: stateful-app
  template:
    metadata:
      labels:
        app: stateful-app
    spec:
      containers:
      - name: app
        image: mysql:5.7
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
```

```bash
kubectl apply -f statefulset.yaml
```

- **If PVC fails in KIND**: Stateful storage does not persist by default in KIND. Use Minikube unless you can provide external storage.

---

## 4. Kubernetes CronJobs

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: hello-cron
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

```bash
kubectl apply -f cronjob.yaml
kubectl get cronjobs
kubectl get jobs
kubectl get pods --watch
```

---

## 5. Troubleshooting & Cluster Operations

### CrashLoopBackOff Simulation:

#### Use a bad image in your YAML:
```yaml
image: nonexistentrepo/invalid:latest
```

#### Watch:
```bash
kubectl apply -f deployment.yaml
kubectl get pods
kubectl describe pod <name>
kubectl logs <name>
```

### Essentials:
```bash
kubectl describe <resource> <name>
kubectl logs <pod>
kubectl scale deployment <name> --replicas=3
```

---

## 6. Node Scheduling & Placement

### Taints and Tolerations:
```bash
kubectl taint nodes <node> key=value:NoSchedule
```

#### Pod tolerations (add to spec):
```yaml
tolerations:
- key: "key"
  operator: "Equal"
  value: "value"
  effect: "NoSchedule"
```

### Labels & Affinity:
```bash
kubectl label nodes <node> env=prod
```

#### Pod spec:
```yaml
nodeSelector:
  env: prod

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: zone
          operator: In
          values:
          - ap-south-1a
  podAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - myapp
      topologyKey: "kubernetes.io/hostname"
```

---

## 7. Deployment Management
```bash
kubectl rollout status deployment/hello-web
kubectl set image deployment/hello-web web=nginx:1.19
kubectl rollout history deployment/hello-web
kubectl rollout undo deployment/hello-web
```

---

## 8. Monitoring & Visualization

### Prometheus & Grafana:
```bash
minikube addons enable prometheus
# For Grafana, use addon or install via Helm
minikube service prometheus --url
minikube service grafana --url
```

### Kubernetes Dashboard:
```bash
minikube dashboard
```

---

## 9. Logging & Observability

### EFK Stack:
Deploy Elasticsearch, Fluentd, and Kibana as per official docs or helm charts.

#### Verify:
```bash
kubectl logs <pod> -n <namespace>
# Or: Kibana dashboard
```

---

## 10. Autoscaling Strategies

| Feature              | HPA (Horizontal)                  | VPA (Vertical)                   |
|----------------------|------------------------------------|-----------------------------------|
| **Action**           | Scales pod count                  | Adjusts pod resources            |
| **Use-case**         | Stateless, variable workloads     | Unpredictable CPU/mem usage      |
| **Demo**             | See above HPA section             | Install VPA operator, use CRDs   |

---

For best experience with persistent volumes and realistic dev, use Minikube. KIND is ideal for CI & ephemeral workloads. For production-like stateful sets, Minikube is recommended.
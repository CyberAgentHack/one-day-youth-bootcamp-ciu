<details><summary>問題 2: 解答解説</summary><div>

Deployment の yaml は下記のようになります

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: nginx
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.18.0
        name: nginx
        ports:
        - containerPort: 80
        resources: {}
status: {}
```


</div></details>


<details><summary>上級問題 2: 解答解説</summary><div>

まず、Deployment の yaml は下記のように作成します

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: null
  labels:
    app: nginx
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  strategy: {}
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - image: nginx:1.18.0
        name: nginx
        ports:
        - containerPort: 80
        resources: {}
status: {}
```

次に作成した Deployment に対して HPA を作成し、オートスケールを有効化します。
```yaml
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  creationTimestamp: null
  name: nginx
spec:
  maxReplicas: 10
  minReplicas: 5
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx
  targetCPUUtilizationPercentage: 80
```

少し待つと Deployment の Pod 数が 5に増えているはずです

```sh
kubectl get deploy nginx
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   5/5     5            5           4m2s
```

HPA は30秒に1回の頻度で指定したメトリクスが閾値に到達すると、対象のリソースの Replicas を増やします。
スケールアウトは3分に1回が最大となっています。
- 必要なレプリカ数 = ceil(sum( 指定したメトリクス ) / 指定した閾値)
- ceil 関数は切り上げを行う関数です。

なので Replicas が 6台にスケールされるには
- 6 = ceil(sum(cpu usage) / 80 ) となればいいので sum (cpu usage) / 80 >= 5.5 を満たせばよいです。
- sum (cpu usage) >= 440 となるので 5台の場合は平均 88 % の CPU 使用率で 6台に増加させる処理が行われます。

また、HPA はスケールインも行います。スケールインは 5分に1回上記の条件式で計算を行います。
スケールインは5分に1回が最大となっています。

HPA に使用するメトリクスは CPU やメモリだけでなく、custom metrics という機能で Kubernetes に組み込まれたメトリクス以外のものも指定することができます。
ビジネスロジックやその他複雑な条件をもとにスケールアウト、スケールインさせたい場合はこちらの採用も考慮すべきでしょう。
</div></details>

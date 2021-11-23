<details><summary>問題3</summary><div>

Ingress の `.spec.rules.host[].paths[]` にエントリーを追加することで `/bar` でアクセスされた時に、
bar Service にリクエストを転送するように設定します。

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
spec:
  tls:
  - hosts:
    - echo.info
    secretName: echo-tls
  rules:
  - host: echo.info 
    http:
      paths:
      - pathType: Prefix
        path: "/foo"
        backend:
          service:
            name: foo-service
            port:
              number: 8080
      - pathType: Prefix
        path: "/bar"
        backend:
          service:
            name: bar-service
            port:
              number: 8080
```

`bar-service` とその裏でリクエストを処理する echo Pod は Examples をもとに新規で追加してみましょう。

</div></details>

<details><summary>上級問題 3: 解答解説</summary><div>

まずオレオレ証明書を作成します

```sh
#!/bin/bash -x
openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -days 10000 -out ca.crt -subj "/CN=ingress-ca"

cat <<_EOF_>ssl.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = echo.info
IP.1 = 127.0.0.1
_EOF_

openssl genrsa -out server.key 2048
openssl req -new -key server.key -subj "/C=JP/ST=Tokyo/L=Shibuya-ku/O=ingress/CN=echo.info" -config ssl.conf | openssl x509 -req -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 10000 -extensions v3_req -extfile ssl.conf

kubectl create secret generic echo-tls --from-file=tls.crt=server.crt --from-file=tls.key=server.key --from-file=ca.crt=ca.crt
```

自己署名証明書は `echo.info` のホストの証明書でなければいけないので、`CN (Common Name)` で指定しています。
マルチドメインの証明書にする場合は `[alt_names]` セクションに受け付けるホスト名を記していきます。
IP が固定でグローバルIPなどで直接アクセスされるケースが想定されるなら、 `IP.2 = x.x.x.x` のように追加することもできます。

次に、リクエストを受け付けるアプリケーションと Ingress を作成します

```yaml
kind: Pod
apiVersion: v1
metadata:
  name: foo-app
  labels:
    app: foo
spec:
  containers:
  - name: foo-app
    image: hashicorp/http-echo:0.2.3
    args:
    - "-text=foo"
---
kind: Service
apiVersion: v1
metadata:
  name: foo-service
spec:
  selector:
    app: foo
  ports:
  # Default port used by the image
  - port: 5678
---
kind: Pod
apiVersion: v1
metadata:
  name: bar-app
  labels:
    app: bar
spec:
  containers:
  - name: bar-app
    image: hashicorp/http-echo:0.2.3
    args:
    - "-text=bar"
---
kind: Service
apiVersion: v1
metadata:
  name: bar-service
spec:
  selector:
    app: bar
  ports:
  # Default port used by the image
  - port: 5678
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: example-ingress
spec:
  tls:
  - hosts:
    - echo.info
    secretName: echo-tls
  rules:
  - host: echo.info 
    http:
      paths:
      - pathType: Prefix
        path: "/foo"
        backend:
          service:
            name: foo-service
            port:
              number: 5678
      - pathType: Prefix
        path: "/bar"
        backend:
          service:
            name: bar-service
            port:
              number: 5678
---
```

echo の Pod は Deployment にしても構いません。
Ingress の TLS の設定はホスト単位で行うことができます。
証明書をホストごとに変える場合も単一の Ingress リソースで制御可能です。

```yaml
spec:
  tls:
  - hosts:
    - echo.info
    secretName: echo-tls
```

よくあるパターンは cert-manager という証明書管理の OSS を使用して、Let's Encrypt により発行された証明書などを Ingress でホスティングするケースがあります。
GKE では GCP が署名してくれた証明書を使うこともあるので用途によって使い分けましょう。

実際にサービスを公開する上で現代において TLS 化は必須です。GCP において Cloud Run や App Engine などを使う場合は自動的に TLS 終端を行ってくれるのであまり意識することはないですが、重要な知識ですので頭の片隅に入れておきましょう

## Ingress の実装について
今回は Ingerss Nginx を自前でデプロイしたので TLS 終端を行なっているのは Ingress Nginx の Pod　となります。
GKE などでは Ingress を作成すると GCLB やその他 Firewall のリソースが GKE 外部に作成され、TLS 終端や L7 のロードバランシングは GCLB が担うことになります。

Ingress の実装はクラウドプロバイダごとに異なるので運用する際はトラブルシューティングを見越して、あらかじめどのリソースがクラウド上に作成されるかなどはチェックしておいたほうが良いでしょう。

</div></details>
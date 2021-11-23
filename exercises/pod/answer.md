<details><summary>問題1</summary><div>
Pod のマニフェストは以下のようになります。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: foobar
spec:
  containers:
  - image: busybox
    imagePullPolicy: IfNotPresent
    name: foo
    command:
    - sh
    - -c
    - "echo foo; sleep infinity"
  - image: busybox
    imagePullPolicy: IfNotPresent
    name: bar
    command:
    - sh
    - -c
    - "echo bar; sleep infinity"
```

`spec.containers[].command` で複数コマンドや引数を1行に書きたい場合などは `sh -c` による指定でが便利です。
しかし、distroless など軽量イメージには shell もないイメージがあるので必ずしも使える手法ではないので注意しましょう。

また、`comamnd` に `sh -c` だけ指定し、`args` にそれ以降の引数を指定することも可能です

### distroless イメージについて
Kubernetes 上で動作する CloudNative なエコシステムの数々はコントロールプレーンのコンテナを distroless イメージにバイナリを配置してイメージサイズを最小限にしているパターンが多いです。
distroless イメージは Google が提供しているイメージで apt や shell といったものも存在しない軽量イメージとなっています。
Go のバイナリなどは基本的にワンバイナリのみで実行できるので distroless イメージと相性が良いです。

とは言っても Ruby や Python などはスクリプト言語なのでランタイムが必要となります。
そういった言語で作成されたアプリケーションをコンテナ化したい場合などは `gcr.io/distroless/python3` といった言語別のイメージも用意されているので是非お試しください。
</div></details>
<details><summary>上級問題1</summary><div>
Pod のマニフェストは下記のようになります

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: box
  name: box
spec:
  initContainers: 
  - args: 
    - /bin/sh 
    - -c 
    - echo -n "Hello, World!" > /work-dir/index.html
    image: busybox 
    name: box 
    volumeMounts: 
    - name: vol 
      mountPath: /work-dir 
  containers:
  - image: nginx
    name: nginx
    ports:
    - containerPort: 80
    volumeMounts: 
    - name: vol 
      mountPath: /usr/share/nginx/html 
  volumes: 
  - name: vol 
    emptyDir: {}
```

`spec.initContainers` で `spec.containers` のコンテナを作成する前に別のコンテナを作成することができます。
`spec.initContainers` は複数指定できますか、initContainers で指定したコンテナ同士の起動順序などは制御ができませんので注意しましょう。

Pod が作成されたあと、別コンテナを作成して curl コマンドで initContainers での処理が反映されてるかをチェックします。
`kubectl run box-text ...` で Pod の IP に直接アクセス可能な別 Pod を建ててチェックしています。Port-forward によるチェックでも構いません。

```sh
kubectl run box-test --image=busybox --restart=Never -it --rm -- /bin/sh -c "wget 192.168.10.1 -q -O-"
kubectl delete po box
```

`kubectl run` コマンドではさくっと Pod を作成してデバッグしたい時に便利ですので覚えておくと良いでしょう。
</div></details>
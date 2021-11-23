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

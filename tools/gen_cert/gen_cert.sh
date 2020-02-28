# see https://istio.io/docs/tasks/traffic-management/ingress/secure-ingress-mount/

# TODO: use .cnf https://gist.github.com/derofim/5d1abf6d3c6244afd969a5ba9b06ae1f

# Create a root certificate and private key to sign the certificate for your services:
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt

# Create a certificate and a private key for httpbin.example.com:
openssl req -out httpbin.example.com.csr -newkey rsa:2048 -nodes -keyout httpbin.example.com.key -subj "/CN=httpbin.example.com/O=httpbin organization"

openssl x509 -req -days 365 -CA example.com.crt -CAkey example.com.key -set_serial 0 -in httpbin.example.com.csr -out httpbin.example.com.crt

# TODO: openssl verify -CAfile httpbin.example.com.key httpbin.example.com.crt
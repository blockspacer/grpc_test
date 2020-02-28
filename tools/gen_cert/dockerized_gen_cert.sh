# see https://loglevel-blog.com/how-to-create-self-signed-certificate-with-openssl-and-docker/

docker run --rm \
  --entrypoint="/bin/bash" \
  -v "$PWD":/home/u/project_copy \
  -w /home/u/project_copy \
  --name cert_gen \
  gaeus:cxx_build_env \
  -c 'pwd ; \
      ls -artlh ; \
      chmod +x gen_cert.sh ; \
      sh ./gen_cert.sh ; \
      ls -artlh '

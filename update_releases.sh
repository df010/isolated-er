cd releases/haproxy-release
git checkout tags/v1.0
bosh create-release --final --tarball

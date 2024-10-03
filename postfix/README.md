Postfix in container `podman`/`docker`
```
podman run --cap-add=NET_ADMIN --device /dev/net/tun  --security-opt label=disable -p $PORT:25 postfix
```
DKIM and ARC keys not generated. You have to do it by yourself also add records to domain
Set smtp server in your email client as `localhost:$PORT`

Postfix in container podman/docker
```
podman run --cap-add=NET_ADMIN --device /dev/net/tun  --security-opt label=disable -p $PORT:25 postfix
```
Set smtp server in your email client as `localhost:$PORT`

Postfix in container
```
podman run  --cap-add=NET_ADMIN --device /dev/net/tun  --security-opt label=disable -p $PORT:25 postfix
```

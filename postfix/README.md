Postfix in container
```
podman run  --cap-add=NET_ADMIN --device /dev/net/tun  --security-opt label=disable -it --rm -p $PORT:25 postfix
```

Postfix in container `podman`/`docker`
```
podman run --cap-add=NET_ADMIN --device /dev/net/tun  --security-opt label=disable -p $PORT:25 postfix \
  opendkim;
  openarc;
  bash tun &
  postfix start ;
  tail -f /var/log/postfix.log
```
DKIM and ARC keys not generated. You have to do it by yourself.<br> Also you have to add records to domain. <br>
Set smtp server in your email client as `localhost:$PORT`

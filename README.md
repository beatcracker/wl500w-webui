# Fixing hardcoded HTTP URLs in ASUS [WL-500W](https://github.com/wl500g/wl500g) web-ui

This allows router's web-ui to be accessed via HTTPS using reverse-proxy like [CloudFlare](https://www.cloudflare.com/).

# Required modifications

## Web-UI

### HTTP URLs in the web-ui files (`*.js` and`*.asp`)

This is done by replacing hardcoded `http://` with combination of `location.protocol` and protocol-relative URLS (`//`).

This repository has two folders:

* `www-lp` - where `location.protocol` is used everywhere.
* `www-pru` - where [protocol-relative URLs](https://www.paulirish.com/2010/the-protocol-relative-url/) (`//`) are used mostly and `location.protocol` is used only when absolutely necessary.

My tests show that both approaches work fine, but in case of issues there is something you can try.

## HTTPD server

I'm too lazy to recompile `httpd` that comes with firmware, so it's binary patching all the way down.

### HTTP URLs

There are `*.cgi` pages that are [served internally](https://github.com/wl500g/wl500g/blob/972cda5f0fcf1bef478b297addab84623f617c95/gateway/httpd/web_ex.c#L124) from `httpd` via HTTP:

```c
websWrite(wp, "<meta http-equiv=\"refresh\" content=\"0; url=http://%s/%s\">\r\n", next_host, url);
```

All we need is to search and replace this string in the `httpd` binary:

	content="0; url=http://%s/%s"

-- with --

	content="0;      url=//%s/%s"


### Multi-user login restriction

Built-in `httpd` server allows web-ui to be accessed only from one IP at time for the sake of "security" ([related discussion](https://bitbucket.org/padavan/rt-n56u/issues/245/login-without-logging-out-on-another)). This doesn't work well with CloudFlare, so [this check](https://github.com/wl500g/wl500g/blob/08b5e24ae9986f41243276239b0d3cd899375479/gateway/httpd/httpd.c#L512-L518) has to be disabled:

```c
if (http_port==server_port && !http_login_check()) {
	inet_ntop(login_ip.family, &login_ip.addr, straddr, sizeof(straddr));
	sprintf(line, "Please log out user %s first or wait for session timeout(60 seconds).", straddr);
	dprintf("resposne: %s \n", line);
	send_error( 200, "Request is rejected", (char*) 0, line);
	return;
}
```

It can be achieved by `NOP`ing conditional jump at file offset `0x2CF0`. Just fill 4 bytes with `0` ([MIPS NOP](http://web.cse.ohio-state.edu/~crawfis/cse675-02/Slides/MIPS%20Instruction%20Set.pdf)) and you're done:

```nasm
.-----------------------------. 
| [0x402ce0] ;[Bm]            | 
| lw v1, -0xfe8(a0)           | 
| lui a0, 0x42                | 
| lw v0, -0xfe4(a0)           | 
| lui s6, 0x42                | 
| beq v1, v0, 0x403064 ;[Bl]  | <- this one!
| sw zero, -0xfec(s6)         | 
`-----------------------------' 
```

# Usage

To use modified files/folder you need to attach properly formatted USB flash drive to your router. This is usually done as a part of [Entware installation](https://github.com/Entware-ng/Entware-ng/wiki).

Since `web-iu` and `httpd` are stored in the readonly file system, the trick is to use [bind mounts](http://unix.stackexchange.com/questions/198590/what-is-a-bind-mount) to override built-in files.

Assuming that you've copied `httpd` to `/opt/sbin/httpd` and files from `web-ui` to `/var/www`:

```shell
mount -o bind /opt/sbin/httpd /usr/sbin/httpd
mount -o bind /opt/var/www /www
killall httpd
```

To remove mounts:

```
killall httpd
umount /usr/sbin/httpd
umount /www
```

To make changes permanent, you need to create shell script and run it from the `cron` at boot.

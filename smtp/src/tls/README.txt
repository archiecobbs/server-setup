You need to install an TLS key and certificate identifying the
SMTP server hostname as configured by the <server> XML tag.

These files must be in PEM format.

You can reuse a web server TLS key/cert if you have one.

Install the files in this directory as:

    tls.key
    tls.crt

If you have intermediate certificates, install them as foobar.crt, etc.


This RPM sets up basic HTTP service on a Linux server using Apache.

The intention is that this RPM would be installed as a base, and then
site-specific customizations would be overlayed via RPMs that include files
in /etc/apache2/conf.d and/or /usr/share/example-web/apache (see below).

The HTTP server is configured as follows:

    Port 80

        /
            Publically available
            Serve static files from /srv/www

        /private
            Redirect to port 443 /private

        Addtional config in /usr/share/example-web/apache/*.port80.include

    Port 443

        /
            Publically available
            Serve static files from /srv/www

        /private
            Protected via one-time password authentication
            Serve static files from /srv/www/private

        Addtional config in /usr/share/example-web/apache/*.port443.include

You must supply the SSL key, certificate, and intermediate certificate:

    src/ssl/web.key - SSL private key
    src/ssl/web.crt - SSL certificate
    src/ssl/int.crt - SSL intermediate certificate (empty file if none)

You can create a new key, CSR (certificate signing request), and optionally self-signed
certificate using the included new-key-and-csr.sh script.

Run `new-key-and-csr.sh --help' for details.

To configure users and one-time passwords for /private access:

    o As root, add a user to the users.txt database and copy the user's OTP key
      into the user's ~/.genkey file where (only) they can read it:

        $ genkey -u username --setup

      This will print out an URL that adds the token to the "Google Authenticator" app.

    o Now the user can run this command to generate a current one-time password:

        $ genkey

    o Or as root, run this command to generate the current one-time password for any user:

        $ genkey -u username

    o Finally, as any normal user, run this command to set your PIN:

        $ setpin

    o Or as root, run this command to set any user's PIN:

        $ setpin -u username


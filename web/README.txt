This RPM sets up basic HTTP service on a Linux server using Apache.

The intention is that this RPM would be installed as a base, and then
site-specific customizations would be overlayed via RPMs that include files
in /etc/apache2/conf.d and/or /usr/share/example-web/apache (see below).

The HTTP server is configured as follows:

    Port 80

        /
            Redirects all requests to port 443

        Addtional config in /usr/share/example-web/apache/*.port80.include

    Port 443

        /
            Publically available
            Serve static files from /srv/www

        /private
            Protected via one-time password authentication
            Serve static files from /srv/www/private

        Addtional config in /usr/share/example-web/apache/*.port443.include

This is setup to use Let's Encrypt for obtaining an SSL Certificate.

To setup SSL:

    o Install the "certbot" package.

    o Verify settings in ../build.properties are correct.

    o Build and install this RPM normally. A fake SSL certificate will be installed,
      but this will get the server up and running so you can use certbot's built-in
      "webroot" module to install a real one.

    o Run "ant certs" to issue a new certificate, then rebuild and reinstall package.

    o Set a reminder every 80 days to run "ant certs" to renew your certificate,
      rebuild, and reinstall package.

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

    o Then you login to the web server using your username and a password consisting of your
      PIN and the OTP from Google Authenticator or genkey concatenated (in that order).


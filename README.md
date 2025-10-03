# server-setup
Miscellaneous RPMs useful for setting up openSUSE server(s) for various tasks.

These RPMs are helpful when trying to operationally bootstrap a new venture.
The idea is you would fork this repository and customize as needed.

RPM summary:

    developer
        Meta-RPM that pulls in various other RPMs needed by developers.

    rpm-repo
        Creates an RPM repository for publishing and distributing custom software.
        Makes the repository available via a password-protected HTTPS URL.

    git-repos
        Creates a directory for git repositories with UNIX group access control
        and a script for creating new ones.

    rpm-scripts
        Contains a shell script defining shell functions that are handy for use
        by other RPM scriptlets.

    smtp
        SMTP email router, supporting TLS, multiple domains, aliases,
        and mailing lists. Configured via an XML routing file.

    sshd
        SSH daemon hardening. Disables password auth, root login, etc.

    system
        Configures a few system level things such as NTP, timezone, and bash prompt.
        Also pulls in other RPMs like traceroute.

    tomcat
        Installs tomcat for Java web application service.

    users
        Automatically creates and maintains user accounts with defined permissions.
        Configured via an XML file.

    web
        Installs and configures Apache web server with basic service on port 80
        and SSL on port 443, including a /private intranet protected with two-factor
        authentication.

To get started:

* Customize settings by editing `build.properties`
* Install some packages:
```
    $ zypper -v in ant ant-contrib apache2-utils apache-ivy \
        createrepo_c git libxslt-tools openssl rpm-build saxon10
    $ update-alternatives --set jaxp_transform_impl /usr/share/java/saxon10.jar
```
  * Install RPM scripts:
```
    $ ( cd rpm-scripts && ant -Dnosign=true install )
```
  * Create your RPM package signing key:
```
    $ cd rpm-repo
    $ ant
    # Follow instructions in error message to create signing key
    $ ant install
```
  * Import your RPM package signing key:
```
    $ rpm --import /usr/share/*-zypper-repos/*-repo.key
```
  * Configure and install your users:
```
    $ cd ../users
    $ vi users/src/xml/accounts.xml
    $ ant install
```
  * Pick and choose what other RPMs you'd like, then build, install and/or publish to RPM repo

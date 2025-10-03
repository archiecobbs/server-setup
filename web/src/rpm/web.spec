#
# Requires:
#   scm_revision
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#   web_hostname
#   publicroot
#   basedir
#

# apache stuff
%define pkgdir      %{_datadir}/%{name}
%define apachedir   %{_sysconfdir}/apache2
%define listenconf  %{apachedir}/listen.conf
%define apconfig    %{_sysconfdir}/sysconfig/apache2
%define apconfdir   %{apachedir}/conf.d
%define sslfiledir  %{pkgdir}/ssl
%define sslcrtfile  %{sslfiledir}/ssl.crt
%define sslkeyfile  %{sslfiledir}/ssl.key
%define mydomain    %{org_domain}
%define serveremail support@%{mydomain}
%define servincdir  %{pkgdir}/apache

# log files
%define logdir      /var/log/apache2
%define publiclog   %{logdir}/access_log

# auth stuff
%define otpdir      %{pkgdir}/otp
%define otpfile     %{otpdir}/users.txt
%define otppinfile  %{otpdir}/pin-htpasswd.txt

# modules
%define apmodules   socache_shmcb rewrite auth_basic auth_digest authn_core authz_core authn_file authn_otp proxy proxy_http proxy_connect evasive24

# Rate limiting with mod_evasive
%define modevconf   %{apconfdir}/mod_evasive.conf
%define maxreqps    25

# exim
%define eximdir     %{_datadir}/%{org_id}-smtp

Name:               %{org_id}-web
Version:            %(echo %{scm_revision} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Setup for Apache (%{osname}%{osrel})
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/
BuildRequires:      xsltproc
Requires:           %{org_id}-web-certs >= %{version}
Requires(post):     %{org_id}-rpm-scripts
Requires(pre):      apache2 >= 2.4.6
Requires:           apache2-mod_authn_otp >= 1.1.5
Requires(post):     apache2-mod_evasive
Requires:           mod_php_any
Requires:           system-user-mail

%description
%{summary}.

%clean
rm -rf %{buildroot}

%prep
rm -rf %{buildroot}
%setup -c

%build
subst()
{
    sed -r \
        -e 's|@accessconf@|%{accessconf}|g' \
        -e 's|@apconfdir@|%{apconfdir}|g' \
        -e 's|@datadir@|%{_datadir}|g' \
        -e 's|@mydomain@|%{mydomain}|g' \
        -e 's|@org_name@|%{org_name}|g' \
        -e 's|@org_id@|%{org_id}|g' \
        -e 's|@otpfile@|%{otpfile}|g' \
        -e 's|@otppinfile@|%{otppinfile}|g' \
        -e 's|@publiclog@|%{publiclog}|g' \
        -e 's|@publicroot@|%{publicroot}|g' \
        -e 's|@serveremail@|%{serveremail}|g' \
        -e 's|@servincdir@|%{servincdir}|g' \
        -e 's|@sslfiledir@|%{sslfiledir}|g' \
        -e 's|@sslcrtfile@|%{sslcrtfile}|g' \
        -e 's|@sslkeyfile@|%{sslkeyfile}|g' \
        -e 's|@web_hostname@|%{web_hostname}|g'
}

# Compile utilities
cc -o setpin -Wall -Werror -DOTP_PIN_FILE='"%{otppinfile}"' sources/setpin.c

# Substitute @variables@
subst < scripts/genkey.sh > scripts/genkey
subst < apache/web.conf > apache/%{name}.conf
for FILE in `find private public -type f -exec sh -c 'file {} | grep -qw text' \\; -print`; do
    subst < "${FILE}" > "${FILE}".new
    mv "${FILE}"{.new,}
done

# Generate temporary self-signed cert if needed

# Verify RPM repo key exists
if ! [ -f certbot/live/%{web_hostname}/privkey.pem ]; then
    cat << 'xxEOFxx'

    *****************************************************************************************

    Creating a temporary self-signed SSL key and certificate.

    After installing and starting Apache, run "ant cert" to get a real one.

    *****************************************************************************************
xxEOFxx

    # Generate self-signed certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -subj "/C=US/ST=State/L=City/O=%{org_name}/OU=%{org_name}/CN=%{web_hostname}" \
      -keyout ssl.key -out ssl.crt
else

    # Copy real certificate
    cp certbot/live/%{web_hostname}/privkey.pem     ssl.key
    cp certbot/live/%{web_hostname}/fullchain.pem   ssl.crt
fi

%install

# Public web files
install -d -m 0755 %{buildroot}%{publicroot}
cp -a public/* %{buildroot}%{publicroot}/

# Private web files
cp -a private %{buildroot}%{publicroot}/

# Apache config file
install -d -m 0755 %{buildroot}%{apconfdir}
install -d -m 0755 %{buildroot}%{servincdir}
install -m 0644 apache/%{name}.conf %{buildroot}%{apconfdir}/

# SSL files
install -d -m 0755 %{buildroot}%{sslfiledir}
install -m 0600 ssl.key %{buildroot}%{sslkeyfile}
install -m 0644 ssl.crt %{buildroot}%{sslcrtfile}

# Exim's copy
install -d -m 0755 %{buildroot}%{eximdir}
install -m 0600 ssl.key %{buildroot}%{eximdir}/ssl.key
install -m 0644 ssl.crt %{buildroot}%{eximdir}/ssl.crt

# OTP directory, OTP users file, and encrypted PINs
install -d -m 0755 %{buildroot}%{otpdir}
install -m 0600 /dev/null %{buildroot}%{otpfile}
install -m 0600 /dev/null %{buildroot}%{otppinfile}

# Scripts and utilities
install -d -m 0755 %{buildroot}%{_bindir}
install -m 0755 scripts/genkey %{buildroot}%{_bindir}/genkey
install -m 0755 setpin %{buildroot}%{_bindir}/

%post

# Load handy scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Edit apache config
filevar_set_var %{apconfig} APACHE_SERVER_FLAGS SSL
filevar_set_var %{apconfig} APACHE_SERVERADMIN '%{serveremail}'

# Enable required Apache modules
for MODULE in %{apmodules}; do
    a2enmod -q "${MODULE}" || a2enmod "${MODULE}"
done

# Tweak mod_evasive params
sed_patch_file '%{modevconf}' -r 's/^([[:space:]]*DOSPageCount[[:space:]]+)[0-9]+[[:space:]]*$/\1%{maxreqps}/g'

# Enable and reload apache
systemctl enable apache2.service
systemctl try-restart apache2.service

%files
%defattr(644,root,root,755)
%{apachedir}/conf.d/%{name}.conf
%dir %{servincdir}
%dir %attr(700,wwwrun,www) %{otpdir}
%dir %{pkgdir}
%{publicroot}/*
%attr(644,mail,mail) %{eximdir}/ssl.crt
%attr(400,mail,mail) %{eximdir}/ssl.key
%attr(600,wwwrun,www) %config(noreplace) %{otpfile}
%attr(640,root,www) %config(noreplace) %{otppinfile}
%attr(755,root,root) %{_bindir}/genkey
%attr(4755,root,root) %{_bindir}/setpin

%package        certs
Summary:        %{org_name} SSL certificates
Group:          System/Setup
Buildarch:      noarch

%description certs
%{summary}.

%post certs

# Reload Apache
if systemctl -q is-active apache2.service; then
    systemctl reload-or-try-restart apache2.service
fi

%files certs
%attr(755,root,root) %dir %{sslfiledir}
%attr(600,root,root) %{sslkeyfile}
%attr(644,root,www) %{sslcrtfile}

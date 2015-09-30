#
# Requires:
#   gitrev
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#

# apache stuff
%define pkgdir      %{_datadir}/%{name}
%define apachedir   %{_sysconfdir}/apache2
%define apconfig    %{_sysconfdir}/sysconfig/apache2
%define apconfdir   %{apachedir}/conf.d
%define publicroot  /srv/www
%define privateroot /srv/www-private
%define ssldir      %{pkgdir}/ssl
%define sslcrtfile  %{ssldir}/ssl.crt
%define sslkeyfile  %{ssldir}/ssl.key
%define sslintfile  %{ssldir}/intermediate.crt
%define mydomain    %{org_domain}
%define serveremail support@%{mydomain}
%define servincdir  %{pkgdir}/apache

# log files
%define logdir      /var/log/apache2
%define logrotdir   %{_sysconfdir}/logrotate.d
%define publiclog   %{logdir}/access_log
%define privatelog  %{logdir}/access_log_private

# auth stuff
%define otpdir      %{pkgdir}/otp
%define otpfile     %{otpdir}/users.txt
%define otppinfile  %{otpdir}/pin-htpasswd.txt

# modules
%define apmodules   socache_shmcb proxy proxy_http rewrite
%define opapmodules %{apmodules} auth_basic auth_digest authn_core authz_core authn_file authn_otp

Name:               %{org_id}-web
Version:            %(echo %{gitrev} | tr - .)
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
Requires(post):     %{org_id}-rpm-scripts
Requires(pre):      apache2 >= 2.4.6
Requires:           apache2-mod_authn_otp >= 1.1.5

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
        -e 's|@privatelog@|%{privatelog}|g' \
        -e 's|@privateroot@|%{privateroot}|g' \
        -e 's|@publiclog@|%{publiclog}|g' \
        -e 's|@publicroot@|%{publicroot}|g' \
        -e 's|@serveremail@|%{serveremail}|g' \
        -e 's|@servincdir@|%{servincdir}|g' \
        -e 's|@sslcrtfile@|%{sslcrtfile}|g' \
        -e 's|@sslintfile@|%{sslintfile}|g' \
        -e 's|@sslkeyfile@|%{sslkeyfile}|g'
}

# Compile utilities
cc -o setpin -Wall -Werror -DOTP_PIN_FILE='"%{otppinfile}"' sources/setpin.c
cc -o genotpurl -Wall -Werror sources/genotpurl.c

# Substitute @variables@
subst < scripts/genkey.sh > scripts/genkey
subst < apache/web.conf > apache/%{name}.conf
subst < logrotate/web > logrotate/%{name}
for FILE in `find private public -type f -exec sh -c 'file {} | grep -qw text' \\; -print`; do
    subst < "${FILE}" > "${FILE}".new
    mv "${FILE}"{.new,}
done

# Create emtpy intermediate file if none exists
touch ssl/int.crt

%install

# Public web files
install -d -m 0755 %{buildroot}%{publicroot}
cp -a public/* %{buildroot}%{publicroot}/

# Private web files
install -d -m 0755 %{buildroot}%{privateroot}
cp -a private/* %{buildroot}%{privateroot}/

# Apache config file
install -d -m 0755 %{buildroot}%{apconfdir}
install -d -m 0755 %{buildroot}%{servincdir}
install -m 0644 apache/%{name}.conf %{buildroot}%{apconfdir}/

# SSL files
install -d -m 0755 %{buildroot}%{ssldir}
install -m 600 ssl/web.key %{buildroot}%{sslkeyfile}
install ssl/web.crt %{buildroot}%{sslcrtfile}
install ssl/int.crt %{buildroot}%{sslintfile}

# logrotate files
install -d -m 0755 %{buildroot}%{logrotdir}
install -m 0644 logrotate/%{name} %{buildroot}%{logrotdir}/

# OTP directory, OTP users file, and encrypted PINs
install -d -m 0755 %{buildroot}%{otpdir}
install -m 0600 /dev/null %{buildroot}%{otpfile}
install -m 0600 /dev/null %{buildroot}%{otppinfile}

# Scripts and utilities
install -d -m 0755 %{buildroot}%{_bindir}
install -m 0755 scripts/genkey %{buildroot}%{_bindir}/genkey
install -m 0755 setpin genotpurl %{buildroot}%{_bindir}/

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

# Enable and reload apache
systemctl enable apache2.service
systemctl try-restart apache2.service

%files
%defattr(644,root,root,755)
%{apachedir}/conf.d/%{name}.conf
%dir %{servincdir}
%dir %attr(700,wwwrun,www) %{otpdir}
%dir %{pkgdir}
%{logrotdir}/*
%{privateroot}
%{publicroot}/*
%dir %{ssldir}
%{sslcrtfile}
%{sslintfile}
%attr(400,wwwrun,www) %{sslkeyfile}
%attr(600,wwwrun,www) %config(noreplace) %{otpfile}
%attr(640,root,www) %config(noreplace) %{otppinfile}
%attr(755,root,root) %{_bindir}/genkey
%attr(4755,root,root) %{_bindir}/setpin
%attr(755,root,root) %{_bindir}/genotpurl


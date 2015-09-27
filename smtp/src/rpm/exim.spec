
#
# Requires:
#   gitrev
#   osname
#   osrel
#   org_id
#   org_name
#   org_domain
#

%define pkgdir      %{_datadir}/%{name}
%define eximconf    %{_sysconfdir}/exim/exim.conf

# Required version
%define eximver     4.80

Name:               %{org_id}-smtp
Version:            %(echo %{gitrev} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Setup for EXIM  (%{osname}%{osrel})
Group:              System/Setup
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
Source0:            source.zip
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/
BuildRequires:      xmlstarlet
Requires(post):     exim >= %{eximver}
Requires(post):     %{org_id}-rpm-scripts

%description
%{summary}.

%prep
%setup -c

%build

xmlfind()
{
    xml sel -T -t -m "${1}" -v "${2}" -nl xml/routing.xml
}

# Build root's .forward file
xmlfind "/routing/users/user[@name = /routing/root/@user]" "@email" > root-forward

# Build exim main config snippet
printf '\n' > exim-main
printf 'qualify_domain = %%s\n' "`xmlfind /routing/local @domain`" >> exim-main
if [ -s tls/tls.key -a -s tls/tls.crt ]; then
    printf 'tls_advertise_hosts = *\n' >> exim-main
    printf 'tls_certificate = %%s\n' '%{pkgdir}/tls.crt' >> exim-main
    printf 'tls_privatekey = %%s\n' '%{pkgdir}/tls.key' >> exim-main
fi
NUM_DOMAINS=`xmlfind / 'count(/routing/domain)'`
if [ "${NUM_DOMAINS}" -eq 0 ]; then
    printf 'local_interfaces = 127.0.0.1\n' >> exim-main
fi
printf '\n' >> exim-main

# Build exim auth config snippet
printf '\n' > exim-auth
printf 'PLAIN:\n' >> exim-auth
printf '  driver = plaintext\n' >> exim-auth
printf '  server_set_id = $auth2\n' >> exim-auth
printf '  server_prompts = :\n' >> exim-auth
printf '  server_advertise_condition = ${if def:tls_cipher }\n' >> exim-auth
printf '  server_condition = ${lookup{$auth2}lsearch{%%s}{${if eq{$value}{$auth3}}} {false}}\n' \
  %{pkgdir}/authdb >> exim-auth
printf '\n' >> exim-auth

# Build authentication db
touch authdb
xmlfind "/routing/users/user[@password]" "concat(@name, ' ', @password)" | while read USER PASS; do
    printf '%%s: %s\n' "${USER}" "${PASS}" >> authdb
done

# Generate relay_to_domains list
touch exim-relay_to_domains
FIRST='true'
for DOMAIN in `xmlfind /routing/domain @name`; do
    if [ "${FIRST}" = 'true' ]; then
        FIRST='false'
    else
        printf ' : ' >> exim-relay_to_domains
    fi
    printf '%%s' "${DOMAIN}" >> exim-relay_to_domains
done

# Build exim routers config snippet
touch exim-routers
for DOMAIN in `xmlfind /routing/domain @name`; do
    LABEL="redirect_`echo "${DOMAIN}" | tr . _`"
    printf '\n%%s:\n  domains = %%s\n  driver = redirect\n  allow_fail = true\n  data = ${lookup{$local_part}lsearch{%%s%%s}}\n\n' \
      "${LABEL}" "${DOMAIN}" '%{pkgdir}/aliases-' "${DOMAIN}" \
      >> exim-routers
done

# Build per-domain aliases files
for DOMAIN in `xmlfind /routing/domain @name`; do
    ALIASES="aliases-${DOMAIN}"
    printf '\n# Aliases for domain %%s\n\n' "${DOMAIN}" > "${ALIASES}"

    # Do forwards
    for DEST in `xmlfind "/routing/domain[@name = '${DOMAIN}']/forward" "@name"`; do
        FIRST='true'
        for EMAIL in `xmlfind "/routing/users/user[@name = /routing/domain[@name = '${DOMAIN}']/forward[@name = '${DEST}']/dest/@user]" "@email"`; do
            if [ "${FIRST}" = 'true' ]; then
                printf '%%s:\t' "${DEST}" >> "${ALIASES}"
                FIRST='false'
            else
                printf ', ' >> "${ALIASES}"
            fi
            printf '%%s' "${EMAIL}" >> "${ALIASES}"
        done
        printf '\n' >> "${ALIASES}"
    done

    # Do rejects
    for DEST in `xmlfind "/routing/domain[@name = '${DOMAIN}']/reject" "@name"`; do
        printf '%%s:\t:fail: %%s\n' "${DEST}" "`xmlfind \"/routing/domain[@name = '${DOMAIN}']/reject[@name = '${DEST}']\" message`" >> "${ALIASES}"
    done
done

# Exim hostname snippet
HOSTNAME=`xmlfind /routing/server @hostname`
printf 'primary_hostname = %%s\n' "${HOSTNAME}" > exim-hostname

%install

# Root's .forward file
install -d -m 0755 %{buildroot}/root
install -m 0755 root-forward %{buildroot}/root/.forward

# Exim config snippets
install -d -m 0755 %{buildroot}/%{pkgdir}
install -m 0644 exim-* %{buildroot}/%{pkgdir}/

# Exim auth db
install -m 0600 authdb %{buildroot}/%{pkgdir}/

# Exim aliases files
find . -maxdepth 1 -name 'aliases-*' -print | while read FILE; do
    install -m 0644 "${FILE}" %{buildroot}/%{pkgdir}/
done

# TLS key and cert(s)
install -m 0644 tls/tls.key %{buildroot}/%{pkgdir}/
find tls -name '*.crt' -a -type f -print | while read FILE; do
    cat "${FILE}" >> %{buildroot}/%{pkgdir}/tls.crt
done

%post

# Read scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Config exim
sed_patch_file '%{eximconf}' -r 's/^(domainlist[[:space:]]+relay_to_domains[[:space:]]*=).*$/\1 '"`cat %{pkgdir}/exim-relay_to_domains`"'/g'
cat %{pkgdir}/exim-main     | update_blurb '%{eximconf}' '^# qualify_domain ='      '%{name} main'
cat %{pkgdir}/exim-auth     | update_blurb '%{eximconf}' '^begin authenticators'    '%{name} auth'
cat %{pkgdir}/exim-routers  | update_blurb '%{eximconf}' '^begin routers'           '%{name} routers'
cat %{pkgdir}/exim-hostname | update_blurb '%{eximconf}' '^# primary_hostname ='    '%{name} hostname'

# Enable exim and reload if running
systemctl enable exim.service
systemctl try-restart exim.service

%files
%defattr(0644,root,root,0755)
%attr(0600,mail,mail) %{pkgdir}/tls.key
%attr(0600,mail,mail) %{pkgdir}/authdb
%{pkgdir}
/root/.forward


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

%define tomcatver   7.0.55

%define pkgdir      %{_datadir}/%{name}
%define serverxml   %{_sysconfdir}/tomcat/server.xml
%define contextxml  %{_sysconfdir}/tomcat/context.xml
%define tomcatconf  %{_sysconfdir}/tomcat/tomcat.conf
%define tomcatsysd  %{_sbindir}/tomcat-sysd
%define heappct     70

Name:               %{org_id}-tomcat
Version:            %(echo %{gitrev} | tr - .)
Release:            1.%{osname}%{osrel}
Summary:            %{org_name} Setup for Tomcat (%{osname}%{osrel})
License:            Apache-2.0
Distribution:       %{org_name} Server Setup
BuildRoot:          %{_tmppath}/%{name}-root
Buildarch:          noarch
URL:                http://%{org_domain}/
Requires(post):     %{org_id}-rpm-scripts
Requires:           tomcat >= %{tomcatver}
Requires:           libtcnative-1-0

%description
%{summary}.

%clean
rm -rf %{buildroot}

%post

# Load handy functions
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

# Only listen on the loopback interface
sed_patch_file %{serverxml} -r 's|^([[:space:]]*)(<Connector)( port=".*$)|\1\2 address="127.0.0.1"\3|g'

# Use the NIO connector
sed_patch_file %{serverxml} -r 's|^(.*<Connector.*8080.*protocol=")[^"]+(".*$)|\1org.apache.coyote.http11.Http11NioProtocol\2|g'

# Don't reload on file changes
sed_patch_file %{contextxml} -r 's|^([[:space:]]+)(<WatchedResource.*)$|\1<!-- \2 -->|g'

# Don't persist sessions across restarts
sed_patch_file %{contextxml} -r 's|^([[:space:]]+)(<Manager +pathname="" */>)[[:space:]]*$|\1--> \2 <!--|g'

# Clear work directory on restart
filevar_set_var %{tomcatconf} CLEAR_WORK "true"

# Set various Java runtime properties
CATALINA_OPTS=""

# Calculate %{heappct}% of available memory
TOTAL_MEM=`free -b | sed -nr 's/^Mem:[[:space:]]*([0-9]+).*/\1/gp'`
HEAP_MEM=`expr \( "${TOTAL_MEM}" \* %{heappct} \) / 100`

# Configure max heap
CATALINA_OPTS="${CATALINA_OPTS} -Xmx${HEAP_MEM}"

# Avoid AWT weirdness
CATALINA_OPTS="${CATALINA_OPTS} -Djava.awt.headless=true"

# Apply properties
filevar_set_var %{tomcatconf} CATALINA_OPTS "${CATALINA_OPTS}"

# Ensure stdout/stderr ends up in catalina.out
if [ -f '%{tomcatsysd}' ]; then
    sed_patch_file %{tomcatsysd} -r 's|^( *org.apache.catalina.startup.Bootstrap start)$|\1 \\\
        >> ${CATALINA_BASE}/logs/catalina.out 2>\&1|g'
fi

# Enable tomcat
systemctl -q enable tomcat.service

%files


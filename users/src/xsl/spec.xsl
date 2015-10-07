<?xml version="1.0" encoding="UTF-8"?>

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

<xsl:output method="text" indent="no"/>

<xsl:param name="machine-classes"/>
<xsl:param name="machine-class"/>
<xsl:param name="this"/>

<xsl:template match="accounts"># GENERATED FILE - DO NOT EDIT

# Which machine class am I?
%define machine_class       <xsl:value-of select="$machine-class"/>

# Programs
%define useradd             %{_sbindir}/useradd
%define usermod             %{_sbindir}/usermod
%define userdel             %{_sbindir}/userdel
%define groupadd            %{_sbindir}/groupadd
%define groupdel            %{_sbindir}/groupdel

# UNIX groups
# All users have "_autousers" as their primary group, and are additionally added to "users" as well
# as other groups they are associated with in accounts.xml.
%define users_group         users
%define auto_users_group    _autousers

# Misc files
%define skel_dir            %{_sysconfdir}/skel
%define passwdfile          %{_sysconfdir}/passwd
%define shadowfile          %{_sysconfdir}/shadow
%define groupfile           %{_sysconfdir}/group
%define sudoersdir          %{_sysconfdir}/sudoers.d
%define tmpfile             %{_tmppath}/%{name}
%define hostnamefile        %{_sysconfdir}/HOSTNAME
%define homedir             /home
%define devnull             /dev/null
%define nologin             %{_sbindir}/nologin
%define maildir             %{_var}/spool/mail

Name:                       %{org_id}-users-%{machine_class}
Version:                    %(echo %{gitrev} | tr - .)
Release:                    1
Summary:                    %{org_name} Users RPM for <xsl:value-of select="$machine-class"/> machines
Group:                      System/Setup
License:                    Commercial
Distribution:               %{org_name}
Source0:                    source.zip
BuildRoot:                  %{_tmppath}/%{name}-root
Buildarch:                  noarch
URL:                        http://%{org_domain}/

<xsl:call-template name="machine-class-conflicts">
    <xsl:with-param name="machine-classes" select="$machine-classes"/>
    <xsl:with-param name="machine-class" select="$machine-class"/>
</xsl:call-template>

Requires(pre):              coreutils
Requires(pre):              grep
Requires(pre):              pwdutils
Requires(post):             %{org_id}-rpm-scripts
Requires(post):             sudo
Requires(post):             gawk

Provides:                   <xsl:value-of select="concat($this, ' = %{version}')"/>

%description
This RPM creates, modifies, or deletes users and groups on machines in class `%{machine_class}'.

%clean
rm -rf %{buildroot}

%prep
%setup -c

%install

install -d -m 755 %{buildroot}%{homedir}

<xsl:for-each select="group[privilege/@name = //privilege[@machine-class=$machine-class and (nonShellAccount or restrictedShellAccount or shellAccount)]/@name]">
    <xsl:variable name="groupname" select="@groupname"/>
    <xsl:for-each select="//user[group/@groupname = $groupname]">
cp -a home/<xsl:value-of select="@username"/> %{buildroot}%{homedir}/
    </xsl:for-each>
</xsl:for-each>

%pre

# Slurp in RPM scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

<xsl:call-template name="emit_functions"/>

# Function to create/update a user account.
# Note users may not have passwords - SSH login only
update_account()
{
    U_USERNAME="$1"
    U_GROUPNAME="$2"
    U_SHELL="$3"
    if ! grep -q '^'"${U_USERNAME}"':' %{passwdfile}; then
        if [ ! -d %{homedir}/"${U_USERNAME}" ]; then
            MFLAG="-m"
        else
            MFLAG=""
        fi
        echo "*** Creating account for user ${U_USERNAME}"
        %{useradd} -p '*' -g '%{users_group}' -G "%{auto_users_group},${U_GROUPNAME}" ${MFLAG} -s "${U_SHELL}" "${U_USERNAME}"
    else
        %{usermod} -p '*' -g '%{users_group}' -G "%{auto_users_group},${U_GROUPNAME}" -s "${U_SHELL}" "${U_USERNAME}"
    fi
}

# Function to create/update a group
update_group()
{
    G_NAME="$1"
    if ! grep -q '^'"${G_NAME}"':' %{groupfile}; then
        echo "*** Creating group ${G_NAME}"
        %{groupadd} "${G_NAME}"
    fi
}

# Create/update groups and users
update_group '%{auto_users_group}'
generate_account_list | while read USERNAME GROUPNAME USERSHELL; do

    # Create groups
    for _GROUPNAME in `echo ${GROUPNAME}|tr ',' ' '`; do
        update_group "${_GROUPNAME}"
    done

    # Create account
    update_account "${USERNAME}" "${GROUPNAME}" "${USERSHELL}"

    # Add account to additional UNIX groups
    generate_unixgroup_list "${USERNAME}" | while read _GROUPNAME; do
        update_group "${_GROUPNAME}"
        %{usermod} -a -G "${_GROUPNAME}" "${USERNAME}"
    done
done

%post

# Slurp in RPM scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

<xsl:call-template name="emit_functions"/>

# Generate sudoers file
SUDOERS_FILE='%{sudoersdir}/%{name}'
cp %{devnull} "${SUDOERS_FILE}"
<xsl:for-each select="privilege[@machine-class=$machine-class and sudo and @name = //group/privilege/@name]">
    <xsl:variable name="privname" select="@name"/>
# Privilege "<xsl:value-of select="$privname"/>"
if grep -qE '<xsl:value-of select="@hosts"/>' %{hostnamefile}; then
    echo '<xsl:for-each select="//group[privilege[@name = $privname]]">
        <xsl:sort select="@groupname"/>
        <xsl:if test="not(position() = 1)">,</xsl:if>
        <xsl:value-of select="'&#37;'"/><xsl:value-of select="@groupname"/>
    </xsl:for-each>
    <xsl:value-of select="'&#9;ALL=(ALL) NOPASSWD:'"/>
    <xsl:for-each select="sudo">
        <xsl:if test="not(position() = 1)">,</xsl:if>
        <xsl:value-of select="concat(' ', .)"/>
    </xsl:for-each>' &gt;&gt; "${SUDOERS_FILE}"
fi
</xsl:for-each>
chmod 0440 "${SUDOERS_FILE}"

# Remove users who no longer have accounts
TEMPFILE="%{tmpfile}.$$"
generate_account_list &gt; "${TEMPFILE}"
remove_old_users "${TEMPFILE}"
rm -f "${TEMPFILE}"

%postun

# Slurp in RPM scripts
. %{_datadir}/%{org_id}-rpm-scripts/rpm-scripts '%{name}' '%{version}' '%{release}'

<xsl:call-template name="emit_functions"/>

if [ $1 = 0 ]; then

    # Remove sudoers files
    rm -f '%{sudoersdir}/%{name}'

    # Remove all users in group %{auto_users_group}
    remove_old_users /dev/null

    # Remove groups we created
    remove_group '%{auto_users_group}'
    generate_account_list | while read USERNAME GROUPNAME USERSHELL; do
        remove_group "${GROUPNAME}"
    done
fi

%files
%defattr(0644,root,root,755)
<xsl:for-each select="group[privilege/@name = //privilege[@machine-class=$machine-class and (nonShellAccount or restrictedShellAccount or shellAccount)]/@name]">
    <xsl:variable name="groupname" select="@groupname"/>
    <xsl:for-each select="//user[group/@groupname = $groupname]">
%attr(-, <xsl:value-of select="@username"/>, %{users_group}) %{homedir}/<xsl:value-of select="@username"/>
    </xsl:for-each>
</xsl:for-each>

</xsl:template>

<!-- Emits shell functions -->
<xsl:template name="emit_functions">

# Function to print list of valid user accounts, groups, and shells to stdout
generate_account_list()
{
    <xsl:for-each select="//user[group/@groupname = //group[privilege/@name = //privilege[@machine-class=$machine-class and (nonShellAccount or restrictedShellAccount or shellAccount)]/@name]/@groupname]">
        <xsl:call-template name="get_user_shell"/>
    if [ "${USER_SHELL}" != "" ]; then
    echo '<xsl:value-of select="@username"/>' '<xsl:for-each select="group"><xsl:value-of select="@groupname"/>
<xsl:if test="position() != last()">,</xsl:if></xsl:for-each>' "${USER_SHELL}"
    fi
    </xsl:for-each>
}

# Function to list additional UNIX groups for each user account (assuming account exists)
generate_unixgroup_list()
{
    <xsl:value-of select="'case &quot;$1&quot; in&#10;'"/>
    <xsl:for-each select="//user">
    <xsl:variable name="user" select="."/>
        <xsl:value-of select="concat('    ', $user/@username, ')&#10;')"/>
        <xsl:for-each select="//group[@groupname = $user/group/@groupname]">
        <xsl:variable name="group" select="."/>
        <xsl:for-each select="//privilege[@name = $group/privilege/@name]">
        <xsl:variable name="privilege" select="."/>
            <xsl:for-each select="$privilege[@machine-class=$machine-class]/unixGroup">
                <xsl:value-of select="concat('        echo &quot;', @name, '&quot;&#10;')"/>
            </xsl:for-each>
        </xsl:for-each>
        </xsl:for-each>
        <xsl:value-of select="'        ;;&#10;'"/>
    </xsl:for-each>
    <xsl:value-of select="'    esac&#10;'"/>
}

# Function to remove a group
remove_group()
{
    G_NAME="${1}"
    if grep -q '^'"${G_NAME}"':' %{groupfile}; then
        echo "*** Removing group ${G_NAME}"
        %{groupdel} "${G_NAME}" 2&gt;%{devnull} || true
    fi
}

# Function to remove users not listed in first argument (users file, as output from generate_account_list())
remove_old_users()
{
    USERS_FILE="${1}"

    # Delete any users in group %{auto_users_group} who no longer have accounts
    grep "^%{auto_users_group}:" %{groupfile} | awk -F: '{ printf "%%s,", $4 }' | while read -d, USERNAME; do

        # Sanity check
        if [ -z "${USERNAME}" ]; then
            continue
        fi

        # Is user still here?
        if grep -qE '^'"${USERNAME}"' ' "${USERS_FILE}"; then
            continue
        fi

        # Remove account
        echo "*** Removing account for user ${USERNAME}"
        %{userdel} "${USERNAME}" 2&gt;%{devnull} || true

        # Remove home directory if empty, otherwise chown to root
        HOMEDIR="%{homedir}/${USERNAME}"
        if diff -urq \
          --exclude=.bash_history \
          --exclude=.bashrc \
          --exclude=.emacs \
          --exclude=.inputrc \
          --exclude=.profile \
          --exclude=.ssh \
          --exclude=.vimrc \
          %{skel_dir} "${HOMEDIR}" &gt;%{devnull}; then
            echo "*** Removing empty homedir for user ${USERNAME}"
            rm -rf "${HOMEDIR}"
        else
            echo "*** NOTE: user ${USERNAME} left a non-empty homedir (will be owned by root)"
            chown -R root:root ${HOMEDIR}
        fi

        # Remove mail file, if nay
        if [ -s "%{maildir}/${USERNAME}" ]; then
            echo "*** NOTE: user ${USERNAME} left a non-empty mailbox (will be owned by root)"
            chown -R root:root "%{maildir}/${USERNAME}"
        else
            rm -f "%{maildir}/${USERNAME}"
        fi
    done
}

</xsl:template>

<!-- Determines the user's shell (if any) via inline emitted code -->
<xsl:template name="get_user_shell">
<xsl:variable name="user" select="."/>
    # Determine shell account for user <xsl:value-of select="@username"/>
    USER_SHELL=""
<xsl:for-each select="//privilege[@machine-class=$machine-class and nonShellAccount and @name = //group[@groupname = $user/group/@groupname]/privilege/@name]">    if grep -qE '<xsl:value-of select="@hosts"/>' /etc/HOSTNAME; then USER_SHELL="/sbin/nologin"; fi
</xsl:for-each>
<xsl:for-each select="//privilege[@machine-class=$machine-class and restrictedShellAccount and @name = //group[@groupname = $user/group/@groupname]/privilege/@name]">    if grep -qE '<xsl:value-of select="@hosts"/>' /etc/HOSTNAME; then USER_SHELL="/usr/bin/rbash"; fi
</xsl:for-each>
<xsl:for-each select="//privilege[@machine-class=$machine-class and shellAccount and @name = //group[@groupname = $user/group/@groupname]/privilege/@name]">    if grep -qE '<xsl:value-of select="@hosts"/>' /etc/HOSTNAME; then USER_SHELL="/bin/bash"; fi
</xsl:for-each>

</xsl:template>

<!-- Generate RPM conflicts line -->
<xsl:template name="machine-class-conflicts">
    <xsl:param name="machine-classes"/>
    <xsl:param name="machine-class"/>
    <xsl:if test="not($machine-classes = '')">
        <xsl:variable name="prefix" select="'Conflicts:                  '"/>
        <xsl:choose>
            <xsl:when test="contains($machine-classes, ',')">
                <xsl:if test="not(substring-before($machine-classes, ',') = $machine-class)">
                    <xsl:value-of select="concat($prefix, $this, '-', substring-before($machine-classes, ','), '&#10;')"/>
                </xsl:if>
            </xsl:when>
            <xsl:otherwise>
                <xsl:if test="not($machine-classes = $machine-class)"> 
                    <xsl:value-of select="concat($prefix, $this, '-', $machine-classes, '&#10;')"/>
                </xsl:if>
            </xsl:otherwise>
        </xsl:choose>
        <xsl:call-template name="machine-class-conflicts">
            <xsl:with-param name="machine-classes" select="substring-after($machine-classes, ',')"/>
            <xsl:with-param name="machine-class" select="$machine-class"/>
        </xsl:call-template>
    </xsl:if>
</xsl:template>

</xsl:transform>

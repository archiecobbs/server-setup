<?xml version="1.0" encoding="utf-8"?>

<xsl:transform version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:output method="html" indent="yes" encoding="utf-8" media-type="text/html"/>

    <xsl:template match="/accounts">
        <html>
            <head>
                <title>Accounts Overview</title>
            </head>
            <body>

                <b>Accounts Overview</b><br/>
                <hr/>

                <xsl:for-each select="machine-class">

                    <table cellspacing="0" cellpadding="3" border="1" width="100%">
                        <tr><td bgcolor="#ff99cc">&#160;Machine Class <code><xsl:value-of select="@name"/></code></td></tr>
                    </table>
                    <br/>

                    <xsl:call-template name="privileges">
                        <xsl:with-param name="machine.class" select="@name"/>
                    </xsl:call-template>

                    <xsl:call-template name="users">
                        <xsl:with-param name="machine.class" select="@name"/>
                    </xsl:call-template>

                    <xsl:call-template name="users-with-privilege">
                        <xsl:with-param name="machine.class" select="@name"/>
                    </xsl:call-template>

                </xsl:for-each>

            </body>
        </html>
    </xsl:template>

    <xsl:template name="users">
        <xsl:param name="machine.class"/>
        <b><u>Privileges by user for machines in class <code><xsl:value-of select="$machine.class"/></code></u></b>
        <blockquote>
            <table cellspacing="0" cellpadding="2" border="1">
                <tr>
                    <th bgcolor="#ccffff">User</th>
                    <th bgcolor="#ffcc33">Privileges</th>
                </tr>
                <xsl:for-each select="//user[group[@groupname = //group[privilege[@name = //privilege[@machine-class = $machine.class]/@name]]/@groupname]]">
                    <xsl:sort select="@username"/>
                    <xsl:variable name="user" select="."/>
                    <tr>
                        <td bgcolor="#ccffff" valign="top" align="center"><code><xsl:value-of select="@username"/></code></td>
                        <td bgcolor="#ffcc33" align="center">
                            <xsl:for-each select="//privilege[@machine-class = $machine.class]">
                                <xsl:sort select="@name"/>
                                <xsl:variable name="privname" select="@name"/>
                                <xsl:choose>
                                    <xsl:when test="$user/group[@groupname = //group[privilege/@name = $privname]/@groupname]">
                                        <a>
                                            <xsl:attribute name="href">
                                                <xsl:value-of select="concat('#privilege-', @name)"/>
                                            </xsl:attribute>
                                            <xsl:value-of select="@name"/>
                                        </a>
                                        <br/>
                                    </xsl:when>
                                </xsl:choose>
                            </xsl:for-each>
                        </td>
                    </tr>
                </xsl:for-each>
            </table>
        </blockquote>
    </xsl:template>

    <xsl:template name="privileges">
        <xsl:param name="machine.class"/>
        <b><u>Privilege Definitions for machines in class <code><xsl:value-of select="$machine.class"/></code></u></b>
        <blockquote>
            <table cellspacing="0" cellpadding="2" border="1">
                <tr>
                    <th bgcolor="#ffcc33">Privilege</th>
                    <th>Hosts</th>
                    <th>Account Type</th>
                    <th>Groups</th>
                    <th>Sudo Commands</th>
                </tr>
                <xsl:for-each select="//privilege[@machine-class = $machine.class]">
                    <xsl:sort select="@name"/>
                    <a>
                        <xsl:attribute name="name">
                            <xsl:value-of select="concat('privilege-', @name)"/>
                        </xsl:attribute>
                    </a>
                    <tr>
                        <td align="center" bgcolor="#ffcc33"><xsl:value-of select="@name"/></td>
                        <xsl:choose>
                            <xsl:when test="@hosts = '.*'">
                                <td align="center"><i>All</i></td>
                            </xsl:when>
                            <xsl:otherwise>
                                <td align="center"><code><xsl:value-of select="@hosts"/></code></td>
                            </xsl:otherwise>
                        </xsl:choose>
                        <xsl:choose>
                            <xsl:when test="shellAccount">
                                <td align="center">Shell</td>
                            </xsl:when>
                            <xsl:when test="nonShellAccount">
                                <td align="center">Non-shell</td>
                            </xsl:when>
                            <xsl:when test="restrictedShellAccount">
                                <td align="center">Restricted Shell</td>
                            </xsl:when>
                            <xsl:otherwise>
                                <td align="center">-</td>
                            </xsl:otherwise>
                        </xsl:choose>
                        <td align="center">
                            <xsl:choose>
                                <xsl:when test="unixGroup">
                                    <code>
                                        <xsl:for-each select="unixGroup">
                                            <xsl:value-of select="@name"/>
                                            <br/>
                                        </xsl:for-each>
                                    </code>
                                </xsl:when>
                                <xsl:otherwise>
                                    <td>-</td>
                                </xsl:otherwise>
                            </xsl:choose>
                        </td>
                        <td align="center">
                            <xsl:choose>
                                <xsl:when test="sudo = 'ALL'">
                                    <font color="#cc3333"><b>ALL</b></font>
                                </xsl:when>
                                <xsl:when test="sudo">
                                    <code>
                                        <xsl:for-each select="sudo">
                                            <xsl:value-of select="."/>
                                            <br/>
                                        </xsl:for-each>
                                    </code>
                                </xsl:when>
                                <xsl:otherwise>
                                    <td>-</td>
                                </xsl:otherwise>
                            </xsl:choose>
                        </td>
                    </tr>
                </xsl:for-each>
            </table>
        </blockquote>
    </xsl:template>

    <xsl:template name="users-with-privilege">
        <xsl:param name="machine.class"/>
        <b><u>Users by privilege for machines in class <code><xsl:value-of select="$machine.class"/></code></u></b>
        <blockquote>
            <table cellspacing="0" cellpadding="2" border="1">
                <tr>
                    <th bgcolor="#ffcc33">Privilege</th>
                    <th bgcolor="#ccffff">Users</th>
                </tr>
                <xsl:for-each select="//privilege[@machine-class = $machine.class]">
                    <xsl:sort select="@name"/>
                    <xsl:variable name="privname" select="@name"/>
                    <tr>
                        <td bgcolor="#ffcc33" valign="top" align="center">
                            <a>
                                <xsl:attribute name="href">
                                    <xsl:value-of select="concat('privilege-', @name)"/>
                                </xsl:attribute>
                                <xsl:value-of select="@name"/>
                            </a>
                        </td>
                        <td bgcolor="#ccffff" align="center">
                            <xsl:variable name="users" select="//user[group[@groupname = //group[privilege[@name = $privname]]/@groupname]]"/>
                            <xsl:choose>
                                <xsl:when test="not($users)">-</xsl:when>
                                <xsl:otherwise>
                                    <xsl:for-each select="$users">
                                        <xsl:sort select="@username"/>
                                        <code><xsl:value-of select="@username"/></code>
                                        <br/>
                                    </xsl:for-each>
                                </xsl:otherwise>
                            </xsl:choose>
                        </td>
                    </tr>
                </xsl:for-each>
            </table>
        </blockquote>
    </xsl:template>

    <xsl:template match="text()"/>

</xsl:transform>


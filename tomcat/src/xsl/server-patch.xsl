<?xml version="1.0" encoding="UTF-8"?>

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <xsl:template match="Connector">
        <xsl:copy>

            <!-- Copy existing attributes (some will get overridden) -->
            <xsl:apply-templates select="@*"/>

            <!-- Only ever listen on the loopback interface -->
            <xsl:attribute name="address">127.0.0.1</xsl:attribute>

            <!-- On 8080 connector, increase default "maxThreads" setting, and mark as secure -->
            <xsl:if test="@port = '8080'">
                <xsl:attribute name="maxThreads">500</xsl:attribute>
                <xsl:attribute name="secure">true</xsl:attribute>
            </xsl:if>

            <!-- Proceed -->
            <xsl:apply-templates select="node()"/>
        </xsl:copy>
    </xsl:template>

    <!--
        Use "combined" logging pattern for access log, set rotatable="false", and remove suffix
        The latter two changes make things consistent with the configuration in /etc/logrotate.d/tomcat.
    -->
    <xsl:template match="Valve[@className = 'org.apache.catalina.valves.AccessLogValve']/@pattern">
        <xsl:attribute name="pattern">combined</xsl:attribute>
    </xsl:template>
    <xsl:template match="Valve[@className = 'org.apache.catalina.valves.AccessLogValve']/@suffix"/>
    <xsl:template match="Valve[@className = 'org.apache.catalina.valves.AccessLogValve']">
        <xsl:copy>
            <xsl:apply-templates select="@*[name(.) != 'suffix']"/>
            <xsl:attribute name="prefix">access_log</xsl:attribute>
            <xsl:attribute name="rotatable">false</xsl:attribute>
        </xsl:copy>
    </xsl:template>

    <!-- Default copy exactly -->
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

</xsl:transform>

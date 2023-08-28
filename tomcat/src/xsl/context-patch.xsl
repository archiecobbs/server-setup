<?xml version="1.0" encoding="UTF-8"?>

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <!-- Don't reload on file changes -->
    <xsl:template match="WatchedResource">
        <xsl:comment>
            <xsl:value-of select="' &lt;WatchedResource&gt;'"/>
            <xsl:value-of select="."/>
            <xsl:value-of select="'&lt;/WatchedResource&gt; '"/>
        </xsl:comment>
    </xsl:template>

    <!-- Don't persist sessions across restarts -->
    <xsl:template match="Context">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
            <xsl:if test="not(Manager)">
                <xsl:value-of select="'    '"/>
                <Manager pathname=""/>
                <xsl:value-of select="'&#10;'"/>
            </xsl:if>
        </xsl:copy>
    </xsl:template>
    <xsl:template match="comment()[contains(., '&lt;Manager pathname')]"/>

    <!-- Default copy exactly -->
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>

</xsl:transform>

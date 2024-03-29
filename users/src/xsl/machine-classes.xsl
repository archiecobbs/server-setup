<?xml version="1.0" encoding="utf-8"?>

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

    <xsl:output encoding="utf-8" method="text" media-type="text/plain"/>

    <xsl:template match="/">
        <xsl:text># GENERATED FILE - DO NOT EDIT&#10;&#10;</xsl:text>
        <xsl:text>machine.classes=</xsl:text>
        <xsl:for-each select="accounts/machine-class">
            <xsl:if test="position() &gt; 1">,</xsl:if>
            <xsl:value-of select="@name"/>
        </xsl:for-each>
        <xsl:text>&#10;</xsl:text>
    </xsl:template>

</xsl:transform>

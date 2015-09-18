<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

    <xsl:output encoding="ISO-8859-1" method="text" media-type="text/plain"/>

    <xsl:template match="/">
        <xsl:text># GENERATED FILE - DO NOT EDIT&#10;&#10;</xsl:text>
        <xsl:text>machine.classes=</xsl:text>
        <xsl:for-each select="accounts/machine-class">
            <xsl:value-of select="concat(@name, ' ')"/>
        </xsl:for-each>
        <xsl:text>&#10;</xsl:text>
    </xsl:template>

</xsl:transform>

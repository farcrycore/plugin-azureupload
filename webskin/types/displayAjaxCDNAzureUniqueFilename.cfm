<cfparam name="form.filename" type="string">
<cfparam name="form.nameconflict" type="string">
<cfparam name="form.uploadpath" type="string">
<cfparam name="form.location" type="string" default="publicfiles">


<cfset pathWithoutCDNPrefix = form.uploadpath>
<cfset cdnConfig = application.fc.lib.cdn.getLocation("#form.location#")>
<cfif len(cdnConfig.pathPrefix)>
	<cfset pathWithoutCDNPrefix = replace("/#form.uploadpath#", cdnConfig.pathPrefix, "")>
</cfif>

<cfset uniquefilename = "#pathWithoutCDNPrefix#/#form.filename#">
<cfif form.nameconflict eq "makeunique">
	<cfset uniquefilename = application.fc.lib.cdn.ioGetUniqueFilename("#form.location#", uniquefilename)>
</cfif>


<cfset path = uniquefilename />
<cfif len(cdnConfig.pathPrefix) AND left(path, 1) neq "/">
	<cfset path = cdnConfig.pathPrefix & "/" & path />
<cfelseif len(cdnConfig.pathPrefix)>
	<cfset path = cdnConfig.pathPrefix & path />
</cfif>
<cfset path = "/" & cdnConfig.container & "/" & path />

<cfset binaryKey = binaryDecode(cdnConfig.storageKey, "base64")>

<cfset utcDate = dateConvert("local2UTC",now()) />
<cfset xmsDate = dateFormat(utcDate,"ddd, dd mmm yyyy") & " " & timeFormat(utcDate,"HH:mm:ss") & " GMT" />

<cfset xmsVersion = "2017-04-17" />

<cfset canonicalizedResource = "/blob/#cdnConfig.account##path#" />

<cfset signedpermissions = "rw">
<cfset signedexpiry = "2018-04-01T00:00:00Z">

<cfset stringToSign = "#signedpermissions#\n\n#signedexpiry#\n#canonicalizedResource#\n\n\n\n#xmsVersion#\n\n\n\n\n" />

<cfset x = replace(stringToSign,"\n","#chr(10)#","all") />
<cfset y = hmac(x,binaryKey,"HmacSHA256","utf-8") />
<cfset requestSignature = toBase64(binaryDecode(y,"hex")) />


<cfset result = {
	"filename": "#form.filename#",
	"uploadpath": "#form.uploadpath#",
	"uniquefilename": "#listLast(uniquefilename, "/")#",
	"requestURL": "https://#cdnConfig.account#.blob.core.windows.net#path#?sv=2017-04-17&sr=b&sp=#signedpermissions#&se=#encodeForURL(signedexpiry)#&sig=#urlEncodedFormat(requestSignature)#",
	"xmsdate": "#xmsDate#",
	"xmsversion": "#xmsVersion#"
}>

<cfcontent reset="true">
<cfheader name="Content-Type" value="application/json">
<cfoutput>#serializeJSON(result)#</cfoutput>

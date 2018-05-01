<cfcomponent displayname="Azure" hint="Encapsulates file persistence functionality" output="false" persistent="false">

	<cffunction name="init" returntype="any">
		<cfargument name="cdn" type="any" required="true" />
		<cfargument name="engine" type="string" required="true" />

		<cfset var qLeftovers = queryNew("")>

		<cfset this.cdn = arguments.cdn />
		<cfset this.engine = arguments.engine />

		<cfset this.cacheMap = structnew() />

		<cfif directoryExists(getTempDirectory() & application.applicationname)>
			<cfdirectory action="list" directory="#getTempDirectory()##application.applicationname#/azurecache" recurse="true" type="file" name="qLeftovers" />

			<cfloop query="qLeftovers">
				<cffile action="delete" file="#qLeftovers.Directory#/#qLeftovers.name#" />
				<cflog file="azure" text="Init: removed cached file #qLeftovers.Directory#/#qLeftovers.name#">
			</cfloop>
		</cfif>

		<cfreturn this />
	</cffunction>

	<cffunction name="validateConfig" output="false" access="public" returntype="struct" hint="Returns an array of errors. An empty array means there are no no errors">
		<cfargument name="config" type="struct" required="true" />

		<cfset var st = duplicate(arguments.config) />
		<cfset var i = 0 />


		<cfif not structkeyexists(st,"storageKey")>
			<cfset application.fapi.throw(message="no '{1}' value defined",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config)),substituteValues=[ 'storageKey' ]) />
		</cfif>

		<cfif not structkeyexists(st,"account")>
			<cfset application.fapi.throw(message="no '{1}' value defined",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config)),substituteValues=[ 'account' ]) />
		</cfif>

		<cfif not structkeyexists(st,"container")>
			<cfset application.fapi.throw(message="no '{1}' value defined",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config)),substituteValues=[ 'container' ]) />
		</cfif>

		<cfif not structkeyexists(st,"indexable")>
			<cfset st.indexable = false />
		</cfif>

		<cfset st.domainType = "custom" />

		<cfif structkeyexists(st,"security") and not listfindnocase("public,private",arguments.config.security)>
			<cfset application.fapi.throw(message="the '{1}' value must be one of ({2})",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config)),substituteValues=[ 'security', 'public|private' ]) />
		<cfelseif not structkeyexists(st,"security") or st.security eq "public">
			<cfset st.security = "public" />
		</cfif>

		<cfif structkeyexists(st,"pathPrefix")>
			<cfif len(st.pathPrefix) and not left(st.pathPrefix,1) eq "/">
				<cfset st.pathPrefix = "/" & st.pathPrefix />
			</cfif>
			<cfif right(st.pathPrefix,1) eq "/">
				<cfset st.pathPrefix = left(st.pathPrefix,len(st.pathPrefix)-1) />
			</cfif>
		<cfelse>
			<cfset st.pathPrefix = "" />
		</cfif>

		<cfif st.security eq "private" and not structkeyexists(st,"urlExpiry")>
			<cfset application.fapi.throw(message="no 'urlExpiry' value defined for private location",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config))) />
		<cfelseif structkeyexists(st,"urlExpiry") and (not isnumeric(st.urlExpiry) or st.urlExpiry lt 0)>
			<cfset application.fapi.throw(message="the 'urlExpiry' value must be a positive integer",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config))) />
		</cfif>

		<cfif not structkeyexists(st,"localCacheSize")>
			<cfset st["localCacheSize"] = 50 />
		</cfif>

		<cfif structkeyexists(st,"maxAge") and not refind("^\d+$",st.maxAge)>
			<cfset application.fapi.throw(message="the 'maxAge' value must be an integer",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config))) />
		</cfif>

		<cfif structkeyexists(st,"sMaxAge") and not refind("^\d+$",st.sMaxAge)>
			<cfset application.fapi.throw(message="the 'sMaxAge' value must be an integer",type="cdnconfigerror",detail=serializeJSON(sanitiseAzureConfig(arguments.config))) />
		</cfif>

		<cfreturn st />
	</cffunction>


	<cffunction name="getCachedFile" returntype="string" access="public" output="false" hint="Returns the local cache path of a file if available">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfif not arguments.config.localCacheSize
			or not structkeyexists(this.cacheMap,arguments.config.name)
			or not structkeyexists(this.cacheMap[arguments.config.name],arguments.file)>

			<cfreturn "" />
		</cfif>

		<cfif fileExists(this.cacheMap[arguments.config.name][arguments.file].path)>
			<cfset this.cacheMap[arguments.config.name][arguments.file].touch = now() />
			<cfreturn this.cacheMap[arguments.config.name][arguments.file].path />
		<cfelse>
			<cfset structdelete(this.cacheMap[arguments.config.name],arguments.file)>
			<cfreturn "" />
		</cfif>
	</cffunction>

	<cffunction name="addCachedFile" returntype="void" access="public" output="false" hint="Adds a temporary file to the local cache">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="path" type="string" required="true" />

		<cfset var oldest = "" />
		<cfset var oldesttouch = now() />
		<cfset var thisfile = "" />

		<cfif not structkeyexists(this.cacheMap,arguments.config.name)>
			<cfset this.cacheMap[arguments.config.name] = structnew() />
		</cfif>

		<cfif structkeyexists(this.cacheMap[arguments.config.name],arguments.file)
			and this.cacheMap[arguments.config.name][arguments.file].path neq arguments.path
			and fileexists(this.cacheMap[arguments.config.name][arguments.file].path)>

			<cfset removeCachedFile(config=arguments.config,file=arguments.file) />
		</cfif>

		<cfset this.cacheMap[arguments.config.name][arguments.file] = structnew() />
		<cfset this.cacheMap[arguments.config.name][arguments.file].touch = now() />
		<cfset this.cacheMap[arguments.config.name][arguments.file].path = arguments.path />

		<cflog file="#application.applicationname#_azure" text="Added [#arguments.config.name#] #sanitiseAzureURL(arguments.file)# to local cache" />

		<!--- Remove old files --->
		<cfif structcount(this.cacheMap[arguments.config.name]) gte arguments.config.localCacheSize>
			<cfloop collection="#this.cacheMap[arguments.config.name]#" item="thisfile">
				<cfif this.cacheMap[arguments.config.name][thisfile].touch lt oldesttouch>
					<cfset oldest = thisfile />
				</cfif>
			</cfloop>

			<cfset removeCachedFile(config=arguments.config,file=oldest) />
		</cfif>
	</cffunction>

	<cffunction name="removeCachedFile" returntype="void" access="public" output="false" hint="Removes a file from the local cache">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfif structkeyexists(this.cacheMap,arguments.config.name)
			and structkeyexists(this.cacheMap[arguments.config.name],arguments.file)>

			<cfif fileexists(this.cacheMap[arguments.config.name][arguments.file].path)>
				<cftry>
					<cffile action="delete" file="#this.cacheMap[arguments.config.name][arguments.file].path#" />
					<cfcatch>
					</cfcatch>
				</cftry>
			</cfif>

			<cfset structdelete(this.cacheMap[arguments.config.name],arguments.file) />

			<cflog file="#application.applicationname#_azure" text="Removed [#arguments.config.name#] #sanitiseAzureURL(arguments.file)# from local cache" />
		</cfif>
	</cffunction>

	<cffunction name="getTemporaryFile" returntype="string" access="public" output="false" hint="Returns a path for a new temporary file">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfset var tmpfile = "#getTempDirectory()##application.applicationname#/azurecache/#arguments.config.name#/#createuuid()#.#listlast(arguments.file,'.')#" />

		<cfif not directoryExists(getDirectoryFromPath(tmpfile))>
			<cfdirectory action="create" directory="#getDirectoryFromPath(tmpfile)#" mode="774" />
		</cfif>

		<cfreturn tmpfile />
	</cffunction>

	<cffunction name="deleteTemporaryFile" returntype="void" access="public" output="false" hint="Removes the specified temporary file">
		<cfargument name="file" type="string" required="true" />

		<cffile action="delete" file="#arguments.file#" />
		<cflog file="debug" text="deleting #arguments.file# #serializeJSON(application.fc.lib.error.getStack(bIgnoreJava=true))#">
	</cffunction>

	<cffunction name="getURLPath" output="false" access="public" returntype="string" hint="Returns full internal path. Works for files and directories." ref="https://docs.microsoft.com/en-us/azure/storage/common/storage-dotnet-shared-access-signature-part-1">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="method" type="string" required="false" default="GET" />
		<cfargument name="azurePath" type="boolean" required="false" default="false" />
		<cfargument name="protocol" type="string" require="false" />

		<cfset var urlpath = arguments.file />
		<cfset var epochTime = 0 />
		<cfset var signature = "" />
		<cfset var permission = "r" />
		<cfset var binaryKey = "" />

		<cfif not left(urlpath,1) eq "/">
			<cfset urlpath = "/" & urlpath />
		</cfif>

		<cfif NOT left(urlpath,2) eq "//">

			<!--- Prepend account and pathPrefix --->
			<cfset urlpath = "/#arguments.config.container##arguments.config.pathPrefix##urlpath#" />

			<!--- URL encode the filename --->
			<cfset urlpath = replacelist(urlencodedformat(urlpath),"%2F,%2B,%2D,%2E,%5F,%27","/, ,-,.,_,'")>

			<cfif structkeyexists(arguments.config,"security") and arguments.config.security eq "private">
				<cfset expiryDate = dateToRFC3339(d=DateAdd("s", arguments.config.urlExpiry, now()), bMS=false) />

				<cfset binaryKey = binaryDecode(arguments.config.storageKey, "base64") />

				<!--- Create a canonical string to send --->
				<cfset signature = "#permission#\n\n#expiryDate#\n/blob#getCanonicalResource(config=arguments.config, path=replace(urlpath,"%20"," ","all"))#\n\n\n\n2015-04-05\n\n\n\n\n" />

				<!--- Replace "\n" with "chr(10) to get a correct digest --->
				<cfset signature = replace(signature,"\n","#chr(10)#","all") />

				<!--- Encrypt signature --->
				<cfset signature = toBase64(binaryDecode(hmac(signature, binaryKey, "HmacSHA256", "utf-8"), "hex")) />

				<cfset urlpath = urlpath & "?sv=2015-04-05&sr=b&sp=#permission#&se=#replace(expiryDate, ':', '%3A', 'ALL')#&sig=#urlencodedformat(signature)#" />
			</cfif>

			<cfif arguments.config.domainType eq "azure" or arguments.azurePath>
				<cfset urlpath = "//#arguments.config.account#.blob.core.windows.net" & urlpath />
			<cfelse>
				<cfset urlpath = "//" & arguments.config.account & ".blob.core.windows.net" & urlpath />
			</cfif>

		</cfif>

		<cfif structkeyexists(arguments,"protocol")>
			<cfset urlpath = arguments.protocol & ":" & urlpath />
		</cfif>

		<cfreturn urlpath />
	</cffunction>

	<cffunction name="getMeta" output="false" access="public" returntype="struct" hint="Returns a metadata struct for setting Azure metadata">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfset var stResult = structnew() />

		<cfset stResult["content_type"] = this.cdn.getMimeType(arguments.file) />

		<cfif structkeyexists(arguments.config,"maxAge")>
			<cfparam name="stResult.cache_control" default="" />
			<cfset stResult.cache_control = rereplace(listappend(stResult.cache_control,"max-age=#arguments.config.maxAge#"),",([^ ])",", \1","ALL") />
		</cfif>

		<cfif structkeyexists(arguments.config,"sMaxAge")>
			<cfparam name="stResult.cache_control" default="" />
			<cfset stResult.cache_control = rereplace(listappend(stResult.cache_control,"s-maxage=#arguments.config.maxAge#"),",([^ ])",", \1","ALL") />
		</cfif>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="getAbsolutePath" returntype="string" access="public" output="false" hint="Returns the Azure path for the specified file">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfset var path = arguments.file />

		<cfif left(path, 1) neq "/">
			<cfset path = "/" & path />
		</cfif>

		<cfif len(arguments.config.pathPrefix)>
			<cfset path = arguments.config.pathPrefix & path />
		</cfif>

		<cfset path = "/" & arguments.config.container & path />

		<cfreturn path />
	</cffunction>


	<cffunction name="ioFileExists" returntype="boolean" access="public" output="false" hint="Checks that a specified path exists">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="protocol" type="string" require="false" />

		<cfset var stResponse = makeRequest(config=arguments.config, method="HEAD", path=getAbsolutePath(argumentCollection=arguments)) />

		<cfif listfirst(stResponse.statusCode," ") eq "200">
			<!--- file exists --->
			<cfreturn true />
		<cfelseif listfirst(stResponse.statusCode," ") eq "404">
			<!--- file does not exist --->
			<cfreturn false />
		</cfif>

		<cfthrow message="Unexpected reponse: #stResponse.statusCode#" />
	</cffunction>

	<cffunction name="ioGetFileSize" returntype="numeric" output="false" hint="Returns the size of the file in bytes">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfset var stResponse = makeRequest(config=arguments.config, method="HEAD", path=getAbsolutePath(argumentCollection=arguments)) />

		<cfreturn round(stResponse.responseheader["Content-Length"]) />
	</cffunction>

	<cffunction name="ioGetFileLocation" returntype="struct" output="false" hint="Returns serving information for the file - either method=redirect + path=URL OR method=stream + path=local path">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="admin" type="boolean" required="false" default="false" />
		<cfargument name="protocol" type="string" require="false" />

		<cfset var stResult = structnew() />

		<cfset arguments.azurepath = arguments.admin />

		<cfset stResult["method"] = "redirect" />
		<cfset stResult["path"] = getURLPath(argumentCollection=arguments) />
		<cfset stResult["mimetype"] = getPageContext().getServletContext().getMimeType(arguments.file) />

		<cfreturn stResult />
	</cffunction>

	<cffunction name="ioWriteFile" returntype="void" access="public" output="false" hint="Writes the specified data to a file">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="data" type="any" required="true" />
		<cfargument name="datatype" type="string" required="false" default="text" options="text,binary,image" />
		<cfargument name="quality" type="numeric" required="false" default="1" hint="This is only required for image writes" />

		<cfif arguments.datatype eq "image">
			<cfset arguments.data = ImageGetBlob(arguments.data)>
		<cfelseif arguments.datatype eq "text">
			<cfset arguments.data = ToBinary(ToBase64(arguments.data))>
		</cfif>

		<cfset makeRequest(
			config=arguments.config,
			method="PUT",
			path=getAbsolutePath(argumentCollection=arguments),
			headers={
				"Content-Type"=this.cdn.getMimeType(arguments.file),
				"x-ms-meta-AzureSearch_Skip"="true",
				"x-ms-blob-type"="BlockBlob"
			},
			data=arguments.data
		) />

		<cflog file="#application.applicationname#_azure" text="Wrote [#arguments.config.name#] #sanitiseAzureURL(arguments.file)#" />
	</cffunction>

	<cffunction name="ioWriteMetadata" returntype="void" access="public" output="false" hint="Writes the specified data to a file" ref="https://docs.microsoft.com/en-us/rest/api/storageservices/set-blob-metadata">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="metadata" type="struct" required="true" />

		<cfset var key = "" />
		<cfset var headers = {} />

		<cfloop collection="#arguments.metadata#" item="key">
			<cfset headers["x-ms-meta-#key#"] = arguments.metadata[key] />
		</cfloop>

		<cfset makeRequest(
			config=arguments.config,
			method="PUT",
			path=getAbsolutePath(argumentCollection=arguments),
			query={
				"comp" = "metadata"
			},
			headers=headers
		) />

		<cflog file="#application.applicationname#_azure" text="Wrote [#arguments.config.name#] #sanitiseAzureURL(arguments.file)# metadata" />
	</cffunction>

	<cffunction name="ioReadMetadata" returntype="struct" access="public" output="false" hint="Writes the specified data to a file" ref="https://docs.microsoft.com/en-us/rest/api/storageservices/get-blob-metadata">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfset var key = "" />
		<cfset var headers = {} />

		<cfset var stResult = makeRequest(
			config=arguments.config,
			method="GET",
			path=getAbsolutePath(argumentCollection=arguments),
			query={
				"comp" = "metadata"
			},
			bMetadataOnly=true
		) />

		<cfloop collection="#stResult.responseheader#" item="key">
			<cfif reFindNoCase("^x-ms-meta-", key)>
				<cfset headers[mid(key, 11, len(key))] = stResult.responseheader[key] />
			</cfif>
		</cfloop>

		<cfreturn headers />
	</cffunction>

	<cffunction name="ioReadFile" returntype="any" access="public" output="false" hint="Reads from the specified file">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />
		<cfargument name="datatype" type="string" required="false" default="text" options="text,binary,image" />

		<cfset var data = "" />
		<cfset var tmpfile = getCachedFile(config=arguments.config,file=arguments.file) />

		<cftry>

			<cfif len(tmpfile)>

				<!--- Read cache file --->
				<cfswitch expression="#arguments.datatype#">
					<cfcase value="text">
						<cffile action="read" file="#tmpfile#" variable="data" />
					</cfcase>

					<cfcase value="binary">
						<cffile action="readBinary" file="#tmpfile#" variable="data" />
					</cfcase>

					<cfcase value="image">
						<cfset data = imageread(tmpfile) />
					</cfcase>
				</cfswitch>

				<cflog file="#application.applicationname#_azure" text="Read [#arguments.config.name#] #sanitiseAzureURL(arguments.file)# from local cache" />

			<cfelse>

				<cfset tmpfile = getTemporaryFile(config=arguments.config,file=arguments.file) />

				<cfset ioCopyFile(source_config=arguments.config,source_file=arguments.file,dest_localpath=tmpfile) />

				<!--- Read cache file --->
				<cfswitch expression="#arguments.datatype#">
					<cfcase value="text">
						<cffile action="read" file="#tmpfile#" variable="data" />
					</cfcase>

					<cfcase value="binary">
						<cffile action="readBinary" file="#tmpfile#" variable="data" />
					</cfcase>

					<cfcase value="image">
						<cfset data = imageread(tmpfile) />
					</cfcase>
				</cfswitch>

				<cfif arguments.config.localCacheSize>
					<cfset addCachedFile(config=arguments.config,file=arguments.file,path=tmpfile) />
				<cfelse>
					<!--- Delete temporary file --->
					<cfset deleteTemporaryFile(tmpfile) />
				</cfif>

				<cflog file="#application.applicationname#_azure" text="Read [#arguments.config.name#] #sanitiseAzureURL(arguments.file)# from Azure" />

			</cfif>

			<cfcatch>
				<cflog file="#application.applicationname#_azure" text="Error reading [#arguments.config.name#] #sanitiseAzureURL(arguments.file)#: #cfcatch.message#" />
				<cfrethrow>
			</cfcatch>
		</cftry>

		<cfreturn data />
	</cffunction>

	<cffunction name="ioMoveFile" returntype="void" access="public" output="false" hint="Moves the specified file between locations on a specific CDN, or between the CDN and the local filesystem">
		<cfargument name="source_config" type="struct" required="false" />
		<cfargument name="source_file" type="string" required="false" />
		<cfargument name="source_localpath" type="string" required="false" />
		<cfargument name="dest_config" type="struct" required="false" />
		<cfargument name="dest_file" type="string" required="false" />
		<cfargument name="dest_localpath" type="string" required="false" />

		<cfset var sourcefile = "" />
		<cfset var destfile = "" />
		<cfset var acl = "" />
		<cfset var tmpfile = "" />
		<cfset var stAttrs = structnew() />
		<cfset var cachePath = "" />

		<!--- Inter-container move --->
		<cfif not structkeyexists(arguments,"dest_file")>
			<cfset arguments.dest_file = arguments.source_file />
		</cfif>

		<!--- Copy the file across --->
		<cfset ioCopyFile(argumentCollection=arguments) />

		<cfif structkeyexists(arguments,"source_config")>

			<!--- Remove original file --->
			<cfset ioDeleteFile(config=arguments.source_config,file=arguments.source_file) />

		<cfelseif structkeyexists(arguments,"dest_config")>

			<!--- Remove the original file --->
			<cffile action="delete" file="#arguments.source_localpath#" />

			<cflog file="#application.applicationname#_azure" text="Deleted local file #arguments.source_localpath#" />

		</cfif>

	</cffunction>

	<cffunction name="ioCopyFile" returntype="void" access="public" output="false" hint="Copies the specified file between locations on a specific CDN, or between the CDN and the local filesystem">
		<cfargument name="source_config" type="struct" required="false" />
		<cfargument name="source_file" type="string" required="false" />
		<cfargument name="source_localpath" type="string" required="false" />
		<cfargument name="dest_config" type="struct" required="false" />
		<cfargument name="dest_file" type="string" required="false" />
		<cfargument name="dest_localpath" type="string" required="false" />

		<cfset var sourcefile = "" />
		<cfset var destfile = "">
		<cfset var acl = "" />
		<cfset var tmpfile = "" />
		<cfset var stAttrs = structnew() />
		<cfset var cachePath = "" />

		<cfif not structkeyexists(arguments,"dest_file")>
			<cfset arguments.dest_file = arguments.source_file />
		</cfif>

		<cfif structkeyexists(arguments,"source_config") and structkeyexists(arguments,"dest_config")>

			<!--- Copy the file across --->
			<cfset makeRequest(
				config=arguments.dest_config,
				method="PUT",
				path=getAbsolutePath(config=arguments.dest_config, file=arguments.dest_file),
				headers={
					"x-ms-copy-source"="https://#arguments.source_config.account#.blob.core.windows.net#getAbsolutePath(config=arguments.source_config, file=arguments.source_file)#"
				}
			) />

			<cflog file="#application.applicationname#_azure" text="Copied [#arguments.source_config.name#] #sanitiseAzureURL(arguments.source_file)# to [#arguments.dest_config.name#] #sanitiseAzureURL(arguments.dest_file)#" />

		<cfelseif structkeyexists(arguments,"source_config")>

			<cfset cachePath = getCachedFile(config=arguments.source_config,file=arguments.source_file) />

			<cfif len(cachePath)>

				<cffile action="copy" source="#cachePath#" destination="#arguments.dest_localpath#" mode="664" nameconflict="overwrite" />

				<cflog file="#application.applicationname#_azure" text="Copied [#arguments.source_config.name#] #sanitiseAzureURL(arguments.source_file)# from cache to #sanitiseAzureURL(arguments.dest_localpath)#" />

			<cfelse>

				<!--- move from Azure source to local destination --->
				<cfset sourcefile = getURLPath(config=arguments.source_config, file=arguments.source_file) />
				<cfset destfile = arguments.dest_localpath />

				<!--- Copy the file locally --->
				<cfhttp url="https:#sourcefile#" path="#getDirectoryFromPath(destfile)#" file="#getFileFromPath(destfile)#" />

				<cfif arguments.source_config.localCacheSize>
					<cfset tmpfile = getTemporaryFile(config=arguments.source_config,file=arguments.source_file) />
					<cffile action="copy" source="#destfile#" destination="#tmpfile#" mode="664" nameconflict="overwrite" />
					<cfset addCachedFile(config=arguments.source_config,file=arguments.source_file,path=tmpfile) />
				</cfif>

				<cflog file="#application.applicationname#_azure" text="Copied [#arguments.source_config.name#] #sanitiseAzureURL(arguments.source_file)# from Azure to #sanitiseAzureURL(destfile)#" />

			</cfif>

		<cfelseif structkeyexists(arguments,"dest_config")>

			<cftry>

				<cfset makeRequest(
					config=arguments.dest_config,
					method="PUT",
					path=getAbsolutePath(config=arguments.dest_config, file=arguments.dest_file),
					headers={
						"Content-Type"=this.cdn.getMimeType(arguments.dest_file),
						"x-ms-meta-AzureSearch_Skip"="true",
						"x-ms-blob-type"="BlockBlob"
					},
					dataFile=arguments.source_localpath
				) />

				<cfcatch>
					<cflog file="#application.applicationname#_azure" text="Error moving #arguments.source_localpath# to [#arguments.dest_config.name#] #sanitiseAzureURL(arguments.dest_file)#: #cfcatch.message#" />
					<cfrethrow>
				</cfcatch>
			</cftry>

			<cfif arguments.dest_config.localCacheSize>
				<cfset tmpfile = getTemporaryFile(config=arguments.dest_config,file=arguments.dest_file) />
				<cffile action="copy" source="#arguments.source_localpath#" destination="#tmpfile#" mode="664" nameconflict="overwrite" />
				<cfset addCachedFile(config=arguments.dest_config,file=arguments.dest_file,path=tmpfile) />
			</cfif>

			<cflog file="#application.applicationname#_azure" text="Copied #sanitiseAzureURL(arguments.source_localpath)# to [#arguments.dest_config.name#] #sanitiseAzureURL(arguments.dest_file)#" />

		</cfif>
	</cffunction>

	<cffunction name="ioDeleteFile" returntype="void" output="false" hint="Deletes the specified file. Does not check that the file exists first.">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="file" type="string" required="true" />

		<cfset makeRequest(
			method="DELETE",
			config=arguments.config,
			path=getAbsolutePath(argumentCollection=arguments),
			headers={
				"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"
			}
		) />

		<cfif arguments.config.localCacheSize>
			<cfset removeCachedFile(config=arguments.config,file=arguments.file) />
		</cfif>

		<cflog file="#application.applicationname#_azure" text="Deleted [#arguments.config.name#] #sanitiseAzureURL(arguments.file)#" />
	</cffunction>


	<cffunction name="ioDirectoryExists" returntype="boolean" access="public" output="false" hint="Checks that a specified path exists">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="dir" type="string" required="true" />

		<cfreturn true />
	</cffunction>

	<cffunction name="ioCreateDirectory" returntype="void" access="public" output="false" hint="Creates the specified directory. It assumes that it does not already exist, and will create all missing directories">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="dir" type="string" required="true" />

	</cffunction>

	<cffunction name="ioGetDirectoryListing" returntype="query" access="public" output="false" hint="Returns a query of the directory containing a 'file' column only. This filename will be equivilent to what is passed into other CDN functions." ref="https://docs.microsoft.com/en-us/rest/api/storageservices/list-blobs">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="dir" type="string" required="true" />

		<cfset var data = makeRequest(
			config=arguments.config,
			path="/#arguments.config.container#",
			query={
				"restype"="container",
				"comp"="list",
				"prefix"=arguments.config.pathPrefix & arguments.dir
			}
		) />
		<cfset var blob = {} />
		<cfset var qDir = queryNew("file", "varchar") />

		<cfif structKeyExists(data.EnumerationResults.Blobs, "Blob")>
			<cfloop array="#data.EnumerationResults.Blobs.Blob#" index="blob">
				<cfset queryAddRow(qDir) />
				<cfset querySetCell(qDir, "file", "/" & blob.Name.XMLText) />
			</cfloop>
		</cfif>

		<cfquery dbtype="query" name="qDir">
			SELECT * FROM qDir ORDER BY file
		</cfquery>

		<cfreturn qDir />
	</cffunction>


	<cffunction name="sanitiseAzureURL" access="public" output="false" returntype="string">
		<cfargument name="azureURL" type="string" required="true" />

		<cfreturn arguments.azureURL />
	</cffunction>

	<cffunction name="sanitiseAzureConfig" access="public" output="false" returntype="struct">
		<cfargument name="config" type="struct" required="true" />

		<cfreturn arguments.config />
	</cffunction>

	<cffunction name="makeRequest" returntype="any" access="public" output="false" hint="Makes the specified request to Azure">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="method" type="string" required="false" default="GET" />
		<cfargument name="path" type="string" required="true" />
		<cfargument name="query" type="struct" required="false" default="#structNew()#" />
		<cfargument name="headers" type="struct" required="false" default="#structNew()#" />
		<cfargument name="data" type="string" required="false" />
		<cfargument name="dataFile" type="string" required="false" />
		<cfargument name="bMetadataOnly" type="boolean" required="false" default="false" />

		<cfset var bExists = false />
		<cfset var signature = "" />
		<cfset var timestamp = dateConvert("local2UTC",now()) />
		<cfset var stResponse = structNew() />
		<cfset var results = "" />
		<cfset var stDetail = structNew() />
		<cfset var substituteValues = arrayNew(1) />
		<cfset var binaryKey = binaryDecode(arguments.config.storageKey, "base64")>
		<cfset var key = "" />
		<cfset var stringToSign = "" />
		<cfset var binarySignature = "" />
		<cfset var resourcePath = arguments.path />

		<cfif structKeyExists(arguments, "dataFile")>
			<cfset arguments.data = fileReadBinary(arguments.dataFile) />
		</cfif>

		<!--- Basic headers --->
		<cfset arguments.headers["x-ms-date"] = dateFormat(timestamp,"ddd, dd mmm yyyy") & " " & timeFormat(timestamp,"HH:mm:ss") & " GMT" />
		<cfset arguments.headers["x-ms-version"] = "2015-12-11" />

		<cfif not structKeyExists(arguments.headers, "content-type")>
			<cfset arguments.headers["content-type"] = "" />
		</cfif>

		<cfif structKeyExists(arguments, "data") and listFindNoCase("POST,PUT", arguments.method)>
			<cfset arguments.headers["content-length"] = len(arguments.data) />
			<cfset stringToSign = replace("#arguments.method#\n\n\n#arguments.headers['content-length']#\n\n#arguments.headers['content-type']#\n\n\n\n\n\n\n#getCanonicalHeaders(argumentCollection=arguments)##getCanonicalResource(argumentCollection=arguments)##getCanonicalQuery(argumentCollection=arguments)#","\n","#chr(10)#","all") />
		<cfelse>
			<cfset stringToSign = replace("#arguments.method#\n\n\n\n\n#arguments.headers['content-type']#\n\n\n\n\n\n\n#getCanonicalHeaders(argumentCollection=arguments)##getCanonicalResource(argumentCollection=arguments)##getCanonicalQuery(argumentCollection=arguments)#","\n","#chr(10)#","all") />
		</cfif>

		<cfset binarySignature = hmac(stringToSign, binaryKey, "HmacSHA256", "utf-8") />
		<cfset signature = toBase64(binaryDecode(binarySignature, "hex")) />

		<cfset resourcePath = replace(resourcePath, "##", "%23", "ALL") />
		<cfloop collection="#arguments.query#" index="key">
			<cfif find("?", resourcePath)>
				<cfset resourcePath = resourcePath & "&" & key & "=" & urlEncodedFormat(arguments.query[key]) />
			<cfelse>
				<cfset resourcePath = resourcePath & "?" & key & "=" & urlEncodedFormat(arguments.query[key]) />
			</cfif>
		</cfloop>

		<cfhttp method="#arguments.method#" url="https://#arguments.config.account#.blob.core.windows.net#resourcePath#" charset="utf-8" result="stResponse" timeout="10">
			<cfhttpparam type="header" name="Authorization" value="SharedKey #arguments.config.account#:#signature#">
		 	<cfloop collection="#arguments.headers#" item="key">
			 	<cfhttpparam type="header" name="#key#" value="#arguments.headers[key]#">
		 	</cfloop>

		 	<cfif structKeyExists(arguments, "data") and listFindNoCase("POST,PUT", arguments.method)>
		 		<cfhttpparam type="body" value="#arguments.data#" />
		 	</cfif>
		</cfhttp>

		<cfif listFindNoCase("HEAD,DELETE", arguments.method) or arguments.bMetadataOnly>
			<cfif NOT reFind("^(2\d\d|404) ", stResponse.statuscode)>
				<cfset application.fapi.throw(
					message="Error accessing Azure API: {1} {2}",
					type="azureerror",
					detail=serializeJSON({ "signature"=signature, "stringToSign"=stringToSign, "method"=arguments.method, "path"=arguments.path, "query"=arguments.query, "headers"=arguments.headers, "result"=stResponse.filecontent }),
					substituteValues=[ stResponse.statuscode, arguments.path ]
				) />
			<cfelse>
				<cfreturn stResponse />
			</cfif>
		</cfif>

		<cfif isXML(mid(stResponse.fileContent, 2, len(stResponse.fileContent)))>
			<cfset results = XMLParse(stResponse.fileContent) />

			<!--- check for errors --->
			<cfif structkeyexists(results,"Error")>
				<cfset application.fapi.throw(
					message="Error accessing Azure API: {1} [signature={2}]",
					type="azureerror",
					detail=serializeJSON({ "signature"=signature, "stringToSign"=stringToSign, "method"=arguments.method, "path"=arguments.path, "query"=arguments.query, "headers"=arguments.headers, "result"=stResponse.filecontent }),
					substituteValues=[results.Error.Message.XMLText, signature]
				) />
			</cfif>
		<cfelseif NOT reFind("^2\d\d ", stResponse.statuscode)><cfdump var="#stResponse.filecontent#"><cfabort>
			<cfset application.fapi.throw(
				message="Error accessing Azure API: {1} {2}",
				type="azureerror",
				detail=serializeJSON({ "signature"=signature, "stringToSign"=stringToSign, "method"=arguments.method, "path"=arguments.path, "query"=arguments.query, "headers"=arguments.headers, "result"=stResponse.filecontent }),
				substituteValues=[stResponse.statuscode, arguments.path]
			) />
		</cfif>

		<cfreturn results />
	</cffunction>


	<cffunction name="getCanonicalHeaders" access="private" output="false" returntype="string">
		<cfargument name="headers" type="struct" required="true" />

		<cfset var key = "" />
		<cfset var keys = listToArray(listSort(lcase(structKeyList(arguments.headers)), "text")) />
		<cfset var canonicalizedHeaders = [] />

		<cfloop array="#keys#" item="key">
			<cfif not listFindNoCase("Content-Type,Content-Length", key)>
				<cfset arrayAppend(canonicalizedHeaders, lcase(key) & ":" & arguments.headers[key]) />
			</cfif>
		</cfloop>

		<cfreturn arrayToList(canonicalizedHeaders, "\n") & "\n" />
	</cffunction>

	<cffunction name="getCanonicalQuery" access="private" output="false" returntype="string">
		<cfargument name="query" type="struct" required="true" />

		<cfif structIsEmpty(arguments.query)>
			<cfreturn "" />
		</cfif>

		<cfset var key = "" />
		<cfset var keys = listToArray(listSort(lcase(structKeyList(arguments.query)), "text")) />
		<cfset var canonicalizedQuery = [] />

		<cfloop array="#keys#" item="key">
			<cfset arrayAppend(canonicalizedQuery, lcase(key) & ":" & arguments.query[key]) />
		</cfloop>

		<cfreturn "\n" & arrayToList(canonicalizedQuery, "\n") />
	</cffunction>

	<cffunction name="getCanonicalResource" access="private" output="false" returntype="string">
		<cfargument name="config" type="struct" required="true" />
		<cfargument name="path" type="string" required="true" />

		<cfset var dir = getDirectoryFromPath(arguments.path) />
		<cfset var file = getFileFromPath(arguments.path) />

		<cfset file = urlEncodedFormat(file) />
		<cfset file = replaceList(file, "%2E,%5F,%2D,%20", ".,_,-, ") />

		<cfreturn "/" & arguments.config.account & dir & file />
	</cffunction>

	<cffunction name="dateToRFC3339" access="public" output="false" returntype="string">
		<cfargument name="d" type="date" required="true" />
		<cfargument name="bMS" type="boolean" required="false" default="true" />

		<cfset var asUTC = dateConvert("local2utc", arguments.d) />
		<cfset var dFormat = "yyyy-mm-dd" />
		<cfset var tFormat = "HH:mm:ss" />

		<cfif arguments.bMS>
			<cfset tFormat = tFormat & ".lll" />
		</cfif>

		<cfreturn dateformat(asUTC, dFormat) & "T" & timeformat(asUTC, tFormat) & "Z" />
	</cffunction>

	<cffunction name="rfc3339ToDate" access="public" output="false" returntype="date">
		<cfargument name="input" type="date" required="true" />

		<cfset var sdf = "" />
		<cfset var pos = "" />
		<cfset var rdate = "" />

		<cfif not reFind("^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(\.\d{1,4})?Z)?$", arguments.input)>
			<cfthrow message="Date/time must be in the form yyyy-MM-ddTHH:mm:ss.SSSZ or yyyy-MM-dd: #arguments.input#" />
		</cfif>

		<cfif reFind("^\d{4}-\d{2}-\d{2}$", arguments.input)>
			<cfset sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd") />
		<cfelseif reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$", arguments.input)>
			<cfset sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss'Z'") />
		<cfelseif reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1}Z$", arguments.input)>
			<cfset sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.S'Z'") />
		<cfelseif reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{2}Z$", arguments.input)>
			<cfset sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SS'Z'") />
		<cfelseif reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$", arguments.input)>
			<cfset sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'") />
		<cfelseif reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{4}Z$", arguments.input)>
			<cfset sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SSSS'Z'") />
		</cfif>

		<cfset pos = CreateObject("java", "java.text.ParsePosition").init(0) />

		<cfset rdate = sdf.parse(arguments.input, pos) />

		<cfreturn application.fc.LIB.TIMEZONE.castFromUTC(rdate, application.fc.serverTimezone) />
	</cffunction>

</cfcomponent>
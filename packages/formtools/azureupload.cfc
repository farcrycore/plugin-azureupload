<cfcomponent displayname="Azure Upload" extends="farcry.core.packages.formtools.field" output="false">

	<cfproperty name="ftAllowedFileExtensions" default="jpg,jpeg,png,gif,pdf,doc,ppt,xls,docx,pptx,xlsx,zip,rar,mp3,mp4,m4v,avi">
	<cfproperty name="ftDestination" default="" hint="Destination of file store relative of secure/public locations.">
	<cfproperty name="ftNameConflict" default="makeunique" hint="Strategy for resolving file name conflicts; makeunique | overwrite">
	<cfproperty name="ftMax" default="1" hint="Maximum number of allowed files to upload.">
	<cfproperty name="ftMaxHeight" default="0" hint="Maximum height of the upload drop zone in pixels.">
	<cfproperty name="ftMaxSize" default="104857600" hint="Maximum filesize upload in bytes.">
	<cfproperty name="ftSecure" default="false" hint="Store files securely outside of public webspace.">
	<cfproperty name="ftLocation" default="auto" hint="Store files in a specific CDN location. If set to 'auto', this value will be derived from the target property." />
	<cfproperty name="ftAzureUploadTarget" default="false" hint="Allow the property to be joined with array upload.">
	<cfproperty name="indexable" default="true" hint="Allow the file to be indexed.">
	<cfproperty name="ftSecure" default="false" hint="Store files securely outside of public webspace." />


	<cffunction name="init" output="false">
		<cfreturn this>
	</cffunction>

	<cffunction name="edit" access="public" output="true" returntype="string">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">
		<cfargument name="inputClass" required="false" type="string" default="" hint="This is the class value that will be applied to the input field.">


		<cfset var html = "">
		<cfset var item = "">
		<cfset var fileMeta = application.fc.lib.azurecdn.resolveLocationMetadata(argumentCollection=arguments) />

		<cfset var ftMin = 0 />
		<cfset var ftMax = arguments.stMetadata.ftMax />
		<cfset var thumbWidth = 80 />
		<cfset var thumbheight = 80 />
		<cfset var cropMethod = 'fitinside' />
		<cfset var format = 'jpg' />
		<cfset var buttonAddLabel = "Add File" />
		<cfset var placeholderAddLabel = """#buttonAddLabel#"" or drag and drop here" /><!--- TODO: for mobile / responsive there should be no mention of drag/drop  --->

		<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

		<cfif ftMax gt 1>
			<cfset buttonAddLabel = "Add Files" />
		</cfif>


		<skin:loadJS id="azureuploadJS" />
		<skin:loadCSS id="azureuploadCSS" />

		<cfif arguments.stMetadata.ftMaxHeight gt 0>
			<cfoutput>
			<style type="text/css">
				###arguments.fieldname#-upload-dropzone {
					max-height: #arguments.stMetadata.ftMaxHeight#px;
					overflow-y: auto;
				}
			</style>
			</cfoutput>
		</cfif>

		<cfsavecontent variable="html">
			<cfoutput>

				<!--- UPLOADER UI --->
				<div class="multiField">
				<div id="#arguments.fieldname#-container" class="azureupload upload-empty">
					<div id="upload-placeholder" class="upload-placeholder">
						<div class="upload-placeholder-message">
							#placeholderAddLabel#
						</div>
					</div>

					<div id="#arguments.fieldname#-upload-dropzone" class="upload-dropzone">
						<cfloop list="#arguments.stMetadata.value#" index="item">
							<div class="upload-item upload-item-complete">
								<div class="upload-item-row">
									<div class="upload-item-container">
										
										<cfif NOT arguments.stMetadata.ftSecure AND structKeyExists(application.fc.lib, "cloudinary") and len(arguments.stMetadata.value)>
											<cfset var cdnPath = getFileLocation(stObject=arguments.stObject, stMetadata=arguments.stMetadata).path>
											<cfset var croppedThumbnail = application.fc.lib.cloudinary.fetch(
												file=cdnPath,
												cropParams={
													width: "#thumbWidth#", 
													height: "#thumbheight#", 
													crop: "#cropMethod#",
													format: "#format#"
											})>
											<div class="upload-item-image">
												<img src="#croppedThumbnail#" />
											</div>
										<cfelse>
											<div class="upload-item-nonimage" style="display:block;">
												<i class='fa fa-file-image-o'></i>
											</div>
										</cfif>
										
										<div class="upload-item-progress-bar"></div>
									</div>
									<div class="upload-item-info">
										<div class="upload-item-file">#listLast(arguments.stMetadata.value, "/")#</div>
									</div>
									<div class="upload-item-state"></div>
									<div class="upload-item-buttons">
										<button type="button" title="Remove" class="upload-button-remove">&times;</button>
									</div>
								</div>
							</div>
						</cfloop>
					</div>

					<div style="border:none; text-align:left;" class="buttonHolder form-actions">
						<button id="#arguments.fieldname#-upload-add" class="fc-btn btn" role="button" aria-disabled="false"><i class="fa fa-cloud-upload"></i> #buttonAddLabel#</button>
					</div>

				</div>
				</div>

				<input type="hidden" name="#arguments.fieldname#" id="#arguments.fieldname#" value="#application.fc.lib.esapi.encodeForHTMLAttribute(arguments.stMetadata.value)#" />
				<input id="#arguments.fieldname#_orientation" name="#arguments.fieldname#_orientation" type="hidden" value="">

				<!--- FARCRY FORMTOOL VALIDATION --->
				<input id="#arguments.fieldname#_filescount" name="#arguments.fieldname#_filescount" type="hidden" value="#listLen(arguments.stMetadata.value)#">
				<input id="#arguments.fieldname#_errorcount" name="#arguments.fieldname#_errorcount" type="hidden" value="0">
				<script>
					$j(function(){
						$j("###arguments.fieldname#_filescount").rules("add", {
							min: #ftMin#,
							max: #ftMax#,
							messages: {
								min: "Please attach at least #ftMin# files.",
								max: "Please attach no more than #ftMax# files."
							}
						});
						$j("###arguments.fieldname#_errorcount").rules("add", {
							min: 0,
							max: 0,
							messages: {
								min: "There was an error with some uploads. Please remove them and try uploading again.",
								max: "There was an error with some uploads. Please remove them and try uploading again."
							}
						});
					});
				</script>

				<script>
					azureupload($j, plupload, {
						url : "#fileMeta.uploadEndpoint#",
						fieldname: "#arguments.fieldname#",
						uploadpath: "#fileMeta.fileUploadPath#",
						location: "#fileMeta.cdnLocation#",
						destinationpart: "#arguments.stMetadata.ftDestination#",
						nameconflict: "#arguments.stMetadata.ftNameConflict#",
						maxfiles: #ftMax#,
						multipart_params: {
							"key": "#fileMeta.fileUploadPath#/${filename}",
							"name": "#fileMeta.fileUploadPath#/${filename}",
							"filename": "#fileMeta.fileUploadPath#/${filename}"
						},
						filters: {
							max_file_size : "#arguments.stMetadata.ftMaxSize#",
							mime_types: [
								{ title: "Files", extensions: "#arguments.stMetadata.ftAllowedFileExtensions#" }
							]
						},
						fc: {
							"webroot": "#application.url.webroot#/index.cfm?ajaxmode=1",
							"typename": "#arguments.typename#",
							"objectid": "#arguments.stObject.objectid#",
							"property": "#arguments.stMetadata.name#",
							"indexable": "#fileMeta.indexable#"
							<cfif fileMeta.cdnLocation eq "images">
								, "onFileUploaded" : function(file,item) {
									if (window.$fc !== undefined && window.$fc.imageformtool !== undefined) {
										$j($fc.imageformtool(
											"#left(arguments.fieldname,len(arguments.fieldname)-len(arguments.stMetadata.name))#",
											"#arguments.stMetadata.name#"
										)).trigger("filechange", [{
											value : "#arguments.stMetadata.ftDestination#/" + file.name,
											filename : file.name,
											fullpath : "#fileMeta.uploadEndpoint#/" + file.name,
											width : file.width,
											height : file.height,
											size : file.size
										}]);
									}
								},
								"onFileRemove" : function(item,file,removeOnly) {
									if (window.$fc !== undefined && window.$fc.imageformtool !== undefined) {
										$j($fc.imageformtool(
											"#left(arguments.fieldname,len(arguments.fieldname)-len(arguments.stMetadata.name))#",
											"#arguments.stMetadata.name#"
										)).trigger("deleteall");
									}
								}
							</cfif>
						}	
					});
				</script>

			</cfoutput>
		</cfsavecontent>

		<cfreturn html>
	</cffunction>
	
	<cffunction name="display" access="public" output="true" returntype="string" hint="This will return a string of formatted HTML text to display.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">
	
		<cfset var html = "">
	
		<cfsavecontent variable="html">
			<cfoutput><a target="_blank" href="#application.url.webroot#/download.cfm?downloadfile=#arguments.stobject.objectid#&typename=#arguments.typename#&fieldname=#arguments.stmetadata.name#">#listLast(arguments.stMetadata.value,"/")#</a></cfoutput>
		</cfsavecontent>
		
		<cfreturn html>
	</cffunction>



<!--- file formtool methods... --->

	<cffunction name="getFileLocation" access="public" output="false" returntype="struct" hint="Returns information used to access the file: type (stream | redirect), path (file system path | absolute URL), filename, mime type">
		<cfargument name="objectid" type="string" required="false" default="" hint="Object to retrieve">
		<cfargument name="typename" type="string" required="false" default="" hint="Type of the object to retrieve">
		<!--- OR --->
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		<cfargument name="firstLook" type="string" required="false" hint="Where should we look for the file first. The default is to look based on permissions and status">
		<cfargument name="bRetrieve" type="boolean" required="false" default="true">

		<cfset var stResult = structnew()>
		
		<!--- Throw an error if the field is empty --->
		<cfif NOT len(arguments.stObject[arguments.stMetadata.name])>
			<cfset stResult = structnew()>
			<cfset stResult.method = "none">
			<cfset stResult.path = "">
			<cfset stResult.error = "No file defined">
			<cfreturn stResult>
		</cfif>

		<cfif structKeyExists(arguments.stMetadata, "ftLocation") and arguments.stMetadata.ftLocation eq "images">
			<cfset stResult = application.fc.lib.cdn.ioGetFileLocation(location="images",file=arguments.stObject[arguments.stMetadata.name], bRetrieve=arguments.bRetrieve)>
		<cfelseif structKeyExists(arguments.stMetadata, "ftLocation") and len(arguments.stMetadata.ftLocation)>
			<cfset stResult = application.fc.lib.cdn.ioGetFileLocation(location=arguments.stMetadata.ftLocation,file=arguments.stObject[arguments.stMetadata.name], bRetrieve=arguments.bRetrieve)>
		<cfelseif isSecured(stObject=arguments.stObject,stMetadata=arguments.stMetadata)>
			<cfset stResult = application.fc.lib.cdn.ioGetFileLocation(location="privatefiles",file=arguments.stObject[arguments.stMetadata.name], bRetrieve=arguments.bRetrieve)>
		<cfelse>
			<cfset stResult = application.fc.lib.cdn.ioGetFileLocation(location="publicfiles",file=arguments.stObject[arguments.stMetadata.name], bRetrieve=arguments.bRetrieve)>
		</cfif>
		
		<cfreturn stResult>
	</cffunction>
	
	<cffunction name="checkFileLocation" access="public" output="false" returntype="struct" hint="Checks that the location of the specified file is correct (i.e. privatefiles vs publicfiles)">
		<cfargument name="objectid" type="string" required="false" default="" hint="Object to retrieve">
		<cfargument name="typename" type="string" required="false" default="" hint="Type of the object to retrieve">
		<!--- OR --->
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		
		
		<cfset var stResult = structnew()>
		
		<!--- Throw an error if the field is empty --->
		<cfif NOT len(arguments.stObject[arguments.stMetadata.name])>
			<cfset stResult = structnew()>
			<cfset stResult.error = "No file defined">
			<cfreturn stResult>
		</cfif>
		
		<cfif isSecured(stObject=arguments.stObject,stMetadata=arguments.stMetadata)>
			<cfset stResult.correctlocation = "privatefiles">
			<cfset stResult.currentlocation = application.fc.lib.cdn.ioFindFile(locations="privatefiles,publicfiles",file=arguments.stObject[arguments.stMetadata.name])>
		<cfelse>
			<cfset stResult.correctlocation = "publicfiles">
			<cfset stResult.currentlocation = application.fc.lib.cdn.ioFindFile(locations="publicfiles,privatefiles",file=arguments.stObject[arguments.stMetadata.name])>
		</cfif>
		
		<cfset stResult.correct = stResult.correctlocation eq stResult.currentlocation>
		
		<cfreturn stResult>
	</cffunction>
	
	<cffunction name="isSecured" access="private" output="false" returntype="boolean" hint="Encapsulates the security check on the file">
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		
		<cfset var filepermission = false>
		
		<cfparam name="arguments.stMetadata.ftSecure" default="false">
		<cfif arguments.stMetadata.ftSecure eq "false">
			<cfreturn false>
		<cfelse>
			<cfreturn true>
		</cfif>
	</cffunction>
	
	<cffunction name="duplicateFile" access="public" output="false" returntype="string" hint="For use with duplicateObject, copies the associated file and returns the new unique filename">
		<cfargument name="stObject" type="struct" required="false" hint="Provides the object">
		<cfargument name="stMetadata" type="struct" required="false" hint="Property metadata">
		
		<cfset var currentfilename = arguments.stObject[arguments.stMetadata.name]>
		<cfset var currentlocation = "">
		
		<cfif not len(currentfilename)>
			<cfreturn "">
		</cfif>
		
		<cfset currentlocation = application.fc.lib.cdn.ioFindFile(locations="privatefiles,publicfiles",file=currentfilename)>
		
		<cfif not len(currentlocation)>
			<cfreturn "">
		</cfif>
		
		<cfif isSecured(arguments.stObject,arguments.stMetadata)>
			<cfreturn application.fc.lib.cdn.ioCopyFile(source_location=currentlocation,source_file=currentfilename,dest_location="privatefiles",dest_file=newfilename,nameconflict="makeunique",uniqueamong="privatefiles,publicfiles")>
		<cfelse>
			<cfreturn application.fc.lib.cdn.ioCopyFile(source_location=currentlocation,source_file=currentfilename,dest_location="publicfiles",dest_file=newfilename,nameconflict="makeunique",uniqueamong="privatefiles,publicfiles")>
		</cfif>
	</cffunction>

</cfcomponent>

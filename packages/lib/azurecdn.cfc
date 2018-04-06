component {

	public struct function resolveLocationMetadata(required string typename, required struct stMetadata, struct stObject) {
		var stResult = {
			"cdnLocation" = "publicfiles",
			"cdnPath" = ""
		};

		if (structKeyExists(arguments.stMetadata, "ftLocation") and len(arguments.stMetadata.ftLocation) and arguments.stMetadata.ftLocation neq "auto") {
			stResult.cdnLocation = arguments.stMetadata.ftLocation;
		}
		else if (arguments.stMetadata.ftSecure) {
			stResult.cdnLocation = "privatefiles";
		}
		else if (isDefined("arguments.stObject.status") and arguments.stObject.status eq "draft") {
			stResult.cdnLocation = "privatefiles";
		}

		stResult["cdnConfig"] = application.fc.lib.cdn.getLocation(stResult.cdnLocation);

		if (stResult.cdnConfig.cdn neq "azure") {
			return {};
		}

		stResult.cdnConfig.urlExpiry = 1800;

		stResult["fileUploadPath"] = stResult.cdnConfig.pathPrefix & arguments.stMetadata.ftDestination;
		if (left(stResult.fileUploadPath, 1) == "/") {
			stResult.fileUploadPath = mid(stResult.fileUploadPath, 2, len(stResult.fileUploadPath)-1);
		}

		stResult["uploadEndpoint"] = "https://#stResult.cdnConfig.account#.blob.core.windows.net/#stResult.cdnConfig.container#";

		if (not stResult.cdnConfig.indexable) {
			stResult["indexable"] = false;
		}
		else if (not structKeyExists(arguments.stMetadata, "indexable")) {
			stResult["indexable"] = true;
		}
		else {
			stResult["indexable"] = arguments.stMetadata.indexable;
		}

		return stResult;
	}

	public void function updateTags(required string typename, required struct stMetadata, struct stObject) {
		if (not len(arguments.stObject[arguments.stMetadata.name])) {
			return;
		}

		var fileMeta = resolveLocationMetadata(argumentCollection=arguments);

		application.fc.lib.cdn.cdns.azure.ioWriteMetadata(
			config = fileMeta.cdnConfig,
			file = arguments.stObject[arguments.stMetadata.name],
			metadata = {
				"objectid" = arguments.stObject.objectid,
				"AzureSearch_Skip" = fileMeta.indexable ? "false" : "true"
			}
		);
	}

	public string function getAzureLocations() {
		var locations = application.fc.lib.cdn.getLocations();
		var result = "";
		var row = {};

		for (row in locations) {
			if (row.type eq "azure" and application.fc.lib.cdn.getLocation(row.name).indexable) {
				result = listAppend(result, row.name);
			}
		}

		return result;
	}

	public string function getLocationByContainer(required string container) {
		var locations = application.fc.lib.cdn.getLocations();
		var row = {};

		for (row in locations) {
			if (row.type eq "azure" and application.fc.lib.cdn.getLocation(row.name).container eq arguments.container) {
				return row.name;
			}
		}

		return "";
	}

	public struct function getAllFiles(string marker="start", numeric maxRows=-1) {
		var locations = getAzureLocations();
		var thislocation = "";
		var thismarker = "";

		// Figure out what the request is, i.e. which location, what marker
		if (arguments.marker eq "start") {
			thislocation = listFirst(locations);
			thismarker = "";
		}
		else if (find(",", arguments.marker)) {
			thislocation = listFirst(arguments.marker);
			thismarker = listRest(arguments.marker);
		}
		else {
			thislocation = arguments.marker;
		}

		// Make the API request
		var config = application.fc.lib.cdn.getLocation(thislocation);
		var stArgs = {
			config=config,
			path="/#config.container#",
			query={
				"restype"="container",
				"comp"="list",
				"prefix"=config.pathPrefix
			}
		};
		if (len(thismarker)) {
			stArgs.query["marker"] = thismarker;
		}
		if (arguments.maxRows neq -1) {
			stArgs.query["maxresults"] = arguments.maxrows;
		}
		var data = application.fc.lib.cdn.cdns.azure.makeRequest(argumentCollection=stArgs);

		// Parse resonse into query
		var qFiles = queryNew("file", "varchar");
		var i = 0;
		if (structKeyExists(data.EnumerationResults.Blobs, "Blob")) {
			for (i=1; i<=arrayLen(data.EnumerationResults.Blobs.Blob); i++) {
				queryAddRow(qFiles);
				querySetCell(qFiles, "file", "/" & data.EnumerationResults.Blobs.Blob[i].Name.XMLText);
			}
		}

		var nextMarker = "";
		if (structKeyExists(data.EnumerationResults, "NextMarker")) {
			nextMarker = thislocation & "," & data.EnumerationResults.NextMarker.XMLText;
		}
		else if (listFind(locations, thislocation) eq listLen(locations)) {
			nextMarker = "";
		}
		else {
			nextMarker = listGetAt(locations, listFind(locations, thislocation)+1);
		}

		return {
			"files" = qFiles,
			"location" = thislocation,
			"locationConfig" = config,
			"marker" = thisMarker,
			"nextmarker" = nextMarker
		};
	}

}
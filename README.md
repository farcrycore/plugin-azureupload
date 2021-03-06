# Azure Upload Plugin

A temporary plugin which adds two new formtools which support uploading direct to Azure Blob Storage.

It includes an `azureupload` formtool for single file properties and an `azurearrayupload` formtool
for array properties (multiple file uploads using related objects).

These features will eventually be integrated into the image and file formtools in Core, so this
plugin is intended as a stop gap alternative until then.

**This plugin is compatible with FarCry 7.2.x and over.**

Azure Upload Plugin is available under LGPL and compatible with the open source and commercial licenses of FarCry Core.

> **Massively scalable object storage for unstructured data**
With exabytes of capacity and massive scalability, Blob Storage stores from hundreds to billions of objects in hot, cool or archive tiers, depending on how often data access is needed. Store any type of unstructured data – images, videos, audio, documents and more – easily and cost-effectively.
https://azure.microsoft.com/en-au/services/storage/blobs/

## Setup

The project must be using Azure for all file storage.

The Azure storage account / container CORS policy must allow GET and PUT for the website domain.

The following settings should be included in the `setLocation` configuration:

<table>
	<thead>
		<tr>
			<th>Key</th>
			<th>Description</th>
		</tr>
	</thead>
	<tbody>
		<tr><td>cdn</td><td>Should be set to `azure`.</td></tr>
		<tr><td>name</td><td>As per normal location configuration.</td></tr>
		<tr><td>storageKey</td><td>The Azure storage API key.</td></tr>
		<tr><td>account</td><td>The Azure storage account.</td></tr>
		<tr><td>container</td><td>The Azure storage container - different containers will typically be used for different CDN locations.</td></tr>
		<tr><td>security</td><td>`private` or `public`, depending on how the container has been configured.</td></tr>
		<tr><td>urlExpiry</td><td>The number of seconds that signed URLs should be valid for. Only needs to be set if security is private.</td></tr>
		<tr><td>pathPrefix</td><td>As per normal location configuration. Note that if each location is in a different container (as recommended), no prefix is required.</td></tr>
		<tr><td>localCacheSize</td><td>As per normal location configuration.</td></tr>
		<tr><td>indexable</td><td>Flag this location as being indexable by Azure Search. Should not be set to true for archive, temp, or image locations.</td></tr>
	</tbody>
</table>

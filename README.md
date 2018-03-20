# Azure Upload Plugin for FarCry Core 7.2.x

This is a temporary plugin which adds two new formtools which support uploading direct to Azure Blob Storage.

It includes an `azureupload` formtool for single file properties and an `azurearrayupload` formtool
for array properties (multiple file uploads using related objects).

These features will eventually be integrated into the image and file formtools in Core, so this
plugin is intended as a stop gap alternative until then.

## Setup

The project must be using Azure for all file storage.

The Azure storage account / container CORS policy must allow GET and PUT for the website domain.

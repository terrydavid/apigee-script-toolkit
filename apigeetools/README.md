## General Instructions for setting up "Apigee Tools Kit"

Source of record for all code, configurations, management scripts, etc. are located in a git repository at

    https://github.com/terrydavid/apigee-script-tools.git

### Setup your environment variables:
```

#!/bin/bash

# Set the Management Host (IMPORTANT: This determines "which" management server is accessed) <br>

There are several example scripts located in the ../config directory

Note: These tools use .netrc file for credentials

By default, all commands issued with no Args will get the Usage and Switches, e.g.:
```shell
> getTargetServers -h
usage: getTargetServers [-cd:hjlvx] [Args]

    -d[0-9] set Debug output 0=off; 2='curl'; 9=help
    -h print this Help message
    -j input/output data in Json format
    -l execute a %true% deLete
    -v display Version information
    -x input/output data in Xml format
```

Example command usage:

```shell
> getTargetServers -x <br>
<?xml version="1.0" encoding="UTF-8" standalone="yes"?> <br>
<List> <br>
    <Item>TS-MFS</Item> <br>
    <Item>TS-ILSMSIT</Item> <br>
    <Item>TS-WFIPOC</Item> <br>
    ... <br>
</List> <br>
```
Then drill down farther with the next command:
```shell
> getTargetServer TS-ILSMIT <br>
<?xml version="1.0" encoding="UTF-8" standalone="yes"?> <br>
<TargetServer name="TS-ILSMIT"> <br>
    <IsEnabled>true</IsEnabled> <br>
    <Host>stpadm1t.{yourdomain}</Host> <br>
    <Port>2012</Port> <br>
</TargetServer> <br>
```

Some useful commands - 

<table>
<tr><th>deploy*</th> <th>Deploy an API Proxy to a specific version</th></tr>
<tr><th>deployLatest*</th>  <th>Deploy the Latest (Newest) Version to an environment </th></tr>
<tr><th>dlAllApis*</th>  <th>Download All the deployed API proxies </th></tr>
<tr><th>getTargetServer*</th>  <th>Get Target Server Config </th></tr>
<tr><th>createTargetServer*</th>  <th>Set a Target Server Config </th></tr>
<tr><th>getVirtualHost*</th>  <th>Get Virtual Host Configs </th></tr>
<tr><th>importAll*</th>  <th>Import All APIs from a repository into a management server </th></tr>
<tr><th>importApi*</th>  <th>Import a single API </th></tr>
<tr><th>importDeploy*</th>  <th>Import and then Deploy an API Bundle </th></tr>
<tr><th>listApiVersions*</th>  <th>Show Latest and Deployed versions of APIs </th></tr>
<tr><th>undeploy*</th>  <th>Undeploy a Version of an API </th></tr>
</table>


A typical development session might use commands in this sequence:

1. Use a SCM system to store tested and verified revisions <br>
2. Extract the latest known good version from your SCM as your starting point (or verify current working version) <br>

3. Download a version of the API <br>
4. dlApi myApi myApiRev <br>

5. Explode the zip file <br>
6. unzip myApi.zip -d myApi <br>

7. Use your editing tools (e.g., Sublime, Eclipse, etc.) to modify your code <br>
8. Note that there are specific sequencing requirements for default and conditional Flows, and for Route-Rules. <br>
   (See Developer Best Practices on the APIGEE doc site:   <br>
   http://apigee.com/docs/api-services/content/best-practices-api-proxy-design-and-development) <br>

9. Re-zip the modifications <br>
   zip -r myApi apiproxy <br>

11. Import (upload) the new revisions: <br>
   ImportApi myApi

12. Please use a json file to enter data for createAppfromfile and createDeveloperfromfile. The arg is the name of the json file. 

Send thoughts, comments, bugs, etc., to tdavid99@gmail.com

Cheers!

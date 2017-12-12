## General Instructions for setting up "Apigee Tools Kit"

Source of record for all code, configurations, management scripts, etc. are located in a git repository at

    https://gitlab.apigee.com/apigee-cs/astk.git


The Tools kit comes as a compressed tarball. To deploy, 

### Create a directory for your workspace and explode the tarball into the directory:

Example:
```
\> cd ~ <br>
\> mkdir \<wkspace.dir\> <br>
\> mv ATK.tgz \<wkspace.dir\> <br>
\> cd \<wkspace.dir\> <br>
\> tar -xzvf ATK.tgz <br>
```

The tool kit requires a couple configuration files and directories to function.
	(TBD Reduce this down to a single configuration)

### Setup your highlevel config file:
```
\> cp .apigee .\<yourapigeeorgname\> <br>
\> vi .\<yourapigeeorgname\> <br>

\#!/bin/bash

\# Set the Management Host (IMPORTANT: This determines "which" management server is accessed) <br>
export MOST="http://\<yourmgmhost\>.\<yourdomain\>:8080/v1"

\# Set the Tools Home directory <br>
export APITOOLS_HOME="$HOME/\<wkspace.dir\>"

\# Set the Tools bin Path <br>
export PATH="$APITOOLS_HOME/bin:$PATH"

\# Set up Secondary config file (handles org/env pairs, will be configured below) <br>
if [ -d $APITOOLS_HOME ] ; then
	cp $APITOOLS_HOME/config/\<yourorg\> $APITOOLS_HOME/config/global
	source $APITOOLS_HOME/config/global
	source $APITOOLS_HOME/lib/functions
else
	echo "NO [$APITOOLS_HOME] Directory"
fi

:wq
```
### Source this into your environment: 
\> source .\<yourapigeeorgname\>

### Configure your orgs/environments so the tools knows about them: 
${APITOOLS_HOME}/bin/crOrgEnv \<yourOrgname\> \<env1\> \<env2\> ...

This step may take some tweaking if you have multiple Environments and/or Orgs.

####Addn'l Notes:
1. These tools use .netrc file for credentials
2. The first parameter (sometimes called "environment" or "host_environment" consists of the <OrgName>-<EnvName> (dash "-" [no quotes] separator))


## You are now SET UP to use the ApigeeToolKit!

By default, all commands issued with no Args will get the Usage and Switches, e.g.:
```shell
\> getTargetServers <br>
ERROR: getTargetServers: no host environment specified <br>
usage: getTargetServers [-cdhjlvx] environment 

    -c turn on curl command display
    -d turn on Debug output
    -h print this Help message
    -j input/output data in Json format
    -l execute a %true% deLete
    -v display Version information
    -x input/output data in Xml format
```

Example command usage:

```shell
\> getTargetServers \<orgname\>-\<envname\> <br>
\<\?xml version="1.0" encoding="UTF-8" standalone="yes"\?\> <br>
\<List\> <br>
    \<Item\>TS-MFS\</Item\> <br>
    \<Item\>TS-ILSMSIT\</Item\> <br>
    \<Item\>TS-WFIPOC\</Item\> <br>
    ... <br>
\</List\> <br>
```
Then drill down farther with the next command:
```shell
\> getTargetServer \<orgname\>-\<envname\> TS-ILSMIT <br>
\<\?xml version="1.0" encoding="UTF-8" standalone="yes"\?\> <br>
\<TargetServer name="TS-ILSMIT"\> <br>
    \<IsEnabled\>true\</IsEnabled\> <br>
    \<Host\>stpadm1t.{yourdomain}\</Host\> <br>
    \<Port\>2012\</Port\> <br>
\</TargetServer\> <br>
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
4. dlApi myorg-myenv myApi myApiRev <br>

5. Explode the zip file <br>
6. unzip myApi.zip -d myApi <br>

7. Use your editing tools (e.g., Sublime, Eclipse, etc.) to modify your code <br>
8. Note that there are specific sequencing requirements for default and conditional Flows, and for Route-Rules. <br>
   (See Developer Best Practices on the APIGEE doc site:   <br>
   http://apigee.com/docs/api-services/content/best-practices-api-proxy-design-and-development) <br>

9. Re-zip the modifications <br>
   zip -r myApi apiproxy <br>

11. Import (upload) the new revisions: <br>
   ImportApi myOrg-myEnv myApi


Send thoughts, comments, bugs, etc., to tdavid@apigee.com

Cheers!
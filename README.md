## General Instructions for setting up "Apigee Tools Kit"

Source of record for all code, configurations, management scripts, etc. are located in a git repository at

    https://github.com/terrydavid/apigee-script-tools.git

### Setup your environment variables
    Use the following code to create and make runable to set up environments:
```
#!/bin/bash
#
#   This shell script handles verifying project directories are setup correctly for operation of 
#       the Apigee Management APIs
#
#   The lines below referencing the environment variable "ENVARS" will source a second script that 
#       handle the setup of the environment variables for the Apigee Organization & Environment
#
# set -x

# APITOOLS_HOME should point to the "apigeetools" subdirectory of the repo.
[[ -f "${HOME}/apigee/../README.md" ]] && export APITOOLS_HOME="${HOME}/apigee"

[[ "_$1" == "_" ]] && exit 1

export ENVARS=$1

# Source the bash environment variables for Apigee (See example below)
source ${ENVARS}

export TOOLSDIR="${APITOOLS_HOME}"
export APISDIR="${HOME}/Projects/${APRJCT}/${ORGANIZATION}/${ENVIRONMENT}/apis"

if [[ ! -d $APISDIR ]] ; then
    if [[ ! -d ${HOME}/Projects/${APRJCT}/${ORGANIZATION}/${ENVIRONMENT} ]] ; then
        if [[ ! -d ${HOME}/Projects/${APRJCT}/${ORGANIZATION} ]] ; then
            mkdir ${HOME}/Projects/${APRJCT}/${ORGANIZATION}
        fi
        mkdir ${HOME}/Projects/${APRJCT}/${ORGANIZATION}/${ENVIRONMENT}
    fi
    mkdir ${APISDIR}
fi

set -
export DEBUG=0
chmod 600 $HOME/.curlrc
echo -n "" >$HOME/.curlrc
export FRMT="json"

# Set the Management Host (IMPORTANT: This determines "which" management server is accessed) <br>
export APIGEE_HOST="${SCHEME}://${HOST_ALIAS}${DOMAIN}${PORT}/v1"

export ORG=${ORGANIZATION}
export ENV=${ENVIRONMENT}
export PATH="${PATH}:${APITOOLS_HOME}/bin"
export CDPATH="${CDPATH}:${APISDIR}"
export MOST="${APIGEE_HOST}"

# A fair number of my aliases need to be set to use bash env vars we just set up.
#   You can skip this step if not needed
source $HOME/.aliases

echo -en "\nAPISDIR = ${APISDIR}\n"
cd ${APISDIR}

set -

```

Example child script for Apigee Variables:
```
#!/bin/bash

if [ ${APITOOLS_HOME} ] ; then

	export APRJCT="rso"
	export ORGANIZATION="lite"
	export ENVIRONMENT="sandbox"
	export DEVELOPER="terry.david@540.co"
	export SCHEME="https"
	export HOST_ALIAS="mgmt-api.sandbox"
	#export HOST_ALIAS="${ORGANIZATION}-${ENVIRONMENT}"; export PORT=":8080"
	export DOMAIN=".lite-portal.com"
	export PORT=""

else
	echo "NO APITOOLS_HOME Directory: [${APITOOLS_HOME}]"
	exit 1
fi
```

Note: These tools use .netrc file for credentials

By default, all commands issued with -h will get the Usage and Switches, e.g.:
```shell
> getTargetServers -h
usage: getTargetServers [-cd:hjlvx] [Args]

    -d[0-9] set Debug output 0=off; 2='curl'; 9=help
    -h print this Help message
    -j input/output data in Json format (default)
    -l execute a %true% deLete
    -v display Version information
    -x input/output data in Xml format (future)
```

Example command usage:

```shell
> gettargetservers

TS-IMDS-01
TS-AIRS-01
TS-MANAGEMENT-API-01
TS-MARS-01
TS-KEYCLOAK-01
TS-FADS-01
```

Then drill down farther with the next command:
```shell
> gettargetserver TS-AIRS-01
RESPONSE= {
  "host" : "<yourAPIHost>.<yourDomain>.com",
  "isEnabled" : true,
  "name" : "TS-SOMETHINGHERE-01",
  "port" : 443,
  "sSLInfo" : {
    "ciphers" : [ ],
    "clientAuthEnabled" : "false",
    "enabled" : "true",
    "ignoreValidationErrors" : false,
    "protocols" : [ ]
  }
}
STATUS_CODE= 200

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
    > dlApi myApi myApiRev <br>

5. Explode the zip file <br>
    > unzip myApi.zip -d myApi <br>

7. Use your editing tools (e.g., Sublime, Eclipse, etc.) to modify your code <br>
8. Note that there are specific sequencing requirements for default and conditional Flows, and for Route-Rules. <br>
   (See Developer Best Practices on the APIGEE doc site:   <br>
   http://apigee.com/docs/api-services/content/best-practices-api-proxy-design-and-development) <br>

9. Re-zip the modifications <br>
    > zip -r myApi apiproxy <br>

11. Import (upload) the new revisions: <br>
    > ImportApi myApi

12. Please use a json file to enter data for createAppfromfile and createDeveloperfromfile. The arg is the name of the json file. 

Send thoughts, comments, bugs, etc., to tdavid99@gmail.com

Cheers!

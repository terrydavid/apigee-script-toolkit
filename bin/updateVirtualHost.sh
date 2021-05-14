#!/bin/bash
 
#
# updateVirtualHost
# updates a Virtual Host by
#	deleting then creating a new one
# usage:
#   updateVirtualHost <virtualHost name>

#set -e

USAGE="virtual_host_name { <vh_config.json file> | [port [host_alias]* ...]}"

deleteVirtualHost "$@"
createVirtualHost "$@"
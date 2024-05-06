#!/usr/bin/bash
#############################################################################
# Filename: create-scality-csrs.sh
#############################################################################
# Purpose:
#   This script can be run from Satellite to generate certificates for the
#   Scality storage nodes.
#############################################################################

#############################################################################
# Change these to match the values that you wish to use for your organization
# NOTE: Not all CAs will make sue of the oN or oUN
#############################################################################
countryName="US"
stateOrProvinceName="My_State_Name"
localityName="My_Town_Name"
organizationName="My_Organization"
organizationalUnitName="My_Department"
emailAddress="security@mycompany.com"

#############################################################################
# Set your encryption bits. Valid levels can vary but most support 2048 and 
# 4096. The higher the number the more likely there could be a CPU cost. At
# the time of writing this script many CAs are stopping support for 1024
#############################################################################
encBits="4096"

#############################################################################
# DNS_COMMON_NAME
# This is the name that the system expects people to connecto to. Most times
# peoeple will connect to a server whose DNS Name is not the FQDN of the 
# actual host name.
#
# Long Name
# This is the FQDN of the full host name. This will be included so that if 
# the host were to make an outbound request and the remote server goes to 
# validate the host's cert then the name will be in the SANs list and 
# validate.
#
# Short Name
# This assumes that the hostname is something like scality-msb-0-mgmt and it
# will only return  scality-msb-0 If the hostname changes then this will
# need to be adjusted.
#############################################################################
DNS_COMMON_NAME="REPLACE_WITH_MY_FULL_DNS_NAME"
LONG_HOST=`hostname -f`
SHORT_HOST=`hostname -s | cut -f1-3 -d\-`

#############################################################################
# OPENSSL_CERT_DIR will be where you want all of the certificates to be
# stored. If you have a diffent prefered location, you would change that here
#############################################################################
OPENSSL_CERT_DIR="/root/certs"
OPENSSL_CONFIG="$OPENSSL_CERT_DIR/openssl.cnf"
CERT_REQ="$OPENSSL_CERT_DIR/$LONG_HOST.csr"
CERT_KEY="$OPENSSL_CERT_DIR/$LONG_HOST.key"
OPENSSL="/usr/bin/openssl"

mkdir $OPENSSL_CERT_DIR
cd $OPENSSL_CERT_DIR

#############################################################################
# This will create the configuration that the Certificates will use by
# default. localityName, organizationName and organizationalUnitName may
# change between UCH and Storrs.
#############################################################################
echo "
default_bits             = $encBits
distinguished_name       = req_distinguished_name
req_extensions           = req_ext
prompt                   = no

[req_distinguished_name]
0.countryName            = $countryName
0.stateOrProvinceName    = $stateOrProvinceName
0.localityName           = $localityName
0.organizationName       = $organizationName
0.organizationalUnitName = $organizationalUnitName

commonName               = $DNS_COMMON_NAME
emailAddress             = $emailAddress

[req_ext]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DNS_COMMON_NAME
DNS.2 = $SHORT_HOST.mycompany.com
" > $OPENSSL_CONFIG

$OPENSSL req -new -config $OPENSSL_CONFIG -keyout $CERT_KEY -out $CERT_REQ -nodes

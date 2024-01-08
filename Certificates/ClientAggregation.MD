# Installing UBA Aggregation Servers

- [Installing UBA Aggregation Servers](#installing-uba-aggregation-servers)
  - [Purpose](#purpose)
    - [Install Process](#install-process)
      - [Deploy New Indexes to Indexers](#deploy-new-indexes-to-indexers)
      - [Create LVM for Splunk data](#create-lvm-for-splunk-data)
      - [Install Splunk](#install-splunk)
      - [setup the firewall](#setup-the-firewall)
      - [Configure Certificates](#configure-certificates)
        - [Create CA Certificates](#create-ca-certificates)
        - [Create Server Certs for indexers](#create-server-certs-for-indexers)
        - [Create Certificate for Clients](#create-certificate-for-clients)
    - [Configuration Process](#configuration-process)
      - [Create Client Deployment](#create-client-deployment)
      - [Setup Windows App](#setup-windows-app)
      - [Configure Deployment Server](#configure-deployment-server)
        - [Restart Splunk](#restart-splunk)

## Purpose

Build Guide getting clients ready to talk to the Splunk servers for UBA. Since clients will be all over the country, we are going to allow only encrypted Splunk traffic to a paid of Aggregators they will collect, process and ship the logs to the Indexing Cluster. 

### Install Process

On the Cluster Master add the following index stanzas to your ```indexes.conf```.

#### Deploy New Indexes to Indexers

```ini
[workstation_eventlogs]
repFactor  = auto
homePath   = volume:hot/workstation/workstation_eventlogs/db
coldPath   = volume:cold/workstation/workstation_eventlogs/colddb
thawedPath = /opt/splunk/var/lib/cold/thawed/workstation/workstation_eventlogs/thaweddb
summaryHomePath = volume:cold/workstation/summary/workstation_eventlogs/db
tstatsHomePath = volume:cold/workstation/tstats/workstation_eventlogs/db

[workstation_dhcp]
repFactor  = auto
homePath   = volume:hot/workstation/workstation_dhcp/db
coldPath   = volume:cold/workstation/workstation_dhcp/colddb
thawedPath = /opt/splunk/var/lib/cold/thawed/workstation/workstation_dhcp/thaweddb
summaryHomePath = volume:cold/workstation/summary/workstation_dhcp/db
tstatsHomePath = volume:cold/workstation/tstats/workstation_dhcp/db

[workstation_anyconnect]
repFactor  = auto
homePath   = volume:hot/workstation/workstation_anyconnect/db
coldPath   = volume:cold/workstation/workstation_anyconnect/colddb
thawedPath = /opt/splunk/var/lib/cold/thawed/workstation/workstation_anyconnect/thaweddb
summaryHomePath = volume:cold/workstation/summary/workstation_anyconnect/db
tstatsHomePath = volume:cold/workstation/tstats/workstation_anyconnect/db

[workstation_powershell]
repFactor  = auto
homePath   = volume:hot/workstation/workstation_powershell/db
coldPath   = volume:cold/workstation/workstation_powershell/colddb
thawedPath = /opt/splunk/var/lib/cold/thawed/workstation/workstation_powershell/thaweddb
summaryHomePath = volume:cold/workstation/summary/workstation_powershell/db
tstatsHomePath = volume:cold/workstation/tstats/workstation_powershell/db

[workstation_winupdate]
repFactor  = auto
homePath   = volume:hot/workstation/workstation_winupdate/db
coldPath   = volume:cold/workstation/workstation_winupdate/colddb
thawedPath = /opt/splunk/var/lib/cold/thawed/workstation/workstation_winupdate/thaweddb
summaryHomePath = volume:cold/workstation/summary/workstation_winupdate/db
tstatsHomePath = volume:cold/workstation/tstats/workstation_winupdate/db

[workstation_winreg]
repFactor  = auto
homePath   = volume:hot/workstation/workstation_winreg/db
coldPath   = volume:cold/workstation/workstation_winreg/colddb
thawedPath = /opt/splunk/var/lib/cold/thawed/workstation/workstation_winreg/thaweddb
summaryHomePath = volume:cold/workstation/summary/workstation_winreg/db
tstatsHomePath = volume:cold/workstation/tstats/workstation_winreg/db
```

#### Create LVM for Splunk data

Run fdisk

```sh
fdisk -l
```

Output: Look for 1 TB Volume

```text
Disk /dev/sdb: 1 TiB, 1099511627776 bytes, 2147483648 sectors
Disk model: Virtual disk
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
```

Create PV

```sh
pvcreate /dev/sdb
```

Create Volume Group

```sh
vgcreate Splunk /dev/sdb
```

Create Logical Volume

```sh
lvcreate -l 100%FREE -n splunk Splunk
```

Make file system

```sh
 mkfs.xfs /dev/Splunk/splunk
 ```

Create mount point

```sh
mkdir /opt/splunk
```

 All of the commands together:

 ```sh
 pvcreate /dev/sdb
 vgcreate Splunk /dev/sdb
 lvcreate -l 100%FREE -n splunk Splunk
 mkfs.xfs /dev/Splunk/splunk
 mkdir /opt/splunk
 ```

 Setup mount point

 ```sh
vi /etc/fstab
 ```

 Add the following to the end of ```/etc/fstab```

 ```text
 /dev/Splunk/splunk /opt/splunk                   xfs   defaults 0 0
 ```

 The reload systemctl and mount the drive

 ```sh
 systemctl daemon-reload
 mount -a
 ```

 df should now show almost a TB of free space

 ```text
 [root@uba-hbl-agg0 ~]# df -h
Filesystem                 Size  Used Avail Use% Mounted on
devtmpfs                   4.0M     0  4.0M   0% /dev
tmpfs                      7.7G     0  7.7G   0% /dev/shm
tmpfs                      3.1G  1.1M  3.1G   1% /run
/dev/mapper/rhel-root       89G  3.5G   86G   4% /
/dev/sda1                  694M  273M  422M  40% /boot
/dev/sda2                  300M   32K  300M   1% /boot/efi
/dev/mapper/rhel-home      4.9G   68M  4.9G   2% /home
/dev/mapper/rhel-var       9.8G  562M  9.3G   6% /var
/dev/mapper/rhel-tmp       2.0G   47M  2.0G   3% /tmp
/dev/mapper/rhel-vartmp   1014M  207M  808M  21% /var/tmp
/dev/mapper/rhel-log        49G  435M   49G   1% /var/log
/dev/mapper/rhel-audit     2.0G   48M  2.0G   3% /var/log/audit
tmpfs                      1.6G     0  1.6G   0% /run/user/0
/dev/mapper/Splunk-splunk  1.0T  8.8G 1015G   1% /opt/splunk
```
---

#### Install Splunk

You will need to get the lastest version from Splunk.com but as of writing the documentation you can download it and install it like this:

```sh
cd
wget https://download.splunk.com/products/splunk/releases/9.1.2/linux/splunk-9.1.2-b6b9c8185839.x86_64.rpm
rpm -ivh splunk-9.1.2-b6b9c8185839.x86_64.rpm
/opt/splunk/bin/splunk enable boot-start -systemd-managed 1 -user splunk --accept-license
```

We need to disable THP in linux

```sh
echo "
echo never > /sys/kernel/mm/transparent_hugepage/defrag 
echo never > /sys/kernel/mm/transparent_hugepage/enabled " >> /etc/rc.d/rc.local
chmod +x /etc/rc.d/rc.local
```

Once the install is complete you will need to make a single change to the config file. Make sure that Splunk will not use all of the system ram. If the system has 16GB then tell it to 14G. 

```sh
vi /etc/systemd/system/Splunkd.service
```

And replace the line ```MemoryLimit=SOMENUMERICALVALUE``` with the following. Assuming that we are going to use 14GB then

```text
MemoryLimit=14G
```

Now restart the services

```sh
systemctl daemon-reload
systemctl enable Splunkd
```

#### setup the firewall 

```sh
echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<service>
  <short>Splunk Management Port</short>
  <description>The management port is a request-response model communication path, implemented as REST over HTTP (historically SOAP was used in older products). Thus anything that is a request with a result occurs over the management port.</description>
  <port protocol=\"tcp\" port=\"8089\"/>
</service>" > /etc/firewalld/services/splunk-management.xml
echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<service>
  <short>Splunk Web Port</short>
  <description>This is the web port required for access to the Splunk Web UI.</description>
  <port protocol=\"tcp\" port=\"8000\"/>
</service> " > /etc/firewalld/services/splunk-web.xml
echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>
<service>
  <short>Splunk Web Port</short>
  <description>The port that the instance uses to listen for incomming indexer data.</description>
  <port protocol=\"tcp\" port=\"9999\"/>
</service>" > /etc/firewalld/services/splunk-idx-data.xml

firewall-cmd --reload
firewall-cmd --permanent --remove-service=cockpit
firewall-cmd --permanent --add-service=splunk-idx-data
firewall-cmd --permanent --add-service=splunk-management
firewall-cmd --permanent --add-service=splunk-web
firewall-cmd --permanent --add-service=https
firewall-cmd --reload
```
reboot

---

#### Configure Certificates

##### Create CA Certificates

```sh
su - splunk
SPLUNK_HOME=/opt/splunk
mkdir $SPLUNK_HOME/etc/auth/mycerts
$SPLUNK_HOME/bin/splunk cmd openssl genrsa -aes256 -out myCertAuthPrivateKey.key 2048
$SPLUNK_HOME/bin/splunk cmd openssl req -new -key myCertAuthPrivateKey.key -out myCertAuthCertificate.csr
```

I used the following values for the CA

```text
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:MyState
Locality Name (eg, city) []:MyCity
Organization Name (eg, company) [Internet Widgits Pty Ltd]:MyCompany
Organizational Unit Name (eg, section) []:Security Office
Common Name (e.g. server FQDN or YOUR name) []:uba-msb-agg0.ad.mycompany.com
Email Address []:SecurityOffice@mycompany.com
```

Create CA Certificate

```sh
$SPLUNK_HOME/bin/splunk cmd openssl x509 -req -in myCertAuthCertificate.csr -sha512 -signkey myCertAuthPrivateKey.key -CAcreateserial -out myCertAuthCertificate.pem -days 1800
```

##### Create Server Certs for indexers

```sh
$SPLUNK_HOME/bin/splunk cmd openssl genrsa -aes256 -out myServerPrivateKey.key 2048
$SPLUNK_HOME/bin/splunk cmd openssl req -new -key myServerPrivateKey.key -out myServerCertificate.csr
```

I used the following values for the server certificate

```text
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:MyState
Locality Name (eg, city) []:MyCity
Organization Name (eg, company) [Internet Widgits Pty Ltd]:MyCompany
Organizational Unit Name (eg, section) []:Security Office
Common Name (e.g. server FQDN or YOUR name) []:*.ad.mycompany.com
Email Address []:security@MyCompany.edu
```

Create the server certificate 

```sh
$SPLUNK_HOME/bin/splunk cmd openssl x509 -req -in myServerCertificate.csr -SHA256 -CA myCertAuthCertificate.pem -CAkey myCertAuthPrivateKey.key -CAcreateserial -out myServerCertificate.pem -days 1825
```

##### Create Certificate for Clients

```sh
$SPLUNK_HOME/bin/splunk cmd openssl genrsa -aes256 -out myClientPrivate.key 2048
$SPLUNK_HOME/bin/splunk cmd openssl req -new -key myClientPrivate.key -out myClientCertificate.csr
```

I used the following values for the server certificate

```text
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:MyState
Locality Name (eg, city) []:MyCity
Organization Name (eg, company) [Internet Widgits Pty Ltd]:MyCompany
Organizational Unit Name (eg, section) []:Security Office
Common Name (e.g. server FQDN or YOUR name) []:clients.ad.mycompany.com
Email Address []:security@MyCompany.edu
```

Create the client certificate

```sh
$SPLUNK_HOME/bin/splunk cmd openssl x509 -req -in myClientCertificate.csr -SHA256 -CA myCertAuthCertificate.pem -CAkey myCertAuthPrivateKey.key -CAcreateserial -out myClientCertificate.pem -days 1825
```

### Configuration Process

#### Create Client Deployment

Create the directories for the app

```sh
SPLUNK_HOME=/opt/splunk
mkdir $SPLUNK_HOME/etc/deployment-apps/UBA_Aggrigator/
mkdir $SPLUNK_HOME/etc/deployment-apps/UBA_Aggrigator/certs
mkdir $SPLUNK_HOME/etc/deployment-apps/UBA_Aggrigator/local

cd $SPLUNK_HOME/etc/deployment-apps/UBA_Aggrigator/certs
cat $SPLUNK_HOME/etc/auth/mycerts/myCertAuthCertificate.pem  $SPLUNK_HOME/etc/auth/mycerts/myCertAuthPrivateKey.key > ca_chain.pem
cat $SPLUNK_HOME/etc/auth/mycerts/myClientCertificate.pem  $SPLUNK_HOME/etc/auth/mycerts/myClientPrivate.key > client.pem

```

In the directory ```$SPLUNK_HOME/etc/deployment-apps/UBA_Aggrigator/local``` create the following files

**deployment.conf**

```ini
[deployment-client]
phoneHomeIntervalInSecs = 180
handshakeRetryIntervalInSecs = 60
```

**outputs.conf**

```ini
[tcpout]
defaultGroup = primary_indexers

[tcpout:primary_indexers]
useSSL = true
server = AGG_SVR_IP_ONE:9999, AGG_SVR_IP_TWO:9999
clientCert = $SPLUNK_HOME/etc/apps/UBA_Aggrigator/certs/client.pem
sslPassword = REPLACE_THIS_WITH_PASSWORD_YOU_USED_TO_CREATE_PRIVATE_KEYS
compressed = true
useClientSSLCompression = true
sslVerifyServerCert = false
disabled = 0
sslVersions = -ssl2, -ssl3, tls1.1, tls1.2
```

**server.conf**

```ini
[sslConfig]
sslRootCAPath = $SPLUNK_HOME/etc/apps/UBA_Aggrigator/certs/ca_chain.pem
useClientSSLCompression = true
sslPassword = REPLACE_THIS_WITH_PASSWORD_YOU_USED_TO_CREATE_PRIVATE_KEYS

[httpServer]
disableDefaultPort = true
```
---

#### Setup Windows App

Download the [Splunk Add-On for Microsoft Windows](https://splunkbase.splunk.com/app/742) and install it

Remove the inputs.conf from ```$SPLUNK_HOME/Splunk_TA_windows/default```

Create ```$SPLUNK_HOME/Splunk_TA_windows/local``` and place the following ```inputs.conf``` in that folder.


```ini
#####################
#      OS Logs      #
#####################
[WinEventLog://Application]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
renderXml=true
index=workstation_eventlogs

[WinEventLog://Security]
disabled = 0
start_from = oldest
current_only = 0
evt_resolve_ad_obj = 1
checkpointInterval = 5
renderXml=true
index=workstation_eventlogs

[WinEventLog://Setup]
disabled = 0
start_from = oldest
current_only = 0
evt_resolve_ad_obj = 1
checkpointInterval = 5
renderXml=true
index=workstation_eventlogs

[WinEventLog://System]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
renderXml=true
index=workstation_eventlogs

###### Forwarded WinEventLogs (WEF) ######
[WinEventLog://ForwardedEvents]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
## The addon supports only XML format for the collection of WinEventLogs using WEF, hence do not change the below renderXml parameter to false.
renderXml=true
host=WinEventLogForwardHost
index=workstation_eventlogs

#####################
#    DHCP Logs      #
#####################
[monitor://$WINDIR\System32\DHCP]
disabled = 0
whitelist = DhcpSrvLog*
crcSalt = <SOURCE>
sourcetype = DhcpSrvLog
index=workstation_dhcp


#########################
# Cisco AnyConnect Logs #
#########################
[WinEventLog://Cisco AnyConnect Diagnostics and Reporting Tool]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
renderXml=true
sourcetype=anyconnect_dart
index=workstation_anyconnect

[WinEventLog://Cisco AnyConnect Secure Mobility Client]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
renderXml=true
sourcetype=anyconnect_secure
index=workstation_anyconnect

[WinEventLog://Cisco AnyConnect Umbrella Roaming Security Module]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
renderXml=true
sourcetype=anyconnect_umbrella
index=workstation_anyconnect

#################################
#    Windows PowerShell Logs    #
#################################
[WinEventLog://Windows PowerShell]
disabled = 0
start_from = oldest
current_only = 0
checkpointInterval = 5
renderXml=true
index=workstation_powershell

#################################
#      Windows Update Logs      #
#################################
## Enable below stanza to get WindowsUpdate.log for Windows 8, Windows 8.1, Server 2008R2, Server 2012 and Server 2012R2
[monitor://$WINDIR\WindowsUpdate.log]
disabled = 0
sourcetype = WindowsUpdateLog
index=workstation_winupdate

## Enable below powershell and monitor stanzas to get WindowsUpdate.log for Windows 10 and Server 2016
## Below stanza will automatically generate WindowsUpdate.log daily
[powershell://generate_windows_update_logs]
script = ."$SplunkHome\etc\apps\Splunk_TA_windows\bin\powershell\generate_windows_update_logs.ps1"
schedule = 0 */24 * * *
disabled = 0
index=workstation_winupdate

## Below stanza will monitor the generated WindowsUpdate.log in Windows 10 and Server 2016
[monitor://$SPLUNK_HOME\var\log\Splunk_TA_windows\WindowsUpdate.log]
disabled = 0
sourcetype = WindowsUpdateLog
index=workstation_winupdate
```

Fix Permissions 

```sh
chown splunk.splunk $SPLUNK_HOME/etc/deployment-apps/* -R
```
---

#### Configure Deployment Server

Create the following files

Create the full certificate chain:

```sh
cat $SPLUNK_HOME/etc/auth/mycerts/myServerCertificate.pem $SPLUNK_HOME/etc/auth/mycerts/myServerPrivateKey.key $SPLUNK_HOME/etc/auth/mycerts/myCertAuthCertificate.pem > /opt/splunk/etc/auth/mycerts/fullchain.pem

```

**inputs.conf**

```ini
[SSL]
sslCommonNameToCheck = uba-msb-agg0.ad.mycompany.com
serverCert = /opt/splunk/etc/auth/mycerts/fullchain.pem
sslPassword = REPLACE_THIS_WITH_PASSWORD_YOU_USED_TO_CREATE_PRIVATE_KEYS
sslVersions = -ssl2, -ssl3, tls1.1, tls1.2
requireClientCert = false
useSSLCompression = true

[splunktcp-ssl:9999]
disabled = 0
```

**outputs.conf**

```ini
[tcpout:PrimaryCluster]
server = IDX_SVR_1:9997, IDX_SVR_2:9997, IDX_SVR_3:9997, IDX_SVR_4:9997, IDX_SVR_5:9997, IDX_SVR_6:9997, IDX_SVR_7:9997, IDX_SVR_8:9997
compressed = true
```

**serverclass.conf**

```ini
[serverClass:Indexer Config:app:UBA_Aggrigator]
restartSplunkWeb = 0
restartSplunkd = 0
stateOnClient = enabled

[serverClass:Indexer Config]
whitelist.0 = *

[serverClass:Windows Logging]
whitelist.0 = *

[serverClass:Windows Logging:app:Splunk_TA_windows]
restartSplunkWeb = 0
restartSplunkd = 0
stateOnClient = enabled
```

**server.conf**

This one is important you will have to merge what is below with what already exists on the server.

```ini
[general]
serverName = uba-msb-agg0.ad.mycompany.com
pass4SymmKey = DO_NOT_CHANGE_THIS_VALUE_FROM_WHAT_EXISTS

[sslConfig]
sslPassword = DO_NOT_CHANGE_THIS_VALUE_FROM_WHAT_EXISTS
useClientSSLCompression = false

[lmpool:auto_generated_pool_download-trial]
description = auto_generated_pool_download-trial
peers = *
quota = MAX
stack_id = download-trial

[lmpool:auto_generated_pool_forwarder]
description = auto_generated_pool_forwarder
peers = *
quota = MAX
stack_id = forwarder

[lmpool:auto_generated_pool_free]
description = auto_generated_pool_free
peers = *
quota = MAX
stack_id = free
```

##### Restart Splunk

```sh
systemctl restart Splunkd.service
```

---


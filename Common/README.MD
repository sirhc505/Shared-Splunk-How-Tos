# Splunk Linux Help

## Popular Splunk / Linux Command

| Command | What is does |
|---------|--------------|
| ll							| Two Ls which is an alias for ls -la |
| cp -R <src> <dest>			| Copy from <src> to <dest> recursively |
| chown -R <usr>.<grp> <path>	| Change the ownership to the value specified in the location specified recursively |
| mkdir <directory>             | Make a directory
| rm <-rf> <file/directory>     | If you want to remove a file then you only need rm <file> if you want to remove an entire directory with it's sub directories use rm -rf <directory>. Use that with care because there is no undo. |

There is is another command that you really want to know called ```setfacl```. 

So you are going to replace SPLUNK_USER with the account that Splunk runs as. The first one sets the ```-m``` set the mask. ```-d``` set the default value so future files would get the same mask. ```-R``` Set mask recursively

```sh
/usr/bin/setfacl -m u:SPLUNK_USER:rx /var/log
/usr/bin/setfacl -R -m u:SPLUNK_USER:rx /var/log/*
/usr/bin/setfacl -d -m u:SPLUNK_USER:rx /var/log
/usr/bin/setfacl -d -R -m u:SPLUNK_USER:rx /var/log/*
```
The above commands set it so that SPLUNK_USER will be able to read any log file in the ```/var/log``` directory and sub-directories. This can be changed when the system is upgraded so know that if you suddenly stop getting logs, this is likely why.


## Splunk Commands


Install Splunk and set the user it is running as to splunkUser. This will change depending
on the specifics of your environment

```sh
/opt/splunk/bin/splunk enable boot-start --accept-license --auto-ports -user splunkUser
```

This creates a terrible init.d file. 

This command tells you how much memory you can allocate to Splunk that will allow the system to NOT be fully consumed by Splunk

```sh
free -g|grep Mem | awk '{ print $2 - 1 "G" }'
```

This is the unit file that I use frequently. 

- The ExecStart path should reference your install directory. 
- MemoryLimit should be set to whatever the value is from the command above
- User / Group should be set to whatever the user Splunk will be running as.
- ExecStartPost / ExecStartPost should reference the user Splunk will be running as.

This file lives in Create ```/etc/systemd/system/``` as ```Splunkd.service```

```ini
[Unit]
Description=Systemd service file for Splunk
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Restart=always
ExecStart=/opt/splunk/bin/splunk _internal_launch_under_systemd
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=360
LimitNOFILE=65536
LimitRTPRIO=99
SuccessExitStatus=51 52
RestartPreventExitStatus=51
RestartForceExitStatus=52
User=splunk
Group=splunk
Delegate=true
CPUShares=1024
MemoryLimit=REPLACE_ME_WITH_VALUE_FROM_AWK_COMMAND
PermissionsStartOnly=true
ExecStartPost=-/bin/bash -c "chown -R splunk:splunk /sys/fs/cgroup/cpu/system.slice/%n"
ExecStartPost=-/bin/bash -c "chown -R splunk:splunk /sys/fs/cgroup/memory/system.slice/%n"

[Install]
WantedBy=multi-user.target

```

If you want Splunk to start on boot time AND you want to start it now then:

```sh
systemctl daemon-reload
systemctl enable Splunkd.service
systemctl start Splunkd.service
``` 

Change the hostname that Splunk uses to identify itself. NOTE You will be prompted for admin passwords if you have not logged into splunk via CLI yet so don't go crazy with copy/paste

```sh
/opt/splunk/bin/splunk set servername NEW_HOSTNAME_HERE
/opt/splunk/bin/splunk set default-hostname NEW_HOSTNAME_HERE
```


```sh
/opt/splunk/bin/splunk edit licenser-localpeer -manager_uri https://LM_SVR_IP:8089
```

Set the Cluster Manager to use a specific SF and RF

```sh
/opt/splunk/bin/splunk edit cluster-config -mode manager -replication_factor INT_RF_VALUE -search_factor INT_SF_VALUE -secret mysupersecretpassword
```

If this is an indexer then you are going to want it to listen on a port 9777. I will always say that this is the default port, I am willing to die on that hill.. LOL

```sh
/opt/splunk/bin/splunk enable listen 9997
```

Tell the Indexer it needs to talk to a Cluster Manager

```sh
/opt/splunk/bin/splunk edit cluster-config -mode peer -manager_uri https://CM_SVR_IP:8089 -secret mysupersecretpassword -replication_port 9100
systemctl restart Splunkd.service

```

I am going to assume that under normal circumstances we would have dedicated SAN volumes for hot, cold, summary, thawed, and they would be mounted in the following locations:

```sh
mkdir /opt/splunk/var/lib/hot
mkdir /opt/splunk/var/lib/cold
mkdir /opt/splunk/var/lib/thawed
mkdir /opt/splunk/var/lib/summary
```

Here is a sample indexes.conf

```ini
[default]
homePath.maxDataSizeMB = 100000

# VOLUME SETTINGS
# In this example, the volume spec here is set to the indexer-specific
# path for data storage. It satisfies the "volume:primary" tag used in
# the indexes.conf which is shared between SH and indexers.
# See also: org_all_indexes

# Two volumes for a "tiered storage" solution--fast and slow disk.
[volume:hot]
path = /opt/splunk/var/lib/hot

# Longer term storage on slower disk.
[volume:cold]
path = /opt/splunk/var/lib/cold

[volume:summary]
path=/opt/splunk/var/lib/summary

#I would love it if thawed could use volume:something but I cannot have everything I guess

[thisismyindex]
repFactor  = auto
homePath   = volume:hot/thisismyindex/db
coldPath   = volume:cold/thisismyindex/db
thawedPath = /opt/splunk/var/lib/thawed/thisismyindex_thawed/thaweddb
summaryHomePath = volume:summary/thisismyindex_summary/db

```


# VIPChange - PostgreSQL failover and replication script

### Assumptions

- The VIP always controls what is the current active node
- The active node ships database transactions to the standby node via PostgreSQL Streaming Replication
- A working secondary node is available for read-only queries but applications must gracefully handle it being unavailable
- The secondary node can get up to 1GB of deltas (changes) behind the primary before you need to rsync the database files across
- Database creation is handled by puppet and only ensures against the current active node.
- It does make an assumption you're using puppet to deploy the files in a few places but that's easily swapped out.

### Failover

Assuminging the following:

- You have two database servers, `postgresql-01` and `postgresql-02`.
- You have two floating virtual IPs (vips) `postgresql-vip` and `postgresql-standbyvip`.
- You have PostgreSQL streaming replication enabled and working [(`wal_level = hot_standby` and `hot_standby = on`)](https://www.postgresql.org/docs/current/static/hot-standby.html)
- You have /etc/vipchange.cfg populated as per the example in this repo (hopefully using configuration management / automation).

### 1) On the **Current active node:** ensure that the vip (eth0:active) is disabled and _as soon as it's done_ enable it on the **current standby node**:

```bash
ssh postgresql-01 vipchange.sh disableactive     # Current primary
ssh postgresql-02 vipchange.sh makeactive        # Current secondary
```

At this point in time, we have a working active and no standby.

Expect to see replication failure alerts & an alert for the standby IP being offline.

### 2) Enable the standby IP on *new* **standby node:** aka *old* **active node**:

```bash
ssh postgresql-02 vipchange.sh makestandby       # Enable secondary / replication
```

At this point in time, the standby now has an IP address, but is not replicating.

Expect to see replication failure alerts.

### 3) On _either node_ sync the data from the new active to the standby:

-   Ensure your SSH keys are forwarded (`ssh -A postgresql-01`)
-   Run from the new *standby* node:

```bash
syncpostgres.sh
```

### Resync

```bash
ssh -A root@postgresql-standyvip
root@postgresql-standyvip:~  # syncpostgres.sh
Note: you must have ssh agent forwarding enabled (ssh-add, ssh -A root@server)
SSH forwarding working...
This script will wipe the STANDBY node, then copy all data from the ACTIVE node to the STANDBY node and bring it online.

The current active node has been detected as 192.168.1.1 postgresql-vip.fqdn
The current standby node has been detected as 192.168.1.2 postgresql-standbyvip.fqdn

Are you sure you want to continue? [y/N] y
Stopping puppet on the STANDBY...
Stopping postgres on the STANDBY...
Stopping PostgreSQL 9.3 database server: main.
Cleaning up old cluster directory on the STANDBY...
Starting base backup as replicator
transaction log start point: 104/2A000028 on timeline 12
pg_basebackup: starting background WAL receiver
10982188/10982287 kB (100%), 1/1 tablespace
transaction log end point: 104/2A5FCCA0
pg_basebackup: waiting for background process to finish streaming ...
pg_basebackup: base backup completed
DONE, starting PostgreSQL on 192.168.1.1 ...
Starting PostgreSQL 9.3 database server: main.
DONE, re-enabling puppet on 192.168.1.1 ...
```

Which when finished will have started postgres and re-enabled puppet.

The servers should now be in sync and replicating.

Expect to see all alerts recover.


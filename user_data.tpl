#cloud-config
"coreos":
  "units":
  - "command": |-
      stop
    "mask": !!bool |-
      true
    "name": |-
      etcd.service
  - "command": |-
      stop
    "mask": !!bool |-
      true
    "name": |-
      update-engine.service
  - "command": |-
      stop
    "mask": !!bool |-
      true
    "name": |-
      locksmithd.service
  - "command": |-
      stop
    "name": |-
      systemd-resolved.service
  - "command": |-
      start
    "content": |
      [Unit]
      Description=Formats the /var/lib ephemeral drive
      Before=var-lib.mount dbus.service
      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=/bin/bash -c "(blkid -t TYPE=ext4 | grep xvdb) || (/usr/sbin/mkfs.ext4 -F /dev/xvdb)"
    "name": |-
      format-var-lib-ephemeral.service
  - "command": |-
      start
    "content": |
      [Unit]
      Description=Mount /var/lib
      Before=dbus.service
      [Mount]
      What=/dev/xvdb
      Where=/var/lib
      Type=ext4
    "name": |-
      var-lib.mount
  - "command": |-
      restart
    "name": |-
      systemd-journald.service
  - "command": |-
      restart
    "name": |-
      docker.service
  - "command": |-
      start
    "content": |
      [Unit]
      Before=dcos.target
      [Service]
      Type=oneshot
      StandardOutput=journal+console
      StandardError=journal+console
      ExecStartPre=/usr/bin/mkdir -p /etc/profile.d
      ExecStart=/usr/bin/ln -sf /opt/mesosphere/environment.export /etc/profile.d/dcos.sh
    "name": |-
      dcos-link-env.service
  - "content": |
      [Unit]
      Description=Download the DCOS
      After=network-online.target
      Wants=network-online.target
      ConditionPathExists=!/opt/mesosphere/
      [Service]
      EnvironmentFile=/etc/mesosphere/setup-flags/bootstrap-id
      Type=oneshot
      StandardOutput=journal+console
      StandardError=journal+console
      ExecStartPre=/usr/bin/curl --fail --retry 20 --continue-at - --location --silent --show-error --verbose --output /tmp/bootstrap.tar.xz ${DOWNLOAD_URL}
      ExecStartPre=/usr/bin/mkdir -p /opt/mesosphere
      ExecStart=/usr/bin/tar -axf /tmp/bootstrap.tar.xz -C /opt/mesosphere
      ExecStartPost=-/usr/bin/rm -f /tmp/bootstrap.tar.xz
    "name": |-
      dcos-download.service
  - "command": |-
      start
    "content": |
      [Unit]
      Description=Download the dockercfg
      After=network-online.target
      Wants=network-online.target
      [Service]
      Type=simple
      Restart=on-failure
      ExecStartPre=/usr/bin/docker pull xueshanf/awscli
      ExecStartPre=/usr/bin/docker run --volume=/tmp:/tmp --rm xueshanf/awscli aws s3 cp s3://${S3_DOCKER_PATH}/.dockercfg /tmp
      ExecStart=-/usr/bin/mv /tmp/.dockercfg /root/.dockercfg
    "name": |-
      docker-auth-downlaod.service
  - "command": |-
      start
    "content": |
      [Unit]
      Description=Prep the Pkgpanda working directories for this host.
      Requires=dcos-download.service
      After=dcos-download.service
      [Service]
      Type=oneshot
      StandardOutput=journal+console
      StandardError=journal+console
      EnvironmentFile=/opt/mesosphere/environment
      ExecStart=/opt/mesosphere/bin/pkgpanda setup --no-block-systemd
      [Install]
      WantedBy=multi-user.target
    "enable": !!bool |-
      true
    "name": |-
      dcos-setup.service
  - "command": |-
      start
    "content": |-
      [Unit]
      Description=Signal CloudFormation Success
      After=dcos.target
      Requires=dcos.target
      ConditionPathExists=!/var/lib/dcos-cfn-signal
      [Service]
      Type=simple
      Restart=on-failure
      StartLimitInterval=0
      RestartSec=15s
      EnvironmentFile=/opt/mesosphere/environment
      EnvironmentFile=/opt/mesosphere/etc/cfn_signal_metadata
      Environment="AWS_CFN_SIGNAL_THIS_RESOURCE=SlaveServerGroup"
      ExecStartPre=/bin/ping -c1 leader.mesos
      ExecStartPre=/opt/mesosphere/bin/cfn-signal
      ExecStart=/usr/bin/touch /var/lib/dcos-cfn-signal
    "name": |-
      dcos-cfn-signal.service
  "update":
    "reboot-strategy": |-
      off
"write_files":
- "content": |
    https://downloads.mesosphere.com/dcos/stable
  "owner": |-
    root
  "path": |-
    /etc/mesosphere/setup-flags/repository-url
  "permissions": |-
    0644
- "content": |
    BOOTSTRAP_ID=${BOOTSTRAP_ID}
  "owner": |-
    root
  "path": |-
    /etc/mesosphere/setup-flags/bootstrap-id
  "permissions": |-
    0644
- "content": |
    ["dcos-config--setup_39bcd04b14a990a870cdff4543566e78d7507ba5", "dcos-metadata--setup_39bcd04b14a990a870cdff4543566e78d7507ba5"]
  "owner": |-
    root
  "path": |-
    /etc/mesosphere/setup-flags/cluster-packages.json
  "permissions": |-
    0644
- "content": |
    [Journal]
    MaxLevelConsole=warning
  "owner": |-
    root
  "path": |-
    /etc/systemd/journald.conf.d/dcos.conf
  "permissions": |-
    0644
- "content": |
    AWS_REGION=${AWS_REGION}
    AWS_IAM_MASTER_ROLE_NAME=${MasterRole}
    AWS_IAM_SLAVE_ROLE_NAME=${SlaveRole}
    AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
  "path": |-
    /etc/mesosphere/setup-packages/dcos-provider-aws--setup/etc/cfn_signal_metadata
- "content": |
    MESOS_CLUSTER=${MESOS_CLUSTER}
  "path": |-
    /etc/mesosphere/setup-packages/dcos-provider-aws--setup/etc/mesos-master-provider
- "content": |
    EXHIBITOR_BACKEND=AWS_S3
    AWS_REGION=${AWS_REGION}
    AWS_S3_BUCKET=${AWS_S3_BUCKET}
    AWS_S3_PREFIX=dcos-exhibitor-config
  "path": |-
    /etc/mesosphere/setup-packages/dcos-provider-aws--setup/etc/exhibitor
- "content": |
    com.netflix.exhibitor.s3.access-key-id=${AWS_ACCESS_KEY_ID}
    com.netflix.exhibitor.s3.access-secret-key=${AWS_SECRET_ACCESS_KEY}
  "path": |-
    /etc/mesosphere/setup-packages/dcos-provider-aws--setup/etc/exhibitor.properties
- "content": |
    MASTER_SOURCE=exhibitor
    EXHIBITOR_ADDRESS=${EXHIBITOR_ADDRESS}
    RESOLVERS=169.254.169.253
  "path": |-
    /etc/mesosphere/setup-packages/dcos-provider-aws--setup/etc/dns_config
- "content": |-
    {}
  "path": |-
    /etc/mesosphere/setup-packages/dcos-provider-aws--setup/pkginfo.json
${ROLES}

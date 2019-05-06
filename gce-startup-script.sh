#!/bin/bash

set -ue

# Log everything to /var/log/messages, should make it easier to debug any problems.
exec 1> >(logger -s -t $(basename $0)) 2>&1

# HOME isn't set for startup script.
export HOME=/root

################################################################
# Basic Utility Methods.
function get_meta() {
  curl --fail -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/$1"
}

function get_attr() {
  get_meta "v1/instance/attributes/$1"
  if [ $? -eq 0 ]; then
    return 0
  fi
  get_meta "v1/project/attributes/$1"
}


################################################################
# Setup DNS record with the current IP address of this machine.
echo "Updating DNS..."

INSTANCE_NAME=`get_meta "v1/instance/name"`
IP_ADDRESS=`get_meta "v1/instance/network-interfaces/0/access-configs/0/external-ip"`
DNS_NAME=`get_attr DNS_NAME`
ZONE=`get_attr DNS_ZONE_NAME`
NAME="$INSTANCE_NAME.$DNS_NAME"
PROJECT=`get_attr DNS_PROJECT`
OLDIP_SET=0
OLDIP=`gcloud dns --project="$PROJECT" record-sets list -z $ZONE \
    | grep "^$NAME" | grep -oE '[^ ]+$'` || OLDIP_SET=1

echo "Update DNS? $PROJECT $ZONE $NAME $OLDIP $IP_ADDRESS"
if [ "$OLDIP" != "$IP_ADDRESS" ]; then
  gcloud dns --project="$PROJECT" record-sets transaction \
    start --zone=$ZONE
  if [ "$OLDIP_SET" -eq 0 ]; then
    gcloud dns --project="$PROJECT" record-sets transaction \
        remove $OLDIP --name=$NAME --ttl=5 --type=A --zone=$ZONE
  fi
  gcloud dns --project="$PROJECT" record-sets transaction \
    add $IP_ADDRESS --name=$NAME --ttl=5 --type=A --zone=$ZONE
  gcloud dns --project="$PROJECT" record-sets transaction \
    execute --zone=$ZONE

  echo "Updated DNS:  $PROJECT $ZONE $NAME $OLDIP to $IP_ADDRESS"
fi


################################################################
# Update Packages. This is slow, we should only do this every week or so.
echo "apt update and upgrade"
apt update
apt upgrade -y
apt install -y git-core less

################################################################
# Setup crontab to shutdown if gotosleep returns true.
echo "install crontab"
(crontab -l | grep -v gotosleep; \
     echo "*/3 * * * * /root/gotosleep && /sbin/shutdown -h now") | crontab -


echo "DONE"

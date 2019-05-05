#!/bin/bash

set -ue

function get_meta() {
  curl -s -H "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/$1"
}

function get_attr() {
  get_meta "v1/instance/attributes/$1"
}

echo "Set IP"
IP_ADDRESS=`get_meta "v1/instance/network-interfaces/0/access-configs/0/external-ip"`
ZONE=`get_attr IP_ZONE`
NAME=`get_attr IP_DNS_ADDRESS`
PROJECT=`get_attr IP_PROJECT`
OLDIP=`gcloud dns --project="$PROJECT" record-sets list -z $ZONE | grep $NAME | grep -oE '[^ ]+$'`
echo "$PROJECT $ZONE $NAME $OLDIP $IP_ADDRESS"

if [ "$OLDIP" != "$IP_ADDRESS" ]; then
  gcloud dns --project="$PROJECT" record-sets transaction start --zone=$ZONE
  gcloud dns --project="$PROJECT" record-sets transaction remove $OLDIP --name=$NAME --ttl=5 --type=A --zone=$ZONE
  gcloud dns --project="$PROJECT" record-sets transaction add $IP_ADDRESS --name=$NAME --ttl=5 --type=A --zone=$ZONE
  gcloud dns --project="$PROJECT" record-sets transaction execute --zone=$ZONE
fi

# Update Packages
# This is slow, we should only do this every week or so.
echo "APT"
apt update
apt upgrade

echo "DONE"

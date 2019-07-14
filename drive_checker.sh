#!/bin/bash
user=""
for i in $(cat full_list.txt); do
#for i in $(grep "address =" ${1}/*.conf | awk -F "\"" '{print $2}'); do

if ssh -A ${user}@${i} '[ -d /opt/MegaRAID/MegaCli/ ]' ;then
  ssh -A ${user}@${i} hostname
  echo "megaraid exists. Lets try to check for errors.."
  echo "Checking ip ${i} "
  errors=$(ssh -A ${user}@${i} sudo /opt/MegaRAID/MegaCli/lsi.sh errors | grep -i "error" -B1)
  num_drives=$(ssh -A ${user}@${i} sudo /opt/MegaRAID/MegaCli/lsi.sh drives | wc -l)
  if [ -n "${errors}" ]; then
      echo "${errors}"
      echo "Total number of Drives for ip: ${i} " ${num_drives}
      echo ""
  fi
else
  echo "Megaraid does not exist on ${i}"
fi
done

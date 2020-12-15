#!/bin/bash

SITE_NAME=""
for i in "$@"
do
  case $i in
      --siteName=*)
        SITE_NAME="${i#*=}"
        shift # past argument=value
      ;;
      *)
      ;;
  esac
done

if [ "$SITE_NAME" <> "rwinkwavu" && "$SITE_NAME" <> "butaro" ]; then
      echo "You must specify either -- siteName=butaro or --siteName=rwinkwavu"
      exit 1
fi

ansible-playbook \
  -i inventories/test/hosts \
  -l vagrant \
  -e "ansible_user=vagrant ansible_ssh_pass=vagrant ansible_sudo_pass=vagrant openmrs_distro_site=${siteName}" \
  playbooks/rwandaemr-2x.yml \
  -vvvvvvvvvvvvvvv


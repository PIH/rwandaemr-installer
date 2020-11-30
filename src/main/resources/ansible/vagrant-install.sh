#!/bin/bash

ansible-playbook \
  -i inventories/test/hosts \
  -l vagrant \
  -e "ansible_user=vagrant ansible_ssh_pass=vagrant ansible_sudo_pass=vagrant" \
  playbooks/rwandaemr-2x.yml \
  -vvvvvvvvvvvvvvv


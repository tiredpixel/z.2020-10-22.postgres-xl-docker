#!/bin/bash

set -e

ssh-keygen -f .ssh/id_rsa -N '' -q

ssh-keyscan localhost >> .ssh/known_hosts

ln -s id_rsa.pub .ssh/authorized_keys

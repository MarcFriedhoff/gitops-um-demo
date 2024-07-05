#!/bin/bash

BASE_DIR=$(pwd) envsubst < kube-play.yaml # | podman kube play -
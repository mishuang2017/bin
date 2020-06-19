#!/bin/bash

git send-email /labhome/chrism/sflow/ovs_review/2/* --to=roniba@mellanox.com \
	  --cc=majd@mellanox.com \
	  --cc=maord@mellanox.com \
	  --cc=ozsh@mellanox.com \
	  --cc=chrism@mellanox.com \
	  --suppress-cc=all

#!/bin/bash

source ./wmLHEGEN.sh $1 $2
source ./SIM.sh
for i in {1..5}; do
    source ./DIGIPremix.sh && break
    sleep 3
done
source ./HLT.sh
source ./RECO.sh
source ./MiniAODv2.sh
#source ./customizedNanoAOD.sh

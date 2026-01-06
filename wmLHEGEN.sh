#!/bin/bash

export HOME=`pwd`
export EVENTS=$1
export NODE_HASH=$(hostname | cksum | awk '{print $1}')

# Binds for singularity containers
# Mount /afs, /eos, /cvmfs, /etc/grid-security for xrootd
export APPTAINER_BINDPATH='/afs,/cvmfs,/cvmfs/grid.cern.ch/etc/grid-security:/etc/grid-security,/eos,/etc/pki/ca-trust,/run/user,/var/run/user'

cat <<'EndOfGenScriptFile' > wmLHEGEN_gen_script.sh

echo "Running CMS GEN request script using cms-sw containers. Architecture: el9:x86_64"
python3 -m venv cms_gen_venv_wmLHEGEN && source ./cms_gen_venv_wmLHEGEN/bin/activate

# Install the PdmV REST client
pip install git+https://github.com/cms-PdmV/mcm_scripts &> /dev/null

echo "Packages installed"
pip freeze
echo ""

# GEN Script begin
rm -f request_fragment_check.py
wget -q https://gitlab.cern.ch/cms-gen/genproductions_scripts/-/raw/master/bin/utils/request_fragment_check.py
chmod +x request_fragment_check.py

./request_fragment_check.py --bypass_status --prepid wmLHEGEN

# End of CMS GEN script file: wmLHEGEN_gen_script.sh
EndOfGenScriptFile
chmod +x wmLHEGEN_gen_script.sh

# Run in singularity container
singularity run --home $PWD:$PWD /cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el9:x86_64 $(echo $(pwd)/wmLHEGEN_gen_script.sh)

GEN_ERR=$?
if [ $GEN_ERR -ne 0 ]; then
  echo "GEN Checking Script returned exit code $GEN_ERR which means there are $GEN_ERR errors"
  echo "Validation WILL NOT RUN"
  echo "Please correct errors in the request and run validation again"
  exit $GEN_ERR
fi
echo "Running VALIDATION. GEN Request Checking Script returned no errors"
# GEN Script end

# Download fragment from McM
#curl -s -k https://cms-pdmv-prod.web.cern.ch/mcm/public/restapi/requests/get_fragment/wmLHEGEN --retry 3 --create-dirs -o Configuration/GenProduction/python/wmLHEGEN-fragment.py
mkdir -p Configuration/GenProduction/python/
cp ./fragment.py Configuration/GenProduction/python/wmLHEGEN-fragment.py
[ -s Configuration/GenProduction/python/wmLHEGEN-fragment.py ] || exit $?;

# Check if fragment contais gridpack path ant that it is in cvmfs
#if grep -q "gridpacks" Configuration/GenProduction/python/wmLHEGEN-fragment.py; then
#  if ! grep -q -e "/cvmfs/cms.cern.ch/phys_generator/gridpacks" -e "/cvmfs/cms-griddata.cern.ch/phys_generator/gridpacks_tarball" Configuration/GenProduction/python/wmLHEGEN-fragment.py; then
#    echo "Gridpack inside fragment is not in cvmfs."
#    exit -1
#  fi
#fi

# Dump actual test code to a wmLHEGEN_test.sh file that can be run in Singularity
cat <<'EndOfTestFile' > wmLHEGEN_test.sh

export SCRAM_ARCH=slc7_amd64_gcc700

source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_10_6_30_patch1/src ] ; then
  echo release CMSSW_10_6_30_patch1 already exists
else
  scram p CMSSW CMSSW_10_6_30_patch1
fi
cd CMSSW_10_6_30_patch1/src
eval `scram runtime -sh`

mv ../../Configuration .
scram b
cd ../..

# cmsDriver command
cmsDriver.py Configuration/GenProduction/python/wmLHEGEN-fragment.py --eventcontent RAWSIM,LHE --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN,LHE --conditions 106X_upgrade2018_realistic_v4 --beamspot Realistic25ns13TeVEarly2018Collision --customise_commands "process.source.numberEventsInLuminosityBlock=cms.untracked.uint32(100); process.RandomNumberGeneratorService.externalLHEProducer.initialSeed=$((NODE_HASH%1000000+1))" --step LHE,GEN --geometry DB:Extended --era Run2_2018 --python_filename wmLHEGEN_cfg.py --fileout file:wmLHEGEN.root --number $EVENTS --number_out $EVENTS --no_exec --mc || exit $? ;

# Run generated config
REPORT_NAME=wmLHEGEN_report.xml
# Run the cmsRun
exec >/dev/null 2>&1; cmsRun -e -j $REPORT_NAME wmLHEGEN_cfg.py || exit $? ;

# Parse values from wmLHEGEN_report.xml report
processedEvents=$(grep -Po "(?<=<Metric Name=\"NumberEvents\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
producedEvents=$(grep -Po "(?<=<TotalEvents>)(\d*)(?=</TotalEvents>)" $REPORT_NAME | tail -n 1)
threads=$(grep -Po "(?<=<Metric Name=\"NumberOfThreads\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
peakValueRss=$(grep -Po "(?<=<Metric Name=\"PeakValueRss\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
peakValueVsize=$(grep -Po "(?<=<Metric Name=\"PeakValueVsize\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalSize=$(grep -Po "(?<=<Metric Name=\"Timing-tstoragefile-write-totalMegabytes\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalSizeAlt=$(grep -Po "(?<=<Metric Name=\"Timing-file-write-totalMegabytes\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalJobTime=$(grep -Po "(?<=<Metric Name=\"TotalJobTime\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
totalJobCPU=$(grep -Po "(?<=<Metric Name=\"TotalJobCPU\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
eventThroughput=$(grep -Po "(?<=<Metric Name=\"EventThroughput\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
avgEventTime=$(grep -Po "(?<=<Metric Name=\"AvgEventTime\" Value=\")(.*)(?=\"/>)" $REPORT_NAME | tail -n 1)
if [ -z "$threads" ]; then
  echo "Could not find NumberOfThreads in report, defaulting to 1"
  threads=1
fi
if [ -z "$eventThroughput" ]; then
  eventThroughput=$(bc -l <<< "scale=4; 1 / ($avgEventTime / $threads)")
fi
if [ -z "$totalSize" ]; then
  totalSize=$totalSizeAlt
fi
if [ -z "$processedEvents" ]; then
  processedEvents=$EVENTS
fi
echo "Validation report of wmLHEGEN sequence 1/1"
echo "Processed events: $processedEvents"
echo "Produced events: $producedEvents"
echo "Threads: $threads"
echo "Peak value RSS: $peakValueRss MB"
echo "Peak value Vsize: $peakValueVsize MB"
echo "Total size: $totalSize MB"
echo "Total job time: $totalJobTime s"
echo "Total CPU time: $totalJobCPU s"
echo "Event throughput: $eventThroughput"
echo "CPU efficiency: "$(bc -l <<< "scale=2; ($totalJobCPU * 100) / ($threads * $totalJobTime)")" %"
echo "Size per event: "$(bc -l <<< "scale=4; ($totalSize * 1024 / $producedEvents)")" kB"
echo "Time per event: "$(bc -l <<< "scale=4; (1 / $eventThroughput)")" s"
echo "Filter efficiency percent: "$(bc -l <<< "scale=8; ($producedEvents * 100) / $processedEvents")" %"
echo "Filter efficiency fraction: "$(bc -l <<< "scale=10; ($producedEvents) / $processedEvents")

# End of wmLHEGEN_test.sh file
EndOfTestFile

# Make file executable
sed -i "s/\$EVENTS/$EVENTS/g" wmLHEGEN_test.sh
chmod +x wmLHEGEN_test.sh

if [ -e "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el7:amd64" ]; then
  CONTAINER_NAME="el7:amd64"
elif [ -e "/cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/el7:x86_64" ]; then
  CONTAINER_NAME="el7:x86_64"
else
  echo "Could not find amd64 or x86_64 for el7"
  exit 1
fi
# Run in singularity container
export SINGULARITY_CACHEDIR="/tmp/$(whoami)/singularity"
singularity run --home $PWD:$PWD /cvmfs/unpacked.cern.ch/registry.hub.docker.com/cmssw/$CONTAINER_NAME $(echo $(pwd)/wmLHEGEN_test.sh)

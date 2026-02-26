import FWCore.ParameterSet.Config as cms

# link to cards:
# https://github.com/cms-sw/genproductions/tree/80fc1ec5df92c7fcb97a2b6300eeb5db815a3558/bin/MadGraph5_aMCatNLO/cards/production/2017/13TeV/DYJets_HT_LO_MLM/DYJetsToQQ_HT/DYJetsToQQ_HT180toInf

externalLHEProducer = cms.EDProducer("ExternalLHEProducer",
    #args = cms.vstring('/cvmfs/cms.cern.ch/phys_generator/gridpacks/2017/13TeV/madgraph/V5_2.4.2/DYJetsToQQ_HT180toInf/v1/DYJetsToQQ_HT180toInf_slc6_amd64_gcc481_CMSSW_7_1_30_tarball.tar.xz'),
    args = cms.vstring('/afs/cern.ch/user/d/dfu/public/DYJetsToQQG_HT180toInf_slc7_amd64_gcc700_CMSSW_10_6_19_tarball.tar.xz'),
    nEvents = cms.untracked.uint32(5000),
    numberOfParameters = cms.uint32(1),
    outputFile = cms.string('cmsgrid_final.lhe'),
    scriptName = cms.FileInPath('GeneratorInterface/LHEInterface/data/run_generic_tarball_cvmfs.sh')
)

from Configuration.Generator.Pythia8CommonSettings_cfi import *
from Configuration.Generator.MCTunes2017.PythiaCP5Settings_cfi import *

generator = cms.EDFilter("Pythia8HadronizerFilter",
    maxEventsToPrint = cms.untracked.int32(1),
    pythiaPylistVerbosity = cms.untracked.int32(1),
    filterEfficiency = cms.untracked.double(1.0),
    pythiaHepMCVerbosity = cms.untracked.bool(False),
    comEnergy = cms.double(13000.),
    PythiaParameters = cms.PSet(
        pythia8CommonSettingsBlock,
        pythia8CP5SettingsBlock,
        processParameters = cms.vstring(
            'JetMatching:setMad = off',
            'JetMatching:scheme = 1',
            'JetMatching:merge = on',
            'JetMatching:jetAlgorithm = 2',
            'JetMatching:etaJetMax = 5.',
            'JetMatching:coneRadius = 1.',
            'JetMatching:slowJetPower = 1',
            'JetMatching:qCut = 20.', #this is the actual merging scale
            'JetMatching:nQmatch = 5', #4 corresponds to 4-flavour scheme (no matching of b-quarks), 5 for 5-flavour scheme
            'JetMatching:nJetMax = 4', #number of partons in born matrix element for highest multiplicity
            'JetMatching:doShowerKt = off', #off for MLM matching, turn on for shower-kT matching
            
            #PSweights
        	'UncertaintyBands:doVariations = on',
			# 3 sets of variations for ISR&FSR up/down
		# Reduced sqrt(2)/(1/sqrt(2)), Default 2/0.5 and Conservative 4/0.25 variations
        'UncertaintyBands:List = {\
		isrRedHi isr:muRfac=0.707,fsrRedHi fsr:muRfac=0.707,isrRedLo isr:muRfac=1.414,fsrRedLo fsr:muRfac=1.414,\
		isrDefHi isr:muRfac=0.5, fsrDefHi fsr:muRfac=0.5,isrDefLo isr:muRfac=2.0,fsrDefLo fsr:muRfac=2.0,\
		isrConHi isr:muRfac=0.25, fsrConHi fsr:muRfac=0.25,isrConLo isr:muRfac=4.0,fsrConLo fsr:muRfac=4.0}',

        'UncertaintyBands:MPIshowers = on',
        'UncertaintyBands:overSampleFSR = 10.0',
        'UncertaintyBands:overSampleISR = 10.0',
        'UncertaintyBands:FSRpTmin2Fac = 20',
        'UncertaintyBands:ISRpTmin2Fac = 1'
        ),
        parameterSets = cms.vstring('pythia8CommonSettings',
                                    'pythia8CP5Settings',
                                    'processParameters',
                                    )
    )
)

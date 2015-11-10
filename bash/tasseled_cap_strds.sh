#!/bin/bash

##--------------------------------------------------------------------------------------------------------------
##
## Calculate Tasseled cap
##   Ben DeVries
##   26/02/2015
##
##
## Kennedy, R. E., Yang, Z., & Cohen, W. B. (2010). Detecting trends in forest disturbance and recovery 
##   using yearly Landsat time series: 1. LandTrendr - Temporal segmentation algorithms. Remote Sensing of Environment, 
##   114(12), 2897–2910. doi:10.1016/j.rse.2010.07.008
##     Methods (Section 2.3.4):
##      "Because the normalization process makes the spectral space relatively consistent across sensors, 
##       it is imperative that a single spectral transformation be used for all images in the LTS. We chose the 
##       tasseledcap transformation, and used the coefficients defined for reflectance data (Crist, 1985), 
##       regardless of Landsat sensor."
##
## Crist, E. (1985). A TM Tasseled Cap Equivalent Transformation for Reflectance Factor Data. Remote Sensing of Environment, 
##   306, 301–306. Retrieved from http://www.sciencedirect.com/science/article/pii/0034425785901026
##
##
##--------------------------------------------------------------------------------------------------------------

## BEFORE RUNNING THIS SCRIPT:
## set the GRASS_BATCH_JOB variable to equal the full path to this script:
## export GRASS_BATCH_JOB=/path/to/script.sh
## see http://grasswiki.osgeo.org/wiki/GRASS_and_Shell for more info

## call GRASS with the location/name of the target mapset as the argument. e.g.:
## grass70 /path/to/grassdata/name_of_location/PERMANENT

## to use GRASS interactively again, unset the GRASS_BATCH_JOB variable:
## unset GRASS_BATCH_JOB

# GRASS settings
export GRASS_MESSAGE_FORMAT=plain

# TC coefficients
brightness=( 0.2043 0.4158 0.5524 0.5741 0.3124 0.2303 )
greenness=( "-0.1603" 0.2819 "-0.4934" 0.7940 "-0.0002" "-0.1446" )
wetness=( 0.0315 0.2021 0.3102 0.1594 "-0.6806" "-0.6109" )
#fourth=( "-0.2117" "-0.0284" 0.1302 "-0.1007" 0.6529 "-0.7078" )
#fifth=( "-0.8669" "-0.1835" 0.3856 0.0408 0.1132 0.2272 )
#sixth=( 0.3677 "-0.8200" 0.4354 0.0518 0.066 "-0.0104" )

# names of stdrs corresponding to input bands
bands=( kafa_blue kafa_green kafa_red kafa_NIR kafa_SWIR1 kafa_SWIR2 )

# expression strings for t.rast.mapcalc (IMPORTANT: spaces not allowed between operations -- interpreted differently by bash)
tcBright="(${brightness[0]}*${bands[0]})+(${brightness[1]}*${bands[1]})+(${brightness[2]}*${bands[2]})+(${brightness[3]}*${bands[3]})+(${brightness[4]}*${bands[4]})+(${brightness[5]}*${bands[5]})"
tcGreen="(${greenness[0]}*${bands[0]})+(${greenness[1]}*${bands[1]})+(${greenness[2]}*${bands[2]})+(${greenness[3]}*${bands[3]})+(${greenness[4]}*${bands[4]})+(${greenness[5]}*${bands[5]})"
tcWet="(${wetness[0]}*${bands[0]})+(${wetness[1]}*${bands[1]})+(${wetness[2]}*${bands[2]})+(${wetness[3]}*${bands[3]})+(${wetness[4]}*${bands[4]})+(${wetness[5]}*${bands[5]})"

# compute indices
echo Computing brightness @ $(date +%T)...
t.rast.mapcalc inputs=${bands[0]},${bands[1]},${bands[2]},${bands[3]},${bands[4]},${bands[5]} expression=$tcBright --o output=kafa_tcBright basename=tcBright
echo Computing greenness @ $(date +%T)...
t.rast.mapcalc inputs=${bands[0]},${bands[1]},${bands[2]},${bands[3]},${bands[4]},${bands[5]} expression=$tcGreen --o output=kafa_tcGreen basename=tcGreen
echo Computing wetness @ $(date +%T)...
t.rast.mapcalc inputs=${bands[0]},${bands[1]},${bands[2]},${bands[3]},${bands[4]},${bands[5]} expression=$tcWet --o output=kafa_tcWet basename=tcWet
echo Computing TCA @ $(date +%T)...
t.rast.mapcalc inputs=kafa_tcBright,kafa_tcGreen expression="atan(kafa_tcGreen,kafa_tcBright)" --o output=kafa_TCA basename=TCA
echo Finished @ $(date +%T)

exit
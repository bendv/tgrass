# tgrass
Some tools for working with LTS in TGRASS

## Download GRASS 7
<a href="https://grass.osgeo.org/grass7/" target="_blank">Go here</a>

## Create a new location from EPSG code
Locations can be created using existing geospatial datasets as templates, or using an EPSG code. I wanted to create one for <a href="http://spatialreference.org/ref/epsg/wgs-84-utm-zone-36n/" target="_blank">UTM zone 36N</a> for my study area (Kafa) in southern Ethiopia:

```
cd /some/directory/
mkdir grassdata
cd grassdata
grass70 -c EPSG:32636 ./kafa_UTM36N
```

## Install spgrass7 and bfastSpatial in R
```
install.packages("spgrass7", repos="http://R-Forge.R-project.org")
library(devtools)
install_github("dutri001/bfastSpatial")
```

## Create spatio-temporal raster data set (strds) from a directory of .tif files
I have a directory with .tif files representing separate SWIR2 (band 7) layers and I want to register these into a spatio-temporal raster data set using GRASS 7.

![File List](https://github.com/bendv/tgrass/blob/master/img/file_list.png)

First, open up a GRASS session (assuming you have created the appriate LOCATION above)

```
grass70 --text
```

Then, run the Rscript ```create_stdrs_Landsat.R``` *within* your GRASS session as follows:

```
Rscript ./grassdata/R/create_strds_Landsat.R ./01_tif SWIR2 kafa_SWIR2 "Kafa SWIR2 LTS" "Kafa SWIR2 LTS" 10 overwrite
```

Running ```t.info kafa_SWIR2``` for this new strds shows the following:

![t.info](https://github.com/bendv/tgrass/blob/master/img/t_info.png)

## Update an strds with newly downloaded scenes
New scenes downloaded and still compressed (.tar.gz) can be added to an existing strds using ```update_strds_Landsat.R```

```
Rscript ./update_strds_Landsat.R kafa_SWIR2 ./00_tar/new ./01_tif SWIR2 SWIR2 1
```

The arguments are: (1) strds, (2) input directory, (3) output directory for processed layers, (4) search pattern, (5) layer tag, (6) cpus



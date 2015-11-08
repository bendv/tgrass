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

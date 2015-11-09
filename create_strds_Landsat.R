##-------------------------------------------------------------------------------------------------------------------------------------
##
## Script to to search all Landsat .tif files in a path, import them into a GRASS LOCATION, and register to a strds
##  Ben DeVries
##  18-02-15; updated 08-11-15
##
## usage:
##  To be called within a GRASS session. Start GRASS with the command "grass70 -text" and then run:
##	  Rscript create_strds_Landsat.R search_path pattern strds title description cpus ['overwrite']
##
## parameters:
##    - search_path: path containing Landsat scene folders
##    - pattern: pattern indicating which band to use. For spectral bands, this should be one of 'blue', 'green', 'red', 'NIR', 'SWIR1', or 'SWIR2', but not the band numbers (since these are different between L5/7 and L8). Otherwise, other metrics can like 'NDVI', 'NDMI', 'NBR', 'NBR2', 'SAVI', 'MSAVI', or 'EVI', can be used
##    - strds: name of the strds to be created
##    - title: title of the strds
##    - description: description of the strds
##    - cpus: number of cpus (1 for sequential; > 1 for parallel processing)
##    - overwrite: (optional); if included, strds and existing raster maps will be overwritten without prompt
##
## requires:
##    - bfastSpatial:
##        library(devtools)
##        install_github('dutri001/bfastSpatial')
##    - spgrass6: 
##        install.packages('spgrass6')
##
## notes:
##    - this script must be run in the command line from within a GRASS session
##	  - search_path contains subfolders for each scene (with appropriate names)
##	  - .tif format is assumed for input files (uses r.in.gdal)
##    - .tif filenames must contain standard Landsat scene ID strings (see ?bfastSpatial::getSceneinfo)
##	  - the script assumes that a LOCATION set up
##	  - this script will then create the strds in LOCATION and import raster maps into the PERMANENT mapset and register to the strds
##    - individual map names in the strds consist of the Landsat sceneID + '_' + pattern
##
##-------------------------------------------------------------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
path <- args[1]
pattern <- args[2]
strds <- args[3]
title <- sprintf("\'%s\'", args[4])
desc <- sprintf("\'%s\'", args[5])
cpus <- as.numeric(args[6])
if(length(args) > 6 & args[7] == 'overwrite') {
  overwrite = TRUE
} else {
  overwrite = FALSE
}

cat('\n#############################\n')
cat('Creating ', strds, ' and registering all ', pattern, ' scenes in ', path, '.\n', sep = '')
cat('#############################\n\n')

library(bfastSpatial)
library(spgrass7)
setwd(path)
loc <- Sys.setlocale('LC_TIME', 'en_US.utf-8')

# create the strds
if(overwrite) {
  command <- sprintf("t.create --o type=strds temporaltype=absolute output=%s title=%s description=%s", strds, title, desc)
} else {
  command <- sprintf("t.create type=strds temporaltype=absolute output=%s title=%s description=%s", strds, title, desc)
}
system(command)

# function for batch import and timestamping of raster maps
r.in.gdal.timestamp <- function(r, name, date) {
  if(overwrite) {
    execGRASS("r.in.gdal", parameters = list(input = r, output = name), flags = c("overwrite"))
  } else {
    execGRASS("r.in.gdal", parameters = list(input = r, output = name))
  }
  execGRASS("r.timestamp", parameters = list(map = name, date = date))
}

# convert band 'tag' if spectral bands, otherwise use literal search
if(pattern %in% c("blue", "green", "red", "NIR", "SWIR1", "SWIR2")) {
  
  lut <- data.frame(band = c("blue", "green", "red", "NIR", "SWIR1", "SWIR2"),
                    TMETM = sprintf("band%s", c(1:5, 7)),
                    OLI = sprintf("band%s", c(2:7)),
                    stringsAsFactors = FALSE)
  
  srch1 <- glob2rx(sprintf("*%s*.tif", lut$TMETM[lut$band == pattern]))
  srch2 <- glob2rx(sprintf("*%s*.tif", lut$OLI[lut$band == pattern]))
  fl1 <- list.files(pattern = srch1, recursive = TRUE)
  s1 <- getSceneinfo(fl1)
  fl1 <- fl1[s1$sensor %in% c("TM", "ETM+ SLC-on", "ETM+ SLC-off")]
  fl2 <- list.files(pattern = srch2, recursive = TRUE)
  s2 <- getSceneinfo(fl2)
  fl2 <- fl2[s2$sensor == "OLI"]
  fl <- c(fl1, fl2)
  
} else {
  
  srch <- glob2rx(sprintf("*%s*.tif", pattern))
  fl <- list.files(pattern = srch, recursive = TRUE)
  
}

# get scene info and sort by date
s <- getSceneinfo(fl)
fl <- fl[order(s$date)]
s <- getSceneinfo(fl)

# format dates for r.datestamp
dates <- tolower(format(s$date, format = "%d %b %Y"))

# apply function over all scenes
if(cpus == 1) {
  for(i in 1:length(fl)) {
    label <- sprintf("%s_%s", row.names(s)[i], pattern)
    r.in.gdal.timestamp(fl[i], label, dates[i])
  }
} else if(cpus > 1) {
  library(doMC)
  registerDoMC(cores = cpus)
  junk <- foreach(i = 1:length(fl)) %dopar% {
    label <- sprintf("%s_%s", row.names(s)[i], pattern)
    r.in.gdal.timestamp(fl[i], label, dates[i])
  }
}

# write .txt with start and end times for registering the raster maps to the 
sname <- sprintf("%s_%s", row.names(s), pattern)
start_date <- as.character(s$date)
end_date <- as.character(s$date + 1) # 1 day later
lines <- sprintf("%s|%s|%s", sname, start_date, end_date)
fileConn <- file('scenes_time.txt', open = "w")
writeLines(lines, fileConn)
close(fileConn)

# register all scenes in the strds
if(overwrite) {
  command <- sprintf("t.register --o input=%s file=scenes_time.txt", strds)
} else {
  command <- sprintf("t.register input=%s file=scenes_time.txt", strds)
}
system(command)
junk <- file.remove('scenes_time.txt')

# show info
system(sprintf("t.info type=strds input=%s", strds))
cat("\n\nFinished.")

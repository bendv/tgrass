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
##    - pattern: pattern indicating which band to use (e.g. 'band1', 'NDVI', etc...)
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
##    - search_path contains subfolders for each scene (with appropriate names)
##    - .tif format is assumed for input files (uses r.in.gdal)
##    - .tif filenames must contain standard Landsat scene ID strings (see ?bfastSpatial::getSceneinfo)
##    - the script assumes that a LOCATION set up
##    - this script will then create the strds in LOCATION and import raster maps into the PERMANENT mapset and register to the strds
##    - individual map names in the strds consist of the Landsat sceneID + '_' + pattern
##
##-------------------------------------------------------------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
path <- args[1]
pattern <- args[2]
strds <- args[3]
title <- paste("\'", args[4], "\'", sep = '')
desc <- paste("\'", args[5], "\'", sep = '')
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
library(spgrass6)
setwd(path)
loc <- Sys.setlocale('LC_TIME', 'en_US.utf-8')

# create the strds
if(overwrite) {
  command <- paste('t.create --o type=strds temporaltype=absolute output=', strds, ' title=', title, ' description=', desc, sep = '')
} else {
  command <- paste('t.create type=strds temporaltype=absolute output=', strds, ' title=', title, ' description=', desc, sep = '')
}
system(command)

# list scene folders and scene info
fl <- list.files()
s <- getSceneinfo(fl)

# format dates for r.datestamp
dates <- tolower(format(s$date, format = '%d %b %Y'))

# function for batch import and timestamping of raster maps
r.in.gdal.timestamp <- function(r, name, date) {
  if(overwrite) {
    execGRASS('r.in.gdal', parameters = list(input = r, output = name), flags = c("overwrite"))
  } else {
    execGRASS('r.in.gdal', parameters = list(input = r, output = name))
  }
  execGRASS('r.timestamp', parameters = list(map = name, date = date))
}

# list all .tif files (with pattern (e.g. all blue band))
srch <- glob2rx(paste('*', pattern, '*.tif', sep = ''))
files <- list.files(pattern = srch, recursive = TRUE)

# apply function over all scenes
if(cpus == 1) {
  for(i in 1:length(fl)) {
    label <- paste(row.names(s)[i], "_", pattern, sep='')
    r.in.gdal.timestamp(files[i], label, dates[i])
  }
} else if(cpus > 1) {
  library(doMC)
  registerDoMC(cores = cpus)
  junk <- foreach(i = 1:length(fl)) %dopar% {
    label <- paste(row.names(s)[i], "_", pattern, sep='')
    r.in.gdal.timestamp(files[i], label, dates[i])
  }
}

# write .txt with start and end times for registering the raster maps to the 
sname <- paste(row.names(s), "_", pattern, sep = '')
start_date <- as.character(s$date)
end_date <- as.character(s$date + 1) # 1 day later
lines <- paste(sname, start_date, end_date, sep = '|')
fileConn <- file('scenes_time.txt', open = 'w')
writeLines(lines, fileConn)
close(fileConn)

# register all scenes in the strds
if(overwrite) {
  command <- paste('t.register --o input=', strds, ' file=scenes_time.txt', sep='')
} else {
  command <- paste('t.register input=', strds, ' file=scenes_time.txt', sep='')
}
system(command)
junk <- file.remove('scenes_time.txt')

# show info
system(paste('t.info type=strds input=', strds, sep = ''))
cat('\n\nFinished.')

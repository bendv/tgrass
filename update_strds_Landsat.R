##--------------------------------------------------------------------------------------
##
## Update existing strds with new scenes in .tar.gz format
##   Ben DeVries
##   19-02-14, updated 10-11-15
##
##   Usage:
##     <from within GRASS session>
##     Rscript update_strds_Landsat.R strds /path/to/scene(s)[.tar.gz] /path/to/outdir pattern label cpus [overwrite]
##
##   Notes:
##     - scenes were downloaded via http://espa.cr.usgs.gov
##     - gtiff format was requested
##     - scene .tar.gz file must be named according to Landsat scene name convention
##     - only one band at a time is processed with this script (using 'pattern')
##     - cloud masking is done automatically by searching for the *cfmask.tif band
##
##-------------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
strds <- args[1]
fl <- args[2]
outdir <- args[3]
pattern <- args[4]
label <- args[5]
cpus <- as.numeric(args[6])
if(length(args) > 6 & args[7] == 'overwrite') {
  overwrite = TRUE
} else {
  overwrite = FALSE
}

library(bfastSpatial)
library(spgrass7)
junk <- Sys.setlocale('LC_TIME', 'en_US.utf-8')

# check if fl is a filename or a folder
# if it's a folder, replace fl with all .tar.gz files within that folder
if(file.info(fl)$isdir) {
  fl <- list.files(fl, pattern = glob2rx("*.tar.gz"), full.names = TRUE)
}

# get timestamp from fl
s <- getSceneinfo(fl)
dates <- tolower(format(s$date, format = '%d %b %Y'))
end_dates <- tolower(format(s$date + 1, format = '%d %b %Y'))

# function for batch import and timestamping of raster maps
r.in.gdal.timestamp <- function(r, name, date) {
  if(!overwrite) {
    system(sprintf("r.in.gdal input=%s output=%s", r, name))
  } else {
    system(sprintf("r.in.gdal --o input=%s output=%s", r, name))
  }
  system(sprintf("r.timestamp map=%s date=\'%s\'", name, date))
}

# look-up table if spectral bands are needed (not applicable for metrics)
lut <- data.frame(band = c("blue", "green", "red", "NIR", "SWIR1", "SWIR2"),
                  TMETM = sprintf("sr_band%s", c(1:5, 7)),
                  OLI = sprintf("sr_band%s", c(2:7)),
                  stringsAsFactors = FALSE)

# loop through fl and extract appropriate bands
if(cpus == 1) {
  for(i in 1:length(fl)) {
    
    if(pattern %in% c("blue", "green", "red", "NIR", "SWIR1", "SWIR2")) {
      if(s$sensor[i] == "OLI") {
        vi <- lut$OLI[lut$band == pattern]
      } else {
        vi <- lut$TMETM[lut$band == pattern]
      }
    } else {
      vi <- pattern
    }
    
    # process appropriate bands
    processLandsat(fl[i], vi = vi, srdir = ".", outdir = outdir, delete = TRUE, mask = "cfmask", fileExt = "tif", overwrite = overwrite)
    
    # import raster maps with timestamps to mapset
    sname <- sprintf("%s_%s", row.names(s)[i], label)
    outfl <- sprintf('%s/%s.%s.tif', outdir, vi, row.names(s)[i])
    r.in.gdal.timestamp(outfl, sname, dates[i])
    
    # write .txt with start and end times for registering the raster maps to the strds
    start_date <- as.character(s$date[i])
    end_date <- as.character(s$date[i] + 1) # 1 day later
    lines <- sprintf("%s|%s|%s", sname, start_date, end_date)
    if(i == 1) {
      fileConn <- file('scenes_time.txt', open = 'w')
    } else {
      fileConn <- file('scenes_time.txt', open = 'a')
    }
    writeLines(lines, fileConn)
    close(fileConn)
  }
} else {
  ## TODO: multi-core
}


# register to strds
command <- sprintf("t.register input=%s file=scenes_time.txt", strds)
system(command)
junk <- file.remove("scenes_time.txt")

# show info
system(sprintf("t.info type=strds input=%s", strds))
cat("\n\nFinished.")

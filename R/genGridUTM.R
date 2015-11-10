#' @title Generate UTM tile grid
#' @description Generates a data.frame of tile extents: ie. (xmin, xmax, ymin, ymax) for each tile

#' @param tilesize Numeric. Size of the output tiles (in # pixels)
#' @param extent Extent. Full extent of the scene
#' @param res Numeric. Spatial resolution of the image
#' @param overlap Numeric. Overlapping region (in # pixels)
#' @param polygon Logical. Also return a SpatialPolygons* object?
#' @param prj Character. CRS of the polygon if \code{polygon=TRUE}
#' 
#' @return A \code{data.frame}, or list of \code{data.frame} and \code{SpatialPolygons} if \code{polygon=TRUE}
#' 
#' @author Ben DeVries
#' @import raster
#' @export

genGridUTM <-
  function(tilesize, extent, res, overlap=NULL, polygon=FALSE, prj=NULL)

  {
    # take the first element of res, if length > 1
    if(length(res) > 1)
      res <- res[1]
    
    # set overlap value (in m)
    if(is.null(overlap))
      overlap <- 0
    
    # divide overlap by 2, since extension will go in both directions
    overlap <- overlap / 2
    
    width <- xmax(extent) - xmin(extent)
    height <- ymax(extent) - ymin(extent)
    
    if(width <= (tilesize * res)) {
      xmins <- xmin(extent)
      xmaxes <- xmax(extent)
    } else {
      xmins <- seq(xmin(extent), xmax(extent), by=tilesize*res)
      xmaxes <- c(xmins[2:length(xmins)], xmax(extent))
    }
    
    if(height <= (tilesize * res)) {
      ymins <- ymin(extent)
      ymaxes <- ymax(extent)
    } else {
      ymins <- seq(ymin(extent), ymax(extent), by=tilesize*res)
      ymaxes <- c(ymins[2:length(ymins)], ymax(extent))
    }
    
    # extend extents by overlap
    if (FALSE){
      xmins <- c(xmins[1], xmins[2:length(xmins)] - overlap*res)
      ymins <- c(ymins[1], ymins[2:length(ymins)] - overlap*res)
      xmaxes <- c(xmaxes[1:length(xmaxes)-1] + overlap*res, xmaxes[length(xmaxes)])
      ymaxes <- c(ymaxes[1:length(ymaxes)-1] + overlap*res, ymaxes[length(ymaxes)])
    }
    
    # permute mins and maxes to get all possible extents    
    tiles <- expand.grid(xmins, ymins)
    colnames(tiles) <- c("xmin", "ymin")
    
    temp <- expand.grid(xmaxes, ymaxes)
    tiles$xmax <- temp[,1]
    tiles$ymax <- temp[,2]
    
    # reorder the columns so that each row matches a raster extent object
    tiles <- cbind(tiles$xmin, tiles$xmax, tiles$ymin, tiles$ymax)
    colnames(tiles) <- c("xmin", "xmax", "ymin", "ymax")
    
    # generate tile names that can be used when writing subsets to file
    # in the form "row.column", starting from the bottom left tile ("1.1")
    ind <- NULL
    for (j in 1:length(ymins)){
      for (i in 1:length(xmins)){
        ind <- c(ind, paste(j, "-", i, sep=""))
      }
    }
    row.names(tiles) <- ind
    
    # delete redundant rows (ie. where xmin==xmax or ymin==ymax)
    #tiles <- tiles[-which(tiles[,1]==tiles[,2] | tiles[,3]==tiles[,4]),]
    
    # optional: output a SpatialPolygons object for visualization of tiles
    if(polygon){
      
      require(maptools)
      
      if(is.null(prj)){
        warning("No projection provided. Defaulting to WGR1984 UTM zone 1")
        prj <- CRS("+proj=utm +zone=1 +ellps=WGS84 +units=m +no_defs")
      }
      
      poly <- as(extent(tiles[1,]), "SpatialPolygons")
      proj4string(poly) <- prj
      poly <- spChFIDs(poly, row.names(tiles)[1])
      
      for(i in 2:nrow(tiles)){
        tmp <- as(extent(tiles[i, ]), "SpatialPolygons")
        proj4string(tmp) <- prj
        tmp <- spChFIDs(tmp, row.names(tiles)[i])
        poly <- spRbind(poly, tmp)
      }
      
      poly <- SpatialPolygonsDataFrame(poly, data = as.data.frame(tiles))
    }
    
    if(polygon)
      tiles <- list(tiles=tiles, poly=poly)
    
    return(tiles)
  }

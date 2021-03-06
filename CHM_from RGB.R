"""
ACT group 10
Remote Sensing and GIS Integration 2020
Title: Forest Inventory through UAV based remote sensing
"""

# Loading the required libraries
library(lidR)
library(raster)
library(colorRamps)
library(sp)
library(rgl)
library(ggpubr)
library(rlas)
library(tiff)
library(ForestTools)

## Setting working directory
setwd("/Users/marariza/Downloads")

# We load and read the AHN3 file
AHN3_clip <- "AHN3.laz"
AHN3 <- readLAS(AHN3_clip)

# We compute two DTMs modifying just one parameter (keep lowest)
DTM1 <- grid_terrain(AHN3, res=1, algorithm = knnidw(k=6L, p = 2), keep_lowest = FALSE)
DTM2 <- grid_terrain(AHN3, res=1, algorithm = knnidw(k=6L, p = 2), keep_lowest=TRUE)

# We plot both DTMs to observe the differences
plot(DTM1, main="DTM1", col=matlab.like2(50))
plot(DTM2, main="DTM2", col=matlab.like2(50))

# We compute the differences between DTM and create and histogram to check if they are close to 0
Difference <- DTM2 - DTM1
plot(Difference, main="Difference", col=matlab.like2(50))
hist(Difference)
# As the values are almost the same (all around 0 in the difference), we will work with the first DTM (DTM1)

# We load the DSM created with photogrammetry from RGB images, we project it to RD New and resample to 
# have the same resolution as the DTM
RGB <- "DEM_speulderbos_georef_ar.tif"
DSM_no_proj <- raster(RGB)
DSM_proj <- projectRaster(DSM_no_proj, crs = crs(DTM1))
DSM <- resample(DSM_proj, DTM1, method = "bilinear")

# We compute the CHM substracting also 40.68, which is the difference height between the DSM and the DTM
# in the area on the left (U-shaped area).
CHM <- DSM - DTM1 - 40.68
plot(CHM, main="CHM", col=matlab.like2(50), xaxt="n", yaxt="n")

# We use the Variable Window Filter (VWF) to detect dominant tree tops. We use a linear function used in 
# forestry and set the minimum height of trees at 10, but those variables can be modified. 
# After we plot it to check how the tree tops look like. 
lin <- function(x) {x*0.05+0.6}
treetops <- vwf(CHM = CHM, winFun = lin, minHeight = 15)
plot(CHM, main="CHM", col=matlab.like2(50), xaxt="n", yaxt="n")
plot(treetops, col="black", pch = 20, cex=0.5, add=TRUE)

# We check the mean of the height of the detected tree tops 
mean(treetops$height)

# We compute the function MCWS function that implements the watershed algorithm. In this case, the argument
# minHeight refers to the lowest expected treetop. The result is a raster where each tree crown is 
# a unique cell value. 
crowns <- mcws(treetops = treetops, CHM=CHM, minHeight = 15, verbose=FALSE)
plot(crowns, main="Detected tree crowns", col=sample(rainbow(50), length(unique(crowns[])),replace=TRUE), 
     legend=FALSE, xaxt="n", yaxt="n")

# We do the same computation as before but changig the output format to polygons. It takes more processing
# time but polygons inherit the attributes of treetops as height. Also, crown area is computed for each polygon.
crownsPoly <- mcws(treetops = treetops, CHM=CHM, minHeight = 8, verbose=FALSE, format="polygons")
plot(CHM, main="CHM", col=matlab.like2(50), xaxt="n", yaxt="n")
plot(crownsPoly, border="black", lwd=0.5, add=TRUE)

# Assuming each crown has a roughly circular shape,the crown area is used to compute its average circular diameter.
crownsPoly[["crownDiameter"]] <- sqrt(crownsPoly$crownArea/pi) *2
mean(crownsPoly$crownDiameter)
mean(crownsPoly$crownArea)

sp_summarise(treetops)
sp_summarise(crownsPoly, variables=c("crownArea", "height"))


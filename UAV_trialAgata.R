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
library(itcSegment)
library(TreeLS)


## Setting working directory
#setwd("/Users/marariza/Downloads")

# We load and read the AHN3 file
AHN3_clip <- "/Users/HP/Documents/ACT/R/Data/AHN3_beech.laz"
AHN3 <- readLAS(AHN3_clip)

lasfile <- "/Users/HP/Documents/ACT/R/Data/UAV_withGround.laz"
beechLas <- readLAS(lasfile)
beechLas <- lasclipRectangle(beechLas, 176170, 473657, 176265, 473782)

# Computing the DSM with the AHN3 dataset
DSM <- grid_canopy(beechLas, res=1, p2r(0.2))
#plot(DSM, main="DSM", col=matlab.like2(50))

# Computing the DTM with the AHN3 dataset
DTM <- grid_terrain(AHN3, res=1, algorithm = knnidw(k=6L, p = 2), keep_lowest = FALSE)
#plot(DTM, main="DTM", col=matlab.like2(50))

# We compute the CHM and remove one value which is below 0 (-0.005 m)
CHM <- DSM - DTM
CHM[is.na(CHM)] <- 0

# Using focal statistics to smooth the CHM
CHM_smooth <- focal(CHM,w=matrix(1/9, nc=3, nr=3), na.rm=TRUE)

# We use the Variable Window Filter (VWF) to detect dominant tree tops. We use a linear function used in 
# forestry and set the minimum height of trees at 10, but those variables can be modified. 
# After we plot it to check how the tree tops look like. 
lin <- function(x) {x*0.2 + 3}
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

#####################################################################################################

# Point density
density <- grid_density(beechLas, res=1)
#plot(density)

# Normalize las to correct the height of all points for the terrain height
nlas <- lasnormalize(beechLas, DTM)
plot(nlas)

# Select stems/crowns segment
DBH_slice <-  nlas %>% lasfilter(Z>0.8 & Z<2) ## slice around Breast height 
Crowns_slice <-  nlas %>% lasfilter(Z>10)
plot(DBH_slice, color="Classification")

#### INDIVIDUAL TREE SEGMENTATION ####
# Select all vegetation and other objects
Vegpoints_norm <- nlas %>% lasfilter(Classification==1) 
# Dalponte
trees <- lastrees(Vegpoints_norm, dalponte2016(CHM, treetops))
plot(trees, color="treeID") 

# Li 
#trees <- lastrees(Vegpoints_norm, li2012(R=5, speed_up=10, hmin=5))  

tls = tlsNormalize(beechLas)
# map the trees on a resampled point cloud so all trees have approximately the same point density
thin = tlsSample(tls, voxelize(0.01))
map = treeMap(thin, map.hough(hmin = 1, hmax = 2, max_radius = 0.3, min_density = 0.01, min_votes = 2))
tls = stemPoints(tls, map)
df = stemSegmentation(tls, sgmt.ransac.circle(n=10))
head(df)
tlsPlot(tls, df, map)
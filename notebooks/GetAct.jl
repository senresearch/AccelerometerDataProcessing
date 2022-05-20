# ---
# jupyter:
#   jupytext:
#     formats: ipynb,jl:light
#     text_representation:
#       extension: .jl
#       format_name: light
#       format_version: '1.5'
#       jupytext_version: 1.11.0
#   kernelspec:
#     display_name: Julia 1.7.2
#     language: julia
#     name: julia-1.7
# ---

# # Get activity data
# ___

# This note notebook explore how to extract activity data and convert it into a data frame before to save it as a CSV file. It explore also how to change the temporal resolution of the activity.  

# ## Load input: packages, external functions, input data.

# ### Packages

# Load packages
using PyCall, PyPlot
pygui(:tk)
using DataFrames, CSV, Dates, StatsBase, Statistics, Tables, DataFramesMeta, BenchmarkTools
using Missings

# ### External Functions

# +
# Include function file to extract and display accelerometer data
# Include the modules directory
dirFun = realpath(string(@__DIR__,"/../../temp/"))
include(dirFun*"/ActStatData.jl"); # include(dirFun*"/ActPlotData.jl"))
include(dirFun*"/GetAct.jl");
include(dirFun*"/GetBio.jl");
include(dirFun*"/ActTools.jl");
include(dirFun*"/AccDynamics.jl");

using .ActStatData
# -

# ### Data

# +
# List of visit directories
listDir = ["/../../../data/Baseline Visit Data/";
           "/../../../data/32 Week Gestation Data/";
           "/../../../data/6 Week PP Data/";
           "/../../../data/6 Months PP Data/";
           "/../../../data/12 Months PP Data/"]

# Visit Dictionary 
dictVisitName =  Dict(1=>"VisitBaseline",
                    2=>"Visit32w",
                    3=>"Visit6wPP",
                    4=>"Visit6mPP",
                    5=>"Visit12mPP");

# Load the group assignment information
groupFileName = realpath(string(@__DIR__, "/../../../data/Group/group_assignement.csv"))
global dfGroup = DataFrame!(CSV.File(groupFileName));
sort!(dfGroup);
# -

# ## Get an individual activity data 

# For example, let get the activity data frame of an individual from the Baseline directory:

# +
# Get the path of the directory 
myDir = abspath(string(@__DIR__,listDir[1]));

# Get the data list files from the directory myDir
(actFiles, bioFiles) = ActStatData.filesNoNaN(myDir);
# -

# Let return the activity and bio file names with respect to the index 3: 

println(actFiles[3]*"\n"*bioFiles[3])

length(bioFiles)

# Get the activity data frame:

# Get any file and show columns of the data frame structure
idx = 3
df = ActStatData.readActivity(myDir*actFiles[idx]);
first(df, 3)

# Get complete days
ActStatData.getCompleteDays(df)

# ### GetIndivAct

# `GetIndivAct` returns a vector containing the average of an activity type over maximum 7 days. It should returns also the ID and eventually the group

?GetIndivAct

# Get complete days
idx = 21
df = ActStatData.readActivity(myDir*actFiles[idx]);
ActStatData.getCompleteDays(df)

# +
fileName = myDir * actFiles[21] # 107

# Get average Activity Count over 7 days
 vec = GetIndivAct(fileName, actType = 1, resmin = 1, isavg = true)
plot(vec)
# -

# Get average Activity Intensity over 7 days
vec = GetIndivAct(fileName, actType = 4, resmin = 1, isavg = false)
plot(vec)

vecIntensity = GetIndivAct(fileName, actType = 4, resmin = 1, isavg = false);

countmap(vecIntensity)

# ## Write Script to generate csv data

# ### Get directory activity 

# Set the path the visit directory and a temporal resolution if desired.

# +
# Select path of visit directory
idxDir = 5
myDir = abspath(string(@__DIR__,listDir[idxDir]))

# Set a temporal resolution
rmin = 60
# -


# Generate a data matrix containing values of one type of activity (*e.g.*, activity count, steps, intensity model...) and IDs vector with respect to each observation (row) of the data matrix.

# Activity type dictionary 
dictActType =  Dict(1=>"Acc",
                    2=>"Steps",
                    3=>"Xpndtr",
                    4=>"Ntnst");

# Get the data list files from the directory myDir
# (myData, myHeader) = ActStatData.filesNoNaN(myDir);
# myDir
# Get the matrix data
idxAct = 1
mat, vID = GetDirAct(myDir,actType = idxAct, resmin = rmin);
size(mat)


# ### Check uniqueness

nonunique(vID)

findall(x -> x == 248, vID)

# Get the data list files from the directory myDir
(dataFiles, bioFiles) = ActStatData.filesNoNaN(myDir);
bioFiles[findall(x -> x == 248, vID)]

# Join the activity information to the list with group assignment.

# ### Add group information

# +
# Get Group assignment for the selected ID
myDf = DataFrame(studyID = vID)
dfAct = leftjoin(myDf, dfGroup, on = :studyID)

# Check for missing
numMiss = sum(ismissing.(dfAct.arm[:]))
println("Number of ID missing  : $numMiss")
# -


# Drop missing
dfAct = dropmissing(dfAct);

# ### Convert matrix to data frame

# Convert matrix to data frame
df = Mat2DfAct(mat, vID, resmin = rmin)
first(df, 3)


# Join the group assignment information:

# +
# Left join
df = leftjoin(dfAct, df, on = :studyID);

# Check for missing data
findall(x -> ismissing(x), df.arm)

# -

# ### Save the activity data frame


# Prepare the file name:

myFileName = string("m",dictVisitName[idxDir],"_", rmin,"_",
                    dictActType[idxAct], ".csv")

# Save activity data frame:

csvFileName = string(@__DIR__,"/../../../data/fda/",myFileName)
CSV.write(csvFileName, df ; writeheader=true)


# ## Generate and save activity differences between 2 consecutive visits

# Load baseline and 32 weeks visits.

# Load data frame from the Baseline visit
myFileName = string("m",dictVisitName[1],"_", rmin,"_",
                    dictActType[idxAct], ".csv")
csvFileName = string(@__DIR__,"/../../../data/fda/", myFileName)
dfV1 = DataFrame!(CSV.File(csvFileName; comment = "#"));
size(dfV1)

# Load data frame from the 32 weeks visit
myFileName = string("m",dictVisitName[2],"_", rmin,"_",
                    dictActType[idxAct], ".csv")
csvFileName = string(@__DIR__,"/../../../data/fda/", myFileName)
dfV2 = DataFrame!(CSV.File(csvFileName; comment = "#"))
size(dfV2)

# Build a dataframe containing the the activity data with the ID existing in the 32 weeks visit data frame.

# Keep IDs of the baseline visit in common with the next visit
df1 = DataFrame(studyID = dfV2.studyID);
df1 = innerjoin(df1, dfV1, on = :studyID);
size(df1)

# # Keep IDs of the second visit in common with the first visit
df2 = DataFrame(studyID = df1.studyID);
df2 = innerjoin(df2, dfV2, on = :studyID);
size(df2)

# test 
df1.studyID == df2.studyID

first(df1)

# ### Get the difference between two visits

# Convert data frame activity into matrix 
mat21 = (log.(Matrix(df2[:, 3:end]).+1) - log.(Matrix(df1[:, 3:end]).+1 ));

d = names(@view df1[1,3:end]);

df21  = DataFrame([@view(mat21[:, i]) for i in 1:size(mat21, 2)], Symbol.(d))
insertcols!(df21, 1, :studyID => df1.studyID)
insertcols!(df21, 2, :arm => df1.arm);

# ### Save the diff data frame

# csvFileName = string(@__DIR__,"/../../../data/fda/","mBaselineSteps60.csv")
myFileName = string("m",dictVisitName[2], "-", dictVisitName[1],
                    "_", rmin,"_", dictActType[idxAct], ".csv")
csvFileName = string(@__DIR__,"/../../../data/fda/", myFileName)
CSV.write(csvFileName, df21 ; writeheader=true)

# ## Accumulation

A = [1.0 2 3 4;1 2 3 4;1 2 3 4]
A =copy(transpose(A))

GetAccAct(A)

# +
function GetAccAct(mat::Array{Float64, 2})
    
    mat = copy(transpose(mat))
        
    for  i = 1:size(mat)[2]
        mat[:,i] = accumulate(+, mat[:,i])
    end
        
    mat = copy(transpose(mat))
    
    return mat
    
end
# -

   # Transpose dataframe
    dfAct = DataFrame([[names(dfAct)]; collect.(eachrow(dfAct))], [:day; Symbol.(axes(dfAct, 1))])

# ## Extra

# Add closest divisor:
#
# Num = 636         # Numerator we are seeking to divide with no remainder
# Den = 8           # Initial denominator
# max_iters = 15    # caps the maximum loops
# iters = 1         # initialize counter
# Deni = Dend = Den # vars for searching increasing and decreasing denominators
#
# while Num%Den != 0:
# Deni +=1                 # searching increased vals
# if Dend > 0 : Dend -=1   # searching decreased vals, but check 0 condition
# if Num%Dend ==0:         # found a 0 remainder denominator
#     Den = Dend           # assign found denominator
#     break
# elif Num%Deni ==0:       # found a 0 remainder denominator
#     Den = Deni           # assign found denominator
#     break
# elif iters >= max_iters: # check loop count
#     break
# iters+=1

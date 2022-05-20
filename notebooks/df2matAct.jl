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

# # Convert activity data to data frame
# ___

# This note notebook explore how to extract activity data and convert it into a data frame before to save it as a CSV file.

# ## Packages and functions

# +
# Include function file to extract and display accelerometer data
include(realpath(string(@__DIR__,"/../../temp/ActStatData.jl")))

# include(string(realpath(pwd()*"/../temp")*"/ActPlotData.jl"))

# Load packages
using PyCall, PyPlot
pygui(:tk)
using DataFrames, .ActStatData, CSV, Dates, StatsBase, Statistics, Tables, DataFramesMeta, BenchmarkTools
# -

# ## Input Directories

# List of visit directories
listDir = ["/../../../data/Baseline Visit Data/";
           "/../../../data/32 Week Gestation Data/";
           "/../../../data/6 Week PP Data/";
           "/../../../data/6 Months PP Data/";
           "/../../../data/12 Months PP Data/"]
# Load the group assignment information
groupFileName = realpath(string(@__DIR__, "/../../../data/Group/group_assignement.csv"))
global dfDem = DataFrame!(CSV.File(groupFileName));
sort!(dfDem);

realpath(string(@__DIR__,listDir[1]))
myDir = abspath(string(@__DIR__,listDir[1]));
# Get the data list files from the directory myDir
(myData, myHeader) = ActStatData.filesNoNaN(myDir);

myData[3]

# Get any file and show columns of the data frame structure
df = ActStatData.readActivity(myDir*myData[3]);

# ## Function getIndivMatAct()
# `getIndivMatAct` returns a vector containing the average of an activity type over maximum 7 days. It should returns also the ID and eventually the group.

function getIndivMatAct(fileName::String; actType = 1, isavg::Bool = true)
    
    # Read activity data
    df = ActStatData.readActivity(fileName);
    
    # Dictionnary to select type of activity data
    dictActivity = Dict(1=>:ActivityCounts, 
                    2=>:Steps, 
                    3=>:EnergyExpenditure, 
                    4=>:ActivityIntensity);
    
    # Create a dataframe that will contain the average activity data
    d = Dates.Time("00:00", "HH:MM"):Dates.Minute(1):Dates.Time("00:00", "HH:MM") + Dates.Hour(24) - Dates.Minute(1)
    dfAct = DataFrame(Time = collect(d));
    
    # Get over 8 days since the first day is not necessary complete. 
    numDays = ifelse(ActStatData.getComplete24h(df)>=8, 8, 7)
    
    # Build a dataframe where each column is 24h or 1440min  
    for i = 1:numDays
        dfTmp = @linq filter(:Day => x -> x == i, df) |> 
                transform(Time = Dates.Time.(:DateTime[:])) 
        select!(dfTmp, :Time, dictActivity[actType] => Symbol(string("day",i))); # select and change name of the activity type
        dfAct = leftjoin(dfAct, dfTmp, on = :Time);
    end
    
    # Keep only activity
    select!(dfAct, Not(:Time));

    # Merge day 1 and last day according to the missing slots
    lastDay = Symbol(names(dfAct)[end])
    
    dfAct[:, [:day1, lastDay]] .= ifelse.(ismissing.(dfAct[!, [:day1, lastDay]]) , 0, dfAct[!, [:day1, lastDay]]);
    dfAct[:, :day1] = dfAct[:, :day1] + dfAct[:, lastDay]
    select!(dfAct, Not(lastDay));

    # Transpose dataframe
    dfAct = DataFrame([[names(dfAct)]; collect.(eachrow(dfAct))], [:day; Symbol.(axes(dfAct, 1))])
    select!(dfAct, Not(:day))
    
    nMin = 60
    
    # Get average activity 
    if isavg
        return sum(reshape(mean.(eachcol(dfAct)), nMin, Int(1440/nMin)), dims = 1)[:] # mean.(eachcol(dfAct)) 
    else
        return reshape(copy(transpose(convert(Matrix, dfAct))), nVec, 1) 
    end
end

# ### Testing getIndivMatAct

# GET FILE NAME
# List of visit directories
listDir = ["/../../../data/Baseline Visit Data/";
           "/../../../data/32 Week Gestation Data/";
           "/../../../data/6 Week PP Data/";
           "/../../../data/6 Months PP Data/";
           "/../../../data/12 Months PP Data/"]
myDir = abspath(string(@__DIR__,listDir[1]))
(dataFiles, bioFiles) = ActStatData.filesNoNaN(myDir);
fileName = myDir * dataFiles[50] # 169-> 6 days

# Get average Activity over 7 days
avgAct = getIndivMatAct(fileName, actType = 1)

# +


# Get average Activity over 7 days
avgAct = getIndivMatAct(fileName, actType = 1, isavg= false)

# -

df1=copy(transpose(convert(Matrix, avgAct)))
nVec = 1440*7
A = reshape(copy(transpose(convert(Matrix, avgAct))), nVec, 1);
plot(A)

# ## Function `getbio()`

# `getbio()` returns a tuple containing the bio information of an individual.

function getbio(dfBio::DataFrame)
    dem = NamedTuple{(:id, :age, :height, :weight, :startdate),
            Tuple{Int64, Int64, Float64, Float64, DateTime}}((
            parse(Int64, dfBio[1, :Value]), # id
            parse(Int64, dfBio[2, :Value]), # age
            parse(Float64, dfBio[4, :Value]), # height
            parse(Float64, dfBio[6, :Value]),  # weight
            parse(DateTime, dfBio[8, :Value]*"T"*dfBio[9, :Value]) # start date
            ))
    
    return dem
end

realpath(string(@__DIR__,listDir[1]))
myDir = abspath(string(@__DIR__,listDir[1]));
# Get the data list files from the directory myDir
(dataFiles, bioFiles) = ActStatData.filesNoNaN(myDir)
# Get any file and show columns of the data frame structure
df = ActStatData.readActivity(myDir*bioFiles[3]);
getbio(df).id

# ## Function getIndivID()
# `getIndivID` returns the ID and group assignement of an infdicidual.

function getIndivID(fileName::String; actType = 1)
    dfBiorg = ActStatData.readActivity(fileName);
    return getbio(dfBiorg).id
end

idd = getIndivID(myDir*bioFiles[3])

idd = Array{Int64, 1}(undef, 3)

# ## Function `getStatAct()`

# Builds a average activity matrix, MxN where M is numbers of epochs (1440 minutes) and N is the number of subjects for a given visit (e.g. Baseline, 32 Week Gestation, 6 Weeks PP...).   
# It also saves the matrix in the corresponding  vistit folder. Finally, it returns the average activity for all subjects and the standard deviation.

# +
function getStatActi(dirName::String, actType::Int64 = 1)
    # Get the data list files from the directory myDir
    (dataFiles, bioFiles) = ActStatData.filesNoNaN(dirName);
    
    # Total number of files in the directory dirName
    numFiles = length(dataFiles)
    
    # Keep ID of individual
    vecID = Array{Int64, 1}(undef, numFiles)
    
    nMin = 60
    # Create average activity matrix 
    avgActMat = Array{Float64, 2}(undef, Int(1440/nMin), numFiles)
    
    for  i = 1:numFiles
        # Get average Activity over 7 days
        avgAct = getIndivMatAct(dirName * dataFiles[i], actType = actType)
                
        # Add the new column in the average activity matrix form 00:00 to 23:59
        avgActMat[:, i] = avgAct[:]
        
        # Collect ID
        vecID[i] = getIndivID(dirName * bioFiles[i])    
    end
        
    return avgActMat, vecID
    
end
# -

# ## Function `mat2dfAct()`
# `mat2dfAct()` returns a dataframe containing activity datafor each min and for each individual.

# +
function mat2dfAct(mat::Array{Float64, 2}, vecID::Array{Int64, 1})
    
    # Transpose the matrix: ID rowwise and time columnwise
    mat = copy(transpose(mat))
    
#     d = Dates.Time("00:00", "HH:MM"):Dates.Minute(1):Dates.Time("00:00", "HH:MM") + Dates.Hour(24) - Dates.Minute(1)
    d = Dates.Time("00:00", "HH:MM"):Dates.Minute(60):Dates.Time("00:00", "HH:MM") + Dates.Hour(24) - Dates.Minute(1)
    d = string.(collect(d))
    for i= 1:length(d) d[i] = d[i][1:5] end
    d = "T".*replace.(d, ":"=> "h") 
    df  = DataFrame([@view(mat[:, i]) for i in 1:size(mat, 2)], Symbol.(d))
    
    insertcols!(df, 1, :StudyID => vecID)
    
    return df 
    
end
# -

mat1 = [1 2 3; 4 5 6]
headerstr = ["a"; "b"; "c"]

mat1 = rand(0:10,(1440, 300));

# ## Function `nonunique()`

# `nonunique()` returns an array containing all the elements that appear at least twice in its input.

function nonunique!(x::AbstractArray{T}) where T
    sort!(x)
    duplicatedvector = T[]
    for i=2:length(x)
        if (isequal(x[i],x[i-1]) && (length(duplicatedvector)==0 || !isequal(duplicatedvector[end], x[i])))
            push!(duplicatedvector,x[i])
        end
    end
    duplicatedvector
end

tt = [ 1; 2; 3; 2; 4; 5]

nonunique2!(tt)

tt

# ## Write Script to generate csv data

# Set the list of the visit directories relative path.

# List of visit directories
listDir = ["/../../../data/Baseline Visit Data/";
           "/../../../data/32 Week Gestation Data/";
           "/../../../data/6 Week PP Data/";
           "/../../../data/6 Months PP Data/";
           "/../../../data/12 Months PP Data/"]
realpath(string(@__DIR__,listDir[1]))
myDir = abspath(string(@__DIR__,listDir[1]))


# Load the group assignment data.

# Load the group assignment information
groupFileName = realpath(string(@__DIR__, "/../../../data/Group/group_assignement.csv"))
global dfGroup = DataFrame!(CSV.File(groupFileName));
sort!(dfGroup);

# Get the average activity data during one week for all individual.

# Get the data list files from the directory myDir
# (myData, myHeader) = ActStatData.filesNoNaN(myDir);
# myDir
# Get the matrix data
mat, vID = getStatActi(myDir);
size(mat)


# Get the data list files from the directory myDir
    (dataFiles, bioFiles) = ActStatData.filesNoNaN(myDir);
    
    # Total number of files in the directory dirName
    numFiles = length(dataFiles)

length(unique(dataFiles))

# Keep ID of individual
vID = Array{Int64, 1}(undef, numFiles) 
for  i = 1:numFiles
    # Collect ID
    vID[i] = getIndivID(myDir * bioFiles[i])    
end

sort!(vID);

vID[nonunique!(vID)]
findall(x -> x == 202, vID)

length(unique(vID))

vID[30:39]

# Idendtify if every ID are unique.

length(vID) == length(unique(vID))

vID[nonunique!(vID)]

show(length(vID))
show(length(unique(vID)))

# Get Group assignment for the selected ID
myDf = DataFrame(StudyID = vID)
dfAct = leftjoin(myDf, dfGroup, on = :StudyID)
first(dfAct, 3)

# Convert matrix to data frame
myDf = mat2dfAct(mat, vID)
first(myDf, 3)


df = leftjoin(dfAct, myDf, on = :StudyID)

# Find missing data
findall(x -> ismissing(x), df.Arm)

#Remove missing
dropmissing!(df);

df

# # Save the activity matrix data


csvFileName = string(@__DIR__,"/../../../data/fda/","mBaseline2.csv")
CSV.write(csvFileName, df ; writeheader=true)


# Since Matrix does not support Tables.jl interface, we need to convert the matrix to dataframe 
# in order to save it in csv file with the CSV.jl package
# myDf = DataFrame(transpose(myMat));
# Save the activity matrix data
"/../../../data/Baseline Visit Data/"
csvFileName = realpath(string(@__DIR__,"/../../../data/fda"))*"/mBaseline2.csv"
CSV.write(csvFileName, df ; writeheader=false)

#  @btime A = @view(mat[:,:]).+1
@btime A = mat.+1

# ##### # Get the data list files from the directory myDir


using BenchmarkTools


# +
using BenchmarkTools

# declare global-scope variables as constants, otherwise the compiler can't
# stably infer the variable's type
const L = 500 # integer literals in Julia don't require conversion
const v3 = [[rand(L) for i = 1:L] for j = 1:L]
const vec_mat = Vector{Matrix{Float64}}(L) #Array{Matrix}(L, L);
# const arr = rand(L, L, L);

# fill!(vec_mat, rand(L, L));

# @btime v3 .+= 1.0
# @btime vec_mat .+= 1.0
# @btime arr .+= 1.0

# -

function test()
    L = Int(1e4)
    M = N = 30
    vec_vec_vec = Array{Vector{Vector{Float64}}}(undef, L);
    for i = 1:L vec_vec_vec[i] = [zeros(N) for j = 1:M] end;
    vec_mat = Array{Matrix{Float64}}(undef, L);
    fill!(vec_mat, rand(M, N));
    arr = rand(L, M, N);
    @time  for i = 1:L for j = 1:M for k = 1:N vec_vec_vec[i][j][k] += 1; end; end; end; 
    @time  for i = 1:L for j = 1:M for k = 1:N vec_mat[i][j,k] += 1; end; end; end; 
    @time  for k = 1:N for j = 1:M for i = 1:L arr[i,j,k] += 1; end; end; end; 
end
test()

# +

function test()
    L = Int(1e4)
    M = N = 30
    vec_vec_vec = Array{Vector{Vector{Float64}}}(undef, L);
    for i = 1:L vec_vec_vec[i] = [zeros(N) for j = 1:M] end;
    vec_mat = Array{Matrix{Float64}}(undef, L);
    fill!(vec_mat, rand(M, N));
    arr = rand(L, M, N);
    @time @inbounds for i = 1:L, j = 1:M, k = 1:N vec_vec_vec[i][j][k] += 1 end
    @time @inbounds for i = 1:L, k = 1:N, j = 1:M vec_mat[i][j,k] += 1 end
    @time @inbounds for k = 1:N, j = 1:M, i = 1:L arr[i,j,k] += 1 end
end
test()
# k = 1:N, j = 1:M, i = 1:L
# -
Int(1440/60)









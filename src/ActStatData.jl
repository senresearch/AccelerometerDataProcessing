"""
ActStatData
===========

Synopsis
--------
*ActStatData* provides a set of function that extracts data from activity CSV
files.

Exported Functions
------------------
* ``readActivity``: Reads the data in the csv file, it extracts the header
                    information and the data activity in two data frames.

* ``filesNoNaN``: Returns two list of files with complete data in a given 
                  directory,i.e. a list containing and it returns
                  files with activity data and a file containing bio information.

* ``getStatAct``: Builds a average activity matrix, MxN where M is numbers of
                  epochs (1440 minutes) and N is the number of subjects for a
                  given visit (e.g. Baseline, 32 Week Gestation, 6 Weeks PP...).
                  It also saves the matrix in the corresponding  vistit folder.
                  Finally, it returns the average activity for all subjects and
                  the standard deviation.

* ``getStatActMed``: Builds a median activity matrix, MxN where M is numbers of
                     epochs (1440 minutes) and N is the number of subjects for a
                     given visit (e.g. Baseline, 32 Week Gestation...). It also
                     saves the matrix in the corresponding  vistit folder.
                     Finally, it returns the average activity over the number of
                     subject and the standard deviation.


* ``getCompleteDays``: Estimate the total number of complete days (24 hours).

* ``getIntensity``: Returns matrix or data frame that contains activity intensity summary  for each day.

* ``getAccAC``: Returns data frame that contains accumulated activity count for each day.
                It includes also date time stamp and day name of the week.   
     
* ``filterAccDays``: Filters days with acccumulated activity counts less or equal to a     
                     threshold (default is 0) , and returns filtered data frame.

See also
--------
ActPlotData.jl

References
----------
https://github.com/davidanthoff/ExcelReaders.jl
http://aviks.github.io/Taro.jl/#usage
https://juliadata.github.io/CSV.jl/stable/
"""
module ActStatData

using PyCall
using DataFrames
using CSV
using DelimitedFiles
using StatsBase, Statistics
using Dates

export readActivity, filesNoNaN, getStatAct, getStatActMed, getCompleteDays

dirFun = realpath(string(@__DIR__,"/"))
include(dirFun*"/ActTools.jl");

    """
    readActivity(dataFileName::String)

    Synopsis:
    readActivity reads the data in the csv file, it extracts the header information
    and the data activity in two data frames.

    Input:
    - dataFileName      String     Name of the excel file.

    - dataDirNameOut    String     Contains directory location where new csv
                                   files are are to be saved.
    Output:
    - df                DataFrame

    Example:
    readActivity(myFiles[i])
    """
    function readActivity(dataFileName::String)
        dfData  = CSV.read(dataFileName, DataFrame; comment = "#");
        rename!(dfData, Symbol.(lstrip.(names(dfData))))

        return dfData
    end

    ################################################################################
    """
        filesNoNaN(dataDirNameIn::String)

        Synopsis:
        filesNoNaN returns two list of files with complete data in a given directory,i.e. a list containing and it returns
        files with activity data and a file containing bio information.

        Input:
        - dataDirNameIn      String       Contains directory location

        Output:
        - myNoMissFiles     String Array  Contains the list of file names with no missing activity
        - myNoMissFilesHdr  String Array  Contains the list of file names with bio information

        Example:
    """     
    function filesNoNaN(dataDirNameIn::String)
        #-------------------------------------------------------------------------------
        # Get the name of the file containing the list of data files
        myFileName = joinpath(dataDirNameIn, "DataLogInfo.txt")#string(dataDirNameIn, "DataLogInfo.txt")

        # Read the list of names of the files in the given folder last checked
        myFiles = Array{String,1}()
        myNaNFiles = Array{String,1}()
        myMissingFiles = Array{String,1}()

        # Read the list of names of the files
        # Check there exist data file in the directory
        try
            f = open(myFileName, "r")
            readline(f)
            myFiles = readdlm(f, ',')
            close(f)
        catch
            println("There is no data log file in the following directory: ")
            println(dataDirNameIn)
            myFiles = ""
        end
        #-------------------------------------------------------------------------------
        # Get the name of the file containing the list of files with NaN
        NaNFileName = string(dataDirNameIn, "/NaNDataLog.txt")
        # Read the list of names of the files with NaN
        try
            f = open(NaNFileName, "r")
            myNaNFiles = readdlm(f, ',')
            close(f)
        catch
            println("There is no missing (i.e. NaN) data log in the following directory:")
            println(dataDirNameIn)
        end
        #-------------------------------------------------------------------------------
        # Get the name of the file containing the list of files with missing data
        NAFileName = string(dataDirNameIn, "/NADataLog.txt")
        # Read the list of names of the files with NA step column
        try
            f = open(NAFileName, "r")
            myMissingFiles = readdlm(f, ',')
            close(f)
        catch
            println("There is no missing (i.e. NA) data log in the following directory:")
            println(dataDirNameIn)
        end
        #-------------------------------------------------------------------------------
        if !isempty(myMissingFiles)
            myNaNFiles =
                collect(Iterators.flatten([myNaNFiles[:], myMissingFiles[:]]))
        end
        #-------------------------------------------------------------------------------
        if !isempty(myNaNFiles)
            # Get the name of the new files if any
            myNoMissFiles = convert(Array{String,1}, setdiff(myFiles, myNaNFiles))
            # Change the extension xlsx to csv in the myNaNFiles array
            #myNoMissFilesHdr = replace.(myNoMissFiles,(".xlsx" => "_hdr.csv",))
            #myNoMissFiles = replace.(myNoMissFiles,(".xlsx" => ".csv",))
        else
            myNoMissFiles = myFiles
            # Change the extension xlsx to csv in the myNaNFiles array
            #myNoMissFilesHdr = replace.(myNoMissFiles,(".xlsx" => "_hdr.csv",))
            #myNoMissFiles = replace.(myNoMissFiles,(".xlsx" => ".csv",))
        end

        # Change the extension xlsx to csv in the myNaNFiles array
        myNoMissFilesHdr = replace.(myNoMissFiles, (".xlsx" => "_hdr.csv",))
        myNoMissFiles = replace.(myNoMissFiles, (".xlsx" => ".csv",))

        return myNoMissFiles, myNoMissFilesHdr
    end

################################################################################
function getStatAct(myDir::String, myFiles::Array{String,1}, colNum::Int)
    # getStatAct(myDir::String, myFiles::Array{String,1})
    #
    # Synopsis:
    # getStatAct builds a average activity matrix, MxN where M is numbers of
    # epochs (1440 minutes) and N is the number of subjects for a given visit (e.g.
    # Baseline, 32 Week Gestation, 6 Weeks PP...). It also saves the matrix in the
    # corresponding  vistit folder. Finally, it returns the average activity for all
    # subjects and the standard deviation.
    #
    # Input:
    # - myDir           String                  Contains directory location
    # - myFiles         Array{String, 1}        Contains files data names
    # - colNum          Integer                 Contains the id column of data frame
    #
    # Output:
    # - avgActMat           Array{Float64, 1}   Average of activity over 24 hours for all subjects during a given visit
    # - varActVisit         Array{Float64, 1}   Variance of activity over 24 hours for all subjects during a given visit
    # - corActVisit         Array{Float64, 2}   Correlation of activity over 24 hours for all subjects during a given visit
    #
    # Example:
    #
    #-------------------------------------------------------------------------------

    # Get the total number of files in the directory myDir
    numFiles = length(myFiles)
    # Create the matrix that contains all average activity of each subject
    avgActMat = ones(1440, numFiles)

    # Create the matrix that contains all median activity of each subject
    medActMat = ones(1440, numFiles)


    for i = 1:numFiles
        # Read file
        dfD = readActivity(myDir * myFiles[i])

        # Convert the column DateTime to DateTime type
        # it is notnecessary to convert to DateTime since 1.2.0
        # dfD[:DateTime]=DateTime(dfD.DateTime) # dfD.DateTime == dfD[!,:DateTime]

        # Get timing of the first and last epoch in order to estimate the
        # total number of days.
        myStartTime = dfD[1, 3]
        myFinishTime = dfD[end, 3]

        # Get the total number of seconds wearing the device
        totalWearTime = convert(
            Float64,
            Dates.value(Dates.Second((myFinishTime - myStartTime))),
        ) #in seconds
        completeNumDays = Int(floor(totalWearTime / 86400)) # number of day with full 24 hours

        # Reshape the vector in matrix such that each column corresponds to 24 hours of wearing time.
        matActivity =
            reshape(dfD[1:completeNumDays*1440, colNum], 1440, completeNumDays) # 1440 min in 24 hours
        matActivity = matActivity[:, :]

        # Get the activity count average over for full days.
        avAct = mean(matActivity, dims = 2)
        medAct = median(matActivity, dims = 2)# median over for full days.

        # Get the first 24 hours
        dtS = Dates.format.(dfD[1:1440, 3], "HH:MM")

        # Sort time vector and get the indices of permutation
        idx = sortperm(dtS)

        # Reorder the activity count vector such that timing start at 00:00 and
        # at finish at 23:59
        avAct = avAct[idx]
        medAct = medAct[idx]# re-ordering for the median values

        # Add the new column in the average activity matrix form 00:00 to 23:59
        avgActMat[:, i] = avAct[:]
        medActMat[:, i] = medAct[:]# for median values
    end

    # Get the activity data average over for full days for all subjects.
    #avgActVisit = mean(log2.(avgActMat+1), 2);
    avgActVisit = mean(avgActMat, dims = 2)

    # Get the activity data average over for full days for all subjects.
    #medActVisit = median(log2.(avgActMat+1), 2);
    medActVisit = median(medActMat, dims = 2)#median(avgActMat, 2);

    # Get the activity data variance over for full days for all subjects.
    #varActVisit = var(log2.(avgActMat+1), 2);
    varActVisit = var(avgActMat, dims = 2)
    # Get the activity data correlation over for full days for all subjects.
    #corActVisit = cor(log2.(avgActMat+1), 2);
    corActVisit = cor(avgActMat, dims = 2)


    return avgActVisit, medActVisit, varActVisit, corActVisit, avgActMat
end

################################################################################
function getAEEStat(myDir::String, myFiles::Array{String,1}, colNum::Int)
    # getStatAct(myDir::String, myFiles::Array{String,1})
    #
    # Synopsis:
    # getAEEStat get the statsistics of the energy expenditure for each day and for
    # for the total time wearing the accelerometer.
    #
    # Input:
    # - myDir           String              Contains directory location
    # - myFiles         Array{String, 1}       Contains files data names
    # - colNum          Integer                 Contains the id column of data frame
    #
    # Output:
    # - avgActMat           Array{Float64, 1}   Average of activity over 24 hours for all subjects during a given visit
    # - varActVisit         Array{Float64, 1}   Variance of activity over 24 hours for all subjects during a given visit
    # - corActVisit         Array{Float64, 2}   Correlation of activity over 24 hours for all subjects during a given visit
    #
    # Example:
    #
    #-------------------------------------------------------------------------------

    # Get the total number of files in the directory myDir
    numFiles = length(myFiles)
    # Create the matrix that contains all average activity of each subject
    avgActMat = ones(1440, numFiles)

    # Create the matrix that contains all median activity of each subject
    medActMat = ones(1440, numFiles)


    for i = 1:numFiles
        # Read file
        dfD = readActivity(myDir * myFiles[i])

        # Convert the column DateTime to DateTime type
        dfD[:DateTime] = DateTime(dfD[:DateTime])

        # Get timing of the first and last epoch in order to estimate the
        # total number of days.
        myStartTime = dfD[1, 3]
        myFinishTime = dfD[end, 3]

        # Get the total number of seconds wearing the device
        totalWearTime = convert(
            Float64,
            Dates.value(Dates.Second((myFinishTime - myStartTime))),
        ) #in seconds
        completeNumDays = Int(floor(totalWearTime / 86400)) # number of day with full 24 hours

        # Reshape the vector in matrix such that each column corresponds to 24 hours of wearing time.
        matActivity =
            reshape(dfD[1:completeNumDays*1440, colNum], 1440, completeNumDays) # 1440 min in 24 hours
        matActivity = matActivity[:, :]

        # Get the activity count average over for full days.
        avAct = mean(matActivity, dims = 2)
        medAct = median(matActivity, dims = 2)# median over for full days.

        # Get the first 24 hours
        dtS = Dates.format(dfD[1:1440, 3], "HH:MM")

        # Sort time vector and get the indices of permutation
        idx = sortperm(dtS)

        # Reorder the activity count vector such that timing start at 00:00 and
        # at finish at 23:59
        avAct = avAct[idx]
        medAct = medAct[idx]# re-ordering for the median values

        # Add the new column in the average activity matrix form 00:00 to 23:59
        avgActMat[:, i] = avAct[:]
        medActMat[:, i] = medAct[:]# for median values
    end

    # Get the activity data average over for full days for all subjects.
    #avgActVisit = mean(log2.(avgActMat+1), 2);
    avgActVisit = mean(avgActMat, dims = 2)

    # Get the activity data average over for full days for all subjects.
    #medActVisit = median(log2.(avgActMat+1), 2);
    medActVisit = median(medActMat, dims = 2)#median(avgActMat, 2);

    # Get the activity data variance over for full days for all subjects.
    #varActVisit = var(log2.(avgActMat+1), 2);
    varActVisit = var(avgActMat, dims = 2)
    # Get the activity data correlation over for full days for all subjects.
    #corActVisit = cor(log2.(avgActMat+1), 2);
    corActVisit = cor(avgActMat, dims = 2)


    return avgActVisit, medActVisit, varActVisit, corActVisit, avgActMat
end








################################################################################
function getStatActMed(myDir::String, myFiles::Array{String,1}, colNum::Int)
    # getStatAct(myDir::String, myFiles::Array{String,1})
    #
    # Synopsis:
    # getStatActMed builds a median activity matrix, MxN where M is numbers of
    # epochs (1440 minutes) and N is the number of subjects for a given visit (e.g.
    # Baseline, 32 Week Gestation, 6 Weeks PP...). It also saves the matrix in the
    # corresponding  vistit folder. Finally, it returns the average activity over the
    # number of subject and the standard deviation.
    #
    # Input:
    # - myDir               String              Contains directory location
    # - myFiles          Array{String, 1}       Contains files data names
    # - colNum          Integer                 Contains the id column of data frame
    #
    # Output:
    # - avgActMat           Array{Float64, 1}   Average of activity over 24 hours for all subjects during a given visit
    # - varActVisit         Array{Float64, 1}   Variance of activity over 24 hours for all subjects during a given visit
    # - corActVisit         Array{Float64, 2}   Correlation of activity over 24 hours for all subjects during a given visit
    #
    # Example:
    #
    #-------------------------------------------------------------------------------

    # Get the total number of files in the directory myDir
    numFiles = length(myFiles)
    # Create the matrix that contains all average activity of each subject
    avgActMat = ones(1440, numFiles)

    for i = 1:numFiles
        # Read file
        dfD = readActivity(myDir * myFiles[i])

        # Convert the column DateTime to DateTime type
        #dfD[:DateTime] = DateTime(dfD[:, :DateTime])

        # Get timing of the first and last epoch in order to estimate the
        # total number of days.
        myStartTime = dfD[1, 3]
        myFinishTime = dfD[end, 3]

        # Get the total number of seconds wearing the device
        totalWearTime = convert(
            Float64,
            Dates.value(Dates.Second((myFinishTime - myStartTime))),
        ) #in seconds
        completeNumDays = Int(floor(totalWearTime / 86400)) # number of day with full 24 hours

        # Reshape the vector in matrix such that each column corresponds to 24 hours of wearing time.
        matActivity =
            reshape(dfD[1:completeNumDays*1440, colNum], 1440, completeNumDays) # 1440 min in 24 hours
        matActivity = matActivity[:, :]

        # Get the activity count average over for full days.
        avAct = median(matActivity, 2)

        # Get the fisrt 24 hours
        dtS = Dates.format(dfD[1:1440, 3], "HH:MM")

        # Sort time vector and get the indices of permutation
        idx = sortperm(dtS)

        # Reorder the activity count vector such that timing start at 00:00 and
        # at finish at 23:59
        avAct = avAct[idx]

        # Add the new column in the average activity matrix form 00:00 to 23:59
        avgActMat[:, i] = avAct[:]
    end

    # Get the activity count average over for full days for all subjects.
    #avgActVisit = mean(log2.(avgActMat+1), 2);
    avgActVisit = mean(avgActMat, 2)

    # Get the activity count average over for full days for all subjects.
    #medActVisit = median(log2.(avgActMat+1), 2);
    medActVisit = median(avgActMat, 2)

    # Get the activity count variance over for full days for all subjects.
    #varActVisit = var(log2.(avgActMat+1), 2);
    varActVisit = var(avgActMat, 2)
    # Get the activity count correlation over for full days for all subjects.
    #corActVisit = cor(log2.(avgActMat+1), 2);
    corActVisit = cor(avgActMat, 2)


    return avgActVisit, medActVisit, varActVisit, corActVisit, avgActMat
end# function

################################################################################
"""
**`getComplete24h`** -*Function*.

    `getComplete24h(myDf::DataFrames.DataFrame)` => `Int64`

Estimates the total number of complete 24 hours.

"""
function getComplete24h(myDf::DataFrames.DataFrame)
    # Convert the column DateTime to DateTime type
#     myDf[:DateTime] = DateTime(myDf[: ,:DateTime])

    # Get timing of the first and last epoch in order to estimate the
    # total number of days.
    myStartTime = myDf[1, 3]
    myFinishTime = myDf[end, 3]

    # Get the total number of seconds wearing the device
    totalWearTime = convert(
        Float64,
        Dates.value(Dates.Second((myFinishTime - myStartTime))),
    ) #in seconds
    completeNumDays = Int(floor(totalWearTime / 86400)) # number of day with full 24 hours
    return completeNumDays

end# function

################################################################################
"""
**`getCompleteDays`** -*Function*.

    `getCompleteDays(myDf::DataFrames.DataFrame, filterData::Bool = false)` => `Int64`/ `DataFrames`

Returns the total number of complete days. If filterData is true, it returns a data frame that contains 
only complete days.

"""
function getCompleteDays(myDf::DataFrames.DataFrame, filterData::Bool = false)
    # Ignore first and last day since incomplete
    completeNumDays = length(unique(myDf.Day)) - 2 
    
    if filterData
        # filter first day (remove day 1)
       myDf = filter(row -> row.Day != 1, myDf)
                
        # filter last day (remove last day)
        lastDay = myDf.Day[end]
        myDf = filter(row -> row.Day != lastDay, myDf)
        
        return myDf
    else
        return completeNumDays
    end

end# function

################################################################################
"""
**`getIntensity`** -*Function*.

    `getIntensity(df::DataFrames.DataFrame, asDataFrame::Bool = false, ; digits::Int64 = 3)` => `Array{Float64,3}`

Returns matrix or data frame that contains activity intensity summary  for each day. Dimension 1 represents each levels: sedentary, light, moderate, vigorous. Dimension 2 represents type of value: total intensity and percentage intensity.
Dimension 3 represents day number.

"""
function getIntensity(df::DataFrames.DataFrame, asDataFrame::Bool = false; digits::Int64 = 2)
    # initialize
    vDays = unique(df.Day)
    numDays = length(vDays)
    weekIntensity = zeros(4, 2, numDays)
    
    for i = 1:numDays
        vIntensity = df[df.Day .== vDays[i], :ActivityIntensity];
        vIntensity = sort(vIntensity);
        vCount = counts(vIntensity);
   
        if length(vCount) < 4
            if length(vCount) < 3
                if length(vCount) < 2
                    weekIntensity[1,:, i] = [vCount vCount.*100/sum(vCount)];
                else
                    weekIntensity[1:2,1:2, i] = [vCount vCount.*100/sum(vCount)];
                end # if
            else
                weekIntensity[1:3,1:2, i] = [vCount vCount.*100/sum(vCount)];
            end # if
        else
            weekIntensity[:,:,i] = [vCount vCount.*100/sum(vCount)];
        end # if
        weekIntensity[:,2,i] = roundPer(weekIntensity[:,2,i], digits)
        
    end # for
    
    return weekIntensity  
end# function




################################################################################
"""
**`getAccAC`** -*Function*.

    `getAccAC(df::DataFrames.DataFrame)` => `DataFrames`

Returns data frame that contains accumulated activity count for each day.

"""
function getAccAC(df::DataFrames.DataFrame)
    # initialize
    vDays = unique(df.Day)
    vDateTime = unique(Dates.Date.(df.DateTime))
    numDays = length(vDays)
    dfAccAc = DataFrame(Day = vDays, 
                        DateTime = vDateTime,
                        DayName = Dates.dayname.(vDateTime),
                        DayOfWeek = Dates.dayofweek.(vDateTime),
                        TotalAC = Array{Int64,1}(undef, numDays)
#                         TotalSteps =  Array{Int64,1}(undef, numDays)
                            ) 
        
    # estimate accumulative activity counts for each days
    for i in 1:numDays
        dfAccAc.TotalAC[i] = sum(df.ActivityCounts[findall(x -> x == vDays[i], df.Day)])
#         dfAccAc.TotalSteps[i] = sum(df.Steps[findall(x -> x == vDays[i], df.Day)])
        
    end
    
    return dfAccAc  
end# function

################################################################################
"""
**`filterAccDays`** -*Function*.

    `filterAccDays(df::DataFrames.DataFrame, thresh::Int64 = 0)` => `DataFrames`

Filters days with acccumulated activity counts less or equal to a threshold (default is 0) , and returns filtered data frame.

"""
function filterAccDays(df::DataFrames.DataFrame, thresh::Int64 = 0)
    
    # get total AC data frame
    dfAccAC = getAccAC(df)
    
    # get days where total AC is strictly greater than thresh
    idxFilt = findall(x -> x > thresh,  dfAccAC.TotalAC)
    dayAccAC = dfAccAC.Day[idxFilt]
    
    # filter days with zero accumulative activity counts    
    return filter(row -> row.Day ⊆ dayAccAC, df)  
end



################################################################################
"""
**`checkRequiredDays`** -*Function*.

    `checkRequiredDays(df::DataFrames.DataFrame)` => `Bool`

Returns true if and only if activity days fit requirement: at least 1 weekend day and 2 week days.

"""
function checkRequiredDays(df::DataFrames.DataFrame)
    # create a set containing week days: 1 (Monday) to 5 (Friday) 
    vWeekDayCode = collect(1:5);
    # create a set containing weekend days: 6 (Saturday) to 5 (Sunday)
    vWeekendDayCode = collect(6:7);
    
    # initialize days counters
    numWeekDay = 0
    numWeekEndDay = 0

    # check if days meet requirements
    for i in 1:length(df.DayOfWeek)
        if df.DayOfWeek[i] ⊆ vWeekDayCode
            numWeekDay += 1
        else
            numWeekEndDay += 1
        end
    end

    if (numWeekDay >= 2) & (numWeekEndDay >= 1)
        areDaysOk = true
    else 
        areDaysOk = false
    end
    
    return areDaysOk

end # function


################################################################################
"""
**`getIndivTotal`** -*Function*.

    `getIndivTotal(df::DataFrames.DataFrame, filt::Bool = false)` => `DataFrames`

Returns data frame that contains total info per day.

"""
function getIndivTotal(df::DataFrames.DataFrame, filt::Bool = false; thresh::Int64 = 0)
    
    if filt
        # filter incomplete day, i.e. less than 24H
        dfTmpFilt = ActStatData.getCompleteDays(df, true);
        
        # filter zero activity day
        dfTmpFilt = ActStatData.filterAccDays(dfTmpFilt, thresh);

        # keep only 5 days max
        df = filter(row -> row.Day <= unique(dfTmpFilt.Day)[1]+4, dfTmpFilt)
    end

    
    # get intensity level info
    mIntensity = getIntensity(df)
    
    # initialize
    vDays = unique(df.Day)
    vDateTime = unique(Dates.Date.(df.DateTime))
    numDays = length(vDays)
    
    dfIndivTotal = DataFrame(Day = vDays, 
                        DateTime = vDateTime,
                        DayName = Dates.dayname.(vDateTime),
                        DayOfWeek = Dates.dayofweek.(vDateTime),
                        TotalAC = Array{Int64,1}(undef, numDays),
                        TotalSteps =  Array{Union{Missing, Int64},1}(undef, numDays),
                        Sedentary = mIntensity[1, 1, :],
                        Light = mIntensity[2, 1, :],
                        Moderate = mIntensity[3, 1, :],
                        Vigorous = mIntensity[4, 1, :]) 
        
    # estimate accumulative activity counts for each days
    for i in 1:numDays
        dfIndivTotal.TotalAC[i] = sum(df.ActivityCounts[findall(x -> x == vDays[i], df.Day)])
        dfIndivTotal.TotalSteps[i] = sum(df.Steps[findall(x -> x == vDays[i], df.Day)])
        
    end
    
    return dfIndivTotal  
end# function




end # Module ActStatData

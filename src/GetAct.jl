
"""
**`GetIndivAct`** -*Function*.

    `GetIndivAct(fileName::String; actType = 1, resmin::Int64 = 1, isavg::Bool = true)` => `vector`

Returns a vector containing the average of an activity type over maximum 7 days.

- `filename` contains the path of the individual data in a specific folder.
- `actype` indicates the type of activity to be processed (1=>:Activity Counts, 
  2=> number of Steps, 3=> Energy Expenditure, 4=> Activity Intensity)
- `resmin` indicates temporal resolution of activity acquisition in minutes. 
- `isavg` is a boolean where true means that the return is the average data over one week
  and false means that the return is the full week cycle.
"""
function GetIndivAct(fileName::String; actType = 1, resmin::Int64 = 1, isavg::Bool = true)
    
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
    numDays = ifelse(ActStatData.getCompleteDays(df)>=8, 8, ActStatData.getCompleteDays(df)) # previously 7
    
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
    
    dfAct[:, :day1] .= ifelse.(ismissing.(dfAct[!, :day1]) , dfAct[!, lastDay], dfAct[!, :day1]);
    select!(dfAct, Not(lastDay));

    # Transpose dataframe
    dfAct = DataFrame([[names(dfAct)]; collect.(eachrow(dfAct))], [:day; Symbol.(axes(dfAct, 1))])
    select!(dfAct, Not(:day))

    # Get average activity 
    if isavg
        return sum(reshape(mean.(eachcol(dfAct)), resmin, Int(1440/resmin)), dims = 1)[:] # TO DELETE mean.(eachcol(dfAct)) 
    else
        # Total number of minutes over complete days
        ttMin = Int(1440*(numDays-1))
        rslt = reshape(copy(transpose(convert(Matrix, dfAct))), ttMin, 1)
        return  sum(reshape(rslt, resmin, Int(ttMin/resmin)), dims = 1)[:]# TO DELETE reshape(copy(transpose(convert(Matrix, dfAct))), ttMin, 1) 
    end
end


"""
**`GetDirAct`** -*Function*.

    `GetDirAct(dirName::String; actType::Int64 = 1)` => `Matrix, vector`

Returns a matrix containing the activity data of all individual in a specific directory, and a vector containing the ID of all the individual.

- `dirName` contains the path of the directory containing the individuals data.
- `actype` indicates the type of activity to be processed (1=>:Activity Counts, 
  2=> number of Steps, 3=> Energy Expenditure, 4=> Activity Intensity)
- `isavg` is a boolean where true means that the return is the average data over one week
  and false means that the return is the full week cycle.
- `resmin` indicates temporal resolution of activity acquisition in minutes. 
"""
function GetDirAct(dirName::String; actType::Int64 = 1, resmin::Int64 = 1)
    # Get the data list files from the directory myDir
    (dataFiles, bioFiles) = ActStatData.filesNoNaN(dirName);
    
    # Total number of files in the directory dirName
    numFiles = length(dataFiles)
    
    # Keep ID of individual
    vecID = Array{Int64, 1}(undef, numFiles)
    
    # Create average activity matrix 
    avgActMat = Array{Float64}(undef, Int(1440/resmin), numFiles)
    
    for  i = 1:numFiles
        # Get average Activity over 7 days
#         println(dirName * dataFiles[i])
        avgAct = GetIndivAct(dirName * dataFiles[i], actType = actType, resmin = resmin)
                
        # Add the new column in the average activity matrix form 00:00 to 23:59
        avgActMat[:, i] = avgAct[:]
        
        # Collect ID
        vecID[i] = GetIndivID(dirName * bioFiles[i])    
    end
        
    return avgActMat, vecID
    
end
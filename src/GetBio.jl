using DataFrames
"""
**`VisitsBio`** type is an object that contains data frames for each visits describing bio information
"""
mutable struct VisitsBio
    vBaseline::DataFrame
    v32weeks::DataFrame
    v6weeksPP::DataFrame
    v6monthsPP::DataFrame
    v12monthsPP::DataFrame
end

"""
**`GetBio`** -*Function*.

    `GetBio(dfBio::DataFrame)` => `Tuple`

Returns a tuple containing the bio information of an individual as:
- id
- age 
- height
- weight
- start date

"""
function GetBio(dfBio::DataFrame)
    tplDem = NamedTuple{(:id, :age, :height, :weight, :startdate),
            Tuple{Int64, Int64, Float64, Float64, DateTime}}((
            parse(Int64, dfBio[1, :Value]), # id
            parse(Int64, dfBio[2, :Value]), # age
            parse(Float64, dfBio[4, :Value]), # height
            parse(Float64, dfBio[6, :Value]),  # weight
            parse(DateTime, dfBio[8, :Value]*"T"*dfBio[9, :Value]) # start date
            ))
    
    return tplDem
end

"""
**`GetIndivID`** -*Function*.

    `GetIndivID(fileName::String)` => `Int64`

Returns the ID of an individual.

"""
function GetIndivID(fileName::String)
    dfBiorg = ActStatData.readActivity(fileName);
    return GetBio(dfBiorg).id
end

"""
**`GetVisitBio`** -*Function*.

    `GetVisitBio(bioFiles::Array{String,1}, visitName::String)` => `DataFrame`

Returns a data frame containing the bio information of all individuals collected during a specific visit:
- id
- age 
- height
- weight
- start date

"""
function GetVisitBio(bioFiles::Array{String,1})
    
    numFiles = length(bioFiles)
    # Initialize vectors
    vecID = Vector{Int64}(undef, numFiles)
    vecAge = Vector{Int64}(undef, numFiles)
    vecHeight = Vector{Float64}(undef, numFiles)
    vecWeight = Vector{Float64}(undef, numFiles)
    vecStartDate = Array{DateTime}(undef, numFiles) 
    
    # Fill up vectors
    for i = 1:numFiles 
        dfBiorg = ActStatData.readActivity(bioFiles[i]);
        tplBio = GetBio(dfBiorg)
        vecID[i]  = tplBio.id
        vecAge[i] = tplBio.age
        vecHeight[i] = tplBio.height
        vecWeight[i] = tplBio.weight
        vecStartDate[i] = tplBio.startdate
    end
 
    # Build data frame
    df = DataFrame(studyID = vecID,
                   age = vecAge,
                   height = vecHeight,
                   weight = vecWeight,
                   startDate = vecStartDate
                  )
    return df 
end

"""
**`GetAllVisitBio`** -*Function*.

    `GetAllVisitBio(bioFiles::Array{String,1}, visitName::String)` => `DataFrame`

Returns a list containing all data frame bio of each visit.

"""
function GetAllVisitBio(visitDir::Array{String,1}, groupFileName::String)
    
    # Construct 
    allVisitsBio = VisitsBio(DataFrame(A = [1]), DataFrame(B = [1]),
                            DataFrame(C = [1]), DataFrame(D = [1]),
                            DataFrame(E = [1]))
    
    # Load the group assignment information
    dfDem = DataFrame!(CSV.File(groupFileName));
    sort!(dfDem)
    
    
    for n = 1:5#length(listDir)
        
    
        # Get the list of files in the data directory myDir.
        (actFiles, bioFiles) = ActStatData.filesNoNaN(visitDir[n]);

        bioFiles = abspath.(string.(visitDir[n], bioFiles))
        
        # get bio data frame for a visit
        df = GetVisitBio(bioFiles)

#         global dfDem = leftjoin(dfDem, df, on = :StudyID)
        
        dfVisit = leftjoin(dfDem, df, on = :studyID)
        setfield!(allVisitsBio, fieldnames(typeof(allVisitsBio))[n], dfVisit)
    end

    return allVisitsBio
    
end    
    
"""
**`GetVisitsSampleSize`** -*Function*.

    `GetVisitsSampleSize(vstBio::VisitsBio)` => `DataFrame`

Returns a data frame decribe sample size of the visits.

"""
function GetVisitsSampleSize(vstBio::VisitsBio)
    
    
    # Initialize data frame
    vstSampleSize = DataFrame(Visit = Array{String}(undef, 5), SampleSize = zeros(Int64, 5), 
                            NumberOfMissings = zeros(Int64,5))
       
    
    for n = 1:5#length(listDir)
        
        idxMissing = findall(x -> isequal(missing, x), getfield(vstBio, fieldnames(typeof(vstBio))[n]).age)
        vstSampleSize[n, 1] = string(fieldnames(typeof(vstBio))[n])
        vstSampleSize[n, 2] = length(getfield(vstBio, fieldnames(typeof(vstBio))[n]).age) - length(idxMissing)
        vstSampleSize[n, 3] = length(idxMissing)
    
    end

    return vstSampleSize
    
end 

"""
**`GetVisitsSampleSize`** -*Function*.

    `GetVisitsSampleSize(visitDir::Array{String,1}, groupFileName::String)` => `DataFrame`

Returns a data frame decribe sample size of the visits.

"""
function GetVisitsSampleSize(visitDir::Array{String,1}, groupFileName::String)
    
    vstBio = GetAllVisitBio(visitDir, groupFileName);
    
    return GetVisitsSampleSize(vstBio)
    
end 

"""
**`GetMissingID`** -*Function*.

    `GetMissingID(vstBio::VisitsBio)` => `Array{Int64}`

Returns a vector containing the ID of missing data for a visit.

"""
function GetMissingID(dfBio::DataFrame)
  
#     idxMissing = findall(x -> isequal(missing,x), getfield(vstBio, fieldnames(typeof(vstBio))[1]).age)
#     getfield(vstBio, fieldnames(typeof(vstBio))[1]).studyID[idxMissing]
    
    idxMissing = findall(x -> isequal(missing,x), dfBio.age)
    
    return dfBio.studyID[idxMissing]
    
end 

"""
**`DropMissingObs`** -*Function*.

    `DropMissingObs(vstBio::VisitsBio)` => `VisitsBio`

Returns a data frame containing the ID of missing data for a visit.

"""
function DropMissingObs(vstBio::VisitsBio)

    # Construct 
    allVisitsBio = VisitsBio(DataFrame(A = [1]), DataFrame(B = [1]),
                            DataFrame(C = [1]), DataFrame(D = [1]),
                            DataFrame(E = [1]))
    

    for n = 1:5#length(listDir) 
        
        df = dropmissing(getfield(vstBio, fieldnames(typeof(vstBio))[n]))
        setfield!(allVisitsBio, fieldnames(typeof(allVisitsBio))[n], df)
    
    end    
    
        
    return allVisitsBio
    
end 

"""
**`conjointVisitID`** -*Function*.

    `conjointVisitID(N::Int64, visitID::Any)` => `Array{Any,1}`

Returns an array of vector containing the conjoint IDs between the time point *t* and *t-1*.

"""
function conjointVisitID(N::Int64, vstBio::VisitsBio)
    
    # Build visitID arrays
    visitID = Any[]
    for i in 1:5 
        push!(visitID,getfield(vstBio, fieldnames(typeof(vstBioCmplt))[i]).studyID);
    end
    
    # Check for time points range 
    if N < 1 || N > 5
        return error("Number of visit is out of range")
    end
    
    # Initialize arrays
    cjointID = Any[]
    
    # Fill up cjointID 
    if N >= 2
        push!(cjointID, intersect(visitID[1], visitID[2]));
    end
    
    global i = 3
    
    while i <= N
        push!(cjointID, intersect(cjointID[i-2], visitID[i]));
        i += 1
    end
    pushfirst!(cjointID, visitID[1])
    
    return cjointID
end 

"""
**`conjointVisit`** -*Function*.

    `conjointVisitID(N::Int64, visitID::Any)` => `Array{Any,1}`

Returns a vector containing the vector length of conjoint IDs between the time point *t* and *t-1*.

"""
function conjointVisit(N::Int64, visitID::Any)
    
    return length.(conjointVisitID(N, visitID))
    
end 

    
"""
**`GetCommonID`** -*Function*.

    `GetCommonID(vstBio::VisitsBio, visit1::Int64, visit2::Int64)` => `Vector{Int64}`

Returns a vector containing the conjoint IDs between the time point *t* and *t-1*.

"""
function GetCommonID(N::Int64, visitID::Any)
    
    return length.(conjointVisitID(N, visitID))
    
end 

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    




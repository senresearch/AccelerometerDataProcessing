"""
**`Mat2DfAct`** -*Function*.

    `Mat2DfAct(mat::Array{Float64, 2}, vecID::Array{Int64, 1}; resmin::Int64 = 1)` => `data frame`

Returns a dataframe containing activity data for each individual.

- `mat` contains the activity matrix.
- `vecID` is a vector that contains the ID individual for each activity pattern inside the activity matrix.
- `resmin` indicates temporal resolution of activity acquisition in minutes. 

"""
function Mat2DfAct(mat::Array{Float64, 2}, vecID::Array{Int64, 1}; resmin::Int64 = 1)
    
    # Transpose the matrix: ID rowwise and time columnwise
    mat = copy(transpose(mat))

    d = Dates.Time("00:00", "HH:MM"):Dates.Minute(resmin):Dates.Time("00:00", "HH:MM") + Dates.Hour(24) - Dates.Minute(1)
    d = string.(collect(d))
    for i= 1:length(d) d[i] = d[i][1:5] end
    d = "T".*replace.(d, ":"=> "h") 
    df  = DataFrame([@view(mat[:, i]) for i in 1:size(mat, 2)], Symbol.(d))
    
    insertcols!(df, 1, :studyID => vecID)
    
    return df 
    
end


"""
**`nonunique`** -*Function*.

    `nonunique(x::AbstractArray{T})` => `vector`

Returns an array containing all the elements that appear at least twice in its input.

"""
function nonunique(x::AbstractArray{T}) where T
    sort!(x)
    duplicatedvector = T[]
    for i=2:length(x)
        if (isequal(x[i],x[i-1]) && (length(duplicatedvector)==0 || !isequal(duplicatedvector[end], x[i])))
            push!(duplicatedvector,x[i])
        end
    end
    
    return duplicatedvector
end



"""
**`roundPer`** -*Function*.

    `roundPer(Xp::Array{Float64,2}, roundUp::Integer)` => `Array{Float64,2}`

Round percentages such that the sum of % values are equal exactly to 100, columnwise.

"""
function roundPer(Xp::Array{Float64,2}, roundUp::Integer)
   szXp = size(Xp)
   Xpr = deepcopy(Xp)
   for i = 1:szXp[2]
      Xpr[:,i] = roundPer(Xp[:,i], roundUp)
   end
   return Xpr
end # roundPer

"""
**`roundPer`** -*Function*.

    `roundPer(X::Array{Float64,1}, rUp::Integer)` => `Array{Float64,1}`

Round percentages such that the sum of % values are equal exactly to 100.

"""

function roundPer(X::Array{Float64,1}, rUp::Integer)
        Xup = 10^rUp .*X
        Y = floor.(Xup)
        # Get the number of values to be increased by 1
        num2round = Int(100*10^rUp - sum(Y))
        diff = Xup-Y
        # Get the index of the num2round highest values to increase by 1
        idx = sortperm(Xup-Y, rev = true)
        # Increase by 1 the values to be rounded
        Y[idx[1:num2round]] = (Y[idx[1:num2round]] .+1)
        # Get the new percentage values
        Xrper = Y ./10^rUp
        return Xrper
end


################################################################################
"""
**`getIntersect`** -*Function*.

    `getIntersect(df1::DataFrame, df2::DataFrame)` => `DataFrame`, `DataFrame`

Returns two data frames whose IDs intersect.
"""
function getIntersect(df1::DataFrame, df2::DataFrame)
    
    newdf1 = filter(row -> row.studyID ⊆ df2.studyID, df1);
    newdf2 = filter(row -> row.studyID ⊆ newdf1.studyID, df2);
   
    return newdf1, newdf2

end
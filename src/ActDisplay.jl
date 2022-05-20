
"""
ActDisplay
============

Synopsis
--------
*ActDisplay* generates plot to visualize average activity summary per category.

Exported Functions
------------------
* `getCatActSummary`: Split-compute-combine and returns a data frame

* `plotCatActLvlSummary`: Plots average activity summary per category

See also
--------
ActStatData.jl

References
----------
https://github.com/davidanthoff/ExcelReaders.jl
http://aviks.github.io/Taro.jl/#usage
https://juliadata.github.io/CSV.jl/stable/
"""


include("ActStatData.jl")
using PyCall
pygui(:tk)
using PyPlot, DataFrames, Dates
using CSV, DelimitedFiles, StatsBase
PyPlot.svg(true)

import .ActStatData






"""
**`getCatActSummary`** -*Function*.

    `getCatActSummary(df::DataFrame, catName::Symbol, valName::Array{Symbol,1}; compPerc::Bool = false)` => `DataFrame`

Returns a data frame containing the mean of every indicated variables in `valName` per category 
according to the selector `catName`. If `compPerc` is `true` (default is `false`), it computes the percentage for all variables form `valName`.

"""
function getCatActSummary(df::DataFrame, catName::Symbol, valName::Array{Symbol,1}; compPerc::Bool = false, roundUp::Integer = 2, ismedian::Bool = false )
    
    # select only variables of interest with first column the categorical variable
    select!(df, vcat(catName, valName))
    
    # split-compute-combine
    gd = groupby(df, catName)
    if ismedian
        dfAvgPerCat = combine(gd, nrow, valName .=> median .=> valName)
    else
        dfAvgPerCat = combine(gd, nrow, valName .=> mean .=> valName)
    end
    # compute percentage if compPerc is true
    if compPerc
        mAvgPerCat = Matrix(dfAvgPerCat[:, 3:end])
        mAvgPerCat = roundPer(collect(transpose((mAvgPerCat./sum(mAvgPerCat, dims = 2)).*100)), roundUp)
        mAvgPerCat = collect(transpose(mAvgPerCat))  
        dfAvgPerCat[:, 3:end] = mAvgPerCat
    end
    
    return sort(dfAvgPerCat, catName)    
end


################################################################################
"""
**`plotCatActLvlSummary`** -*Function*.

    `plotCatActLvlSummary(df::DataFrame, visitName::String = "")` => `PyPlot`

Plots average activity summary per category.

"""
function plotCatActLvlSummary(df::DataFrame, visitName::String = "")
    if size(df)[2]>3
        vCat = Vector(df[:,1]) 
        mVal = Matrix(df[:,3:end])

        # plot bar level of activity per category
        fig1 = figure("pyplot_barplot",figsize=(7,5))
        myWidth = 0.7;

        bar(vCat, mVal[:,1] ,width = myWidth, label = "Sedentary",
            align="center", color = "#2c7bb6")

        bar(vCat, mVal[:,2], width = myWidth,
            bottom = mVal[:,1], label = "Light", align="center",
            color = "#ffffbf")

        bar(vCat, mVal[:,3], width = myWidth,
            bottom = mVal[:,2]+mVal[:,1],
            label = "Moderate", align="center",color = "#fdae61")

        bar(vCat, mVal[:,4], width = myWidth,
            bottom = mVal[:,3]+mVal[:,2]+mVal[:,1],
            label = "Vigorous", align="center",color = "#d7191c")

        axis("tight")
        title(string(visitName, "Activity Intensity per ", string(names(df)[1])))
        grid(false)
        legend(bbox_to_anchor=(1.3,0.75))
        xlabel(string(names(df)[1]))
        ylabel("Average Percentage of Time Engaging in Activity")
        fig1.autofmt_xdate(bottom=0.25,rotation=30,ha="right")
    #     savefig("/home/faragegr/Projects/smartbandactivity2018/develop/test/temp_images/fig2.svg", dpi= 300)

        ax2 = gca();
        ax2.spines["top"].set_visible(false); # Hide the top edge of the axis
        ax2.spines["right"].set_visible(false); # Hide the right edge of the axis

        # Close all figures
    #     PyPlot.close()
    else
        vCat = Vector(df[:,1]) 
        vVal = Vector(df[:,3])

        # plot bar level of activity per category
        fig1 = figure("pyplot_barplot",figsize=(7,5))
        myWidth = 0.7;

        bar(vCat, vVal,width = myWidth, label = names(df)[3],
            align="center", color = "#2c7bb6")
        axis("tight")
        title(string(visitName, string(names(df)[3], " per "), string(names(df)[1])))
        grid(false)
        legend(bbox_to_anchor=(1.3,0.75))
        xlabel(string(names(df)[1]))
        ylabel("Intensity Level")
        fig1.autofmt_xdate(bottom=0.25,rotation=30,ha="right")
    #     savefig("/home/faragegr/Projects/smartbandactivity2018/develop/test/temp_images/fig2.svg", dpi= 300)

        ax2 = gca();
        ax2.spines["top"].set_visible(false); # Hide the top edge of the axis
        ax2.spines["right"].set_visible(false); # Hide the right edge of the axis

        # Close all figures
    #     PyPlot.close()
        
    end
    
end

















function getWeekEEAct(myActData::String, myActHeader::String,
                      completeNumDays = 7)
# getWeekEEAct(myActData::String, myActHeader::String)
#
# Synopsis:
# getWeekEEAct generates a data frame containing Activity summary.
#
# Args:
# - myActData             String         Contains full path of data file
# - myActHeader           String         Contains full path of header file
#
# Returns:
# - durationDay       Array{String, 1}        List of dates
# - sumAEE            Array{Float64, 1}       Daily physical activity calories
# - weekIntensity     Array{Float64, 3}       Percentage of daily activity level
#
# Example:
#
#-------------------------------------------------------------------------------

    # Get the weight from the bio file
    dfB = ActStatData.readActivity(myActHeader)
    wght = parse(Float64, dfB[6,2]);

    # Get any file and show columns of the data frame structure
    df = ActStatData.readActivity(myActData);

    # Select the first 'completeNumDays' days
    df = df[df.Day .< completeNumDays+1, :];

    # Estimate the total amount of calories burnt per day
    dfSumAct = by(df, :Day) do d
        DataFrame(ActCalPerDiem = sum(d.EnergyExpenditure).*wght)
    end

    # Create vectors containing daily calories burnt by physical activity
    sumAEE = dfSumAct.ActCalPerDiem
    sumAEE = collect(Iterators.flatten(transpose(sumAEE)));

    # Calculate count value for each level of activity (Light, Moderate, Vigorous)

    weekIntensity = zeros(completeNumDays, 4, 2)
    for i = 1:completeNumDays
        dtmp = df[df.Day .== i, :];
        tmp =  Int64.(collect(Iterators.flatten(dtmp.ActivityIntensity)));
        tmp = sort(tmp);
        if length(counts(tmp)) < 4
            if length(counts(tmp)) < 3
                if length(counts(tmp)) < 2
                    weekIntensity[i,1,:] = [counts(tmp) counts(tmp).*100/sum(counts(tmp))];
                else
                    weekIntensity[i,1:2,1:2] = [counts(tmp) counts(tmp).*100/sum(counts(tmp))];
                end # if
            else
                weekIntensity[i,1:3,1:2] = [counts(tmp) counts(tmp).*100/sum(counts(tmp))];
            end # if
        else
            weekIntensity[i,:,:] = [counts(tmp) counts(tmp).*100/sum(counts(tmp))];
        end # if
    end # for

    # Get timing of the first and last epoch in order to estimate the
    # total number of days.
    myStartTime = df[1,3];
    myFinishTime = df[end,3];
    # Get the total number of seconds wearing the device
    totalWearTime = convert(Float64,Dates.value(Dates.Second((myFinishTime-myStartTime)))); #in seconds
    completeNumDays = Int(floor(totalWearTime/86400)); # number of day with full 24 hours

    # Get the exact date of each day of the week (e.g. Mon, 22 May 2017)
    durationDay = collect(Dates.format.(myStartTime:Day(1):myFinishTime, "e, dd u yyyy"))

    return durationDay, sumAEE, weekIntensity

end

################################################################################
function setPlotEEAct(myDays::Array{String, 1}, mySumAEE::Array{Float64, 1},
                      myWeekIntensity::Array{Float64, 3}, completeNumDays = 7)
# setPlotEEAct(myActData::String, myActHeader::String)
#
# Synopsis:
# setPlotEEAct generates plots and save them in a temporary directory.
#
# Args:
# - myDays              Array{String, 1}        List of dates
# - mySumAEE            Array{Float64, 1}       Daily physical activity calories
# - myWeekIntensity     Array{Float64, 3}       Percentage of daily activity level
#
# Returns:
# -
#
# Example:
#
#-------------------------------------------------------------------------------

    # Plot and save daily physical activity calories.
    fig1 = figure("pyplot_barplot",figsize=(10,5), dpi= 300)
    b = bar(myDays,mySumAEE,color="#0f87bf",align="center",alpha=0.4);
    axis("tight")
    title("Activity Calories burnt per day")
    grid(false)
    xlabel("DAYS")
    ylabel("kCal")
    fig1.autofmt_xdate(bottom=0.25,rotation=30,ha="right")
    savefig("/home/faragegr/Projects/smartbandactivity2018/develop/test/temp_images/fig1.svg", dpi= 600)

    PyPlot.close()
    # Plot and save percentage of daily level of activity.
    fig2 = figure("pyplot_barplot",figsize=(10,5), dpi=300)
    myWidth = 0.8;
    numD = completeNumDays;
    bar(myDays, myWeekIntensity[1:numD,1,2] ,width = myWidth, label = "Sedentary",
        align="center", color = "blue")
    bar(myDays, myWeekIntensity[1:numD,2,2], width = myWidth,
        bottom = myWeekIntensity[1:numD,1,2], label = "Light", align="center",
        color = "yellow")
    bar(myDays, myWeekIntensity[1:numD,3,2], width = myWidth,
        bottom = myWeekIntensity[1:numD,2,2]+myWeekIntensity[1:numD,1,2],
        label = "Moderate", align="center",color = "orange")
    bar(myDays, myWeekIntensity[1:numD,4,2], width = myWidth,
        bottom = myWeekIntensity[1:numD,3,2]+myWeekIntensity[1:numD,2,2]+myWeekIntensity[1:numD,1,2],
        label = "Vigorous", align="center",color = "red")
    axis("tight")
    title("Activity Intensity ratio per day")
    grid(false)
    legend()
    xlabel("DAYS")
    ylabel("Intensity Level %")
    fig2.autofmt_xdate(bottom=0.25,rotation=30,ha="right")
    savefig("/home/faragegr/Projects/smartbandactivity2018/develop/test/temp_images/fig2.svg", dpi= 300)

    # Close all figures
    PyPlot.close()

end

################################################################################
function getPlotSumAEE(myDays::Array{String, 1}, mySumAEE::Array{Float64, 1},
                       completeNumDays = 7)
# setPlotEEAct(myActData::String, myActHeader::String)
#
# Synopsis:
# setPlotEEAct generates plots and save them in a temporary directory.
#
# Args:
# - myDays              Array{String, 1}        List of dates
# - mySumAEE            Array{Float64, 1}       Daily physical activity calories
# - myWeekIntensity     Array{Float64, 3}       Percentage of daily activity level
#
# Returns:
# -
#
# Example:
#
#-------------------------------------------------------------------------------

    # Plot and save daily physical activity calories.
    fig1 = figure("pyplot_barplot",figsize=(10,5), dpi= 300)
    b = bar(myDays,mySumAEE,color="#0f87bf",align="center",alpha=0.4);
    axis("tight")
    title("Activity Calories burnt per day")
    grid(false)
    xlabel("DAYS")
    ylabel("kCal")
    fig1.autofmt_xdate(bottom=0.25,rotation=30,ha="right")

    display(fig1)

end

################################################################################
function getPlotIntensity(myDays::Array{String, 1},
                      myWeekIntensity::Array{Float64, 3}, completeNumDays = 7)
# setPlotEEAct(myActData::String, myActHeader::String)
#
# Synopsis:
# setPlotEEAct generates plots and save them in a temporary directory.
#
# Args:
# - myDays              Array{String, 1}        List of dates
# - mySumAEE            Array{Float64, 1}       Daily physical activity calories
# - myWeekIntensity     Array{Float64, 3}       Percentage of daily activity level
#
# Returns:
# -
#
# Example:
#
#-------------------------------------------------------------------------------

    # Plot and save percentage of daily level of activity.
    fig2 = figure("pyplot_barplot",figsize=(10,5), dpi=300)
    myWidth = 0.8;
    numD = completeNumDays;
    bar(myDays, myWeekIntensity[1:numD,1,2] ,width = myWidth, label = "Sedentary",
        align="center", color = "blue")
    bar(myDays, myWeekIntensity[1:numD,2,2], width = myWidth,
        bottom = myWeekIntensity[1:numD,1,2], label = "Light", align="center",
        color = "yellow")
    bar(myDays, myWeekIntensity[1:numD,3,2], width = myWidth,
        bottom = myWeekIntensity[1:numD,2,2]+myWeekIntensity[1:numD,1,2],
        label = "Moderate", align="center",color = "orange")
    bar(myDays, myWeekIntensity[1:numD,4,2], width = myWidth,
        bottom = myWeekIntensity[1:numD,3,2]+myWeekIntensity[1:numD,2,2]+myWeekIntensity[1:numD,1,2],
        label = "Vigorous", align="center",color = "red")
    axis("tight")
    title("Activity Intensity ratio per day")
    grid(false)
    legend()
    xlabel("DAYS")
    ylabel("Intensity Level %")
    fig2.autofmt_xdate(bottom=0.25,rotation=30,ha="right")

    # Close all figures
    display(fig2)

end

"""
**`checkRequiredDays`** -*Function*.

    `checkRequiredDays(df::DataFrame)` => `Bool`

Returns data frame true if and only if activity days fit requirement: at least 1 weekend day and 2 week days.

"""
function tmpFunc(df::DataFrame, catName::Symbol, valName::Array{Symbol,1}; compPerc::Bool = false)
    
    # select only variables of interest with first column the categorical variable
    select!(df, vcat(catName, valName))
    
    # get categories
    myCat = unique(df[:,1])
    numCat = lenghth(myCat)
    
    # initiate output 
    mAvgPerCat = zeros(numCat, size(df)[2]-1)
    
    for i in 1:numCat
        mAvgPerCat[i,:] = mean(Matrix(filter(row -> row[1] == myCat[i], df)[:, 2:end]), dims = 1)       
    end
    
    # compute percentage if compPerc is true
    if compPerc
        mAvgPerCat = roundPer(collect(transpose((mAvgPerCat./sum(mAvgPerCat, dims = 2)).*100)), 1)
        mAvgPerCat = collect(transpose(mAvgPerCat))  
    end
    
    dfAvgPerCat = DataFrame(mAvgPerCat[i,:], valName)
    insert!(dfAvgPerCat, 1, myCat, catName)
    
    return dfAvgPerCat    
end
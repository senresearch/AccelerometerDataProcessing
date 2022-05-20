
"""
ActEEDisplay
============

Synopsis
--------
*ActEEDisplay* generates data frame containing the summary of physical activity
for the first 7 days.

Exported Functions
------------------
* ``getWeekEEAct``: Returns list of dates for the 7 days,


See also
--------
ActStatData.jl

References
----------
https://github.com/davidanthoff/ExcelReaders.jl
http://aviks.github.io/Taro.jl/#usage
https://juliadata.github.io/CSV.jl/stable/
"""
module ActEEDisplay

include("ActStatData.jl")
using PyCall
pygui(:tk)
using PyPlot, DataFrames, Dates
using CSV, DelimitedFiles, StatsBase

import .ActStatData

export getWeekEEAct



################################################################################
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

################################################################################
function roundPer(Xp::Array{Float64,2}, roundUp::Integer)
# roundPer(Xp::Array{Float64,1}, roundUp::Integer)
#
# Synopsis:
# roundPer rounds percentages such that the sum of percentage values are exactly
# equal to 100.
#
# Args:
# - Xp                  Array{Float64,1}       Vector of values
# - roundUp             Integer                Rounding number after the decimal
#
# Returns:
# - Xrper               Array{Float64,1}       Vector of percentages values
#
# Example:
#
#-------------------------------------------------------------------------------
Xp = transpose(Xp)
   function func(X::Array{Float64,1}, rUp::Integer)
        Xup = 10^roundUp .*X
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
   szXp = size(Xp)
   Xpr = deepcopy(Xp)
   for i = 1:szXp[2]
      Xpr[:,i] = func(Xp[:,i], roundUp)
   end
   Xpr = transpose(Xpr)
   return Xpr
end

end # module

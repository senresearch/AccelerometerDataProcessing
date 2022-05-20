
"""
ActPlotData
===========

Synopsis
--------
*ActPlotData* allows to read excel files and convert them into
csv file.

Exported Functions
------------------
* ``plotAct``: Plots the Activity data array myActData over 24 hours.

* ``dualPlotAct``: Plots the Activity data array over 24 hours with two plots on
                   the same axes with different left and right scales.

* ``plotCircAct``: Plots the Activity array over 24 hours circularly.

* ``smoothPlotAct``: Plots smoothly the Activity array over 24 hours.

See also
--------
ActStatData.jl

References
----------
https://github.com/davidanthoff/ExcelReaders.jl
http://aviks.github.io/Taro.jl/#usage
https://juliadata.github.io/CSV.jl/stable/
"""
module ActPlotData
include("ActStatData.jl")

using PyCall
pygui(:tk)
using PyPlot
using DataFrames, Dates

import .ActStatData



################################################################################
function plotAct(myActData::Array{Float64,2}, myTitle = "Average Activity over 24 hours")
# plotAct(myActData::Array{Float64,2}, myTitle::String)
#
# Synopsis:
# plotAct plots the Activity array myActData over 24 hours.
#
# Args:
# - myActData        Array{Float64, 2}      Contains activity data
# - myTitle          String                 (Optional) Title of the figure
#
# Returns:
# -figure plot
#
# Example:
#
#-------------------------------------------------------------------------------

    # Create abscissa x-axis
    startTime = DateTime("2018-04-27T00:00:00", "yyyy-mm-ddTHH:MM:SS")
    dtX = collect(startTime:Dates.Minute(1):DateTime(startTime+Dates.Day(1)-Dates.Minute(1)));

    # Plot axis setting
    majorformatter = matplotlib[:dates][:DateFormatter]("%H")#("%H:%M")#("%d.%m.%Y")
    minorformatter = matplotlib[:dates][:DateFormatter]("%H")
    majorlocator = matplotlib[:dates][:HourLocator](byhour=(6,12,18,0))#(interval=1)
    minorlocator = matplotlib[:dates][:HourLocator](byhour=(2,4,8,10,14,16,20,22))

    # Plot activity data
    fig = figure("Activity",figsize=(15,5))
    ax1 = PyPlot.axes()
    p1 = plot_date(dtX,myActData, fmt=",-") # fmt=",-" equivalent to marker="None", linestyle="-"
    ylabel("Activity Counts")
    xlabel("Time")
    title(myTitle)
    axis("tight")
    ax1[:xaxis][:set_major_formatter](majorformatter)
    ax1[:xaxis][:set_minor_formatter](minorformatter)
    ax1[:xaxis][:set_major_locator](majorlocator)
    ax1[:xaxis][:set_minor_locator](minorlocator)
    grid(true)
    #fig[:autofmt_xdate](bottom=0.1,rotation=30,ha="right")
    fig[:canvas][:draw]()
    PyPlot.tight_layout()

end

################################################################################
function dualPlotAct(myActData1::Array{Float64,2}, myActData2::Array{Float64,2}, myTitle = "Average Activity over 24 hours")
# dualPlotAct(myActData1::Array{Float64,2}, myActData2::Array{Float64,2}, myTitle::String)
#
# Synopsis:
# dualPlotAct plots the Activity array over 24 hours with two plots on the same
# axes with different left and right scales.
#
# Input:
# - myActData1       Array{Float64, 2}      Contains data
# - myActData2       Array{Float64, 2}      Contains data
# - myTitle          String                 Contains the title of the figure
#
# Output:
# -figure plot
#
# Example:
#
#-------------------------------------------------------------------------------

    # Create abscissa x-axis
    startTime = DateTime("2018-04-27T00:00:00", "yyyy-mm-ddTHH:MM:SS")
    dtX = collect(startTime:Dates.Minute(1):DateTime(startTime+Dates.Day(1)-Dates.Minute(1)));

    # Plot axis setting
    majorformatter = matplotlib[:dates][:DateFormatter]("%H")#("%H:%M")#("%d.%m.%Y")
    minorformatter = matplotlib[:dates][:DateFormatter]("%H")
    majorlocator = matplotlib[:dates][:HourLocator](byhour=(6,12,18,0))#(interval=1)
    minorlocator = matplotlib[:dates][:HourLocator](byhour=(2,4,8,10,14,16,20,22))

    # Plot activity data

    ##########
    #  Plot  #
    ##########
    fig = figure("Activity",figsize=(15,5))
    p = plot_date(dtX,myActData1, fmt = "b", linestyle="-",marker="None", label="First") # Plot a basic line
    ax = gca()
    #title("Multi-axis Plot")

    xlabel("X Axis")
    font1 = Dict("color"=>"blue")
    ylabel("Activity Count",fontdict=font1)
    setp(ax[:get_yticklabels](),color="blue") # Y Axis font formatting
    ax[:xaxis][:set_major_formatter](majorformatter)
    ax[:xaxis][:set_minor_formatter](minorformatter)
    ax[:xaxis][:set_major_locator](majorlocator)
    ax[:xaxis][:set_minor_locator](minorlocator)

    ################
    #  Other Axes  #
    ################
    new_position = [0.06;0.06;0.77;0.91] # Position Method 2
    ax[:set_position](new_position) # Position Method 2: Change the size and position of the axis
    #fig[:subplots_adjust](right=1.0) # Position Method 1

    ax2 = ax[:twinx]() # Create another axis on top of the current axis
    font2 = Dict("color"=>"red")
    ylabel("Energy Expenditure",fontdict=font2)
    p = plot_date(dtX,myActData2, fmt = "r", linestyle="-",marker="None",label="Second") # Plot a basic line
    ax2[:set_position](new_position) # Position Method 2
    setp(ax2[:get_yticklabels](),color="red") # Y Axis font formatting

    ax2[:xaxis][:set_major_formatter](majorformatter)
    ax2[:xaxis][:set_minor_formatter](minorformatter)
    ax2[:xaxis][:set_major_locator](majorlocator)
    ax2[:xaxis][:set_minor_locator](minorlocator)

    title(myTitle)
    axis("tight")


    fig[:autofmt_xdate](bottom=0.1,rotation=30,ha="right")
    fig[:canvas][:draw]()
    PyPlot.tight_layout()

end


################################################################################
function plotFullAct(myActData::Array{Float64,2}, myTitle = "Average Activity over 24 hours")
# plotAct(myActData::Array{Float64,1}, myTitle::String)
#
# Synopsis:
# plotFullAct plots the Activity array over 24 hours.
#
# Input:
# - myDir               String              Contains directory location
# - myFiles          Array{String, 1}       Contains files data names
#
# Output:
# -
#
# Example:
#
#-------------------------------------------------------------------------------

    # Create abscissa x-axis
    startTime = DateTime("2018-04-27T00:00:00", "yyyy-mm-ddTHH:MM:SS")
    dtX = collect(startTime:Dates.Minute(1):DateTime(startTime+Dates.Day(1)-Dates.Minute(1)));

    # Plot axis setting
    majorformatter = matplotlib[:dates][:DateFormatter]("%H")#("%H:%M")#("%d.%m.%Y")
    minorformatter = matplotlib[:dates][:DateFormatter]("%H")
    majorlocator = matplotlib[:dates][:HourLocator](byhour=(6,12,18,0))#(interval=1)
    minorlocator = matplotlib[:dates][:HourLocator](byhour=(2,4,8,10,14,16,20,22))

    # Plot activity data
    #fig = figure("Average Activity",figsize=(15,5))
    ax1 = axes()
    for i in 1:size(myActData, 2)
        p1 = plot_date(dtX,myActData[:,i], color= "silver", linestyle="-",marker="None")
    end

    avgActVisit = mean(myActData, 2);
    p1 = plot_date(dtX, avgActVisit, color= "black", linestyle="-",marker="None")


    ylabel("Activity Counts")
    xlabel("Time")
    title(myTitle)
    axis("tight")
    ax1[:xaxis][:set_major_formatter](majorformatter)
    ax1[:xaxis][:set_minor_formatter](minorformatter)
    ax1[:xaxis][:set_major_locator](majorlocator)
    ax1[:xaxis][:set_minor_locator](minorlocator)
    grid(true, linestyle="--")
    #fig[:autofmt_xdate](bottom=0.1,rotation=30,ha="right")
    #fig[:canvas][:draw]()
    PyPlot.tight_layout()

end

################################################################################
function plotTriAct(myActData1::Array{Float64,2}, myActData2::Array{Float64,2}, myActData3::Array{Float64,2}, myTitle = "Average Activity over 24 hours")
# plotAct(myActData::Array{Float64,1}, myTitle::String)
#
# Synopsis:
# plotFullAct plots the Activity array over 24 hours.
#
# Input:
# - myDir               String              Contains directory location
# - myFiles          Array{String, 1}       Contains files data names
#
# Output:
# -
#
# Example:
#
#-------------------------------------------------------------------------------

    # Create abscissa x-axis
    startTime = DateTime("2018-04-27T00:00:00", "yyyy-mm-ddTHH:MM:SS")
    dtX = collect(startTime:Dates.Minute(1):DateTime(startTime+Dates.Day(1)-Dates.Minute(1)));

    # Plot axis setting
    majorformatter = matplotlib[:dates][:DateFormatter]("%H")#("%H:%M")#("%d.%m.%Y")
    minorformatter = matplotlib[:dates][:DateFormatter]("%H")
    majorlocator = matplotlib[:dates][:HourLocator](byhour=(6,12,18,0))#(interval=1)
    minorlocator = matplotlib[:dates][:HourLocator](byhour=(2,4,8,10,14,16,20,22))

    # Plot activity data
    #fig = figure("Average Activity",figsize=(15,5))
    ax1 = PyPlot.axes()

    p1 = plot_date(dtX, myActData1, fmt= "b", linestyle="-", marker="None")
    p1 = plot_date(dtX, myActData2, fmt= "r", linestyle="-", marker="None")
    p1 = plot_date(dtX, myActData3, fmt= "g", linestyle="-", marker="None")

    ylabel("Activity Counts")
    xlabel("Time")
    title(myTitle)
    axis("tight")
    ax1[:xaxis][:set_major_formatter](majorformatter)
    ax1[:xaxis][:set_minor_formatter](minorformatter)
    ax1[:xaxis][:set_major_locator](majorlocator)
    ax1[:xaxis][:set_minor_locator](minorlocator)
    grid(true, linestyle="--")
    #fig[:autofmt_xdate](bottom=0.1,rotation=30,ha="right")
    #fig[:canvas][:draw]()
    PyPlot.tight_layout()

end


################################################################################
function plotCircAct(myActData::Array{Float64,2}, myTitle = "Average Activity over 24 hours")
# plotCircAct(myActData::Array{Float64,1}, myTitle::String)
#
# Synopsis:
# plotCircAct plots the Activity array over 24 hours circularly.
#
# Input:
# - myDir               String              Contains directory location
# - myFiles          Array{String, 1}       Contains files data names
#
# Output:
# -
#
# Example:
#
#-------------------------------------------------------------------------------
    #################
    #  Create Data  #
    #################
    theta = [0:2pi/1439:2pi;]

    ##########################
    ##  Windrose Line Plot  ##
    ##########################
    fig = figure("pyplot_windrose_lineplot",figsize=(7,7)) # Create a new figure
    ax = PyPlot.axes(polar="true") # Create a polar axis
    title(myTitle)
    p = plot(theta,myActData,linestyle="-",marker="None") # Basic line plot

    dtheta = 15 # 360*60/1440
    ax[:set_thetagrids]([0:dtheta:360-dtheta;]) # Show grid lines from 0 to 360 in increments of dtheta
    ax[:set_theta_zero_location]("N") # Set 0 degrees to the top of the plot
    ax[:set_theta_direction](-1) # Switch to clockwise
    fig[:canvas][:draw]() # Update the figure


end

################################################################################
function smoothPlotAct(myActData::Array{Float64,1}, nMin::Int, myTitle = "Average Activity over 24 hours")
# smoothPlotAct(myActData::Array{Float64,1}, myTitle::String)
#
# Synopsis:
# smoothPlotAct plots smoothly the Activity array over 24 hours.
#
# Input:
# - myDir               String              Contains directory location
# - myFiles          Array{String, 1}       Contains files data names
#
# Output:
# -
#
# Example:
#
#-------------------------------------------------------------------------------

    # Check if 1440/nMin equals to a natural number
    if mod(1440, nMin)!=0
        println("Change the cluster number of minutes.
        Division of 1440 by your number is not a positive natural number.")
    else
        # Reshape the data vector into a matrix of size nMin x 1440/nMin
        myActData = reshape(myActData, nMin, Int(1440/nMin));
        myActData = sum(myActData, dims = 1)';# Add up rows to get the new data per nMin minutes

        # Create abscissa x-axis
        startTime = DateTime("2018-04-27T00:00:00", "yyyy-mm-ddTHH:MM:SS")
        dtX = collect(startTime:Dates.Minute(nMin):DateTime(startTime+Dates.Day(1)-Dates.Minute(1)));

        # Plot axis setting
        majorformatter = matplotlib[:dates][:DateFormatter]("%H")#("%H:%M")#("%d.%m.%Y")
        minorformatter = matplotlib[:dates][:DateFormatter]("%H")
        majorlocator = matplotlib[:dates][:HourLocator](byhour=(6,12,18,0))#(interval=1)
        minorlocator = matplotlib[:dates][:HourLocator](byhour=(2,4,8,10,14,16,20,22))

        # Plot activity data
        fig = figure("Activity",figsize=(15,5))
        ax1 = PyPlot.axes()
        p1 = plot_date(dtX,myActData, fmt= ",-")
        ylabel("Activity Counts")
        xlabel("Time")
        title(myTitle)
        axis("tight")
        ax1[:xaxis][:set_major_formatter](majorformatter)
        ax1[:xaxis][:set_minor_formatter](minorformatter)
        ax1[:xaxis][:set_major_locator](majorlocator)
        ax1[:xaxis][:set_minor_locator](minorlocator)
        grid(true, linestyle="--")
        #fig[:autofmt_xdate](bottom=0.1,rotation=30,ha="right")
        fig[:canvas][:draw]()
        PyPlot.tight_layout()

    end
end


end # Module ActPlotData

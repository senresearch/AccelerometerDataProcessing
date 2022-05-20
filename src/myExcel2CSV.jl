"""
myExcel2CSV
===========

Synopsis
--------
*myExcel2CSV* allows to read excel files and convert them into
csv file.

Exported Functions
------------------
* ``checkFile2Convert``: Check if there is any new data excels file to convert
                         into csv file. And it uses the function ``xlsx2csv`` to
                         make the conversion.
* ``xlsx2csv``: Create two csv files from one excel file. The first file ending
                by _hdr contains header file information. The second file
                contains activity data. Each file can be read as data frames.

See also
--------
ExcelReaders.jl Taro.jl DataFrames.jl CSV

References
----------
https://github.com/davidanthoff/ExcelReaders.jl
http://aviks.github.io/Taro.jl/#usage
https://juliadata.github.io/CSV.jl/stable/
"""
module myExcel2CSV

import XLSX
using DataFrames, Dates, DelimitedFiles
import CSV

export checkFile2Convert, xlsx2csv, mytest



################################################################################
function checkFile2Convert(dataDirNameIn::String, dataDirNameOut::String)
# checkFile2Convert
#
# Synopsis:
# checkFile2Convert check if there are any new excels files to convert into csv
# files from the dataDirNameIn directory to the directory dataDirNameOut.It checks
# a control file called DataLogInfo.txt, inside dataDirNameOut, that list the
# converted files from the drirectory dataDirNameIn. After converting any files
# it updates DataLogInfo.txt.
#
# Input:
# - dataDirNameIn     String     It contains directory location where excels
#                                files are to be converted.
#
# - dataDirNameOut    String     It contains directory location where new csv
#                                files are are to be saved.
# Output:
# -No return
#
# Example:
# myExcel2CSV.checkFile2Convert(string(myDataDirIn, myDir[i],"/"),
# string(myDataDirOut,myDir[i],"/"))
#-------------------------------------------------------------------------------
           # Get the name of the files inside the input directory
           myFiles = readdir(dataDirNameIn)

           # Check out new file from  log file
           logFileName = string(dataDirNameOut, "DataLogInfo.txt")
           myLastFiles = Array{String,1}();

           # Read the list of names of the files in current folder last checked
           try
                      f = open(logFileName,"r")
                       readline(f);
                       myLastFiles = readdlm(f,',');
                      close(f)
           catch
                      println("There is no log file in the current directory.");
                      f = open(logFileName,"w")
                       write(f,"# List of files name last time checked \n");
                      close(f)
                      println("DataLogInfo.txt has been created in current directory.");
                      println(dataDirNameOut);
           end

           # Get the name of the new files if any
           myNewFiles = convert(Array{String,1}, setdiff(myFiles, myLastFiles))

           if !isempty(myNewFiles)
                      # New files to be converted
                      for i in 1:length(myNewFiles)
                                 xlsx2csv(myNewFiles[i], dataDirNameIn, dataDirNameOut)

			println(string("File converted: ", myNewFiles[i]))
			f = open(logFileName,"a")
			 write(f,myNewFiles[i],"\n");
			close(f)
                      end
                      # Write the new list of file names

           end
end

################################################################################
function xlsx2csv(dataFileName::String, dataDirIn::String, dataDirOut::String)
# xlsx2csv
#
# Synopsis:
# xlsx2csv reads the excel file dataFileName from the directory dataDirIn, where
# it extracts the header information from the xlsx file before to save it in a csv
# file extension. Then it reads the excel file again to extract the activity data
# before to save it in a csv file too, in the directory dataDirOut. The new csv
# data file keeps the orignal name of the original excel file.
#
# Input:
# - dataFileName      String     Name of the excel file.
# - dataDirNameIn     String     Contains directory location where excels
#                                files are to be converted.
#
# - dataDirNameOut    String     Contains directory location where new csv
#                                files are are to be saved.
# Output:
# -No return
#
# Example:
# xlsx2csv(myFiles[i], dataDirNameIn, dataDirNameOut)
#-------------------------------------------------------------------------------
	# Test for missing column
	println("Conversion xlsx to csv of the file "*dataFileName);
	dfTest = dfData = DataFrame(XLSX.readdata(realpath(dataDirIn*dataFileName),
	                           "Sheet1", "A23:I23"))
	if dfTest[1,7]=="Steps"
	          missCol = false
	else
	          missCol = true
	end

	# Create a header file and create metadata
	csvFileName = string(dataDirOut, dataFileName[1:end-5],"_hdr", ".csv")
	f = open(csvFileName,"w")
	write(f,"# Subject and analysis setting extracted, from "*dataFileName*", on "*string(now())*"\n")
	write(f," Setting, Value, Unit\n")
	close(f)

	# Load the excel file into dataframe
	# The setting information are stored in cells [A2:C11] and [A14:C20]
	df1 = DataFrame(XLSX.readdata(realpath(dataDirIn*dataFileName),"Sheet1","A2:C11"))
	rename!(df1, [:Setting, :Value, :Unit])

	df2 = DataFrame(XLSX.readdata(realpath(dataDirIn*dataFileName),"Sheet1","A14:C20"))
	rename!(df2, [:Setting, :Value, :Unit])

	# Combine the two dataframes df1 and df2
	dfSetting = [df1; df2]


	# Write the header file containing setting information
	CSV.write(csvFileName, dfSetting; header = false, append = true)

	# Create the data file and create metadata
	csvFileName = string(dataDirOut, dataFileName[1:end-5], ".csv")
	if !missCol # No missing column
	          f = open(csvFileName, "w")
	           write(f,"# Data extracted, from "*dataFileName*", on "*
	                      string(now())*"\n")
	           write(f,"Day, ElapsedSeconds, DateTime, ActivityCounts, Steps, EnergyExpenditure, ActivityIntensity\n")
	          close(f)

	          # Read Data from the xlsx file
	          xf = XLSX.readxlsx(realpath(dataDirIn*dataFileName))
	          sh = xf["Sheet1"] # get a reference to a Worksheet
	          endOfSh = string(XLSX.get_dimension(sh))[5:end]
	          dfData = DataFrame(XLSX.readdata(realpath(dataDirIn*dataFileName), "Sheet1", "B31:I"*endOfSh))
	          rename!(dfData, [ :Day, :ElapsedSeconds, :Date, :Time, :ActivityCounts, :Steps,
	                           :EnergyExpenditure, :ActivityIntensity])

	else # Step clolumn is missing
	          f = open(csvFileName,"w")
	           write(f,"# Data extracted, from "*dataFileName*", on "*
	                      string(now())*"\n")
	           write(f,"Day, ElapsedSeconds, DateTime, ActivityCounts, EnergyExpenditure, ActivityIntensity, Steps\n")
	          close(f)

	          # Read Data from the xlsx file
	          xf = XLSX.readxlsx(realpath(dataDirIn*dataFileName))
	          sh = xf["Sheet1"] # get a reference to a Worksheet
	          endOfSh = string(XLSX.get_dimension(sh))[5:end]
	          dfData = DataFrame(XLSX.readdata(realpath(dataDirIn*dataFileName), "Sheet1", "B31:H"*endOfSh))
	          rename!(dfData, [ :Day, :ElapsedSeconds, :Date, :Time, :ActivityCounts,
	                           :EnergyExpenditure, :ActivityIntensity])

	          # Add a step coloumn in data frame filled with NA
	          numRows = nrow(dfData);
	          dfData[!, :Steps] = Array{Missing}(missing, numRows)

	          missFileName = string(dataDirOut, "MissingDataLog.txt")
	          f = open(missFileName,"a")
	           write(f,dataFileName,"\n");
	          close(f)

	end

	# Merge Date and Time columns
	dfData[!, :Time] = filt1899(dfData[:, :Time]); # First filter the time column
	dfData[!, :Date] .= string.(dfData[:, :Date]).*"T".*string.(dfData[:, :Time]); # Join Date and Time
	dfData[!, :Date] = DateTime.(dfData[:, :Date]); # Convert to DateTime type
	rename!(dfData, Dict(:Date => :DateTime)); # Rename the merged column
	select!(dfData, Not(:Time)); # Delete unecessary column

	#= Check for NaN values
	  	Try to convert each column except :DateTime to check if any NaN
		Catch means that the column contains some missing value as
		"NaN", therefore add file name to NaNDataLog.txt=#
	try
		convert.(Int64, dfData[:, [ :Day, :ElapsedSeconds, :ActivityCounts,
	                                :ActivityIntensity]]);
		convert.(Float64, dfData[:, :EnergyExpenditure]);
	catch
		println("There is NaN error file in the current directory.");
	    nanFileName = string(dataDirOut, "NaNDataLog.txt")
	    f = open(nanFileName,"a")
	    write(f,dataFileName,"\n");
	    close(f)
		println("NaNDataLog.txt has been updated in current directory.");
		println(dataDirOut);
	end

	# Write the header file containing setting information
	CSV.write(csvFileName, dfData; header = false, append = true)


	# To read the activity data use the following command
	# better to use read table and to convert datatime back to datatime
	# type, since readtable will read it as a string.
	# dfCSV = CSV.read(csvFileName; datarow =3 ,
	#           header = ["Day", "ElapsedSeconds", "Date", "Time", "ActivityCounts",
	#            "Steps", "EnergyExpenditure", "ActivityIntensity"], nullable = false,
	#            rows=6,
	#           types=Dict(3=>DateTime ))

	#Dates.Time(now())
end


################################################################################
function filt1899(colTime::Array{Any,1})
# filt1899
#
# Synopsis:
# filt1899 is used along with XLSX results which load the date 1899-12-30 instead
# of 00:00:00. It checks if there are any Date type elements in a Time type vector.
# Then, if dates exists in the vector they are converted to 00:00:00.
#
# Input:
# - colTime           Array{Any,1}     Time vector
#
# Output:
# -colTime            Array{Any,1}     Filtered Time vector
#
# Example:
# xlsx2csv(myFiles[i], dataDirNameIn, dataDirNameOut)
#-------------------------------------------------------------------------------
        idx = LinearIndices(colTime)[findall(typeof.(colTime) .== Date)]
        colTime[idx] .= Dates.Time("00:00:00")
        return colTime
end


"""
input(prompt::String="")::String

Read a string from STDIN. The trailing newline is stripped.

The prompt string, if given, is printed to standard output without a
trailing newline before reading input.
"""
function myInput(prompt::String="")::String
           print(prompt)
           return chomp(readline())
end

# sciptXLSX2CSV reads excel files, load data into a dataframe, and it can save the
# data in .csv extension file.
end

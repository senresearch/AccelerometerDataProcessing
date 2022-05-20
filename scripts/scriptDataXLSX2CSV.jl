# scriptDataXLSX2CSV read excel file and convert them into a csv file.
#
# Synopsis:
# () = scriptDataXLSX2CSV()
#
# Input:
# -
# Output:
# -
# Description:
#
# sciptDataXLSX2CSV reads excel files, load data into a dataframe, and it save the
# data in .csv extension file.
#
# Example:
#
# See also
# myExcel2CSV.jl ExcelReaders.jl Taro.jl DataFrames.jl CSV
#
# Author: Gregory Farage - Biostatistics Division, Prev. Medecine Department
# Created in 2018
#
# References:
# https://github.com/davidanthoff/ExcelReaders.jl
# http://aviks.github.io/Taro.jl/#usage
# https://juliadata.github.io/CSV.jl/stable/

include(realpath("../src/myExcel2CSV.jl"));
using .myExcel2CSV

function runMyCode()

# Get the directory

myDataDirIn = realpath((@__DIR__)*"/../../dataRaw/Accelerometer/")*"/"
println(myDataDirIn)
myDataDirOut = realpath((@__DIR__)*"/../../data/")*"/"
println(myDataDirOut)

# Get the name of the folders containing xlsx data
myDir = readdir(myDataDirIn)
display(myDir)
for i in 1:length(myDir)
           if isdir(myDataDirIn*myDir[i])&isdir(myDataDirOut*myDir[i])
                      # call function to check new files
                      myExcel2CSV.checkFile2Convert(string(myDataDirIn,
                      myDir[i],"/"),string(myDataDirOut,myDir[i],"/"));
           end

end
end

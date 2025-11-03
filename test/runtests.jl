#using Pkg
#pkg"activate ."
# Insert the path to your PSID_DATA_DIR here. It should contain all the data files.
# export PSID_DATA_DIR=/home/andrew/Documents/julia/PSIDTool/testdata
@assert haskey(ENV, "PSID_DATA_DIR")
cd(ENV["PSID_DATA_DIR"])
using PSID
@time makePSID("user_input.json")

using CSV, DataFrames, DataFramesMeta

using Test 
using Missings

@testset "Data looks ok" begin
alldata = CSV.read("output/allinds.csv", DataFrame, copycols = true)
@test length(unique(alldata.age_spouse)) < 120
@test minimum(alldata.age_spouse |> skipmissing) >= 0
@test maximum(alldata.age_spouse|> skipmissing) <= 120

@test length(unique(alldata.age_ind)) < 120
@test minimum(alldata.age_ind |> skipmissing) >= 0
@test maximum(alldata.age_ind|> skipmissing) <= 120

@test nrow(alldata) >= 472609
@test ncol(alldata) == 43

nrows_byind = [nrow(sdf) for sdf in groupby(alldata, "id_ind")]

@test minimum(nrows_byind) == 1
@test maximum(nrows_byind) >= 42 
@test maximum(nrows_byind) <= maximum(alldata.year) - minimum(alldata.year)

@test minimum(alldata.year) == 1968
@test maximum(alldata.year) == 2023

## fix income since it changed in 1993
inds = (alldata.year .<= 1993) .& (alldata.ishead .== true)
alldata.labor_inc_spouse[inds] .= alldata.labor_inc_pre_spouse[inds]
inds = (alldata.year .<= 1993) .& (alldata.ishead .== false)
alldata.labor_inc_ind[inds] .= alldata.labor_inc_pre_ind[inds]

## keep only SRC sample
alldata = @subset(alldata, :famid_1968 .< 3000) # Keep only SRC sample


## assume missing income is 0
re(x, val) = Missings.replace(x, val) |> collect # Replace missing with value
alldata.labor_inc_ind = re(alldata.labor_inc_ind, 0.)
alldata.hours_ind = re(alldata.hours_ind, 0.)
##
using Statistics
inc_byind = [mean(sdf.labor_inc_ind) for sdf in groupby(alldata, "id_ind")]

hours_byind = [mean(sdf.hours_ind) for sdf in groupby(alldata, "id_ind")]

wages_byind = [mean(sdf.labor_inc_ind ./ sdf.hours_ind) for sdf in groupby(alldata, "id_ind")]

@test 10 <= median((w for w in wages_byind if w > 0)) <= 15

@test 15_000 <= median((w for w in inc_byind if w > 0)) <= 25_000

## issue #53 
## what to do with data that's in data and psid.xlsx, but not in the codebook 
## ex V13500
## suggest just leave label blank
## Not string
@test eltype(alldata.spouserace1_family) == Union{Missing, Float64}
@test "V13500" in alldata.spouserace1_family_code_fam
end
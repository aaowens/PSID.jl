#using Pkg
#pkg"activate ."
using PSID
makePSID("user_input.json")

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
@test ncol(alldata) == 41

nrows_byind = [nrow(sdf) for sdf in groupby(alldata, "id_ind")]

@test minimum(nrows_byind) == 1
@test maximum(nrows_byind) >= 41 
@test maximum(nrows_byind) <= maximum(alldata.year) - minimum(alldata.year)

@test minimum(alldata.year) == 1968
@test maximum(alldata.year) == 2021

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
end
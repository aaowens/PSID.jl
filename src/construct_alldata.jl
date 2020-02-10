inrange(x, l, u) = l <= x <= u
inrange(x::Missing, l, u) = false
function famid(A)
    # A is length 1 or 2 (depending on having spouse)
    # This needs to be symmetric. Order of A can't matter
    if length(A) == 1
        return A[1]
    elseif length(A) == 2
        return 1_000_000*minimum(A) + maximum(A)
    else
        #error("$A")
        return missing
    end
end

function construct_alldata(famdatas, inddata; codemissings = true)
    ## Combine the VarInfo5 array with the data
    readme = JSON3.read(read("output/user_output.json", String), Vector{VarInfo5})
    #readme = procvar
    readme_ind = JSON3.read(read("output/ind_output.json", String), Vector{VarInfo5})

    years = [collect(1968:1997); collect(1999:2:2017)]
    newdatas_ind = [DataFrame() for x in famdatas]
    # Go year by year
    for y_nx in eachindex(years)
        year = years[y_nx]
        df = newdatas_ind[y_nx]
        data = inddata
        #df[!, :id_ind] = 1:nrow(inddata)
        df[!, :id_ind] = Int.(1000data.ER30001 .+ data.ER30002)
        df[!, :famid_1968] = Int.(data.ER30001)
        df[!, :year] .= year
        for vari in readme_ind
            ## Check if vari is in the data this year
            if !haskey(vari.yeardict, year)
                continue
            end
            ss = vari.yeardict[year][1]
            sym = Symbol(ss)
            dat1 = data[!, sym]
            # Apply missing value codes
            sm = vari.yeardict[year][3]
            finalname = Symbol("$(vari.name_user)_$(vari.unit)")
            if codemissings
                dat2 = [x in sm ? missing : x for x in dat1 ]
            else
                dat2 = [x for x in dat1]
            end
            if vari.iscontinuous == false
                labs = Dict(parse(Int, k) => v for (k, v) in vari.labeldict)
                strlabel = [ismissing(x) ? missing : labs[x] for x in dat2]
                finalname_label = Symbol("$(vari.name_user)_$(vari.unit)_label")
                df[!, finalname_label] = strlabel
            end
            df[!, finalname] = dat2
        end
    end

    newdatas2 = (headdata = [DataFrame() for x in famdatas], spousedata = [DataFrame() for x in famdatas])
    ## Heads, spouses
    for ishead in (false, true)
        # Go year by year
        for y_nx in eachindex(years)
            year = years[y_nx]
            df = ishead ? newdatas2.headdata[y_nx] : newdatas2.spousedata[y_nx]
            data = famdatas[year]
            for vari in readme
                ## Check if vari is in the data this year
                if !haskey(vari.yeardict, year)
                    continue
                end
                ss = vari.yeardict[year][1]
                sym = Symbol(ss)
                if vari.unit == "family"
                    finalname = Symbol("$(vari.name_user)_family")
                elseif vari.unit == "head" && ishead
                    finalname = Symbol("$(vari.name_user)_ind")
                elseif vari.unit == "spouse" && ishead
                    finalname = Symbol("$(vari.name_user)_spouse")
                elseif vari.unit == "head" && !ishead
                    finalname = Symbol("$(vari.name_user)_spouse")
                elseif vari.unit == "spouse" && !ishead
                    finalname = Symbol("$(vari.name_user)_ind")
                else
                    error("???")
                end
                if hasproperty(data, sym)
                    dat1 = data[!, sym]
                    # Apply missing value codes
                    sm = vari.yeardict[year][3]
                    if codemissings
                        dat2 = [x in sm ? missing : x for x in dat1 ]
                    else
                        dat2 = [x for x in dat1]
                    end
                    # if categorical
                    newdat = dat2
                    if vari.iscontinuous == false
                        labs = Dict(parse(Int, k) => v for (k, v) in vari.labeldict)
                        strlabel = [ismissing(x) ? missing : labs[x] for x in dat2]
                        finalname_label = Symbol("$(finalname)_label")
                        df[!, finalname_label] = strlabel
                    end
                else
                    newdat = [missing for i in 1:nrow(data)]
                    println("Warning: $sym, $finalname in $year was supposed to be in the data but isn't there")
                end
                df[!, finalname] = newdat
            end
            df[!, :year] .= year
            df[!, :ishead] .= ishead
        end
    end

    allinds = DataFrame()
    for y_nx in eachindex(years)
        di = newdatas_ind[y_nx]
        if y_nx > 1 # Sequence number not in 1968
            di = @where(di, inrange.(:seq_num_ind, 1, 20))
        end
        dj_heads = @where(di,  in.(:rel_head_ind, (1, 10) |> Set |> Ref))
        dj_spouses = @where(di,  in.(:rel_head_ind, (2, 20, 22) |> Set |> Ref))
        djall = vcat(dj_heads, dj_spouses)
        famids = by(djall, [:id_family, :year], (:id_ind,) => x -> (famid = famid(x.id_ind),))
        # join the heads with the head family file
        hi = join(dj_heads, newdatas2.headdata[y_nx], on = [:id_family, :year])
        si = join(dj_spouses, newdatas2.spousedata[y_nx], on = [:id_family, :year])
        hi = join(hi, famids, on = [:id_family, :year])
        si = join(si, famids, on = [:id_family, :year])
        allinds = vcat(allinds, hi, cols = :union)
        allinds = vcat(allinds, si, cols = :union)
    end
    CSV.write("output/allinds.csv", allinds)
    println("Finished constructing individual data, saved to output/allinds.csv")
end

"""
    makePSID(userinput_json; codemissings = true)

Constructs the PSID panel of individuals using the variables in the input JSON.

Arguments: `userinput_json` - A string naming the input JSON file

Keyword arguments: `codemissings` - A bool indicating whether values detected as missing according to the codebook
 will be converted to `missing`. Defaults to true.
"""
function makePSID(userinput_json; codemissings = true)
    isfile(userinput_json) || error("$userinput_json not found in current directory")
    x = dirname(pathof(PSID))
    fx = "$x/allfiles_hash.json"
    @assert isfile(fx)
    PSID.verifyfiles(fx)
    isdir("output") || mkdir("output")
    isdir("datafiles") || mkdir("datafiles")
    println("Making codebook")
    PSID.process_codebook()
    println("Processing input JSON")
    PSID.process_input(userinput_json)
    println("Reading data files")
    famdatas, inddata = PSID.unzip_data()
    println("Constructing data")
    PSID.construct_alldata(famdatas, inddata, codemissings = codemissings)
end

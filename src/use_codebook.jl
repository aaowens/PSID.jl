function year2year(s)
    rtest = r"(19|20)\d{2}"
    replace(s, rtest => "YEAR")
end
function checkerror(x, y)
    x, y = year2year(x), year2year(y)
    if x == y
        return x
    elseif x ⊆ y
        return y
    elseif y ⊆ x
        return x
    else # give up
        return "$x PSIDOR $y"
    end
end

dropY(s) = parse(Int, match(r"(19|20)\d{2}", s).match)

function checkmissing(s)
    for r in (r"NA", r"DK", r"Inap.", r"Wild code", r"Missing")
        occursin(r, s) && return true
    end
    return false
end

function iscontinuous(k)
    for key in k
        out = tryparse(Float64, key)
        if out === nothing
            return true
        end
    end
    return false
end

# Need a vector of missing value codes for each year
dropcomma(s) = String([c for c in s if !(c == ',')])
function parse2(s, v)
    out = tryparse(Float64, dropcomma(s))
    # if this isn't a Float, maybe it was a range "-89.0 - -0.4"
    # TODO fix this
    if out === nothing
        #@show s v
        return missing
    else
        return out
    end
end
narrow(A) = [a for a in A]


function process_varname(name, d, df_vars, d2, fastfind)
    ## Find the row in the crosswalk we can find this variable in
    myrow = d[name]
    ## Fetch all the names in that row
    dfvar = df_vars[myrow, :]
    mynames = [ r for r in dfvar if r !== missing]
    ## Need to figure out the variable label expansion
    # Can I just take the union?
    codevec = [fastfind[s] for s in values(mynames)]
    codedict = [d2.codedict[i] for i in codevec]
    un = Dict{String, String}()
    merge!(checkerror, un, codedict...)
    map!(trimlabel, values(un))
    varnames = SortedDict{Int, Tuple{String, String, Vector{Float64}}}(
    parse(Int, d2.YEAR[i]) => (d2.NAME[i], d2.LABEL[i], d2.excluding[i]) for i in codevec)
    varnames, iscontinuous(keys(un)), un
end

function trimlabel(s)
    sp = strip.(split(s, "PSIDOR"))
    # find common substrings
    # For each string in s, check if it occurs in another string in s
    # If so, drop it from s
    # If not, push it to the new string list

    # For each index in s
    # Check if s[i] is in s \ excluded
    # If so, add this index to the excluded list
    clean(x) = lowercase(dropcomma(x))
    setsp = Set(sp)
    #cleaned = Set(clean.(sp))
    excluded = Int[]
    for i in eachindex(sp)
        targind = setdiff(1:length(sp), union(i, excluded))
        cleaned = clean.(sp[targind])
        any(clean(sp[i]) ⊆ c for c in cleaned) && push!(excluded, i)
    end
    newsp = sp[setdiff(1:length(sp), excluded)]
    if length(newsp) == 1
        return newsp[1]
    else
        return reduce((x, y) -> "$x OR $y", newsp[2:end], init = newsp[1])
    end
end

function process_input(inputjson)
    @assert last(splitext(inputjson)) == ".json"
    j2 = jsontable(read("output/codebook.json", String));
    d2 = DataFrame(j2);
    d2.codedict = [Dict(string(x) => y for (x, y) in dt) for dt in d2.codedict]
    df = DataFrame(XLSX.readtable("psid.xlsx", "MATRIX")...)
    df = mapcols(x -> [xx for xx in x], df)
    ## Need a map from VAR to the right row
    df_vars = df[!, r"^Y.+"]
    d = Dict{String, Int}()
    for col in eachcol(df_vars)
        x = Dict(col[i] => i for i in 1:length(col) if col[i] !== missing)
        merge!(checkerror, d, x)
    end
    ## Need to figure out the variable label expansion
    fastfind = Dict(d2.NAME[i] => i for i in 1:length(d2.NAME))
    d2.excluding = [[parse2(k, v) for (k, v) in d if checkmissing(v)] |> skipmissing |> narrow for d in d2.codedict]
    ### Key block
    read_input = JSON3.read(read(inputjson, String), Vector{VarInput})
    process_varinput(v::VarInput) = VarInfo5(v.name_user, v.unit, process_varname(v.varID, d, df_vars, d2, fastfind)...)
    procvar = process_varinput.(read_input)
    write("output/user_output.json", JSON3.write(procvar))

    modpath = dirname(pathof(PSID))
    indpath = "$modpath/ind_input.json"

    read_input = JSON3.read(read(indpath, String), Vector{VarInput})
    procvar = process_varinput.(read_input)
    write("output/ind_output.json", JSON3.write(procvar))
end

#Transforms a string like \"This time in 1996\" to \"This time in YEAR\"
function year2year(s)
    rtest = r"(19|20)\d{2}"
    replace(s, rtest => "YEAR")
end
#If x or y are supersets of each other, keep the superset. Otherwise OR them
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

#Check if this label describes a missing value code
function checkmissing(s)
    for r in (r"NA", r"DK", r"Inap.", r"Wild code", r"Missing")
        occursin(r, s) && return true
    end
    return false
end

#Check if this is a continuous variable
function iscontinuous(k)
    for key in k
        out = tryparse(Float64, key)
        if out === nothing
            return true
        end
    end
    return false
end

dropcomma(s) = String([c for c in s if !(c == ',')])

#Try to parse this value as a float
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
narrowtypes(A) = [a for a in A]

"""
Inputs:
name: The variable ID we want to match
var2ind_dict: The crosswalk table
df_vars: The data
codebook_df: The codebook table
fastfind: Dict mapping from variable IDs to their index in the codebook
Processes a variable ID, finds all years thats match, and collects the labels
"""
function process_varname(name, var2ind_dict, df_vars, codebook_df, fastfind)
    ## Find the row in the crosswalk we can find this variable in
    myrow = var2ind_dict[name]
    ## Fetch all the names in that row
    dfvar = df_vars[myrow, :]
    mynames = [ r for r in dfvar if r !== missing]
    ## Need to figure out the variable label expansion
    # Can I just take the union?
    codevec = [fastfind[s] for s in values(mynames)]
    codedict = [codebook_df.codedict[i] for i in codevec]
    un = Dict{String, String}()
    merge!(checkerror, un, codedict...)
    map!(trimlabel, values(un))
    varnames = Dict{String, Tuple{String, String, Vector{Float64}}}(
    codebook_df.YEAR[i] => (codebook_df.NAME[i], codebook_df.LABEL[i],
     codebook_df.excluding[i]) for i in codevec)
    varnames, iscontinuous(keys(un)), un
end



"""
Sometimes the labels uses a comma in one year and a semicolon in another,
but are otherwise identical.
This function parses the different labels and drops these duplicates.
It also keeps only labels which are unique after cleaning, and constructs
a label which is a union of the parts (A OR B OR C)
"""
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
    # We want to find the unique (after cleaning) labels
    # Iterate through the set and check if we have seen this label before
    # If not, add it to the seen list
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
"""
Processes input JSON file
Reads the crosswalk and codebook table from disk and
harmonizes the labels. Constructs the output JSON
"""
function process_input(inputjson)
    @assert last(splitext(inputjson)) == ".json"
    codebook_json = jsontable(read("output/codebook.json", String));
    codebook_df = DataFrame(codebook_json);
    codebook_df.codedict = [Dict(string(x) => y for (x, y) in dt) for dt in codebook_df.codedict]
    #@infiltrate
    crosswalk_df = DataFrame(XLSX.readtable("psid.xlsx", "MATRIX"))
    crosswalk_df = mapcols(narrowtypes, crosswalk_df)
    ## Need a map from VAR to the right row
    df_vars = crosswalk_df[!, r"^Y.+"]
    var2ind_dict = Dict{String, Int}()
    ##
    for col in eachcol(df_vars)
        x = Dict(col[i] => i for i in 1:length(col) if col[i] !== missing)
        merge!(checkerror, var2ind_dict, x)
    end
    ## Need to figure out the variable label expansion
    fastfind = Dict(codebook_df.NAME[i] => i for i in 1:length(codebook_df.NAME))
    # Check if this label denotes a missing value code. If so, this value is an excluding value
    codebook_df.excluding = [[parse2(k, v) for (k, v) in d if checkmissing(v)] |> skipmissing |> narrowtypes for d in codebook_df.codedict]

    ### Do the final processing of the input JSON, produce the output
    read_input = JSON3.read(read(inputjson, String), Vector{VarInput})
    process_varinput(v::VarInput) = VarInfo5(v.name_user, v.unit, process_varname(v.varID, var2ind_dict, df_vars, codebook_df, fastfind)...)
    procvar = process_varinput.(read_input)
    write("output/user_output.json", JSON3.write(procvar))

    modpath = dirname(pathof(PSID))
    indpath = "$modpath/ind_input.json"

    read_input = JSON3.read(read(indpath, String), Vector{VarInput})
    procvar = process_varinput.(read_input)
    write("output/ind_output.json", JSON3.write(procvar))
end

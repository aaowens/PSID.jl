function parsestring(s)
    s = replace(s, "long" => "") # In the 2017 do file they declared some variables as long
    tokens = String[]
    n = 0
    i = 1
    while i <= lastindex(s)
        if s[i] == ' '
            i = i + 1
        else
            nx = findnext("  ", s, i)
            if nx === nothing
                push!(tokens, s[i:end])
                break
            else
                push!(tokens, s[i:(first(nx) - 1) ])
                i = first(nx)
            end
        end
    end
    tokens
end

function process_tok(tok)
    alltokens = String[]
    ready = false
    for i = 1:length(tok)
        w = tok[i]
        if "infix" ⊆ w
            ready = true
            continue
        end
        "using" ⊆ w && break
        ready && append!(alltokens, parsestring(w))
    end
    alltokens
end

function str2range(s)
    myr = r"\d+"
    d = eachmatch(myr, s)
    c = collect(d)
    parse(Int, first(c).match):parse(Int, last(c).match)
end

function read_fixedwidth(data, toks)
    names = String[tok[1] for tok in toks]
    dat = zeros(length(data), length(toks))
    for i in eachindex(data)
        line = data[i]
        for j in eachindex(toks)
            tok = toks[j]
            r = tok[2]
            dat[i, j] = Parsers.parse(Float64, line[r])
        end
    end
    DataFrame(dat, Symbol.(names))
end


function readPSID(zipname)
    zipp = "$zipname.zip"
    ZIPNAME = uppercase(zipname)
    #t = mktempdir()
    t = "datafiles/$zipname"
    #run(`unzip $zipname -d $t`)
    isdir(t) || run(DataDeps.unpack_cmd("$zipp", "$t", ".zip", ""))
    tok = readlines("$t/$ZIPNAME.do")
    alltokens = process_tok(tok)
    toks = [(alltokens[i], str2range(alltokens[i+1])) for i in 1:2:length(alltokens)]
    data = readlines("$t/$ZIPNAME.txt")
    Base.GC.gc() # memory was going too high
    out = read_fixedwidth(data, toks)
end

function unzip_data()
    years = [collect(1968:1997); collect(1999:2:2019)]
    filenames = [year <= 1993 ? "fam$year" : "fam$(year)er" for year in years]
    datas =  SortedDict(year => readPSID(filename) for (year, filename) in zip(years, filenames))
    inddata = readPSID("ind2019er")
    (famdatas = datas, inddata = inddata)
end

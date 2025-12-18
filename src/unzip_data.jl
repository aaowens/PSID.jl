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

const PARSER_OPTS = Parsers.OPTIONS

function read_fixedwidth(data, toks)
    names = String[tok[1] for tok in toks]
    dat = zeros(length(data), length(toks))
    for i in eachindex(data)
        line = data[i]
        for j in eachindex(toks)
            tok = toks[j]
            r = tok[2]
            dat[i, j] = Parsers.parse(Float64, line, PARSER_OPTS, first(r), last(r))
        end
    end
    DataFrame(dat, Symbol.(names))
end

## ChatGPT's fast parser
const POW10_TABLE = Float64[10.0^i for i in 0:308]
const INV_POW10_TABLE = Float64[1.0 / POW10_TABLE[i] for i in 1:length(POW10_TABLE)]

@inline fastpow10(e::Int) = e >= 0 ?
    (e <= 308 ? @inbounds(POW10_TABLE[e + 1]) : 10.0^e) :
    (e >= -308 ? @inbounds(INV_POW10_TABLE[-e + 1]) : 10.0^e)

@inline function fast_parse_float64(line::Base.CodeUnits{UInt8, String}, s::Int, e::Int)
    i = s
    @inbounds while i <= e && line[i] == 0x20 # skip leading spaces
        i += 1
    end

    neg = false
    if i <= e
        b = @inbounds line[i]
        if b == 0x2d # '-'
            neg = true
            i += 1
        elseif b == 0x2b # '+'
            i += 1
        end
    end

    intpart = 0.0
    @inbounds while i <= e
        b = line[i]
        if b == 0x2e # '.'
            i += 1
            break
        end
        (b >= 0x30 && b <= 0x39) || break
        intpart = muladd(intpart, 10.0, b - 0x30)
        i += 1
    end

    fracpart = 0.0
    ndfrac = 0
    @inbounds while i <= e
        b = line[i]
        if b == 0x65 || b == 0x45 # 'e' or 'E'
            i += 1
            break
        end
        (b >= 0x30 && b <= 0x39) || break
        fracpart = muladd(fracpart, 10.0, b - 0x30)
        ndfrac += 1
        i += 1
    end

    expadj = 0
    if i <= e && (line[i - 1] == 0x65 || line[i - 1] == 0x45)
        expsign = 1
        if i <= e
            b = line[i]
            if b == 0x2d
                expsign = -1
                i += 1
            elseif b == 0x2b
                i += 1
            end
        end
        @inbounds while i <= e
            b = line[i]
            (b >= 0x30 && b <= 0x39) || break
            expadj = expadj * 10 + (b - 0x30)
            i += 1
        end
        expadj *= expsign
    end

    val = intpart
    if ndfrac != 0
        val = muladd(fracpart, @inbounds(INV_POW10_TABLE[ndfrac + 1]), val)
    end
    if expadj != 0
        val *= fastpow10(expadj)
    end
    return neg ? -val : val
end

function read_fixedwidth_fast(data, toks)
    nrows = length(data)
    ncols = length(toks)

    names = Vector{Symbol}(undef, ncols)
    starts = Vector{Int}(undef, ncols)
    stops = Vector{Int}(undef, ncols)
    @inbounds for j in 1:ncols
        tok = toks[j]
        names[j] = Symbol(tok[1])
        r = tok[2]
        starts[j] = first(r)
        stops[j] = last(r)
    end

    bufs = Vector{Base.CodeUnits{UInt8, String}}(undef, nrows)
    @inbounds for i in 1:nrows
        bufs[i] = codeunits(data[i])
    end

    dat = Matrix{Float64}(undef, nrows, ncols)
    @threads for i in 1:nrows
        line = bufs[i]
        @inbounds @simd for j in 1:ncols
            dat[i, j] = fast_parse_float64(line, starts[j], stops[j])
        end
    end

    DataFrame(dat, names)
end


function readPSID(zipname; fastparse = true)
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
    if fastparse
        out = read_fixedwidth_fast(data, toks)
    else
        out = read_fixedwidth(data, toks)
    end
end

function unzip_data(;fastparse = true)
    years = [collect(1968:1997); collect(1999:2:2023)]
    filenames = [year <= 1993 ? "fam$year" : "fam$(year)er" for year in years]
    datas =  SortedDict(year => readPSID(filename, fastparse = fastparse) for (year, filename) in zip(years, filenames))
    inddata = readPSID("ind2023er", fastparse = fastparse)
    (famdatas = datas, inddata = inddata)
end

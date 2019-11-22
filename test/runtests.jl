using Test
using PSID, DataDeps, JSON3


@show pwd()
x = dirname(pathof(PSID))
fx = "$x/allfiles_hash.json"
skipdata = try
    PSID.verifyfiles(fx)
    println("Found all files, running full tests")
    false
catch
    println("Did not find data files, running partial tests")
    true
end

if skipdata
    Base.download("https://raw.githubusercontent.com/aaowens/PSID.jl/master/examples/user_input.json", "user_input.json")
    Base.download("https://drive.google.com/uc?authuser=0&id=1nz1UaVGcj0ur2Bp3ev7a8agJbj0A5JTF&export=download", "J265684_codebook.zip")
    run(DataDeps.unpack_cmd("J265684_codebook.zip", "$(pwd())", ".zip", ""))
    Base.download("https://psidonline.isr.umich.edu/help/xyr/psid.xlsx", "psid.xlsx")
    userinput_json = "user_input.json"
    isfile(userinput_json) || error("$userinput_json not found in current directory")
    isdir("output") || mkdir("output")
    isdir("datafiles") || mkdir("datafiles")
    PSID.process_codebook()
    PSID.process_input("user_input.json")
    JSON3.read(read("output/user_output.json", String), Vector{PSID.VarInfo5})
    #famdatas, inddata = PSID.unzip_data()
    #PSID.construct_alldata(famdatas, inddata)
else
    makePSID("user_input.json")
end

using Test
using PSID
@show pwd()
#=
x = dirname(pathof(PSID))
fx = "$x/allfiles_hash.json"
@show isfile(fx)
PSID.verifyfiles(fx)
PSID.process_codebook()
PSID.process_input("user_input.json")
famdatas, inddata = PSID.unzip_data()
PSID.construct_alldata(famdatas, inddata)
=#
makePSID("user_input.json")

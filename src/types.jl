mutable struct VarInfo5
    name_user::String
    unit::String
    yeardict::Dict{String, Tuple{String, String, Vector{Float64}}}
    iscontinuous::Bool
    labeldict::Dict{String, String}
    VarInfo5() = new()
    VarInfo5(x...) = new(x...)
end
JSON3.StructType(::Type{VarInfo5}) = JSON3.Mutable()


mutable struct VarInput
    name_user::String
    varID::String
    unit::String #family, head, or spouse
    VarInput() = new()
    VarInput(x...) = new(x...)
end
JSON3.StructType(::Type{VarInput}) = JSON3.Mutable()

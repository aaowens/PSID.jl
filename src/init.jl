function checkhash(filename)
    filename |> read |> sha256 |> bytes2hex
end
function verifyfiles(allfilesjson)
    allfiles_dict = JSON3.read(read(allfilesjson, String), SortedDict{String, String})
    for (f, v) in allfiles_dict
        isfile(f) || error("$f not found and is required.")
        fh = checkhash(f)
        if fh == v
            println("Found file $f, hash OK")
        else
            @warn "Hash for file $f is $fh, expected $v"
        end
    end
end

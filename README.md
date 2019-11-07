# PSID.jl
To add this package, use
```
(v1.2) pkg> add https://github.com/aaowens/PSID.jl
```

This package produces a labeled panel of individuals with a consistent individual ID across time. You provide a JSON file describing the variables you want. An example input file can be found at [examples/user_input.json.](https://github.com/aaowens/PSID.jl/blob/master/examples/user_input.json). Currently only variables in the family files can be added, but in the future it should be possible to support variables in the individual files or the supplements.

Requirements: A list of data files required to be in the current directory can be found [here](https://github.com/aaowens/PSID.jl/blob/master/src/allfiles_hash.json). These files are

1. The PSID codebook in XML format. TODO: Explain how users can download this by themselves. 
2. The PSID family files and cross-year individual file, which can be downloaded here https://simba.isr.umich.edu/Zips/ZipMain.aspx.
3. The XLSX cross-year index for the variables, which can be downloaded here https://psidonline.isr.umich.edu/help/xyr/psid.xlsx.

After acquiring the data, run 
```
julia> using PSID
julia> makePSID("user_input.json") 
# for the raw data, makePSID("user_input.json", codemissings = false, makelabels = false)
```
It will verify the required files exist and then construct the data. If successful, it will print `Finished constructing individual data, saved to output/allinds.csv` after about 5 minutes.

This package provides the following features:
1. Automatically labels missing values by searching the value labels from the codebook for strings like "NA", "Inap.", or "Missing".
2. Tries to produce consistent value labels across years for categotical variables. This is difficult because the labels in the PSID sometimes change between years. This package uses an algorithm to try to harmonize the labels when possible by removing common subsets. For example, in one year race is labeled as "Asian" but in the next year it is "Asian, Pacific Islander". The first is a subset of the second, so the final label will be "Asian, Pacific Islander". When this is not possible, the final label will be "A or B or C" for however many incomparable labels were found.
3. Matches the individuals across time to produce a panel with consistent (ID, year) keys and their associated variables.
4. Produces consistent individual or spouse variables for individuals. In the input JSON file, you must indicate whether a variable is family level, household head level, or household spouse level. The final output will have variables of the form VAR_family, VAR_ind, or VAR_spouse. When the individual is a household head, VAR_ind will come from the household head version of that variable, and VAR_spouse will come from the household spouse version. If the individual is a household spouse, it is the reverse.
5. It's easiest to track individuals, but this package also produces a consistent family ID by treating a family as a combination of head and spouse (if spouse exists). If you keep only household heads and drop years before 1970, (famid, year) should be an ID.

This package is new and not well tested, please file issues if you find a bug. 

# PSID.jl

[![Build Status](https://travis-ci.com/aaowens/PSID.jl.svg?branch=master)](https://travis-ci.com/aaowens/PSID.jl)
[![codecov](https://codecov.io/gh/aaowens/PSID.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/aaowens/PSID.jl)

The Panel Study of Income Dynamics (PSID) is a longitudinal public dataset which has been following a collection of families and their descendants since 1968. It provides a breadth of information about labor supply and life-cycle dynamics. More information is available at https://psidonline.isr.umich.edu/.

This package produces a labeled panel of individuals with a consistent individual ID across time. You provide a JSON file describing the variables you want. An example input file can be found at [examples/user_input.json.](https://github.com/aaowens/PSID.jl/blob/master/examples/user_input.json). Currently only variables in the family files can be added, but in the future it should be possible to support variables in the individual files or the supplements.

An example workflow can be found on my blog post [here](https://aaowens.github.io/julia/2020/02/11/Using-the-Panel-Study-of-Income-Dynamics.html)

# Instructions

To add this package, use
```
(@v1.4) pkg> add https://github.com/aaowens/PSID.jl
```

Next, download the PSID data files yourself. The package can't automatically fetch them because the PSID requires you to register for a free account before using the data.

The list of data files required to be in the current directory can be found [here](https://github.com/aaowens/PSID.jl/blob/master/src/allfiles_hash.json). These files are

1. The PSID codebook in XML format. You can download this from me here https://drive.google.com/open?id=1nz1UaVGcj0ur2Bp3ev7a8agJbj0A5JTF . In the future there will be a way to download this from the PSID directly.
2. The zipped PSID family files and cross-year individual file, which can be downloaded here https://simba.isr.umich.edu/Zips/ZipMain.aspx. Do not extract the files--leave them zipped. You need to download every family file from 1968 to 2017, and you also need to download the cross-year individual file.
3. The XLSX cross-year index for the variables, which can be downloaded here https://psidonline.isr.umich.edu/help/xyr/psid.xlsx.

After acquiring the data, run
```
julia> using PSID
julia> makePSID("user_input.json")
# to not code missings, makePSID("user_input.json", codemissings = false)
```
It will verify the required files exist and then construct the data. If successful, it will print `Finished constructing individual data, saved to output/allinds.csv` after about 5 minutes.

## The input JSON file
The file passed to `makePSID` describes the variables you want.
```
{
    "name_user": "hours",
    "varID": "V465",
    "unit": "head"
  },
  ```
  There are three fields, `name_user`, `varID`, and `unit`. `name_user` is a name chosen by you. `varID` is one of the codes assigned by the PSID to this variable. These can be looked up in the PSID [cross-year index](https://simba.isr.umich.edu/VS/i.aspx). For example, hours above can be found in the crosswalk at `	Family Public Data Index 01>WORK 02>Hours and Weeks 03>annual in prior year 04>head 05>total:`. Clicking on the variable info will show the the list of years and associated IDs when that variable is available. Choose any of the IDs for `varID`, it does not matter. `PSID.jl` will look up all available years for that variable in the crosswalk. You must also indicate the unit, which can be `head`, `spouse`, or `family`. This makes sure the variable is assigned to the correct individual.


# Features

This package provides the following features:
1. Automatically labels missing values by searching the value labels from the codebook for strings like "NA", "Inap.", or "Missing".
2. Tries to produce consistent value labels across years for categorical variables. This is difficult because the labels in the PSID sometimes change between years. This package uses an algorithm to try to harmonize the labels when possible by removing common subsets. For example, in one year race is labeled as "Asian" but in the next year it is "Asian, Pacific Islander". The first is a subset of the second, so the final label will be "Asian, Pacific Islander". When this is not possible, the final label will be "A or B or C" for however many incomparable labels were found.
3. Matches the individuals across time to produce a panel with consistent (ID, year) keys and their associated variables.
4. Produces consistent individual or spouse variables for individuals. In the input JSON file, you must indicate whether a variable is family level, household head level, or household spouse level. The final output will have variables of the form `VAR_family`, `VAR_ind`, or `VAR_spouse`. When the individual is a household head, `VAR_ind` will come from the household head version of that variable, and `VAR_spouse` will come from the household spouse version. If the individual is a household spouse, it is the reverse. Both individuals will get all family level variables.
5. It's easiest to track individuals, but this package also produces a consistent family ID by treating a family as a combination of head and spouse (if spouse exists). If you keep only household heads and drop years before 1970, (famid, year) should be an ID.

# Notable Omissions

Certain variables are not in the family files. For example, the wealth data are in separate files, and there is some unique information in the individual file directly. In the future I plan to add support for these data, but you can manually add them by constructing the unique individual ID yourself as (ER30001 * 1000) + ER30002, and then joining your data on that ID with the dataset produced by PSID.jl. 

Please file issues if you find a bug.

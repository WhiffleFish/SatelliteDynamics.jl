###############
# Remote Data #
###############

DATA_DIR = abspath(joinpath(abspath(string(@__DIR__)), "../data"))

function download_file(url, file)
    filepath = abspath(joinpath(DATA_DIR, file))
    tempfilepath = filepath * ".tmp"

    @debug("Downloading datafile. URL: $url DESTINATION: $filepath")
    
    # Remove any temp files
    rm(tempfilepath, force=true)

    # Attempt to download data
    download(url, tempfilepath)

    # Move temporary file into permanent location
    rm(filepath, force=true)
    mv(tempfilepath, filepath)

    @debug("Downloaded all datafiles.")
end

export download_kp
"""
Download geomagnetic indices.

Notes:
1. Data source is Celestract: https://celestrak.com/SpaceData/sw19571001.txt
"""
function download_kp()
    download_file("https://celestrak.com/SpaceData/sw19571001.txt", "sw19571001.txt")
end

export download_solar_flux
"""
Download F10.7cm Solar Flux data.

10.7cm solar flux is the standard measure of solar activity in space weather models.

Notes:
1. Data source is NRC Canada solar flux tables: ftp://ftp.seismo.nrcan.gc.ca/spaceweather/solar_flux/daily_flux_values/fluxtable.txt
"""
function download_solar_flux()
    @suppress download_file("ftp://ftp.seismo.nrcan.gc.ca/spaceweather/solar_flux/daily_flux_values/fluxtable.txt", "fluxtable.txt")
end

export download_all_data
"""
Downloads package datafiles into folders `\$PACKAGE_ROOT/DIR`

Downloads the following files:
- IERS C04 IAU2000A Earth Orientation Data
- IERS C04 IAU1980 Earth Orientation Data
- IERS Bulletin A/B IAU2000 Earth Orientation Data
"""
function download_all_data()
    # Earth Orientation Data
    for (product_name, product_data) in eop_products
        (url, dest) = product_data
        download_file(url, basename(dest))
    end

    # Geomagnetic inidies
    download_kp()

    # Solar Flux
    download_solar_flux()
end

##########################
# Earth Orientation Data #
##########################

# Define product dictionary
eop_products = Dict(
    "C04_20" => ("https://datacenter.iers.org/data/latestVersion/EOP_20_C04_one_file_1962-now.txt", abspath(string(@__DIR__), "../data/EOP_20_C04_one_file_1962-now.txt")),
    "FINALS_2000" => ("https://datacenter.iers.org/data/latestVersion/finals.all.iau2000.txt", abspath(string(@__DIR__), "../data/finals.all.iau2000.txt"))
)

export EarthOrientationData
"""
The EarthOrientationData constains a single data member of type 
`Dict{Int, Tuple{Float64, Float64, Float64}}` that stores the Earth
Orientation parameters `UT1-UTC`, `xp`, and `yp` whose units are _meters_, 
_radians_, and _radians_, respectively. `xp` and `yp` are the x- and 
y-components of Earth's polar motion. The dictionary key is the Epoch the 
parameters are for as a Modified Julian Day at 0h UTC.

Arguments:
- `product::Symbol` The IERS product type can be `"C04_20"` or `"FINALS_2000"`
"""
struct EarthOrientationData
    data::Dict{Int, Tuple{Float64, Float64, Float64}}
end


function EarthOrientationData(product::String) 
    # Initialize Data Array
    eop_data = Dict{Int, Tuple{Float64, Float64, Float64}}()

    # Load in Data from filepath
    if product == "FINALS_2000"
        for line in readlines(eop_products[product][2])
            if line[17] == 'P' || line[17] == 'I'
                mjd_utc = parse(Int, line[8:12])            # MJD (UTC)
                ut1_utc = parse(Float64, line[59:68])         # UT1-UTC [s]
                xp      = parse(Float64, line[19:27])*AS2RAD  # xp [rad]
                yp      = parse(Float64, line[38:46])*AS2RAD  # yp [rad]

                eop_data[mjd_utc] = (ut1_utc, xp, yp)
            end
        end
    elseif product == "C04_20" || product == "C04_14"
        open(eop_products[product][2], "r") do product_file
            for i in 1:14
                # Read first 14 lines to skip to data
                readline(product_file)
            end

            for line in readlines(product_file)
                split_line = split(line)
                mjd_utc = parse(Int, split_line[4])
                ut1_utc = parse(Float64, split_line[7])
                xp      = parse(Float64, split_line[5])*AS2RAD
                yp      = parse(Float64, split_line[6])*AS2RAD

                eop_data[mjd_utc] = (ut1_utc, xp, yp)
            end
        end
    else
        error("Unknown symbol $(String(:product))")
    end

    return EarthOrientationData(eop_data)
end

# Declare global Earth Orientation Data Object used by Reference System Calls
export EOP
"""
Module-wide global EarthOrientationData object. This data object is used as the
default source of Earth Orientation Data by reference system transformations if
no explicit EarthOrientationData file is provided to those transformations.

This value can be overridden in your own code as follows:

```julia
SatelliteDynamics.EOP = EarthOrientationData(:EOP_PRODUCT_CHOICE)
```

This global variable defaults to use the module's internal version of `"FINALS_2000"` 
if it is not otherwise set/provided.
"""
global EOP = EarthOrientationData("FINALS_2000")

# Access Methods
export UT1_UTC
"""
Compute the offset between the UT1 and UTC time systems in seconds. If the EarthOrientationData argument is ommitted the function will use the default module-global value.

Arguments:
- `eop::EarthOrientationData` EarthOrientationData object to use to compute the offset
- `mjd::Real` Modified Julian Date in UTC of the Epoch for which the UT1-UTC offset is desired.
- `interp::Bool` Whether to linearly interpolate the parameter data to the input MJD.

Returns:
- `ut1_utc::Float` UT1 - UTC offset. [s] 
"""
function UT1_UTC(eop::EarthOrientationData, mjd::Real; interp::Bool=false)
    if interp
        x1 = floor(mjd)
        x2 = floor(mjd) + 1
        y1 = eop.data[convert(Int, floor(mjd))][1]
        y2 = eop.data[convert(Int, floor(mjd)+1)][1]
        x  = (y2 - y1)/(x2 - x1) * (mjd - x1) + y1
        return x
    else
        return eop.data[convert(Int, floor(mjd))][1]
    end
end

UT1_UTC(mjd::Real; interp::Bool=false) = UT1_UTC(EOP, mjd, interp=interp)

export POLE_LOCATOR
"""
Compute the location of the pole. Returns x- and y- components as a tuple with the units of [radians].  If the EarthOrientationData argument is ommitted the function will use the default module-global value.

Arguments:
- `eop::EarthOrientationData` EarthOrientationData object to use to compute the offset
- `mjd::Real` Modified Julian Date in UTC of the Epoch for which the pole locator is desired.
- `interp::Bool` Whether to linearly interpolate the parameter data to the input MJD.

Returns:
- `pole_locator::Tuple{ -Float, Float}` (x, y) pole location in radians.
"""
function POLE_LOCATOR(eop::EarthOrientationData, mjd::Real; interp::Bool=false)
    if interp
        x1 = floor(mjd)
        x2 = floor(mjd) + 1

        # Get values converted to array for interpolation
        y1 = [v for v in eop.data[convert(Int, floor(mjd))][2:3]]
        y2 = [v for v in eop.data[convert(Int, floor(mjd)+1)][2:3]]
        x  = (y2 - y1)/(x2 - x1) * (mjd - x1) + y1
        return x
    else
        return eop.data[convert(Int, floor(mjd))][2:3]
    end
end

POLE_LOCATOR(mjd::Real; interp::Bool=false) = POLE_LOCATOR(EOP, mjd, interp=interp)

export XP
"""
Compute the x-component of the pole locator in [radians]. If the first EarthOrientationData argument is ommitted the function will use the default module-global value.

Arguments:
- `eop::EarthOrientationData` EarthOrientationData object to use to compute the offset
- `mjd::Real` Modified Julian Date in UTC of the Epoch for which the xp value is desired.
- `interp::Bool` Whether to linearly interpolate the parameter data to the input MJD.

Returns:
- `xp::Float` x-component of pole locator in radians.
"""
function XP(eop::EarthOrientationData, mjd::Real; interp=false)
    if interp
        x1 = floor(mjd)
        x2 = floor(mjd) + 1
        y1 = eop.data[convert(Int, floor(mjd))][2]
        y2 = eop.data[convert(Int, floor(mjd)+1)][2]
        x  = (y2 - y1)/(x2 - x1) * (mjd - x1) + y1
        return x
    else
        return eop.data[convert(Int, floor(mjd))][2]
    end
end

XP(mjd::Real; interp::Bool=false) = XP(EOP, mjd, interp=interp)

export YP
"""
Compute the y-component of the pole locator in [radians]. If the first EarthOrientationData argument is ommitted the function will use the default module-global value.

Arguments:
- `eop::EarthOrientationData` EarthOrientationData object to use to compute the offset
- `mjd::Real` Modified Julian Date in UTC of the Epoch for which the yp value is desired.
- `interp::Bool` Whether to linearly interpolate the parameter data to the input MJD.

Returns:
- `yp::Float` y-component of pole locator in radians.
"""
function YP(eop::EarthOrientationData, mjd::Real; interp::Bool=false)
    if interp
        x1 = floor(mjd)
        x2 = floor(mjd) + 1
        y1 = eop.data[convert(Int, floor(mjd))][3]
        y2 = eop.data[convert(Int, floor(mjd)+1)][3]
        x  = (y2 - y1)/(x2 - x1) * (mjd - x1) + y1
        return x
    else
        return eop.data[convert(Int, floor(mjd))][3]
    end
end

YP(mjd::Real; interp::Bool=false) = YP(EOP, mjd, interp=interp)

export set_eop
"""
Set Earth orientation data values for a specific date in the module global EarthOrientationData object.

Arguments:
- `mjd::Real` Modified Julian Date in UTC of the Epoch for which the Earth orientation data is aligned to.
- `ut1_utc::Real` Offset between UT1 and UTC in seconds.
- `xp::Real` x-component of the pole locator in radians.
- `yp::Real` y-component of the pole locator in radians.
"""
function set_eop(mjd::Real, ut1_utc::Real, xp::Real, yp::Real)
    EOP.data[convert(Int, floor(mjd))] = (ut1_utc, xp*AS2RAD, yp*AS2RAD)
end

export load_eop
"""
Load new Earth orientation data into the module global EarthOrientationData object. The product can be one of the symbols: `"C04_14"`, `"C04_80"`, or `"FINALS_2000"`.

Arguments:
- `product::String` Loads a different set of EarthOrientationData values into the module-wide global EarthOrientationData parameters.
"""
function load_eop(product::String)
    global EOP = EarthOrientationData(product::String) 
end

#################
# Gravity Model #
#################

grav_products = Dict(
    :EGM2008_20 => abspath(string(@__DIR__), "../data/EGM2008_20.gfc"),
    :EGM2008_90 => abspath(string(@__DIR__), "../data/EGM2008_90.gfc"),
    :GGM01S => abspath(string(@__DIR__), "../data/GGM01S.gfc"),
    :GGM01S => abspath(string(@__DIR__), "../data/GGM05S.gfc"),
)


function line_starts_with(line::String, str::String)
    if length(line) > length(str) && line[1:length(str)] == str
        return true
    else
        return false
    end
end

export GravModel
"""
GravModel stores a spherical harmonic gravity field in memory. Can store normalized or denomalized coefficients. Package contains EGM2008, GGM01S, and GGM0S gravity models, as well as the default gravity model of EGM2008 truncated to degree and order 90.

Additional gravity field models can be downloaded from: <http://icgem.gfz-potsdam.de/home>

Arguments:
- `filepath::string` Path to spherical harmonic gravity model file.
"""
struct GravModel
    name::String
    normalized::Bool
    R::Float64
    GM::Float64
    n_max::Int64
    m_max::Int64
    data::AbstractArray{Float64, 2}
end

function GravModel(filepath::String)
    model_name = ""
    normalized = false
    R          = 0.0
    GM         = 0.0
    n_max      = 0.0
    m_max      = 0.0
    data       = Array{Float64, 2}(undef, 1, 1)

    # Parse File
    for line in readlines(filepath)
        # Replace non-standard float formatting in GFC files
        line = replace(line, "D+" => "e+")
        line = replace(line, "D-" => "e-")

        if line_starts_with(line, "modelname")
            model_name = split(line)[2]
        elseif line_starts_with(line, "max_degree")
            n_max = parse(Int16, split(line)[2])
            m_max = n_max
            data = zeros(Float64, n_max+1, m_max+1)
        elseif line_starts_with(line, "earth_gravity_constant")
            GM = parse(Float64, split(line)[2])
        elseif line_starts_with(line, "radius")
            R = parse(Float64, split(line)[2])
        elseif line_starts_with(line, "norm")
            if split(line)[2] == "fully_normalized"
                normalized = true
            else
                normalized = false
            end
        elseif line_starts_with(line, "gfc")
            line_split = split(line)
            n = parse(Int16, line_split[2])
            m = parse(Int16, line_split[3])
            C = parse(Float64, line_split[4])
            S = parse(Float64, line_split[5])

            data[n+1, m+1] = C
            if m != 0
                data[m+1-1, n+1] = S
            end
        end
    end

    # Pre-Allocate 
    return GravModel(model_name, normalized, R, GM, n_max, m_max, data)
end

function GravModel(product_name::Symbol)
    return GravModel(grav_products[product_name])
end


# Declare glrobal Gravity Model used by dynamics model calls
export GRAVITY_MODEL
"""
Module-wide global GravityModel object. This data object is used as the
default spherical harmonic gravity field unless one is otherwise provided.

This value can be overridden in your own code as follows:

```julia
SatelliteDynamics.GravityModel = GravityModel(PATH_TO_YOUR_GRAVITY_MODEL)
```

This global variable defaults to use the module's internal version of the EGM2008 model truncated to order and degree 90, if it is not otherwise set.
"""
global GRAVITY_MODEL = GravModel(abspath(@__DIR__, "../data/EGM2008_90.gfc"))

export load_gravity_model
"""
Load new gravity model into module global EarthOrientationData object.

Arguments:
- `gfc_file::String` File path of gravity field model
"""
function load_gravity_model_file(gfc_file::String)
    global GRAVITY_MODEL = GravModel(gfc_file::String) 
end

"""
Load new gravity model into module global EarthOrientationData object. The product can be one of the symbols: `:EGM2008_20`, `:EGM2008_90`, `:GGM01S`, `:GGM05S`, or the filepath to a text-encoded gravity model file.

Arguments:
- `product_name::Symbol` Symbol of a known gravity field product. Valid ones are: `:EGM2008_20`, `:EGM2008_90`, `:GGM01S`, `:GGM05S`
"""
function load_gravity_model(product_name::Symbol)
    global GRAVITY_MODEL = GravModel(product_name::Symbol) 
end

export GRAV_COEF
function GRAV_COEF(i::Int, j::Int)
    # Offset into matrix to deal with julia indexing
    return GRAVITY_MODEL.data[i+1, j+1]
end
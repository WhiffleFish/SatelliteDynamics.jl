# Packages required for testing
using Test
using Random
using LinearAlgebra
using Logging
using Printf

# Package under test
using SatelliteDynamics

# Set logging level
global_logger(SimpleLogger(stderr, Logging.Debug))

# Fix randomness during tests
Random.seed!(0)

# Define paths for test data
const TEST_C04_EOP_DATA = abspath(joinpath(@__DIR__, "./data/EOP_20_C04_one_file_1962-now.txt"))
const TEST_FINALS_EOP_DATA = abspath(joinpath(@__DIR__, "./data/FINALS.ALL_IAU2000.txt"))

# Check equality of two arrays
@inline function array_isapprox(x::AbstractArray{F},
                  y::AbstractArray{F};
                  rtol::F=sqrt(eps(F)),
                  atol::F=zero(F)) where {F<:Real}

    # Easy check on matching size
    if length(x) != length(y)
        return false
    end

    for (a,b) in zip(x,y)
        @test isapprox(a,b, rtol=rtol, atol=atol)
    end
end

# Check if array equals a single value
@inline function array_isapprox(x::AbstractArray{F},
                  y::F;
                  rtol::F=sqrt(eps(F)),
                  atol::F=zero(F)) where {F<:Real}

    for a in x
        @test isapprox(a, y, rtol=rtol, atol=atol)
    end
end

@time @testset "SatelliteDynamics Package Tests" begin

    # Load default test Earth Orientation Data
    load_eop(TEST_FINALS_EOP_DATA, :FINALS_2000)

    # testdir = joinpath(dirname(@__DIR__), "test")
    # @time @testset "SatelliteDynamics.Contants" begin
    #     include(joinpath(testdir, "test_constants.jl"))
    # end
    # @time @testset "SatelliteDynamics.Universe" begin
    #     include(joinpath(testdir, "test_universe.jl"))
    # end
    # @time @testset "SatelliteDynamics.Time" begin
    #     include(joinpath(testdir, "test_time.jl"))
    # end
    # @time @testset "SatelliteDynamics.Refsys" begin
    #     include(joinpath(testdir, "test_reference_systems.jl"))
    # end
    # @time @testset "SatelliteDynamics.Attitude" begin
    #     include(joinpath(testdir, "test_attitude.jl"))
    # end
    # @time @testset "SatelliteDynamics.Coordinates" begin
    #     include(joinpath(testdir, "test_coordinates.jl"))
    # end
    # @time @testset "SatelliteDynamics.Astrodynamics" begin
    #     include(joinpath(testdir, "test_astrodynamics.jl"))
    # end
    # @time @testset "SatelliteDynamics.OrbitDynamics" begin
    #     include(joinpath(testdir, "test_orbitdynamics.jl"))
    # end
    # @time @testset "SatelliteDynamics.SGPModels" begin
    #     include(joinpath(testdir, "test_sgp_models.jl"))
    # end

    # Earth Environment
    @time @testset "SatelliteDynamics.NRLMSISE00" begin
        include(joinpath(testdir, "earth_environment/", "test_spaceweather.jl"))
    end
    # @time @testset "SatelliteDynamics.NRLMSISE00" begin
    #     include(joinpath(testdir, "earth_environment/", "test_nrlmsise00.jl"))
    # end

    # # Simulation Tools
    # @time @testset "SatelliteDynamics.Integrators" begin
    #     include(joinpath(testdir, "simulation/", "test_integrators.jl"))
    # end
    # @time @testset "SatelliteDynamics.Propagators" begin
    #     include(joinpath(testdir, "simulation/", "test_propagators.jl"))
    # end
end
# ============================ /test/MOI_wrapper.jl ============================
module TestPenbmi

import Penopt
using MathOptInterface
using Test

const MOI = MathOptInterface

const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(
    Penopt.Optimizer,
    MOI.Silent() => true,
    #"PBM_EPS" => 1e-4,
    #"PRECISION_2" => 1e-4,
)
const OPTIMIZER = MOI.instantiate(OPTIMIZER_CONSTRUCTOR)

const BRIDGED = MOI.instantiate(
    OPTIMIZER_CONSTRUCTOR, with_bridge_type = Float64
)

const CACHED = MOI.Utilities.CachingOptimizer(
    MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
    BRIDGED,
)

const CONFIG = MOI.Test.TestConfig(
    atol = 1e-6,
    rtol = 1e-6,
    duals = false,
    infeas_certificates = false,
    optimal_status = MOI.LOCALLY_SOLVED,
    basis = false,
    query = false,
)

#TestPenbmi.MOI.Test.solve_affine_lessthan(TestPenbmi.CACHED, TestPenbmi.CONFIG)

function test_SolverName()
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "Penbmi"
end

function test_supports_default_copy_to()
    @test MOI.Utilities.supports_default_copy_to(OPTIMIZER, false)
    @test !MOI.Utilities.supports_default_copy_to(OPTIMIZER, true)
end

function test_unittest()
    # Test all the functions included in dictionary `MOI.Test.unittests`,
    # except functions "number_threads" and "solve_qcp_edge_cases."
    MOI.Test.unittest(
        CACHED,
        CONFIG,
        [
            # Attribute not supported
            "number_threads", "time_limit_sec",
            # Does not converge since everything is at zero and it uses a relative tolerance ?
            "solve_duplicate_terms_obj", "solve_time", "solve_constant_obj", "solve_affine_equalto", "raw_status_string",
            # Binary variables not supported
            "solve_integer_edge_cases", "solve_objbound_edge_cases",
            "solve_zero_one_with_bounds_1",
            "solve_zero_one_with_bounds_2",
            "solve_zero_one_with_bounds_3",
            # `ConstraintPrimal` not implemented
            "solve_affine_lessthan", "solve_affine_equalto", "solve_affine_interval", "solve_affine_greaterthan",
            "solve_affine_deletion_edge_cases", "solve_result_index", "solve_blank_obj", "solve_singlevariable_obj",
            "solve_duplicate_terms_scalar_affine", "solve_duplicate_terms_vector_affine",
            "solve_with_upperbound", "solve_with_lowerbound",
            # `ConstraintFunction` not implemented but needed by bridge
            "delete_soc_variables", "update_dimension_nonnegative_variables", "delete_nonnegative_variables",
            # Unbounded
            "solve_unbounded_model",
        ]
    )
end

# TODO
#function test_contlinear()
#    MOI.Test.contlineartest(BRIDGED, CONFIG)
#end

function test_contquadratictest()
    MOI.Test.contquadratictest(CACHED, CONFIG, [
        # Bridge fails since it's nonconvex
        "socp", "ncqcp",
        # `ConstraintPrimal` not implemented
        "qcp", "qp3",
    ])
end

# TODO
#function test_contconic()
#    MOI.Test.contlineartest(BRIDGED, CONFIG)
#end

function test_default_status_test()
    MOI.Test.default_status_test(OPTIMIZER)
end

# This function runs all functions in this module starting with `test_`.
function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$(name)", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
end

end # module TestPenbmi

TestPenbmi.runtests()

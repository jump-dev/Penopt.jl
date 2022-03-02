# ============================ /test/MOI_wrapper.jl ============================
module TestPenbmi

import Penopt
using MathOptInterface
using Test

const MOI = MathOptInterface

const OPTIMIZER_CONSTRUCTOR = MOI.OptimizerWithAttributes(
    Penopt.Optimizer,
    MOI.Silent() => true,
    "PBM_EPS" => 1.0e-4,
    "P0" => 0.01,
)
const OPTIMIZER = MOI.instantiate(OPTIMIZER_CONSTRUCTOR)

const BRIDGED = MOI.instantiate(
    OPTIMIZER_CONSTRUCTOR, with_bridge_type = Float64
)

const CACHED = MOI.Utilities.CachingOptimizer(
    MOI.Utilities.UniversalFallback(MOI.Utilities.Model{Float64}()),
    BRIDGED,
)

const CONFIG = MOI.Test.Config(
    atol = 2e-4,
    rtol = 2e-4,
    duals = false,
    infeas_certificates = false,
    optimal_status = MOI.LOCALLY_SOLVED,
    basis = false,
    query = false,
)

function test_SolverName()
    @test MOI.get(OPTIMIZER, MOI.SolverName()) == "Penbmi"
end

function test_supports_default_copy_to()
    @test MOI.supports_incremental_interface(OPTIMIZER, false)
    @test !MOI.supports_incremental_interface(OPTIMIZER, true)
end

function test_unittest()
    # With `P0 = 1.1` (default)
    # solve_affine_greaterthan needs > 1.6e-1
    # solve_affine_lessthan needs < 2.0e-1
    # With `P0 = 0.01`, it seems to work better:
    MOI.set(CACHED, MOI.RawOptimizerAttribute("PBM_EPS"), 1.0e-2)
    MOI.set(CACHED, MOI.RawOptimizerAttribute("P0"), 1.0e-2)
    # Test all the functions included in dictionary `MOI.Test.unittests`,
    # except functions "number_threads" and "solve_qcp_edge_cases."
    MOI.Test.unittest(
        CACHED,
        CONFIG,
        [
            # Attribute not supported
            "number_threads", "time_limit_sec",
            # TODO Seems to converge to a local infeasible solution
            "solve_start_soc",
            # FIXME Does not converge since everything is at zero and it uses a relative tolerance ?
            "solve_duplicate_terms_obj", "solve_time", "solve_constant_obj", "solve_affine_equalto", "raw_status_string",
            "solve_affine_deletion_edge_cases", "solve_result_index", "solve_singlevariable_obj",
            # Binary variables not supported
            "solve_integer_edge_cases", "solve_objbound_edge_cases",
            "solve_zero_one_with_bounds_1",
            "solve_zero_one_with_bounds_2",
            "solve_zero_one_with_bounds_3",
            # `ConstraintPrimal` not implemented
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
function test_contlinear()
    MOI.set(CACHED, MOI.RawOptimizerAttribute("PBM_EPS"), 1.0e-3)
    MOI.set(CACHED, MOI.RawOptimizerAttribute("P0"), 1.0e-2)
    MOI.Test.contlineartest(CACHED, CONFIG, [
        # Infeasible
        "linear8a", "linear12",
        # Unbounded
        "linear8b", "linear8c",
        # FIXME Does not converge since everything is at zero and it uses a relative tolerance ?
        "linear6", "linear4", "linear7", "linear15",
        # ITERATION_LIMIT
        "linear9",
    ])
end

function test_contquadratictest()
    MOI.Test.contquadratictest(CACHED, CONFIG, [
        # Bridge fails since it's nonconvex
        "socp", "ncqcp",
        # `ConstraintPrimal` not implemented
        "qcp", "qp3",
    ])
end

function test_contconic()
    MOI.set(CACHED, MOI.RawOptimizerAttribute("PBM_EPS"), 1.0e-4)
    MOI.set(CACHED, MOI.RawOptimizerAttribute("P0"), 1.0e-2)
    MOI.Test.contconictest(CACHED, CONFIG, [
        # Infeasible
        "norminf2", "normone2", "lin3", "lin4", "soc3", "rotatedsoc2",
        # Missing bridges
        "rootdets",
        # Does not support power and exponential cone
        "pow", "dualpow", "logdet", "exp", "dualexp", "relentr",
    ])
end

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

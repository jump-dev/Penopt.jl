# Penopt

Penopt.jl is a wrapper for the **[Penopt Optimizer](http://www.penopt.com/)**.

It has two components:
 - a thin wrapper around the complete C API
 - an interface to [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl)

The C API can be accessed via `Penopt.penbmi` functions, where the names and
arguments are identical to the C API. See the `/tests` folder for inspiration.

## Installation

You can install `Penopt.jl` through the
[Julia package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html):
```julia
] add https://github.com/jump-dev/Penopt.jl.git
```
then open a terminal in the directory when Penopt is installed (find this directory by writing `using Penopt; pathof(Penopt)` in a Julia session).
```
$ mkdir -p deps/usr/lib
$ cd deps/usr/lib
$ gcc  -Wl,--no-undefined -shared -lm -lgfortran -lopenblas -llapack -o libpenbmi.so -Wl,--whole-archive /path/to/PENBMI2.1/lib/libpenbmi.a -Wl,--no-whole-archive
```
This will create a shared library `libpenbmi.so` in the directory `deps/usr/lib`.
Then create the following file `deps/deps.jl`:
```julia
import Libdl
const libpenbmi = joinpath(dirname(@__FILE__), "usr/lib/libpenbmi.so")
function check_deps()
    global libpenbmi
    if !isfile(libpenbmi)
        error("$(libpenbmi) does not exist, Please re-run Pkg.build(\"Penopt\"), and restart Julia.")
    end

    if Libdl.dlopen_e(libpenbmi) == C_NULL
        error("$(libpenbmi) cannot be opened, Please re-run Pkg.build(\"Penopt\"), and restart Julia.")
    end

end
```
You can test the installation with `using Pkg; Pkg.test("Penopt")` in a Julia session.

## Use with JuMP

We highly recommend that you use the *Penopt.jl* package with higher level packages such as
[JuMP.jl](https://github.com/jump-dev/JuMP.jl).

This can be done using the ``Gurobi.Optimizer`` object. Here is how to create a
*JuMP* model that uses Gurobi as the solver.
```julia
using JuMP, Gurobi

model = Model(Gurobi.Optimizer)
set_optimizer_attribute(model, "PBM_MAX_ITER", 100)
set_optimizer_attribute(model, "TR_MODE", 1)
```
See the [Penbmi Documentation](http://www.penopt.com/doc/penbmi2_1.pdf)
for a list and description of allowable parameters.

For instance, here is how to solve the example of given in
`PENBMI2.1/c/driver_bmi_c.c` with JuMP.
This is Example 3 of the [Penbmi Documentation](http://www.penopt.com/doc/penbmi2_1.pdf) except that we add `(x[1] - x[2])^2/2` in the objective.

```julia
using LinearAlgebra
using JuMP
import Penopt

model = Model(Penopt.Optimizer)
set_optimizer_attribute(model, "LS", 1)
set_optimizer_attribute(model, "DIMACS", 0)
set_optimizer_attribute(model, "P0", 0.1)
set_optimizer_attribute(model, "PRECISION_2", 1e-6)
@variable(model, x[1:3])
@objective(model, Min, (x[1] - x[2])^2 / 2 + x[3])
@constraint(model, -0.5 <= x[1] <= 2.0)
@constraint(model, -3.0 <= x[2] <= 7.0)
A0 = [-10  -0.5 -2
      -0.5  4.5  0
      -2    0    0]
A1 = [ 9    0.5  0
       0.5  0   -3
       0   -3   -1]
A2 = [-1.8 -0.1 -0.4
      -0.1  1.2 -1
      -0.4 -1    0]
K12 = [0    0    2
       0   -5.5  3
       2    3    0]
@constraint(model, Symmetric(A0 + x[1] * A1 + x[2] * A2 + x[1] * x[2] * K12 - x[3] * Matrix(I, 3, 3)) in PSDCone())
optimize!(model)

println(solution_summary(model))
@show MOI.get(model, Penopt.NumberOfOuterIterations())
@show MOI.get(model, Penopt.NumberOfNewtonSteps())
@show MOI.get(model, Penopt.NumberOfLinesearchSteps())
```

## Accessing Penopt-specific attributes via JuMP

You can get and set Penopt-specific attributes via JuMP as follows:
```julia
@show MOI.get(model, Penopt.NumberOfOuterIterations())
@show MOI.get(model, Penopt.NumberOfNewtonSteps())
@show MOI.get(model, Penopt.NumberOfLinesearchSteps())
```

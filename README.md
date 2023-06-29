# Penopt.jl

**This repository is still under development. It is not a registered
Julia package, and has not been tested on macOS or Windows.**

[Penopt.jl](https://github.com/jump-dev/Penopt.jl) is a wrapper for the
[Penopt Optimizer](http://www.penopt.com/).

It has two components:
 - a thin wrapper around the complete C API
 - an interface to [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl)

The C API can be accessed via `Penopt.penbmi` functions, where the names and
arguments are identical to the C API. See the `/tests` folder for inspiration.

## Affiliation

This wrapper is maintained by the JuMP community and is not officially
supported by Penopt.

## License

`Penopt.jl` is licensed under the [MIT License](https://github.com/jump-dev/Penopt.jl/blob/master/LICENSE.md).

The underlying solver is a closed-source commercial product for which you must
[purchase a license](http://www.penopt.com).

## Installation

You can install `Penopt.jl` through the
[Julia package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html):
```julia
] add https://github.com/jump-dev/Penopt.jl.git
```
then, open a terminal in the directory when Penopt is installed (find this
directory by writing `using Penopt; pathof(Penopt)` in a Julia session).
```raw
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
You can test the installation with `using Pkg; Pkg.test("Penopt")` in a Julia
session.

## Use with JuMP

```julia
using JuMP, Penopt
model = Model(Penopt.Optimizer)
set_attribute(model, "PBM_MAX_ITER", 100)
set_attribute(model, "TR_MODE", 1)
```

## Options

See the [Penbmi Documentation](http://www.penopt.com/doc/penbmi2_1.pdf)
for a list and description of allowable parameters.

## Accessing Penopt-specific attributes via JuMP

You can get and set Penopt-specific attributes via JuMP as follows:
```julia
@show MOI.get(model, Penopt.NumberOfOuterIterations())
@show MOI.get(model, Penopt.NumberOfNewtonSteps())
@show MOI.get(model, Penopt.NumberOfLinesearchSteps())
```

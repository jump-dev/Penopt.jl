# Penopt

**WARNING**: This is a work in progress, don't trust anything written below.

`Penopt.jl` is an interface to the **[Penopt](http://www.penopt.com/)**
solver. It exports the `sedumi` function that is a thin wrapper on top of the
`penbmi` C function and uses it to define the `Penbmi.Optimizer` object
that implements the solver-independent
[MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) API.

To use it with [JuMP](https://github.com/jump-dev/JuMP.jl), simply do
```julia
using JuMP
using Penopt
model = Model(with_optimizer(Penbmi.Optimizer))
```
To suppress output, do
```julia
model = Model(with_optimizer(Penbmi.Optimizer, ???=???))
```

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
```
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

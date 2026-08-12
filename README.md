# Penopt.jl

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

> [!WARNING]
> Only Linux is supported at the moment.
> Help is welcome to add support for [Mac OS](https://github.com/jump-dev/Penopt.jl/pull/14) and [Windows](https://github.com/jump-dev/Penopt.jl/pull/15).

You can install `Penopt.jl` through the
[Julia package manager](https://docs.julialang.org/en/v1/stdlib/Pkg/index.html):
```julia
] add https://github.com/jump-dev/Penopt.jl.git
```

This downloads and builds [PENSDP](https://github.com/kocvara/pensdp), the free
SDP-only solver of the PENOPT family, which is used by `Penopt.pensdp` and by
`Penopt.Optimizer` for problems with a linear objective and linear matrix
inequalities.

### PENBMI

Bilinear matrix inequalities and quadratic objectives require PENBMI, which is a
commercial product for which you must
[purchase a license](http://www.penopt.com). Set the `PENOPT_LIBPENBMI`
environment variable to the path of the PENBMI library and re-run the build:
```julia
ENV["PENOPT_LIBPENBMI"] = "/path/to/PENBMI2.1/lib/libpenbmi.a"

import Pkg
Pkg.build("Penopt")
```
then restart Julia.

PENOPT distributes PENBMI as a static library, which Julia cannot call into
directly. The build detects this and links a shared library from it in
`deps/usr/lib`; a path pointing to a shared library is used as is. To change the
location of the library, update `PENOPT_LIBPENBMI`, re-run
`Pkg.build("Penopt")` and restart Julia.

Whether PENBMI is available is given by `Penopt.has_penbmi()`.

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

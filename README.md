# Penopt

**WARNING**: This is a work in progress, don't trust anything written below.

`Penopt.jl` is an interface to the **[Penopt](http://www.penopt.com/)**
solver. It exports the `sedumi` function that is a thin wrapper on top of the
`penbmi` C function and uses it to define the `Penbmi.Optimizer` object
that implements the solver-independent
[MathOptInterface](https://github.com/JuliaOpt/MathOptInterface.jl) API.

To use it with [JuMP](https://github.com/JuliaOpt/JuMP.jl), simply do
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
] add https://github.com/JuliaOpt/Penopt.jl.git
```
but you first need to make sure that you have Penopt installed and that the
???? environment variable is set to the ??? filder of Penopt.

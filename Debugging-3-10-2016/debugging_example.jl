
# Download debugger
Pkg.add("Gallium")

# Include MyModule.jl
path = string(pwd(), "/MyModule.jl")
include(path)

using Gallium
using MyModule

# Set breakpoint in MyModule line 15
bp = Gallium.breakpoint("MyModule.jl",15)

# Run function from MyModule
f(100)

#
#  `  -> switch from Debugger to Julia REPL
#        println(x)
#        imshow(A[:,:,1]     # For plotting while debugging, include "using PyPlot" in MyModule rather than the main script
#
# del -> switch back to debugger
#

# Delete breakpoint
Gallium.disable(bp)

# Set new breakpoint for f(Float64::x)
bp = Gallium.breakpoint(f, Tuple{Float64})

# Run function 
f(100.)


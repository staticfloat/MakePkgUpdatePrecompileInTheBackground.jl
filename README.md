# MakePkgUpdatePrecompileInTheBackground

[![Build Status](https://travis-ci.org/staticfloat/MakePkgUpdatePrecompileInTheBackground.jl.svg?branch=master)](https://travis-ci.org/staticfloat/MakePkgUpdatePrecompileInTheBackground.jl)

Unnecessarily long titles aside, this package adds a "background task progress reporting" API and provides two functions for testing it out; `start_cycling(name)` which creates a dummy progress bar that cycles endlessly until stopped via `stop_cycling(name)`, and `recompile_everything()` which loops through all installed packages and attempts to precompile them.

To try it out, just `use` this package, then run one of the testing functions above.  Note that you will need to check out [this branch](https://github.com/JuliaLang/julia/tree/sf/replready) of Julia 0.4 to use this package, as it needs a new REPL hook.

Note that still on the TODO list is actually hooking into the `Pkg.update()` process; you have to manually run `recompile_everything()` after running `Pkg.update()` because trying to run `Pkg` operations from within another `Pkg` operation has problems for some reason.

To support this package for eventual world domination, use the `#MakePkg.update()GreatAgain!` hashtag on any social media website that will accept that as a hashtag.

# MakePkgUpdatePrecompileInTheBackground

Unnecessarily long titles aside, this package adds a "background task progress reporting" API and provides a few functions for testing it out; `start_cycling(name)` which creates a dummy progress bar that cycles endlessly until stopped via `stop_cycling(name)`, and `recompile_everything()` which loops through all installed packages and attempts to precompile them.  The star of the show, of course, is the newly overridden `Pkg.update()`.  After `use`'ing this package, running `Pkg.update()` will automatically invoke `recompile_everything()`.

To try it out, just `use` this package, then run one of the testing functions above.  Note that you will need to check out [this branch](https://github.com/JuliaLang/julia/tree/sf/replready) of Julia 0.4 to use this package, as it needs a new REPL hook.  Note that as all "background" tasks are actually implemented using green threads, the REPL will occasionally freeze, especially during `Pkg` operations.

---

To support this package for eventual world domination, use the `#MakePkg.update()GreatAgain!` hashtag on any social media website that will accept that as a hashtag.

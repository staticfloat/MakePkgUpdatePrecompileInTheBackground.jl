function recompile_everything()
    compile_channel = Channel(100)
    max_title_width = 0

    @schedule begin
        # Find all installed packages (except ourselves), and which packages depend on them
        sorted_pkgs = nothing
        cd(Pkg.dir()) do
            global required, available, installed, fixed, dependencies, conflicts, deps
            put!(compile_channel, ("Reading package lists...", 0,))
            required  = Pkg.Reqs.parse("REQUIRE")
            available = Pkg.Read.available()
            installed = Pkg.Read.installed(available)
            fixed = Pkg.Read.fixed(available, installed)

            put!(compile_channel, ("Computing dependencies...", 0))

            dependencies, conflicts = Pkg.Query.dependencies(available, fixed)
            deps = Dict{AbstractString,Vector{AbstractString}}()
            for (name, (version, fixed)) in installed
                if haskey(dependencies, name)
                    deps[name] = collect(keys(dependencies[name][version].requires))
                else
                    deps[name] = []
                end
            end

            function flatten_deps(pkg_deps)
                if isempty(pkg_deps)
                    return pkg_deps
                end
                flat_deps = AbstractString[]
                for dep in pkg_deps
                    push!(flat_deps, dep)
                    for flat_dep in flatten_deps(deps[dep])
                        push!(flat_deps, flat_dep)
                    end
                end
                return unique(flat_deps)
            end

            # Flatten dependency trees
            for (pkg_name, pkg_deps) in deps
                deps[pkg_name] = flatten_deps(pkg_deps)
            end

            # Now sort packages such that dependencies are always in front of their
            # dependents, so that we are always compiling up the tree, never having
            # to compile a dependent package implicitly

            # We get an initial sort by just sorting by the length of dependencies
            sorted_pkgs = sort(collect(keys(deps)), lt=(a,b) -> length(deps[a]) < length(deps[b]))

            # Remove our own package name because we have obviously already been
            # precompiled since we're running!  Also our name is ridiculously long
            sorted_pkgs = filter(x -> x != "MakePkgUpdatePrecompileInTheBackground", sorted_pkgs)

            # Next, swap around every package until it's in behind all of its dependencies
            for idx in 1:length(sorted_pkgs)
                for dep in deps[sorted_pkgs[idx]]
                    # Is this dependency listed _after_ us?  If so, move it closer
                    dep_idx = find(sorted_pkgs .== dep)[1]
                    if dep_idx > idx
                        splice!(sorted_pkgs, dep_idx)
                        insert!(sorted_pkgs, idx, dep)
                    end
                end
            end
        end

        # Calculate maximum title width just so that the printing algorithm can use it
        max_title_width = maximum([strwidth(x) for x in sorted_pkgs])

        # For each package, check to see if it's been cached and if not, cache it
        for idx in 1:length(sorted_pkgs)
            modname = sorted_pkgs[idx]
            put!(compile_channel, ("$(modname).jl...", idx*1.0/length(sorted_pkgs)))
            cache_paths = Base.find_all_in_cache_path(modname)
            if isempty(cache_paths)
                Base.compilecache(modname, true)
            else
                for cachepath in cache_paths
                    try
                        # Essentiallty recreating recompile_stale() from loading.jl
                        # but without all the info()'s as we want to be silent
                        srcpath = Base.find_in_path(modname, nothing)

                        # Can we just auto-delete orphaned cache files here?
                        if srcpath === nothing
                            rm(cachepath)
                            continue
                        end

                        # If it's stale, recompile!
                        if Base.stale_cachefile(srcpath, cachepath)
                            # Simulate compilation.  lol
                            Base.compilecache(modname, true)
                        end
                    end
                end
            end
        end

        put!(compile_channel, ("Done!", 1))
    end

    last_status = "Pkg:"
    report_progress("Pkg") do width
        if isready(compile_channel)
            title, progress = take!(compile_channel)

            if progress == 1
                return nothing
            end

            titlepad = max(max_title_width + 3 - length(title), 0)
            pbar = progress_bar(Float64(progress), width - length(title) - titlepad - 16)
            last_status = @sprintf("Pkg: %s%s [%s] (%.1f%%)", title, " "^titlepad, pbar, 100.0*progress)
        end
        return last_status
    end
    return nothing
end

# This sets up our own REPL backend as well as some frontend hooks
function supplant_repl_backend(;attempt=0)
    if !isdefined(Base, :active_repl_backend)
        if attempt > 0
            if attempt > 15
                warn("Unable to auto-supplant REPL backend; please try manually by calling supplant_repl_backend()")
                return
            end
            @schedule (sleep(0.1); supplant_repl_backend(attempt=attempt + 1))
            return
        else
            error("Base.active_repl_backend not defined!  This happens when running as a script; don't do that!")
        end
    end

    # First, create our own backend
    repl_channel = Channel(1)
    response_channel = Channel(1)
    backend = REPL.REPLBackend(repl_channel, response_channel, false, nothing)
    backend.backend_task = @schedule begin
        global running_mutex
        unlock(running_mutex)
        while true
            tls = task_local_storage()
            tls[:SOURCE_PATH] = nothing
            ast, show_value = take!(backend.repl_channel)
            if show_value == -1
                # exit flag
                break
            end
            # Lock the mutex so stuff can't happen while the REPL is busy, as
            # that would be incredibly messy.  We unlock in on_ready()
            lock(running_mutex)
            REPL.eval_user_input(ast, backend)
        end
    end

    # Now swap it in for the old backend
    old_backend = Base.active_repl_backend
    eval(Base, :(global active_repl_backend; active_repl_backend = $backend))
    eval(Base, :(global active_repl; active_repl.backendref = REPL.REPLBackendRef($repl_channel,$response_channel)))

    # Hook into LineEdit mode `on_enter` and add a CTRL-X keymapping for debugging of cursor position
    for mode in Base.active_repl.interface.modes
        if !isdefined(mode, :on_done)
            continue
        end

        const old_on_done = mode.on_done
        mode.on_done = (state, buffer, ok) -> begin
            global prompt_state, last_enter
            if prompt_state == nothing
                prompt_state = state
            end

            # If there were lines written before, let's blank them!
            if last_draw_lines > 0
                lock(running_mutex)
                # Skip over the input line(s)
                total_lines = prompt_lines(state)
                skip_lines = cursor_position(state)[1] + 1
                write(STDOUT,"$(CSI)$(skip_lines)A$(CSI)1G")
                for idx in 1:(last_draw_lines)
                    write(STDOUT,"$(CSI)1A$(CSI)0K")
                end
                write(STDOUT, "$(CSI)$(last_draw_lines+1)B$(CSI)1G")
                write(STDOUT, "\n"^(total_lines-1))
                unlock(running_mutex)
            end
            last_enter = time()
            old_on_done(state, buffer, ok)
        end

        # Use a hook specially added for this; to know when the prompt is ready
        # for more input and no longer computing the previous result
        const old_on_ready = mode.on_ready
        mode.on_ready = (state) -> begin
            global running_mutex
            unlock(running_mutex)
            return old_on_ready(state)
        end
    end

    # Ask the old backend to die, nicely
    put!(old_backend.repl_channel, (nothing, -1))

    # "We're in".
    print("\rSuccessfully supplanted REPL backend with our own\n")

    return nothing
end

function lock(c::Channel)
    take!(c)
end
function unlock(c::Channel)
    # We don't deal with recurrent locking; we go only one level deep
    if !isready(c)
        put!(c, UInt8(1))
    end
end


btask_status = Dict{AbstractString,Tuple{Float64,Function}}()
function btask_draw()
    global prompt_state, last_enter, last_draw_enter, last_draw_lines, btask_status, running_mutex

    # If we haven't supplanted the backend yet, then wait it out
    if prompt_state === nothing
        return nothing
    end

    # Useful constant
    term_width = LineEdit.width(TTYTerminal("",STDIN,STDOUT,STDERR))

    # Read in any new reports from the outside world
    while isready(btask_report)
        name, callback = take!(btask_report)
        btask_status[name] = (time(), callback)
    end

    status_timestamps = Tuple{Float64,AbstractString}[]
    for name in keys(btask_status)
        status = btask_status[name][2](term_width)
        if status === nothing
            delete!(btask_status, name)
        else
            push!(status_timestamps, (btask_status[name][1], status))
        end
    end

    statuses = AbstractString[status for (timestamp, status) in sort(status_timestamps)]

    # Ensure we're the only one messing with the screen at the moment
    lock(running_mutex)

    # Calculate widths of status lines
    all_widths = Int[strwidth(status) for status in statuses]
    num_lines = sum(Int[div(max(0,w-1),term_width)+1 for w in all_widths])

    # Have we hit enter since the last time we drew?
    if last_enter == last_draw_enter
        # If not, then keep num_lines at least as large as last_draw_lines
        num_lines = max(num_lines, last_draw_lines)
    else
        # If so, then update last_draw_enter and reset last_draw_lines
        last_draw_enter = last_enter
        last_draw_lines = 0
    end

    # Calculate how many lines we need to move up due to the user typing stuff
    skip_lines = max(cursor_position(prompt_state)[1], 0)

    # Now draw the lines
    if num_lines > 0
        # Move up to the top of our play area
        moveup_lines = max(last_draw_lines, 1) + skip_lines
        write(STDOUT,"$(CSI)$(moveup_lines)A$(CSI)1G")

        # Now add as many lines as we still need
        if moveup_lines < num_lines
            write(STDOUT,"\n"^(num_lines - moveup_lines + 1))
            write(STDOUT,"$(CSI)$(num_lines - moveup_lines + 1)A")
        end

        # Clear all lines in case some are shorter, or we dropped some
        for idx in 1:num_lines
            write(STDOUT,"$(CSI)1G$(CSI)0K$(CSI)1B")
            #write(STDOUT,"$(CSI)1G$(CSI)1B")
        end

        # Jump back up the number of lines we have to spit out
        write(STDOUT,"$(CSI)$(length(statuses))A")
        for status in statuses
            write(STDOUT, status)
            write(STDOUT,"\n")
        end

        # Jump back down however many lines we need to in order to satisfy skip_lines
        if skip_lines > 0
            write(STDOUT,"$(CSI)$(skip_lines)B")
        end

        # Refresh the line, save how many lines we just wrote
        LineEdit.refresh_line(prompt_state)
        last_draw_lines = max(last_draw_lines, num_lines)
    end
    flush(STDOUT)
    unlock(running_mutex)
    return nothing
end

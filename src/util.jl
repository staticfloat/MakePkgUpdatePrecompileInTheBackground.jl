function report_progress(callback::Function, name::AbstractString)
    global btask_report
    put!(btask_report, (name, callback))
    return nothing
end

function progress_bar(progress::Float64, bar_width::Int)
    progress = max(0,min(1,progress))
    num_hashes = round(Int,progress*bar_width)
    return "#"^num_hashes * " "^(bar_width - num_hashes)
end

type Cycle
    t::Union{Void,Timer}
    name::AbstractString
    progress::Float64
    speed::Float64

    function Cycle(name::AbstractString)
        # Generate random speed
        speed = rand()*.01

        # Create Cycle object (have to create dummy Timer to avoid Nullable)
        cycle = new(nothing, name, 0, speed)

        # Create timer to increment progress and wrap it around
        cycle.t = Timer(t -> begin
            cycle.progress += cycle.speed
            while cycle.progress >= 1.0
                cycle.progress -= 1.0
            end
        end, 0, .01)

        # Don't forget to clean ourselves up!
        finalizer(cycle, x -> begin
            if x.t != nothing
                close(x.t)
            end
            x.progress = 1.0
        end)
        return cycle
    end
end

function stop(c::Cycle)
    close(c.t)
    c.progress = 1.0
end

# Return the progress line for a particular cycle
function cycle_progress_line(c::Cycle, width)
    if c.progress >= 1.0
        return nothing
    end
    bar_width = max(0, width - strwidth(c.name)) - 12
    return @sprintf("%s: [%s] (%02.1f%%)", c.name, progress_bar(c.progress, bar_width), c.progress*100)
end

cycles = Dict{AbstractString,Cycle}()
function start_cycling(name::AbstractString)
    global cycles

    # Cycle object creates a Timer object that runs itself ragged for us
    cycle = Cycle(name)
    cycles[name] = cycle

    # Tell btask how to ask for our status line of width `width`
    report_progress(name) do width
        return cycle_progress_line(cycle, width)
    end
    return nothing
end

function stop_cycling(name::AbstractString)
    global cycles
    if haskey(cycles, name)
        stop(cycles[name])
        delete!(cycles, name)
    end
    return nothing
end

function stop_cycling()
    global cycles
    cycles = []
end

function cursor_position(state)
    const term = TTYTerminal("",STDIN,STDOUT,STDERR)
    const term_width = LineEdit.width(term)
    buffstr = takebuf_string(copy(LineEdit.buffer(state)))

    # Absolute offset of cursor
    pos = position(LineEdit.buffer(state))

    # Calculate which line that is on
    splitbuff = split(buffstr[1:pos], "\n")
    line = sum(Int[div(max(0,strwidth(line)-1),term_width)+1 for line in splitbuff]) - 1

    # The length of the last line is the offset into that line of the cursor
    offset = strwidth(splitbuff[end])

    return line, offset
end

function prompt_lines(state)
    const term = TTYTerminal("",STDIN,STDOUT,STDERR)
    const term_width = LineEdit.width(term)
    buffstr = takebuf_string(copy(LineEdit.buffer(state)))

    # Calculate number of lines in the full buffer
    return sum(Int[div(max(0,strwidth(line)-1),term_width)+1 for line in split(buffstr, "\n")])
end

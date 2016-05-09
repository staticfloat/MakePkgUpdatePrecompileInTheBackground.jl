__precompile__()
module MakePkgUpdatePrecompileInTheBackground

export start_cycling, stop_cycling, report_progress, supplant_repl_backend, progress_bar, recompile_everything

# We use these subsystems.  A lot.
using Base.REPL, Base.Terminals, Base.LineEdit

# Way better than the TV show.
const CSI = Terminals.CSI

# Global variables help keep the code quality high
btask_report = Channel(10000)
prompt_state = nothing

# The last time a newline caused a new prompt to be written out, signifying that
# we can reset our memory of how many lines we've written out
last_enter = 0
last_draw_enter = 0
last_draw_lines = 0

# This gets locked and unlocked to control ownership of the screen so that we
# don't have two tasks overwriting eachother
running_mutex = Channel()


include("util.jl")
include("pkgupdate.jl")
include("btask.jl")
include("backend.jl")

function __init__()
    # Create timer to continually draw background task progress updates
    btask_draw_timer = Timer(timer -> btask_draw(), 0, .05)

    # Try to auto-supplant the default REPL backend
    supplant_repl_backend(attempt=1)
end

Base.precompile(recompile_everything, ())

end # module

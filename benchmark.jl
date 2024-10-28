using ProgressMeter
using Plots
using ColorSchemes

include("sudoku.jl")

"""
    benchmark

Count how many of the 49158 existing 17 clue sudoku puzzles can be solved using the various strategies. It was proven that the list is complete
and no 16 clue sudoku puzzle can have a unique solution (http://forum.enjoysudoku.com/scan-solution-grids-for-17-clues-as-of-blue-t34012-90.html#p282968).

# counter = [21905, 9617, 2481, 4207, 3191, 79, 7678]
"""
function benchmark()
    counter = fill(0, 7)
    p = Progress(49158; dt=1.0)

    open("data/all-17-hint-sudoku.txt", "r") do file
        for line in eachline(file)
            s = read(line)
            h = solve(s; verbose = false)  # hardness of sudoku

            counter[h] += 1

            update!(p, sum(counter))
        end
    end

    return counter
end

function plotBenchmark(counts::Vector{Int})
    # Strategy labels
    labels = ["Singles", "Hidden Sets", "Naked Sets", "Pointing Sets", 
              "Box Reduction", "X-Wing", "More advanced"]
    
    # Create color gradient from green to red
    gradient = cgrad(colorschemes[:rainbow_bgyr_35_85_c72_n256])
    colors = [gradient[x] for x in range(0.25, 1.0, length=7)]
    
    # Create bar plot
    p = bar(labels, 
            counts,
            title="Most complicated strategy needed",
            xlabel="Strategy",
            ylabel="Count",
            legend=false,
            titlefont=font(12),
            guidefont=font(10),
            tickfont=font(8),
            color=colors,
            size=(800, 500),
            formatter=:plain)  # no scientific notation
    
    savefig(p,"data/benchmark.png")
end

# (c) Mia Muessig
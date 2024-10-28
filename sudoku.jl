using Combinatorics

ROWS = [[(i, j) for j in 1:9] for i in 1:9]
COLS = [[(i, j) for i in 1:9] for j in 1:9]
BLOCKS = [[(by + j, bx + i) for i in 0:2, j in 0:2] for bx in 1:3:9, by in 1:3:9]


"""
    Sudoku

# Arguments
* `solved`: solved[x, y] is true iff the tile at (x, y) is filled
* `candidates`: candidates[x, y] is a bitset of all numbers from 1 to 9 which are valid entries for the tile at (x, y) in the sudoku s. Bitset has a
better performance for dense sets.
* `occRow`: occRow[g, num] is a set of all tiles in row g which can still contain entry num
* `occCol`: occCol[g, num] is a set of all tiles in column g which can still contain entry num
* `occBlock`: occBlock[g, num] is a set of all tiles in block g which can still contain entry num
"""
struct Sudoku
    solved::Array{Bool, 2}
    candidates::Array{BitSet, 2}
    occRow::Array{Set, 2}
    occCol::Array{Set, 2}
    occBlock::Array{Set, 2}

    # Sudoku without any hints
    function Sudoku()
        solved = fill(false, 9, 9)
        candidates = [BitSet(1:9) for _ in 1:9, _ in 1:9]

        occRow = [Set(ROWS[g]) for g in 1:9, _ in 1:9]
        occCol = [Set(COLS[g]) for g in 1:9, _ in 1:9]
        occBlock = [Set(BLOCKS[g]) for g in 1:9, _ in 1:9]

        return new(solved, candidates, occRow, occCol, occBlock)
    end
end

Base.show(io::IO, s::Sudoku) = begin
    for i in 1 : 9
        if (i % 3 == 1)
            println(io, "+-------+-------+-------+")
        end
        for j in 1 : 9
            if j % 3 == 1
                print(io, "| ")
            end
            if s.solved[i, j]
                print(io, string(first(s.candidates[i, j])) * " ")
            else
                print(io, ". ")
            end
        end
        println(io, "|")
    end

    println(io, "+-------+-------+-------+")
end


"""
    read(str)

Construct a Sudoku based on the string representation, so 81 characters with empty spaces being encoded as "0", "_", "," or "*".

# Arguments
* `str`: Input string
"""
function read(str::String)
    # Preprocess string
    str = replace(str, "\n" => "")
    str = replace(str, '*' => '0', ',' => '0', '_' => '0')
    
    if length(str) != 81
        println("Invalid string length")
        return nothing
    end

    s = Sudoku()

    for (i, c) in enumerate(str)
        if c != '0'  # non-empty tile
            # reconstruct coordinates
            x = ((i - 1) ÷ 9) + 1
            y = (i % 9 == 0) ? 9 : i % 9

            add(s, x, y, parse(Int64, c))
        end
    end

    return s
end


"""
    add(s, x, y, num)

Set the tile at position (x, y) in s to entry num and update the candidate sets.

# Arguments
* `s`: Sudoku
* `x`: x coordinate (which row)
* `y`: x coordinate (which row)
* `num`: entry to add
"""
function add(s::Sudoku, x::Int, y::Int, num::Int)
    # mark tile as solved
    s.solved[x, y] = true

    # only remaining canidate is entry
    s.candidates[x, y] = BitSet(num)

    addToRow(s, x, y, num)
    addToCol(s, x, y, num)
    addToBlock(s, x, y, num)
end


function addToRow(s::Sudoku, x::Int, y::Int, num::Int)
    # the added value num can be removed as a candidate from all other tiles in the row
    for (i, j) in ROWS[x]
        if j != y
            remCandidate(s, i, j, num)
        end
    end

    # all values except the added one can be removed as a candidate for the tile
    for n in 1 : 9
        if n != num
            delete!(s.occRow[x, n], (x, y))
        end
    end
end

function addToCol(s::Sudoku, x::Int, y::Int, num::Int)
    # the added value num can be removed as a candidate from all other tiles in the column
    for (i, j) in COLS[y]
        if i != x
            remCandidate(s, i, j, num)
        end
    end

    # all values except the added one can be removed as a candidate for the column
    for n in 1 : 9
        if n != num
            delete!(s.occCol[y, n], (x, y))
        end
    end
end

function addToBlock(s::Sudoku, x::Int, y::Int, num::Int)
    # determine in which block (x, y) is contained
    b = coord2Box(x, y)


    # the added value num can be removed as a candidate from all other tiles in the block
    for (i, j) in BLOCKS[b]
        if (i, j) != (x, y)
            remCandidate(s, i, j, num)
        end
    end

    # all values except the added one can be removed as a candidate for the block
    for n in 1 : 9
        if n != num
            delete!(s.occBlock[b, n], (x, y))
        end
    end
end

function remCandidate(s::Sudoku, i::Int, j::Int, num::Int)
    delete!(s.candidates[i, j], num)  # remove as candidate
    delete!(s.occRow[i, num], (i, j))  # remove from row possibilities for num
    delete!(s.occCol[j, num], (i, j))  # remove from col possibilities for num
    delete!(s.occBlock[coord2Box(i, j), num], (i, j))  # remove from block possibilities for num
end

@inline function coord2Box(i::Int, j::Int)
    # determine in which block tile (i, j) is contained
    return ((i-1) ÷ 3) * 3 + ((j-1) ÷ 3) + 1
end

"""
    isValid(s)

Detect if sudoku is invalid because a unsolved tile has no candidates left

# Arguments
* `s`: Sudoku
"""
function isValid(s::Sudoku)
    for x in 1 : 9
        for y in 1 : 9
            if isempty(s.candidates[x, y])
                return false
            end
        end
    end

    return true
end


"""
    isDone(s)

Detect if sudoku is done because every tile is filled

# Arguments
* `s`: Sudoku
"""
function isDone(s::Sudoku)
    for x in 1 : 9
        for y in 1 : 9
            if !s.solved[x, y]
                return false
            end
        end
    end

    return true
end


"""
    solve(s)

Attempts to solve the sudoku s without guessing by repeatedly applying various deduction strategies

# Arguments
* `s`: Sudoku
"""
function solve(s)
    while !isDone(s) && isValid(s)
        if useSingle(s)
            continue
        end

        if useHiddenSet(s)
            println("Hidden Set deduction used")
            continue
        end

        if useNakedSet(s)
            println("Naked Set deduction used")
            continue
        end

        if usePointingSet(s)
            println("Pointing Set deduction used")
            continue
        end

        if useBoxReduction(s)
            println("Box Reduction deduction used")
            continue
        end

        if useXWing(s)
            println("X-Wing deduction used")
            continue
        end

        break
    end

    if !isValid(s)
        println("Unsatisfiable Sudoku")
    end

    return s
end


"""
    useSingle(s)

Searches for a naked or hidden single in the sudoku s. If one is found, the forced entry is added and the function return true. A detailed explanation
of this strategy can be found here: http://www.taupierbw.be/SudokuCoach/SC_Singles.shtml

# Arguments
* `s`: Sudoku
"""
function useSingle(s::Sudoku)
    # Find naked single (only one candidate left in cell)
    for x in 1 : 9
        for y in 1 : 9
            if length(s.candidates[x, y]) == 1
                if !s.solved[x, y]
                    add(s, x, y, first(s.candidates[x, y]))
                    return true
                end
            end
        end
    end

    # Find hidden single (number only appears in one candidate list of a row/column/block)
    for num in 1 : 9
        for g in 1 : 9
            if length(s.occRow[g, num]) == 1
                (x, y) = first(s.occRow[g, num])
                if !s.solved[x, y]
                    add(s, x, y, num)
                    return true
                end
            end
        end

        for g in 1 : 9
            if length(s.occCol[g, num]) == 1
                (x, y) = first(s.occCol[g, num])
                if !s.solved[x, y]
                    add(s, x, y, num)
                    return true
                end
            end
        end

        for g in 1 : 9
            if length(s.occBlock[g, num]) == 1
                (x, y) = first(s.occBlock[g, num])
                if !s.solved[x, y]
                    add(s, x, y, num)
                    return true
                end
            end
        end
    end

    return false
end


"""
    useHiddenSet(s)

Searches for a hidden pair/triple/quad in the sudoku s. If one is found, the candidates are removed and the function returns true. A detailed explanation
of this strategy can be found here: https://www.sudokuwiki.org/Hidden_Candidates

# Arguments
* `s`: Sudoku
"""
function useHiddenSet(s::Sudoku)
    for c in 2 : 4  # size of hidden set
        for g in 1 : 9  # row
            # more than c tiles free
            if sum([!s.solved[i, j] for (i, j) in ROWS[g]]) <= c
                continue
            end

            # numbers which can be placed in exactly c tiles in row g
            nums = filter(n -> length(s.occRow[g, n]) == c, 1:9)

            for set in combinations(nums, c)
                hidden = true
                for (i, e) in enumerate(set)
                    if i != 1 && s.occRow[g, e] != s.occRow[g, first(set)]
                        # not a hidden set
                        hidden = false
                        break
                    end
                end

                if hidden
                    effective = false  # hidden set actually allows deduction

                    for (i, j) in s.occRow[g, first(set)]
                        for n in 1 : 9
                            if !(n in set) && n in s.candidates[i, j]
                                effective = true
                                remCandidate(s, i, j, n)
                            end
                        end
                    end

                    if effective
                        return true
                    end
                end
            end
        end

        for g in 1 : 9  # column
            # more than c tiles free
            if sum([!s.solved[i, j] for (i, j) in COLS[g]]) <= c
                continue
            end

            # numbers which can be placed in exactly c tiles in column g
            nums = filter(n -> length(s.occCol[g, n]) == c, 1:9)

            for set in combinations(nums, c)
                hidden = true
                for (i, e) in enumerate(set)
                    if i != 1 && s.occCol[g, e] != s.occCol[g, first(set)]
                        # not a hidden set
                        hidden = false
                        break
                    end
                end

                if hidden
                    effective = false  # hidden set actually allows deduction

                    for (i, j) in s.occCol[g, first(set)]  # hidden set
                        for n in 1 : 9
                            if !(n in set) && n in s.candidates[i, j]
                                effective = true
                                remCandidate(s, i, j, n)
                            end
                        end
                    end

                    if effective
                        return true
                    end
                end
            end
        end

        for g in 1 : 9  # block
            # more than c tiles free
            if sum([!s.solved[i, j] for (i, j) in BLOCKS[g]]) <= c
                continue
            end

            # numbers which can be placed in exactly c tiles in block g
            nums = filter(n -> length(s.occBlock[g, n]) == c, 1:9)

            for set in combinations(nums, c)
                hidden = true
                for (i, e) in enumerate(set)
                    if i != 1 && s.occBlock[g, e] != s.occBlock[g, first(set)]
                        # not a hidden set
                        hidden = false
                        break
                    end
                end

                if hidden
                    effective = false  # hidden set actually allows deduction

                    for (i, j) in s.occBlock[g, first(set)]  # hidden set
                        for n in 1 : 9
                            if !(n in set) && n in s.candidates[i, j]
                                effective = true
                                remCandidate(s, i, j, n)
                            end
                        end
                    end

                    if effective
                        return true
                    end
                end
            end
        end
    end

    return false
end


"""
    useNakedSet(s)

Searches for a naked pair/triple/quad in the sudoku s. If one is found, the candidates are removed and the function returns true. A detailed explanation
of this strategy can be found here: https://www.sudokuwiki.org/Naked_Candidates

# Arguments
* `s`: Sudoku
"""
function useNakedSet(s::Sudoku)
    for c in 2 : 4  # size of naked set
        for g in 1 : 9  # row
            # more than c tiles free
            if sum([!s.solved[i, j] for (i, j) in ROWS[g]]) <= c
                continue
            end

            # unsolved tiles with <= c candidates
            tiles = filter(t -> length(s.candidates[t[1], t[2]]) <= c && !s.solved[t[1], t[2]], ROWS[g])

            for set in combinations(tiles, c)
                naked = true
                collect = Set()

                for (i, j) in set
                    for e in s.candidates[i, j]
                        push!(collect, e)
                    end

                    if length(collect) > c
                        # not a naked set since union of candidates has more than c elements
                        naked = false
                        break
                    end
                end

                if naked
                    effective = false  # naked set actually allows deduction

                    for (i, j) in ROWS[g]
                        if !((i, j) in set)  # not part of naked set
                            for n in collect
                                if n in s.candidates[i, j]
                                    effective = true
                                    remCandidate(s, i, j, n) 
                                end
                            end
                        end
                    end

                    if effective
                        return true
                    end
                end
            end
        end

        for g in 1 : 9  # column
            # more than c tiles free
            if sum([!s.solved[i, j] for (i, j) in COLS[g]]) <= c
                continue
            end

            # unsolved tiles with <= c candidates
            tiles = filter(t -> length(s.candidates[t[1], t[2]]) <= c && !s.solved[t[1], t[2]], COLS[g])

            for set in combinations(tiles, c)
                naked = true
                collect = Set()

                for (i, j) in set
                    for e in s.candidates[i, j]
                        push!(collect, e)
                    end

                    if length(collect) > c
                        # not a naked set since union of candidates has more than c elements
                        naked = false
                        break
                    end
                end

                if naked
                    effective = false  # naked set actually allows deduction

                    for (i, j) in COLS[g]
                        if !((i, j) in set)  # not part of naked set
                            for n in collect
                                if n in s.candidates[i, j]
                                    effective = true
                                    remCandidate(s, i, j, n) 
                                end
                            end
                        end
                    end

                    if effective
                        return true
                    end
                end
            end
        end

        for g in 1 : 0 # TODO 9  # block
            # more than c tiles free
            if sum([!s.solved[i, j] for (i, j) in BLOCKS[g]]) <= c
                continue
            end

            # unsolved tiles with <= c candidates
            tiles = filter(t -> length(s.candidates[t[1], t[2]]) <= c && !s.solved[t[1], t[2]], BLOCKS[g])

            for set in combinations(tiles, c)
                naked = true
                collect = Set()

                for (i, j) in set
                    for e in s.candidates[i, j]
                        push!(collect, e)
                    end

                    if length(collect) > c
                        # not a naked set since union of candidates has more than c elements
                        naked = false
                        break
                    end
                end

                if naked
                    effective = false  # naked set actually allows deduction

                    for (i, j) in BLOCKS[g]
                        if !((i, j) in set)  # not part of naked set
                            for n in collect
                                if n in s.candidates[i, j]
                                    effective = true
                                    remCandidate(s, i, j, n) 
                                end
                            end
                        end
                    end

                    if effective
                        return true
                    end
                end
            end
        end
    end

    return false
end


"""
    usePointingSet(s)

Searches for a pointing pair/triple in the sudoku s. If one is found, the candidates are removed and the function returns true. A detailed explanation
of this strategy can be found here: http://www.taupierbw.be/SudokuCoach/SC_PointingPair.shtml

# Arguments
* `s`: Sudoku
"""
function usePointingSet(s::Sudoku)
    for g in 1 : 9  # block
        for n in 1 : 9
            x = first(s.occBlock[g, n])[1]
            y = first(s.occBlock[g, n])[1]

            effective = false

            if all(t -> t[1] == x, s.occBlock[g, n])  # all candidates for n in g are in one row
                for (i, j) in ROWS[x]
                    if !((i, j) in BLOCKS[g])
                        # remove candidates from tiles which share row but are outside block
                        if (i, j) in s.occRow[x, n]
                            effective = true
                            remCandidate(s, i, j, n)
                        end
                    end
                end
            end

            if effective
                return true
            end


            if all(t -> t[2] == y, s.occBlock[g, n])  # all candidates for n in g are in one column
                for (i, j) in COLS[y]
                    if !((i, j) in BLOCKS[g])
                        # remove candidates from tiles which share row but are outside block
                        if (i, j) in s.occCol[y, n]
                            effective = true
                            remCandidate(s, i, j, n)
                        end
                    end
                end
            end

            if effective
                return true
            end
        end
    end

    return false
end


"""
    useBoxReduction(s)

Searches for a box reduction in the sudoku s. If one is found, the candidates are removed and the function returns true. A detailed explanation
of this strategy can be found here: http://www.taupierbw.be/SudokuCoach/SC_BoxReduction.shtml

# Arguments
* `s`: Sudoku
"""
function useBoxReduction(s::Sudoku)
    for g in 1 : 9  # row
        for n in 1 : 9
            effective = false

            b = coord2Box(first(s.occRow[g, n])[1], first(s.occRow[g, n])[2])

            if all(t -> coord2Box(t[1], t[2]) == b, s.occRow[g, n])  #  all candidates for n in g are in one block
                for (i, j) in BLOCKS[b]
                    if !((i, j) in ROWS[g])
                        # remove candidates from tiles which share block but are outside row
                        if (i, j) in s.occBlock[b, n]
                            effective = true
                            remCandidate(s, i, j, n)
                        end
                    end
                end
            end

            if effective
                return true
            end
        end
    end

    for g in 1 : 9  # column
        for n in 1 : 9
            effective = false

            b = coord2Box(first(s.occCol[g, n])[1], first(s.occCol[g, n])[2])

            if all(t -> coord2Box(t[1], t[2]) == b, s.occCol[g, n])  #  all candidates for n in g are in one block
                for (i, j) in BLOCKS[b]
                    if !((i, j) in COLS[g])
                        # remove candidates from tiles which share block but are outside column
                        if (i, j) in s.occBlock[b, n]
                            effective = true
                            remCandidate(s, i, j, n)
                        end
                    end
                end
            end

            if effective
                return true
            end
        end
    end

    return false
end


"""
    useXWing(s)

Searches for a X-Wing pattern in the sudoku s. If one is found, the candidates are removed and the function returns true. A detailed explanation
of this strategy can be found here: http://www.taupierbw.be/SudokuCoach/SC_XWing.shtml

# Arguments
* `s`: Sudoku
"""
function useXWing(s::Sudoku)
    for g1 in 1 : 9  # row
        nums = filter(n -> length(s.occRow[g1, n]) == 2, 1:9)  # numbers appearing exactly twice

        for n in nums
            for g2 in g1 + 1 : 9
                if length(s.occRow[g2, n]) == 2
                    if all(t -> (t[1] - (g2 - g1), t[2]) in s.occRow[g1, n], s.occRow[g2, n])  # n appears in both rows in exact same column
                        effective = false
                        
                        for (x, y) in s.occRow[g1, n]
                            for (i, j) in COLS[y]
                                if i != g1 && i != g2 && (i, j) in s.occCol[j, n]
                                    effective = true
                                    remCandidate(s, i, j, n)
                                end
                            end
                        end
                        
                        if effective
                            return true
                        end
                    end
                end
            end
        end
    end

    for g1 in 1 : 9  # column
        nums = filter(n -> length(s.occCol[g1, n]) == 2, 1:9)  # numbers appearing exactly twice

        for n in nums
            for g2 in g1 + 1 : 9
                if length(s.occCol[g2, n]) == 2
                    if all(t -> (t[1], t[2] - (g2 - g1)) in s.occCol[g1, n], s.occCol[g2, n])  # n appears in both column in exact same row
                        effective = false
                        
                        for (x, y) in s.occCol[g1, n]
                            for (i, j) in ROWS[x]
                                if j != g1 && j != g2 && (i, j) in s.occRow[j, n]
                                    effective = true
                                    remCandidate(s, i, j, n)
                                end
                            end
                        end
                        
                        if effective
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

# (c) Mia Muessig
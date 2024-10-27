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
            b = ((i-1) ÷ 3) * 3 + ((j-1) ÷ 3) + 1

            delete!(s.candidates[i, j], num)
            delete!(s.occRow[x, num], (i, j))
            delete!(s.occCol[j, num], (i, j))
            delete!(s.occBlock[b, num], (i, j))
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
            b = ((i-1) ÷ 3) * 3 + ((j-1) ÷ 3) + 1

            delete!(s.candidates[i, j], num)
            delete!(s.occCol[y, num], (i, j))
            delete!(s.occRow[i, num], (i, j))
            delete!(s.occBlock[b, num], (i, j))
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
    # determine which block (x, y) is contained
    b = ((x-1) ÷ 3) * 3 + ((y-1) ÷ 3) + 1


    # the added value num can be removed as a candidate from all other tiles in the block
    for (i, j) in BLOCKS[b]
        if (i, j) != (x, y)
            delete!(s.candidates[i, j], num)
            delete!(s.occBlock[b, num], (i, j))
            delete!(s.occRow[i, num], (i, j))
            delete!(s.occCol[j, num], (i, j))
        end
    end

    # all values except the added one can be removed as a candidate for the block
    for n in 1 : 9
        if n != num
            delete!(s.occBlock[b, n], (x, y))
        end
    end
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
            if isempty(s.tiles[x, y])
                return false
            end
        end
    end

    return true
end


# (c) Mia Muessig
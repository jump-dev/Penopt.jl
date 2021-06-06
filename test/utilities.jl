using Test
using Penopt

function test_col_row(n)
    k = 0
    for col in 1:n
        for row in 1:col
            k += 1
            c, r = Penopt._col_row(k)
            @test c == col
            @test r == row
        end
    end
end

@testset "_col_row" begin
    test_col_row(100)
end

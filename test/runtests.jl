using Pipe
using Test

_macroexpand(q) = macroexpand(Main, q)

expressions_equal(e1::Expr, e2::Expr) = Base.remove_linenums!(e1) == Base.remove_linenums!(e2)

#No change to nonpipes functionality
@test _macroexpand( :(@pipe a) ) == :a #doesn't change single inputs
@test _macroexpand( :(@pipe b(a)) ) == :(b(a)) #doesn't change inputs that a function applications

#Compatable with Julia 1.3 piping functionality
@test _macroexpand( :(@pipe a|>b) ) == :(b(a)) #basic
@test _macroexpand( :(@pipe a|>b|>c) ) == :(c(b(a)))  #Keeps chaining 3
@test _macroexpand( :(@pipe a|>b|>c|>d) ) == :(d(c(b(a)))) #Keeps chaining 4

@test _macroexpand( :(@pipe a|>b(x)) ) == :((b(x))(a))  #applying to function calls returning functions
@test _macroexpand( :(@pipe a(x)|>b ) ) == :(b(a(x)))   #feeding functioncall results on wards

@test _macroexpand(:(@pipe 1|>a)) ==:(a(1)) #Works with literals (int)
@test _macroexpand(:(@pipe "foo"|>a)) == :(a("foo")) #Works with literal (string)
@test _macroexpand( :(@pipe a|>bb[2])) == :((bb[2])(a)) #Should work with RHS that is a array reference



#Marked locations
@test _macroexpand( :(@pipe a |> _)) == :(a) #Identity works
@test _macroexpand( :(@pipe a |> _[b])) == :(a[b]) #Indexing works

@test _macroexpand( :(@pipe a|>b(_) ) ) == :(b(a)) #Marked location only
@test _macroexpand( :(@pipe a|>b(x,_) ) ) == :(b(x,a)) # marked 2nd (and last)
@test _macroexpand( :(@pipe a|>b(_,x) ) ) == :(b(a,x)) # marked first
@test _macroexpand( :(@pipe a|>b(_,_) ) ) == :(b(a,a)) # marked double (Not certain if this is a good idea)
@test _macroexpand( :(@pipe a|>bb[2](x,_))) == :((bb[2])(x,a)) #Should work with RHS that is a array reference

#Macros and blocks
macro testmacro(arg, n)
    esc(:($arg + $n))
end
@test _macroexpand( :(@pipe a |> @testmacro _ 3 ) ) == :(a + 3) # Can pipe into macros
@test _macroexpand( :(@pipe a |> begin b = _; c + b + _ end )) == :(
                                 begin b = a; c + b + a end)

#marked Unpacking
@test _macroexpand( :(@pipe a|>b(_...) ) ) == :(b(a...)) # Unpacking
@test _macroexpand( :(@pipe a|>bb[2](_...))) == :((bb[2])(a...)) #Should work with RHS of arry ref and do unpacking

#Mixing modes
@test _macroexpand( :(@pipe a|>b|>c(_) ) ) == :(c(b(a)))
@test _macroexpand( :(@pipe a|>b(x,_)|>c|>d(_,y) ) ) == :(d(c(b(x,a)),y))
@test _macroexpand( :(@pipe a|>b(xb,_)|>c|>d(_,xd)|>e(xe) |>f(xf,_,yf)|>_[i] ) ) == :(f(xf,(e(xe))(d(c(b(xb,a)),xd)),yf)[i]) #Very Complex

# broadcasting
fn(x) = x^2
@test _macroexpand( :(@pipe fn |> _.(1:2) ) ) == :(fn.(1:2))
# @test _macroexpand( :(@pipe fn .|> _.(1:2) ) ) == :(fn.(1:2))   # what should we do with this?
@test expressions_equal(_macroexpand( :(@pipe 1:10 .|> _*2 ) ), :(1:10 .|> (var"##253"->var"##253" * 2)))
@test expressions_equal(_macroexpand( :(@pipe 1:10 .|> fn ) ), :(1:10 .|> (var"##254"->fn(var"##254"))))
@test expressions_equal(_macroexpand( :(@pipe a .|> fn .|> _*2 ) ), :(a .|> (var"##255"->fn(var"##255")) .|> (var"##256"->var"##256"*2)))
@test expressions_equal(_macroexpand( :(@pipe a .|> fn |> _*2 ) ), :((a .|> var"##257"->fn(var"##257")) * 2))
@test expressions_equal(_macroexpand( :(@pipe [1,2,2] |> atan.([10,20,30], _) ) ), :(atan.([10,20,30], [1,2,2])))
@test expressions_equal(_macroexpand( :(@pipe [1,2,2] .|> atan.([10,20,30], _) ) ), :([1,2,2] .|> var"##257"->atan.([10,20,30], var"##257")))

# @test _macroexpand( :(@pipe [true,false] .|> ! ) ) == :((!).([true, false]))
# @test _macroexpand( :(@pipe [1, 2] |> .+(_, x) ) ) == :([1, 2] .+ x)
# @test _macroexpand( :(@pipe [1, 2] |>  _ .+ x ) ) == :([1, 2] .+ x)
# # last two are probably not right
# @test _macroexpand( :(@pipe [1, 2] .|> .+(_, x) ) ) == :(var"..+"([1, 2], x))
# @test _macroexpand( :(@pipe [1, 2] .|>  _ .+ x ) ) == :(var"..+"([1, 2], x))

#todo: maybe use broadcase function to deal with
# atan.([10,20,30], [1,2,2])
# broadcast(atan, [10,20,30], [1,2,2])
# broadcast(atan, [10,20,30], broadcast(atan, [1,2,2], 1))

# todo: add tests for following

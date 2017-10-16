# This file is part of the TaylorIntegration.jl package; MIT licensed

using TaylorSeries, TaylorIntegration
using Base.Test

# Constants for the integrations
const _order = 20
const _abstol = 1.0E-20
const t0 = 0.0
const tf = 1000.0



# Scalar integration
const b1 = 3.0
xdot1(t, x) = b1-x^2
ll = length(methods(TaylorIntegration.jetcoeffs!))
@taylorize_ode xdot1_parsed(t, x) = b1-x^2

@testset "Scalar case: xdot(t,x) = b-x^2" begin
    @test length(methods(TaylorIntegration.jetcoeffs!)) == ll+1
    @test isdefined(:xdot1_parsed)
    x0 = 1.0

    tv1, xv1   = taylorinteg( xdot1, x0, t0, tf, _order, _abstol, maxsteps=1000)
    tv1p, xv1p = taylorinteg( xdot1_parsed, x0, t0, tf, _order, _abstol,
        maxsteps=1000)
    @test length(tv1) == length(tv1p)
    @test iszero( norm(tv1-tv1p, Inf) )
    @test iszero( norm(xv1-xv1p, Inf) )
end

xdot2(t, x) = -9.81 + zero(t)
@taylorize_ode xdot2_parsed(t, x) = -9.81

@testset "Scalar case: xdot(t,x) = -9.81" begin
    @test isdefined(:xdot2_parsed)

    tv11, xv11   = taylorinteg( xdot2, 10.0, 1.0, tf, _order, _abstol)
    tv11p, xv11p = taylorinteg( xdot2_parsed, 10.0, 1.0, tf, _order, _abstol)
    @test length(tv11) == length(tv11p)
    @test iszero( norm(tv11-tv11p, Inf) )
    @test iszero( norm(xv11-xv11p, Inf) )
end



# Pendulum integrtf = 100.0
function pendulum!(t, x, dx)
    dx[1] = x[2]
    dx[2] = -sin( x[1] )
    nothing
end
@taylorize_ode function pendulum_parsed!(t, x, dx)
    dx[1] = x[2]
    dx[2] = -sin( x[1] )
    nothing  # `return` is needed at the end, for the vectorial case
end

@testset "Integration of the pendulum" begin
    @test isdefined(:pendulum_parsed!)
    q0 = [pi-0.001, 0.0]
    tv2, xv2 = taylorinteg(pendulum!, q0, t0, tf, _order, _abstol)
    tv2p, xv2p = taylorinteg(pendulum_parsed!, q0, t0, tf, _order, _abstol)
    @test length(tv2) == length(tv2p)
    @test iszero( norm(tv2-tv2p, Inf) )
    @test iszero( norm(xv2-xv2p, Inf) )
end



# Complex dependent variables
const cc = complex(0.0,1.0)
eqscmplx(t,x) = cc*x
@taylorize_ode eqscmplx_parsed(t,x) = cc*x

@testset "Complex dependent variable" begin
    @test isdefined(:eqscmplx_parsed)
    cx0 = complex(1.0, 0.0)
    tv3, xv3 = taylorinteg(eqscmplx, cx0, t0, tf, _order, _abstol,
        maxsteps=1500)
    tv3p, xv3p = taylorinteg(eqscmplx_parsed, cx0, t0, tf, _order, _abstol,
        maxsteps=1500)
    @test length(tv3) == length(tv3p)
    @test iszero( norm(tv3-tv3p, Inf) )
    @test iszero( norm(xv3-xv3p, Inf) )
end



# Multiple (3) pendula
function multpendula!(t, x, dx)
    NN = 3
    for i = 1:NN
        dx[i] = x[NN+i]
        dx[i+NN] = -sin( x[i] )
    end
    return nothing
end
@taylorize_ode function multpendula_parsed!(t, x, dx)
    NN = 3
    for i = 1:NN
        dx[i] = x[NN+i]
        dx[i+NN] = -sin( x[i] )
    end
    return nothing
end

@testset "Multiple pendula" begin
    @test isdefined(:multpendula_parsed!)
    q0 = [pi-0.001, 0.0, pi-0.001, 0.0,  pi-0.001, 0.0]
    tv4, xv4 = taylorinteg(multpendula!, q0, t0, tf, _order, _abstol,
        maxsteps=1000)
    tv4p, xv4p = taylorinteg(multpendula_parsed!, q0, t0, tf, _order, _abstol,
        maxsteps=1000)
    @test length(tv4) == length(tv4p)
    @test iszero( norm(tv4-tv4p, Inf) )
    @test iszero( norm(xv4-xv4p, Inf) )
end



# Kepler problem
_order = 28
tf = 2π*1000.0
mμ = -1.0
function kepler1!(t, q, dq)
    r_p3d2 = (q[1]^2+q[2]^2)^1.5

    dq[1] = q[3]
    dq[2] = q[4]
    dq[3] = mμ*q[1]/r_p3d2
    dq[4] = mμ*q[2]/r_p3d2

    return nothing
end
@taylorize_ode function kepler1_parsed!(t, q, dq)
    r_p3d2 = (q[1]^2+q[2]^2)^1.5

    dq[1] = q[3]
    dq[2] = q[4]
    dq[3] = mμ*q[1]/r_p3d2
    dq[4] = mμ*q[2]/r_p3d2

    return nothing
end
@taylorize_ode function kepler2_parsed!(t, q, dq)
    ll = 2
    r2 = zero(q[1])
    for i = 1:ll
        r2_aux = r2 + q[i]^2
        r2 = r2_aux
    end
    r_p3d2 = r2^(3/2)
    for j = 1:ll
        dq[j] = q[ll+j]
        dq[ll+j] = mμ*q[j]/r_p3d2
    end

    nothing
end

@testset "Kepler problem (two implementations)" begin
    @test isdefined(:kepler1_parsed!)
    @test isdefined(:kepler2_parsed!)
    q0 = [0.2, 0.0, 0.0, 3.0]
    tv5, xv5 = taylorinteg(kepler1!, q0, t0, tf, _order, _abstol,
        maxsteps=500000)
    tv5p, xv5p = taylorinteg(kepler1_parsed!, q0, t0, tf, _order, _abstol,
        maxsteps=500000)
    tv6p, xv6p = taylorinteg(kepler2_parsed!, q0, t0, tf, _order, _abstol,
        maxsteps=500000)
    @test length(tv5) == length(tv5p) == length(tv6p)
    @test iszero( norm(tv5-tv5p, Inf) )
    @test iszero( norm(xv5-xv5p, Inf) )
    @test iszero( norm(tv5-tv6p, Inf) )
    @test iszero( norm(xv5-xv6p, Inf) )
end

# This file is part of the TaylorIntegration.jl package; MIT licensed


# jetcoeffs!
doc"""
    jetcoeffs!(f, t, x)

Returns an updated `x` using the recursion relation of the
derivatives from the ODE $\dot{x}=dx/dt=f(t,x)$.

`f` is the function defining the RHS of the ODE, `x` is a `Taylor1{T}`
or a vector of that type, containing the Taylor expansion
of the dependent variables of the ODE and `t` is the independent
variable.
Initially, `x` contains only the 0-th order Taylor coefficients of
the current system state (the initial conditions), and `jetcoeffs!`
computes recursively the high-order derivates back into `x`.
"""
function jetcoeffs!{T<:Number}(eqsdiff, t0::T, x::Taylor1{T})
    order = x.order
    for ord in 1:order
        ordnext = ord+1

        # Set `xaux`, auxiliary Taylor1 variable to order `ord`
        @inbounds xaux = Taylor1( x.coeffs[1:ord] )

        # Equations of motion
        # TODO! define a macro to optimize the eqsdiff
        xdot = eqsdiff(t0, xaux)

        # Recursion relation
        @inbounds x.coeffs[ordnext] = xdot.coeffs[ord]/ord
    end
    nothing
end

function jetcoeffs!{T<:Number}(eqsdiff, t0::T, x::Vector{Taylor1{T}})
    order = x[1].order
    xaux = similar(x)
    for ord in 1:order
        ordnext = ord+1

        # Set `xaux`, auxiliary vector of Taylor1 to order `ord`
        @inbounds for j in eachindex(x)
            xaux[j] = Taylor1( x[j].coeffs[1:ord] )
        end

        # Equations of motion
        # TODO! define a macro to optimize the eqsdiff
        xdot = eqsdiff(t0, xaux)

        # Recursion relations
        @inbounds for j in eachindex(x)
            x[j].coeffs[ordnext] = xdot[j].coeffs[ord]/ord
        end
    end
    nothing
end


# stepsize
doc"""
    stepsize(x, epsilon)

Returns a time-step for a `x::Taylor1{T}` using a
prescribed absolute tolerance `epsilon`.
"""
function stepsize{T<:Number}(x::Taylor1{T}, epsilon::T)
    ord = x.order
    h = T(Inf)
    for k in (ord-1, ord)
        @inbounds aux = abs( x.coeffs[k+1] )
        aux == zero(T) && continue
        aux = epsilon / aux
        kinv = one(T)/k
        aux = aux^kinv
        h = min(h, aux)
    end
    return h
end

doc"""
    stepsize(q, epsilon)

Returns the minimum time-step for `q::Array{Taylor1{T},1}`,
using a prescribed absolute tolerance `epsilon`.
"""
function stepsize{T<:Number}(q::Array{Taylor1{T},1}, epsilon::T)
    h = T(Inf)
    for i in eachindex(q)
        @inbounds hi = stepsize( q[i], epsilon )
        h = min( h, hi )
    end
    return h
end

doc"""
    stepsize(x, rel_tol, abs_tol)

Returns a time-step for a `x::Taylor1{T}` using a
prescribed absolute tolerance `epsilon`.
"""
function stepsize{T<:Number}(x::Taylor1{T}, rel_tol::T, abs_tol::T)
    ord = x.order
    h = T(Inf)
    x0infnorm = abs( x.coeffs[1] )
    if rel_tol*x0infnorm <= abs_tol
        for k in (ord-1, ord)
            @inbounds aux = abs( x.coeffs[k+1] )
            aux == zero(T) && continue
            aux = one(T) / aux
            kinv = one(T)/k
            aux = aux^kinv
            h = min(h, aux)
        end
    else
        for k in (ord-1, ord)
            @inbounds aux = abs( x.coeffs[k+1] )
            aux == zero(T) && continue
            aux = x0infnorm / aux
            kinv = one(T)/k
            aux = aux^kinv
            h = min(h, aux)
        end
    end
    expsq = exp(one(T))^2
    safety = exp( -one(T)/(ord-one(T)) )/expsq
    return h*safety
end

doc"""
    stepsize(q, rel_tol, abs_tol)

Returns the minimum time-step for `q::Array{Taylor1{T},1}`,
using a prescribed absolute tolerance `epsilon`.
"""
function stepsize{T<:Number}(q::Array{Taylor1{T},1}, rel_tol::T, abs_tol::T)
    ord = q[1].order
    h = T(Inf)
    qcoeffs0 = Array{T}(length(q))
    for i in eachindex(q)
        @inbounds qcoeffs0[i] = q[i].coeffs[1]
    end
    qcoeffs0infnorm = norm(qcoeffs0, Inf)
    if rel_tol*qcoeffs0infnorm <= abs_tol
        for k in (ord-1, ord)
            qcoeffskp1 = Array{T}(length(q))
            for i in eachindex(q)
                @inbounds qcoeffskp1[i] = q[i].coeffs[k+1]
            end
            aux = norm(qcoeffskp1, Inf)
            aux == zero(T) && continue
            aux = one(T) / aux
            kinv = one(T)/k
            aux = aux^kinv
            h = min(h, aux)
        end
    else
        for k in (ord-1, ord)
            qcoeffskp1 = Array{T}(length(q))
            for i in eachindex(q)
                @inbounds qcoeffskp1[i] = q[i].coeffs[k+1]
            end
            aux = norm(qcoeffskp1, Inf)
            aux == zero(T) && continue
            aux = qcoeffs0infnorm / aux
            kinv = one(T)/k
            aux = aux^kinv
            h = min(h, aux)
        end
    end
    expsq = exp(one(T))^2
    exparg = 10( ord-one(T) )
    exparg = -7/exparg
    safety = exp( exparg )/expsq
    return h*safety
end


# evaluate and evaluate!
doc"""
    evaluate(x, δt)

Evaluates each element of `x::Array{Taylor1{T},1}`, representing
the dependent variables of an ODE, at *time* δt.
"""
function evaluate{T<:Number}(x::Array{Taylor1{T},1}, δt::T)
    xnew = Array{T}( length(x) )
    evaluate!(x, δt, xnew)
    return xnew
end

doc"""
    evaluate!(x, δt, x0)

Evaluates each element of `x::Array{Taylor1{T},1}`, representing
the Taylor expansion for the dependent variables of an ODE at
*time* δt; it updates the vector `x0` with the computed values.
"""
function evaluate!{T<:Number}(x::Array{Taylor1{T},1}, δt::T, x0::Array{T,1})
    @assert length(x) == length(x0)
    @inbounds for i in eachindex(x)
        x0[i] = evaluate( x[i], δt )
    end
    nothing
end


# taylorstep and taylorstep!
doc"""
    taylorstep(f, t0, x0, order, abs_tol)

Compute one-step Taylor integration for the ODE $\dot{x}=dx/dt=f(t, x)$
with initial condition $x(t_0)=x0$, returning the
time-step of the integration carried out and the updated value of `x0`.

Here, `x0` is the initial (and returned) dependent variable, `order`
is the degree used for the `Taylor1` polynomials during the integration
and `abs_tol` is the absolute tolerance used to determine the time step
of the integration.
"""
function taylorstep{T<:Number}(f, t0::T, x0::T, order::Int, abs_tol::T)
    # Initialize the Taylor1 expansions
    xT = Taylor1( x0, order )
    # Compute the Taylor coefficients
    jetcoeffs!(f, t0, xT)
    # Compute the step-size of the integration using `abs_tol`
    δt = stepsize(xT, abs_tol)
    x0 = evaluate(xT, δt)
    return δt, x0
end

doc"""
    taylorstep!(f, t0, x0, order, abs_tol)

Compute one-step Taylor integration for the ODE $\dot{x}=dx/dt=f(t, x)$
with initial conditions $x(t_0)=x0$, a vector of type T, returning the
step-size of the integration; `x0` is updated.

Here, `x0` is the initial (and updated) dependent variables, `order`
is the degree used for the `Taylor1` polynomials during the integration
and `abs_tol` is the absolute tolerance used to determine the time step
of the integration.
"""
function taylorstep!{T<:Number}(f, t0::T, x0::Array{T,1}, order::Int, abs_tol::T)
    # Initialize the vector of Taylor1 expansions
    xT = Array{Taylor1{T}}(length(x0))
    for i in eachindex(x0)
        @inbounds xT[i] = Taylor1( x0[i], order )
    end
    # Compute the Taylor coefficients
    jetcoeffs!(f, t0, xT)
    # Compute the step-size of the integration using `abs_tol`
    δt = stepsize(xT, abs_tol)
    evaluate!(xT, δt, x0)
    return δt
end

doc"""
    taylorstep(f, t0, t1, x0, order, abs_tol)

Compute one-step Taylor integration for the ODE $\dot{x}=dx/dt=f(t, x)$
with initial conditions $x(t_0)=x0$, returning the
time-step of the integration carried out and the updated value of `x0`.

Here, `x0` is the initial (and returned) dependent variables, `order`
is the degree used for the `Taylor1` polynomials during the integration
and `abs_tol` is the absolute tolerance used to determine the time step
of the integration. If the time step is larger than `t1-t0`, that difference
is used as the time step.
"""
function taylorstep{T<:Number}(f, t0::T, t1::T, x0::T, order::Int, abs_tol::T)
    @assert t1 > t0
    # Initialize the Taylor1 expansions
    xT = Taylor1( x0, order )
    # Compute the Taylor coefficients
    jetcoeffs!(f, t0, xT)
    # Compute the step-size of the integration using `abs_tol`
    δt = stepsize(xT, abs_tol)
    if δt ≥ t1-t0
        δt = t1-t0
    end
    x0 = evaluate(xT, δt)
    return δt, x0
end

doc"""
    taylorstep!(f, t0, t1, x0, order, abs_tol)

Compute one-step Taylor integration for the ODE $\dot{x}=dx/dt=f(t, x)$
with initial conditions $x(t_0)=x0$, a vector of type T, returning the
step-size of the integration carried out and updating `x0`.

Here, `x0` is the initial (and updated) dependent variables, `order`
is the degree used for the `Taylor1` polynomials during the integration
and `abs_tol` is the absolute tolerance used to determine the time step
of the integration. If the time step is larger than `t1-t0`, that difference
is used as the time step.
"""
function taylorstep!{T<:Number}(f, t0::T, t1::T, x0::Array{T,1},
        order::Int, abs_tol::T)
    @assert t1 > t0
    # Initialize the vector of Taylor1 expansions
    xT = Array{Taylor1{T}}(length(x0))
    for i in eachindex(x0)
        @inbounds xT[i] = Taylor1( x0[i], order )
    end
    # Compute the Taylor coefficients
    jetcoeffs!(f, t0, xT)
    # Compute the step-size of the integration using `abs_tol`
    δt = stepsize(xT, abs_tol)
    if δt ≥ t1-t0
        δt = t1-t0
    end
    evaluate!(xT, δt, x0)
    return δt
end

doc"""
    taylorstep(f, t0, x0, rel_tol, abs_tol)

Compute one-step Taylor integration for the ODE $\dot{x}=dx/dt=f(t, x)$
with initial condition $x(t_0)=x0$, returning the
time-step of the integration carried out and the updated value of `x0`.

Here, `x0` is the initial (and returned) dependent variable and `rel_tol`
and `abs_tol` are, respectively, the relative and absolute tolerance used to
determine the order and time step of the integration.
"""
function taylorstep{T<:Number}(f, t0::T, x0::T, rel_tol::T, abs_tol::T)
    # Compute the infinity-norm (ie., absolute value) of x0
    x0infnorm = abs(x0)
    # Compute the optimal order of Taylor expansion
    if rel_tol*x0infnorm <= abs_tol
        order = ceil( Int, one(T)-log(abs_tol)/2 )
    else
        order = ceil( Int, one(T)-log(rel_tol)/2 )
    end
    # Initialize the Taylor1 expansions
    xT = Taylor1( x0, order )
    # Compute the Taylor coefficients
    jetcoeffs!(f, t0, xT)
    # Compute the step-size of the integration using `abs_tol`
    δt = stepsize(xT, rel_tol, abs_tol)
    x0 = evaluate(xT, δt)
    return δt, x0
end

doc"""
    taylorstep!(f, t0, x0, rel_tol, abs_tol)

Compute one-step Taylor integration for the ODE $\dot{x}=dx/dt=f(t, x)$
with initial conditions $x(t_0)=x0$, a vector of type T, returning the
step-size of the integration; `x0` is updated.

Here, `x0` is the initial (and updated) dependent variables, `order`
is the degree used for the `Taylor1` polynomials during the integration
and `abs_tol` is the absolute tolerance used to determine the time step
of the integration.
"""
function taylorstep!{T<:Number}(f, t0::T, x0::Array{T,1}, rel_tol::T, abs_tol::T)
    # Compute the infinity-norm (ie., absolute value) of x0
    x0infnorm = norm(x0, Inf)
    # Compute the optimal order of Taylor expansion
    if rel_tol*x0infnorm <= abs_tol
        order = ceil( Int, one(T)-log(abs_tol)/2 )
    else
        order = ceil( Int, one(T)-log(rel_tol)/2 )
    end
    # println("order=", order)
    # Initialize the vector of Taylor1 expansions
    xT = Array{Taylor1{T}}(length(x0))
    for i in eachindex(x0)
        @inbounds xT[i] = Taylor1( x0[i], order )
    end
    # Compute the Taylor coefficients
    jetcoeffs!(f, t0, xT)
    # Compute the step-size of the integration using `abs_tol`
    δt = stepsize(xT, rel_tol, abs_tol)
    evaluate!(xT, δt, x0)
    return δt
end


# taylorinteg
doc"""
    taylorinteg(f, x0, t0, tmax, order, abs_tol; keyword... )

This is a general-purpose Taylor integrator for the explicit ODE
$\dot{x}=f(t, x)$ with initial condition specified by `x0` at time `t0`.
It returns a vector with the values of time (independent variable),
and a vector (of type `typeof(x0)`) with the computed values of
the dependent variables. The integration stops when time
is larger than `tmax`, or the number of saved steps is larger
than `maxsteps`.

The integrator uses polynomial expansions on the independent variable
of order `order` and the parameter `abs_tol` serves to define the
time step using the last two Taylor coefficients of the expansions.

The current keyword arguments is `maxsteps=500`.
"""
function taylorinteg{T<:Number}(f, x0::T, t0::T, t_max::T,
        order::Int, abs_tol::T; maxsteps::Int=500)
    tv = [t0]
    xv = [x0]
    nsteps = 0
    while t0 < t_max
        δt, x0 = taylorstep(f, t0, x0, order, abs_tol)
        t0 += δt
        push!(tv, t0)
        push!(xv, x0)
        nsteps += 1
        if nsteps ≥ maxsteps
            warn("""
            Maximum number of integration steps reached; exiting.
            """)
            break
        end
    end

    return tv, xv
end

function taylorinteg{T<:Number}(f, q0::Array{T,1}, t0::T, t_max::T,
        order::Int, abs_tol::T; maxsteps::Int=500)

    x0 = copy(q0)
    tv = [t0]
    xv = Array{typeof(x0)}(0)
    push!(xv, copy(x0))
    nsteps = 0
    while t0 < t_max
        δt = taylorstep!(f, t0, x0, order, abs_tol)
        t0 += δt
        push!(tv, t0)
        push!(xv, copy(x0))
        nsteps += 1
        if nsteps ≥ maxsteps
            warn("""
            Maximum number of integration steps reached; exiting.
            """)
            break
        end
    end

    return tv, xv
end

# Integrate and return results evaluated at given time
function taylorinteg{T<:Number}(f, x0::T, trange::Range{T},
        order::Int, abs_tol::T; maxsteps::Int=500)

    nn = length(trange)
    xv = Array{T,1}(nn)
    fill!(xv, T(NaN))
    xv[1] = x0

    iter = 1
    while iter < nn
        t0, t1 = trange[iter], trange[iter+1]
        nsteps = 0
        while nsteps < maxsteps
            xold = x0
            δt, x0 = taylorstep(f, t0, x0, order, abs_tol)
            if t0+δt ≥ t1
                x0 = xold
                δt, x0 = taylorstep(f, t0, t1, x0, order, abs_tol)
                t0 = t1
                break
            end
            t0 += δt
            nsteps += 1
        end
        if nsteps ≥ maxsteps && t0 != t1
            warn("""
            Maximum number of integration steps reached; exiting.
            """)
            break
        end
        iter += 1
        xv[iter] = x0
    end

    return xv
end

function taylorinteg{T<:Number}(f, q0::Array{T,1}, trange::Range{T},
        order::Int, abs_tol::T; maxsteps::Int=500)

    nn = length(trange)
    x0 = similar(q0)
    fill!(x0,T(NaN))
    xv = Array{typeof(q0),1}(nn)
    for iter in eachindex(xv)
        xv[iter] = x0
    end
    x0 = copy(q0)
    xv[1] = copy(q0)

    iter = 1
    while iter < nn
        t0, t1 = trange[iter], trange[iter+1]
        nsteps = 0
        while nsteps < maxsteps
            xold = copy(x0)
            δt = taylorstep!(f, t0, x0, order, abs_tol)
            if t0+δt ≥ t1
                x0 = xold
                δt = taylorstep!(f, t0, t1, x0, order, abs_tol)
                t0 = t1
                break
            end
            t0 += δt
            nsteps += 1
        end
        if nsteps ≥ maxsteps && t0 != t1
            warn("""
            Maximum number of integration steps reached; exiting.
            """)
            break
        end
        iter += 1
        xv[iter] = copy(x0)
    end

    return xv
end

function taylorinteg{T<:Number}(f, x0::T, t0::T, t_max::T,
        rel_tol::T, abs_tol::T; maxsteps::Int=500)
    tv = [t0]
    xv = [x0]
    nsteps = 0
    while t0 < t_max
        δt, x0 = taylorstep(f, t0, x0, rel_tol, abs_tol)
        t0 += δt
        push!(tv, t0)
        push!(xv, x0)
        nsteps += 1
        if nsteps ≥ maxsteps
            warn("""
            Maximum number of integration steps reached; exiting.
            """)
            break
        end
    end

    return tv, xv
end

function taylorinteg{T<:Number}(f, q0::Array{T,1}, t0::T, t_max::T,
        rel_tol::T, abs_tol::T; maxsteps::Int=500)

    x0 = copy(q0)
    tv = [t0]
    xv = Array{typeof(x0)}(0)
    push!(xv, copy(x0))
    nsteps = 0
    while t0 < t_max
        δt = taylorstep!(f, t0, x0, rel_tol, abs_tol)
        t0 += δt
        push!(tv, t0)
        push!(xv, copy(x0))
        nsteps += 1
        if nsteps ≥ maxsteps
            warn("""
            Maximum number of integration steps reached; exiting.
            """)
            break
        end
    end

    return tv, xv
end

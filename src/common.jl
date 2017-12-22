abstract type TaylorAlgorithm <: DEAlgorithm end
struct TaylorMethod <: TaylorAlgorithm
    order::Int
end

TaylorMethod() = error("Maximum order must be specified for the Taylor method")

export TaylorMethod

function DiffEqBase.solve{uType,tType,isinplace,AlgType<:TaylorAlgorithm}(
    prob::AbstractODEProblem{uType,tType,isinplace},
    alg::AlgType,
    timeseries=[],ts=[],ks=[];
    verbose=true, abstol = 1e-6, save_start = true,
    timeseries_errors=true, maxiters = 1000000,
    callback=nothing, kwargs...)

    if verbose
        warned = !isempty(kwargs) && check_keywords(alg, kwargs, warnlist)
        warned && warn_compat()
    end

    if prob.callback != nothing || callback != nothing
        error("TaylorIntegration is not compatible with callbacks.")
    end

    if typeof(prob.u0) <: Number
        u0 = [prob.u0]
    else
        u0 = vec(deepcopy(prob.u0))
    end

    sizeu = size(prob.u0)

    if !isinplace && (typeof(prob.u0)<:Vector{Float64} || typeof(prob.u0)<:Number)
        f! = (t, u, du) -> (du .= prob.f(t, u); 0)
    elseif !isinplace && typeof(prob.u0)<:AbstractArray
        f! = (t, u, du) -> (du .= vec(prob.f(t, reshape(u, sizeu))); 0)
    elseif typeof(prob.u0)<:Vector{Float64}
        f! = prob.f
    else # Then it's an in-place function on an abstract array
        f! = (t, u, du) -> (prob.f(t, reshape(u, sizeu),reshape(du, sizeu));
                            u = vec(u); du=vec(du); 0)
    end

    t,vectimeseries = taylorinteg(f!, u0, prob.tspan[1], prob.tspan[2], alg.order,
                                                      abstol, maxsteps=maxiters)

    if save_start
      start_idx = 1
      _t = t
    else
      start_idx = 2
      _t = t[2:end]
    end
    if typeof(prob.u0) <: AbstractArray
      _timeseries = Vector{uType}(0)
      for i=start_idx:size(vectimeseries, 1)
          push!(_timeseries, reshape(view(vectimeseries, i, :, )', sizeu))
      end
    else
      _timeseries = vec(vectimeseries)
    end

    build_solution(prob,  alg, _t, _timeseries,
                   timeseries_errors = timeseries_errors,
                   retcode = :Success)
end

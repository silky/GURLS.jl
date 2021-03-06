# Abstract type to hold sufficient statistics to describe our model. 
abstract AbstractModel <: AbstractResults

# Catch-all to generate errors if we get ahead of ourselves
predict{T<:AbstractModel}(model::T) =
 error("Predict not implemented for models of type $(typeof(model)).")

##############################################################################
# Linear model definition and building
type LinearModel{T<:Real} <: AbstractModel
	w::Vector{T}
end

function predict(model::LinearModel,X)
	return X * model.w
end

function buildModel{P<:Paramsel}(train::Training{Linear,P,Primal},lambda::Real)
	# w = inv(train.X' * train.X + lambda * eye(size(train.X,2))) * train.X' * train.y

	(n,d) = size(train.X)
	XtX = train.X' * train.X + n * lambda * eye(d)
	Xty = train.X' * train.y
	k = chol(XtX)
	w = k\(k'\Xty)

	return LinearModel(vec(w))
end


function buildModel{P<:Paramsel,R<:Real}(train::Training{Linear,P,Dual},lambda::Real,K::Array{R,2})

	w = train.X' * getC(train,lambda,K)

	return LinearModel(vec(w))

end

function getC{R<:Real,Kern<:Kernel,P<:Paramsel}(train::Training{Kern,P,Dual},lambda::Real,K::Array{R,2})
	n = size(train.X,1)

	K += n * lambda * eye(n)

	kFact = chol(K)

	c = kFact\(kFact'\train.y)

	return vec(c)
end

process(p::Prediction, results) = predict(results[p.training].model, p.X)

##############################################################################
# Gaussian model definition and building

type GaussianModel{T<:Real} <: AbstractModel
	c::Array{T,1} 
	sigma::Real
end

function predict(model::GaussianModel,X)
	t = Training(X,ones(size(X,1)),kernel = Gaussian(), rls = Dual())
	k = buildKernel(t,model.sigma)
	return k * model.c
end

function buildModel{P<:Paramsel,R<:Real}(train::Training{Gaussian,P,Dual},lambda::Real,K::Array{R,2},sigma)
	return GaussianModel(getC(train,lambda,K),sigma)
end


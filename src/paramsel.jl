##############################################################################
# Holds the results of our parameter selection process
type ParamselResults{T<:Real} <: AbstractResults
	model::AbstractModel
	guesses::Array # Can contain tuples for sig/lam selection
	performance::Array{T,2}
end

##############################################################################

function process(train::Training{Linear,LOOCV,Primal})
	XX = train.X' * train.X
	Xy = train.X' * train.y
	(n,d) = size(train.X)

	(L,Q) = eig(XX)

	guesses = getLambdaGuesses(L,min(n,d),n,num_lambda(train.kernel))

	LEFT = train.X * Q
	RIGHT = Q' * Xy

	# pre-allocate memory
	performance = zeros(num_lambda(train.kernel))

	# Test all values for lambda
	i = 1
	for lambda in guesses
		# performance[i] = validate(train,lambda)
		performance[i] = validatePrimal(LEFT,RIGHT,L,lambda,train.y)[1]
		# println(performance[i])
		i += 1
	end

		# Find the best value for lambda
	_, best = findmin(performance)
	lambdaBest = guesses[best]

	# Build the final model-- might as well use all of the training set.
	model = buildModel(train,lambdaBest)

	return ParamselResults(model,guesses,performance')
end


function process{Kern<:Kernel}(train::Training{Kern,LOOCV,Dual})

	(n,d) = size(train.X)

	kernelSpace = getKernelSpace(train)

	# pre-allocate memory
	performance = zeros(num_lambda(train.kernel),length(kernelSpace))
	lambdaBests = zeros(length(kernelSpace))
	j = 1
	for kernArgs in kernelSpace

		K = buildKernel(train,kernArgs...)

		# Compute the eigenfactorization of K
		(L,Q) = eig(K)
		r = rank(train.X)
		Qy = Q' * train.y

		guesses = getLambdaGuesses(L,r,n,num_lambda(train.kernel))

		# Test all values for lambda
		i = 1
		for lambda in guesses
			performance[i,j] = validateDual(Q,L,Qy,lambda,train.y)[1]
			# println(performance[i])
			i += 1
		end

		# Find the best value for lambda
		perf, best = findmin(performance[:,j])
		lambdaBests[j] = guesses[best]

		j += 1
	end

	_,best = findmin(min(performance,1)) # find best value for kernArgs

	# Need to build nonlinear kernels. Also record what kernargs we're using
	if Kern != Linear
		kernArgs = kernelSpace[best]
		K = buildKernel(train,kernArgs)
		guesses = kernArgs
	else
		kernelArgs = ()
	end

	# Build the final model-- might as well use all of the training set.
	model = buildModel(train,lambdaBests[best],K,kernArgs...)

	return ParamselResults(model,[guesses],performance')

end

function getLambdaGuesses(eig,rank,n,nLambda)
# Figure out the lambdas we need to search -- based off of paramsel_lambdaguess.m

	eigs = sort(eig,rev = true) # pass by reference, and order matters for later use. 
	lmax = eigs[1]
	lmin = max(min(lmax * 1e-8, eigs[rank]),200*sqrt(eps()))

	powers = linspace(0,1,nLambda)
	guesses = lmin.*(lmax/lmin).^(powers)

	return guesses / n
end

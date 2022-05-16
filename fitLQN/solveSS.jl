using SCIP,AmplNLWriter,Couenne_jll,Printf,Ipopt,MadNLP,Plots,MadNLPMumps,JuMP,MAT,ProgressBars,ParameterJuMP,Statistics

DATA= matread("/Users/emilio/git/MS-App/fitLQN/fromJulia.mat")

P=DATA["P"]
P2=DATA["P2"]
MU=DATA["MU"]
Cli=[110]

npoints=size(Cli,1)

model = Model(Ipopt.Optimizer)
set_optimizer_attribute(model, "max_iter", 20000)
# set_optimizer_attribute(model, "derivative_test", "first-order")
# set_optimizer_attribute(model, "check_derivatives_for_naninf", "yes")
#set_optimizer_attribute(model, "tol", 10^-12)
#set_optimizer_attribute(model, "acceptable_tol", 10^-12)
#set_optimizer_attribute(model, "print_level", 0)

#      X0_E,X1_E,X2_E
jump=[ -1   +1   +0;
       -1   +0   +1;
       +0   +0   +0;
       +1   -1   +0;
       +0   -1   +1;
       +0   +0   +0;
       +1   +0   -1;
       +0   +1   -1;
       +0   +0   +0;
       ]

f(x::T) where {T<:Real} = -(-x+((-x)^2+10^-10)^(1.0/2))/2.0
register(model, :min_, 1, f, autodiff=true) #∇f)

@variable(model,T[i=1:size(jump,1),j=1:npoints]>=0)
@variable(model,RTlqn[i=1:size(jump,2),p=1:npoints]>=0)
@variable(model,X[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,RTs[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,E_ss[i=1:size(jump,2),j=1:npoints]>=0)

for p=1:npoints

@constraint(model,sum(X[:,p])==Cli[p])

exp1=@NLexpression(model,(-(-(X[2,p]-NC[p,2])+((-(X[2,p]-NC[p,2]))^2+10^-10)^(1.0/2))/2.0+NC[p,2]))
exp2=@NLexpression(model,(-(-(X[3,p]-NC[p,3])+((-(X[3,p]-NC[p,3]))^2+10^-10)^(1.0/2))/2.0+NC[p,3]))

@NLconstraint(model,T[1,p]==P[1,2]*MU[1]*X[1,p])
@NLconstraint(model,T[2,p]==P[1,3]*MU[1]*X[1,p])
@NLconstraint(model,T[3,p]==P[1,1]*MU[1]*X[1,p])

@NLconstraint(model,T[4,p]==P[2,1]*MU[2]*exp1)
@NLconstraint(model,T[5,p]==P[2,3]*MU[2]*exp1)
@NLconstraint(model,T[6,p]==P[2,2]*MU[2]*exp1)

@NLconstraint(model,T[7,p]==P[3,1]*MU[3]*exp2)
@NLconstraint(model,T[8,p]==P[3,2]*MU[3]*exp2)
@NLconstraint(model,T[9,p]==P[3,3]*MU[3]*exp2)

#@constraint(model,jump'*T[:,p].==0)

@constraint(model,[k=1:size(E_ss,1)],E_ss[k,p]>=(jump'*T[:,p])[k])
@constraint(model,[k=1:size(E_ss,1)],E_ss[k,p]>=-(jump'*T[:,p])[k])

@NLconstraint(model,sum(T[i,p] for i in [1,2,3])*RTs[1,p]==X[1,p])
@NLconstraint(model,sum(T[i,p] for i in [4,5,6])*RTs[2,p]==X[2,p])
@NLconstraint(model,sum(T[i,p] for i in [7,8,9])*RTs[3,p]==X[3,p])
end

for p=1:npoints
        for i=1:size(jump,2)
            @constraint(model,RTlqn[i,p]==sum(P[i,j]*P2[i,j]*RTlqn[j,p] for j=1:size(jump,2))+RTs[i,p])
        end
end

@objective(model,Min, sum(E_ss))
JuMP.optimize!(model)

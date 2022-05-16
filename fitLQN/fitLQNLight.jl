using SCIP,AmplNLWriter,Couenne_jll,Printf,Ipopt,MadNLP,Plots,MadNLPMumps,JuMP,MAT,ProgressBars,ParameterJuMP,Statistics

DATA = matread("../execution/data/3tier_learnHDVCALL.mat")

nzIdz=sum(DATA["RTm"],dims=2).!=0

Cli=zeros(sum(nzIdz),1)
Tm=zeros(sum(nzIdz),size(DATA["Tm"],2))
RTm=zeros(sum(nzIdz),size(DATA["RTm"],2))
NC=zeros(sum(nzIdz),size(DATA["NC"],2))

for i=1:sum(nzIdz)
        if(DATA["Cli"][i]!=0)
                global Cli[i]=DATA["Cli"][i]
                global Tm[i,:]=DATA["Tm"][i,:]
                global RTm[i,:]=DATA["RTm"][i,:]
                global NC[i,:]=DATA["NC"][i,:]
        end
end


#model = Model(()->MadNLP.Optimizer(linear_solver=MadNLPLapackCPU,max_iter=100000))
model = Model(Ipopt.Optimizer)
#model = Model(() -> AmplNLWriter.Optimizer(Couenne_jll.amplexe))
#model = Model(SCIP.Optimizer)
#set_optimizer_attribute(model, "linear_solver", "pardiso")
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

npoints=size(RTm,1)

#f(x::T, y::T) where {T<:Real} = -(-x-0+((-x+0)^2+10^-100)^(1.0/2))/2.0
f(x::T) where {T<:Real} = -(-x+((-x)^2+10^-10)^(1.0/2))/2.0
# function ∇f(g::AbstractVector{T}, x::T, y::T) where {T<:Real}
#     g[1] = 1/2 - (2*x - 2*y)/(4*((x - y)^2 + 1/10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)^(1/2))
#     g[2] = (2*x - 2*y)/(4*((x - y)^2 + 1/10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)^(1/2)) + 1/2
#     return
# end
register(model, :min_, 1, f, autodiff=true) #∇f)

mmu=1 ./minimum(RTm,dims=1)

#mmu=[1/0.3019,1/0.1053,1/0.1546]

@variable(model,T[i=1:size(jump,1),j=1:npoints]>=0)
@variable(model,RTlqn[i=1:size(jump,2),p=1:npoints]>=0) #cerco di far conservare anche il response time Steady, state
@variable(model,MU[i=1:size(jump,2)]>=0)
#MU=[1/0.3019,1/0.1053,1/0.1546]
@variable(model,X[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,P[i=1:size(jump,2),j=1:size(jump,2)]>=0)
@variable(model,P2[i=1:size(jump,2),j=1:size(jump,2)]>=0)
@variable(model,E_abs[i=1:(size(jump,2)),j=1:npoints]>=0)
#@variable(model,E_abs2[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,ERT_abs[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,RTs[i=1:size(jump,2),j=1:npoints]>=0)

@constraint(model,sum(P,dims=2).==1)
@constraint(model,P2.<=1)
@constraint(model,P.<=1)
@constraint(model,[i=1:size(P2,1)],P2[i,i]==0)
@constraint(model,[p=1:npoints],X[:,p].<=(RTm[p,:].*Tm[p,:]))
#@constraint(model,[i=1:size(P2,1)],P[i,i]==0)
#@constraint(model,P[1,1]==0)
#@constraint(model,MU[1]==1/0.3)

#@constraint(model,MU.==[1/0.3019,1/0.1053,1/0.1546])

for idx=1:size(MU,1)
        set_start_value(MU[idx],mmu[idx])
        #@constraint(model,MU[idx]>=mmu[idx])
end

Xu=RTm.*Tm;

for p=1:npoints

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

# @constraint(model,[k=1:size(E_abs2,1)],E_abs2[k,p]>=(jump'*T[:,p])[k])
# @constraint(model,[k=1:size(E_abs2,1)],E_abs2[k,p]>=-(jump'*T[:,p])[k])

@constraint(model,jump'*T[:,p].==0)

@NLconstraint(model,sum(T[i,p] for i in [1,2,3])*RTs[1,p]==X[1,p])
@NLconstraint(model,sum(T[i,p] for i in [4,5,6])*RTs[2,p]==X[2,p])
@NLconstraint(model,sum(T[i,p] for i in [7,8,9])*RTs[3,p]==X[3,p])
end

obj=[]
for p=1:npoints
        @constraint(model,sum(X[:,p])==Cli[p])
        @constraints(model,begin
                E_abs[1,p]>=(Tm[p,1]-sum(T[[1,2,3],p]))
                E_abs[1,p]>=-(Tm[p,1]-sum(T[[1,2,3],p]))

                E_abs[2,p]>=(Tm[p,2]-sum(T[[4,5,6],p]))
                E_abs[2,p]>=-(Tm[p,2]-sum(T[[4,5,6],p]))

                E_abs[3,p]>=(Tm[p,3]-sum(T[[7,8,9],p]))
                E_abs[3,p]>=-(Tm[p,3]-sum(T[[7,8,9],p]))
        end)

        for i=1:size(jump,2)
            @NLconstraint(model,RTlqn[i,p]==sum(P[i,j]*P2[i,j]*RTlqn[j,p] for j=1:size(jump,2))+RTs[i,p])
            #@constraint(model,RTlqn[i,p]==sum(P2[i,j]*RTm[p,j] for j=1:size(jump,2))+RTs[i,p])
            @constraint(model,ERT_abs[i,p]>=(RTlqn[i,p]-RTm[p,i]))
            @constraint(model,ERT_abs[i,p]>=(-RTlqn[i,p]+RTm[p,i]))
        end
end


#@objective(model,Min, sum(E_abs2[i,p] for i=1:size(E_abs2,1) for p=1:size(E_abs2,2))+sum(E_abs[i,p] for i=1:size(E_abs,1) for p=1:size(E_abs,2))+sum(ERT_abs[i,p] for i=1:size(ERT_abs,1) for p=1:size(E_abs,2)))
@objective(model,Min, sum(E_abs[i,p] for i=1:size(E_abs,1) for p=1:size(E_abs,2))+sum(ERT_abs[i,p] for i=1:size(ERT_abs,1) for p=1:size(E_abs,2)))
#@objective(model,Min, ETmax+ERTmax)
JuMP.optimize!(model)

matwrite("fromJulia.mat", Dict(
               "RTlqn" => value.(RTlqn),
               "T" => value.(T),
               "MU" => value.(MU),
               "P" => value.(P),
               "P2" => value.(P.*P2),
               "NCopt" => value.(NC)
       );)

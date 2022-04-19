using Printf,Ipopt,MadNLP,Plots,MadNLPMumps,JuMP,MAT,ProgressBars,ParameterJuMP,Statistics

DATA = matread("../execution/data/2tier.mat")

nzIdz=sum(DATA["RTm"],dims=2).!=0

Cli=zeros(sum(nzIdz),1)
Tm=zeros(sum(nzIdz),size(DATA["Tm"],2))
RTm=zeros(sum(nzIdz),size(DATA["RTm"],2))
#NC=zeros(sum(nzIdz),size(DATA["NC"],2))
NC=ones(sum(nzIdz),size(DATA["RTm"],2))*5

for i=1:sum(nzIdz)
        if(DATA["Cli"][i]!=0)
                global Cli[i]=DATA["Cli"][i]
                global Tm[i,:]=DATA["Tm"][i,:]
                global RTm[i,:]=DATA["RTm"][i,:]
                #global NC[i,:]=DATA["NC"][i,:]
        end
end


#model = Model(()->MadNLP.Optimizer(linear_solver=MadNLPMumps,max_iter=100000))
model = Model(Ipopt.Optimizer)
#set_optimizer_attribute(model, "linear_solver", "pardiso")
#set_optimizer_attribute(model, "max_iter", 20000)
#set_optimizer_attribute(model, "tol", 10^-10)
#set_optimizer_attribute(model, "print_level", 0)

#      X0_E,X1_E
jump=[ -1   +1;
       +0   +0;
       +1   -1;
       +0   +0;
       ]

npoints=size(RTm,1)

#f(x::T, y::T) where {T<:Real} = -(-x-0+((-x+0)^2+10^-100)^(1.0/2))/2.0
f(x::T) where {T<:Real} = -(-x+((-x)^2+10^-100)^(1.0/2))/2.0
# function ∇f(g::AbstractVector{T}, x::T, y::T) where {T<:Real}
#     g[1] = 1/2 - (2*x - 2*y)/(4*((x - y)^2 + 1/10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)^(1/2))
#     g[2] = (2*x - 2*y)/(4*((x - y)^2 + 1/10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000)^(1/2)) + 1/2
#     return
# end
register(model, :min_, 1, f, autodiff=true) #∇f)

 mmu=1 ./minimum(RTm,dims=1)

@variable(model,T[i=1:size(jump,1),j=1:npoints]>=0,start=0)
@variable(model,RTlqn[i=1:size(jump,2),p=1:npoints]>=0,start = 0) #cerco di far conservare anche il response time Steady, state
@variable(model,MU[i=1:size(jump,2)]>=0)
@variable(model,X[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,P[i=1:size(jump,2),j=1:size(jump,2)]>=0)
@variable(model,P2[i=1:size(jump,2),j=1:size(jump,2)]>=0)
@variable(model,E_abs[i=1:(size(jump,2)),j=1:npoints]>=0)
@variable(model,E_abs2[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,ERT_abs[i=1:size(jump,2),j=1:npoints]>=0)
@variable(model,RTs[i=1:size(jump,2),j=1:npoints]>=0)

@constraint(model,sum(P,dims=2).==1)
@constraint(model,P2.<=1)
@constraint(model,P.<=1)
@constraint(model,[i=1:size(P2,1)],P2[i,i]==0)
# @constraint(model,P[1,1]==0)
# @constraint(model,MU[1]==1)

for idx=1:size(MU,1)
        set_start_value(MU[idx],mmu[idx])
        @constraint(model,MU[idx]>=mmu[idx])
end

Xu=RTm.*Tm;

for p=1:npoints

exp=@NLexpression(model,(1.0/(X[2,p]))*(min_((X[2,p])-NC[p,2])+NC[p,2]))

@NLconstraint(model,T[1,p]==P[1,2]*MU[1]*X[1,p])
@NLconstraint(model,T[2,p]==P[1,1]*MU[1]*X[1,p])

@NLconstraint(model,T[3,p]==X[2,p]*P[2,1]*MU[2]*exp)
@NLconstraint(model,T[4,p]==X[2,p]*P[2,2]*MU[2]*exp)

#@constraint(model,[k=1:size(E_abs2,1)],E_abs2[k,p]>=(jump'*T[:,p])[k])
#@constraint(model,[k=1:size(E_abs2,1)],E_abs2[k,p]>=-(jump'*T[:,p])[k])

@constraint(model,jump'*T[:,p].==0)

@NLconstraint(model,sum(T[i,p] for i in [1,2])*RTs[1,p]==X[1,p])
@NLconstraint(model,sum(T[i,p] for i in [3,4])*RTs[2,p]==X[2,p])
end

obj=[]
for p=1:npoints
        @constraint(model,sum(X[:,p])==Cli[p])
        @constraints(model,begin
                E_abs[1,p]>=(Tm[p,1]-sum(T[[1,2],p]))/Tm[p,1]
                E_abs[1,p]>=-(Tm[p,1]-sum(T[[1,2],p]))/Tm[p,1]
                E_abs[2,p]>=(Tm[p,2]-sum(T[[3,4],p]))/Tm[p,2]
                E_abs[2,p]>=-(Tm[p,2]-sum(T[[3,4],p]))/Tm[p,2]
        end)

        for i=1:size(jump,2)
            @NLconstraint(model,RTlqn[i,p]==sum(P[i,j]*P2[i,j]*RTlqn[j,p] for j=1:size(jump,2))+RTs[i,p])
            #@constraint(model,RTlqn[i,p]==sum(P2[i,j]*RTm[p,j] for j=1:size(jump,2))+RTs[i,p])
            @constraint(model,ERT_abs[i,p]>=(RTlqn[i,p]-RTm[p,i])/RTm[p,i])
            @constraint(model,ERT_abs[i,p]>=(-RTlqn[i,p]+RTm[p,i])/RTm[p,i])
        end
end


#@objective(model,Min, 0.1*(sum(MU)+sum(P)+sum(P2))+sum(E_abs2[i,p] for i=1:size(E_abs2,1) for p=1:size(E_abs2,2))+sum(E_abs[i,p] for i=1:size(E_abs,1) for p=1:size(E_abs,2))+sum(ERT_abs[i,p] for i=1:size(ERT_abs,1) for p=1:size(E_abs,2)))
@objective(model,Min, sum(E_abs[i,p] for i=1:size(E_abs,1) for p=1:size(E_abs,2))+sum(ERT_abs[i,p] for i=1:size(ERT_abs,1) for p=1:size(E_abs,2)))
JuMP.optimize!(model)
function [RT]=solveRT(P,RTL)

RTlqn = optimvar('RTlqn',[size(P,1),1],'LowerBound',0);
E_abs = optimvar('E_abs',[size(P,1),1],'LowerBound',0);

prob = optimproblem('Objective',sum(E_abs),'ObjectiveSense','min');

i=1;
cstr=[];
while(i<=size(P,1))
    cstr=[cstr;E_abs(i)>=P(i,:)*RTlqn+RTL(i)-RTlqn(i);E_abs(i)>=-(P(i,:)*RTlqn+RTL(i)-RTlqn(i));];
    i=i+1;
end
prob.Constraints=cstr;

problem = prob2struct(prob);
[sol,fval,exitflag,output] = linprog(problem);
RT=sol(end-size(P,1)+1:end);
end
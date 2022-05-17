function [Kpi]=lineQN(X0,Pn,MU,NC)
model = Network("eQN");

delay = Delay(model,'WorloadGen');
cclass = ClosedClass(model, 'Users', sum(X0), delay);
delay.setService(cclass,  Exp(MU(1)));

for i=2:size(Pn,1)
    queue = Queue(model, sprintf("X%s",i), SchedStrategy.FCFS);
    queue.setNumberOfServers(NC(i));
    queue.setService(cclass, Exp(MU(i)));
end

%% Block 3: topology
P = model.initRoutingMatrix;
P{cclass} = Pn;
model.link(P);
%% Block 4: solution
%solver = SolverFluid(model,'stiff',true,'iter_tol',10^-8);
%solver = SolverMVA(model);
solver = SolverCTMC(model,'force',true);
%solver = SolverSSA(model,'samples',1e5);
%ctmcAvgTable = solver.getAvgTable();

% QN(i,r): mean queue-length of class r at station i
QN = solver.getAvgQLen();
% UN(i,r): utilization of class r at station i
UN = solver.getAvgUtil();
% RN(i,r): mean response time of class r at station i (summed on visits)
RN = solver.getAvgRespT();
% TN(i,r): mean throughput of class r at station i
TN = solver.getAvgTput();
Kpi=[QN';RN';UN';TN'];
end
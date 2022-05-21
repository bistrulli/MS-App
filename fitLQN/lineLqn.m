clear
RTm=[];
Tm=[];
NC=[];
Cli=1:5:300;
Cli=Cli';
for i=1:size(Cli,1)
    
    model = LayeredNetwork('myLayeredModel');
    
    NC=[NC;inf,randi([10,10],1,2)];
    
    P1 = Processor(model, 'P1', Inf, SchedStrategy.INF);
    P2 = Processor(model, 'P2', 10, SchedStrategy.PS);
    P3 = Processor(model, 'P3', 20, SchedStrategy.PS);
    
    T1 = Task(model, 'T1', Cli(i), SchedStrategy.REF).on(P1);
    T2 = Task(model, 'T2', Inf, SchedStrategy.INF).on(P2);
    T3 = Task(model, 'T3', Inf, SchedStrategy.INF).on(P3);
    
    E1 = Entry(model, 'E1').on(T1);
    E2 = Entry(model, 'E2').on(T2);
    E3 = Entry(model, 'E3').on(T3);
    
    A1 = Activity(model, 'A1', Exp(1.0)).on(T1).boundTo(E1).synchCall(E2);
    A2 = Activity(model, 'A2', Exp(10.0)).on(T2).boundTo(E2).asynchCall(E3).repliesTo(E2);
    A3 = Activity(model, 'A3', Exp(1.0)).on(T3).boundTo(E3).repliesTo(E3);
    
    AvgTable = SolverLN(model).getAvgTable;
    RTm=[RTm;AvgTable.RespT(end-2:end)';];
    Tm=[Tm;AvgTable.Tput(end-2:end)';];
end

save("../execution/data/sim/linedata.mat",'Cli','RTm','Tm','NC');
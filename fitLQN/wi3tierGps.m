clear
load("/Users/emilio/git/MS-App/execution/data/3tier_learng.mat");

CIdx=sum(sum(RTm,2)~=0);

P=[ 6.61457e-9  0.999999     7.34674e-7
 0.0270748   5.76002e-8   0.972925
 0.973028    0.000372083  0.0265998];
P2=[ 0.0          0.999999    7.34263e-7
 5.26591e-10  0.0         0.972091
 0.00936461   0.00037208  0.0];
MU=[ 3.472900121820211
 6.524581143266308
 6.521401511962102];

NT=[inf,inf,inf];

N=size(P,2);

RTl=zeros(CIdx,size(P,2));
Tl=zeros(CIdx,size(P,2));

TF=2000;

B=[];

%dimensione di un batch
K = 30;
%numrto di batch
N = 30;
dt=1;



for i=1:CIdx
    
    X0=[Cli(i),0,0];        
    [X,Ts]=bmSim(X0,P,MU,NT,NC(i,:)+1,K,N);
    
    Tl(i,:)=Ts';
    
    RTs=[X(1)/Ts(1);
        X(2)/Ts(2);
        X(3)/Ts(3);];
    
    RTl(i,:)=solveRT(P2,RTs);
end

figure
boxplot(abs(RTl-RTm(1:CIdx,:))*100./RTm(1:CIdx,:))
ylabel("AbsoluteError (s)")
title("Response time absolute prediction error (what-if)")

figure
boxplot(abs(Tl-Tm(1:CIdx,:))*100./Tm(1:CIdx,:))
title("Throughput absolute prediction error (what-if)")
ylabel("AbsoluteError (Req/s)")
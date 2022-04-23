clear
load("/Users/emilio/git/MS-App/execution/data/3tier_learn2.mat");

CIdx=sum(sum(RTm,2)~=0);

P=[ 9.04557e-8  0.951064   0.0489357
 0.0331115   0.017613   0.949275
 0.966747    0.0332524  6.05006e-7];
P2=[ 0.0          0.951064    0.0489357
 3.52352e-10  0.0         0.949275
 0.0423485    2.85163e-9  0.0];
MU=[ 3.0372419624655307
 9.544327902425517
 6.691552805666332];

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
    %[t,y,Ts]=flatOde(X0,P,MU,NT,NC(i,:));
    [X,Ts]=bmSim(X0,P,MU,NT,NC(i,:),K,N);
    
    Tl(i,:)=Ts';
    
    RTs=[X(1)/Ts(1);
        X(2)/Ts(2);
        X(3)/Ts(3);];
    
%     RTs=[y(end,1)/Ts(1);
%          y(end,2)/Ts(2);
%          y(end,3)/Ts(3);];
    
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
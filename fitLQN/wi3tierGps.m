clear
load("../ras_app/ras_teastore_server/three_tier_wi.mat");

P=[   1.29988e-7  0.956474    0.043526
 0.0864486   9.23966e-8  0.913551
 0.915469    0.0414284   0.0431022

    ];

P2=[       0.0         0.956474   0.043526
 0.00763097  0.0        0.912952
 0.0         0.0414284  0.0
];

MU=[       0.9757325889083525
  9.59726615366555
 15.8169040038149];

%MU=[0.9896,9.3652,15.5539];

NT=[inf,inf];

N=size(P,2);

RTl=zeros(size(Cli,1),size(P,2));
Tl=zeros(size(Cli,1),size(P,2));

TF=2000;

B=[];

%dimensione di un batch
K = 30;
%numrto di batch
N = 30;
dt=1;



for i=4:4
    
    X0=[Cli(i),0,0];        
    [X,Ts]=bmSim(X0,P,MU,NT,NC(i,:),K,N);
    
    Tl(i,:)=Ts';
    
    RTs=[X(1)/Ts(1);
        X(2)/Ts(2);
        X(3)/Ts(3);];
    
    RTl(i,:)=solveRT(P2,RTs);
end

figure
boxplot(abs(RTl-RTm)*100./RTm)
ylabel("AbsoluteError (s)")
title("Response time absolute prediction error (what-if)")

figure
boxplot(abs(Tl-Tm)*100./Tm)
title("Throughput absolute prediction error (what-if)")
ylabel("AbsoluteError (Req/s)")
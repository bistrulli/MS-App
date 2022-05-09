% Idx=NC(:,2)==4;
% 
% figure
% hold on
% stem(sort(RTm(Idx,2)))
% stem(sort(RTl(Idx,2)))
% legend(["RTClient_m","RTClient_p"])
% 
% figure
% hold on
% stem(sort(Tm(Idx,2)))
% stem(sort(Tl(Idx,2)))
% legend(["TClient_m","TClient_p"])

load("/Users/emilio/git/MS-App/execution/data/3tier_learn4.mat");

CIdx=sum(sum(RTm,2)~=0);
%CIdx=15;
% 
% P=[0.00217905  0.997821
%  0.996344    0.00365643];
% P2=[0.0         0.99774
%  0.00253123  0.0];
% MU=[3.2865425244638855,9.781509324351875];

P=[ 4.88501e-8  0.928243    0.0717573
 0.0186855   3.89306e-8  0.981314
 0.877249    0.0641379   0.0586135];

P2=[  0.0        0.928243    0.0717573
 0.0186855  0.0         0.981314
 0.044992   1.40844e-9  0.0
];

MU=[  2.7796137475543343
 9.879407146694485
 6.630899843879367];


RTl=zeros(CIdx,size(RTm,2));
Tl=zeros(CIdx,size(RTm,2));
for i=1:CIdx
    %Kpi=lineQN([Cli(i)],[0,1;1,0],1./[0.9977,0.10316562661911506],[inf,5]);
    Kpi=lineQN([Cli(i)],P,MU,NC(i,:));
    
%   RTl(i,:)=Kpi(2,:);
%     RTl(i,1)=sum(RTl(i,:));
    RTl(i,:)=solveRT(P2,Kpi(2,:));
    
    Tl(i,:)=Kpi(4,:);
end

figure
hold on
box on
grid on
plot(Cli(1:CIdx),RTm(1:CIdx,:),"linewidth",1.1)
plot(Cli(1:CIdx),RTl(:,:),"-.","linewidth",1.3)
% plot(Cli(1:CIdx),RTlqn(:,1:CIdx)',"--","linewidth",1.3)
legend(["RT_m","RT_p"])

figure
hold on
box on
grid on
plot(Cli(1:CIdx),Tm(1:CIdx,:),"linewidth",1.1)
plot(Cli(1:CIdx),Tl(:,:),"-.","linewidth",1.3)
% plot(Cli(1:CIdx),sum(T([1,2,3],1:CIdx)),"--","linewidth",1.3)
legend(["T_m","T_p"])

figure
boxplot(abs(RTm(1:CIdx,:)-RTl)*100./RTm(1:CIdx,:))
title("Relative Prediction Error (Response Time)")
box on
grid on

figure
boxplot(abs(Tm(1:CIdx,:)-Tl)*100./Tm(1:CIdx,:))
%boxplot(abs(Tm(1:CIdx,1)-sum(T([1,2,3],:))')*100./Tm(1:CIdx,:))
title("Relative Prediction Error (Throughput)")
box on
grid on


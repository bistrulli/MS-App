clear

wi=load("../ras_app/ras_teastore_server/three_tier2.mat");

E1=[];
E2=[];

PL=[  1.0         4.4801e-9  8.293e-9
 4.52032e-9  1.0        8.53067e-9
 8.27281e-9  8.558e-9   1.0];

PL2=[   0.0       0.503419     1.0
 0.039672  1.31904e-33  0.673943
 0.0       0.09801      0.0];

MUL=[   0.9528925646665004
  9.044897279752158
 16.86249666583258];

%for i=1:size(wi.Cli,1)
for i=1:size(wi.Cli,1)
    NC=wi.NC(i,:);
   
    X0=zeros(1,size(wi.NC,2));
    X0(1)=wi.Cli(i);
    Kpi=lineQN(X0,PL,MUL,NC);
    
    
    RT_t=wi.RTm(i,:);
    RT_l=solveRT(PL2,Kpi(2,:))';
    
    %     E1=[E1,abs(X_t-X_l)*100./X_t];
    E2=[E2,abs(RT_t-RT_l)];
    disp(abs(RT_t-RT_l))
end

% figure
% boxplot(E1)
% box on
% grid on
% title("Relative Error of Queue Lengths")
% ylabel("Relative Error(%)")
figure
boxplot(E2)
box on
grid on
ylabel("Relative Error(%)")
title("Relative Error of Rsponse Time")
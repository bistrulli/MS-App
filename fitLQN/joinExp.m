clear

e1=load("/Users/emilio/git/MS-App/execution/data/3tier_learn.mat");
e2=load("/Users/emilio/git/MS-App/execution/data/3tier_learn2.mat");


Cli=cat(2,e1.Cli([1:end]),e2.Cli(1:end));
RTm=cat(1,e1.RTm([1:end],:),e2.RTm([1:end],:));
Tm=cat(1,e1.Tm([1:end],:),e2.Tm([1:end],:));
NC=cat(1,e1.NC([1:end],:),e2.NC([1:end],:));


clear e1 e2

save("/Users/emilio/git/MS-App/execution/data/3tier_all.mat")
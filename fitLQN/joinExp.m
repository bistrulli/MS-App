clear

e1=load("/Users/emilio/git/MS-App/execution/data/3tier_learnHDVCALL2.mat");
e2=load("/Users/emilio/git/MS-App/execution/data/3tier_learnHDVCWI.mat");

e1CIdx=sum(sum(e1.RTm,2)~=0);
e2CIdx=sum(sum(e2.RTm,2)~=0);



Cli=cat(2,e1.Cli([1:e1CIdx]),e2.Cli(1:e2CIdx));
RTm=cat(1,e1.RTm([1:e1CIdx],:),e2.RTm([1:e2CIdx],:));
Tm=cat(1,e1.Tm([1:e1CIdx],:),e2.Tm([1:e2CIdx],:));
NC=cat(1,e1.NC([1:e1CIdx],:),e2.NC([1:e2CIdx],:));


clear e1 e2

save("/Users/emilio/git/MS-App/execution/data/3tier_learnHDVCALL3.mat")
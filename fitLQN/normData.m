clear
load("/Users/emilio/git/MS-App/execution/data/3tier_learnHDVCALL2.mat");

Tm_N=(Tm-mean(Tm))./std(Tm);
RTm_N=(RTm-mean(RTm))./std(RTm);
Cli_N=(Cli-mean(double(Cli)))./std(double(Cli));
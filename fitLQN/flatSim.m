function [t,X,Ts] = flatSim(X0,P,MU,NT,NC,TF,rep,dt)
import Gillespie.*
% Make sure vector components are doubles
X0 = double(X0);
MU = double(MU);
P = double(P);

% Make sure all vectors are row vectors
if(iscolumn(X0))
    X0 = X0';
end
if(iscolumn(MU))
    MU = MU';
end
if(iscolumn(NT))
    NT = NT';
end
if(iscolumn(NT))
    NC = NC';
end

X0=cat(2,X0,zeros(1,size(MU,2)));

p.MU = MU;
p.NT = NT;
p.NC = NC;
p.P = P;
p.delta = inf; % context switch rate (super fast)

jump=[ -1   +1   +0   +1   +0   +0;
       -1   +0   +1   +1   +0   +0;
       +0   +0   +0   +1   +0   +0;
       +1   -1   +0   +0   +1   +0;
       +0   -1   +1   +0   +1   +0;
       +0   +0   +0   +0   +1   +0;
       +1   +0   -1   +0   +0   +1;
       +0   +1   -1   +0   +0   +1;
       +0   +0   +0   +0   +0   +1;
       ];

tspan = [0, TF];
pfun = @propensities_2state;
 
X = zeros(length(X0), ceil(TF/dt) + 1, rep);
for i = 1:rep
    [t, x] = directMethod(jump, pfun, tspan, X0, p);
    tsin = timeseries(x,t);
    tsout = resample(tsin, linspace(0, TF, ceil(TF/dt)+1), 'zoh');
    X(:, :, i) = tsout.Data';
end

Ts=X(size(MU,2)+1:end,:);
Ts=Ts';

X=X(1:size(MU,2),:)';
end

% Propensity rate vector (CTMC)
function Rate = propensities_2state(X, p)
Rate = [p.P(1,2)*p.MU(1)*X(1);
        p.P(1,3)*p.MU(1)*X(1);
        p.P(1,1)*p.MU(1)*X(1);
        
        (X(2)/sum(X([2])))*p.P(2,1)*p.MU(2)*min(sum(X([2])),p.NC(2));
        (X(2)/sum(X([2])))*p.P(2,3)*p.MU(2)*min(sum(X([2])),p.NC(2));
        (X(2)/sum(X([2])))*p.P(2,2)*p.MU(2)*min(sum(X([2])),p.NC(2));
        
        (X(3)/sum(X([3])))*p.P(3,1)*p.MU(3)*min(sum(X([3])),p.NC(3));
        (X(3)/sum(X([3])))*p.P(3,2)*p.MU(3)*min(sum(X([3])),p.NC(3));
        (X(3)/sum(X([3])))*p.P(3,3)*p.MU(3)*min(sum(X([3])),p.NC(3));
    ];
Rate(isnan(Rate))=0;
end

function [t,y,Ts] = flatOde(X0,P,MU,NT,NC)
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
disp(X0)

p.MU = MU;
p.NT = NT;
p.NC = NC;
p.P = P;
p.delta = 10^5; % context switch rate (super fast)

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

T = @(X)propensities_2state(X,p);

opts = odeset('Events',@(t,y)eventfun(t,y,jump,T));
[t,y]=ode23t(@(t,y) jump'*T(y),[0,Inf], X0,opts);

Ts=y(end, size(MU,2)+1:end)/(t(end)-t(1));

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

function [x,isterm,dir] = eventfun(t,y,jump,T)    
    dy = jump'*T(y);
    %x = norm(dy) - 1e-5;
    x=max(abs(dy)) - 1e-5;
    isterm = 1;
    dir = 0;
end

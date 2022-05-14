function [RT]=solveRT2(P,RTL)
    RT=linsolve((eye(size(P))-P),RTL);
end
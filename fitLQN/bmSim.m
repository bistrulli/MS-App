function [X,Ts]=bmSim(X0,P,MU,NT,NC,K,N)
B=[];
Bx=[];
E=-1;
Ex=-1;
dt=1;

while(sum(E)<0 || sum(Ex)<0 || max(E)>0.001 || max(Ex)>0.001)
    [t,y,Ts]=flatSim(X0,P,MU,NT,NC,K * (N + 1) * dt,1,dt);
    Ts=diff(Ts)/dt;
    X0=y(end,:);
    
    Bi=[];
    for cmp=1:size(Ts,2)
        cmpT=[];
        for n=2:(N + 1)
            if(n==1)
                cmpT=[cmpT;Ts(1:(K*n),cmp)'];
            else
                cmpT=[cmpT;Ts((K * (n-1))+1:(K*n),cmp)'];
            end
        end
        Bi=cat(3,Bi,cmpT);
        %B[cmp] = np.vstack((B[cmp], [X[cmp, K * n:K * (n + 1)] for n in range(N + 1)])
    end
    B=cat(1,B,Bi);
    Bm2 = mean(B,2);
    
    CI=[];
    for cmp=1:size(Bm2,3)
        SEM = std(Bm2(:,:,cmp))/size(Bm2,1);               % Standard Error
        ts = tinv([0.025  0.975],size(Bm2,1)-1);      % T-Score
        CI = [CI;mean(Bm2(:,:,cmp)) + ts*SEM];
    end
    
    E=abs(CI(:,end)-reshape(mean(Bm2,1),[3,1]));
    Ts=reshape(mean(Bm2,1),[3,1]);
    
    %%batchmeans queuelength
    Bi=[];
    for cmp=1:size(y,2)
        cmpT=[];
        for n=2:(N + 1)
            if(n==1)
                cmpT=[cmpT;y(1:(K*n),cmp)'];
            else
                cmpT=[cmpT;y((K * (n-1))+1:(K*n),cmp)'];
            end
        end
        Bi=cat(3,Bi,cmpT);
        %B[cmp] = np.vstack((B[cmp], [X[cmp, K * n:K * (n + 1)] for n in range(N + 1)])
    end
    Bx=cat(1,Bx,Bi);
    Bm2 = mean(Bx,2);
    
    CI=[];
    for cmp=1:size(Bm2,3)
        SEM = std(Bm2(:,:,cmp))/size(Bm2,1);               % Standard Error
        ts = tinv([0.025  0.975],size(Bm2,1)-1);      % T-Score
        CI = [CI;mean(Bm2(:,:,cmp)) + ts*SEM];
    end
    
    Ex=abs(CI(:,end)-reshape(mean(Bm2,1),[3,1]));
    X=reshape(mean(Bm2,1),[3,1]);
    disp("1")
    disp(max(Ex))
    disp("2")
    disp(max(E))
end
end
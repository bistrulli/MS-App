clear
N=1000000;

X1=unifrnd(0,10,[N,1]);
X2=unifrnd(0,10,[N,1]);

a1=min(X1);
b1=max(X1);

a2=min(X2);
b2=max(X2);


Y=mean(min(X1,X2));
Y1=min(mean(X1),mean(X2));

Y2=(b1+2*a1)/3;
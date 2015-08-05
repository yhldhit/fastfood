rng(1);
warning('off','all');
try
    matlabpool open;
    use_parallel = true;
catch
    display('Can not open matlab pool.');
    use_parallel = false;
end
options = statset('UseParallel',use_parallel);

ntimes = 10;
frac_nonzero = 0.1;

n_values = [1000,10000];%,100000];
d_values = [150,300];%,600,1000,10000];
accuracy_data = {};

y_func = @(X,r) (X*r + randn(size(X,1),1)*.1); % linear function

for k = 1:length(n_values)
    n = n_values(k);
    for z = 1:length(d_values)
        d = d_values(z);
        fprintf('iter n = %d, d = %d\n',n,d);
        
        acclasso = [];
        accsven = [];
        accffen = [];
        for i = 1:ntimes
            X = randn(n,d);
            r = zeros(size(X,2),1);
            inxs = randperm(d);
            num_nonzero = round(frac_nonzero*d);
            ugly = [-1,1];
            s = [];
            for j = 1:num_nonzero
                ugly_inxs = randperm(2);
                s(j) = ugly(ugly_inxs(1));
            end
            r(inxs(1:num_nonzero)) = s.*(3 + 2*rand(1,num_nonzero));
            y = y_func(X,r);
            X = zscore(X); % mean center and unit variance
            
            %% (Hyper-)params
            lambda2 = 0.1;
            alpha = 0.5;
            t = lambda2*alpha;
            N = d*20; % number of basis functions to use for approximation
            para = FastfoodPara(N,d); % generate FF parameters
            cp = cvpartition(n,'kfold',5); % create the 5-fold partitions
            
            %% Built-in lasso
            acclasso(i) = crossval('mse',X,y,'partition',cp,...
                'Predfun',@(xtrain,ytrain,xtest) cv_lasso(xtrain,ytrain,xtest,alpha,lambda2,options)); % perform CV to get a MSE
            fprintf('acclasso = %f, ',acclasso);
            
            %% SVEN
            accsven(i) = crossval('mse',X,y,'partition',cp,...
                'Predfun',@(xtrain,ytrain,xtest) cv_sven(xtrain,ytrain,xtest,t,lambda2,options)); % perform CV to get a MSE
            fprintf('accsven = %f, ',accsven);
            
            %% FFEN
            accffen(i) = crossval('mse',X,y,'partition',cp,...
                'Predfun',@(xtrain,ytrain,xtest) cv_ffen(xtrain,ytrain,xtest,alpha,lambda2,options)); % perform CV to get a MSE
            fprintf('accffen = %f\n',accffen);
        end
        
        accuracy_data{k,z} = {};
        accuracy_data{k,z}.acclasso = acclasso;
        accuracy_data{k,z}.accsven = accsven;
        accuracy_data{k,z}.accffen = accffen;
    end
end

for k = 1:length(n_values)
    n = n_values(k);
    for z = 1:length(d_values)
        d = d_values(z);
        acclasso = accuracy_data{k,z}.acclasso;
        accsven = accuracy_data{k,z}.accsven;
        accffen = accuracy_data{k,z}.accffen;
        fprintf('ntimes = %d, frac_nonzero = %f, n = %d, d = %d\n',ntimes,frac_nonzero,n,d);
        fprintf('acclasso: %f, %f\n',mean(acclasso),std(acclasso));
        fprintf('accsven: %f, %f\n',mean(accsven),std(accsven));
        fprintf('accffen: %f, %f\n',mean(accffen),std(accffen));
    end
end
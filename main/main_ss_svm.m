% MAIN ANALYSIS SCRIPT

% reset random generator
rng(1000);

%% set path
addpath(genpath('/home/sh3276/work/code/hydra_behavior'));
addpath(genpath('/home/sh3276/software/inria_fisher_v1/yael_v371/matlab'));
addpath(genpath('/home/sh3276/work/code/other_sources/'))

%% setup parameters
% use availabel seg and dt data
srcstr = '20161019';
parampath = '/home/sh3276/work/results/param/';
load([parampath 'expt_param_' srcstr '.mat']);

% file information
param.fileIndx = [8,17,18,19,20,24];
param.trainIndx = [8,17,18,19,20];
param.testIndx = 24;

param.datastr = '20170223';
param.srcstr = srcstr;

param.dpathbase = '/home/sh3276/work/data';
param.pbase = '/home/sh3276/work/results';
param.dpath = sprintf('%s/bkg_subtracted/',param.dpathbase);
param.segpath = sprintf('%s/seg/%s/',param.pbase,param.srcstr);
param.segvidpath = sprintf('%s/segvid/%s/',param.pbase,param.srcstr);
param.dtpath = sprintf('%s/dt/%s/',param.pbase,param.srcstr);
param.dtmatpath = sprintf('%s/dt/%s/mat/',param.pbase,param.srcstr);
param.fvpath = sprintf('%s/fv/%s/',param.pbase,param.datastr);
param.svmpath = sprintf('%s/svm/%s/',param.pbase,param.datastr);
param.tsnepath = sprintf('%s/tsne/%s/',param.pbase,param.datastr);
param.annopath = sprintf('%s/annotations/',param.dpathbase);
param.parampath = sprintf('%s/param/',param.pbase);

param.dt.thresh = 0.5;

param.annotype = 13;
param.fr = 5;
param.timeStep = param.dt.tlen*param.fr;
param.infostr = sprintf('L_%u_W_%u_N_%u_s_%u_t_%u_step_%u',param.dt.L,...
    param.dt.W,param.dt.N,param.dt.s,param.dt.t,param.timeStep);

% FV parameters
param.fv.K = 128;
param.fv.ci = 70;
param.fv.intran = 0;
param.fv.powern = 1;
param.fv.featstr = {'hof','hog','mbhx','mbhy'};
param.fv.featlen = [9,8,8,8];
param.fv.numPatch = param.dt.s^2*param.dt.t;

% SVM parameters
param.svm.src = '/home/sh3276/software/libsvm';
param.svm.percTrain = 0.9;
param.svm.kernel = 2; % 0 linear, 1 polynomial, 2 rbf, 3 sigmoid
param.svm.probest = 1; % true
param.svm.name = [param.infostr '_drFVall_annoType' num2str(param.annotype)];


%% check if all directories exist
if exist(param.dpath,'dir')~=7
    error('Incorrect data path')
end
if exist(param.annopath,'dir')~=7
    error('Incorrect annotation path')
end
if exist(param.segpath,'dir')~=7
    error('Incorrect seg path')
end
if exist(param.dtpath,'dir')~=7
    error('Incorrect dt path')
end
if exist(param.dtmatpath,'dir')~=7
    error('Incorrect dtmat path')
end
if exist(param.fvpath,'dir')~=7
    fprintf('creating directory %s...\n',param.fvpath);
    mkdir(param.fvpath);
end
if exist(param.svmpath,'dir')~=7
    fprintf('creating directory %s...\n',param.svmpath);
    mkdir(param.svmpath);
end
if exist(param.tsnepath,'dir')~=7
    fprintf('creating directory %s...\n',param.tsnepath);
    mkdir(param.tsnepath);
end
if exist(param.parampath,'dir')~=7
    fprintf('creating directory %s...\n',param.parampath);
    mkdir(param.parampath);
end

% save parameters to file
dispStructNested(param,[],[param.parampath 'expt_param_' param.datastr '.txt']);
save([param.parampath 'expt_param_' param.datastr '.mat'],'param');


%% run Fisher Vector on features
% ---------- training FV ---------- %
for n = 1:length(param.fv.featstr)
    
    fprintf([param.fv.featstr{n} '...\n']);
    fvparam = param.fv;
    fvparam.featstr = param.fv.featstr{n};
    fvparam.namestr = [param.infostr '_' fvparam.featstr];
    fvparam.lfeat = param.fv.featlen(n);
    fprintf('%s...\n',fvparam.featstr);
    
    % fit GMM and encode FV
    eval(sprintf(['[coeff,w,mu,sigma,%sFV,eigval,acm] = encodeSpFV2(param.trainIndx,' ...
        'param.dtmatpath,fvparam);'],fvparam.featstr));

    % save results
    save([param.fvpath param.infostr '_' fvparam.featstr 'Coeff.mat'],'coeff','eigval','-v7.3'); 
    eval(sprintf(['save([param.fvpath param.infostr ''_'' fvparam.featstr ''FV.mat''],'...
        '''%sFV'',''-v7.3'');'],fvparam.featstr));
    save([param.fvpath param.infostr '_' fvparam.featstr 'GMM.mat'],'w','mu','sigma','-v7.3');
    
end

% put together data, do pca
FVall = [hofFV,hogFV,mbhxFV,mbhyFV]/4;
[drFVall,coeff] = drHist(FVall,param.fv.ci);
pcaDim = size(drFVall,2);
save([param.fvpath param.infostr '_FVall.mat'],'FVall','acm','-v7.3');
save([param.fvpath param.infostr '_drFVall.mat'],'drFVall','acm','-v7.3');
save([param.fvpath param.infostr '_pcaCoeff.mat'],'coeff','pcaDim','-v7.3');

% ---------- test FV ---------- %
for n = 1:length(param.testIndx)
    
    movieParam = paramAll(param.dpath,param.testIndx(n));
    fprintf('processing sample: %s\n', movieParam.fileName);
    
    for ii = 1:length(param.fv.featstr)
        fvparam = param.fv;
        fvparam.gmmpath = param.fvpath;
        fvparam.featstr = param.fv.featstr{ii};
        fvparam.namestr = [param.infostr '_' fvparam.featstr];
        fvparam.lfeat = param.fv.featlen(ii);
        fprintf('%s...\n',fvparam.featstr);
        eval(sprintf('%sFV = encodeIndivSpFV2(param.testIndx(n),param.dtmatpath,fvparam);',...
            fvparam.featstr));
    end
    
    % put together FV, do pca
    FVall = [hofFV,hogFV,mbhxFV,mbhyFV]/4;
    muData = mean(FVall,1);
    drFVall = bsxfun(@minus,FVall,muData)*coeff;
    drFVall = drFVall(:,1:pcaDim);
    save([param.fvpath movieParam.fileName '_' param.infostr '_FVall.mat'],'FVall','-v7.3');
    save([param.fvpath movieParam.fileName '_' param.infostr '_drFVall.mat'],'drFVall','-v7.3');
    
end

%% generate SVM samples
% training data
sample = load([param.fvpath param.infostr '_drFVall.mat']);
acm = sample.acm;
sample = sample.drFVall;
keep_dim = 5;

% load annotations
movieParamMulti = paramMulti(param.dpath,param.trainIndx);
for n = 1:length(param.trainIndx)
    movieParamMulti{n}.numImages = (acm(n+1)-acm(n))*param.timeStep;
end
annoAll = annoMulti(movieParamMulti,param.annopath,param.annotype,param.timeStep);

% write data
% param.svm.name = [param.infostr '_drFVall_annoType' num2str(param.annotype)];
% mkLibSVMsample(sample(:,1:keep_dim),param.svm.percTrain,annoAll,...
%     param.svm.name,param.svmpath);

% take equal number of two classes
ff = 3;
num_pos = sum(annoAll==1);
keep_indx = find(annoAll==2);
keep_indx = keep_indx(randperm(length(keep_indx),ff*num_pos));
keep_indx = [keep_indx;find(annoAll==1)];
mkLibSVMsample(sample(keep_indx,1:keep_dim),param.svm.percTrain,annoAll(keep_indx,:),...
    param.svm.name,param.svmpath);

% weights
% wei_str = [];
% [~,numClass] = annoInfo(param.annotype,1);
% w = zeros(numClass,1);
% labelset = unique(annoAll);
% for n = 1:numClass
%     w(n) = (length(annoAll)/sum(annoAll==labelset(n)))^2;
%     wei_str = [wei_str ' -w' num2str(labelset(n)) ' ' num2str(w(n))];
% end
% wei_str = wei_str(2:end);
wei_str = [' -w1 ' num2str(ff^2) ' -w2 1'];

% test sample
for n = 1:length(param.testIndx)
    
    movieParam = paramAll(param.dpath,param.testIndx(n));
    sample = load([param.fvpath movieParam.fileName '_' param.infostr '_drFVall.mat']);
    sample = sample.drFVall;
    annoAll = annoMulti({movieParam},param.annopath,param.annotype,param.timeStep);
    keepIndx = annoAll~=0;

    % write to libsvm format file
    gnLibsvmFile(annoAll(keepIndx),sample(keepIndx,1:keep_dim),[param.svmpath ...
        param.svm.name '_' movieParam.fileName '.txt']);

end

%% SVM
% train SVM
writeSVMscriptSS(param.svm,wei_str,param.svmpath,param.svm.name);
try 
    system(sprintf('chmod +x %srunSVM.sh',param.svmpath));
    status = system(sprintf('bash %srunSVM.sh',param.svmpath));
catch ME
    error('Error running libSVM');
end

% predict test samples
testnames = '';
for n = 1:length(param.testIndx)
    testnames = [testnames sprintf('"%s" ',fileinfo(param.testIndx(n)))];
end
testnames = testnames(1:end-1);
writeSVMTestScript(param.svm.src,param.svmpath,param.svmpath,param.svm.name,testnames);
try 
    status = system(sprintf('bash %ssvmClassifyIndv.sh',param.svmpath));
catch ME
    error('Error running svm classification');
end

% save prediction result to mat files
load([param.svmpath param.svm.name '_svm_data.mat']);
pred = struct();
pred_score = struct();
anno.train = label(indxTrain);
anno.test = label(indxTest);
[pred.train,pred_score.train,pred.train_soft] = saveSVMpred(param.svmpath,[param.svm.name '_train']);
[pred.test,pred_score.test,pred.test_soft] = saveSVMpred(param.svmpath,[param.svm.name '_test']);
for n = 1:length(param.testIndx)
    movieParam = paramAll(param.dpath,param.testIndx(n));
    annoAll = annoMulti({movieParam},param.annopath,param.annotype,param.timeStep);
    anno.new{n} = annoAll(annoAll~=0);
    [pred.new{n},pred_score.new{n},pred.new_soft{n}] = saveSVMpred(param.svmpath,...
        [param.svm.name '_' fileinfo(param.testIndx(n))]);
end

save([param.svmpath 'annotype' num2str(param.annotype) '_mat_results.mat'],...
    'pred','pred_score','anno','-v7.3');

%% SVM analysis
% confusion matrix and stats
load([param.svmpath 'annotype' num2str(param.annotype) '_mat_results.mat']);

numClass = max(anno.train);
svm_stats = struct();
cmat = struct();

[svm_stats.acr_all.train,svm_stats.prc.train,svm_stats.rec.train,...
    svm_stats.acr.train,cmat.train] = precisionrecall(pred.train,anno.train,numClass);
[svm_stats.acr_all.test,svm_stats.prc.test,svm_stats.rec.test,...
    svm_stats.acr.test,cmat.test] = precisionrecall(pred.test,anno.test,numClass);
for n = 1:length(param.testIndx)
    movieParam = paramAll(param.dpath,param.testIndx(n));
    annoAll = annoMulti({movieParam},param.annopath,param.annotype,param.timeStep);
    anno.new{n} = annoAll(annoAll~=0);
    [svm_stats.acr_all.new(n),svm_stats.prc.new{n},svm_stats.rec.new{n},...
        svm_stats.acr.new{n},cmat.new{n}] = precisionrecall(pred.new{n},anno.new{n},numClass);
end

[svm_stats.acr_all.new_all,svm_stats.prc.new_all,svm_stats.rec.new_all,...
    svm_stats.acr.new_all,cmat.new_all] = precisionrecall...
    (cell2mat(pred.new'),cell2mat(anno.new'),numClass);

% save results
save([param.svmpath 'annotype' num2str(param.annotype) '_stats.mat'],'svm_stats','cmat','-v7.3');

%% plot results
load(param.wbmap);
% wbmap = 'C:\Shuting\Projects\hydra behavior\results\wbmap.mat';
load(wbmap);

disp(svm_stats.acr_all);
fprintf('Precision:\n');
disp(table(svm_stats.prc.train,svm_stats.prc.test,svm_stats.prc.new_all,...
    'variablenames',{'train','test','new'}));
fprintf('Recall:\n');
disp(table(svm_stats.rec.train,svm_stats.rec.test,svm_stats.rec.new_all,...
    'variablenames',{'train','test','new'}));
fprintf('Accuracy:\n');
disp(table(svm_stats.acr.train,svm_stats.acr.test,svm_stats.acr.new_all,...
    'variablenames',{'train','test','new'}));

% plot confusion matrix
num_plts = max([length(pred.new),3]);
figure;set(gcf,'color','w','position',[2055 500 821 578])
subplot(2,num_plts,1)
plotcmat(cmat.train,wbmap);title('Train');colorbar off
gcapos = get(gca,'position');colorbar off; set(gca,'position',gcapos);
subplot(2,num_plts,2)
plotcmat(cmat.test,wbmap);title('Test');colorbar off
gcapos = get(gca,'position');colorbar off; set(gca,'position',gcapos);
subplot(2,num_plts,3)
plotcmat(cmat.new_all,wbmap);title('New');colorbar off
for n = 1:length(pred.new)
    subplot(2,num_plts,length(pred.new)+num_plts)
    plotcmat(cmat.new{n},wbmap);
    title(['New #' num2str(n)]);colorbar off
%     gcapos = get(gca,'position');colorbar off;set(gca,'position',gcapos)
end
% set(findall(gcf,'-property','FontSize'),'FontSize',9)

% ROC curve
figure;set(gcf,'color','w','position',[2079 168 792 236])
subplot(1,3,1)
auc.train = plotROCmultic(anno.train,pred_score.train,numClass);
legend('off')
subplot(1,3,2)
auc.test = plotROCmultic(anno.test,pred_score.test,numClass);
legend('off')
subplot(1,3,3)
auc.new = plotROCmultic(cell2mat(anno.new'),cell2mat(pred_score.new'),numClass);

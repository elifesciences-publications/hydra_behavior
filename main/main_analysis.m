% MAIN ANALYSIS SCRIPT

% reset random generator
rng(1000);

%% set path
addpath(genpath('/home/sh3276/work/code/hydra_behavior'));
addpath(genpath('/home/sh3276/software/inria_fisher_v1/yael_v371/matlab'));
addpath(genpath('/home/sh3276/software/MotionMapper/'));

%% setup parameters
param = struct();

% file information
param.fileIndx = [1:5,7:11,13:28,30:34];
param.trainIndx = [1:5,7:11,13:24,26:28,30:32];
param.testIndx = [25,33,34];

param.datastr = '20160912';

param.dpathbase = '/home/sh3276/work/data';
param.pbase = '/home/sh3276/work/results';
param.dpath = sprintf('%s/bkg_subtracted/',param.dpathbase);
param.segpath = sprintf('%s/seg/%s/',param.pbase,param.datastr);
param.segvidpath = sprintf('%s/segvid/%s/',param.pbase,param.datastr);
param.dtpath = sprintf('%s/dt/%s/',param.pbase,param.datastr);
param.dtmatpath = sprintf('%s/dt/%s/mat/',param.pbase,param.datastr);
param.fvpath = sprintf('%s/fv/%s/',param.pbase,param.datastr);
param.svmpath = sprintf('%s/svm/%s/',param.pbase,param.datastr);
param.tsnepath = sprintf('%s/tsne/%s/',param.pbase,param.datastr);
param.annopath = sprintf('%s/annotations/',param.dpathbase);
param.parampath = sprintf('%s/param/',param.pbase);

% segmentation/registration parameters
param.seg.numRegion = 3;
param.seg.skipStep = 1;
param.seg.outputsz = [300,300];
param.seg.ifscale = 1;

% DT parameters
param.dt.src = '/home/sh3276/software/dense_trajectory_release_v1.2/release_v4';
param.dt.W = 5;
param.dt.L = 15;
param.dt.tlen = 5; % in seconds
param.dt.s = 1;
param.dt.t = 1;
param.dt.N = 32;
param.dt.thresh = 0.5;

param.annotype = 5;
param.fr = 5;
param.timeStep = param.dt.tlen*param.fr;
param.infostr = sprintf('L_%u_W_%u_N_%u_s_%u_t_%u_step_%u',param.dt.L,...
    param.dt.W,param.dt.N,param.dt.s,param.dt.t,param.timeStep);

% FV parameters
param.fv.K = 128;
param.fv.ci = 90;
param.fv.intran = 0;
param.fv.powern = 1;
param.fv.featstr = {'hof','hog','mbhx','mbhy'};
param.fv.featlen = [9,8,8,8];
param.fv.numPatch = param.dt.s^2*param.dt.t;

% SVM parameters
param.svm.src = '/home/sh3276/software/libsvm';
param.svm.percTrain = 0.9;
param.svm.kernel = 3; % rbf kernel
param.svm.probest = 1; % true
param.svm.name = [param.infostr '_drFVall_annoType' num2str(param.annotype)];

% embedding parameters
param.tsne.distType = 'euc';
param.tsne.closeMatPool = true;
param.tsne.perplexity = 16;
param.tsne.training_perplexity = 16;
param.tsne = setRunParameters(param.tsne);
param.tsne.percTrain = 0.8;

%% check if all directories exist
if exist(param.dpath,'dir')~=7
    error('Incorrect data path')
end
if exist(param.anno.path,'dir')~=7
    error('Incorrect annotation path')
end
if exist(param.segpath,'dir')~=7
    fprintf('creating directory %s...\n',param.segpath);
    mkdir(param.segpath);
end
if exist(param.dtpath,'dir')~=7
    fprintf('creating directory %s...\n',param.dtpath);
    mkdir(param.dtpath);
end
if exist(param.dtmatpath,'dir')~=7
    fprintf('creating directory %s...\n',param.dtmatpath);
    mkdir(param.dtmatpath);
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

%% segmentation and registration
numfile = length(param.fileIndx);

% segmentation
for n = 1:numfile
    movieParam = paramAll(param.dpath,param.fileIndx(n));
    [segAll,theta,centroid,a,b] = runBPSegmentation(movieParam);
    save([param.segpath movieParam.fileName '_seg.mat'],'segAll','theta',...
        'centroid','a','b','-v7.3');
end

% make registered video clips
for n = 1:numfile

    movieParam = paramAll(param.dpath,param.fileIndx(n));
    fprintf('processing %s...\n',movieParam.fileName);
    
    % registration and make scaled video clips
    load([param.segpath movieParam.fileName '_seg.mat']);
    regSeg = registerSegmentMask(segAll,theta,centroid,param.timeStep*param.seg.skipStep);
    segmat = makeRegisteredVideo(param.fileIndx(n),regSeg,param.timeStep,param.seg.skipStep,...
        param.dpath,param.segpath,param.segvidpath,param.seg.ifscale,param.seg.outputsz);
    save([param.segpath movieParam.fileName '_scaled_reg_seg_step_' ...
        num2str(param.timeStep) '.mat'],'segmat','-v7.3');

end

%% run Dense Trajectories in terminal
% generate the script to run DT and save to dt result directory
writeDTscript(param);

% run DT
try 
%     system(sprintf('chmod +x %srunDT.sh',param.dtpath));
    status = system(sprintf('bash %srunDT.sh',param.dtpath));
catch ME
    error('Error running DenseTrajectoris');
end

%% extract DT features
for i = 1:length(param.fileIndx)
    
    % load features
    movieParam = paramAll(param.dpath,param.fileIndx(i));
    fprintf('extracting features %s...\n',movieParam.fileName);
    load([param.segpath movieParam.fileName '_scaled_reg_seg_step_'...
        num2str(param.timeStep) '.mat']);
    [trajAll,hofAll,hogAll,mbhxAll,mbhyAll,coordAll] = extractRegionTwDT...
        (movieParam,param.dtpath,segmat,param.seg.numRegion,param.dt);

    % save features
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_traj.mat'],'trajAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_hof.mat'],'hofAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_hog.mat'],'hogAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_mbhx.mat'],'mbhxAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_mbhy.mat'],'mbhyAll','-v7.3');
    save([param.dtmatpath movieParam.fileName '_' param.infostr '_coord.mat'],'coordAll','-v7.3');
    
end

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

% load annotations
movieParamMulti = paramMulti(param.dpath,param.trainIndx);
for n = 1:length(param.trainIndx)
    movieParamMulti{n}.numImages = (acm(n+1)-acm(n))*param.timeStep;
end
annoAll = annoMulti(movieParamMulti,param.annopath,param.annotype,param.timeStep);

% write data
param.svm.name = [param.infostr '_drFVall_annoType' num2str(param.annotype)];
wei_str = mkLibSVMsample(sample,param.svm.percTrain,annoAll,param.svm.name,param.svmpath);

% test sample
for n = 1:length(param.testIndx)
    
    movieParam = paramAll(param.dpath,param.testIndx(n));
    sample = load([param.fvpath movieParam.fileName '_' param.infostr '_drFVall.mat']);
    sample = sample.drFVall;
    annoAll = annoMulti({movieParam},param.annopath,param.annotype,param.timeStep);
    keepIndx = annoAll~=0;

    % write to libsvm format file
    gnLibsvmFile(annoAll(keepIndx),sample(keepIndx,:),[param.svmpath ...
        param.svm.name '_' movieParam.fileName '.txt']);

end

%% SVM
% train SVM
writeSVMscript(param.svm,wei_str,param.svmpath,param.svm.name);
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
writeSVMTestScript(param.svm.src,param.svmpath,param.svm.name,testnames);
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
[pred.train,pred_score.train] = saveSVMpred(param.svmpath,[param.svm.name '_train']);
[pred.test,pred_score.test] = saveSVMpred(param.svmpath,[param.svm.name '_test']);
for n = 1:length(param.testIndx)
    movieParam = paramAll(param.dpath,param.testIndx(n));
    annoAll = annoMulti({movieParam},param.annopath,param.annotype,param.timeStep);
    anno.new{n} = annoAll(annoAll~=0);
    [pred.new{n},pred_score.new{n}] = saveSVMpred(param.svmpath,...
        [param.svm.name '_' fileinfo(param.testIndx(n))]);
end

save([param.svmpath 'mat_results.mat'],'pred','pred_score','anno','-v7.3');

%% SVM analysis
% confusion matrix and stats
load([param.svmpath 'mat_results.mat']);
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
    (cell2mat(pred.new'),cell2mat(anno.new),numClass);

% plot confusion matrix
num_plts = max([length(param.testIndx),3]);
figure;set(gcf,'color','w')
subplottight(2,num_plts,1)
plotcmat(cmat.train,label(indxTrain),pred.train)
title('Train')
subplottight(2,num_plts,2)
plotcmat(cmat.test,label(indxTest),pred.test)
title('Test')
subplottight(2,num_plts,3)
plotcmat(cmat.new_all,cell2mat(anno.new),cell2mat(pred.new'))
title('New')
for n = 1:length(param.testIndx)
    subplottight(2,num_plts,length(param.testIndx)+n)
    plotcmat(cmat.new{n},anno.new{n},pred.new{n});
    title(['New #' num2str(n)])
end
set(findall(gcf,'-property','FontSize'),'FontSize',8)

disp(svm_stats.acr_all);
% stats_tb = table(svm_stats(:).acr);

% ROC curve
figure;
subplot(1,3,1)
auc.train = plotROCmultic(anno.train,pred_score.train,numClass);
legend('off')
subplot(1,3,2)
auc.test = plotROCmultic(anno.test,pred_score.test,numClass);
legend('off')
subplot(1,3,3)
auc.new = plotROCmultic(cell2mat(anno.new'),cell2mat(pred_score.new'),numClass);

% save results
save([param.svmpath 'stats.mat'],'svm_stats','cmat','auc','-v7.3');

%% embedding
fparam = struct();
fparam.filepath = param.fvpath;
fparam.infostr = param.infostr;
fparam.fileIndx = param.fileIndx;
fparam.tsnepath = param.tsnepath;
fparam.datastr = param.datastr;

runFVtsne(fparam,param.tsne);







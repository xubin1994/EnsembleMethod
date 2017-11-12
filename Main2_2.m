%% DESCRIPTION
% Dataset: any
% images: from dataset
% features: DD LRC MED ai TS
% algorithms: implemented
% classifier: TreeBagger


%% Initialization
close all;
clear all;
clc;

%%
%loading image names and locations
DatasetDir;

%loading all functions in arrays
FunctionsDir;

algosNum = [ 4 5 9 10 11] ;                                 %<<<-----------------------HARD CODED
%select desired algorithms from the list below and put its number in the list
%1-ADSM  2-ARWSM 3-BMSM  4-BSM   5-ELAS  6-FCVFSM   7-SGSM  8-SSCA  9-WCSM
%10-MeshSM 11-NCC

%featuresNum= [1 2 3];
%select desired features from the list below and put its number in the list
%   1-CE    2-CANNY 3-FNVE  4-GRAYCONNECTED 5-HA    6-HARRISCORNERPOINTS    7-HOG   8-LABELEDREGIONS    9-RD    10-SOBEL    11-SP   12-SURFF

addpath('2016-Correctness'); %features should be floats in range [0 1]
featureFunc{1}=str2func('DD');%overriding features
featureFunc{2}=str2func('LRC');
featureFunc{3}=str2func('MED');
%featureFunc{4}=str2func('DB');
%MMN, AML, LRD are not usefull here since we do not have cost volumes of other algorithms


%% reading or calculating errors for images (left and right)

display ('calculating disparities...');
data=struct;
dispData=struct;
tau=1; %error threshold

%real image mumbers in AllImages
%[1 90] --> Middlebury2014
%[91 478] --> KITTI2012
%[479 692] --> Sintel
%[693 713] -->Middlebury2006
%[714 719] -->Middlebury2005
trainImageList=[705,706];                                   %<<<-----------------------HARD CODED
testImageList=[707];                                        %<<<-----------------------HARD CODED
imagesList = [ trainImageList ,testImageList];

for imgNum=1:size(imagesList,2) %local image numbers
    imgL=imread(AllImages(imagesList(imgNum)).LImage);
    imgR=imread(AllImages(imagesList(imgNum)).RImage);
    algoCount=0;
    for aNum=algosNum
        algoCount=algoCount+1;
        fileName=strcat('./Results/',num2str(imagesList(imgNum)) ,'_',AllImages(imagesList(imgNum)).ImageName , '_'  ,func2str( algoFunc{aNum}),  '.mat');
        if exist(fileName,'file')
            load(fileName);
        else
            tic;
            [dispL, dispR]=algoFunc{aNum}(imgL,imgR,[1 AllImages(imagesList(imgNum)).maxDisp]);
            data.TimeCosts=toc;
            data.DisparityLeft=dispL;
            data.DisparityRight=dispR;
            data.ErrorRates=EvaluateDisp(AllImages(imagesList(imgNum)),double(dispL),tau);
            save(fileName,'data');
        end
        err(algoCount,imgNum)=EvaluateDisp(AllImages(imagesList(imgNum)),data.DisparityLeft,tau);%data.ErrorRates;
        dispData(algoCount,imgNum).left=data.DisparityLeft;
        dispData(algoCount,imgNum).right=data.DisparityRight;
    end
    display([num2str(imagesList(imgNum)) 'done']);
end
clear algoCount aNum data fileName
%checking every result
% for i=1:m
% imshow(dispData(i,2).left,[]);
% waitforbuttonpress();
% cla;
% end

%% making the dataset and features
m=size(algosNum,2); %number of active matchers
display('making dataset...');
totalPCount=0;
%samples=struct;


for imgNum=1:size(imagesList,2)
    width=size(dispData(1,imgNum).left,1);
    height=size(dispData(1,imgNum).left,2);
    imgPixelCount(imgNum)=width*height;
end
samplesNum=sum(imgPixelCount);
%input=zeros(samplesNum,m-1+m+m+1+m,m);%ai , DD , LRC , TS, MED
input=zeros(samplesNum,8,m);                                %<<<-----------------------HARD CODED
class=zeros(samplesNum,m);
for imgNum=1:size(imagesList,2)
    display(['working on img ' num2str(imagesList(imgNum)) ]);
    %pre-calculting all agreement features =ai
    agreementMat=struct;
    for i=1:m
        for j=i:m
            if i~=j
                diff=abs(dispData(i,imgNum).left-dispData(j,imgNum).left);
                diff(diff<=3)=1;%ai threshold
                diff(diff>3)=-1;
                agreementMat(i,j).diff=diff;
                agreementMat(j,i).diff=diff;
            else
                agreementMat(i,j).diff=NaN;
            end
        end
    end
    
    %pre-calculting all DDs LRCs and MEDs
    display('Getting DD LRC MED' );
    DD=zeros(size(dispData(i,imgNum).left,1),size(dispData(i,imgNum).left,2),m);
    LRC=DD;
    MED=DD;
    for i=1:m
        DD(:,:,i)=featureFunc{1}(dispData(i,imgNum).left);
        LRC(:,:,i)=featureFunc{2}(dispData(i,imgNum).left,dispData(i,imgNum).right );
        MED(:,:,i)=featureFunc{3}(dispData(i,imgNum).left);
    end
    
    imgGT = GetGT(AllImages(imagesList(imgNum)));
    
    for i=1:m % so, primary matcher is i
        pCount=totalPCount;%number of pixels (samples)
        truePixles = abs(dispData(i,imgNum).left - imgGT) <= 1;
        %badPixles(~imgMask) = 0;
        
        %making data
        display(['making data for algorithm number ', num2str(i)]);
        for x=1:size(dispData(i,imgNum).left,1)
            for y=1:size(dispData(i,imgNum).left,2)
                %FIX: considering non-occluded pixels (SHOULD WE????)
                pCount=pCount+1;
                tmpCount=0;% always reachs to m-1
                for j=1:m %index of secondary matcher
                    if j~=i
                        tmpCount=tmpCount+1;
                        input(pCount,tmpCount,i)=agreementMat(j,i).diff(x,y);%ai
                    end
                end
                %only using its own features                %<<<-----------------------HARD CODED
                input(pCount,5,i)=squeeze(DD(x,y,i));%DD
                input(pCount,6,i)=squeeze(LRC(x,y,i));%LRC
                input(pCount,7,i)=sum (input(pCount,1:tmpCount,i)==1);%TS
                input(pCount,8,i)=squeeze(MED(x,y,i));
                
                %using other features of other matchers
%                 fInd=8;
%                 for j=1:m %index of secondary matcher
%                     if j~=i
%                         ai=agreementMat(j,i).diff(x,y);
%                         fInd=fInd+1;
%                         input(pCount,fInd,i)=squeeze(DD(x,y,j))*ai;%aiDD
%                         fInd=fInd+1;
%                         input(pCount,fInd,i)=squeeze(LRC(x,y,j))*ai;%aiLRC
%                         fInd=fInd+1;
%                         input(pCount,fInd,i)=squeeze(MED(x,y,j))*ai;%aiMED
%                     end
%                 end
                class(pCount,i)= truePixles(x,y);%whether the disparity assigned to that pixel was correct (1) or not (0)
            end
        end
    end
    totalPCount=pCount;
    display([num2str(imagesList(imgNum)) ' done']);
end
clear width height agreementMat DD LRC MED imgGT pCount tmpCount diff


%% TreeBagger
imgPixelCountTrain=imgPixelCount(1:size(trainImageList,2));
imgPixelCountTest=imgPixelCount(1+size(trainImageList,2):end);
permutedIndices=randperm( sum(imgPixelCountTrain));
portion=1;
sampleCount=uint32( portion*sum(imgPixelCountTrain));
trainIndices=permutedIndices (1:sampleCount);

RFs=struct;%to store TreeBagger models
treesCount=50;
%train and test sets

trainInput=input(trainIndices,:,:);
trainClass=class(trainIndices,:);%floor(totalPCount/2)

for i=1:m
    X=trainInput(:,:,i);
    Y=trainClass(:,i);
    display(['training RF number ' num2str(i)]);
    %RFs(i).model=TreeBagger(treesCount,X,Y,'OOBPrediction','on');
    RFs(i).model=compact (TreeBagger(treesCount,X,Y,'MinLeafSize',5000,'MergeLeaves','on' ));
    %RFs(i).model=TreeBagger(treesCount,X,Y);
    %RFs(i).treeErrors = oobError(RFs(i).model);%out of bag error
    %tr10 = RFs(i).model.Trees{10};
    %view(tr10,'Mode','graph');
end

%testing...
display('testing...');
testInput=input(1+sum(imgPixelCountTrain):end,:,:);
testClass=class(1+sum(imgPixelCountTrain):end,:);%for AUC calculations
for i=1:m
    [labels,confidence] = predict(RFs(i).model,testInput(:,:,i));
    %[RFs(i).labels,RFs(i).scores] = predict(RFs(i).model,testInput(:,:,i),'Trees',10:20);
    finalScores(i,:)=confidence(:,2);
    %finalLabels(i,:)=labels;
end
[values, indices]=max(finalScores);

%getting results per image
Results=struct;
for testImgNum=1:size(imgPixelCountTest,2)
    ind1=sum(imgPixelCountTest(1:testImgNum-1));
    ind2=ind1+imgPixelCountTest(testImgNum);
    imgNum=testImgNum+size(imgPixelCountTrain,2);
    [imgW ,imgH]=size(dispData(1,imgNum).left);
    
    Results(testImgNum).Indices=reshape(indices(1+ind1:ind2),[imgH imgW ])';
    Results(testImgNum).Values=reshape(values(1+ind1:ind2),[imgH imgW ])';
    finalDisp=zeros(imgW,imgH);
    for x=1:imgW
        for y=1:imgH
            finalDisp(x,y)=dispData(Results(testImgNum).Indices(x,y),imgNum).left(x,y);
        end
    end
    Results(testImgNum).FinalDisp=finalDisp;
    Results(testImgNum).Error=EvaluateDisp(AllImages(imagesList(imgNum)),finalDisp,tau);
    [roc,pers]=GetROC(AllImages(imagesList(imgNum)),finalDisp,Results(testImgNum).Values);
    Results(testImgNum).ROC=roc;
    %The trapz function overestimates the value of the integral when f(x) is concave up.
    Results(testImgNum).AUC=GetAUC(roc,pers); %perfect AUC is err-(1-err)*ln(1-err)
    %% other stuff                                                               
    %best possible error                                                     
%     finalDisp2=zeros(imgW,imgH);                                           
%     imgGT = GetGT(AllImages(imagesList(imgNum)));                          
%     for x=1:imgW                                                           
%         for y=1:imgH                                                       
%             for i=1:m                                                      
%                 alldisps(i)=dispData(i,imgNum).left(x,y);                  
%             end                                                            
%             alldispsDif=abs(alldisps-imgGT(x,y));                          
%             [val,ind]=min(alldispsDif);                                    
%             finalDisp2(x,y)=alldisps(ind);                                 
%         end                                                                
%     end                                                                    
%     BPE(imgNum)=EvaluateDisp(AllImages(imagesList(imgNum)),finalDisp2,tau);
                                                                             
                                                                             
    %simple post process ;-)                                                 
%     se = strel('rectangle',[2 2]);                                         
%     closeBW = imclose(finalDisp,se);                                       
%     imshow(closeBW,[]);                                                    
%     EvaluateDisp(AllImages(imgNum),closeBW,tau) 
end

clear alldisps alldispsDif X Y roc pers imgGT imgNum i j x y labels confidence finalScores ind1 ind2 imgW imgH ind val
load chirp % chirp handel  gong
sound(y,Fs);    display('Job Done.');
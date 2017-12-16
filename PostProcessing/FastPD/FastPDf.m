function MRF_labeling = FastPDf(CostVolume, numlabels ,dispImg,imgL3D)
%https://github.com/srdjankrstic/defocus
lambda=2;

input_file = tempname('test\tmp\');
output_file = tempname('test\tmp\');

fid = fopen(input_file, 'wb');
if fid == -1
    error(['Cannot open file ' results_fname]);
end

h = size(imgL3D, 1);
w = size(imgL3D, 2);
numpoints = h * w;
numpairs = 2 * h * w - h - w;
maxIters = 100;
type = 'float';

fwrite(fid, numpoints, 'int');
fwrite(fid, numpairs, 'int');
fwrite(fid, numlabels, 'int');
fwrite(fid, maxIters, 'int');

%making nodes...
node=0;
nodes=struct;
for i=1:w
    for j=1:h
        node=node+1;
        nodes(node).x=j;
        nodes(node).y=i;
    end
end

%CostVolume=CostVolume+bias;
% HACK
avg = mean(CostVolume(:));
stdev = std(CostVolume(:));
CostVolume(CostVolume> avg + 2*stdev) = avg + 2 * stdev;
CostVolume = normalize(CostVolume);
lcosts=CostVolume(:);
fwrite(fid,lcosts, type);


p=double(imgL3D );
wcosts=zeros(numpairs,1);
edgeNum=0;
[cost, ~]=min(CostVolume,[],3);
for i=1:numpoints
    if nodes(i).x < h
    tail=i;
    head=i+1;
    edgeNum=edgeNum+1;
    edge=[tail, head]-1;
    fwrite(fid,edge,'int');
    edgeW=Wpq(p(nodes(tail).x,nodes(tail).y),p(nodes(head).x,nodes(head).y),...
        dispImg(nodes(tail).x,nodes(tail).y),dispImg(nodes(head).x,nodes(head).y));
    wcosts(edgeNum)=edgeW+cost(nodes(tail).x,nodes(tail).y);
    end
    
    if nodes(i).y<w
        tail=i;
        head=i+h;
        edgeNum=edgeNum+1;
        edge=[tail, head]-1;
        fwrite(fid,edge,'int');
        edgeW=Wpq(p(nodes(tail).x,nodes(tail).y),p(nodes(head).x,nodes(head).y),...
            dispImg(nodes(tail).x,nodes(tail).y),dispImg(nodes(head).x,nodes(head).y));
        wcosts(edgeNum)=edgeW+cost(nodes(tail).x,nodes(tail).y);
    end
end

% inter-label costs (0 if same, 1 if adjacent, 2 otherwise)
% dist = 2 * ones(numlabels, numlabels) - ...
%     2 * eye(numlabels) - ...
%     1 * diag(ones(numlabels - 1, 1), 1) - ...
%     1 * diag(ones(numlabels - 1, 1), -1);
dist=ones(numlabels, numlabels)-eye(numlabels);

%	fread( _dist  , sizeof(Real), _numlabels*_numlabels, fp );
fwrite(fid, dist, type);

fwrite(fid,wcosts*lambda, type);
fclose(fid);

% run FastPD
commandStr = ['"'  mfilename('fullpath') '/../FastPDf.exe" ' input_file ' ' output_file]
result=system(commandStr);
if(result~=0)
    error(['FastPDf.exe return error:' num2str(result)]);
end
MRF_labeling = get_MRF_labeling(output_file);
MRF_labeling = reshape(MRF_labeling, h,w)+1;
%    MRF_labeling = max(max(MRF_labeling)) - MRF_labeling;

% clean up
%if (~DEBUG)
delete(input_file, output_file);
%end

end

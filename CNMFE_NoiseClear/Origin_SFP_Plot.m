%% Origin_SFP_Plot
% 绘制没有进行去噪的SFP
% 生成的图像可用于判断哪些数据需要比较仔细的去噪

%% 2. 加载数据
matFiles = dir('*CNMFE.mat');
if isempty(matFiles), error('未找到 *CNMFE.mat 文件'); end
filename = matFiles(1).name;
[~, baseName, ~] = fileparts(filename);
fprintf('正在加载数据: %s ...\n', filename);
load(filename);

% 变量标准化
if exist('NeuronC','var'), C = NeuronC; else, C = data.C; end
if exist('NeuronA','var'), A = NeuronA; else, A = data.A; end
if exist('NeuronP','var'), P = NeuronP; else, P = data.P; end
if exist('NeuronS','var'), S = NeuronS; else, S = data.S; end

[h, w, nNeurons] = size(A);

% --- 修改部分：定义保存路径 ---
outputDir = 'D:\Others\Wu_Data\Origin_SFP\Wu_Data2_20250218_27_OF';
if ~exist(outputDir, 'dir')
    mkdir(outputDir); % 如果文件夹不存在，则创建它
end
% ---------------------------

f_sfp = figure('Name', 'SFP');
SFP = max(NeuronA, [], 3);
imagesc(SFP); axis image; colormap jet; colorbar;
title('去噪后空间投影 (SFP)');

% --- 修改部分：保存到指定路径 ---
savePath = fullfile(outputDir, [baseName, '_Origin_SFP.png']);
saveas(f_sfp, savePath); 
fprintf('图片已保存至: %s\n', savePath);
% ---------------------------

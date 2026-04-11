%% CNMFE_Noise_Cleaner_v2.1
% %% 代码说明：
% 改编自 HXY 的 Filter_Bad_Neurons.m
% 根据神经元和噪音的特性，半自动化筛选噪音和真实神经元信号

% %% 代码标注：
% WXW 
% 2026/1/21 version 2.1
% 修复了 Linger 交互报错，优化了 A/C 呈现对比度与布局
% 添加了"回车"退出和总量显示


% %% 工作流程：
% 运行
% 确认噪音 true or false（红色噪音，绿色神经元）
% 确认神经元 true or false
% 绘制滤去噪音后的 SFP

clc; clear; close all;

%% 1. 参数设置
Stability_Threshold = 0.15; 
Eccentricity_Threshold = 0.95;
Entropy_Threshold = 5.8;  

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

%% 3. 自动初步筛选
is_noise_auto = false(nNeurons, 1);
reasons = strings(nNeurons, 1);
for i = 1:nNeurons
    img = A(:,:,i); img_norm = img/max(img(:));
    mask = img_norm > 0.2;
    stats = regionprops(mask, 'Eccentricity');
    space_entropy = entropy(img_norm);
    
    trace = C(i,:); mid = floor(length(trace)/2);
    m1 = mean(trace(1:mid)) - min(trace); m2 = mean(trace(mid+1:end)) - min(trace);
    ratio = min(m1, m2) / (max(m1, m2) + 1e-6);
    
    if ratio < Stability_Threshold, is_noise_auto(i) = true; reasons(i) = "Unstable";
    elseif space_entropy > Entropy_Threshold, is_noise_auto(i) = true; reasons(i) = "Fragmented";
    elseif ~isempty(stats) && stats(1).Eccentricity > Eccentricity_Threshold
        is_noise_auto(i) = true; reasons(i) = "Vessel";
    end
end

%% 4. 键盘交互核验程序
final_status = ~is_noise_auto; 
for s = 1:2
    if s == 1
        targets = find(is_noise_auto);
        msg = '正在核验【自动剔除的噪音】';
    else
        targets = find(~is_noise_auto);
        msg = '正在核验【自动保留的神经元】';
    end
    
    if isempty(targets), continue; end
    hFig = figure('Name', msg, 'Color', 'w', 'Position', [100 100 1200 650], ...
                  'KeyPressFcn', @(src, event)setappdata(src, 'key', event.Key));
    curr = 1;
    total_num = length(targets);
    
    while true
        id = targets(curr);
        clf(hFig);
        
        % --- 1. 空间图 (NeuronA) ---
        axA = axes('Position', [0.05, 0.15, 0.4, 0.7], 'Interactions', [], 'HitTest', 'off'); 
        img_data = A(:,:,id);
        imagesc(img_data); axis image; colormap(axA, 'hot');
        set(axA, 'CLim', [0, 0.2]); 
        
        [row_bad, col_bad] = find(img_data > 0.5);
        if ~isempty(row_bad)
            hold(axA, 'on'); plot(axA, col_bad, row_bad, 'r.', 'MarkerSize', 4); hold(axA, 'off');
        end
        cb = colorbar('Location', 'westoutside'); ylabel(cb, 'Spatial Intensity');
        axis off; title(sprintf('Spatial A (ID: %d)', id), 'FontSize', 12, 'FontWeight', 'bold');
        
        % --- 2. 时间轨迹 (NeuronC) ---
        axC = axes('Position', [0.52, 0.35, 0.43, 0.3], 'Interactions', [], 'HitTest', 'off'); 
        hold(axC, 'on');
        line([1, size(C,2)], [20, 20], 'Color', [1, 0, 0, 0.5], 'LineStyle', '--', 'LineWidth', 1);
        line([1, size(C,2)], [100, 100], 'Color', [1, 0, 0, 0.5], 'LineStyle', '--', 'LineWidth', 1);
        plot(C(id,:), 'LineWidth', 1, 'Color', [0.1, 0.4, 0.8]); 
        xlim(axC, [1, size(C,2)]); ylim(axC, [0, 120]);
        set(axC, 'TickDir', 'out', 'Box', 'off'); grid off;
        ylabel(axC, 'Intensity'); title(axC, 'Temporal Trace', 'FontSize', 12);
        
        % --- 3. 状态颜色与进度显示 ---
        if final_status(id)
            color_str = [0 0.6 0]; fig_bg = [0.95, 1, 0.95]; status_str = '【保留】';
        else
            color_str = [0.8 0 0]; fig_bg = [1, 0.95, 0.95]; status_str = '【剔除】';
        end
        set(hFig, 'Color', fig_bg);
        
        % 动态操作提示
        if curr == total_num
            op_hint = '【已至末尾，回车(Return)确认并退出此阶段】';
        else
            op_hint = '[→]下一步';
        end

        sgtitle({sprintf('%s (%d/%d)', msg, curr, total_num), ...
            sprintf('ID: %d | 自动原因: %s | 当前状态: %s', id, reasons(id), status_str), ...
            ['操作：[空格]切换状态  [←]上一步  ', op_hint]}, ...
            'Color', color_str, 'FontSize', 14, 'FontWeight', 'bold');
        
        % --- 4. 键盘逻辑控制 ---
        waitforbuttonpress;
        key = getappdata(hFig, 'key');
        if strcmp(key, 'space')
            final_status(id) = ~final_status(id);
        elseif strcmp(key, 'rightarrow')
            if curr < total_num, curr = curr + 1; end % 限制在最后一位
        elseif strcmp(key, 'leftarrow')
            curr = max(1, curr - 1);
        elseif strcmp(key, 'return') && curr == total_num
            break; % 只有在最后一位且按下回车才退出
        elseif strcmp(key, 'escape')
            break; 
        end
        setappdata(hFig, 'key', ''); 
    end
    if ishandle(hFig), close(hFig); end
end

%% 5. 数据提取与保存
TrueNeuronID = find(final_status); NoiseID = find(~final_status);
NeuronA = A(:,:,TrueNeuronID); NeuronC = C(TrueNeuronID,:);
NeuronP = P(TrueNeuronID,:); NeuronS = S(TrueNeuronID,:);
outputName = [baseName, '_Cleaned.mat'];
save(outputName, 'NeuronA', 'NeuronC', 'NeuronP', 'NeuronS', 'NoiseID', 'TrueNeuronID', '-v7.3');

%% 6. SFP Plot
f_sfp = figure('Name', 'Cleaned SFP');
SFP = max(NeuronA, [], 3);
imagesc(SFP); axis image; colormap jet; colorbar;
title('去噪后空间投影 (SFP)');
savefig(f_sfp, [baseName, '_Cleaned_SFP.fig']);
saveas(f_sfp, [baseName, '_Cleaned_SFP.png']);

%% 7. 噪音最终核验大图 (4x4 静态)
IDs = NoiseID; numTotal = length(IDs); cellsPerPage = 16;
numPages = ceil(numTotal / cellsPerPage);
for p = 1:numPages
    figName = sprintf('噪音核验 - 页 %d/%d', p, numPages);
    figure('Name', figName, 'Color', 'w', 'Units', 'normalized', 'OuterPosition', [0.05 0.05 0.9 0.9]);
    tlo = tiledlayout(4, 4, 'TileSpacing', 'loose', 'Padding', 'compact');
    
    startIdx = (p-1) * cellsPerPage + 1; endIdx = min(p * cellsPerPage, numTotal);
    for i = startIdx:endIdx
        id = IDs(i); parentTile = nexttile(tlo);
        set(parentTile, 'Color', 'none', 'XColor', 'none', 'YColor', 'none');
        drawnow; pos = parentTile.Position; 
        
        % A部分 (禁用交互防止报错)
        axA = axes('Position', [pos(1), pos(2) + pos(4)*0.4, pos(3), pos(4)*0.55], 'Interactions', [], 'HitTest', 'off');
        imagesc(axA, A(:,:,id)); axis(axA, 'image'); colormap(axA, 'hot'); axis off;
        title(axA, sprintf('ID: %d', id), 'FontSize', 10, 'FontWeight', 'bold');
        
        % C部分 (红色分界线呈现)
        axC = axes('Position', [pos(1), pos(2), pos(3), pos(4)*0.3], 'Interactions', [], 'HitTest', 'off');
        hold(axC, 'on');
        line(axC, [1, size(C,2)], [20, 20], 'Color', [1 0 0], 'LineStyle', '--');
        line(axC, [1, size(C,2)], [100, 100], 'Color', [1 0 0], 'LineStyle', '--');
        plot(axC, C(id,:), 'Color', [0 0.2 0.6], 'LineWidth', 0.8);
        xlim(axC, [1, size(C,2)]); ylim(axC, [0, 120]);
        set(axC, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8); hold(axC, 'off');
    end
end
fprintf('处理完成！保留: %d | 剔除: %d\n', length(TrueNeuronID), length(NoiseID));

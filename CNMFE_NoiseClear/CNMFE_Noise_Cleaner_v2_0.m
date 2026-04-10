%% CNMFE_Noise_Cleaner_v2
% %% 代码说明：
% 改编自 HXY 的 Filter_Bad_Neurons.m
% 根据神经元和噪音的特性，自动化筛选噪音和真实神经元信号
% 最终人工核验

% %% 代码标注：
% WXW
% 2026/1/21 version 2.0

% %% 工作流程：
% 运行全部
% 确认噪音 true or false（红色噪音，绿色神经元）
% 确认神经元 true or false
% 绘制滤去噪音后的SFP

%% 神经元自动过滤与深度交互核验脚本
clc; clear; close all;

%% 1. 参数设置
Stability_Threshold = 0.15; 
Eccentricity_Threshold = 0.95;
Entropy_Threshold = 5.8;  % 空间破碎度阈值

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
    % 空间分析
    img = A(:,:,i); img_norm = img/max(img(:));
    mask = img_norm > 0.2;
    stats = regionprops(mask, 'Eccentricity', 'Solidity');
    space_entropy = entropy(img_norm);
    
    % 时间分析
    trace = C(i,:); mid = floor(length(trace)/2);
    m1 = mean(trace(1:mid)) - min(trace); m2 = mean(trace(mid+1:end)) - min(trace);
    ratio = min(m1, m2) / (max(m1, m2) + 1e-6);
    
    % 判定逻辑
    if ratio < Stability_Threshold, is_noise_auto(i) = true; reasons(i) = "Unstable";
    elseif space_entropy > Entropy_Threshold, is_noise_auto(i) = true; reasons(i) = "Fragmented";
    elseif ~isempty(stats) && stats(1).Eccentricity > Eccentricity_Threshold
        is_noise_auto(i) = true; reasons(i) = "Vessel";
    end
end

%% 4. 键盘交互核验程序
final_status = ~is_noise_auto; % true = 良好, false = 噪音
stages = {"Noise_Candidate", "True_Neuron_Candidate"};

for s = 1:2
    if s == 1
        targets = find(is_noise_auto);
        msg = '正在核验【自动剔除的噪音】';
    else
        targets = find(~is_noise_auto);
        msg = '正在核验【自动保留的神经元】';
    end
    
    if isempty(targets), continue; end
    
    hFig = figure('Name', msg, 'Color', 'w', 'Position', [100 100 1200 600], 'KeyPressFcn', @(src, event)setappdata(src, 'key', event.Key));
    curr = 1;
    
    while curr <= length(targets)
        id = targets(curr);
        
        % 绘图区

        % --- 深度美化布局：突出数据本身 ---
        clf(hFig);
        
        % 1. 空间图 (NeuronA)：占据左侧，保持正方形
        % 位置参数: [左, 下, 宽, 高]
        axA = axes('Position', [0.05, 0.15, 0.4, 0.7]); 
        imagesc(A(:,:,id)); 
        axis image;            % 保持像素比例不失真
        % colormap(axA, 'hot'); 
        colorbar('Location', 'westoutside'); % 能量条放左边，避免挤占中间
        axis off;              % 去除坐标轴干扰，突出形态本身
        title(sprintf('Spatial A (ID: %d)', id), 'FontSize', 12, 'FontWeight', 'bold');
        
        % --- 2. 时间轨迹 (NeuronC)：高度压扁 + 限制y轴 + 绘制参考线 ---
        axC = axes('Position', [0.52, 0.35, 0.43, 0.25]); 
        hold(axC, 'on'); % 开启 hold 以绘制多条线
        
        % 绘制参考线 (20 和 100)
        line([1, size(C,2)], [20, 20], 'Color', [1, 0, 0, 0.5], 'LineStyle', '--', 'LineWidth', 1);
        line([1, size(C,2)], [100, 100], 'Color', [1, 0, 0, 0.5], 'LineStyle', '--', 'LineWidth', 1);
        
        % 绘制主要的钙信号线
        plot(C(id,:), 'LineWidth', 1, 'Color', [0.1, 0.4, 0.8]); 
        
        % 设置轴属性
        xlim(axC, [1, size(C,2)]);
        ylim(axC, [0, 120]); % 强制 y 轴范围 0-120
        grid off;
        set(axC, 'TickDir', 'out', 'Box', 'off');
        ylabel(axC, 'Intensity');
        title(axC, 'Temporal Trace (Ref: 20 & 100)', 'FontSize', 12, 'FontWeight', 'bold');
        
        hold(axC, 'off');
        
        % 3. 交互状态反馈（动态标题与背景色）
        if final_status(id)
            status_text = '【 状态：保留 (True Neuron) 】';
            display_color = [0, 0.5, 0]; % 森林绿
            fig_bg = [0.95, 1, 0.95];    % 淡绿背景
        else
            status_text = '【 状态：剔除 (Noise) 】';
            display_color = [0.8, 0, 0]; % 警告红
            fig_bg = [1, 0.95, 0.95];    % 淡红背景
        end
        set(hFig, 'Color', fig_bg); % 背景随状态变化，给用户最直观的反馈
        
        sgtitle({['正在审核: ', char(msg)], ...
                 ['自动原因: ', char(reasons(id))], ...
                 [status_text, '  (Space: 切换状态 | →: 下一个 | ←: 上一个)']}, ...
                'Color', display_color, 'FontSize', 15, 'FontWeight', 'bold');
        
        % 状态与操作提示 (动态更新标题颜色)
        if final_status(id)
            status_text = '【 保留：True Neuron 】';
            display_color = [0, 0.5, 0]; % 绿色
        else
            status_text = '【 剔除：Noise / Bad 】';
            display_color = [0.8, 0, 0]; % 红色
        end
        
        sgtitle({['正在审核: ', msg], ...
                 ['ID: ', num2str(id), ' | 自动判别原因: ', char(reasons(id))], ...
                 [status_text, '  (Space: 切换 | →: 下一个 | ←: 上一个)']}, ...
                'Color', display_color, 'FontSize', 14, 'FontWeight', 'bold');
        
        % 状态显示
        if final_status(id)
            status_str = '状态：【保留 (True Neuron)】';
            color_str = [0 0.6 0]; % 绿色
        else
            status_str = '状态：【剔除 (Noise)】';
            color_str = [0.8 0 0]; % 红色
        end
        sgtitle({msg, sprintf('ID: %d | 自动原因: %s', id, reasons(id)), ...
            [status_str, '   操作：[空格]切换状态  [→]下一步  [←]上一步']}, 'Color', color_str, 'FontSize', 14, 'FontWeight', 'bold');

        % 交互等待
        waitforbuttonpress;
        key = getappdata(hFig, 'key');
        
        switch key
            % 
            case 'space'
                final_status(id) = ~final_status(id); % 切换状态
            case 'rightarrow'
                curr = curr + 1;
            case 'leftarrow'
                curr = max(1, curr - 1);
            case 'escape'
                break;
        end
    end
    if ishandle(hFig), close(hFig); end
end

%% 5. 数据提取与保存
TrueNeuronID = find(final_status);
NoiseID = find(~final_status);

NeuronA = A(:,:,TrueNeuronID);
NeuronC = C(TrueNeuronID,:);
NeuronP = P(TrueNeuronID,:);
NeuronS = S(TrueNeuronID,:);

outputName = [baseName, '_Cleaned.mat'];
save(outputName, 'NeuronA', 'NeuronC', 'NeuronP', 'NeuronS', 'NoiseID', 'TrueNeuronID', '-v7.3');

%% 6. SFP Plot

% 绘制去噪后的 SFP
% 
figure('Name', 'Cleaned SFP');
SFP = max(NeuronA, [], 3);
imagesc(SFP); axis image; colormap jet;
title('去噪后空间投影 (SFP)');
saveas(gcf, [baseName, '_Cleaned_SFP.fig']);

fprintf('处理完成！\n保留: %d | 剔除: %d\n结果保存至: %s\n', length(TrueNeuronID), length(NoiseID), outputName);

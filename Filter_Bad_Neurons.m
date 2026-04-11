function Filter_Bad_Neurons()
    % Filter_Bad_Neurons
    % 功能：自动过滤坏神经元（半死半活的Trace + 血管状的Spatial）
    % 输入：自动读取目录下的 CNMFE.mat
    % 输出：Filter_Report.png (过滤报告) + Cleaned_CNMFE.mat (保存好细胞)
    
    clc; clear; close all;

    %% 1. 参数设置 (Sensitivity Settings)
    % --- 时间筛选参数 ---
    % 只要前半段和后半段的活跃度差异超过这个倍数，就认为是坏的
    % 例如 0.15 表示：弱的那一半的强度还不到强的那一半的 15%
    Stability_Threshold = 0.15; 
    
    % --- 空间筛选参数 ---
    % 离心率阈值 (0=圆, 1=线)。超过此值视为血管
    Eccentricity_Threshold = 0.96; 
    
    %% 2. 加载数据
    matFiles = dir('*CNMFE.mat');
    if isempty(matFiles), matFiles = dir('*.mat'); end
    if isempty(matFiles), error('未找到 .mat 文件'); end
    
    filename = matFiles(1).name;
    fprintf('正在加载数据: %s ...\n', filename);
    data = load(filename);
    
    % 提取变量 (兼容大小写)
    if isfield(data, 'NeuronC'), C = data.NeuronC; else, C = data.C; end
    if isfield(data, 'NeuronA'), A = data.NeuronA; else, A = data.A; end
    if isfield(data, 'NeuronP'), P = data.NeuronP; else, P = data.P; end
    if isfield(data, 'NeuronS'), S = data.NeuronS; else, S = data.S; end
    
    % 维度标准化
    % C: [Neurons x Frames]
    [d1, d2] = size(C);
    if d1 > d2, C = C'; P = P'; S = S'; end
    nNeurons = size(C, 1);
    
    % A: [Height x Width x Neurons]
    % 你的截图显示 A 是 3D 矩阵 (200x200x153)
    [h, w, nA] = size(A);
    if nA ~= nNeurons
        % 如果 A 不是 3D 或者是 (pixels x neurons) 的 2D
        if h*w == nNeurons || h == nNeurons
             % 需要特殊处理 reshape，这里暂时假设你的数据格式如截图所示是标准的 3D
             warning('NeuronA 的维度 (%d) 与 NeuronC (%d) 不一致，请检查!', nA, nNeurons);
        end
    end
    
    fprintf('共检测到 %d 个神经元。开始筛选...\n', nNeurons);
    
    %% 3. 筛选循环
    keep_indices = true(nNeurons, 1);
    reject_reason = strings(nNeurons, 1); % 记录拒绝原因
    
    % 准备画图：被拒绝的细胞展示
    rejected_indices = [];
    
    for i = 1:nNeurons
        %% --- A. 空间筛选 (检测血管) ---
        % 获取当前神经元的空间图
        spatial_footprint = A(:, :, i);
        
        % 二值化 (提取轮廓)
        % 取最大亮度的 20% 作为阈值，提取主体
        binary_mask = spatial_footprint > (max(spatial_footprint(:)) * 0.2);
        
        % 计算形态学属性
        stats = regionprops(binary_mask, 'Eccentricity', 'Area');
        
        is_vessel = false;
        if ~isempty(stats)
            % 取面积最大的那个连通域（防止噪点干扰）
            [~, idx] = max([stats.Area]);
            ecc = stats(idx).Eccentricity;
            
            if ecc > Eccentricity_Threshold
                is_vessel = true;
                reject_reason(i) = sprintf("Vessel (Ecc: %.2f)", ecc);
            end
        end
        
        %% --- B. 时间筛选 (检测半死半活) ---
        trace = C(i, :);
        nFrames = length(trace);
        
        % 分割为前后两半
        midPoint = floor(nFrames / 2);
        part1 = trace(1:midPoint);
        part2 = trace(midPoint+1:end);
        
        % 计算平均活跃度 (减去最小基线，防止负数影响比率)
        base = min(trace);
        mu1 = mean(part1) - base;
        mu2 = mean(part2) - base;
        
        % 计算比率 (小的 / 大的)
        % 如果很稳定，比率应该接近 1
        % 如果一半死一半活，比率会接近 0
        activity_ratio = min(mu1, mu2) / (max(mu1, mu2) + 1e-6); % 加极小值防除零
        
        is_unstable = false;
        if activity_ratio < Stability_Threshold
            is_unstable = true;
            if mu1 > mu2
                reject_reason(i) = "Dead End (Half-Active)";
            else
                reject_reason(i) = "Sudden Start (Half-Active)";
            end
        end
        
        %% --- C. 综合判定 ---
        if is_vessel || is_unstable
            keep_indices(i) = false;
            rejected_indices(end+1) = i;
        end
    end
    
    nKeep = sum(keep_indices);
    nReject = nNeurons - nKeep;
    
    fprintf('筛选完成！\n保留: %d\n剔除: %d\n', nKeep, nReject);
    
    %% 4. 生成拒绝报告图 (可视化验证)
    if nReject > 0
        % 最多画 25 个被拒绝的例子
        nPlot = min(nReject, 25);
        f = figure('Name', 'Rejected Neurons Report', 'Color', 'w', 'Position', [100 100 1200 800]);
        
        for k = 1:nPlot
            idx = rejected_indices(k);
            
            % 画 Trace
            subplot(5, 5, k);
            plot(C(idx, :), 'k', 'LineWidth', 0.5);
            
            % 在图上标注原因
            title(sprintf('ID %d: %s', idx, reject_reason(idx)), 'Interpreter', 'none', 'FontSize', 8, 'Color', 'r');
            xlim([1 size(C,2)]);
            axis off;
        end
        sgtitle('Rejected Candidates (First 25)');
        
        % 保存报告
        exportgraphics(f, 'Filter_Report.png');
        fprintf('拒绝报告已保存至 Filter_Report.png (请务必检查)\n');
    else
        fprintf('太完美了，没有神经元被剔除。\n');
    end
    
    %% 5. 保存干净的数据
    % 提取好数据
    NeuronC = C(keep_indices, :);
    NeuronP = P(keep_indices, :);
    NeuronS = S(keep_indices, :);
    NeuronA = A(:, :, keep_indices); % 注意 A 是 3D 的
    
    % 保存为新文件
    outputName = 'Cleaned_CNMFE.mat';
    fprintf('正在保存筛选后的数据至 %s ...\n', outputName);
    
    % 使用 -v7.3 以支持大文件
    save(outputName, 'NeuronA', 'NeuronC', 'NeuronP', 'NeuronS', '-v7.3');
    
    fprintf('全部完成！\n');
end

%% 
clear
close all
clc
load('NewMr_results.mat');
    NeuronA = reshape(neuron.A,Ysiz(1),Ysiz(2),[]);
    NeuronA_peak = squeeze(max(max(NeuronA, [], 1), [], 2));
    

    figure
    plot(NeuronA_peak)
    xlabel('Neuron ID')
    ylabel('峰值亮度')


    neuronID = reshape(1:size(NeuronA,3), [], 1);
    NeuronA_peak2 = horzcat(neuronID, NeuronA_peak);

    NeuronA_peak2_sorted = sortrows(NeuronA_peak2, 2, 'ascend');

    figure
 y = 1:size(NeuronA,3);
 x = NeuronA_peak2_sorted(:,2);
 plot(x,y);
hold on
 noise_threshold = 0.32;
xline(noise_threshold, 'r', 'LineWidth', 2);


    %%
    noise = [];
    neuron_ture = setdiff(1:size(NeuronA,3), noise);
    NeuronA1 = NeuronA(:,:,neuron_ture);
    SFP1 = max(NeuronA1,[],3);
   figure
    imagesc(SFP1);
    % colorbar([0 8])
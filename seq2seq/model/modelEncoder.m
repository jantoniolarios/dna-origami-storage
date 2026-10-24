function [Z,hiddenState] = modelEncoder(parameters,X,sequenceLengths)

weights = parameters.emb.Weights;
Z = embed(X,weights,DataFormat="CBT");

inputWeights = parameters.lstm.InputWeights;
recurrentWeights = parameters.lstm.RecurrentWeights;
bias = parameters.lstm.Bias;

numHiddenUnits = size(recurrentWeights, 2);
initialHiddenState = dlarray(zeros([numHiddenUnits 1]));
initialCellState = dlarray(zeros([numHiddenUnits 1]));

[Z,hiddenState] = lstm(Z,initialHiddenState,initialCellState,inputWeights, ...
    recurrentWeights,bias,DataFormat="CBT");

if ~isempty(sequenceLengths)
    miniBatchSize = size(Z,2);
    for n = 1:miniBatchSize
        hiddenState(:,n) = Z(:,n,sequenceLengths(n));
    end
end

end

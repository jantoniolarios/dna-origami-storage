function [Y,context,hiddenState,attentionScores] = modelDecoder(parameters,X,context, ...
    hiddenState,Z,dropout)

weights = parameters.emb.Weights;
X = embed(X,weights,DataFormat="CBT");

sequenceLength = size(X,3);
Y = cat(1, X, repmat(context,[1 1 sequenceLength]));

inputWeights = parameters.lstm.InputWeights;
recurrentWeights = parameters.lstm.RecurrentWeights;
bias = parameters.lstm.Bias;

initialCellState = dlarray(zeros(size(hiddenState)));

[Y,hiddenState] = lstm(Y,hiddenState,initialCellState, ...
    inputWeights,recurrentWeights,bias,DataFormat="CBT");

mask = rand(size(Y),"like",Y) > dropout;
Y = Y.*mask;

weights = parameters.attention.Weights;
[context,attentionScores] = luongAttention(hiddenState,Z,weights);

Y = cat(1, Y, repmat(context,[1 1 sequenceLength]));

weights = parameters.fc.Weights;
bias = parameters.fc.Bias;
Y = fullyconnect(Y,weights,bias,DataFormat="CBT");

Y = softmax(Y,DataFormat="CBT");

end
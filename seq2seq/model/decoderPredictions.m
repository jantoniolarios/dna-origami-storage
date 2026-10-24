function Y = decoderPredictions(parameters,Z,T,hiddenState,dropout, ...
    doTeacherForcing,sequenceLength)

T = dlarray(T);

miniBatchSize = size(T,2);
numHiddenUnits = size(Z,1);
context = zeros([numHiddenUnits miniBatchSize],"like",Z);

if doTeacherForcing
    Y = modelDecoder(parameters,T,context,hiddenState,Z,dropout);
else
    decoderInput = T(:,:,1);

    numClasses = numel(parameters.fc.Bias);
    Y = zeros([numClasses miniBatchSize sequenceLength],"like",decoderInput);

    for t = 1:sequenceLength
        [Y(:,:,t), context, hiddenState] = modelDecoder(parameters,decoderInput,context, ...
            hiddenState,Z,dropout);

        [~, decoderInput] = max(Y(:,:,t),[],1);
    end
end

end
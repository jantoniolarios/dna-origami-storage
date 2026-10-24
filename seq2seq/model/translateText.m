function strTranslated = translateText(parameters,strSource,maxSequenceLength,miniBatchSize, ...
    encSource,encTarget,startToken,stopToken,delimiter)

documentsSource = transformText(strSource,startToken,stopToken);
sequencesSource = doc2sequence(encSource,documentsSource, ...
    PaddingDirection="right", ...
    PaddingValue=encSource.NumWords + 1);

X = cat(3,sequencesSource{:});
X = permute(X,[1 3 2]);
X = dlarray(X);

numObservations = numel(strSource);
strTranslated = strings(numObservations,1);

numIterations = ceil(numObservations / miniBatchSize);
for i = 1:numIterations
    idxMiniBatch = (i-1)*miniBatchSize+1:min(i*miniBatchSize,numObservations);
    miniBatchSize = numel(idxMiniBatch);

    sequenceLengths = [];
    [Z, hiddenState] = modelEncoder(parameters.encoder,X(:,idxMiniBatch,:),sequenceLengths);

    doTeacherForcing = false;
    dropout = 0;
    decoderInput = repmat(word2ind(encTarget,startToken),[1 miniBatchSize]);
    decoderInput = dlarray(decoderInput);
    Y = decoderPredictions(parameters.decoder,Z,decoderInput,hiddenState,dropout, ...
        doTeacherForcing,maxSequenceLength);
    [~, idxPred] = max(extractdata(Y),[],1);

    idxStop = word2ind(encTarget,stopToken);
    keepTranslating = idxPred ~= idxStop;

    t = 1;
    while t <= maxSequenceLength && any(keepTranslating(:,:,t))

        newWords = ind2word(encTarget, idxPred(:,:,t))';
        idxUpdate = idxMiniBatch(keepTranslating(:,:,t));
        strTranslated(idxUpdate) = strTranslated(idxUpdate) + delimiter + newWords(keepTranslating(:,:,t));

        t = t + 1;
    end
end

end
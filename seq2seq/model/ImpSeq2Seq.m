function outputText = ImpSeq2Seq(inputText, parameters, encSource, encTarget)
    startToken = "<start>";
    stopToken = "<stop>";
    maxSequenceLength = 20;
    miniBatchSize = 1;
    delimiter = "";

    inputText = char(inputText);
    inputLength = length(inputText);
    numBlocks = ceil(inputLength / 4);

    paddedInput = [inputText, repmat(' ', 1, numBlocks * 4 - inputLength)];
    blocks = reshape(paddedInput, 4, []).';

    translatedBlocks = strings(numBlocks, 1);
    for i = 1:numBlocks
        translatedBlocks(i) = translateText(parameters, blocks(i, :), maxSequenceLength, ...
            miniBatchSize, encSource, encTarget, startToken, stopToken, delimiter);
    end

    outputText = strjoin(translatedBlocks, '');
end

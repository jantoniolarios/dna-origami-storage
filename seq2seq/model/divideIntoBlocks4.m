function blocks = divideIntoBlocks4(inputText)
    inputText = char(inputText);

    inputLength = length(inputText);

    numBlocks = ceil(inputLength / 4);
    paddedInput = [inputText, repmat(' ', 1, numBlocks * 4 - inputLength)];

    blocks = cellstr(reshape(paddedInput, 4, []).');
end
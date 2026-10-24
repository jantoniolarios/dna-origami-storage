function blocks = divideIntoBlocks8(inputText)
    inputText = char(inputText);

    inputLength = length(inputText);

    numBlocks = ceil(inputLength / 8);
    paddedInput = [inputText, repmat(' ', 1, numBlocks * 8 - inputLength)];

    blocks = cellstr(reshape(paddedInput, 8, []).');
end
function [loss,gradients] = modelLoss(parameters,X,T,...
    sequenceLengthsSource,maskTarget,dropout)

[Z,hiddenState] = modelEncoder(parameters.encoder,X,sequenceLengthsSource);

doTeacherForcing = rand < 0.5;
sequenceLength = size(T,3);
Y = decoderPredictions(parameters.decoder,Z,T,hiddenState,dropout,...
    doTeacherForcing,sequenceLength);

Y = Y(:,:,1:end-1);
T = extractdata(gather(T(:,:,2:end)));
T = onehotencode(T,1,ClassNames=1:size(Y,1));

maskTarget = maskTarget(:,:,2:end);
maskTarget = repmat(maskTarget,[size(Y,1),1,1]);

loss = crossentropy(Y,T,Mask=maskTarget,Dataformat="CBT");

gradients = dlgradient(loss,parameters);

end
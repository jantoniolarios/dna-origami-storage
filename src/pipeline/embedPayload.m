function [newTop, stats] = embedPayload(top, payload)
%EMBEDPAYLOAD  Inserta una carga de nucleótidos en la región de staples.
%
%   newTop = EMBEDPAYLOAD(top, payload) devuelve una copia de top en la que
%   los primeros numel(payload) nucleótidos de staples llevan las bases de
%   payload. El resto de la estructura queda exactamente como estaba.
%
%   [newTop, stats] = EMBEDPAYLOAD(...) devuelve además:
%     stats.nWritten   - nucleótidos escritos
%     stats.nChanged   - cuántos de ellos cambiaron de base
%     stats.nUntouched - nucleótidos de staples que quedaron intactos
%     stats.occupancy  - fracción de la región de staples utilizada

if isstring(payload)
    payload = char(payload);
end
payload = reshape(payload, 1, []);

idx = stapleIndices(top);
nStaples = numel(idx);
nPayload = numel(payload);

if nPayload > nStaples
    error('embedPayload:tooLong', ...
        ['El mensaje ocupa %d nucleótidos pero la región de staples solo ' ...
         'tiene %d. Usa una estructura más grande o acorta el texto.'], ...
        nPayload, nStaples);
end

target = idx(1:nPayload);

newTop = top;
nChanged = sum(top.base(target) ~= payload(:));
newTop.base(target) = payload(:);

stats.nWritten   = nPayload;
stats.nChanged   = nChanged;
stats.nUntouched = nStaples - nPayload;
stats.occupancy  = nPayload / nStaples;
end

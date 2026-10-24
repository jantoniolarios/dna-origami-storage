function [payload, report] = buildPayload(text, useLayer2)
%BUILDPAYLOAD  Convierte texto en la carga de nucleótidos lista para insertar.
%
%   payload = BUILDPAYLOAD(text) codifica text con la capa 1 y lo enmarca
%   entre el marcador inicial y el final.
%
%   payload = BUILDPAYLOAD(text, true) aplica además la capa 2 (expansión de
%   4 a 8 nucleótidos por carácter).
%
%   [payload, report] = BUILDPAYLOAD(...) devuelve un informe con:
%     report.nChars     - caracteres codificados
%     report.dropped    - caracteres que no estaban en el alfabeto
%     report.useLayer2  - si se aplicó la capa 2
%     report.ntPerChar  - nucleótidos por carácter (4 u 8)
%     report.nNucleotides - longitud total de la carga


if nargin < 2 || isempty(useLayer2)
    useLayer2 = false;
end

cb = dnaCodebook();
[nt, dropped] = encodeText(text);

payload = [cb.startMarker, nt, cb.endMarker];
if useLayer2
    payload = expandCodons(payload);
end

report.nChars        = numel(nt) / 4;
report.dropped       = dropped;
report.useLayer2     = logical(useLayer2);
report.ntPerChar     = 4 + 4 * double(logical(useLayer2));
report.nNucleotides  = numel(payload);
end

function [text, report] = extractPayload(top, forceLayer2, allowScan)
%EXTRACTPAYLOAD  Recupera el texto almacenado en la región de staples.
%
%   text = EXTRACTPAYLOAD(top) espera el marcador inicial en el primer
%   nucleótido de la región de staples, detecta automáticamente si el mensaje
%   usa la capa 2 y devuelve el texto decodificado.
%
%   text = EXTRACTPAYLOAD(top, true)  fuerza la lectura como capa 2.
%   text = EXTRACTPAYLOAD(top, false) fuerza la lectura como capa 1.
%
%   text = EXTRACTPAYLOAD(top, [], true) busca el marcador por toda la región
%   en vez de exigirlo al principio. Solo hace falta para archivos escritos
%   por otra herramienta: encodeToStructure siempre escribe desde el primer
%   nucleótido, y anclar ahí la búsqueda hace imposible confundir una
%   coincidencia del diseño original con un mensaje real.
%
%   [text, report] = EXTRACTPAYLOAD(...) devuelve además:
%     report.useLayer2     - capa detectada o impuesta
%     report.detected      - true si la capa se dedujo automáticamente
%     report.startOffset   - posición del marcador inicial dentro de la región
%     report.rawBody       - el mensaje tal como está almacenado, sin marcadores
%     report.body          - el mismo mensaje ya colapsado a codones de 4 nt
%     report.nNucleotides  - nucleótidos del cuerpo del mensaje
%     report.nRawNucleotides - nucleótidos tal como se almacenan
%     report.nChars        - caracteres recuperados
%     report.unknownCodons - codones sin equivalente en el codebook

if nargin < 2
    forceLayer2 = [];
end
if nargin < 3 || isempty(allowScan)
    allowScan = false;
end
allowScan = logical(allowScan);

cb = dnaCodebook();
seq = stapleSequence(top);

if isempty(forceLayer2)
    useLayer2 = detectLayer2(seq, cb, allowScan);
    detected = true;
else
    useLayer2 = logical(forceLayer2);
    detected = false;
end

if useLayer2
    startTok = expandCodons(cb.startMarker);
    endTok   = expandCodons(cb.endMarker);
    stride   = 8;
else
    startTok = cb.startMarker;
    endTok   = cb.endMarker;
    stride   = 4;
end

s = findStart(seq, startTok, stride, allowScan);
if isempty(s)
    error('extractPayload:noStart', ...
        ['No se encontró el marcador inicial "%s" al principio de la región ' ...
         'de staples. Puede que la estructura no lleve información ' ...
         'codificada, o que se haya elegido la capa equivocada.'], startTok);
end

if s ~= 1
    warning('extractPayload:offsetStart', ...
        ['El marcador inicial se encontró en el nucleótido %d de la región ' ...
         'de staples y no en el primero. Revisa que el resultado tenga ' ...
         'sentido: podría ser una coincidencia del diseño original.'], s);
end

e = findAligned(seq, endTok, s + numel(startTok), stride);
if isempty(e)
    error('extractPayload:noEnd', ...
        ['Se encontró el marcador inicial pero no el final "%s". ' ...
         'El archivo puede estar truncado o modificado.'], endTok);
end

rawBody = seq(s + numel(startTok) : e - 1);

if useLayer2
    body = collapseCodons(rawBody);
else
    body = rawBody;
end

[text, unknown] = decodeText(body);

report.useLayer2     = useLayer2;
report.detected      = detected;
report.startOffset   = s;
report.rawBody       = rawBody;
report.body          = body;
report.nNucleotides  = numel(body);
report.nRawNucleotides = numel(rawBody);
report.nChars        = numel(text);
report.unknownCodons = unknown;
end

function tf = detectLayer2(seq, cb, allowScan)
tf = false;

expandedStart = expandCodons(cb.startMarker);
expandedEnd   = expandCodons(cb.endMarker);

s = findStart(seq, expandedStart, 8, allowScan);
if isempty(s)
    return
end

e = findAligned(seq, expandedEnd, s + numel(expandedStart), 8);
if isempty(e)
    return
end

tf = isExpanded(seq(s : e + numel(expandedEnd) - 1), 2);
end

function pos = findStart(seq, token, stride, allowScan)
if ~allowScan
    if numel(seq) >= numel(token) && strncmp(seq, token, numel(token))
        pos = 1;
    else
        pos = [];
    end
    return
end

pos = findAligned(seq, token, 1, stride);
end

function pos = findAligned(seq, token, from, stride)
hits = strfind(seq, token);
hits = hits(hits >= from & mod(hits - 1, stride) == 0);

if isempty(hits)
    pos = [];
else
    pos = hits(1);
end
end

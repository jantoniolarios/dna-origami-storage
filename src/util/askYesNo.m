function tf = askYesNo(prompt, defaultValue)
%ASKYESNO  Pregunta de sí o no por consola, tolerante a mayúsculas y acentos.
%
%   tf = ASKYESNO(prompt) repite la pregunta hasta obtener una respuesta
%   válida. 
%   tf = ASKYESNO(prompt, defaultValue) acepta además una respuesta vacía y
%   devuelve defaultValue en ese caso.

hasDefault = nargin >= 2 && ~isempty(defaultValue);

if hasDefault
    if defaultValue
        hint = ' [S/n]: ';
    else
        hint = ' [s/N]: ';
    end
else
    hint = ' [s/n]: ';
end

while true
    answer = lower(strtrim(input([prompt hint], 's')));

    if isempty(answer) && hasDefault
        tf = logical(defaultValue);
        return
    end
    if ~isempty(answer) && any(answer(1) == 'sy')
        tf = true;
        return
    end
    if ~isempty(answer) && answer(1) == 'n'
        tf = false;
        return
    end

    fprintf('  Responde s (sí) o n (no).\n');
end
end

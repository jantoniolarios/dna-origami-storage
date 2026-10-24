function sel = chooseStructure(list, needChars, useLayer2)
%CHOOSESTRUCTURE  Menú interactivo para elegir una estructura de origami.
%
%   sel = CHOOSESTRUCTURE(list) muestra el catálogo devuelto por
%   LISTSTRUCTURES y pide al usuario que elija una.
%
%   sel = CHOOSESTRUCTURE(list, needChars, useLayer2) marca además que
%   estructuras tienen capacidad suficiente para un mensaje de needChars
%   caracteres con la capa indicada, y rechaza las que no.

if nargin < 2, needChars = []; end
if nargin < 3, useLayer2 = false; end

if isempty(list)
    error('chooseStructure:empty', ...
        ['No hay ningún archivo .top en la carpeta structures/. ' ...
         'Copia ahí los diseños de origami que quieras usar.']);
end

if useLayer2
    capacity = [list.capacityLayer2];
    capLabel = 'capa 2';
else
    capacity = [list.capacityLayer1];
    capLabel = 'capa 1';
end

fprintf('\nEstructuras disponibles (capacidad en %s):\n\n', capLabel);
fprintf('  %-4s %-24s %12s %12s\n', 'num', 'estructura', 'nt staples', 'caracteres');
fprintf('  %s\n', repmat('-', 1, 56));
for k = 1:numel(list)
    if isempty(needChars) || capacity(k) >= needChars
        mark = ' ';
    else
        mark = '!';
    end
    fprintf('%s %-4d %-24s %12d %12d\n', mark, k, list(k).name, ...
        list(k).nStaples, capacity(k));
end

if ~isempty(needChars)
    fprintf('\n  El mensaje necesita %d caracteres.', needChars);
    if any(capacity < needChars)
        fprintf(' Las marcadas con ! no tienen sitio suficiente.');
    end
    fprintf('\n');
end

while true
    answer = input(sprintf('\nNúmero de estructura (0 para cancelar): '), 's');
    choice = str2double(strtrim(answer));

    if isnan(choice) || choice ~= fix(choice)
        fprintf('  Escribe un número entero.\n');
        continue
    end
    if choice == 0
        sel = [];
        return
    end
    if choice < 1 || choice > numel(list)
        fprintf('  Elige un número entre 1 y %d.\n', numel(list));
        continue
    end
    if ~isempty(needChars) && capacity(choice) < needChars
        fprintf(['  "%s" solo admite %d caracteres y el mensaje tiene %d. ' ...
                 'Elige otra.\n'], list(choice).name, capacity(choice), needChars);
        continue
    end

    sel = list(choice);
    return
end
end

function settings = askNoiseSettings()
%ASKNOISESETTINGS  Pregunta por consola qué ruido aplicar a la cadena.
%
%   settings = ASKNOISESETTINGS() devuelve una estructura con los campos
%   Substitution, Deletion, Insertion y Seed, lista para pasar a INJECTNOISE.

settings = [];

fprintf('\n--- Simulación de errores de síntesis -----------\n');
fprintf('En simulación la recuperación es perfecta, lo que no dice nada\n');
fprintf('sobre qué pasaría con una cadena sintetizada de verdad.\n\n');
fprintf('  Sustitución: cambia una base por otra. Daña un carácter.\n');
fprintf('  Eliminación: quita una base. Corre el marco de lectura.\n');
fprintf('  Inserción  : añade una base. Corre el marco de lectura.\n');

if ~askYesNo(sprintf('\nAplicar ruido a la cadena antes de decodificar?'), false)
    return
end

fprintf('\nPorcentajes sobre la longitud de la cadena. Enter deja 0.\n');

settings.Substitution = askPercent('  Sustitución (%)');
settings.Deletion     = askPercent('  Eliminación (%)');
settings.Insertion    = askPercent('  Inserción   (%)');

if settings.Substitution + settings.Deletion + settings.Insertion == 0
    fprintf('\nTodos los porcentajes son 0: no se aplica ruido.\n');
    settings = [];
    return
end

settings.Seed = askSeed('  Semilla aleatoria [0]');
end

function value = askPercent(prompt)
while true
    answer = strtrim(input([prompt ': '], 's'));
    if isempty(answer)
        value = 0;
        return
    end

    number = str2double(strrep(answer, ',', '.'));
    if isnan(number) || number < 0 || number > 100
        fprintf('    Escribe un número entre 0 y 100.\n');
        continue
    end

    value = number / 100;
    return
end
end

function value = askSeed(prompt)
while true
    answer = strtrim(input([prompt ': '], 's'));
    if isempty(answer)
        value = 0;
        return
    end

    number = str2double(answer);
    if isnan(number) || number ~= fix(number) || number < 0
        fprintf('    Escribe un entero no negativo.\n');
        continue
    end

    value = number;
    return
end
end

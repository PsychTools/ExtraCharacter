selectCharacter = 'bf'

local config = {
    tag = 'extraCharacter',
    x = 1650,
    y = 825,
    scaleX = 1,
    scaleY = 1,
    alpha = 1,
    side = 'player',
    teamplay = true,
    noteType = '',
    altNoteType = '',
    layer = 'front',
    flipX = nil,
    dance = true,
    hideOriginal = false
}

local directions = {
    'LEFT',
    'DOWN',
    'UP',
    'RIGHT'
}

local ready = false
local holdTimer = 0
local singing = false
local specialAnimation = false
local lastAnimation = ''

local function escapeHaxe(value)
    return '"' .. tostring(value)
        :gsub('\\', '\\\\')
        :gsub('"', '\\"')
        :gsub('\n', '\\n')
        :gsub('\r', '\\r') .. '"'
end

local function characterPath(property)
    return config.tag .. '.' .. property
end

local function exists()
    return getVar(config.tag) ~= nil
end

local function hasAnimation(name)
    if not ready then
        return false
    end

    return runHaxeCode([[
        var character = game.variables.get(]] .. escapeHaxe(config.tag) .. [[);
        return character != null
            && character.animation.getByName(]] .. escapeHaxe(name) .. [[) != null;
    ]]) == true
end

local function playAnimation(name, force)
    if not ready or not hasAnimation(name) then
        return false
    end

    runHaxeCode([[
        var character = game.variables.get(]] .. escapeHaxe(config.tag) .. [[);

        if (character != null)
            character.playAnim(
                ]] .. escapeHaxe(name) .. [[,
                ]] .. tostring(force ~= false) .. [[
            );
    ]])

    lastAnimation = name
    return true
end

local function dance()
    if not ready or not config.dance then
        return
    end

    runHaxeCode([[
        var character = game.variables.get(]] .. escapeHaxe(config.tag) .. [[);

        if (character != null)
        {
            character.specialAnim = false;
            character.dance();
        }
    ]])

    singing = false
    holdTimer = 0
end

local function shouldSing(noteType)
    if config.noteType ~= '' and noteType == config.noteType then
        return true
    end

    if config.altNoteType ~= '' and noteType == config.altNoteType then
        return true
    end

    return config.teamplay
end

local function sing(direction, noteType, miss)
    if not ready or not shouldSing(noteType) then
        return
    end

    local directionName = directions[direction + 1]

    if directionName == nil then
        return
    end

    local base = 'sing' .. directionName
    local animation = base

    if miss then
        animation = base .. 'miss'
    elseif config.altNoteType ~= '' and noteType == config.altNoteType then
        animation = base .. '-alt'
    end

    if not hasAnimation(animation) then
        animation = base
    end

    if playAnimation(animation, true) then
        singing = true
        specialAnimation = false
        holdTimer = 0
    end
end

local function createCharacter()
    local tag = escapeHaxe(config.tag)
    local character = escapeHaxe(selectCharacter)
    local isPlayer = tostring(config.side == 'player')

    local code = [[
        import objects.Character;

        var character = new Character(
            ]] .. config.x .. [[,
            ]] .. config.y .. [[,
            ]] .. character .. [[,
            ]] .. isPlayer .. [[
        );

        game.variables.set(]] .. tag .. [[, character);

        switch (]] .. escapeHaxe(config.layer) .. [[)
        {
            case "behind":
                game.insert(
                    game.members.indexOf(game.gfGroup),
                    character
                );

            case "front":
                game.add(character);

            case "dad":
                game.insert(
                    game.members.indexOf(game.dadGroup) + 1,
                    character
                );

            case "boyfriend":
                game.insert(
                    game.members.indexOf(game.boyfriendGroup) + 1,
                    character
                );

            default:
                game.add(character);
        }
    ]]

    runHaxeCode(code)
end

function onCreatePost()
    createCharacter()

    ready = exists()

    if not ready then
        debugPrint('Extra Character: failed to load ' .. selectCharacter)
        return
    end

    local jsonScale = getProperty(characterPath('jsonScale')) or 1

    scaleObject(
        config.tag,
        jsonScale * config.scaleX,
        jsonScale * config.scaleY
    )

    setProperty(characterPath('alpha'), config.alpha)

    if config.flipX ~= nil then
        setProperty(characterPath('flipX'), config.flipX)
    end

    if config.hideOriginal then
        if config.side == 'player' then
            setProperty('boyfriend.visible', false)
        else
            setProperty('dad.visible', false)
        end
    end

    dance()
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if config.side ~= 'player' then
        return
    end

    sing(direction, noteType, false)
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    if config.side ~= 'opponent' then
        return
    end

    sing(direction, noteType, false)
end

function noteMiss(id, direction, noteType, isSustainNote)
    if config.side ~= 'player' then
        return
    end

    sing(direction, noteType, true)
end

function onUpdate(elapsed)
    if not ready then
        return
    end

    if specialAnimation then
        local finished = getProperty(
            characterPath('animation.curAnim.finished')
        )

        if finished then
            specialAnimation = false
            dance()
        end

        return
    end

    if singing then
        holdTimer = holdTimer + elapsed

        local duration = getProperty(
            characterPath('singDuration')
        ) or 4

        local beatLength = (stepCrochet or 125) * 0.004

        if holdTimer >= beatLength * duration then
            singing = false
            holdTimer = 0
            dance()
        end
    end
end

function onBeatHit()
    if not ready or singing or specialAnimation then
        return
    end

    local danceEvery = getProperty(
        characterPath('danceEveryNumBeats')
    ) or 2

    if danceEvery > 0 and curBeat % danceEvery == 0 then
        dance()
    end
end

function onCountdownTick(counter)
    if ready and not singing then
        dance()
    end
end

function onEvent(name, value1, value2)
    if name == 'ToggleTeamplay' then
        if value1 ~= config.tag then
            return
        end

        local value = string.lower(value2 or '')

        if value == '' then
            config.teamplay = not config.teamplay
        elseif value == 'true' or value == '1' then
            config.teamplay = true
        elseif value == 'false' or value == '0' then
            config.teamplay = false
        end

    elseif name == 'CharacterPlayAnimation' then
        if value2 ~= config.tag then
            return
        end

        if playAnimation(value1, true) then
            specialAnimation = true
            singing = false
            holdTimer = 0
        end

    elseif name == 'ExtraCharacterChange' then
        if value1 ~= config.tag or value2 == '' then
            return
        end

        selectCharacter = value2

        runHaxeCode([[
            var character = game.variables.get(
                ]] .. escapeHaxe(config.tag) .. [[
            );

            if (character != null)
                character.changeCharacter(
                    ]] .. escapeHaxe(selectCharacter) .. [[
                );
        ]])

        singing = false
        specialAnimation = false
        holdTimer = 0
        dance()
    end
end

function onDestroy()
    if not ready then
        return
    end

    runHaxeCode([[
        var character = game.variables.get(
            ]] .. escapeHaxe(config.tag) .. [[
        );

        if (character != null)
        {
            game.remove(character, true);
            game.variables.remove(
                ]] .. escapeHaxe(config.tag) .. [[
            );
            character.destroy();
        }
    ]])

    ready = false
end

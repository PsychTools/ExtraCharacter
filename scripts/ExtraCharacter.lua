selectCharacter = 'bf'

local config = {
    tag = 'extraCharacter',

    x = 1650,
    y = 825,

    scaleX = 1,
    scaleY = 1,

    alpha = 1,
    flipX = nil,

    side = 'player',
    teamplay = true,

    noteType = '',
    altNoteType = '',

    layer = 'front',

    dance = true,
    danceSpeed = 1,

    hideOriginal = false,

    singDuration = 4,
    sustainHold = true,

    missAnimations = true,
    fallbackAnimations = true,

    debug = false
}

local directions = {
    'LEFT',
    'DOWN',
    'UP',
    'RIGHT'
}

local state = {
    ready = false,
    singing = false,
    special = false,
    holdTimer = 0,
    lastAnimation = '',
    lastDirection = -1,
    character = selectCharacter,
    originalVisible = nil
}

local function log(message)
    if config.debug then
        debugPrint('[ExtraCharacter] ' .. tostring(message))
    end
end

local function escapeHaxe(value)
    local result = tostring(value)
    result = result:gsub('\\', '\\\\')
    result = result:gsub('"', '\\"')
    result = result:gsub('\n', '\\n')
    result = result:gsub('\r', '\\r')
    return '"' .. result .. '"'
end

local function haxe(code)
    return runHaxeCode(code)
end

local function characterCode(code)
    return haxe([[
        var character = game.variables.get(
            ]] .. escapeHaxe(config.tag) .. [[
        );

        if (character != null) {
    ]] .. code .. [[
        }
    ]])
end

local function exists()
    return haxe([[
        return game.variables.exists(
            ]] .. escapeHaxe(config.tag) .. [[
        );
    ]]) == true
end

local function getCharacterProperty(property)
    return haxe([[
        var character = game.variables.get(
            ]] .. escapeHaxe(config.tag) .. [[
        );

        if (character == null) return null;

        return Reflect.getProperty(
            character,
            ]] .. escapeHaxe(property) .. [[
        );
    ]])
end

local function hasAnimation(name)
    if not state.ready then
        return false
    end

    return haxe([[
        var character = game.variables.get(
            ]] .. escapeHaxe(config.tag) .. [[
        );

        return character != null
            && character.animation != null
            && character.animation.getByName(
                ]] .. escapeHaxe(name) .. [[
            ) != null;
    ]]) == true
end

local function playAnimation(name, force)
    if not hasAnimation(name) then
        return false
    end

    characterCode([[
        character.playAnim(
            ]] .. escapeHaxe(name) .. [[,
            ]] .. tostring(force ~= false) .. [[
        );
    ]])

    state.lastAnimation = name
    return true
end

local function resetSinging()
    state.singing = false
    state.holdTimer = 0
    state.lastDirection = -1
end

local function dance()
    if not state.ready then
        return
    end

    if not config.dance or state.special then
        return
    end

    characterCode([[
        character.specialAnim = false;
        character.dance();
    ]])

    resetSinging()
end

local function matchesNote(noteType)
    noteType = noteType or ''

    if config.noteType ~= '' then
        if noteType == config.noteType then
            return true
        end

        return config.altNoteType ~= ''
            and noteType == config.altNoteType
    end

    if config.altNoteType ~= ''
        and noteType == config.altNoteType then
        return true
    end

    return config.teamplay
end

local function getSingAnimation(direction, noteType, miss)
    local directionName = directions[direction + 1]

    if not directionName then
        return nil
    end

    local base = 'sing' .. directionName

    if miss and config.missAnimations then
        return base .. 'miss'
    end

    if config.altNoteType ~= ''
        and noteType == config.altNoteType then
        return base .. '-alt'
    end

    return base
end

local function sing(direction, noteType, miss, sustain)
    if not state.ready or state.special then
        return
    end

    if not matchesNote(noteType) then
        return
    end

    local animation = getSingAnimation(
        direction,
        noteType,
        miss
    )

    if not animation then
        return
    end

    if not hasAnimation(animation)
        and config.fallbackAnimations then
        animation = 'sing' .. directions[direction + 1]
    end

    if not hasAnimation(animation) then
        return
    end

    local shouldRestart = true

    if sustain and config.sustainHold then
        if state.lastAnimation == animation then
            shouldRestart = false
        end
    end

    if shouldRestart then
        playAnimation(animation, true)
    end

    state.singing = true
    state.holdTimer = 0
    state.lastDirection = direction
end

local function applyProperties()
    if not state.ready then
        return
    end

    characterCode([[
        character.scale.set(
            character.jsonScale * ]] .. config.scaleX .. [[,
            character.jsonScale * ]] .. config.scaleY .. [[
        );

        character.updateHitbox();

        character.alpha = ]] .. config.alpha .. [[;

        character.danceEveryNumBeats = Math.max(
            1,
            Std.int(
                character.danceEveryNumBeats
                / ]] .. math.max(0.01, config.danceSpeed) .. [[
            )
        );
    ]])

    if config.flipX ~= nil then
        characterCode([[
            character.flipX =
                ]] .. tostring(config.flipX) .. [[;
        ]])
    end

    if config.hideOriginal then
        local original = config.side == 'player'
            and 'boyfriend'
            or 'dad'

        if state.originalVisible == nil then
            state.originalVisible = getProperty(
                original .. '.visible'
            )
        end

        setProperty(original .. '.visible', false)
    end
end

local function createCharacter()
    local player = config.side == 'player'

    local created = haxe([[
        var tag = ]] .. escapeHaxe(config.tag) .. [[;

        if (game.variables.exists(tag)) {
            return false;
        }

        var character = new Character(
            ]] .. config.x .. [[,
            ]] .. config.y .. [[,
            ]] .. escapeHaxe(state.character) .. [[,
            ]] .. tostring(player) .. [[
        );

        if (character == null) {
            return false;
        }

        game.variables.set(tag, character);

        var layer = ]] .. escapeHaxe(config.layer) .. [[;

        var target = null;

        switch (layer) {
            case "behind":
                target = game.gfGroup;

            case "dad":
                target = game.dadGroup;

            case "boyfriend":
                target = game.boyfriendGroup;
        }

        if (target != null) {
            var index = game.members.indexOf(target);

            if (index >= 0) {
                var insertIndex = index;

                if (layer != "behind") {
                    insertIndex++;
                }

                game.insert(insertIndex, character);
            } else {
                game.add(character);
            }
        } else {
            game.add(character);
        }

        return true;
    ]])

    return created == true
end

local function changeCharacter(name)
    if not state.ready or name == nil or name == '' then
        return
    end

    if name == state.character then
        return
    end

    characterCode([[
        character.changeCharacter(
            ]] .. escapeHaxe(name) .. [[
        );
    ]])

    state.character = name
    state.lastAnimation = ''
    state.special = false

    resetSinging()
    applyProperties()
    dance()

    log('Changed character to: ' .. name)
end

function onCreatePost()
    if not createCharacter() then
        debugPrint(
            '[ExtraCharacter] Creation failed: '
            .. state.character
        )
        return
    end

    state.ready = exists()

    if not state.ready then
        debugPrint(
            '[ExtraCharacter] Character not found: '
            .. state.character
        )
        return
    end

    applyProperties()
    dance()

    log('Loaded: ' .. state.character)
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if config.side == 'player' then
        sing(direction, noteType, false, isSustainNote)
    end
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    if config.side == 'opponent' then
        sing(direction, noteType, false, isSustainNote)
    end
end

function noteMiss(id, direction, noteType, isSustainNote)
    if config.side == 'player' then
        sing(direction, noteType, true, isSustainNote)
    end
end

function onUpdate(elapsed)
    if not state.ready then
        return
    end

    if state.special then
        local finished = haxe([[
            var character = game.variables.get(
                ]] .. escapeHaxe(config.tag) .. [[
            );

            return character != null
                && character.animation.curAnim != null
                && character.animation.curAnim.finished;
        ]])

        if finished == true then
            state.special = false
            dance()
        end

        return
    end

    if state.singing then
        state.holdTimer = state.holdTimer + elapsed

        local beatLength = (stepCrochet or 125) * 0.001
        local duration = beatLength * config.singDuration

        if state.holdTimer >= duration then
            resetSinging()
            dance()
        end
    end
end

function onBeatHit()
    if not state.ready
        or state.singing
        or state.special
        or not config.dance then
        return
    end

    local danceEvery = getCharacterProperty(
        'danceEveryNumBeats'
    ) or 2

    danceEvery = math.max(1, danceEvery)

    if curBeat % danceEvery == 0 then
        dance()
    end
end

function onCountdownTick(counter)
    if state.ready
        and not state.singing
        and not state.special then
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

        log('Teamplay: ' .. tostring(config.teamplay))

    elseif name == 'CharacterPlayAnimation' then
        if value2 ~= config.tag then
            return
        end

        if playAnimation(value1, true) then
            state.special = true
            resetSinging()
        end

    elseif name == 'ExtraCharacterChange' then
        if value1 == config.tag then
            changeCharacter(value2)
        end

    elseif name == 'ExtraCharacterAlpha' then
        if value1 ~= config.tag then
            return
        end

        local alpha = tonumber(value2)

        if alpha then
            config.alpha = math.max(
                0,
                math.min(1, alpha)
            )

            characterCode([[
                character.alpha =
                    ]] .. config.alpha .. [[;
            ]])
        end

    elseif name == 'ExtraCharacterDance' then
        if value1 == config.tag then
            state.special = false
            dance()
        end
    end
end

function onDestroy()
    if not state.ready then
        return
    end

    if config.hideOriginal
        and state.originalVisible ~= nil then

        local original = config.side == 'player'
            and 'boyfriend'
            or 'dad'

        setProperty(
            original .. '.visible',
            state.originalVisible
        )
    end

    characterCode([[
        game.remove(character, true);
        game.variables.remove(
            ]] .. escapeHaxe(config.tag) .. [[
        );
        character.destroy();
    ]])

    state.ready = false
end

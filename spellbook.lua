local chat = require('chat')
local command = require('command')
local player = require('player')
local resources = require('resources')
local spells_known = require('spells_known')
local string = require('string')
local table = require('table')
local ui = require('ui')

local spell_types = {
    whitemagic  = { type = 'WhiteMagic',    readable = 'White Magic spells' },
    blackmagic  = { type = 'BlackMagic',    readable = 'Black Magic spells' },
    songs       = { type = 'BardSong',      readable = 'Bard songs' },
    ninjutsu    = { type = 'Ninjutsu',      readable = 'Ninjutsu' },
    summoning   = { type = 'SummonerPact',  readable = 'Summoning spells' },
    bluemagic   = { type = 'BlueMagic',     readable = 'Blue Magic spells' },
    geomancy    = { type = 'Geomancy',      readable = 'Geomancy spells' },
    trusts      = { type = 'Trust',         readable = 'Trusts'},
    all         = { type = 'all',           readable = 'spells of all types'}
}

local display_help = function()
    print('display_help')
end

local handle_current = function(all)
    local spells = resources.spells
    local main_id = player.main_job_id
    local main_level = player.main_job_level
    local sub_id = player.sub_job_id
    local sub_level = player.sub_job_level
    local learnable_spells = {}
    local learnable_spell_count = 0

    for spell_id, spell in pairs(spells) do
        if spell.type ~= 'Trust' and not spells_known[spell_id] then
            if not spell.unlearnable then
                local main_learns_at
                local sub_learns_at
                local learned_at

                if spell.levels[main_id] and (main_level >= spell.levels[main_id] or all) then
                    main_learns_at = spell.levels[main_id]
                elseif spell.levels[sub_id] and (sub_level >= spell.levels[sub_id] * 2 or all) then
                    sub_learns_at = spell.levels[sub_id]
                end

                if main_learns_at and sub_learns_at then
                    if main_learns_at > sub_learns_at * 2 then
                        learned_at = sub_learns_at * 2
                    else
                        learned_at = main_learns_at
                    end
                elseif main_learns_at then
                    learned_at = main_learns_at
                elseif sub_learns_at then
                    learned_at = sub_learns_at * 2
                end

                if learned_at then
                    if not learnable_spells[learned_at] then
                        learnable_spells[learned_at] = {}
                    end

                    table.insert(learnable_spells[learned_at],spell.en)
                    learnable_spell_count = learnable_spell_count + 1
                end
            end
        end
    end

    if learnable_spell_count == 0 then
        print(string.format('There are no learnable spells for %s%s/%s%s.',
            resources.jobs[main_id].ens, main_level,
            resources.jobs[sub_id].ens, sub_level))
    else
        if all then
            print(string.format('There are %s unknown spells for %s99/%s49.',
                resources.jobs[main_id].ens, resources.jobs[sub_id].ens))
        else
            print(string.format('There are %s learnable spells for %s%s/%s%s.',
                learnable_spell_count,
                resources.jobs[main_id].ens, main_level,
                resources.jobs[sub_id].ens, sub_level))
        end

        for k,v in pairs(learnable_spells) do
            table.sort(v)
            print(string.format('%s: %s', k, table.concat(v,', ')))
        end
    end
end

local handle_job = function(job, level)
    local spells = resources.spells
    local learnable_spells = {}
    local learnable_spell_count = 0
    for spell_id, spell in pairs(spells) do
        if spell.levels[job] and level >= spell.levels[job] and
            not spell.unlearnable and spell.type ~= 'Trust' and
            not spells_known[spell_id] then

            if not learnable_spells[spell.levels[job]] then
                learnable_spells[spell.levels[job]] = {}
            end
            table.insert(learnable_spells[spell.levels[job]],spell.en)
            learnable_spell_count = learnable_spell_count + 1
        end
    end

    if learnable_spell_count == 0 then
        print(string.format('There are no learnable spells for %s%s.',
            resources.jobs[job].ens, level))
    else
        print(string.format('There are %s learnable spells for %s%s.',
            learnable_spell_count, resources.jobs[job].ens, level))
        for i=1,1500 do
            if learnable_spells[i] then
                print(string.format('%s: %s', i, table.concat(learnable_spells[i],', ')))
            end
        end
    end
end

local handle_spell_type
do
    local format_spell = function(spell)
        local jobs = {}
        local levels = {}
        
        for job_id,_ in pairs(spell.levels) do
            table.insert(jobs, job_id)
        end
        table.sort(jobs)

        for _,job_id in ipairs(jobs) do
            table.insert(levels, resources.jobs[job_id].ens .. ' Lv.' .. tostring(spell.levels[job_id]))
        end

        table.sort(levels)
        local output = table.concat(levels,' / ')
        return string.format('%-20s %s', spell.en, output)
    end

    local is_learnable = function(spell)
        if spell.unlearnable then
            return false
        end

        for k,v in pairs(spell.levels) do
            if player.job_levels[k] >= v then
                return true
            end
        end

        return false
    end

    handle_spell_type = function(category, all)
        if all and all ~= 'all' then
            display_help()
            return
        end

        local type = spell_types[category]
        local spells = resources.spells
        local learnable_spells = {}
        local learnable_spell_count = 0

        for spell_id,spell in pairs(spells) do
            if spell.type == type.type and (is_learnable(spell) or all == 'all') and
                (spell.type ~= 'Trust' or type.type == 'Trust')
                and not spell.unlearnable and not spells_known[spell_id] then

                table.insert(learnable_spells,format_spell(spell))
                learnable_spell_count = learnable_spell_count + 1
            end
        end

        if learnable_spell_count == 0 then
            print(string.format('There are no learnable %s.', type.readable))
        else
            print(string.format('There are %s learnable %s.', learnable_spell_count, type.readable))
            table.sort(learnable_spells)
            for _,spell in pairs(learnable_spells) do
                print(spell)
            end
        end
    end
end

local handle_command
do
    local jobs_by_ens = {}
    for i,v in pairs(resources.jobs) do
        local ens = string.lower(v.ens)
        jobs_by_ens[ens] = i
    end
    
    handle_command = function(command, args)
        if command then
            command = command:lower()
        else
            command = 'current'
        end

        if command == 'cur' or command == 'current' then
            handle_current(args)
        elseif command == 'main' then
            if not args then
                handle_job(player.main_job_id, player.main_job_level)
            elseif args == 'all' then
                handle_job(player.main_job_id, 1500)
            else
                local level = tonumber(args)
                if level and level>0 and level<=1500 then
                    handle_job(player.main_job_id,level)
                else
                    display_help()
                end
            end
        elseif command == 'sub' then
            if not args then
                handle_job(player.sub_job_id, player.sub_job_level)
            elseif args == 'all' then
                handle_job(player.sub_job_id, 1500)
            else
                local level = tonumber(args)
                if level and level>0 and level<=1500 then
                    handle_job(player.sub_job_id,level)
                else
                    display_help()
                end
            end
        elseif jobs_by_ens[command] then
            local job = jobs_by_ens[command]
            if not args then
                handle_job(job, player.job_levels[job])
            elseif args == 'all' then
                handle_job(job, 1500)
            else
                local level = tonumber(args)
                if level and level>0 and level<=1500 then
                    handle_job(job,level)
                else
                    display_help()
                end
            end
        elseif spell_types[command] then
            handle_spell_type(command, args)
        else
            display_help()
        end
    end
end

local spellbook = command.new('spellbook')
spellbook:register(handle_command,'[command=current] [*]')

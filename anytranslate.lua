local mod = {}

-- Anycomplete
function mod.letstranslate()
    local TRANS_ENDPOINT = 'https://translate.yandex.net/api/v1.5/tr.json/detect?'
    local DICT_ENDPOINT = "https://dictionary.yandex.net/api/v1/dicservice.json/lookup?"

    local current = hs.application.frontmostApplication()
    local tab = nil
    local copy = nil
    local choices = {}

    -- Insert your keys here
    local TRANS_API_KEY = ""
    local DICT_API_KEY = ""
        
    -- Define the language you want to use
    local NATIVE_LANG = "de"
    local INTO_LANG = "en"
    local LANG_HINTS = "de,en"

    local chooser = hs.chooser.new(function(chosen)
        if copy then copy:delete() end
        if tab then tab:delete() end
        if chosen ~= nil then
            current:activate()
            hs.eventtap.keyStrokes(chosen.text)
        end
  
    end)

    -- Removes all items in list
    function reset()
        chooser:choices({})
    end

    tab = hs.hotkey.bind('', 'tab', function()
        local id = chooser:selectedRow()
        local item = choices[id]
        -- If no row is selected, but tab was pressed
        if not item then return end
        chooser:query(item.text)
        reset()
        updateChooser()
    end)

    copy = hs.hotkey.bind('cmd', 'c', function()
        local id = chooser:selectedRow()
        local item = choices[id]
        if item then
            chooser:hide()
            hs.pasteboard.setContents(item.text)
            hs.alert.show("Copied to clipboard", 1)
        else
            hs.alert.show("No search result to copy", 1)
        end
    end)

    function updateChooser()
        local string = chooser:query()
        local query = hs.http.encodeForQuery(string)
        -- Reset list when no query is given
        if string:len() == 0 then return reset() end

        local trans_query = TRANS_ENDPOINT .. "key=" .. TRANS_API_KEY .. "&text=" .. query .. "&hint=" .. LANG_HINTS

        hs.http.asyncGet(trans_query, nil, function(status, data)
            if not data then return end

            local ok, query_lang = pcall(function() return hs.json.decode(data)["lang"] end)
            if not ok then return end

            local translate_lang = NATIVE_LANG 
            local dest_lang = INTO_LANG

            if query_lang == NATIVE_LANG then
                translate_lang = NATIVE_LANG
                dest_lang = INTO_LANG
            else
                translate_lang = query_lang
                dest_lang = NATIVE_LANG
            end

            getTranslations(translate_lang, dest_lang, query, function(results)
                choices = hs.fnutils.imap(results, function(result)
                    return {
                        ["text"] = result,
                    }
                end)
    
                chooser:choices(choices)
            end)

        end)
    end

    function getTranslations(translate_lang, dest_lang, query, onComplete)
        local from_to = translate_lang .. "-" .. dest_lang
        local query_string = DICT_ENDPOINT .. "key=" .. DICT_API_KEY .. "&lang=" .. from_to .. "&text=" .. query

        -- get dictionary entries
        hs.http.asyncGet(query_string, nil, function(status, data)
            if not data then return end

            local ok, results = pcall(function() return hs.json.decode(data) end)
            if not ok then return end
            if not results["def"] or not next(results["def"]) then return end
                            
            local result_arr = {}
            table.insert(result_arr, results["def"][1]["tr"][1]["text"])

            if results["def"][1]["tr"][1]["syn"] then
                for i in pairs(results["def"][1]["tr"][1]["syn"]) do
                    table.insert(result_arr, results["def"][1]["tr"][1]["syn"][i]["text"])
                end
            end
            
            onComplete(result_arr)
        end)
    end

    chooser:queryChangedCallback(updateChooser)

    chooser:searchSubText(false)

    chooser:show()
end

function mod.registerDefaultBindings(mods, key)
    mods = mods or {"cmd", "alt", "ctrl"}
    key = key or "T"
    hs.hotkey.bind(mods, key, mod.letstranslate)
end

return mod

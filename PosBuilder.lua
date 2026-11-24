local PosStart
local PosEnd
local GrpNums = {}
local ExecutorStartPage
local ExecutorStartExec
local FadeTimes = {}
local MacroStart
local PresetCount
local MacroCount

---Helper Functions---
local function log(msg)
    gma.feedback("PosBuilder: " .. msg)
end

local function getInput(msg)
    local v = gma.textinput(msg)
    return v
end

local function getInputNum(msg)
    local v = gma.textinput(msg)
    return tonumber(v)
end

local function parseNumList(strList)
    local numTable = {}

    for num in string.gmatch(strList, "%d+") do
        table.insert(numTable, tonumber(num))
    end
    return numTable
end

local function tableToString(tbl)
    local v = "[" .. table.concat(tbl, ", ") .. "]"
    return v
end

local function gcmd(command)
    gma.cmd(command)
end

local function clearAll()
    gcmd("ClearAll")
end

local function transferLabel(from, to, prefix)
    prefix = prefix or nil
    local handle = gma.show.getobj.handle(from)
    local label = gma.show.getobj.name(handle)
    label = label:match("(.*)%s")
    if prefix == nil then
        gcmd("Label " .. to .. "\"" .. label .. "\"")
    else
        gcmd("Label " .. to .. "\"" .. prefix .. " " .. label .. "\"")
    end

end


---Programs Functions---
local function StoreCueStack(grp, posBegin, posCount, offset)
    clearAll()
    for i = 0, posCount-1 do
        gcmd("Group " .. grp .. " At Preset 2." .. (posBegin + i))
        gcmd("Store Executor " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. " Cue " .. (1+i))
        --Label Executor 30.1  Cue 1 "Home"
        transferLabel("Preset 2." .. (posBegin + i), "Executor " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. " Cue " .. (1+i))
    end
    gcmd("Appearance Executor " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. "/r=50 /g=50 /b=100")
end


local function AssignMacroLines(lines, MacroNum)
    for lineIndex, command in ipairs(lines) do
        gcmd("Store Macro 1." .. MacroNum .. "." .. lineIndex)
        gcmd("Assign Macro 1." .. MacroNum .. "." .. lineIndex .. " /cmd=\"" .. command .. "\"")
    end
end


local function StorePosMacro(MacStart, LoopCount, CueCount, ExecutorNum, posBegin, grp)
    local MacroLocalStart = MacStart + (LoopCount * CueCount)
    local MacroLocalEnd = MacroLocalStart + CueCount - 1

    for i = 0, CueCount-1 do
        local CurrentMacro = MacroLocalStart + i
        local macroLines = {
            "Appearance Macro " .. MacroLocalStart .. " Thru " .. MacroLocalEnd .. " /r=30 /g=30 /b=30",
            "Goto Executor " .. ExecutorNum .. " Cue " .. i + 1,
            "Appearance Macro " .. CurrentMacro .. " /r=100 /g=100 /b=100"
        }

        gcmd("Store Macro " .. CurrentMacro)
        AssignMacroLines(macroLines, CurrentMacro)

        --LABLE THE MACRO
        local GrpHandle = gma.show.getobj.handle("Group " .. grp)
        local GrpLabel = gma.show.getobj.name(GrpHandle)
        GrpLabel = GrpLabel:match("(.*)%s")

        local PresetHandle = gma.show.getobj.handle("Preset 2." .. (posBegin + i))
        local PresetLabel = gma.show.getobj.name(PresetHandle)
        PresetLabel = PresetLabel:match("(.*)%s")

        gcmd("Label Macro " .. CurrentMacro .. "\"" .. GrpLabel .. ":" .. PresetLabel .."\"")
    end
end

local function StoreFadeMacro(MacroLocalStart, MacroLocalEnd, CurrentMacro, ExecutorNum, FadeTime)
    local macroLines = {
        "Appearance Macro " .. MacroLocalStart .. " Thru " .. MacroLocalEnd .. " /r=30 /g=30 /b =30",
        "Assign Executor " .. ExecutorNum .. " Cue 1 Thru /fade=" .. FadeTime,
        "Appearance Macro " .. CurrentMacro .. " /r=0 /g=100 /b=0"
    }

    gcmd("Store Macro " .. CurrentMacro)
    AssignMacroLines(macroLines, CurrentMacro)

    gcmd("Label Macro " .. CurrentMacro .. " \"" .. FadeTime .. "\"")
end

local function Build()
    --BUILD CUE STACKS FOR EACH GROUP
    gcmd("Blind On")
    for i,v in ipairs(GrpNums) do
        local offset = i-1
        log("Storing for Group " .. v)
        StoreCueStack(v, PosStart, PresetCount, offset)
        transferLabel("Group " .. v, ("Executor " .. ExecutorStartPage .. "." .. ExecutorStartExec + offset), "POS")
    end
    clearAll()
    gcmd("Blind Off")

    --BUILD MACROS FOR EACH CUE IN STACKS
    for i,v in ipairs(GrpNums) do
        local offset = i-1
        StorePosMacro(MacroStart+#FadeTimes, offset, PresetCount, ExecutorStartPage .. "." .. ExecutorStartExec + offset, PosStart, v)
    end

    --BUILD MACROS FOR FADE TIMES
    for i,v in ipairs(FadeTimes) do
        i=i-1
        local CurrentMacro = MacroStart + i
        StoreFadeMacro(MacroStart, MacroStart+#FadeTimes, CurrentMacro, ExecutorStartPage .. "." .. ExecutorStartExec, v)
    end
end


local function ConfirmBuild()
        if gma.gui.confirm("Confirm Build?", "Postion Preset Start: " .. PosStart .. "\nPostion Preset End: " .. PosEnd .. "\nPreset Count: " .. PresetCount .. "\nGroups: " .. tableToString(GrpNums) .. "\nExec Start: " .. ExecutorStartPage .. "." .. ExecutorStartExec .. "\nFade Times: " .. tableToString(FadeTimes) .. "\nMacro Start: " .. MacroStart .. "\nMacro Count: " .. MacroCount) then
            log("### OK TO BUILD ###")
            Build()
        else
            gma.gui.msgbox("Build Aborted", "Position Building has been aborted")
            log("### BUILD ABORTED ###")
        end
    end


function Start()
    PosStart = getInputNum("Postion Pool Start Location")
    PosEnd = getInputNum("Postion Pool End Location")
    PresetCount = (PosEnd - PosStart + 1)

    --ALL LISTS OF NUMBERS MUST BE SEPERATED BY COMMAS. SPACES MIGHT WORK HONESTLY I DONT KNOW. -(11/21/2026 11:24pm)
    GrpNums = parseNumList(getInput("Groups to use: (ie \"1,2,5,13,42,8\")"))

    ExecutorStartPage = getInputNum("Page to Put Cues: (Will take up " .. #GrpNums .. " Executors)")
    ExecutorStartExec = getInputNum("Where to Put Executors: (Will take up " .. #GrpNums .. " Executors)")

    FadeTimes = parseNumList(getInput("Desired Fade Times: (ie \"0,1,2,3,5,8,12\")"))

    MacroCount = (#GrpNums * PresetCount + #FadeTimes)
    MacroStart = getInputNum("Where to Put Macros: (Will take up " .. MacroCount .. " Macros)")

    ConfirmBuild()
end

return Start
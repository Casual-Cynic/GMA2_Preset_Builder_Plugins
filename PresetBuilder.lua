local PreStart
local PreEnd
local GrpNums = {}
local ExecutorStartPage
local ExecutorStartExec
local FadeTimes = {}
local MacroStart
local PresetCount
local MacroCount
local PresetPoolNum
local PresetNameList = {
    [1] = "Dimmer",
    [2] = "Position",
    [3] = "Gobo",
    [4] = "Color",
    [5] = "Beam",
    [6] = "Focus",
    [7] = "Control",
    [8] = "Shapers",
    [9] = "Video"
}
local PresetPrefixList = {
    [1] = "DIM",
    [2] = "POS",
    [3] = "GOBO",
    [4] = "CLR",
    [5] = "BEAM",
    [6] = "FOC",
    [7] = "CTRL",
    [8] = "SHPR",
    [9] = "VID"
}
local PresetCueStackColors = {
    [1] = " /r=100 /g=100 /b=0",
    [2] = " /r=30 /g=30 /b=100",
    [3] = " /r=30 /g=100 /b=30",
    [4] = " /r=100 /g=50 /b=50",
    [5] = " /r=75 /g=75 /b=75",
    [6] = " /r=100 /g=65 /b=0",
    [7] = " /r=100 /g=0 /b=0",
    [8] = " /r=0 /g=100 /b=100",
    [9] = " /r=100 /g=100 /b=100"
}
local UnselectedColor = " /r=30 /g=30 /b=30"
local SelectedColor = " /r=100 /g=100 /b=100"
local AltSelectedColor = " /r=0 /g=100 /b=0"

---Helper Functions---
local function log(msg)
    gma.feedback("PresetBuilder: " .. msg)
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
local function StoreCueStack(grp, preBegin, preCount, offset)
    clearAll()
    for i = 0, preCount-1 do
        gcmd("Group " .. grp .. " At Preset " .. PresetPoolNum .. "." .. (preBegin + i))
        gcmd("Store Executor " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. " Cue " .. (1+i))
        --Label Executor 30.1  Cue 1 "Home"
        transferLabel("Preset " .. PresetPoolNum .. "." .. (preBegin + i), "Executor " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. " Cue " .. (1+i))
    end
    gcmd("Appearance Executor " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. PresetCueStackColors[PresetPoolNum])
end


local function AssignMacroLines(lines, MacroNum)
    for lineIndex, command in ipairs(lines) do
        gcmd("Store Macro 1." .. MacroNum .. "." .. lineIndex)
        gcmd("Assign Macro 1." .. MacroNum .. "." .. lineIndex .. " /cmd=\"" .. command .. "\"")
    end
end


local function StorePreMacro(MacStart, LoopCount, CueCount, ExecutorNum, preBegin, grp)
    local MacroLocalStart = MacStart + (LoopCount * CueCount)
    local MacroLocalEnd = MacroLocalStart + CueCount - 1

    for i = 0, CueCount-1 do
        local CurrentMacro = MacroLocalStart + i
        local macroLines = {
            "Appearance Macro " .. MacroLocalStart .. " Thru " .. MacroLocalEnd .. UnselectedColor,
            "Goto Executor " .. ExecutorNum .. " Cue " .. i + 1,
            "Appearance Macro " .. CurrentMacro .. SelectedColor
        }

        gcmd("Store Macro " .. CurrentMacro)
        AssignMacroLines(macroLines, CurrentMacro)

        --LABLE THE MACRO
        local GrpHandle = gma.show.getobj.handle("Group " .. grp)
        local GrpLabel = gma.show.getobj.name(GrpHandle)
        GrpLabel = GrpLabel:match("(.*)%s")

        local PresetHandle = gma.show.getobj.handle("Preset " .. PresetPoolNum .. "." .. (preBegin + i))
        local PresetLabel = gma.show.getobj.name(PresetHandle)
        PresetLabel = PresetLabel:match("(.*)%s")

        gcmd("Label Macro " .. CurrentMacro .. "\"" .. GrpLabel .. ":" .. PresetLabel .."\"")
    end
end

local function StoreFadeMacro(MacroLocalStart, MacroLocalEnd, CurrentMacro, ExecutorNum, FadeTime)
    local macroLines = {
        "Appearance Macro " .. MacroLocalStart .. " Thru " .. MacroLocalEnd .. UnselectedColor,
        "Assign Executor " .. ExecutorNum .. " Cue 1 Thru /fade=" .. FadeTime,
        "Appearance Macro " .. CurrentMacro .. AltSelectedColor
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
        StoreCueStack(v, PreStart, PresetCount, offset)
        transferLabel("Group " .. v, ("Executor " .. ExecutorStartPage .. "." .. ExecutorStartExec + offset), PresetPrefixList[PresetPoolNum])
    end
    clearAll()
    gcmd("Blind Off")

    --BUILD MACROS FOR EACH CUE IN STACKS
    for i,v in ipairs(GrpNums) do
        local offset = i-1
        StorePreMacro(MacroStart+#FadeTimes, offset, PresetCount, ExecutorStartPage .. "." .. ExecutorStartExec + offset, PreStart, v)
    end

    --BUILD MACROS FOR FADE TIMES
    if FadeTimes ~= nil then
        for i,v in ipairs(FadeTimes) do
            i=i-1
            local CurrentMacro = MacroStart + i
            StoreFadeMacro(MacroStart, MacroStart+#FadeTimes, CurrentMacro, ExecutorStartPage .. "." .. ExecutorStartExec, v)
        end
    end
end


local function ConfirmBuild()
        if gma.gui.confirm("Confirm " ..PresetNameList[PresetPoolNum].. " Preset Build?", "Preset Start: " .. PreStart .. "\nPreset End: " .. PreEnd .. "\nPreset Count: " .. PresetCount .. "\nGroups: " .. tableToString(GrpNums) .. "\nExec Start: " .. ExecutorStartPage .. "." .. ExecutorStartExec .. "\nFade Times: " .. tableToString(FadeTimes) .. "\nMacro Start: " .. MacroStart .. "\nMacro Count: " .. MacroCount) then
            log("### OK TO BUILD ###")
            Build()
        else
            gma.gui.msgbox("Build Aborted", PresetNameList[PresetPoolNum] .. "Preset Building has been aborted")
            log("### BUILD ABORTED ###")
        end
    end


function Start()
    PresetPoolNum = getInputNum("Preset Pool Number")
    PreStart = getInputNum("Preset Pool Start Location")
    PreEnd = getInputNum("Preset Pool End Location")
    PresetCount = (PreEnd - PreStart + 1)

    GrpNums = parseNumList(getInput("Groups to use: (\"1,2,5,13,42,8\")"))

    ExecutorStartPage = getInputNum("Page to Put Cues: (" .. #GrpNums .. " Executors)")
    ExecutorStartExec = getInputNum("Where to Put Executors: (" .. #GrpNums .. " Executors)")

    FadeTimes = parseNumList(getInput("Desired Fade Times: (\"0,1,2,3,5,8,12\")"))

    MacroCount = (#GrpNums * PresetCount + #FadeTimes)
    MacroStart = getInputNum("Where to Put Macros: (" .. MacroCount .. " Macros)")

    ConfirmBuild()
end

return Start
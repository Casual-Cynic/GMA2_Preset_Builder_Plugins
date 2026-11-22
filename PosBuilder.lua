local PosStart
local PosEnd
local GrpNums = {}
local ExecutorStartPage
local ExecutorStartExec
local FadeTimes = {}
local MacroStart

local function log(msg)
    gma.feedback("pgrid: " ..msg)
end

local function getInput(msg)
    v = gma.textinput(msg)
    return v
end

local function getInputNum(msg)
    v = gma.textinput(msg)
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
    gcmd("clear")
    gcmd("clear")
    gcmd("clear")
end

local function StoreCueStack(grp, posBegin, posCount, offset)
    clearAll()
    for i = 0, posCount-1 do
        gcmd("Group " .. grp .. " At Preset 2." .. (posBegin + i))
        gcmd("Store " .. ExecutorStartPage .. "." .. (ExecutorStartExec + offset) .. " Cue " .. (1+i))
    end
    local groupHandle = gma.show.getobj.handle("Group " .. grp)
    local groupLabel = gma.show.getobj.name(groupHandle)
    gcmd("Label Group " .. grp .. " \"POS " .. groupLabel .. "\"")
end

function Start()
    PosStart = getInputNum("Postion Pool Start Location")
    PosEnd = getInputNum("Postion Pool End Location")
    local PresetCount = (PosEnd - PosStart + 1)

    --ALL LISTS OF NUMBERS MUST BE SEPERATED BY COMMAS. SPACES MIGHT WORK HONESTLY I DONT KNOW. -(11/21/2026 11:24pm)
    GrpNums = parseNumList(getInput("Groups to use: (ie \"1,2,5,13,42,8\")"))

    ExecutorStartPage = getInputNum("Page to Put Cues: (Will take up " .. #GrpNums .. " Executors)")
    ExecutorStartExec = getInputNum("Where to Put Executors: (Will take up " .. #GrpNums .. " Executors)")

    FadeTimes = parseNumList(getInput("Desired Fade Times: (ie \"0,1,2,3,5,8,12\")"))

    local MacroCount = (#GrpNums * PresetCount + #FadeTimes)
    MacroStart = getInputNum("Where to Put Macros: (Will take up " .. MacroCount .. " Macros)")

    local function PrintDebug()
        gma.gui.msgbox("Debug Info", "Postion Preset Start: " .. PosStart .. "\nPostion Preset End: " .. PosEnd .. "\nPreset Count: " .. PresetCount .. "\nGroups: " .. tableToString(GrpNums) .. "\nExec Start: " .. ExecutorStartPage .. "." .. ExecutorStartExec .. "\nFade Times: " .. tableToString(FadeTimes) .. "\nMacro Start: " .. MacroStart .. "\nMacro Count: " .. MacroCount)
    end

    --BUILD CUE STACKS FOR EACH GROUP
    --gcmd("Blind On")
    for i=0, #GrpNums do
        StoreCueStack(GrpNums[i+1], PosStart, PresetCount, i)
    end
    --gcmd("Blind Off")
end

return Start
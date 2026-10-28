---------------------------------------------------------------------------------------------------
-- Name: QuestieTracker
-- Description: Handles all the quest tracker related functions
---------------------------------------------------------------------------------------------------

QuestieTracker = CreateFrame("Frame", "QuestieTracker", UIParent, "ActionButtonTemplate");

---------------------------------------------------------------------------------------------------
-- Local vars
---------------------------------------------------------------------------------------------------

local QGet_TitleText = GetTitleText;
local QGet_QuestLogTitle = GetQuestLogTitle;
local QGet_NumQuestLeaderBoards = GetNumQuestLeaderBoards;
local QGet_QuestLogLeaderBoard = GetQuestLogLeaderBoard;
local QGet_QuestLogQuestText = GetQuestLogQuestText;
local QGet_NumQuestLogEntries = GetNumQuestLogEntries;
local QGet_NumQuestWatches = GetNumQuestWatches;
local QGet_QuestLogSelection = GetQuestLogSelection;
local QSelect_QuestLogEntry = SelectQuestLogEntry;

-- Expand collapsed quest categories before resolving quest-log indices.
-- In the Vanilla quest log, quests under collapsed headers are not exposed
-- as selectable entries, so cached indices can point at the wrong quest.
local function ExpandAllQuestLogHeaders()
    local numEntries = QGet_NumQuestLogEntries();
    local i = 1;

    while i <= numEntries do
        local _, _, _, isHeader, isCollapsed = QGet_QuestLogTitle(i);

        if isHeader and isCollapsed then
            ExpandQuestHeader(i);
            numEntries = QGet_NumQuestLogEntries();
        end

        i = i + 1;
    end
end

local TrackerTooltip = GameTooltip;

---------------------------------------------------------------------------------------------------
-- Global vars
---------------------------------------------------------------------------------------------------

QuestieTracker.hasCleared = false;
QuestieTracker.questsyncUpdate = 0;
QuestieTracker.trackerUpdate = 0;
QuestieTracker.trackerSize = 0;
QuestieTracker.GeneralInterval = 0;
QuestieTracker.btnUpdate = 1;
QuestieTracker.questButtons = {};
QuestieTracker.questNames = {};
QuestieTracker.questObjects = {};
QuestieTracker.MaxButtonWidths = {};
QuestieTracker.highestIndex = 0;

QuestieTracker.tooltipButton = nil;
QuestieTracker.tooltipHash = nil;

QAddQuestWatch = nil;
QRemoveQuestWatch = nil;
QAutoQuestWatch_CheckDeleted = nil;
QAutoQuestWatch_Update = nil;
QIsQuestWatched = nil;
QAutoQuestWatch_OnUpdate = nil;

---------------------------------------------------------------------------------------------------
-- Quest copy window
---------------------------------------------------------------------------------------------------

QuestieTracker.CopyFrame = nil;
QuestieTracker.CopyEditBox = nil;

---------------------------------------------------------------------------------------------------
-- Creates the dedicated quest copy window
---------------------------------------------------------------------------------------------------

function QuestieTracker:CreateCopyFrame()

    if QuestieTracker.CopyFrame then
        return QuestieTracker.CopyFrame;
    end

    local frame =
        CreateFrame(
            "Frame",
            "QuestieTrackerCopyFrame",
            UIParent
        );

    frame:SetWidth(430);
    frame:SetHeight(300);
    frame:SetPoint(
        "CENTER",
        UIParent,
        "CENTER",
        0,
        0
    );

    frame:SetFrameStrata("DIALOG");

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        edgeSize = 16,
        insets = {
            left = 5,
            right = 5,
            top = 5,
            bottom = 5
        }
    });

    frame:SetBackdropColor(
        0,
        0,
        0,
        0.95
    );

    frame:EnableMouse(true);
    frame:SetMovable(true);

    ---------------------------------------------------------------------------------------------------
    -- Title
    ---------------------------------------------------------------------------------------------------

    local title =
        frame:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        );

    title:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        14,
        -12
    );

    title:SetText(
        "Quest Details"
    );

    ---------------------------------------------------------------------------------------------------
    -- Instructions
    ---------------------------------------------------------------------------------------------------

    local instructions =
        frame:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        );

    instructions:SetPoint(
        "TOPLEFT",
        title,
        "BOTTOMLEFT",
        0,
        -4
    );

    instructions:SetText(
        "Ctrl+C to copy - release Ctrl to close"
    );

    ---------------------------------------------------------------------------------------------------
    -- Scroll frame
    ---------------------------------------------------------------------------------------------------

    local scroll =
        CreateFrame(
            "ScrollFrame",
            "QuestieTrackerCopyScrollFrame",
            frame
        );

    scroll:SetPoint(
        "TOPLEFT",
        frame,
        "TOPLEFT",
        12,
        -48
    );

    scroll:SetPoint(
        "BOTTOMRIGHT",
        frame,
        "BOTTOMRIGHT",
        -12,
        12
    );

    scroll:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        edgeSize = 12,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3
        }
    });

    scroll:SetBackdropColor(
        0,
        0,
        0,
        0.5
    );

    ---------------------------------------------------------------------------------------------------
    -- Editable quest text
    ---------------------------------------------------------------------------------------------------

    local editBox =
        CreateFrame(
            "EditBox",
            "QuestieTrackerCopyEditBox",
            scroll
        );

    editBox:SetMultiLine(true);
    editBox:SetAutoFocus(false);
    editBox:SetFontObject(GameFontNormal);
    editBox:SetTextColor(1, 1, 1);
    editBox:SetJustifyH("LEFT");
    editBox:SetJustifyV("TOP");
    editBox:SetPoint(
        "TOPLEFT",
        scroll,
        "TOPLEFT",
        6,
        -6
    );

    editBox:SetWidth(390);
    editBox:SetHeight(230);

    editBox:SetTextInsets(
        2,
        2,
        2,
        2
    );

    scroll:SetScrollChild(editBox);

    ---------------------------------------------------------------------------------------------------
    -- Close on Escape
    ---------------------------------------------------------------------------------------------------

    editBox:SetScript(
        "OnEscapePressed",
        function()

            QuestieTracker.CopyFrame:Hide();

        end
    );

    ---------------------------------------------------------------------------------------------------
    -- Ctrl-release detection
    --
    -- The frame remains open after Alt is released.
    -- Once Ctrl is pressed, releasing Ctrl closes the window.
    ---------------------------------------------------------------------------------------------------

    frame.ctrlSeen = false;

    frame:SetScript(
        "OnUpdate",
        function()

            if not this:IsShown() then
                return;
            end

            if IsControlKeyDown() then

                this.ctrlSeen = true;

            elseif this.ctrlSeen then

                this:Hide();
                this.ctrlSeen = false;

            end

        end
    );

    ---------------------------------------------------------------------------------------------------
    -- Clear focus when the window is hidden
    ---------------------------------------------------------------------------------------------------

    frame:SetScript(
        "OnHide",
        function()

            if QuestieTracker.CopyEditBox then
                QuestieTracker.CopyEditBox:ClearFocus();
            end

            this.ctrlSeen = false;

        end
    );

    QuestieTracker.CopyFrame = frame;
    QuestieTracker.CopyEditBox = editBox;

    return frame;

end

---------------------------------------------------------------------------------------------------
-- Builds quest text and opens the copy window
---------------------------------------------------------------------------------------------------

function QuestieTracker:ShowQuestCopyWindow(button)

    if not button then
        return;
    end

    local questHash =
        button.hash;

    if not questHash then
        return;
    end

    local quest =
        QuestieCachedQuests[questHash];

    if not quest then
        return;
    end

    local questLogId =
        quest["logId"];

    if not questLogId then
        return;
    end

    local previousSelection =
        QGet_QuestLogSelection();

    ---------------------------------------------------------------------------------------------------
    -- Select the quest so GetQuestLogQuestText() returns the
    -- correct description.
    ---------------------------------------------------------------------------------------------------

    QSelect_QuestLogEntry(
        questLogId
    );

    local questName,
          questLevel,
          questTag,
          isHeader,
          isCollapsed,
          isComplete =
        QGet_QuestLogTitle(
            questLogId
        );

    local questText,
          objectiveText =
        QGet_QuestLogQuestText();

    local text = "";

    if questName then

        text =
            text ..
            questName;

    end

    if questLevel then

        text =
            text ..
            "\nLevel: " ..
            tostring(questLevel);

    end

    if questTag then

        text =
            text ..
            "+";

    end

    text =
        text ..
        "\n\n";

    ---------------------------------------------------------------------------------------------------
    -- Quest description
    ---------------------------------------------------------------------------------------------------

    if questText and
       questText ~= "" then

        text =
            text ..
            questText ..
            "\n\n";

    end

    ---------------------------------------------------------------------------------------------------
    -- Quest objectives
    ---------------------------------------------------------------------------------------------------

    if objectiveText and
       objectiveText ~= "" then

        text =
            text ..
            "Objectives:\n" ..
            objectiveText ..
            "\n\n";

    end

    ---------------------------------------------------------------------------------------------------
    -- Current tracker objectives
    ---------------------------------------------------------------------------------------------------

    local foundTrackerObjective = false;

    for i=1, 20 do

        local objective =
            quest["objective" .. i];

        if objective and
           objective["desc"] then

            if not foundTrackerObjective then

                text =
                    text ..
                    "Progress:\n";

                foundTrackerObjective = true;

            end

            text =
                text ..
                objective["desc"] ..
                "\n";

        end

    end

    ---------------------------------------------------------------------------------------------------
    -- Restore the previous quest-log selection.
    ---------------------------------------------------------------------------------------------------

    QSelect_QuestLogEntry(
        previousSelection
    );

    QuestLog_Update();

    ---------------------------------------------------------------------------------------------------
    -- Create the window if necessary.
    ---------------------------------------------------------------------------------------------------

    local frame =
        QuestieTracker:CreateCopyFrame();

    local editBox =
        QuestieTracker.CopyEditBox;

    ---------------------------------------------------------------------------------------------------
    -- Put the quest text into the editable box.
    ---------------------------------------------------------------------------------------------------

    editBox:SetText(
        text
    );

    frame.ctrlSeen = false;

    frame:Show();
    frame:Raise();

    ---------------------------------------------------------------------------------------------------
    -- Focus and highlight everything so Ctrl+C immediately copies
    -- the entire quest.
    ---------------------------------------------------------------------------------------------------

    editBox:SetFocus();
    editBox:HighlightText();

end

---------------------------------------------------------------------------------------------------
-- Tooltip helpers
---------------------------------------------------------------------------------------------------

local TrackerTooltip = GameTooltip;

local function HideTrackerTooltip()

    TrackerTooltip:Hide();
    TrackerTooltip:ClearLines();

    QuestieTracker.tooltipButton = nil;
    QuestieTracker.tooltipHash = nil;

end

---------------------------------------------------------------------------------------------------

local function GetTrackerTooltipAnchor(button)

    local centerX = button:GetCenter();

    if centerX and centerX < (UIParent:GetWidth() / 2) then
        return "ANCHOR_RIGHT";
    end

    return "ANCHOR_LEFT";

end

---------------------------------------------------------------------------------------------------

local function GetQuestObjectiveName(hash)

    local hashData = QuestieHashMap[hash];

    if not hashData or not hashData.name then
        return nil;
    end

    local lookup =
        Questie:SanitisedQuestLookup(hashData.name);

    if not lookup then
        return nil;
    end

    for k, v in pairs(lookup) do

        if k ~= "" and
           v and
           v[2] == hash then

            return k;

        end

    end

    return nil;

end

---------------------------------------------------------------------------------------------------

function QuestieTracker:ShowButtonTooltip(button)

    if not button then
        return;
    end

    if not button:IsShown() then
        return;
    end

    local questHash = button.hash;

    if not questHash then
        return;
    end

    local quest =
        QuestieCachedQuests[questHash];

    if not quest then
        return;
    end

    -- Do NOT require == true here.
    -- Old Questie configs may use 1 or another truthy value.
    if not QuestieConfig.showToolTips then
        return;
    end

    TrackerTooltip:Hide();
    TrackerTooltip:ClearLines();

    TrackerTooltip:SetOwner(
        button,
        GetTrackerTooltipAnchor(button)
    );

    local questOb =
        GetQuestObjectiveName(questHash);

    if questOb then

        TrackerTooltip:AddLine(
            "|cFFa6a6a6To finish this quest...|r",
            1,
            1,
            1,
            true
        );

        TrackerTooltip:AddLine(
            "|cFFFFFFFF" ..
            Questie:RemoveUniqueSuffix(questOb) ..
            "|r",
            1,
            1,
            1,
            true
        );

    else

        -- This is deliberately useful for debugging.
        -- If the quest exists but the database lookup fails,
        -- we should still get a visible tooltip.
        TrackerTooltip:AddLine(
            quest.questName or "Quest",
            1,
            1,
            1
        );

        TrackerTooltip:AddLine(
            "Quest objective not found in Questie Database.",
            1,
            0.8,
            0.8
        );

    end

    ---------------------------------------------------------------------------------------------------
    -- Copy hint
    ---------------------------------------------------------------------------------------------------

    TrackerTooltip:AddLine(
        " "
    );

    TrackerTooltip:AddLine(
        "|cFFFFFF00Alt-click to show on map|r",
        1,
        1,
        1,
        true
    );
TrackerTooltip:AddLine(
        "|cFFFFFF00Alt-right click to copy quest details|r",
        1,
        1,
        1,
        true
    );
TrackerTooltip:AddLine(
        "|cFFFFFF00Right-click to set way point|r",
        1,
        1,
        1,
        true);
TrackerTooltip:AddLine(
        "|cFFFFFF00Shift-click to untrack quest|r",
        1,
        1,
        1,
        true
    );
    TrackerTooltip:Show();

    QuestieTracker.tooltipButton = button;
    QuestieTracker.tooltipHash = questHash;

end

---------------------------------------------------------------------------------------------------

function QuestieTracker:HideButtonTooltip(button)

    if QuestieTracker.tooltipButton == button then
        HideTrackerTooltip();
    end

end

---------------------------------------------------------------------------------------------------
-- OnEvent
---------------------------------------------------------------------------------------------------

function QuestieTracker:OnEvent()

    QuestieTracker[event](
        QuestieTracker,
        arg1,
        arg2,
        arg3,
        arg4,
        arg5,
        arg6,
        arg7,
        arg8,
        arg9,
        arg10
    );

end

---------------------------------------------------------------------------------------------------
-- OnUpdate
---------------------------------------------------------------------------------------------------

function QuestieTracker_OnUpdate()

    if (IsAddOnLoaded("EQL3") or IsAddOnLoaded("ShaguQuest")) then

        if QuestieConfig.trackerEnabled == true then

            if QuestWatchFrame then
                QuestWatchFrame:Hide();
            end

            if EQL3_QuestWatchFrame then
                EQL3_QuestWatchFrame:Hide();
            end

        else

            if QuestieTracker.frame then
                QuestieTracker.frame:Hide();
            end

            if QuestieTrackerHeader then
                QuestieTrackerHeader:Hide();
            end

            if QuestieTracker.tooltipButton then
                HideTrackerTooltip();
            end

        end

    else

        if QuestieConfig.trackerEnabled == true then

            if QuestWatchFrame then
                QuestWatchFrame:Hide();
            end

        else

            if QuestieTracker.frame then
                QuestieTracker.frame:Hide();
            end

            if QuestieTrackerHeader then
                QuestieTrackerHeader:Hide();
            end

            if QuestieTracker.tooltipButton then
                HideTrackerTooltip();
            end

        end

    end

    if GetTime() - QuestieTracker.trackerUpdate >= 2 then

        if (QuestieConfig.showMapNotes == true) or
           (QuestieConfig.alwaysShowObjectives == true) then

            QuestieTracker:SortTrackingFrame();

        end

        QuestieTracker.trackerUpdate = GetTime();

    end

end

---------------------------------------------------------------------------------------------------
-- Register events
---------------------------------------------------------------------------------------------------

QuestieTracker:SetScript("OnEvent", QuestieTracker.OnEvent);
QuestieTracker:SetScript("OnUpdate", QuestieTracker_OnUpdate);

---------------------------------------------------------------------------------------------------
-- Automatically Calculates QuestieTracker Height and Width
---------------------------------------------------------------------------------------------------

function QuestieTracker:updateTrackingFrameSize()

    if QuestieConfig.trackerEnabled ~= true then
        return;
    end

    if not QuestieTracker.frame then
        return;
    end

    if QuestieConfig.trackerMinimize == true then
        QuestieTracker.frame:Hide();

        if QuestieTrackerHeader then
            QuestieTrackerHeader:Hide();
        end

        HideTrackerTooltip();

        return;
    end

    if (QuestieTracker.highestIndex == 0) or
       (QGet_NumQuestLogEntries() == 0) then

        QuestieTracker.frame:SetHeight(0.1);
        QuestieTracker.frame:SetWidth(0.1);
        QuestieTracker.frame:SetBackdropColor(0,0,0,0);
        QuestieTracker.frame:Hide();

        if QuestieConfig.showTrackerHeader == true then
            QuestieTrackerHeader:Hide();
        end

        HideTrackerTooltip();

        return;

    end

    local maxWidth =
        QuestieTracker.questButtons.maxWidth;

    if maxWidth == nil or maxWidth < 1 then
        maxWidth = 1;
    end

    -- Leave a small horizontal inset so quest buttons do not touch or
    -- protrude through the tracker backdrop border.
    local totalWidth = maxWidth + 12;
    local contentHeight = 0;
    local spacing = QuestieConfig.trackerSpacing or 2;

    if spacing < 0 then spacing = 0 end
    if spacing > 12 then spacing = 12 end

    -- Calculate from the buttons' assigned sizes, not GetTop/GetBottom.
    -- WoW 1.12 can report stale frame coordinates immediately after a
    -- collapse toggle changes objective visibility and button heights.
    for i = 1, QuestieTracker.highestIndex do
        local button = QuestieTracker.questButtons[i];

        if button and button:IsShown() then
            contentHeight = contentHeight + button:GetHeight();

            if i > 1 then
                contentHeight = contentHeight + spacing;
            end
        end
    end

    QuestieTracker.frame:SetWidth(totalWidth);

    local topOffset = 10;
    local bottomPadding = 11;

    if QuestieConfig.showTrackerHeader == true then
        topOffset = 22;

        if QuestieConfig.trackerList == true then
            bottomPadding = 7;
        end

        if watcher and
           totalWidth < watcher:GetStringWidth() + 22 then

            QuestieTracker.frame:SetWidth(
                watcher:GetStringWidth() + 22
            );

        end
    end

    QuestieTracker.frame:SetHeight(
        contentHeight + topOffset + bottomPadding
    );

    QuestieTracker.frame:SetBackdropColor(
        0,
        0,
        0,
        QuestieConfig.trackerAlpha
    );

    -- IMPORTANT:
    -- Do not Hide()/Show() the tracker during resizing.
    -- The quest buttons are children of this frame, and doing so
    -- destroys the tooltip owner state.

    QuestieTracker.frame:Show();

end
---------------------------------------------------------------------------------------------------
-- Color quest objective scheme for quest tracker color option 2
---------------------------------------------------------------------------------------------------

function QuestieTracker:getRGBForObjective(objective)

    if QuestieConfig.boldColors == false then

        if type(objective) ~= "function" then

            local lastIndex =
                findLast(objective, ":");

            if lastIndex ~= nil then

                local progress =
                    string.sub(
                        objective,
                        lastIndex + 2
                    );

                local slash =
                    findLast(progress, "/");

                if slash == nil then
                    return 0.8, 0.8, 0.8;
                end

                local have =
                    tonumber(
                        string.sub(
                            progress,
                            0,
                            slash - 1
                        )
                    );

                local need =
                    tonumber(
                        string.sub(
                            progress,
                            slash + 1
                        )
                    );

                if not have or not need or need == 0 then
                    return 0.8, 0.8, 0.8;
                end

                local float = have / need;

                return
                    0.8 - float / 2,
                    0.8 + float / 3,
                    0.8 - float / 2;

            end

        end

        return 0.3, 1, 0.3;

    else

        if type(objective) ~= "function" then

            local lastIndex =
                findLast(objective, ":");

            if lastIndex ~= nil then

                local progress =
                    string.sub(
                        objective,
                        lastIndex + 2
                    );

                local slash =
                    findLast(progress, "/");

                if slash == nil then
                    return 1, 0, 0;
                end

                local have =
                    tonumber(
                        string.sub(
                            progress,
                            0,
                            slash - 1
                        )
                    );

                local need =
                    tonumber(
                        string.sub(
                            progress,
                            slash + 1
                        )
                    );

                if not have or not need or need == 0 then
                    return 1, 0, 0;
                end

                local float = have / need;

                if float < .49 then
                    return 1, float / .5, 0;
                end

                if float == .50 then
                    return 1, 1, 0;
                end

                if float > .50 then
                    return 1 - float / 2, 1, 0;
                end

            end

        end

        return 0, 1, 0;

    end

end

---------------------------------------------------------------------------------------------------
-- Clears tracking frame
---------------------------------------------------------------------------------------------------

function QuestieTracker:clearTrackingFrame()

    HideTrackerTooltip();

    for i=1, 8 do

        local button =
            getglobal(
                "QuestieTrackerButtonNew"..i
            );

        if button then
            button:Hide();
        end

        for j=1,20 do

            local objective =
                getglobal(
                    "QuestieTrackerButtonNew"..
                    i..
                    "QuestWatchLine"..
                    j
                );

            if objective then
                objective:Hide();
            end

        end

    end

end

---------------------------------------------------------------------------------------------------
-- Makes or retrieves one of the quest objective buttons
---------------------------------------------------------------------------------------------------

function QuestieTracker:createOrGetTrackingButton(index)

    if QuestieTracker.questButtons[index] == nil then

        local parent;

        if index == 1 then
            parent = QuestieTracker.frame;
        else
            parent = QuestieTracker.questButtons[index-1];
        end

        local btn = CreateFrame(
            "Button",
            "QuestieTrackerButtonNew"..index,
            QuestieTracker.frame
        );

        btn.objectives = {};

        -- Separate control for collapsing this quest's objective lines.
        local collapseToggle = CreateFrame(
            "Button",
            nil,
            btn
        );
        collapseToggle:SetWidth(16);
        collapseToggle:SetHeight(16);
        collapseToggle:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0);

        collapseToggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
        collapseToggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down");
        collapseToggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight");
        collapseToggle:SetScript("OnClick", function()
            local collapseKey = btn.collapseKey;
            if not collapseKey then
                return;
            end

            QuestieTracker.collapsedQuests[collapseKey] =
                not QuestieTracker.collapsedQuests[collapseKey];

            QuestieTracker:FillTrackingFrame();
        end);
        btn.collapseToggle = collapseToggle;

        btn:SetWidth(0);
        btn:SetHeight(0);

        btn:EnableMouse(true);
        btn:SetMovable(true);

        btn:SetScript(
            "OnDragStart",
            QuestieTracker.frame.StartMoving
        );

        btn:SetScript(
            "OnDragStop",
            QuestieTracker.frame.StopMovingOrSizing
        );

        ---------------------------------------------------------------------------------------------------
        -- Mouse down
        ---------------------------------------------------------------------------------------------------

        btn:SetScript("OnMouseDown", function()

            btn.dragstartx, btn.dragstarty =
                GetCursorPosition();

            if IsControlKeyDown() and
               IsShiftKeyDown() then

                QuestieTracker.frame:StartMoving();

            end

        end);

        ---------------------------------------------------------------------------------------------------
        -- Mouse up
        ---------------------------------------------------------------------------------------------------

        btn:SetScript("OnMouseUp", function()

            local dragstopx, dragstopy =
                GetCursorPosition();

            if (btn.dragstartx == dragstopx and
                btn.dragstarty == dragstopy) then

                if arg1 == "RightButton" then
    if IsAltKeyDown() then
        QuestieTracker:ShowQuestCopyWindow(btn);
    elseif QuestieConfig.arrowEnabled == true then
        SetArrowObjective(btn.hash);
    end
elseif arg1 == "LeftButton" then
    btn:click();
end

            end

            QuestieTracker.frame:StopMovingOrSizing();
            QuestieTracker.frame:SetUserPlaced(false);
            QuestieTracker:saveFramePosition();

        end);

        ---------------------------------------------------------------------------------------------------
        -- Tooltip
        ---------------------------------------------------------------------------------------------------

        btn:SetScript("OnEnter", function()

            QuestieTracker:ShowButtonTooltip(this);

        end);

        btn:SetScript("OnLeave", function()

            QuestieTracker:HideButtonTooltip(this);

        end);

        btn.dragstartx = 0;
        btn.dragstarty = 0;

        btn:RegisterForClicks(
            "RightButtonDown",
            "LeftButtonUp",
            "LeftClick"
        );

        ---------------------------------------------------------------------------------------------------
        -- Quest tracker click behavior
        ---------------------------------------------------------------------------------------------------

        btn.click = function()

            local questHash = btn.hash;

            local quest =
                QuestieCachedQuests[questHash];

            if not quest then
                return;
            end

            ---------------------------------------------------------------------------------------------------
            -- Alt + Left Click = Show quest on map
            ---------------------------------------------------------------------------------------------------

            if IsAltKeyDown() then

                -- Ensure collapsed quest-log entries can be resolved for map clicks.
                ExpandAllQuestLogHeaders();

                Questie:ShowQuestOnMap(
                    btn.hash
                );

                return;

            end

            ---------------------------------------------------------------------------------------------------
            -- Shift + Left Click
            ---------------------------------------------------------------------------------------------------

            if IsShiftKeyDown() then

                ExpandAllQuestLogHeaders();

                -- Rebuild/resolve the index after revealing collapsed quests.
                local questLogId =
                    Questie:GetQuestIdFromHash(questHash);

                if questLogId then

                    RemoveQuestWatch(questLogId);

                    Questie:AddEvent(
                        "SYNCLOG",
                        0
                    );

                    if QuestieConfig["alwaysShowObjectives"] == false then

                        Questie:AddEvent(
                            "DRAWNOTES",
                            0.02
                        );

                    end

                    QuestWatch_Update();

                end

                return;

            end

            ---------------------------------------------------------------------------------------------------
            -- Normal Left Click
            ---------------------------------------------------------------------------------------------------

            if not IsControlKeyDown() then

                if not QuestLogFrame:IsVisible() then
                    ShowUIPanel(QuestLogFrame);
                end

                ExpandAllQuestLogHeaders();

                -- Resolve the index only after collapsed quests are visible.
                local questLogId =
                    Questie:GetQuestIdFromHash(questHash);

                if questLogId then

                    QuestLog_SetSelection(questLogId);
                    QuestLog_Update();

                end

                return;

            end

        end;

        ---------------------------------------------------------------------------------------------------
        -- Position button
        ---------------------------------------------------------------------------------------------------

        if QuestieConfig.showTrackerHeader == true then

            if QuestieConfig.trackerList == true then

                if index == 1 then

                    btn:SetPoint(
                        "BOTTOMLEFT",
                        parent,
                        "BOTTOMLEFT",
                        0,
                        22
                    );

                else

                    btn:SetPoint(
                        "BOTTOMLEFT",
                        parent,
                        "TOPLEFT",
                        0,
                        2
                    );

                end

            else

                if index == 1 then

                    btn:SetPoint(
                        "TOPLEFT",
                        parent,
                        "TOPLEFT",
                        0,
                        -22
                    );

                else

                    btn:SetPoint(
                        "TOPLEFT",
                        parent,
                        "BOTTOMLEFT",
                        0,
                        -2
                    );

                end

            end

        else

            if QuestieConfig.trackerList == true then

                if index == 1 then

                    btn:SetPoint(
                        "BOTTOMLEFT",
                        parent,
                        "BOTTOMLEFT",
                        0,
                        10
                    );

                else

                    btn:SetPoint(
                        "BOTTOMLEFT",
                        parent,
                        "TOPLEFT",
                        0,
                        0
                    );

                end

            else

                if index == 1 then

                    btn:SetPoint(
                        "TOPLEFT",
                        parent,
                        "TOPLEFT",
                        0,
                        -10
                    );

                else

                    btn:SetPoint(
                        "TOPLEFT",
                        parent,
                        "BOTTOMLEFT",
                        0,
                        -2
                    );

                end

            end

        end

        ---------------------------------------------------------------------------------------------------
        -- Quest title
        ---------------------------------------------------------------------------------------------------

        local quest = btn:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        );

        quest:SetPoint(
            "TOPLEFT",
            btn,
            "TOPLEFT",
            16,
            0
        );

        btn.quest = quest;

        ---------------------------------------------------------------------------------------------------
        -- Quest level
        ---------------------------------------------------------------------------------------------------

        local level = btn:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        );

        level:SetPoint(
            "TOPLEFT",
            btn,
            "TOPLEFT",
            20,
            0
        );

        btn.level = level;

        QuestieTracker.questButtons[index] = btn;

    end

    return QuestieTracker.questButtons[index];

end

---------------------------------------------------------------------------------------------------
-- Determines quest difficulty color based on players level
---------------------------------------------------------------------------------------------------

function QuestieTracker:GetDifficultyColor(level)

    if type(level) == "string" then

        for x in string.gfind(level, "%d+") do
            level = x;
        end

        level = tonumber(level);

    end

    if level == nil then
        return "FFFFFFFF";
    end

    local levelDiff =
        level - UnitLevel("player");

    if levelDiff >= 5 then

        return "FFFF1A1A";

    elseif levelDiff >= 3 then

        return "FFFF8040";

    elseif levelDiff >= -2 then

        return "FFFFFF00";

    elseif (-levelDiff <= GetQuestGreenRange()) then

        return "FF40C040";

    else

        return "FFC0C0C0";

    end

end

---------------------------------------------------------------------------------------------------
-- todo move to QuestieUtils
---------------------------------------------------------------------------------------------------

function RGBToHex(r, g, b)

    if r > 255 then r = 255; end
    if g > 255 then g = 255; end
    if b > 255 then b = 255; end

    return string.format(
        "%02x%02x%02x",
        r,
        g,
        b
    );

end

---------------------------------------------------------------------------------------------------

function fRGBToHex(r, g, b)

    return RGBToHex(
        r * 254,
        g * 254,
        b * 254
    );

end

---------------------------------------------------------------------------------------------------
-- Clamps objective text
---------------------------------------------------------------------------------------------------

local function StripColors(s)

    s = string.gsub(
        s,
        "|c%x%x%x%x%x%x%x%x",
        ""
    );

    s = string.gsub(
        s,
        "|r",
        ""
    );

    return s;

end

---------------------------------------------------------------------------------------------------

function QuestieTracker:ClampObjectiveText(button, desc)

    local header =
        StripColors(
            button.quest:GetText() or ""
        );

    local maxLen =
        string.len(header) + 5;

    if string.len(desc) <= maxLen then
        return desc;
    end

    local _, _, name, progress =
        string.find(
            desc,
            "^(.*)(: %d+/%d+)$"
        );

    if name then

        local room =
            maxLen -
            string.len(progress) -
            3;

        if room < 1 then
            room = 1;
        end

        return string.sub(name, 1, room) ..
               "..." ..
               progress;

    end

    if maxLen <= 3 then
        return string.sub(desc, 1, maxLen);
    end

    return string.sub(
        desc,
        1,
        maxLen - 3
    ) .. "...";

end

---------------------------------------------------------------------------------------------------
-- Adds quest type 'objective' text to quest objective button
---------------------------------------------------------------------------------------------------

function QuestieTracker:AddObjectiveToButton(
    button,
    objective,
    index
)

    local objt;

    if button.objectives[index] == nil then

        objt = button:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        );

    else

        objt = button.objectives[index];

    end

    objt:SetPoint(
        "TOPLEFT",
        button,
        "TOPLEFT",
        20,
        -(index * 11 + 1)
    );

    local r, g, b =
        QuestieTracker:getRGBForObjective(
            objective["desc"]
        );

    local clr =
        fRGBToHex(r, g, b);

    objt:SetText(
        "|cFF" ..
        clr ..
        QuestieTracker:ClampObjectiveText(
            button,
            objective["desc"]
        ) ..
        "|r"
    );

    objt:Show();

    button.objectives[index] = objt;

end

---------------------------------------------------------------------------------------------------
-- Adds quest type 'event' text to quest objective button
---------------------------------------------------------------------------------------------------

function QuestieTracker:AddEventToButton(
    button,
    objective,
    index
)

    local objt;

    if button.objectives[index] == nil then

        objt = button:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormal"
        );

    else

        objt = button.objectives[index];

    end

    objt:SetPoint(
        "TOPLEFT",
        button,
        "TOPLEFT",
        20,
        -(index * 11 + 1)
    );

    if QuestieConfig.boldColors == true then

        objt:SetText(
            "|cFFFF0000" ..
            QuestieTracker:ClampObjectiveText(
                button,
                objective["desc"]
            ) ..
            "|r"
        );

    else

        objt:SetText(
            "|cFFCCCCCC" ..
            QuestieTracker:ClampObjectiveText(
                button,
                objective["desc"]
            ) ..
            "|r"
        );

    end

    objt:Show();

    button.objectives[index] = objt;

end

---------------------------------------------------------------------------------------------------
-- Finds quest finisher location by type and name
---------------------------------------------------------------------------------------------------

function QuestieTracker:GetFinisherLocations(typ, name)

    local C, Z, X, Y;

    if typ == "monster" then

        local paths =
            GetMonsterLocations(name);

        return Questie:RecursiveGetPathLocations(
            paths
        );

    elseif typ == "object" then

        local paths =
            GetObjectLocations(name);

        return Questie:RecursiveGetPathLocations(
            paths
        );

    end

    return C, Z, X, Y;

end

---------------------------------------------------------------------------------------------------
-- Updates the QuestieTracker frames distance sorting feature
---------------------------------------------------------------------------------------------------

function QuestieTracker:SortTrackingFrame()

    local sortedByDistance = {};
    local distanceControlTable = {};

    local C, Z, X, Y =
        Astrolabe:GetCurrentPlayerPosition();

    local distanceNotes = {};

    QuestieTracker.GeneralInterval =
        QuestieTracker.GeneralInterval + 1;

    if QuestieTracker.GeneralInterval >
       (QuestieTracker.btnUpdate * 0.99) then

        QuestieTracker.GeneralInterval = 0;

        for hash, quest in pairs(QuestieHandledQuests) do

            local questTrack =
                QuestieCachedQuests[hash];

            if questTrack ~= nil and
               questTrack.tracked then

                local objectiveCount = 0;

                if not questTrack.isComplete then

                    for objectiveid, objective in pairs(quest.objectives) do

                        if not objective.done then

                            local locations =
                                Questie:RecursiveGetPathLocations(
                                    objective.path
                                );

                            if locations then

                                for i, location in ipairs(locations) do

                                    local dist,
                                          xDelta,
                                          yDelta =
                                        Astrolabe:ComputeDistance(
                                            C,
                                            Z,
                                            X,
                                            Y,
                                            location[1],
                                            location[2],
                                            location[3],
                                            location[4]
                                        );

                                    if dist and
                                       xDelta and
                                       yDelta then

                                        local info = {
                                            ["dist"] = dist,
                                            ["hash"] = hash,
                                            ["xDelta"] = xDelta,
                                            ["yDelta"] = yDelta,
                                            ["c"] = location[1],
                                            ["z"] = location[2],
                                            ["x"] = location[3],
                                            ["y"] = location[4],
                                        };

                                        objectiveCount =
                                            objectiveCount + 1;

                                        table.insert(
                                            distanceNotes,
                                            info
                                        );

                                    end

                                end

                            end

                        end

                    end

                end

                if objectiveCount == 0 then

                    local questData =
                        QuestieHashMap[hash];

                    if questData ~= nil then

                        local locations =
                            QuestieTracker:GetFinisherLocations(
                                questData.finishedType,
                                questData.finishedBy
                            ) or {};

                        for i, location in ipairs(locations) do

                            local dist,
                                  xDelta,
                                  yDelta =
                                Astrolabe:ComputeDistance(
                                    C,
                                    Z,
                                    X,
                                    Y,
                                    location[1],
                                    location[2],
                                    location[3],
                                    location[4]
                                );

                            if dist and
                               xDelta and
                               yDelta then

                                local info = {
                                    ["dist"] = dist,
                                    ["hash"] = hash,
                                    ["xDelta"] = xDelta,
                                    ["yDelta"] = yDelta,
                                    ["c"] = location[1],
                                    ["z"] = location[2],
                                    ["x"] = location[3],
                                    ["y"] = location[4],
                                };

                                table.insert(
                                    distanceNotes,
                                    info
                                );

                            end

                        end

                    end

                end

            end

        end

    end

    sort(
        distanceNotes,
        function(a, b)

            if not a["dist"] or
               not b["dist"] then

                return false;

            end

            return a["dist"] < b["dist"];

        end
    );

    for k, v in ipairs(distanceNotes) do

        if not distanceControlTable[v["hash"]] then

            distanceControlTable[v["hash"]] = true;

            table.insert(
                sortedByDistance,
                v
            );

        end

    end

    -- Fallback: display tracked quests even when Astrolabe
    -- cannot calculate a distance (e.g. inside dungeons).
    for hash, quest in pairs(QuestieHandledQuests) do
        local questTrack = QuestieCachedQuests[hash];

        if questTrack and questTrack.tracked and
           not distanceControlTable[hash] then

            distanceControlTable[hash] = true;

            table.insert(
                sortedByDistance,
                {
                    ["hash"] = hash,
                    ["dist"] = 999999
                }
            );

        end
    end


    for i, v in ipairs(sortedByDistance) do

        local hash = v["hash"];

        local quest =
            QuestieCachedQuests[hash];

        if quest then

            local colorString =
                "|c" ..
                QuestieTracker:GetDifficultyColor(
                    quest["level"]
                );

            if QuestieConfig.boldColors == true then

                if quest["questTag"] then

                    v["title"] =
                        colorString ..
                        "[" ..
                        quest["level"] ..
                        "+] |r" ..
                        quest["questName"];

                else

                    v["title"] =
                        colorString ..
                        "[" ..
                        quest["level"] ..
                        "] |r" ..
                        quest["questName"];

                end

            else

                if quest["questTag"] then

                    v["title"] =
                        colorString ..
                        "[" ..
                        quest["level"] ..
                        "+] " ..
                        quest["questName"] ..
                        "|r";

                else

                    v["title"] =
                        colorString ..
                        "[" ..
                        quest["level"] ..
                        "] " ..
                        quest["questName"] ..
                        "|r";

                end

            end

            -- This is the location used by the existing Questie arrow.
            quest["arrowPoint"] = v;

        end

    end

    return sortedByDistance;

end

---------------------------------------------------------------------------------------------------
-- Populates the quest tracker frame with objective buttons
---------------------------------------------------------------------------------------------------

function QuestieTracker:FillTrackingFrame()

    local index = 1;

    local previousTooltipButton =
        QuestieTracker.tooltipButton;

    local previousTooltipHash =
        QuestieTracker.tooltipHash;

    QuestieTracker.questNames = {};
    QuestieTracker.questObjects = {};
    QuestieTracker.MaxButtonWidths = {};
    QuestieTracker.questButtons.maxWidth = 0;

    local sortedByDistance =
        QuestieTracker:SortTrackingFrame();

    for i, v in ipairs(sortedByDistance) do

        local hash = v["hash"];

        local quest =
            QuestieCachedQuests[hash];

        if quest then

            local button =
                QuestieTracker:createOrGetTrackingButton(index);

            -- Re-anchor every button so spacing changes take effect immediately.
            button:ClearAllPoints();

            local positionParent = QuestieTracker.frame;
            if index > 1 then
                positionParent = QuestieTracker.questButtons[index - 1];
            end

            local spacing = QuestieConfig.trackerSpacing or 2;
            if spacing < 0 then spacing = 0 end
            if spacing > 12 then spacing = 12 end

            -- Only the first button needs an inset from the frame border.
            -- Later buttons align with it; applying the inset repeatedly
            -- makes the list staircase to the right.
            local buttonInset = 0;
            if index == 1 then buttonInset = 6 end

            if QuestieConfig.showTrackerHeader == true then
                if QuestieConfig.trackerList == true then
                    if index == 1 then
                        button:SetPoint("BOTTOMLEFT", positionParent, "BOTTOMLEFT", buttonInset, 22);
                    else
                        button:SetPoint("BOTTOMLEFT", positionParent, "TOPLEFT", buttonInset, spacing);
                    end
                else
                    if index == 1 then
                        button:SetPoint("TOPLEFT", positionParent, "TOPLEFT", buttonInset, -22);
                    else
                        button:SetPoint("TOPLEFT", positionParent, "BOTTOMLEFT", buttonInset, -spacing);
                    end
                end
            else
                if QuestieConfig.trackerList == true then
                    if index == 1 then
                        button:SetPoint("BOTTOMLEFT", positionParent, "BOTTOMLEFT", buttonInset, 10);
                    else
                        button:SetPoint("BOTTOMLEFT", positionParent, "TOPLEFT", buttonInset, spacing);
                    end
                else
                    if index == 1 then
                        button:SetPoint("TOPLEFT", positionParent, "TOPLEFT", buttonInset, -10);
                    else
                        button:SetPoint("TOPLEFT", positionParent, "BOTTOMLEFT", buttonInset, -spacing);
                    end
                end
            end

            button.hash = hash;

            -- Use the quest name as the persistent key; internal hashes can
            -- change when the quest database/server data changes.
            button.collapseKey = quest["questName"] or hash;

            local isCollapsed =
                QuestieTracker.collapsedQuests[button.collapseKey] == true;

            if isCollapsed then
                button.collapseToggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up");
                button.collapseToggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down");
                button.collapseToggle:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight");
            else
                button.collapseToggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up");
                button.collapseToggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down");
                button.collapseToggle:SetHighlightTexture("Interface\\Buttons\\UI-MinusButton-Hilight");
            end
            button.collapseToggle:Show();

            local colorString =
                "|c" ..
                QuestieTracker:GetDifficultyColor(
                    quest["level"]
                );

            local titleData;

            if quest["questTag"] then

                titleData =
                    "[" ..
                    quest["level"] ..
                    "+] ";

            else

                titleData =
                    "[" ..
                    quest["level"] ..
                    "] ";

            end

            -- Completed quest titles use the same green as Questie's
            -- "(complete)" map-note label, overriding difficulty colors.
            if quest["isComplete"] then

                titleData =
                    "|cFF4CFF4C" ..
                    titleData ..
                    quest["questName"] ..
                    "|r";

            else

                titleData =
                    colorString ..
                    titleData;

                if QuestieConfig.boldColors == true then

                    titleData =
                        titleData ..
                        "|r|cFFFFFFFF" ..
                        quest["questName"] ..
                        "|r";

                else

                    titleData =
                        titleData ..
                        quest["questName"] ..
                        "|r";

                end

            end

            button.quest:SetText(titleData);
            button.quest:Show();

            local titleWidth =
                button.quest:GetStringWidth() + 36;

            local maxWidth = titleWidth;

            local obj = 1;

            if isCollapsed then

                -- Keep only the quest title visible.

            elseif quest["isComplete"] or
               quest["leaderboards"] == 0 then

                QuestieTracker:AddObjectiveToButton(
                    button,
                    {["desc"] = "Quest Complete!"},
                    obj
                );

                obj = 2;

            else

                while true do

                    local beefcake =
                        quest["objective" .. obj];

                    if beefcake == nil then
                        break;
                    end

                    if beefcake["desc"] == nil then
                        break;
                    end

                    if beefcake["type"] == "event" then

                        QuestieTracker:AddEventToButton(
                            button,
                            beefcake,
                            obj
                        );

                    else

                        QuestieTracker:AddObjectiveToButton(
                            button,
                            beefcake,
                            obj
                        );

                    end

                    local objectiveWidth =
                        button.objectives[obj]:GetStringWidth() + 40;

                    if objectiveWidth > maxWidth then
                        maxWidth = objectiveWidth;
                    end

                    obj = obj + 1;

                end

            end

            button.currentObjectiveCount =
                obj - 1;

            -- Hide stale objective font strings from a previous quest.
            local staleIndex = obj;

            while staleIndex <= 20 do

                if button.objectives[staleIndex] then

                    button.objectives[staleIndex]:SetText("");
                    button.objectives[staleIndex]:Hide();

                end

                staleIndex = staleIndex + 1;

            end

            button:SetHeight(
                14 +
                (button.currentObjectiveCount * 11)
            );

            button:SetWidth(maxWidth);

            if maxWidth >
               QuestieTracker.questButtons.maxWidth then

                QuestieTracker.questButtons.maxWidth =
                    maxWidth;

            end

            button:Show();

            if (QuestieConfig.showTrackerHeader == true) and
               (QuestieConfig.trackerEnabled == true) then

                local numEntries, numQuests =
                    QGet_NumQuestLogEntries();

                watcher:SetText(
                    "QuestLog Status: (" ..
                    numQuests ..
                    "/20)"
                );

                QuestieTrackerHeader:Show();

            end

            index = index + 1;

        end

    end

    QuestieTracker.highestIndex =
        index - 1;

    ---------------------------------------------------------------------------------------------------
    -- Hide unused buttons.
    ---------------------------------------------------------------------------------------------------

    while true do

        local d =
            QuestieTracker.questButtons[index];

        if d == nil then
            break;
        end

        d:Hide();

        index = index + 1;

    end

    ---------------------------------------------------------------------------------------------------
    -- Calculate tracker dimensions.
    ---------------------------------------------------------------------------------------------------

    if (QuestieConfig.trackerEnabled == true) and
       (QuestieConfig.trackerMinimize == false) then

        if (QuestieTracker.highestIndex >= 1) and
           (QuestieConfig.trackerBackground == false) then

            trackerWidth =
                QuestieTracker.questButtons.maxWidth;

            if QuestieConfig.trackerList == false then

                trackerHeight =
                    QuestieTracker.frame:GetTop() -
                    QuestieTracker.questButtons[
                        QuestieTracker.highestIndex
                    ]:GetBottom();

            else

                trackerHeight =
                    QuestieTracker.questButtons[
                        QuestieTracker.highestIndex
                    ]:GetTop() -
                    QuestieTracker.frame:GetBottom();

            end

            QuestieTracker.frame:SetWidth(
                trackerWidth
            );

            QuestieTracker.frame:SetHeight(
                trackerHeight
            );

        end

        QuestieTracker:updateTrackingFrameSize();

    end

    ---------------------------------------------------------------------------------------------------
    -- Restore/update tooltip if the mouse is still over the same
    -- physical button after the tracker was rebuilt.
    ---------------------------------------------------------------------------------------------------

    if previousTooltipButton then

        if previousTooltipButton:IsShown() and
           GetMouseFocus() == previousTooltipButton then

            if previousTooltipHash ~= previousTooltipButton.hash then

                QuestieTracker:ShowButtonTooltip(
                    previousTooltipButton
                );

            elseif QuestieTracker.tooltipButton == nil then

                QuestieTracker:ShowButtonTooltip(
                    previousTooltipButton
                );

            end

        elseif not previousTooltipButton:IsShown() then

            QuestieTracker:HideButtonTooltip(
                previousTooltipButton
            );

        end

    end

end

---------------------------------------------------------------------------------------------------
-- Creates a blank quest tracking frame and sets up the optional header
---------------------------------------------------------------------------------------------------

function QuestieTracker:createTrackingFrame()

    QuestieTracker.frame =
        CreateFrame(
            "Frame",
            "QuestieTrackerFrame",
            UIParent,
            "ActionButtonTemplate"
        );

    if trackerWidth == nil or
       trackerHeight == nil then

        trackerWidth = 1;
        trackerHeight = 1;

    end

    QuestieTracker.frame:SetWidth(trackerWidth);
    QuestieTracker.frame:SetHeight(trackerHeight);

    QuestieTracker.frame:SetPoint(
        QuestieTrackerVariables["position"]["point"],
        QuestieTrackerVariables["position"]["relativeTo"],
        QuestieTrackerVariables["position"]["relativePoint"],
        QuestieTrackerVariables["position"]["xOfs"],
        QuestieTrackerVariables["position"]["yOfs"]
    );

    QuestieTracker.frame:SetScale(
        QuestieConfig.trackerScale
    );

    if QuestieConfig.trackerBackground == true then

        QuestieTracker.frame:SetBackdrop({
            bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true,
            edgeSize=16,
            insets={
                left=5,
                right=5,
                top=5,
                bottom=5
            }
        });

        QuestieTracker.frame:SetBackdropColor(
            0,
            0,
            0,
            QuestieConfig.trackerAlpha
        );

    end

    QuestieTracker.frame:EnableMouse(true);
    QuestieTracker.frame:SetMovable(true);
    QuestieTracker.frame:SetClampedToScreen(true);
    QuestieTracker.frame.prevoffset = 0;

    QuestieTracker.frame:SetScript(
        "OnMouseUp",
        function()

            this:StopMovingOrSizing();
            this:SetUserPlaced(false);
            QuestieTracker:saveFramePosition();

        end
    );

    ---------------------------------------------------------------------------------------------------
    -- QuestTracker Header Button
    ---------------------------------------------------------------------------------------------------

    local header =
        CreateFrame(
            "Button",
            "QuestieTrackerHeader",
            UIParent
        );

    if QuestieConfig.trackerList == true then

        if QuestieConfig.showTrackerHeader == true then

            watcher =
                header:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormal"
                );

            watcher:SetPoint(
                "BOTTOMLEFT",
                QuestieTracker.frame,
                "BOTTOMLEFT",
                10,
                8
            );

            qmenu =
                CreateFrame(
                    "Button",
                    "QuestieTrackerMenu",
                    header
                );

            qmenu:SetPoint(
                "BOTTOMLEFT",
                QuestieTracker.frame,
                "BOTTOMLEFT",
                6,
                5
            );

        else

            watcher =
                header:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormal"
                );

            watcher:SetPoint(
                "BOTTOMLEFT",
                QuestieTracker.frame,
                "BOTTOMLEFT",
                10,
                8
            );

        end

    else

        if QuestieConfig.showTrackerHeader == true then

            watcher =
                header:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormal"
                );

            watcher:SetPoint(
                "TOPLEFT",
                QuestieTracker.frame,
                "TOPLEFT",
                6,
                -8
            );

            qmenu =
                CreateFrame(
                    "Button",
                    "QuestieTrackerMenu",
                    header
                );

            qmenu:SetPoint(
                "TOPLEFT",
                QuestieTracker.frame,
                "TOPLEFT",
                0,
                -6
            );

        else

            watcher =
                header:CreateFontString(
                    nil,
                    "OVERLAY",
                    "GameFontNormal"
                );

            watcher:SetPoint(
                "TOPLEFT",
                QuestieTracker.frame,
                "TOPLEFT",
                6,
                -8
            );

        end

    end

    ---------------------------------------------------------------------------------------------------
    -- Minimize button
    ---------------------------------------------------------------------------------------------------

    if (QuestieConfig.showTrackerHeader == true) and
       (QuestieConfig.trackerEnabled == true) then

        qmenu:SetFrameStrata("HIGH");
        qmenu:SetWidth(180);
        qmenu:SetHeight(10);

        qmenu.texture =
            qmenu:CreateTexture(
                nil,
                "BACKGROUND"
            );

        qmenu.texture:SetTexture(0,0,0);
        qmenu.texture:SetAlpha(0.0);
        qmenu.texture:SetAllPoints(qmenu);

        qmenu:EnableMouse(true);

        qmenu:SetScript(
            "OnClick",
            function()

                if QuestieConfig.trackerMinimize == false then

                    QuestieConfig.trackerMinimize = true;

                    HideTrackerTooltip();

                    QuestieTracker.frame:Hide();

                else

                    QuestieConfig.trackerMinimize = false;

                    QuestieTracker.frame:Show();

                    QuestieTracker:FillTrackingFrame();

                end

            end
        );

    end

    QuestieTrackerHeader:Hide();
    QuestieTracker.frame:Hide();

end

---------------------------------------------------------------------------------------------------
-- EQL3 login fix
---------------------------------------------------------------------------------------------------

function Questie:LoadEQL3Fix()

    if IsAddOnLoaded("EQL3") and
       not IsAddOnLoaded("ShaguQuest") then

        local EQL_Loader =
            CreateFrame("Frame", nil);

        EQL_Loader.tick = GetTime();
        EQL_Loader.step = 0;

        EQL_Loader:SetScript(
            "OnUpdate",
            function()

                if EQL_Loader.tick + 1 <= GetTime() then

                    EQL_Loader.abort = false;

                    QuestWatch_Update();

                    EQL_Loader.tick =
                        GetTime();

                    if EQL_Loader.step < 10 then

                        EQL_Loader.step =
                            EQL_Loader.step + 1;

                    else

                        EQL_Loader:Hide();

                    end

                end

            end
        );

        local QQuestWatch_Update =
            QuestWatch_Update;

        function QuestWatch_Update()

            if EQL_Loader.abort == nil then
                EQL_Loader.abort = true;
            end

            if (not EQL3_Temp.hasManaged) or
               (EQL_Loader.abort == true and
                EQL_Loader.step < 10) then

                QuestWatchFrame:Hide();

                return;

            end

            EQL_Loader.abort = true;

            QQuestWatch_Update();

        end

    end

end

---------------------------------------------------------------------------------------------------
-- Adds or removes quests to be tracked from the quest tracker.
---------------------------------------------------------------------------------------------------

function QuestLogTitleButton_OnClick(button)

    if IsAddOnLoaded("EQL3") or
       IsAddOnLoaded("ShaguQuest") then

        local questName =
            this:GetText();

        local questIndex =
            this:GetID() +
            FauxScrollFrame_GetOffset(
                EQL3_QuestLogListScrollFrame
            );

        if button == "LeftButton" then

            if IsShiftKeyDown() then

                if IsControlKeyDown() then

                    if this.isHeader then
                        return;
                    end

                    if not ChatFrameEditBox:IsVisible() then

                        EQL3_ClearTracker();
                        AddQuestWatch(questIndex);

                        Questie:AddEvent(
                            "SYNCLOG",
                            0
                        );

                        QuestWatch_Update();

                    end

                else

                    local questLogTitleText;
                    local isHeader;
                    local isCollapsed;
                    local firstTrackable;
                    local lastTrackable;
                    local numTracked;
                    local numUntracked;

                    lastTrackable = -1;
                    numTracked = 0;
                    numUntracked = 0;

                    local track = false;

                    if this.isHeader then

                        local i = 1;
                        local qc = 0;

                        local nEntry, nQuests =
                            QGet_NumQuestLogEntries();

                        local tEntry = nQuests;

                        while qc < nQuests do

                            questLogTitleText,
                            _,
                            _,
                            isHeader,
                            isCollapsed,
                            _ =
                                QGet_QuestLogTitle(i);

                            if questLogTitleText == questName then

                                track = true;
                                firstTrackable = i + 1;

                            elseif track then

                                if not isHeader then

                                    if IsQuestWatched(i) then

                                        numTracked =
                                            numTracked + 1;

                                        RemoveQuestWatch(i);

                                    else

                                        numUntracked =
                                            numUntracked + 1;

                                        RemoveQuestWatch(i);

                                    end

                                end

                                if isHeader and
                                   questLogTitleText ~= questName then

                                    lastTrackable = i - 1;
                                    break;

                                end

                            end

                            if not isHeader then
                                qc = qc + 1;
                            else
                                tEntry = tEntry + 1;
                            end

                            i = i + 1;

                        end

                        if lastTrackable == -1 then
                            lastTrackable = tEntry;
                        end

                        if numUntracked == 0 then

                            for i=firstTrackable,
                                lastTrackable,
                                1 do

                                RemoveQuestWatch(i);

                            end

                        else

                            for i=firstTrackable,
                                lastTrackable,
                                1 do

                                AddQuestWatch(i);

                            end

                        end

                        Questie:AddEvent(
                            "SYNCLOG",
                            0
                        );

                        if QuestieConfig["alwaysShowObjectives"] == false then

                            Questie:AddEvent(
                                "DRAWNOTES",
                                0.1
                            );

                        end

                        QuestWatch_Update();
                        QuestLog_Update();

                        return;

                    end

                    if ChatFrameEditBox:IsVisible() then

                        local text =
                            this:GetText();

                        if QuestieConfig.useQuestLinks then

                            text =
                                "|cffffff00|Hquest:0:0:0:0|h[" ..
                                gsub(
                                    text,
                                    ".*%] (.*)",
                                    "%1"
                                ) ..
                                "]|h|r";

                        end

                        ChatFrameEditBox:Insert(text);

                    elseif WIM_EditBoxInFocus then

                        local text =
                            this:GetText();

                        if QuestieConfig.useQuestLinks then

                            text =
                                "|cffffff00|Hquest:0:0:0:0|h[" ..
                                gsub(
                                    text,
                                    ".*%] (.*)",
                                    "%1"
                                ) ..
                                "]|h|r";

                        end

                        WIM_EditBoxInFocus:Insert(text);

                    else

                        if IsQuestWatched(questIndex) then

                            RemoveQuestWatch(questIndex);

                        else

                            if GetNumQuestWatches() >= 20 then

                                UIErrorsFrame:AddMessage(
                                    format(
                                        QUEST_WATCH_TOO_MANY,
                                        "20"
                                    ),
                                    1.0,
                                    0.1,
                                    0.1,
                                    1.0,
                                    UIERRORS_HOLD_TIME
                                );

                                return;

                            end

                            AddQuestWatch(questIndex);

                        end

                        Questie:AddEvent(
                            "SYNCLOG",
                            0
                        );

                        if QuestieConfig["alwaysShowObjectives"] == false then

                            Questie:AddEvent(
                                "DRAWNOTES",
                                0.1
                            );

                        end

                        QuestWatch_Update();

                    end

                end

            end

        end

        if QuestLog_SetSelection(questIndex) == 1 then

            if (not EQL3_QuestLogFrame_Description:IsVisible() and
                not IsShiftKeyDown() and
                not IsControlKeyDown() and
                QuestlogOptions[EQL3_Player].RestoreUponSelect == 1) then

                EQL3_Maximize();

            end

        end

        if button == "LeftButton" then

            if (not IsShiftKeyDown() and
                IsControlKeyDown()) then

                if ChatFrameEditBox:IsVisible() then

                    AddQuestStatusToChatFrame(
                        questIndex,
                        questName
                    );

                end

            end

        else

            if not this.isHeader then

                if EQL3_IsQuestWatched(questIndex) then

                    EQL3_Organize_Popup_Track_Text:SetText(
                        EQL3_POPUP_UNTRACK
                    );

                else

                    EQL3_Organize_Popup_Track_Text:SetText(
                        EQL3_POPUP_TRACK
                    );

                end

                EQL3_Organize_Popup:ClearAllPoints();

                EQL3_Organize_Popup:SetPoint(
                    "TOPLEFT",
                    this,
                    "TOPLEFT",
                    24,
                    0
                );

                EQL3_Organize_Popup:Raise();
                EQL3_Organize_Popup:Show();

            end

        end

        QuestLog_Update();

    else

        local prevQuestLogSelection =
            QGet_QuestLogSelection();

        local questName =
            this:GetText();

        local questIndex =
            this:GetID() +
            FauxScrollFrame_GetOffset(
                QuestLogListScrollFrame
            );

        local qName,
              level,
              questTag,
              isHeader,
              isCollapsed,
              isComplete =
            QGet_QuestLogTitle(questIndex);

        QSelect_QuestLogEntry(questIndex);

        local questText,
              objectiveText =
            QGet_QuestLogQuestText();

        if IsShiftKeyDown() then

            if this.isHeader then
                return;
            end

            local hash =
                Questie:getQuestHash(
                    qName,
                    level,
                    objectiveText,
                    headerName
                );

            if ChatFrameEditBox:IsVisible() then

                local text =
                    this:GetText();

                if QuestieConfig.useQuestLinks then

                    text =
                        "|cffffff00|Hquest:0:0:0:0|h[" ..
                        gsub(
                            text,
                            "  (.)",
                            "%1"
                        ) ..
                        "]|h|r";

                end

                ChatFrameEditBox:Insert(text);

            elseif WIM_EditBoxInFocus then

                local text =
                    this:GetText();

                if QuestieConfig.useQuestLinks then

                    text =
                        "|cffffff00|Hquest:0:0:0:0|h[" ..
                        gsub(
                            text,
                            "  (.)",
                            "%1"
                        ) ..
                        "]|h|r";

                end

                WIM_EditBoxInFocus:Insert(text);

            else

                if IsQuestWatched(questIndex) then

                    Questie:debug_Print(
                        "Tracker:QuestLogTitleButton_OnClick --> RemoveQuestWatch: [Id: " ..
                        questIndex ..
                        "] | [hash: " ..
                        hash ..
                        "]"
                    );

                    RemoveQuestWatch(questIndex);

                else

                    AddQuestWatch(questIndex);

                    Questie:debug_Print(
                        "Tracker:QuestLogTitleButton_OnClick --> AutoQuestWatch_Insert: [Id: " ..
                        questIndex ..
                        "] | [hash: " ..
                        hash ..
                        "]"
                    );

                end

                Questie:AddEvent(
                    "SYNCLOG",
                    0
                );

                if QuestieConfig["alwaysShowObjectives"] == false then

                    Questie:AddEvent(
                        "DRAWNOTES",
                        0.02
                    );

                end

                QuestWatch_Update();

            end

        end

        QSelect_QuestLogEntry(
            prevQuestLogSelection
        );

        QuestLog_SetSelection(
            questIndex
        );

        QuestLog_Update();

    end

end

---------------------------------------------------------------------------------------------------
-- Expand a collapsed tracker entry when one of its objectives changes.
---------------------------------------------------------------------------------------------------

local function expandQuestOnProgressChange(
    hash,
    questName,
    logId,
    leaderboards,
    isComplete
)

    local cachedQuest = QuestieCachedQuests[hash];

    if not cachedQuest then
        return;
    end

    local hadObjectives = false;
    local progressChanged = false;

    for i = 1, 20 do

        local oldObjective = cachedQuest["objective" .. i];

        if oldObjective then

            hadObjectives = true;

            local desc, objectiveType, done =
                QGet_QuestLogLeaderBoard(i, logId);

            if i > leaderboards then
                progressChanged = true;
            else

                local expectedDesc = desc;
                local expectedDone = done == 1 or done == true;

                if isComplete or leaderboards == 0 or expectedDone then
                    expectedDesc = "Quest Complete!";
                    expectedDone = true;
                end

                if oldObjective["desc"] ~= expectedDesc or
                   (oldObjective["done"] == true or oldObjective["done"] == 1) ~= expectedDone then
                    progressChanged = true;
                end

            end

        elseif hadObjectives and i <= leaderboards then
            progressChanged = true;
        end

    end

    if progressChanged and hadObjectives and questName and
       QuestieTracker.collapsedQuests then
        QuestieTracker.collapsedQuests[questName] = nil;
    end

end

---------------------------------------------------------------------------------------------------
-- If a quest is tracked, add quest to tracker and retrieve cached quest data
---------------------------------------------------------------------------------------------------

local function trim(s)

    return string.gsub(
        s,
        "^%s*(.-)%s*$",
        "%1"
    );

end

---------------------------------------------------------------------------------------------------

function QuestieTracker:addQuestToTrackerCache(
    hash,
    logId,
    level
)

    if not QuestieCachedQuests[hash] then
        QuestieCachedQuests[hash] = {};
    end

    if not logId then
        logId = Questie:GetQuestIdFromHash(hash);
    end

    if logId == nil then

        DEFAULT_CHAT_FRAME:AddMessage(
            "TrackerError! LogId still nil after GetQuestIdFromHash " ..
            tostring(hash)
        );

        return;

    end

    local questName,
          questLevel,
          questTag,
          isHeader,
          isCollapsed,
          isComplete =
        QGet_QuestLogTitle(logId);

    QuestieCachedQuests[hash]["tracked"] =
        QuestieCachedQuests[hash]["tracked"] == true;

    QuestieCachedQuests[hash]["questName"] =
        questName;

    QuestieCachedQuests[hash]["level"] =
        questLevel;

    QuestieCachedQuests[hash]["logId"] =
        logId;

    QuestieCachedQuests[hash]["questTag"] =
        questTag;

    QuestieCachedQuests[hash]["isComplete"] =
        isComplete;

    local leaderboards =
        QGet_NumQuestLeaderBoards(logId);

    QuestieCachedQuests[hash]["leaderboards"] =
        leaderboards;

    -- Expand a collapsed entry if any objective progress changed since the last cache.
    expandQuestOnProgressChange(
        hash,
        questName,
        logId,
        leaderboards,
        isComplete
    );

    -- Remove objectives from the previous quest state.
    for i=1, 20 do
        QuestieCachedQuests[hash]["objective"..i] = nil;
    end

    for i=1, leaderboards do

        local desc,
              type,
              done =
            QGet_QuestLogLeaderBoard(
                i,
                logId
            );

        if isComplete or
           leaderboards == 0 or
           done == 1 then

            RemoveCrazyArrow(hash);

            QuestieCachedQuests[hash]["objective"..i] = {
                ["desc"] = "Quest Complete!",
                ["type"] = type,
                ["done"] = true,
                ["notes"] = {},
            };

        else

            QuestieCachedQuests[hash]["objective"..i] = {
                ["desc"] = desc,
                ["type"] = type,
                ["done"] = done,
                ["notes"] = {},
            };

        end

    end

    local objective1 =
        QuestieCachedQuests[hash]["objective1"];

    if objective1 then

        if (objective1["done"] ~= true and
            objective1["done"] ~= 1) or
           objective1["type"] == nil or
           not QuestieCachedQuests[hash]["arrowPoint"] then

            QuestieTracker:updateTrackerCache(
                hash,
                logId,
                questLevel
            );

        end

    end

end

---------------------------------------------------------------------------------------------------
-- Updates quest log index
---------------------------------------------------------------------------------------------------

function QuestieTracker:updateQuestWatchLogId(
    hash,
    logId
)

    if QUEST_WATCH_LIST[hash] and
       QUEST_WATCH_LIST[hash].questIndex ~= logId then

        Questie:debug_Print(
            "QuestieTracker:updateQuestWatchLogId: QUEST_WATCH_LIST[" ..
            hash ..
            "].questIndex changed from " ..
            QUEST_WATCH_LIST[hash].questIndex ..
            " to " ..
            logId
        );

        QUEST_WATCH_LIST[hash].questIndex =
            logId;

    end

    if QuestieCachedQuests[hash] and
       QuestieCachedQuests[hash].logId ~= logId then

        Questie:debug_Print(
            "QuestieTracker:updateQuestWatchLogId: QuestieCachedQuests[" ..
            hash ..
            "].logId changed from " ..
            QuestieCachedQuests[hash].logId ..
            " to " ..
            logId
        );

        QuestieCachedQuests[hash].logId =
            logId;

    end

end

---------------------------------------------------------------------------------------------------
-- If a quest is tracked, update quest on tracker and cache
---------------------------------------------------------------------------------------------------

function QuestieTracker:updateTrackerCache(
    hash,
    logId,
    level
)

    if (not QUEST_WATCH_LIST[logId]) and
       (not QuestieCachedQuests[hash]) then

        QuestieTracker:addQuestToTrackerCache(
            hash,
            logId,
            level
        );

    end

    if not QuestieCachedQuests[hash] then
        QuestieCachedQuests[hash] = {};
    end

    if not logId then
        logId = Questie:GetQuestIdFromHash(hash);
    end

    if logId == nil then

        DEFAULT_CHAT_FRAME:AddMessage(
            "TrackerError! LogId still nil after GetQuestIdFromHash " ..
            tostring(hash)
        );

        return;

    end

    local questName,
          questLevel,
          questTag,
          isHeader,
          isCollapsed,
          isComplete =
        QGet_QuestLogTitle(logId);

    QuestieCachedQuests[hash]["questName"] =
        questName;

    QuestieCachedQuests[hash]["isComplete"] =
        isComplete;

    QuestieCachedQuests[hash]["questTag"] =
        questTag;

    QuestieCachedQuests[hash]["level"] =
        questLevel;

    QuestieCachedQuests[hash]["logId"] =
        logId;

    local leaderboards =
        QGet_NumQuestLeaderBoards(logId);

    QuestieCachedQuests[hash]["leaderboards"] =
        leaderboards;

    QuestieTracker:updateQuestWatchLogId(
        hash,
        logId
    );

    -- Expand a collapsed entry if any objective progress changed since the last cache.
    expandQuestOnProgressChange(
        hash,
        questName,
        logId,
        leaderboards,
        isComplete
    );

    -- Clear stale objectives.
    for i=1, 20 do
        QuestieCachedQuests[hash]["objective"..i] = nil;
    end

    for i=1, leaderboards do

        local desc,
              type,
              done =
            QGet_QuestLogLeaderBoard(
                i,
                logId
            );

        QuestieCachedQuests[hash]["objective"..i] = {
            ["desc"] = desc,
            ["type"] = type,
            ["done"] = done,
            ["notes"] = {},
        };

    end

end

---------------------------------------------------------------------------------------------------
-- Adds quest from tracker when tracked
---------------------------------------------------------------------------------------------------

function QuestieTracker:addQuestToTracker(hash)

    if QuestieCachedQuests[hash] and
       QuestieCachedQuests[hash]["tracked"] ~= true then

        QuestieCachedQuests[hash]["tracked"] = true;

    end

end

---------------------------------------------------------------------------------------------------
-- Removes quest from tracker
---------------------------------------------------------------------------------------------------

function QuestieTracker:removeQuestFromTracker(hash)

    if QuestieSeenQuests[hash] == 0 and
       QuestieCachedQuests[hash] ~= nil then

        QuestieCachedQuests[hash]["tracked"] = false;

        RemoveCrazyArrow(hash);

    end

end

---------------------------------------------------------------------------------------------------
-- Blizzard Hooks
---------------------------------------------------------------------------------------------------

function QuestieTracker:BlizzardHooks()

    if not IsAddOnLoaded("EQL3") and
       not IsAddOnLoaded("ShaguQuest") then

        ---------------------------------------------------------------------------------------------------
        -- Hooks Blizzard's AddQuestWatch
        ---------------------------------------------------------------------------------------------------

        QAddQuestWatch =
            AddQuestWatch;

        function AddQuestWatch(questIndex)

            local prevQuestLogSelection =
                QGet_QuestLogSelection();

            local questName,
                  level,
                  questTag,
                  isHeader,
                  isCollapsed,
                  isComplete =
                QGet_QuestLogTitle(questIndex);

            QSelect_QuestLogEntry(questIndex);

            local questText,
                  objectiveText =
                QGet_QuestLogQuestText();

            local hash =
                Questie:getQuestHash(
                    questName,
                    level,
                    objectiveText
                );

            if not QUEST_WATCH_LIST[hash] then
                QUEST_WATCH_LIST[hash] = {};
            end

            if QuestieCachedQuests[hash] then

                QUEST_WATCH_LIST[hash]["questIndex"] =
                    questIndex;

                QUEST_WATCH_LIST[hash]["questName"] =
                    questName;

            end

            QSelect_QuestLogEntry(
                prevQuestLogSelection
            );

            QAddQuestWatch(questIndex);

        end

        ---------------------------------------------------------------------------------------------------
        -- Hooks Blizzard's RemoveQuestWatch
        ---------------------------------------------------------------------------------------------------

        QRemoveQuestWatch =
            RemoveQuestWatch;

        function RemoveQuestWatch(questIndex)

            local prevQuestLogSelection =
                QGet_QuestLogSelection();

            local questName,
                  level,
                  questTag,
                  isHeader,
                  isCollapsed,
                  isComplete =
                QGet_QuestLogTitle(questIndex);

            QSelect_QuestLogEntry(questIndex);

            local questText,
                  objectiveText =
                QGet_QuestLogQuestText();

            local hash =
                Questie:getQuestHash(
                    questName,
                    level,
                    objectiveText
                );

            if QuestieCachedQuests[hash] then
                QUEST_WATCH_LIST[hash] = nil;
            end

            QSelect_QuestLogEntry(
                prevQuestLogSelection
            );

            QRemoveQuestWatch(questIndex);

        end

        ---------------------------------------------------------------------------------------------------
        -- Disable Blizzard AutoQuestWatch functions.
        ---------------------------------------------------------------------------------------------------

        QAutoQuestWatch_CheckDeleted =
            AutoQuestWatch_CheckDeleted;

        function AutoQuestWatch_CheckDeleted()
        end

        ---------------------------------------------------------------------------------------------------

        QAutoQuestWatch_Update =
            AutoQuestWatch_Update;

        function AutoQuestWatch_Update(questIndex)
        end

        ---------------------------------------------------------------------------------------------------

        QAutoQuestWatch_OnUpdate =
            AutoQuestWatch_OnUpdate;

        function AutoQuestWatch_OnUpdate(elapsed)

            if QuestieConfig.trackerEnabled == true then
                QuestWatchFrame:Hide();
            end

        end

        ---------------------------------------------------------------------------------------------------
        -- Hooks Blizzard's IsQuestWatched
        ---------------------------------------------------------------------------------------------------

        QIsQuestWatched =
            IsQuestWatched;

        function IsQuestWatched(id)

            local isWatched = false;

            local questName,
                  level,
                  questTag,
                  isHeader,
                  isCollapsed,
                  isComplete =
                QGet_QuestLogTitle(id);

            if not isHeader then

                local prevQuestLogSelection =
                    QGet_QuestLogSelection();

                QSelect_QuestLogEntry(id);

                local questText,
                      objectiveText =
                    QGet_QuestLogQuestText();

                local hash =
                    Questie:getQuestHash(
                        questName,
                        level,
                        objectiveText
                    );

                if QuestieCachedQuests[hash] then

                    if QUEST_WATCH_LIST[hash] then
                        isWatched = true;
                    end

                end

                QSelect_QuestLogEntry(
                    prevQuestLogSelection
                );

            end

            QIsQuestWatched(id);

            return isWatched;

        end

    end

end

---------------------------------------------------------------------------------------------------
-- Sync Quest Watch
---------------------------------------------------------------------------------------------------

function QuestieTracker:syncQuestWatch()

    if IsAddOnLoaded("EQL3") or
       IsAddOnLoaded("ShaguQuest") then

        return;

    end

    if AUTO_QUEST_WATCH ~= "1" then
        return;
    end

    local changed = false;

    for hash, v in pairs(QuestieCachedQuests) do

        if hash and v["logId"] then

            local id = v["logId"];

            if QuestieSeenQuests[hash] == 0 and
               v["tracked"] == true then

                AddQuestWatch(id);
                changed = true;

            elseif QuestieSeenQuests[hash] == 0 and
                   v["tracked"] == false then

                RemoveQuestWatch(id);
                changed = true;

            end

        end

    end

    -- One update after the entire watch list has been synchronized.
    if changed then

        QuestWatch_Update();

    end

    if QuestieConfig.trackerEnabled == true then

        QuestWatchFrame:Hide();

    end

    QuestieTracker:FillTrackingFrame();

end

---------------------------------------------------------------------------------------------------
-- Checks and flags tracked quest status
---------------------------------------------------------------------------------------------------

function QuestieTracker:syncQuestLog()

    Questie:debug_Print(
        "****************| Running QuestieTracker:syncQuestLog |**************** "
    );

    if IsAddOnLoaded("EQL3") or
       IsAddOnLoaded("ShaguQuest") then

        QuestLogSync =
            EQL3_IsQuestWatched;

    else

        QuestLogSync =
            IsQuestWatched;

    end

    local prevQuestLogSelection =
        QGet_QuestLogSelection();

    local id = 1;
    local qc = 0;

    local nEntry,
          nQuests =
        QGet_NumQuestLogEntries();

    while qc < nQuests do

        local isWatched =
            QuestLogSync(id);

        local questName,
              level,
              questTag,
              isHeader,
              isCollapsed,
              isComplete =
            QGet_QuestLogTitle(id);

        if not isHeader and
           not isCollapsed then

            QSelect_QuestLogEntry(id);

            local questText,
                  objectiveText =
                QGet_QuestLogQuestText();

            local hash =
                Questie:getQuestHash(
                    questName,
                    level,
                    objectiveText
                );

            QuestieTracker:updateQuestWatchLogId(
                hash,
                id
            );

            if isWatched and
               QuestieCachedQuests[hash] and
               QuestieCachedQuests[hash]["tracked"] ~= true then

                Questie:debug_Print(
                    "Tracker:syncQuestLog --> addQuestToTracker: Flagging [Hash: " ..
                    hash ..
                    "] TRUE"
                );

                QuestieTracker:addQuestToTracker(
                    hash
                );

            elseif not isWatched and
                   QuestieCachedQuests[hash] and
                   QuestieCachedQuests[hash]["tracked"] ~= false then

                Questie:debug_Print(
                    "Tracker:syncQuestLog --> removeQuestFromTracker: Flagging [Hash: " ..
                    hash ..
                    "] FALSE"
                );

                QuestieTracker:removeQuestFromTracker(
                    hash
                );

            end

        end

        if not isHeader then
            qc = qc + 1;
        end

        id = id + 1;

    end

    QSelect_QuestLogEntry(
        prevQuestLogSelection
    );

    QuestieTracker:FillTrackingFrame();

end

---------------------------------------------------------------------------------------------------
-- Saves the position of the tracker after the user moves it
---------------------------------------------------------------------------------------------------

function QuestieTracker:saveFramePosition()

    local frame =
        getglobal("QuestieTrackerFrame");

    local resolution =
        ({GetScreenResolutions()})[
            GetCurrentResolution()
        ];

    local _, _, x, y =
        string.find(
            resolution,
            "(%d+)x(%d+)"
        );

    if not x or not y then
        return;
    end

    local scrndiv =
        tonumber(x) / 2;

    local point,
          _,
          relativePoint,
          xOfs,
          yOfs =
        frame:GetPoint();

    if QuestieTracker.frame:GetLeft() < scrndiv then

        if QuestieConfig.trackerList == true then

            QuestieTrackerVariables["position"] = {
                ["point"] = "BOTTOMLEFT",
                ["relativePoint"] = "BOTTOMLEFT",
                ["relativeTo"] = "UIParent",
                ["yOfs"] = QuestieTracker.frame:GetBottom(),
                ["xOfs"] = QuestieTracker.frame:GetLeft(),
            };

        else

            QuestieTrackerVariables["position"] = {
                ["point"] = "TOPLEFT",
                ["relativePoint"] = "TOPLEFT",
                ["relativeTo"] = "UIParent",
                ["yOfs"] = yOfs,
                ["xOfs"] = xOfs,
            };

        end

    else

        if QuestieConfig.trackerList == true then

            QuestieTrackerVariables["position"] = {
                ["point"] = "BOTTOMRIGHT",
                ["relativePoint"] = "BOTTOMLEFT",
                ["relativeTo"] = "UIParent",
                ["yOfs"] = QuestieTracker.frame:GetBottom(),
                ["xOfs"] = QuestieTracker.frame:GetRight(),
            };

        else

            QuestieTrackerVariables["position"] = {
                ["point"] = "TOPRIGHT",
                ["relativePoint"] = "TOPLEFT",
                ["relativeTo"] = "UIParent",
                ["yOfs"] = yOfs,
                ["xOfs"] = QuestieTracker.frame:GetRight(),
            };

        end

    end

end

---------------------------------------------------------------------------------------------------
-- Load World Map Module
---------------------------------------------------------------------------------------------------



local MAP_WIDTH = 1024;
local MAP_HEIGHT = 768;
local MAP_SCALE = 0.8;
local FADE_ALPHA = 0.35;
local MAP_STRATA = "LOW";


QuestieMapFadeOffZoneInterval = 1;

local function QuestieMapFadeSwitchPos()
    local vc, vz = GetCurrentMapContinent(), GetCurrentMapZone();

    SetMapToCurrentZone();

    local c, z = GetCurrentMapContinent(), GetCurrentMapZone();
    local px, py = GetPlayerMapPosition("player");

    -- Restore whatever map the player was looking at
    if vc ~= c or vz ~= z then
        if vz and vz > 0 then
            SetMapZoom(vc, vz);
        else
            SetMapZoom(vc);
        end
    end

    if px and py and (px ~= 0 or py ~= 0) then
        return c, z, px, py;
    end

    return nil;
end

-- Map fade: faded while the player is moving, never on a flight path.
local function QuestieSetupMapFade()
    if QuestieMapFadeFrame then
        return;
    end

    QuestieMapFadeFrame = CreateFrame("Frame");
    QuestieMapFadeFrame.elapsed = 0;
    QuestieMapFadeFrame.nextCheck = 0;
    QuestieMapFadeFrame.movingUntil = 0;

    QuestieMapFadeFrame:SetScript("OnUpdate", function()
        if not WorldMapFrame:IsVisible() then
            this.elapsed = 0;
            this.nextCheck = 0;
            this.lastX = nil;
            return;
        end

        this.elapsed = this.elapsed + arg1;

        if this.elapsed < 0.1 then
            return;
        end

        this.elapsed = 0;

        local now = GetTime();
        local x, y = GetPlayerMapPosition("player");
        local c, z, hold;
        local sample = true;

        if x and y and (x ~= 0 or y ~= 0) then
            -- Viewing the player's own zone: cheap native read
            c, z = GetCurrentMapContinent(), GetCurrentMapZone();
            hold = 0.3;
        elseif now >= this.nextCheck then
            -- Viewing another zone: throttled switch-and-restore read
            this.nextCheck = now + QuestieMapFadeOffZoneInterval;
            c, z, x, y = QuestieMapFadeSwitchPos();
            hold = QuestieMapFadeOffZoneInterval + 0.2;
        else
            sample = false;
        end

        if sample then
            if c then
                if this.lastX and this.lastC == c and this.lastZ == z and
                   (x ~= this.lastX or y ~= this.lastY) then
                    this.movingUntil = now + hold;
                end

                this.lastC, this.lastZ, this.lastX, this.lastY = c, z, x, y;
            else
                this.lastX = nil;
            end
        end

        if UnitOnTaxi("player") then
            this.movingUntil = 0;
            WorldMapFrame:SetAlpha(1.0);
        elseif now < this.movingUntil then
            WorldMapFrame:SetAlpha(FADE_ALPHA);
        else
            WorldMapFrame:SetAlpha(1.0);
        end
    end);
end

-- Click-through map: interactive only while Shift or Ctrl is held
-- (for notes and POIs). No drag registration here at all.
local function QuestieSetupClickThrough()
    if QuestieClickThrough then
        return;
    end

    QuestieClickThrough = CreateFrame("Frame");

    QuestieClickThrough:SetScript("OnUpdate", function()
        if not WorldMapFrame:IsVisible() then
            return;
        end

        local interactive = IsShiftKeyDown() or IsControlKeyDown();
        local isOn = WorldMapButton:IsMouseEnabled();

        if interactive and not isOn then
            WorldMapFrame:EnableMouse(true);
            WorldMapButton:EnableMouse(true);
        elseif (not interactive) and isOn then
            WorldMapFrame:EnableMouse(false);
            WorldMapButton:EnableMouse(false);
        end
    end);
end

-- Title bar drag handle. This is the only always-clickable part of the map.
local function QuestieSetupTitleBar()
    if QuestieMapTitleBar then
        return;
    end

    local bar = CreateFrame("Frame", "QuestieMapTitleBar", WorldMapFrame);

    bar:SetHeight(28);
    bar:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 0, 0);
    bar:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", 0, 0);
    bar:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 1);

    bar:EnableMouse(true);
    bar:RegisterForDrag("LeftButton");

    bar:SetScript("OnDragStart", function()
        WorldMapFrame:StartMoving();
    end);

    bar:SetScript("OnDragStop", function()
        WorldMapFrame:StopMovingOrSizing();

        WorldMapFrame:SetWidth(MAP_WIDTH);
        WorldMapFrame:SetHeight(MAP_HEIGHT);

        local x, y = WorldMapFrame:GetCenter();

        local z = UIParent:GetEffectiveScale() / 2 / WorldMapFrame:GetScale();

        x = x - GetScreenWidth() * z;
        y = y - GetScreenHeight() * z;

        WorldMapFrame:ClearAllPoints();
        WorldMapFrame:SetPoint("CENTER", "UIParent", "CENTER", x, y);
    end);

    QuestieMapTitleBar = bar;
end

-- Click-through map clicks, caught on WorldFrame because the map ignores the
-- mouse. Left click = zoom in, right click = zoom out. Only a quick tap counts
-- as a click, so holding a button to steer or run never zooms. Ignored while
-- Shift/Ctrl is held (the map handles its own clicks then).
local function QuestieSetupWorldClicks()
    WorldFrame:SetScript("OnMouseDown", function()
        QuestieMapClickDown = GetTime();
    end);

    WorldFrame:SetScript("OnMouseUp", function()
        if not WorldMapFrame:IsVisible()
           or not MouseIsOver(WorldMapButton)
           or IsShiftKeyDown() or IsControlKeyDown()
           or not QuestieMapClickDown or GetTime() - QuestieMapClickDown > 0.25 then
            return;
        end

        if arg1 == "LeftButton" then
            local x, y = GetCursorPosition();
            local s = WorldMapButton:GetEffectiveScale();

            ProcessMapClick(
                (x / s - WorldMapButton:GetLeft()) / WorldMapButton:GetWidth(),
                (WorldMapButton:GetTop() - y / s) / WorldMapButton:GetHeight()
            );

        elseif arg1 == "RightButton" and (GetCurrentMapZone() > 0 or GetCurrentMapContinent() > 0) then
            WorldMapZoomOutButton_OnClick();
        end
    end);
end

function QuestieTracker:LoadModule()

    if not QuestieTrackerVariables then
        QuestieTrackerVariables = {};
    end

    -- SavedVariables are reliable only after VARIABLES_LOADED. Do not cache
    -- this table while the addon files are being executed: that can leave the
    -- tracker pointing at a temporary table instead of the persisted one.
    QuestieConfig = QuestieConfig or {};
    QuestieConfig["trackerCollapsedQuests"] =
        QuestieConfig["trackerCollapsedQuests"] or {};
    QuestieTracker.collapsedQuests =
        QuestieConfig["trackerCollapsedQuests"];

    if not QuestieTrackerVariables["position"] then
        QuestieTrackerVariables["position"] = {
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER",
            xOfs = 0,
            yOfs = 0,
        };
    end

    -- Only take over the world map when enabled and no other map addon is loaded
    if (QuestieConfig == nil)
       or (QuestieConfig.resizeWorldmap == nil)
       or (QuestieConfig.resizeWorldmap == false)
       or IsAddOnLoaded("Cartographer")
       or IsAddOnLoaded("MetaMap") then
        return;
    end

    -- Do NOT register the map as a UI panel. As a "center" panel it fights
    -- with the other windows, which is what blocked opening interfaces while
    -- the map was open. Unregistered, ShowUIPanel/HideUIPanel just Show/Hide
    -- it and nothing else closes it or gets blocked by it.
    UIPanelWindows["WorldMapFrame"] = nil;

    -- Let ESC still close the map
    if not QuestieMapEscRegistered then
        QuestieMapEscRegistered = true;
        tinsert(UISpecialFrames, "WorldMapFrame");
    end

    -- Keep the map BEHIND other windows (quest log, bags, spellbook, ...)
    WorldMapFrame:SetFrameStrata(MAP_STRATA);

    -- Remove the key handler AND stop the frame from capturing the keyboard.
    -- Without EnableKeyboard(false) the map swallows keys like L while open.
    WorldMapFrame:SetScript("OnKeyDown", nil);
    WorldMapFrame:EnableKeyboard(false);

    WorldMapFrame:EnableMouse(false);
    WorldMapFrame:SetMovable(true);
    WorldMapFrame:SetScale(MAP_SCALE);
    WorldMapTooltip:SetScale(1);

    WorldMapFrame:SetWidth(MAP_WIDTH);
    WorldMapFrame:SetHeight(MAP_HEIGHT);

    WorldMapFrame:ClearAllPoints();
    WorldMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);

    BlackoutWorld:Hide();

    WorldMapFrame:SetScript("OnShow", function()
        SetMapZoom(GetCurrentMapContinent(), GetCurrentMapZone());
        SetMapToCurrentZone();
    end);

    QuestieSetupMapFade();
    QuestieSetupClickThrough();
    QuestieSetupTitleBar();
    QuestieSetupWorldClicks();

end
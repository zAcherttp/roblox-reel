--!strict
-- Panel: a take's own text beside the picture, for a feature showcase (what changed, and what the
-- viewer is looking at): a side panel, half the screen by default, holding a tag, a title, a few
-- lines, a "you're seeing" line and a counter; or a card across the whole screen, for a title and
-- an outro. A take mounts it when its reel asks (`panel = { side, share, font, accent }`), keeps
-- it visible while the stage hides the rest, and its beats fill it (`take.panel.show`, `.card`,
-- `.clear`). New content slides in. The game names its font and colours; Reel only lays it out.
local TweenService = game:GetService("TweenService")

local Panel = {}

Panel.Name = "Reel_Panel"

export type Options = {
    side: ("left" | "right")?,
    share: number?,
    font: Font?,
    accent: Color3?,
    background: Color3?,
    text: Color3?,
    -- Draw the panel and the card without a background, the picture showing through: over a Cyc's
    -- void the two are one colour exactly (a background colour only comes close, the void being
    -- rendered in 3D). Frame the void behind a card.
    seeThrough: boolean?,
}

export type Content = {
    tag: string?,
    title: string,
    lines: { string }?,
    seeing: string?,
    counter: string?,
}

export type Card = { title: string, lines: { string }? }

export type Panel = {
    gui: ScreenGui,
    side: Frame,
    content: CanvasGroup,
    tag: TextLabel,
    title: TextLabel,
    lines: TextLabel,
    seeingHead: TextLabel,
    seeing: TextLabel,
    counter: TextLabel,
    card: CanvasGroup,
    cardTitle: TextLabel,
    cardLines: TextLabel,
}

-- The api a take's beats get: fills the panel, or does nothing when the reel has none.
export type Api = {
    show: (content: Content) -> (),
    card: (card: Card) -> (),
    clear: () -> (),
}

local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local function label(
    parent: Instance,
    name: string,
    font: Font,
    colour: Color3,
    size: UDim2,
    position: UDim2,
    align: Enum.TextXAlignment?
): TextLabel
    local l = Instance.new("TextLabel")
    l.Name = name
    l.BackgroundTransparency = 1
    l.FontFace = font
    l.TextColor3 = colour
    l.TextScaled = true
    l.TextWrapped = true
    l.TextXAlignment = align or Enum.TextXAlignment.Left
    l.TextYAlignment = Enum.TextYAlignment.Top
    l.Size = size
    l.Position = position
    l.Text = ""
    l.Parent = parent
    return l
end

function Panel.mount(parent: Instance, options: Options?): Panel
    local given: Options = options or {}
    local share = given.share or 0.5
    local right = given.side == "right"
    local font = given.font or Font.fromEnum(Enum.Font.GothamBold)
    local accent = given.accent or Color3.fromRGB(255, 196, 64)
    local background = given.background or Color3.fromRGB(18, 20, 26)
    local text = given.text or Color3.fromRGB(240, 242, 246)
    local dim = text:Lerp(background, 0.45)

    local gui = Instance.new("ScreenGui")
    gui.Name = Panel.Name
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 900
    gui.ResetOnSpawn = false

    local side = Instance.new("Frame")
    side.Name = "Side"
    side.BorderSizePixel = 0
    side.BackgroundColor3 = background
    side.BackgroundTransparency = if given.seeThrough then 1 else 0
    side.Size = UDim2.fromScale(share, 1)
    side.Position = UDim2.fromScale(if right then 1 - share else 0, 0)
    side.Visible = false
    side.Parent = gui

    local content = Instance.new("CanvasGroup")
    content.Name = "Content"
    content.BackgroundTransparency = 1
    content.Size = UDim2.fromScale(0.84, 0.84)
    content.Position = UDim2.fromScale(0.08, 0.08)
    content.Parent = side

    -- The tag's pill fits its word (a fixed width clipped CHANGED in a narrow panel).
    local tag =
        label(content, "Tag", font, background, UDim2.fromScale(0, 0.045), UDim2.fromScale(0, 0))
    tag.BackgroundTransparency = 0
    tag.BackgroundColor3 = accent
    tag.AutomaticSize = Enum.AutomaticSize.X
    tag.TextScaled = false
    tag.TextWrapped = false
    tag.TextXAlignment = Enum.TextXAlignment.Center
    tag.TextYAlignment = Enum.TextYAlignment.Center
    local padding = Instance.new("UIPadding")
    padding.Parent = tag
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.3, 0)
    corner.Parent = tag

    local title =
        label(content, "Title", font, text, UDim2.fromScale(1, 0.1), UDim2.fromScale(0, 0.07))
    local lines =
        label(content, "Lines", font, text, UDim2.fromScale(1, 0.42), UDim2.fromScale(0, 0.22))
    lines.TextScaled = false
    local seeingHead = label(
        content,
        "SeeingHead",
        font,
        accent,
        UDim2.fromScale(1, 0.035),
        UDim2.fromScale(0, 0.72)
    )
    seeingHead.Text = "YOU'RE SEEING"
    local seeing =
        label(content, "Seeing", font, dim, UDim2.fromScale(1, 0.12), UDim2.fromScale(0, 0.77))
    seeing.TextScaled = false
    local counter = label(
        content,
        "Counter",
        font,
        dim,
        UDim2.fromScale(0.3, 0.035),
        UDim2.fromScale(0.7, 0.965),
        Enum.TextXAlignment.Right
    )

    local card = Instance.new("CanvasGroup")
    card.Name = "Card"
    card.BorderSizePixel = 0
    card.BackgroundColor3 = background
    card.BackgroundTransparency = if given.seeThrough then 1 else 0
    card.Size = UDim2.fromScale(1, 1)
    card.Visible = false
    card.ZIndex = 2
    card.Parent = gui
    local cardTitle = label(
        card,
        "Title",
        font,
        text,
        UDim2.fromScale(0.7, 0.12),
        UDim2.fromScale(0.15, 0.28),
        Enum.TextXAlignment.Center
    )
    local cardLines = label(
        card,
        "Lines",
        font,
        dim,
        UDim2.fromScale(0.6, 0.36),
        UDim2.fromScale(0.2, 0.46),
        Enum.TextXAlignment.Center
    )
    cardLines.TextScaled = false

    gui.Parent = parent
    return {
        gui = gui,
        side = side,
        content = content,
        tag = tag,
        title = title,
        lines = lines,
        seeingHead = seeingHead,
        seeing = seeing,
        counter = counter,
        card = card,
        cardTitle = cardTitle,
        cardLines = cardLines,
    }
end

-- Body text sized to the screen: a share of the panel's height, in pixels.
local function sized(panel: Panel, share: number): number
    local height = panel.gui.AbsoluteSize.Y
    return math.max(12, math.floor((if height > 0 then height else 720) * share))
end

local function bullets(lines: { string }?): string
    local out = {}
    local list: { string } = lines or {}
    for _, line in list do
        table.insert(out, `·  {line}`)
    end
    return table.concat(out, "\n")
end

local function slideIn(group: CanvasGroup, from: UDim2, to: UDim2)
    group.GroupTransparency = 1
    group.Position = from
    TweenService:Create(group, SLIDE, { GroupTransparency = 0, Position = to }):Play()
end

-- Fill the side panel (and put away the card), sliding the new content in.
function Panel.show(panel: Panel, content: Content)
    panel.card.Visible = false
    panel.side.Visible = true
    panel.tag.Visible = content.tag ~= nil
    panel.tag.Text = content.tag or ""
    panel.tag.TextSize = sized(panel, 0.03)
    local pad = panel.tag:FindFirstChildOfClass("UIPadding") :: UIPadding
    pad.PaddingLeft = UDim.new(0, math.floor(panel.tag.TextSize * 0.6))
    pad.PaddingRight = pad.PaddingLeft
    panel.title.Text = content.title
    panel.lines.Text = bullets(content.lines)
    panel.lines.TextSize = sized(panel, 0.034)
    panel.seeingHead.Visible = content.seeing ~= nil
    panel.seeing.Text = content.seeing or ""
    panel.seeing.TextSize = sized(panel, 0.03)
    panel.counter.Text = content.counter or ""
    slideIn(panel.content, UDim2.fromScale(0.02, 0.08), UDim2.fromScale(0.08, 0.08))
end

-- Show a card across the whole screen, over the panel.
function Panel.card(panel: Panel, card: Card)
    panel.card.Visible = true
    panel.cardTitle.Text = card.title
    panel.cardLines.Text = table.concat(card.lines or {}, "\n")
    panel.cardLines.TextSize = sized(panel, 0.036)
    panel.card.GroupTransparency = 1
    TweenService:Create(panel.card, SLIDE, { GroupTransparency = 0 }):Play()
end

-- Put both away.
function Panel.clear(panel: Panel)
    panel.card.Visible = false
    panel.side.Visible = false
end

-- The api for a take's beats, on `panel` (nil: a reel without one, and it does nothing).
function Panel.api(get: () -> Panel?): Api
    return {
        show = function(content)
            local panel = get()
            if panel then
                Panel.show(panel, content)
            end
        end,
        card = function(card)
            local panel = get()
            if panel then
                Panel.card(panel, card)
            end
        end,
        clear = function()
            local panel = get()
            if panel then
                Panel.clear(panel)
            end
        end,
    }
end

return Panel

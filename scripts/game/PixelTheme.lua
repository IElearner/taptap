-- Warm village colors on PixelForge's hard-edged widget grammar.
-- Pass this table to UI.Init and keep UI.Scale.DEFAULT in the entrypoint.
local UI = require "urhox-libs/UI"
---@class ShanheliPixelTheme
---@field colors table<string,number[]>
local C = {
    primary = {175,68,45,255}, primaryHover = {202,86,53,255}, primaryPressed = {137,46,35,255},
    secondary = {92,71,49,255}, secondaryHover = {115,91,60,255}, secondaryPressed = {65,48,35,255},
    background = {31,30,25,255}, surface = {48,42,32,255}, surfaceHover = {66,57,40,255}, surfaceAlt = {57,49,35,255},
    text = {249,235,202,255}, textSecondary = {197,181,145,255}, textDisabled = {133,120,98,255},
    border = {132,104,63,255}, borderFocus = {230,184,92,255}, disabled = {63,57,47,255}, disabledText = {143,130,108,255}, disabledBorder = {78,66,48,255},
    success = {76,120,81,255}, successHover = {96,145,94,255}, successPressed = {53,91,62,255},
    warning = {232,183,86,255}, warningHover = {247,206,116,255}, error = {190,66,48,255}, errorHover = {216,86,63,255}, errorPressed = {139,43,32,255},
    info = {114,166,154,255}, overlay = {23,25,21,185}, transparent = {0,0,0,0},
}
local hard = {{x=3,y=3,blur=0,color={18,16,13,220}}}
local buttonShadow = {{x=3,y=3,blur=0,color={18,16,13,230}},{x=-1,y=-1,blur=0,color={255,235,180,65}}}
return UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
    name = "Shanheli PixelForge",
    fonts = {
        {family="sans",weights={normal="Fonts/FusionPixel-12px-Prop-zh_hans.ttf",bold="Fonts/FusionPixel-12px-Prop-zh_hans-Bold.ttf"}},
        {family="mono",weights={normal="Fonts/FusionPixel-12px-Prop-zh_hans.ttf",bold="Fonts/FusionPixel-12px-Prop-zh_hans-Bold.ttf"}},
    },
    typography = {fontFamily="sans",h1={fontSize=27},h2={fontSize=18},h3={fontSize=13.5},body={fontSize=9},bodySmall={fontSize=9},caption={fontSize=9}},
    colors = C, spacing = {xs=4,sm=8,md=12,lg=16,xl=24,xxl=32},
    radius = {none=0,xs=0,sm=0,md=0,lg=0,xl=0,full=0}, componentDefaults = {borderRadius=0},
    components = {
        Button = {borderRadius=0,borderWidth=2,borderColor={49,35,24,255},boxShadow=buttonShadow,hoverBoxShadow=buttonShadow,pressedBoxShadow=false,disabledBoxShadow=false,fontWeight="bold",fontSize=9,paddingHorizontal=12},
        Card = {borderWidth=2,borderColor=C.border,boxShadow=hard,showDividers=false,backgroundColor=C.surface},
        Label = {fontFamily="sans",fontSize=9,fontColor=C.text},
        ScrollView = {scrollbarColor=C.border,scrollbarThumbColor=C.warning}, ProgressBar = {height=12,borderWidth=2},
        Modal = {borderWidth=2,boxShadow=hard,headerBgColor=C.surfaceAlt,headerBorderWidth=2,footerBorderWidth=2},
        Drawer = {borderWidth=2,boxShadow=hard,contentPadding=12},
        Menu = {borderWidth=2,boxShadow=hard,itemHoverBgColor=C.surfaceHover,itemHoverTextColor=C.warning,itemHoverRadius=0},
        Tooltip = {borderWidth=2,boxShadow=hard,tooltipBgColor=C.surface}, Toast = {borderWidth=2,boxShadow=hard,showIcon=false},
    },
}) --[[@as ShanheliPixelTheme]]

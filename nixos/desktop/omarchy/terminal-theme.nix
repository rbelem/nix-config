# Renders one Omarchy theme into the colour file of a given terminal.
#
# Omarchy ships one colors.toml per theme and lets each application read it.
# This renders the palette into the format the terminal expects, so the same
# theme drives the compositor and the terminal.
#
# Each terminal needs two files: the colours, and a main configuration that
# loads them. A terminal with no main configuration of its own never shows
# the colours, which is why both are produced here.
{ theme, terminal }:

let
  # foot wants the hex digits without the leading hash.
  rgb = colour: builtins.substring 1 (builtins.stringLength colour) colour;
in

let
  kitty = ''
    # Generated from the Omarchy theme.
    foreground ${theme.foreground}
    background ${theme.background}
    cursor ${theme.foreground}
    cursor_text_color ${theme.background}
    selection_background ${theme.selection}
    selection_foreground ${theme.foreground}
    url_color ${theme.blue}
    active_border_color ${theme.accent}
    inactive_border_color ${theme.muted}
    bell_border_color ${theme.yellow}
  '';

  kittyConfig = ''
    # Generated from the Omarchy theme.
    include themes/omarchy.conf
  '';

  alacritty = ''
    # Generated from the Omarchy theme.
    [colors.primary]
    background = "${theme.background}"
    foreground = "${theme.foreground}"

    [colors.cursor]
    text = "${theme.background}"
    cursor = "${theme.foreground}"

    [colors.selection]
    text = "${theme.foreground}"
    background = "${theme.selection}"

    [colors.normal]
    black = "${theme.dark_foreground}"
    red = "${theme.red}"
    green = "${theme.green}"
    yellow = "${theme.yellow}"
    blue = "${theme.blue}"
    magenta = "${theme.magenta}"
    cyan = "${theme.cyan}"
    white = "${theme.light_foreground}"

    [colors.bright]
    black = "${theme.muted}"
    red = "${theme.bright_red}"
    green = "${theme.bright_green}"
    yellow = "${theme.bright_yellow}"
    blue = "${theme.blue}"
    magenta = "${theme.bright_magenta}"
    cyan = "${theme.bright_cyan}"
    white = "${theme.bright_foreground}"
  '';

  alacrittyConfig = ''
    # Generated from the Omarchy theme.
    [general]
    import = ["themes/omarchy.toml"]
  '';

  # foot 1.28 keeps its colours in the colors-dark and colors-light sections,
  # and wants the hex digits without a leading hash. The same palette is
  # written to both, so the terminal looks the same either way.
  foot = ''
    # Generated from the Omarchy theme.
    [colors-dark]
    background=${rgb theme.background}
    foreground=${rgb theme.foreground}
    selection-foreground=${rgb theme.foreground}
    selection-background=${rgb theme.selection}
    regular0=${rgb theme.dark_foreground}
    regular1=${rgb theme.red}
    regular2=${rgb theme.green}
    regular3=${rgb theme.yellow}
    regular4=${rgb theme.blue}
    regular5=${rgb theme.magenta}
    regular6=${rgb theme.cyan}
    regular7=${rgb theme.light_foreground}
    bright0=${rgb theme.muted}
    bright1=${rgb theme.bright_red}
    bright2=${rgb theme.bright_green}
    bright3=${rgb theme.bright_yellow}
    bright4=${rgb theme.blue}
    bright5=${rgb theme.bright_magenta}
    bright6=${rgb theme.bright_cyan}
    bright7=${rgb theme.bright_foreground}

    [colors-light]
    background=${rgb theme.background}
    foreground=${rgb theme.foreground}
    selection-foreground=${rgb theme.foreground}
    selection-background=${rgb theme.selection}
    regular0=${rgb theme.dark_foreground}
    regular1=${rgb theme.red}
    regular2=${rgb theme.green}
    regular3=${rgb theme.yellow}
    regular4=${rgb theme.blue}
    regular5=${rgb theme.magenta}
    regular6=${rgb theme.cyan}
    regular7=${rgb theme.light_foreground}
    bright0=${rgb theme.muted}
    bright1=${rgb theme.bright_red}
    bright2=${rgb theme.bright_green}
    bright3=${rgb theme.bright_yellow}
    bright4=${rgb theme.blue}
    bright5=${rgb theme.bright_magenta}
    bright6=${rgb theme.bright_cyan}
    bright7=${rgb theme.bright_foreground}
  '';

  footConfig = ''
    # Generated from the Omarchy theme.
    include=~/.config/foot/themes/omarchy
  '';

  # Ghostty takes its colours as hex, the same strings the other terminals
  # get, so there is nothing to convert here.
  ghostty = ''
    # Generated from the Omarchy theme.
    background = ${theme.background}
    foreground = ${theme.foreground}
    cursor-color = ${theme.foreground}
    cursor-text = ${theme.background}
    selection-background = ${theme.selection}
    selection-foreground = ${theme.foreground}
    palette = 0=${theme.dark_foreground}
    palette = 1=${theme.red}
    palette = 2=${theme.green}
    palette = 3=${theme.yellow}
    palette = 4=${theme.blue}
    palette = 5=${theme.magenta}
    palette = 6=${theme.cyan}
    palette = 7=${theme.light_foreground}
    palette = 8=${theme.muted}
    palette = 9=${theme.bright_red}
    palette = 10=${theme.bright_green}
    palette = 11=${theme.bright_yellow}
    palette = 12=${theme.blue}
    palette = 13=${theme.bright_magenta}
    palette = 14=${theme.bright_cyan}
    palette = 15=${theme.bright_foreground}
  '';

  ghosttyConfig = ''
    # Generated from the Omarchy theme.
    config-file = ~/.config/ghostty/themes/omarchy
  '';
in
{
  foot = { theme = foot; config = footConfig; };
  alacritty = { theme = alacritty; config = alacrittyConfig; };
  kitty = { theme = kitty; config = kittyConfig; };
  ghostty = { theme = ghostty; config = ghosttyConfig; };
}.${terminal}

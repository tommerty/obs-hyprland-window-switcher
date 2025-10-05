# Hyprland Active Window Shower


![demo](/assets/preview.gif)

This is a simple Lua script that'll toggle sources depending if the source is the "activewindow" based on `hyprctl`.

## Getting started

### Prepping the script
I've made it easy to know the `class` of each window be printed in the script logs.
1. Download the lua file and navigate to Tools > Scripts and add the script.
2. Open the Script Log and start hovering/changing your "active window", and you should see the `class` populate.
3. Don't worry about configuring the script further, first we need to create the sources.

### Sources
1. Create a scene and create multiple "Screen Capture (PipeWire)" sources, one for each app you want to switch between
2. Name each source `auto_class`, where `class` is the class outputted by `hyprctl`. Some examples are:
`com.obsproject.Studio` = OBS
`zen` = Zen browser
`code` = VS Code
`com.discordapp.Discord` = Discord
Going off this, create a source called `auto_com.discordapp.Discord`, and choose your Discord window in the selector.
3. I recommend applying the following transitions to the source:
    - Positional Alignment = Center
    - Bounding Box Type = Scale to inner bounds
    - Alignmnt in Bounding Box = Center
    Once done this, stretch the window to fit your canvas. Any other sources you create, you can right click and copy/paste the transition value. These settings will help prevent any odd stretching or cropping.

Proceed to doing this for as many sources you want to "auto capture".

### Finishing the script
1. Head back over to Tools > Scripts and under Scene with Window Sources, choose the scene that contains all the sources you've just created
2. I'd recommend leaving the update internal at 500ms
3. Once completed, I'd recommend ensuring all the sources are "hidden" (the eye icon has the line through it) and then clikc "Refresh Window Sources". You should now be able to move your mouse around, and any windows you activate that you've added a source for should appear.
4. Not required, but I recommend having another scene to which you add this scene with all your sources to, otherwise things can get messy. This follows "good OBS practices"

## Tips
- To make the changing appear nicer, you could utilize the OBS Move Transition plugin by Exeldro, right click each source and under "Show/Hide Transition" create a custom transition that moves the sources on visibility change.
- You could create a standard screen capture below all these other sources so that if you're active window isn't a window you've created a source for, it'll just show the entire screen, not a blank canvas.

## Limitations
- I went this route as I couldn't find a good solution to update a single source via lua. This is likely a limitation or permission issue. It'd be very likely to do with something like StreamerBot or other, but I wanted to create a simple lua script that didn't require additional tools that can be troublesome to get working on Linux. If anyone has ideas on how to improve this, I'd be all ears and open to pull requests!

- I initially set out to replicate the standard obs follows mouse, but hit some hard walls. I'd love to implement that, but I couldn't find a real solution. I'm all ears if someone can figure it out!
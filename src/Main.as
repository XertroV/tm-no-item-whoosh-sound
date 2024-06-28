const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$df5";
const string PluginIcon = Icons::Kenney::SoundOff;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

MemPatcher@ PatchNoWhooshDecoItems = MemPatcher(
    // v jne that we patch to jmp
    "0F 85 ?? ?? 00 00 49 83 BF ?? ?? 00 00 00 0F 84 ?? 00 00 00 F3 0F 10 46",
    {0}, {"90 E9"}
);

// Note: this is at the end of the loop, just before incrementing the indexes (there are 2, rcx and rdx)
// 4C 8B 6C 24 58 41 89 86 D8 00 00 00 8B 4C 24 48 48 8B 55 F0 FF C1 F3 44 0F 10 44 24 30 48 FF C2

void Main() {
    yield(60);
    if (S_PatchActive) {
        PatchNoWhooshDecoItems.Apply();
    }
}

/** Called when the plugin is unloaded and completely removed from memory.
*/
void OnDestroyed() {
    PatchNoWhooshDecoItems.Unapply();
}
void OnDisabled() {
    PatchNoWhooshDecoItems.Unapply();
}

[Setting hidden]
bool S_PatchActive = true;

void OnEnabled() {
    if (S_PatchActive) {
        PatchNoWhooshDecoItems.Apply();
    }
}

[SettingsTab name="No Item Whoosh"]
void R_S_Main() {
    auto newVal = UI::Checkbox("Patch Active", S_PatchActive);
    if (newVal != S_PatchActive) {
        S_PatchActive = newVal;
        PatchNoWhooshDecoItems.IsApplied = newVal;
    }
    UI::TextWrapped("Will not disable item whooshes for the currently loaded map. If you activate the patch, you need to reload the map.");
}

/** Render function called every frame intended only for menu items in `UI`.
*/
void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", S_PatchActive)) {
        S_PatchActive = !S_PatchActive;
        PatchNoWhooshDecoItems.IsApplied = S_PatchActive;
    }
}

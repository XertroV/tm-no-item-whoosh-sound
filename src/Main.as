const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cogs;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

/** Called every frame. `dt` is the delta time (milliseconds since last frame).
*/
void Update(float dt) {
    auto app = GetApp();
    if (app.RootMap is null) return;
    // ALHook::Update();
}

/** Called when the plugin is unloaded and completely removed from memory.
*/
void OnDestroyed() {
    CheckUnhookAllRegisteredHooks();
}

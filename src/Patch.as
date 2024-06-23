



const string SourcesAudioLoopPattern =
    //              v mov [r14+d8],eax             v load rdx from rbp-10
    "4C 8B 6C 24 58 41 89 86 D8 00 00 00 8B 4C 24 48 48 8B 55 F0 FF C1 F3 44 0F 10 44 24 30 48 FF C2";
    //                                   ^ load ecx from rsp+48  ^ inc ecx


// we want to increase the index to skip all ItemWhoosh sounds which appear to be loaded first

HookHelper@ SourcesAudioLoopHook = HookHelper(SourcesAudioLoopPattern, 0, 0, "SourcesAudioLoopHook_Run", Dev::PushRegisters::SSE, true);

namespace ALHook {
    [Setting category="General" name="Skip Whoosh" description="Skip the whoosh sound when passing items"]
    bool ShouldSkipWhoosh = true;

    uint lastZ2Len = 0;
    uint whooshSourcesLastIx;

    void Update() {
        if (!ShouldSkipWhoosh) return;
        auto app = GetApp();
        auto ap = app.AudioPort;
        if (ap is null || ap.Zones.Length < 2) return;
        auto zone = ap.Zones[1];
        MwId wdiId;
        wdiId.SetName("WhooshDecoItems");
        auto wdiValue = wdiId.Value;
        if (lastZ2Len != zone.Sources.Length) {
            lastZ2Len = zone.Sources.Length;
            for (int i = lastZ2Len - 1; i > 0; i--) {
                auto ps = zone.Sources[i].PlugSound;
                if (ps is null) continue;
                if (ps.Id.Value == wdiValue) {
                    whooshSourcesLastIx = i;
                    dev_trace('whoosh last ix: ' + whooshSourcesLastIx);
                    break;
                }
            }
        }
        // if (SourcesAudioLoopHook.Ptr > 0) {
        //     trace('hook before: ' + Dev::Read(SourcesAudioLoopHook.Ptr, 8));
        // }
        SourcesAudioLoopHook.Apply();
        // if (SourcesAudioLoopHook.Ptr > 0) {
        //     trace('hook after apply: ' + Dev::Read(SourcesAudioLoopHook.Ptr, 8));
        // }
    }
}

void SourcesAudioLoopHook_Run(uint64 rbp) {
    // set ix to: len - 25;
    // ix at rsp+x48 and rbp-x10
    // len @ rbp-x24;
    // trace("SourcesAudioLoopHook_Run: rbp = " + Text::FormatPointer(rbp));
    int len = Dev::ReadInt32(rbp - 0x24);
    // trace("SourcesAudioLoopHook_Run: len = " + len);
    // skip the zone with len 16
    if (len <= 100) return;
    auto lastWhoosh = ALHook::whooshSourcesLastIx;
    // trace('lastWhoosh: ' + lastWhoosh);
    auto rsp = rbp - 0x100;
    // trace("SourcesAudioLoopHook_Run: rsp = " + Text::FormatPointer(rsp));
    auto sourceIx = Dev::ReadUInt32(rbp - 0x10);
    // trace('sourceIx = ' + sourceIx);
    auto count = Dev::ReadUInt32(rsp + 0x48);
    // trace('count = ' + count);
    if (sourceIx != count) {
        // trace('sourceIx != count');
        return;
    }
    if (sourceIx > lastWhoosh) return;
    uint newIx = Math::Max(sourceIx, lastWhoosh);
    Dev::Write(rbp - 0x10, newIx);
    Dev::Write(rsp + 0x48, newIx);
}


// 88  88  dP"Yb   dP"Yb  88  dP 88  88 888888 88     88""Yb 888888 88""Yb
// 88  88 dP   Yb dP   Yb 88odP  88  88 88__   88     88__dP 88__   88__dP
// 888888 Yb   dP Yb   dP 88"Yb  888888 88""   88  .o 88"'"  88""   88"Yb
// 88  88  YbodP   YbodP  88  Yb 88  88 888888 88ood8 88     888888 88  Yb



// tracks the last time a warning was issued
dictionary warnTracker;
void warn_every_60_s(const string &in msg) {
    if (warnTracker is null) {
        warn(msg);
        return;
    }
    if (warnTracker.Exists(msg)) {
        uint lastWarn = uint(warnTracker[msg]);
        if (int(Time::Now) - int(lastWarn) < 60000) return;
    } else {
        NotifyWarning(msg);
    }
    warnTracker[msg] = Time::Now;
    warn(msg);
}



// Wrapper around Dev::Hook for safety and easy usage; findPtrEarly = find pointer immediately, e.g., if bytes around that location might be patched later.
class HookHelper {
    protected Dev::HookInfo@ hookInfo;
    protected uint64 patternPtr;

    // protected string name;
    protected string pattern;
    protected uint offset;
    protected uint padding;
    protected string functionName;
    protected Dev::PushRegisters pushReg;

    // const string &in name,
    HookHelper(const string &in pattern, uint offset, uint padding, const string &in functionName, Dev::PushRegisters pushRegs = Dev::PushRegisters::SSE, bool findPtrEarly = false) {
        this.pattern = pattern;
        this.offset = offset;
        this.padding = padding;
        this.functionName = functionName;
        this.pushReg = pushRegs;
        startnew(CoroutineFunc(_RegisterUnhookCall));
        if (findPtrEarly) startnew(CoroutineFunc(FindPatternPtr));
    }

    ~HookHelper() {
        Unapply();
    }

    uint64 get_Ptr() {
        return patternPtr;
    }

    void _RegisterUnhookCall() {
        RegisterUnhookFunction(UnapplyHookFn(this.Unapply));
    }

    void FindPatternPtr() {
        if (patternPtr == 0) patternPtr = Dev::FindPattern(pattern);
        dev_trace("HookHelper["+functionName+"] found ptr: " + Text::FormatPointer(patternPtr));
    }

    bool Apply() {
        if (hookInfo !is null) return false;
        if (patternPtr == 0) patternPtr = Dev::FindPattern(pattern);
        if (patternPtr == 0) {
            warn_every_60_s("Failed to apply hook for " + functionName + " (pattern ptr == 0)");
            return false;
        }
        @hookInfo = Dev::Hook(patternPtr + offset, padding, functionName, pushReg);
        if (hookInfo is null) {
            warn_every_60_s("Failed to apply hook for " + functionName + " (hookInfo == null)");
            return false;
        }
        trace("Hook applied for " + functionName + " at " + Text::FormatPointer(patternPtr + offset));
        return true;
    }

    bool Unapply() {
        if (hookInfo is null) return false;
        Dev::Unhook(hookInfo);
        @hookInfo = null;
        return true;
    }

    bool IsApplied() {
        return hookInfo !is null;
    }

    void SetApplied(bool v) {
        if (v && hookInfo !is null) return;
        if (!v && hookInfo is null) return;
        if (v) Apply();
        else Unapply();
    }

    void Toggle() {
        SetApplied(!IsApplied());
    }
}


// A hook helper for a function hook
class FunctionHookHelper : HookHelper {
    protected uint64 functionPtr;
    protected int32 callOffset;
    protected int32 origCallRelOffset;
    protected uint64 cavePtr;

    FunctionHookHelper(const string &in pattern, uint offset, uint padding, const string &in functionName, Dev::PushRegisters pushRegs = Dev::PushRegisters::SSE) {
        super(pattern, offset, padding, functionName, pushRegs);
    }

    bool Apply() override {
        if (IsApplied()) return true;
        if (!HookHelper::Apply()) return false;
        trace("FunctionHookHelper::Apply for " + functionName);
        // read offset assuming jmp [offset]; 5 bytes
        auto caveRelOffset = Dev::ReadInt32(patternPtr + offset + 1);
        dev_trace("caveRelOffset: " + caveRelOffset);
        // calculate the address of the cave
        cavePtr = patternPtr + offset + 5 + caveRelOffset;
        dev_trace("cavePtr: " + Text::FormatPointer(cavePtr));
        // read offset assuming call [offset]; 5 bytes
        origCallRelOffset = Dev::ReadInt32(cavePtr + 1);
        dev_trace("origCallRelOffset: " + origCallRelOffset);
        // calculate the address of the original function
        functionPtr = patternPtr + offset + 5 + origCallRelOffset;
        dev_trace("functionPtr: " + Text::FormatPointer(functionPtr));
        // calculate the offset of the call instruction and write it
        auto newCallRelOffset = int32(functionPtr - cavePtr - 5);
        dev_trace("newCallRelOffset: " + newCallRelOffset);
        if (cavePtr + 5 + newCallRelOffset != patternPtr + offset + 5 + origCallRelOffset) {
            NotifyWarning("bad new call offset. cavePtr: " + cavePtr + ", newCallRelOffset: " + newCallRelOffset + ", origCallRelOffset: " + origCallRelOffset + ", functionPtr: " + functionPtr + ", patternPtr: " + patternPtr + ", offset: " + offset);
            HookHelper::Unapply();
            return false;
        }
        Dev::Write(cavePtr + 1, newCallRelOffset);
        return true;
    }

    bool Unapply() override {
        if (!IsApplied()) return true;
        if (functionPtr == 0 || cavePtr == 0) {
            NotifyWarning("bad function ptr or cave ptr. function ptr: " + functionPtr + ", cave ptr: " + cavePtr + ". Failed to unapply hook for " + functionName);
            return false;
        }
        // write the original call offset back
        Dev::Write(cavePtr + 1, origCallRelOffset);
        if (!HookHelper::Unapply()) return false;
        return true;
    }
}


void dev_trace(const string &in msg) {
#if DEV
    trace(msg);
#endif
}


funcdef bool UnapplyHookFn();

UnapplyHookFn@[] unapplyHookFns;
void RegisterUnhookFunction(UnapplyHookFn@ fn) {
    if (fn is null) throw("null fn passted to reg unhook fn");
    unapplyHookFns.InsertLast(fn);
}

void CheckUnhookAllRegisteredHooks() {
    for (uint i = 0; i < unapplyHookFns.Length; i++) {
        unapplyHookFns[i]();
    }
}
